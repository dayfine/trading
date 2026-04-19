(** Tier-aware bar loader.

    Step 3 of the backtest-scale plan
    (dev/plans/backtest-tiered-loader-2026-04-19.md). The loader keeps
    per-symbol data at one of three tiers so the backtest working set scales
    with {e actively tracked} symbols rather than {e total inventory}:

    - {b Metadata} — last-bar scalars (last close, sector, optional cap and
      average volume). One record for {e every} universe symbol.
    - {b Summary} — sector-ranked subset; indicator scalars (30w MA, RS line,
      stage heuristic, ATR) computed from a bounded tail of bars; raw bars
      dropped.
    - {b Full} — raw OHLCV history for symbols actively considered for entry
      or currently held.

    This increment (3a) implements {b Metadata only}. The [tier] variant
    already exposes all three tags so later increments extend the loader
    without churn in the variant. [Summary.t] and [Full.t] submodules and
    their promotion semantics are added in 3b / 3c. In 3a,
    [promote ~to_:Summary_tier] and [promote ~to_:Full_tier] raise
    [Failure]; [get_summary] and [get_full] always return [None]. *)

open Core

(** {1 Tier tag} *)

type tier = Metadata_tier | Summary_tier | Full_tier
[@@deriving show, eq, sexp]
(** Discrete ordering of tiers by information content:
    [Metadata_tier] < [Summary_tier] < [Full_tier]. Promotion moves a symbol
    to a higher tier; demotion moves it back down. *)

(** {1 Tier-shaped data} *)

module Metadata : sig
  type t = {
    symbol : string;
    sector : string;
        (** Sector name as loaded from the sector table. [""] when the symbol
            has no sector entry — the loader does not synthesize a sector. *)
    last_close : float;  (** Close price of the last bar on or before [as_of]. *)
    avg_vol_30d : float option;
        (** 30-day average volume. [None] on this increment — wired in a
            later PR when the screener needs it. *)
    market_cap : float option;
        (** Market capitalization. [None] on this increment. *)
  }
  [@@deriving show, eq, sexp]
end

(** {1 Loader} *)

type t
(** Mutable bag of per-symbol tier assignments + computed data. Opaque —
    callers go through [promote] / [get_*] / [stats]. Not safe to share
    across threads. *)

type stats_counts = { metadata : int; summary : int; full : int }
[@@deriving show, eq, sexp]
(** Current per-tier symbol counts; used by tracer / parity harness. *)

val create :
  data_dir:Fpath.t -> sector_map:string String.Table.t -> universe:string list -> t
(** [create ~data_dir ~sector_map ~universe] returns a fresh loader. [universe]
    is the full set of symbols the backtest may promote; it is recorded but
    does {b not} load any bars (Metadata-tier loads happen in [promote]).
    [sector_map] is a symbol → sector lookup; symbols missing from the map
    get [sector = ""] on promotion. [data_dir] is forwarded to an internal
    [Price_cache] used on demand. *)

val promote :
  t -> symbols:string list -> to_:tier -> as_of:Date.t -> (unit, Status.t) Result.t
(** [promote t ~symbols ~to_ ~as_of] moves every symbol in [symbols] up to
    tier [to_], loading whatever data that tier needs. Idempotent: a symbol
    already at tier [>= to_] is unchanged.

    In this increment only [to_ = Metadata_tier] is implemented — passing
    [Summary_tier] or [Full_tier] returns an [Error] with a
    [Status.Unimplemented] code. Subsequent increments (3b, 3c) add those
    branches.

    Returns the first per-symbol error encountered (if any). A symbol that
    fails to load is {e not} added to the loader. *)

val demote : t -> symbols:string list -> to_:tier -> unit
(** [demote t ~symbols ~to_] tiers each symbol down, freeing higher-tier data.
    A symbol currently at tier [<= to_] is unchanged. Calling with
    [to_ = Metadata_tier] fully drops any Summary / Full caches.

    In 3a, since promote only reaches Metadata, [demote] is effectively a
    no-op — included for API completeness so 3b / 3c extend the behaviour
    without a signature change. *)

val tier_of : t -> symbol:string -> tier option
(** [tier_of t ~symbol] returns the current tier of [symbol], or [None] if
    the symbol has never been promoted in this loader. *)

val get_metadata : t -> symbol:string -> Metadata.t option
(** [get_metadata t ~symbol] returns the Metadata record for [symbol] when
    it has been promoted at least to Metadata tier, otherwise [None]. *)

val get_summary : t -> symbol:string -> unit option
(** Placeholder for 3b. Always returns [None] in this increment; the return
    type is [unit option] to keep the interface signature stable until 3b
    introduces [Summary.t]. *)

val get_full : t -> symbol:string -> unit option
(** Placeholder for 3c. Always returns [None] in this increment; same
    stability rationale as [get_summary]. *)

val stats : t -> stats_counts
(** [stats t] returns the current per-tier symbol counts. The sum of the
    three fields equals the number of symbols that have been promoted at
    least once (and not subsequently demoted below Metadata). *)
