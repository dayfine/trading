(** Tier-aware bar loader — see [bar_loader.mli]. *)

open Core
module Price_cache = Trading_simulation_data.Price_cache
module Summary_compute = Summary_compute
module Full_compute = Full_compute
module Shadow_screener = Shadow_screener

type tier = Metadata_tier | Summary_tier | Full_tier
[@@deriving show, eq, sexp]

module Metadata = struct
  type t = {
    symbol : string;
    sector : string;
    last_close : float;
    avg_vol_30d : float option;
    market_cap : float option;
  }
  [@@deriving show, eq, sexp]
end

module Summary = struct
  type t = {
    symbol : string;
    ma_30w : float;
    atr_14 : float;
    rs_line : float;
    stage : Weinstein_types.stage;
    as_of : Date.t;
  }
  [@@deriving show, eq, sexp]
end

module Full = struct
  type t = { symbol : string; bars : Types.Daily_price.t list; as_of : Date.t }
  [@@deriving show, eq]
end

type stats_counts = { metadata : int; summary : int; full : int }
[@@deriving show, eq, sexp]

type tier_op = Promote_to_summary | Promote_to_full | Demote_op
[@@deriving show, eq]

type trace_hook = {
  record : 'a. tier_op:tier_op -> symbols:int -> (unit -> 'a) -> 'a;
}

type entry = {
  tier : tier;
  metadata : Metadata.t option;
  summary : Summary.t option;
  full : Full.t option;
}
(** Per-symbol entry. Held in a mutable hashtable keyed on symbol. [tier] is the
    highest tier this symbol has been promoted to; the tier-specific data fields
    are populated at and below that tier. [summary] is [None] for Metadata-only
    entries. [full] is [None] for everything below Full tier. *)

