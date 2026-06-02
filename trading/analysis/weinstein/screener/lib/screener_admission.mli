(** Per-candidate admission predicates and cascade-phase counters for the
    Weinstein screener.

    Extracted from [Screener] to keep the cascade coordinator within the
    500-line linter cap. All functions are pure. Callers outside the screener
    library reference these through {!Screener}, which re-exports this module
    via [include module type of]. *)

open Screener_scoring

type volume_ratio_band = { low : float; high : float } [@@deriving sexp]
(** Half-open volume-ratio exclusion band used by the screener config. The
    named-field record (rather than a plain [float * float] tuple) keeps the
    on-disk sexp shape outside the runner's deep-merge "looks like a record"
    heuristic, so a partial-config overlay that sets just this field deep-merges
    correctly. *)

val passes_score_floor :
  thresholds:grade_thresholds ->
  min_grade:Weinstein_types.grade ->
  min_score_override:int option ->
  max_score_override:int option ->
  int ->
  bool
(** Score gate: [true] iff [score] passes both the configured floor and the
    optional ceiling. [min_score_override = Some n] makes the floor [score >= n]
    and bypasses [min_grade]; [None] uses the grade-derived floor.
    [max_score_override = Some m] adds a strict [score < m] ceiling.

    Single source of truth so the score-and-build path and the
    diagnostics-counting predicates can't drift. *)

val passes_volume_band :
  excl:volume_ratio_band option -> Stock_analysis.t -> bool
(** Volume-band exclusion: rejects iff the candidate's volume_ratio is in the
    half-open interval from [low] (inclusive) to [high] (exclusive). Candidates
    without a [volume] result pass through. *)

val passes_price_floor : min_price:float -> price:float option -> bool
(** Liquidity floor (Weinstein trades liquid leaders — book §4.2 Volume
    Confirmation). [true] iff the floor is disabled ([min_price <= 0.0], the
    default no-op) or [price] is known and at/above [min_price]. A [None] price
    is REJECTED under a positive floor (liquidity can't be verified) and
    admitted when the floor is [0.0]. Callers pass the candidate's setup price —
    [breakout_price] for longs, [breakdown_price] for shorts. *)

val rs_blocks_short : Rs.result option -> bool
(** Hard gate per Weinstein Ch. 11: never short a stock with strong relative
    strength, even if it breaks down. Returns [true] for candidates whose RS
    trend is positive ([Positive_rising], [Positive_flat], [Bullish_crossover]).
    [Negative_improving] stays eligible; absent RS data is treated as not-strong
    (doesn't block shorts). *)

val count_long_phases :
  weights:scoring_weights ->
  thresholds:grade_thresholds ->
  min_grade:Weinstein_types.grade ->
  min_score_override:int option ->
  max_score_override:int option ->
  volume_ratio_exclude_range:volume_ratio_band option ->
  min_price:float ->
  candidates:(Stock_analysis.t * sector_context) list ->
  int * int * int
(** Long-side cascade-phase counts [(breakout, sector, grade)] for the
    diagnostics record. Each phase short-circuits (a [false] earlier phase keeps
    later phases [false]) so the triple is monotone non-increasing. The
    [min_price] liquidity floor folds into the breakout phase. *)

val count_short_phases :
  weights:scoring_weights ->
  thresholds:grade_thresholds ->
  min_grade:Weinstein_types.grade ->
  min_score_override:int option ->
  max_score_override:int option ->
  volume_ratio_exclude_range:volume_ratio_band option ->
  min_price:float ->
  candidates:(Stock_analysis.t * sector_context) list ->
  int * int * int * int
(** Short-side cascade-phase counts [(breakdown, sector, rs, grade)] mirroring
    {!count_long_phases}, with the RS hard gate inserted between sector and
    grade. The [min_price] liquidity floor folds into the breakdown phase. *)
