(** Tier-aware bar loader.

    Step 3 of the backtest-scale plan
    (dev/plans/backtest-tiered-loader-2026-04-19.md). The loader keeps
    per-symbol data at one of three tiers so the backtest working set scales
    with {e actively tracked} symbols rather than {e total inventory}:

    - {b Metadata} — last-bar scalars (last close, sector, optional cap and
      average volume). One record for {e every} universe symbol.
    - {b Summary} — sector-ranked subset; indicator scalars (30w MA, RS line,
      stage heuristic, ATR) computed from a bounded tail of daily bars. The raw
      bars are dropped once the scalars are extracted, which is the core memory
      win over holding full OHLCV history.
    - {b Full} — raw OHLCV history for symbols actively considered for entry or
      currently held. Full-tier promotions load a bounded tail of daily bars and
      retain them in the loader's own cache; demotion drops the bars.

    As of 3c, the loader implements all three tiers. Full-tier promotion
    auto-promotes through Metadata and Summary first; demotion of a Full-tier
    symbol to Summary drops the raw bars (and keeps the Summary scalars), and
    demotion to Metadata drops both (per plan §Resolutions #6: Full → Metadata
    is a full drop; re-promotion recomputes). *)

open Core

(** {1 Re-exports} *)

module Summary_compute = Summary_compute
(** Pure compute helpers used by the Summary tier. Re-exported so callers and
    tests can reach the compute layer through the library's main module without
    depending on the internal module directly. *)

module Full_compute = Full_compute
(** Pure compute helpers used by the Full tier. Re-exported for the same reason
    as {!Summary_compute}. *)

