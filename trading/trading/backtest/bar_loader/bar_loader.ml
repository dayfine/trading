(** Tier-aware bar loader — see [bar_loader.mli]. *)

open Core
module Price_cache = Trading_simulation_data.Price_cache
module Summary_compute = Summary_compute

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

type stats_counts = { metadata : int; summary : int; full : int }
[@@deriving show, eq, sexp]

type entry = {
  tier : tier;
  metadata : Metadata.t option;
  summary : Summary.t option;
}
(** Per-symbol entry. Held in a mutable hashtable keyed on symbol. [tier] is the
    highest tier this symbol has been promoted to; the tier-specific data fields
    are populated at and below that tier. [summary] is [None] for Metadata-only
    entries. Full-tier data will live in a separate field added in 3c. *)

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
  mutable benchmark_bars : Types.Daily_price.t list option;
      (** Lazily loaded on the first Summary promotion. Benchmark bars are read
          via [Csv_storage] directly (bypassing [Price_cache]) so they don't
          inflate the shared cache — but we keep them here because the benchmark
          is the one symbol every Summary promotion needs. *)
}

let create ~data_dir ~sector_map ~universe:_
    ?(benchmark_symbol = _default_benchmark_symbol)
    ?(summary_config = Summary_compute.default_config) () =
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
    benchmark_bars = None;
  }

let tier_of t ~symbol =
  Hashtbl.find t.entries symbol |> Option.map ~f:(fun e -> e.tier)

let get_metadata t ~symbol =
  Option.bind (Hashtbl.find t.entries symbol) ~f:(fun e -> e.metadata)

let get_summary t ~symbol =
  Option.bind (Hashtbl.find t.entries symbol) ~f:(fun e -> e.summary)

let get_full _t ~symbol:_ = None

(** [_tier_rank] encodes the Metadata < Summary < Full ordering used for
    idempotent promotion: a symbol at tier [>= to_] is left alone. *)
let _tier_rank = function
  | Metadata_tier -> 0
  | Summary_tier -> 1
  | Full_tier -> 2

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
  match Hashtbl.find t.entries symbol with
  | Some entry when _tier_rank entry.tier >= _tier_rank Metadata_tier -> Ok ()
  | _ -> (
      match _load_metadata t ~symbol ~as_of with
      | Error err -> Error err
      | Ok metadata ->
          Hashtbl.set t.entries ~key:symbol
            ~data:
              { tier = Metadata_tier; metadata = Some metadata; summary = None };
          Ok ())

(** [_load_bars_tail] reads the most recent [tail_days] daily bars for [symbol]
    ending on or before [as_of], {e bypassing} [Price_cache]. Summary promotion
    drops these bars immediately after computing scalars; keeping them out of
    [Price_cache] prevents the raw history from leaking into the shared cache
    and surviving past the promotion. *)
let _load_bars_tail t ~symbol ~as_of :
    (Types.Daily_price.t list, Status.t) Result.t =
  let%bind.Result storage =
    Csv.Csv_storage.create ~data_dir:t.data_dir symbol
  in
  let start_date = Date.add_days as_of (-t.summary_config.tail_days) in
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
    let%map.Result bars = _load_bars_tail t ~symbol:t.benchmark_symbol ~as_of in
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

(** [_promote_one_to_summary] auto-promotes through Metadata first, then fetches
    a bounded tail, computes the Summary scalars, and drops the raw bars. A
    symbol with insufficient history is left at its current tier (Metadata after
    the auto-promote) — no error surfaced, because insufficient history is a
    pre-condition for Summary, not a load failure. *)
let _promote_one_to_summary t ~symbol ~as_of : (unit, Status.t) Result.t =
  match Hashtbl.find t.entries symbol with
  | Some entry when _tier_rank entry.tier >= _tier_rank Summary_tier -> Ok ()
  | _ -> (
      let%bind.Result () = _promote_one_to_metadata t ~symbol ~as_of in
      let%bind.Result stock_bars = _load_bars_tail t ~symbol ~as_of in
      let%bind.Result benchmark_bars = _benchmark_bars_for t ~as_of in
      match
        Summary_compute.compute_values ~config:t.summary_config ~stock_bars
          ~benchmark_bars ~as_of
      with
      | None ->
          (* Insufficient history — leave at Metadata tier. *)
          Ok ()
      | Some values ->
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
              };
          Ok ())

let _unimplemented_tier tier : Status.t =
  {
    code = Status.Unimplemented;
    message =
      Printf.sprintf
        "Bar_loader.promote: tier %s not yet implemented (Full_tier lands in \
         3c)"
        (show_tier tier);
  }

let _promote_fold ~f symbols =
  List.fold_until symbols ~init:()
    ~f:(fun () symbol ->
      match f ~symbol with
      | Ok () -> Continue ()
      | Error err -> Stop (Error err))
    ~finish:(fun () -> Ok ())

let promote t ~symbols ~to_ ~as_of =
  match to_ with
  | Metadata_tier ->
      _promote_fold symbols ~f:(fun ~symbol ->
          _promote_one_to_metadata t ~symbol ~as_of)
  | Summary_tier ->
      _promote_fold symbols ~f:(fun ~symbol ->
          _promote_one_to_summary t ~symbol ~as_of)
  | Full_tier -> Error (_unimplemented_tier to_)

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
        | Metadata_tier -> { entry with tier = Metadata_tier; summary = None }
        | Summary_tier ->
            (* In 3b the only higher tier is Summary itself; Full tier lands
               in 3c and will drop the raw bars here. Keep [summary] as-is. *)
            { entry with tier = Summary_tier }
        | Full_tier ->
            (* Demoting "to Full" is degenerate — Full is the top tier, so
               there's nothing higher to drop. Preserve entry as-is. *)
            entry
      in
      Hashtbl.set t.entries ~key:symbol ~data:new_entry

let demote t ~symbols ~to_ =
  List.iter symbols ~f:(fun symbol -> _demote_one t ~symbol ~to_)

let stats t =
  Hashtbl.fold t.entries ~init:{ metadata = 0; summary = 0; full = 0 }
    ~f:(fun ~key:_ ~data acc ->
      match data.tier with
      | Metadata_tier -> { acc with metadata = acc.metadata + 1 }
      | Summary_tier -> { acc with summary = acc.summary + 1 }
      | Full_tier -> { acc with full = acc.full + 1 })