(** [_default_benchmark_symbol] is the canonical RS benchmark used by the
    backtest runner. Bar_loader doesn't care which ticker it is, but keeping a
    sensible default means most callers don't need to pass it explicitly. *)
let _default_benchmark_symbol = "SPY"

type t = {
  sector_map : string String.Table.t;
  entries : (string, entry) Hashtbl.t;
  price_cache : Price_cache.t;
  data_dir : Fpath.t;
  benchmark_symbol : string;
  summary_config : Summary_compute.config;
  full_config : Full_compute.config;
  trace_hook : trace_hook option;
      (** When [Some _], [promote] / [demote] wrap their per-call body with the
          hook. When [None], the wrappers short-circuit and produce behaviour
          identical to the pre-hook version — critical for the acceptance
          guarantee that an un-traced run is behaviourally unchanged. *)
  mutable benchmark_bars : Types.Daily_price.t list option;
      (** Lazily loaded on the first Summary promotion. Benchmark bars are read
          via [Csv_storage] directly (bypassing [Price_cache]) so they don't
          inflate the shared cache — but we keep them here because the benchmark
          is the one symbol every Summary promotion needs. *)
}

let create ~data_dir ~sector_map ~universe:_
    ?(benchmark_symbol = _default_benchmark_symbol)
    ?(summary_config = Summary_compute.default_config)
    ?(full_config = Full_compute.default_config) ?trace_hook () =
  (* [universe] is accepted in the signature so 3b/3c/3f can drive tier-wide
     operations ("promote every universe symbol to Metadata on startup")
     without a signature churn. Not consumed yet. *)
  {
    sector_map;
    entries = Hashtbl.create (module String);
    price_cache = Price_cache.create ~data_dir;
    data_dir;
    benchmark_symbol;
    summary_config;
    full_config;
    trace_hook;
    benchmark_bars = None;
  }

let tier_of t ~symbol =
  Hashtbl.find t.entries symbol |> Option.map ~f:(fun e -> e.tier)

let get_metadata t ~symbol =
  Option.bind (Hashtbl.find t.entries symbol) ~f:(fun e -> e.metadata)

let get_summary t ~symbol =
  Option.bind (Hashtbl.find t.entries symbol) ~f:(fun e -> e.summary)

let get_full t ~symbol =
  Option.bind (Hashtbl.find t.entries symbol) ~f:(fun e -> e.full)

(** [_tier_rank] encodes the Metadata < Summary < Full ordering used for
    idempotent promotion: a symbol at tier [>= to_] is left alone. *)
let _tier_rank = function
  | Metadata_tier -> 0
  | Summary_tier -> 1
  | Full_tier -> 2

(** [_already_at_or_above t ~symbol tier] is [true] when [symbol] is registered
    in [t] at [tier] or higher — i.e. promotion to [tier] would be a no-op.
    Reading this as the guard at the top of each promote helper flattens the
    nested [match Some/None]/[when]/[else] cascade. *)
let _already_at_or_above t ~symbol tier =
  match Hashtbl.find t.entries symbol with
  | Some entry -> _tier_rank entry.tier >= _tier_rank tier
  | None -> false

(** [_load_metadata] reads the last bar on or before [as_of] from the shared
    [Price_cache] and joins the sector table. Market cap and average volume are
    [None] on this increment — wired when the first consumer needs them (§Risks
    #4 of the plan). *)
let _load_metadata t ~symbol ~as_of : (Metadata.t, Status.t) Result.t =
  match Price_cache.get_prices t.price_cache ~symbol ~end_date:as_of () with
  | Error err -> Error err
  | Ok [] ->
      Error
        (Status.not_found_error
           (Printf.sprintf "No bars for %s on or before %s" symbol
              (Date.to_string as_of)))
  | Ok bars ->
      let last = List.last_exn bars in
      let sector =
        Hashtbl.find t.sector_map symbol |> Option.value ~default:""
      in
      Ok
        {
          Metadata.symbol;
          sector;
          last_close = last.close_price;
          avg_vol_30d = None;
          market_cap = None;
        }

(** [_promote_one_to_metadata] is idempotent: if the symbol is already at
    Metadata or higher, it's a no-op. Otherwise it runs the metadata load and
    inserts the entry. *)
let _promote_one_to_metadata t ~symbol ~as_of : (unit, Status.t) Result.t =
  if _already_at_or_above t ~symbol Metadata_tier then Ok ()
  else
    let%map.Result metadata = _load_metadata t ~symbol ~as_of in
    Hashtbl.set t.entries ~key:symbol
      ~data:
        {
          tier = Metadata_tier;
          metadata = Some metadata;
          summary = None;
          full = None;
        }

(** [_load_bars_tail] reads the most recent [tail_days] daily bars for [symbol]
    ending on or before [as_of], {e bypassing} [Price_cache]. Summary promotion
    drops these bars immediately after computing scalars; keeping them out of
    [Price_cache] prevents the raw history from leaking into the shared cache
    and surviving past the promotion.

    Parameterized on [tail_days] so Full-tier promotion (which wants a larger
    window for complete strategy analysis) can reuse the same CSV path without
    duplicating the load logic.

    Performance note: this is one CSV read + parse per promote. In the planned
    cascade (Metadata → Summary only on sector-ranked subset, ~2k symbols; Full
    on ~200 candidates) the call count stays bounded; the bottleneck is not
    expected here. Wire trace phase [Promote_summary]/[Promote_full] (3d) to
    measure first before optimising. *)
let _load_bars_tail t ~symbol ~as_of ~tail_days :
    (Types.Daily_price.t list, Status.t) Result.t =
  let%bind.Result storage =
    Csv.Csv_storage.create ~data_dir:t.data_dir symbol
  in
  let start_date = Date.add_days as_of (-tail_days) in
  Csv.Csv_storage.get storage ~start_date ~end_date:as_of ()

(** [_benchmark_bars_for] returns the bounded-tail bars for the benchmark
    symbol, loading them lazily on the first Summary promotion. The loaded
    series covers from the earliest [as_of] a caller has ever asked about minus
    [tail_days] through the latest [as_of] — in practice the backtest replays
    forward so this cache grows monotonically.

    In 3b we keep it simple: load once on first use for the given [as_of],
    reload if subsequent calls need a different window. For the current
    batch-promote-all-symbols-on-Friday workflow this is fine because every
    symbol within the batch shares the same [as_of]. *)
let _benchmark_bars_for t ~as_of : (Types.Daily_price.t list, Status.t) Result.t
    =
  let load () =
    let%map.Result bars =
      _load_bars_tail t ~symbol:t.benchmark_symbol ~as_of
        ~tail_days:t.summary_config.tail_days
    in
    t.benchmark_bars <- Some bars;
    bars
  in
  match t.benchmark_bars with
  | None -> load ()
  | Some bars -> (
      match List.last bars with
      | None -> load ()
      | Some last when Date.(last.date < as_of) -> load ()
      | Some _ -> Ok bars)

(** [_write_summary_entry] is the no-Result tail of [_promote_one_to_summary]:
    given freshly-computed scalars, build the [Summary.t], join it with any
    existing metadata, and overwrite the entry. Pure side-effect — extracted so
    the caller's main flow stays a flat let%bind chain. *)
let _write_summary_entry t ~symbol (values : Summary_compute.summary_values) =
  let existing_metadata =
    Option.bind (Hashtbl.find t.entries symbol) ~f:(fun e -> e.metadata)
  in
  let summary : Summary.t =
    {
      symbol;
      ma_30w = values.ma_30w;
      atr_14 = values.atr_14;
      rs_line = values.rs_line;
      stage = values.stage;
      as_of = values.as_of;
    }
  in
  Hashtbl.set t.entries ~key:symbol
    ~data:
      {
        tier = Summary_tier;
        metadata = existing_metadata;
        summary = Some summary;
        full = None;
      }

(** [_promote_one_to_summary] auto-promotes through Metadata first, then fetches
    a bounded tail, computes the Summary scalars, and drops the raw bars. A
    symbol with insufficient history is left at its current tier (Metadata after
    the auto-promote) — no error surfaced, because insufficient history is a
    pre-condition for Summary, not a load failure. *)
let _promote_one_to_summary t ~symbol ~as_of : (unit, Status.t) Result.t =
  if _already_at_or_above t ~symbol Summary_tier then Ok ()
  else
    let%bind.Result () = _promote_one_to_metadata t ~symbol ~as_of in
    let%bind.Result stock_bars =
      _load_bars_tail t ~symbol ~as_of ~tail_days:t.summary_config.tail_days
    in
    let%map.Result benchmark_bars = _benchmark_bars_for t ~as_of in
    Summary_compute.compute_values ~config:t.summary_config ~stock_bars
      ~benchmark_bars ~as_of
    |> Option.iter ~f:(fun values -> _write_summary_entry t ~symbol values)

(** [_write_full_entry] is the no-Result tail of [_promote_one_to_full]: builds
    the [Full.t] from freshly-loaded bars, joins with any existing metadata /
    summary, and overwrites the entry. Pure side-effect — extracted so the
    caller's main flow stays a flat let%bind chain. *)
let _write_full_entry t ~symbol (values : Full_compute.full_values) =
  let existing = Hashtbl.find t.entries symbol in
  let existing_metadata = Option.bind existing ~f:(fun e -> e.metadata) in
  let existing_summary = Option.bind existing ~f:(fun e -> e.summary) in
  let full : Full.t = { symbol; bars = values.bars; as_of = values.as_of } in
  Hashtbl.set t.entries ~key:symbol
    ~data:
      {
        tier = Full_tier;
        metadata = existing_metadata;
        summary = existing_summary;
        full = Some full;
      }

(** [_promote_one_to_full] auto-promotes through Summary first (which itself
    cascades through Metadata).

    Summary scalar resolution is best-effort: a symbol whose history is too
    short to resolve [ma_30w] / [rs_line] / [stage] stays at Metadata after the
    Summary attempt — but we still proceed to load the Full OHLCV tail and write
    a Full entry. The resulting Full-tier entry has [summary = None]; consumers
    that want indicator scalars must check [get_summary] for [Some _].

    Rationale: the Tiered backtest pipeline gates [Bar_history] population on
    Full-tier promotion (see [Tiered_strategy_wrapper._throttled_get_price]). If
    we required Summary scalars before allowing Full, then a small-fixture
    backtest with insufficient warmup would leave [Bar_history] permanently
    empty — even though the strategy can perfectly well screen with the
    available bars (the strategy has its own per-indicator None handling). This
    was the actual root cause of the residual bull-crash A/B parity gap: on the
    small CI fixture (CSV starts well after the simulator's warmup start),
    Summary required [rs_ma_period] weekly bars before any universe symbol could
    reach Full. Tiered ran with empty [Bar_history] until the Summary RS window
    resolved, while Legacy's [Bar_history.accumulate] (which has no
    minimum-history requirement) populated history day-by-day from
    [warmup_start]. Result: Tiered missed every entry between the simulator's
    [start_date] and the first day Summary resolved — observed as a multi-
    trade, ~five-figure portfolio-value drift on the bull-crash scenario.

    The minimal load requirement for Full is [Metadata succeeded] +
    [_load_bars_tail returned at least one bar]. Both are checks the
    Metadata-cascade and the [Csv.Csv_storage.get] return path already enforce —
    no extra gate here. *)
let _promote_one_to_full t ~symbol ~as_of : (unit, Status.t) Result.t =
  if _already_at_or_above t ~symbol Full_tier then Ok ()
  else
    let%bind.Result () = _promote_one_to_summary t ~symbol ~as_of in
    let%map.Result bars =
      _load_bars_tail t ~symbol ~as_of ~tail_days:t.full_config.tail_days
    in
    Full_compute.compute_values ~bars
    |> Option.iter ~f:(fun values -> _write_full_entry t ~symbol values)

let _promote_fold ~f symbols =
  List.fold_until symbols ~init:()
    ~f:(fun () symbol ->
      match f ~symbol with
      | Ok () -> Continue ()
      | Error err -> Stop (Error err))
    ~finish:(fun () -> Ok ())

(** [_maybe_trace t ~tier_op ~symbols f] routes [f] through [t.trace_hook] when
    one is registered, and runs [f ()] directly otherwise. The [None] branch is
    a plain pass-through so the un-traced code path has zero observable overhead
    beyond a single [Option] match. *)
let _maybe_trace t ~tier_op ~symbols f =
  match t.trace_hook with
  | None -> f ()
  | Some hook -> hook.record ~tier_op ~symbols f

let promote t ~symbols ~to_ ~as_of =
  let batch_size = List.length symbols in
  let run_metadata () =
    _promote_fold symbols ~f:(fun ~symbol ->
        _promote_one_to_metadata t ~symbol ~as_of)
  in
  let run_summary () =
    _promote_fold symbols ~f:(fun ~symbol ->
        _promote_one_to_summary t ~symbol ~as_of)
  in
  let run_full () =
    _promote_fold symbols ~f:(fun ~symbol ->
        _promote_one_to_full t ~symbol ~as_of)
  in
  match to_ with
  | Metadata_tier ->
      (* Metadata promotion is the legacy [Load_bars] path — not traced as a
         tier-op. The runner wraps the outer Load_bars phase. *)
      run_metadata ()
  | Summary_tier ->
      _maybe_trace t ~tier_op:Promote_to_summary ~symbols:batch_size run_summary
  | Full_tier ->
      _maybe_trace t ~tier_op:Promote_to_full ~symbols:batch_size run_full

(** [_demote_one] drops higher-tier data from an existing entry. The caller
    guarantees the entry exists; tier-of-target is enforced here (a symbol at
    tier [<= to_] is unchanged). *)
let _demote_one t ~symbol ~to_ =
  match Hashtbl.find t.entries symbol with
  | None -> ()
  | Some entry when _tier_rank entry.tier <= _tier_rank to_ -> ()
  | Some entry ->
      let new_entry =
        match to_ with
        | Metadata_tier ->
            (* Drop both Summary scalars and Full bars. Per plan §Resolutions
               #6: Full → Metadata is a full drop; re-promotion recomputes
               Summary. *)
            { entry with tier = Metadata_tier; summary = None; full = None }
        | Summary_tier ->
            (* Drop Full bars, keep Summary scalars. Cheap reversal for
               "candidate no longer held but may re-enter soon". *)
            { entry with tier = Summary_tier; full = None }
        | Full_tier ->
            (* Demoting "to Full" is degenerate — Full is the top tier, so
               there's nothing higher to drop. Preserve entry as-is. *)
            entry
      in
      Hashtbl.set t.entries ~key:symbol ~data:new_entry

let demote t ~symbols ~to_ =
  let run () =
    List.iter symbols ~f:(fun symbol -> _demote_one t ~symbol ~to_)
  in
  _maybe_trace t ~tier_op:Demote_op ~symbols:(List.length symbols) run

let stats t =
  Hashtbl.fold t.entries ~init:{ metadata = 0; summary = 0; full = 0 }
    ~f:(fun ~key:_ ~data acc ->
      match data.tier with
      | Metadata_tier -> { acc with metadata = acc.metadata + 1 }
      | Summary_tier -> { acc with summary = acc.summary + 1 }
      | Full_tier -> { acc with full = acc.full + 1 })