module Shadow_screener = Shadow_screener
(** Adapter that drives the existing [Screener.screen] from Summary-tier scalars
    — the shadow screener the Tiered runner path uses on Fridays. Re-exported so
    the Tiered runner can reach it through the library's main module. *)

(** {1 Tier tag} *)

(** Discrete ordering of tiers by information content: [Metadata_tier] <
    [Summary_tier] < [Full_tier]. Promotion moves a symbol to a higher tier;
    demotion moves it back down. *)
type tier = Metadata_tier | Summary_tier | Full_tier
[@@deriving show, eq, sexp]

(** {1 Tier-shaped data} *)

module Metadata : sig
  type t = {
    symbol : string;
    sector : string;
        (** Sector name as loaded from the sector table. [""] when the symbol
            has no sector entry — the loader does not synthesize a sector. *)
    last_close : float;
        (** Close price of the last bar on or before [as_of]. *)
    avg_vol_30d : float option;
        (** 30-day average volume. [None] on this increment — wired in a later
            PR when the screener needs it. *)
    market_cap : float option;
        (** Market capitalization. [None] on this increment. *)
  }
  [@@deriving show, eq, sexp]
end

module Summary : sig
  type t = {
    symbol : string;
    ma_30w : float;  (** 30-week simple MA of weekly-aggregated closes. *)
    atr_14 : float;  (** Average True Range over the last 14 daily bars. *)
    rs_line : float;
        (** Latest Mansfield normalized RS value ([raw_rs / MA(raw_rs)]). Values
            above 1.0 indicate the stock is outperforming its own recent
            baseline. *)
    stage : Weinstein_types.stage;
        (** Weinstein stage heuristic from the one-shot classifier. *)
    as_of : Date.t;  (** Date of the last bar used to derive the scalars. *)
  }
  [@@deriving show, eq, sexp]
  (** Indicator scalars derived from a bounded tail of daily bars. Raw bars are
      dropped once this record is constructed — the memory footprint per symbol
      is fixed at a handful of floats rather than the full history. *)
end

module Full : sig
  type t = {
    symbol : string;
    bars : Types.Daily_price.t list;
        (** OHLCV history loaded from CSV, covering
            [[as_of - full_config.tail_days, as_of]]. Ordered ascending by date.
        *)
    as_of : Date.t;  (** Date of the last bar in [bars]. *)
  }
  [@@deriving show, eq]
  (** Complete-history tier data for symbols under active consideration. Unlike
      {!Summary.t}, the raw bars are retained so callers can drive the full
      Weinstein analysis pipeline (daily price path, weekly aggregation,
      breakout detection). Memory cost is proportional to [List.length bars];
      callers control the fleet size via {!promote} / {!demote}.
      [Types.Daily_price.t] has no sexp converters, so this record omits [sexp]
      — use [show] for test/debug output. *)
end

(** {1 Loader} *)

type t
(** Mutable bag of per-symbol tier assignments + computed data. Opaque — callers
    go through [promote] / [get_*] / [stats]. Not safe to share across threads.
*)

type stats_counts = { metadata : int; summary : int; full : int }
[@@deriving show, eq, sexp]
(** Current per-tier symbol counts; used by tracer / parity harness. *)

(** {1 Tracer hook} *)

(** Which bar_loader operation produced a trace event. Kept distinct from
    [Backtest.Trace.Phase.t] so [bar_loader] stays independent of the [backtest]
    library — the latter depends on [bar_loader] in 3e (tiered runner path) and
    a reverse edge would cycle. Callers route these to the matching
    [Trace.Phase.t] variants (typically [Promote_summary], [Promote_full],
    [Demote]). *)
type tier_op = Promote_to_summary | Promote_to_full | Demote_op
[@@deriving show, eq]

type trace_hook = {
  record : 'a. tier_op:tier_op -> symbols:int -> (unit -> 'a) -> 'a;
}
(** Callback invoked once per [promote] / [demote] batch when the loader was
    constructed with [?trace_hook = Some _]. The wrapper shape
    ([(unit -> 'a) -> 'a]) matches [Trace.record] so a tracer-wrapping caller
    can time the inner work exactly once without measuring overhead elsewhere.

    [symbols] is the count of symbols in the batch — forwarded by conventional
    callers as [symbols_in] on the emitted phase metric. The wrapped thunk's
    return value is passed through unchanged, so the bar_loader implementation
    can wrap its internal per-tier work transparently. *)

val create :
  data_dir:Fpath.t ->
  sector_map:string String.Table.t ->
  universe:string list ->
  ?benchmark_symbol:string ->
  ?summary_config:Summary_compute.config ->
  ?full_config:Full_compute.config ->
  ?trace_hook:trace_hook ->
  unit ->
  t
(** [create ~data_dir ~sector_map ~universe ?benchmark_symbol ?summary_config
     ?full_config ?trace_hook ()] returns a fresh loader. [universe] is the full
    set of symbols the backtest may promote; it is recorded but does {b not}
    load any bars (Metadata-tier loads happen in [promote]). [sector_map] is a
    symbol → sector lookup; symbols missing from the map get [sector = ""] on
    promotion. [data_dir] is forwarded to an internal [Price_cache] used for
    Metadata-tier last-close lookups.

    [benchmark_symbol] is the ticker used to align bars when computing the
    Summary-tier RS line (typically ["SPY"] or ["^GSPC"]). Default: ["SPY"]. Its
    bars are loaded on first Summary promotion and cached inside the loader.

    [summary_config] controls the windows used to compute Summary scalars (see
    {!Summary_compute.default_config}). Default:
    {!Summary_compute.default_config}.

    [full_config] controls the length of the OHLCV tail fetched on Full-tier
    promotion (see {!Full_compute.default_config}). Default:
    {!Full_compute.default_config}.

    [trace_hook] registers a tracer callback. When omitted, [promote] and
    [demote] do no tracing work at all — the implementation short-circuits
    before entering the hook and produces observable behaviour identical to the
    pre-hook version. *)

val promote :
  t ->
  symbols:string list ->
  to_:tier ->
  as_of:Date.t ->
  (unit, Status.t) Result.t
(** [promote t ~symbols ~to_ ~as_of] moves every symbol in [symbols] up to tier
    [to_], loading whatever data that tier needs. Idempotent: a symbol already
    at tier [>= to_] is unchanged.

    Tier-specific load behaviour:
    - [Metadata_tier]: reads the last bar on or before [as_of] from the shared
      [Price_cache].
    - [Summary_tier]: auto-promotes through Metadata first, then reads a bounded
      tail ([summary_config.tail_days] of daily bars ending at [as_of]) directly
      from CSV storage — bypassing [Price_cache] so the raw bars are never
      retained. The benchmark symbol's tail is loaded once and cached for
      subsequent Summary promotions in the same session. A symbol whose history
      is too short to produce all Summary scalars is left at Metadata tier (not
      an error — the caller should retry later or leave the symbol where it is).
    - [Full_tier]: auto-promotes through Metadata and Summary first, then reads
      a bounded OHLCV tail ([full_config.tail_days]) and retains the raw bars on
      the entry. A symbol that could not be promoted to Summary (insufficient
      history) is left at whatever lower tier it reached — Full promotion is
      skipped, not erroring.

    Returns the first per-symbol error encountered (if any). A symbol that fails
    to load is {e not} added to the loader.

    Tracing: when [trace_hook] was provided to [create] and [to_] is
    [Summary_tier] or [Full_tier], the loader calls the hook once per [promote]
    invocation with the appropriate [tier_op] and [symbols] batch size.
    Promotions to [Metadata_tier] are not traced — they are driven by the legacy
    [Load_bars] phase, not a tier-specific operation. *)

val demote : t -> symbols:string list -> to_:tier -> unit
(** [demote t ~symbols ~to_] tiers each symbol down, freeing higher-tier data. A
    symbol currently at tier [<= to_] is unchanged.

    - [to_ = Metadata_tier] drops Summary scalars {e and} any Full-tier bars.
    - [to_ = Summary_tier] drops only Full-tier bars (no-op for Summary-only
      symbols).

    Tracing: when [trace_hook] was provided to [create], the loader calls the
    hook once per [demote] invocation with [tier_op = Demote_op] and [symbols]
    equal to the input list length (not the count of symbols that actually
    changed tier — the batch size is the interesting dimension for the tracer).

    Callers assume demotion is free: there is no reload cost. Re-promoting the
    same symbols back up requires fetching bars again. *)

val tier_of : t -> symbol:string -> tier option
(** [tier_of t ~symbol] returns the current tier of [symbol], or [None] if the
    symbol has never been promoted in this loader. *)

val get_metadata : t -> symbol:string -> Metadata.t option
(** [get_metadata t ~symbol] returns the Metadata record for [symbol] when it
    has been promoted at least to Metadata tier, otherwise [None]. *)

val get_summary : t -> symbol:string -> Summary.t option
(** [get_summary t ~symbol] returns the Summary record for [symbol] when it has
    been promoted to Summary tier or higher, otherwise [None]. *)

val get_full : t -> symbol:string -> Full.t option
(** [get_full t ~symbol] returns the Full-tier record for [symbol] when it has
    been promoted to Full tier, otherwise [None]. *)

val stats : t -> stats_counts
(** [stats t] returns the current per-tier symbol counts. The sum of the three
    fields equals the number of symbols that have been promoted at least once
    (and not subsequently demoted below Metadata). *)
