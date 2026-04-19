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
      currently held. Added in 3c.

    As of 3b, this module implements Metadata and Summary tiers. The [tier]
    variant already exposes all three tags so 3c extends the loader without
    churn to the variant. [promote ~to_:Full_tier] returns
    [Error Status.Unimplemented] until 3c; [get_full] always returns [None]. *)

open Core

(** {1 Re-exports} *)

module Summary_compute = Summary_compute
(** Pure compute helpers used by the Summary tier. Re-exported so callers and
    tests can reach the compute layer through the library's main module without
    depending on the internal module directly. *)

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

(** {1 Loader} *)

type t
(** Mutable bag of per-symbol tier assignments + computed data. Opaque — callers
    go through [promote] / [get_*] / [stats]. Not safe to share across threads.
*)

type stats_counts = { metadata : int; summary : int; full : int }
[@@deriving show, eq, sexp]
(** Current per-tier symbol counts; used by tracer / parity harness. *)

val create :
  data_dir:Fpath.t ->
  sector_map:string String.Table.t ->
  universe:string list ->
  ?benchmark_symbol:string ->
  ?summary_config:Summary_compute.config ->
  unit ->
  t
(** [create ~data_dir ~sector_map ~universe ?benchmark_symbol ?summary_config
     ()] returns a fresh loader. [universe] is the full set of symbols the
    backtest may promote; it is recorded but does {b not} load any bars
    (Metadata-tier loads happen in [promote]). [sector_map] is a symbol → sector
    lookup; symbols missing from the map get [sector = ""] on promotion.
    [data_dir] is forwarded to an internal [Price_cache] used for Metadata-tier
    last-close lookups.

    [benchmark_symbol] is the ticker used to align bars when computing the
    Summary-tier RS line (typically ["SPY"] or ["^GSPC"]). Default: ["SPY"]. Its
    bars are loaded on first Summary promotion and cached inside the loader.

    [summary_config] controls the windows used to compute Summary scalars (see
    {!Summary_compute.default_config}). Default:
    {!Summary_compute.default_config}. *)

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
    - [Full_tier]: returns [Error Status.Unimplemented] until 3c.

    Returns the first per-symbol error encountered (if any). A symbol that fails
    to load is {e not} added to the loader. *)

val demote : t -> symbols:string list -> to_:tier -> unit
(** [demote t ~symbols ~to_] tiers each symbol down, freeing higher-tier data. A
    symbol currently at tier [<= to_] is unchanged.

    - [to_ = Metadata_tier] drops Summary scalars (and Full bars, in 3c).
    - [to_ = Summary_tier] drops only Full bars (no-op for Summary-only
      symbols).

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

val get_full : t -> symbol:string -> unit option
(** Placeholder for 3c. Always returns [None] in this increment; the return type
    is [unit option] to keep the interface signature stable until 3c introduces
    [Full.t]. *)

val stats : t -> stats_counts
(** [stats t] returns the current per-tier symbol counts. The sum of the three
    fields equals the number of symbols that have been promoted at least once
    (and not subsequently demoted below Metadata). *)
