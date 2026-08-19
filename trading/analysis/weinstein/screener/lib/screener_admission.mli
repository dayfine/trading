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

val failed_breakout_reason :
  tolerance_pct:float ->
  breakout_price:float option ->
  current_close:float option ->
  string option
(** Failed-breakout re-validation for long candidates.

    {b Authority — engineering adaptation, not a book-quoted rule.}
    weinstein-book-reference.md states no rule that "a close back below the
    breakout level invalidates the candidate". What this gate does is enforce
    spine item 3 (entry on a breakout above resistance) against {b current}
    data: §4.1 requirement 1 ("stock breaks out above resistance AND above the
    30-week MA") read as a condition that must still hold at {b evaluation}
    time, not only on the breakout bar. §4.6 notes the "greater risk of false
    breakout", and §5.2 handles the failure case downstream ("IF whipsaw (stock
    later breaks out again): acceptable to re-buy") — so an invalidated
    candidate is dropped from the buy list, never barred from re-entry.

    {b Why [tolerance_pct] must not be set small.} The §Stage 2 detail (Ch. 2)
    says the usual post-breakout pullback "close to the breakout point" is a
    {b second chance to buy}. [tolerance_pct] is precisely what separates that
    healthy pullback from a genuine failure — too small a value de-lists
    candidates the book would have you buy.

    Returns [Some reason] when the candidate is invalidated: a human-readable
    drop reason for the watchlist / report. Returns [None] when the candidate
    stands.

    [tolerance_pct] is the knob [k]: invalidate iff
    [current_close < breakout_price *. (1. -. k)].
    - [k <= 0.0] (the default no-op) disables the gate entirely — always [None],
      bit-identical to pre-feature behaviour on every input.
    - A missing [breakout_price] or a missing [current_close] is treated as
      "unknown" and never invalidates. Absence of data is not evidence of a
      failed breakout. *)

val passes_failed_breakout :
  tolerance_pct:float ->
  breakout_price:float option ->
  current_close:float option ->
  bool
(** Boolean form of {!failed_breakout_reason}: [true] iff the candidate is NOT
    invalidated. Defined as [Option.is_none (failed_breakout_reason ...)] so the
    gate and the reported reason can never drift. *)

val count_long_failed_breakouts :
  tolerance_pct:float ->
  early_stage2_max_weeks:int ->
  candidates:(Stock_analysis.t * sector_context) list ->
  int
(** How many long candidates the failed-breakout gate dropped: those that pass
    {!Stock_analysis.is_breakout_candidate} but fail {!passes_failed_breakout}.
    Feeds {!Screener_cascade_diagnostics.t.long_failed_breakout_dropped} so the
    drop is visible in the cascade report. Always [0] when the gate is disabled
    ([tolerance_pct <= 0.0]). *)

val rs_blocks_short : Rs.result option -> bool
(** Hard gate per Weinstein Ch. 11: never short a stock with strong relative
    strength, even if it breaks down. Returns [true] for candidates whose RS
    trend is positive ([Positive_rising], [Positive_flat], [Bullish_crossover]).
    [Negative_improving] stays eligible; absent RS data is treated as not-strong
    (doesn't block shorts). *)

val rs_blocks_long : min_rs_normalized:float -> Rs.result option -> bool
(** Long-side mirror of {!rs_blocks_short}: book §4.4 rule 2,
    {i "negative RS in negative territory → NEVER buy, no matter how good the
       other factors"}. A hard admission gate, not a scoring input — RS
    previously entered the long path only as score points ({!Screener_scoring}
    [_rs_long_signal]), which is a soft preference and does not implement the
    book's prohibition (#2381).

    Returns [true] when [current_normalized < min_rs_normalized] and the trend
    is not the exempt one (see the conjunction paragraph below).
    [current_normalized] is the Mansfield zero-line position — [rs_value] over
    its own long-term average ([Relative_strength._build_history]) — so
    {b 1.0 is the zero line}: above is positive territory, below is negative.
    [min_rs_normalized = 1.0] is therefore the book-faithful setting, and [0.0]
    (the default) blocks nothing, since the ratio of two positive price series
    is always positive.

    The comparison is strict, so a candidate sitting exactly on the zero line is
    admitted, and the [0.0] default is an exact no-op rather than a near one.

    {b The rule is a conjunction}, so one trend is exempt regardless of level:
    [Bullish_crossover] is never blocked. §4.4 rule 3 makes a stock "crossing
    from negative to positive territory" an {b A+ bonus signal}, and
    mid-crossing it is still below [1.0] — a level-only gate would block
    precisely the cohort the book singles out.

    The exemption is exactly one trend, which keeps this the mirror of
    {!rs_blocks_short}: that gate counts [Bullish_crossover] as {i strong} (so
    it blocks shorts) and this one counts it as {i not weak} (so it admits
    longs). [Negative_improving] mirrors too — {i not strong} there, therefore
    still {i weak} here, and still {b blocked}. Improving-but-still-negative is
    not rule 3's case; rule 3 names the crossing.

    [Positive_flat] is deliberately {b not} exempt. "Positive and flat"
    contradicts a sub-[1.0] level, so its appearance there is a symptom of the
    stuck trend classifier (#2380) rather than signal; exempting it would make
    the gate inert. Consequently the trend arm of the conjunction is inert
    {i today} — every candidate classifies as [Positive_flat] — and the gate
    behaves level-only. It becomes faithful the moment #2380 lands, with no
    further change here.

    Absent RS data does {b not} block, mirroring {!rs_blocks_short}: the rule
    prohibits buying on {i established} negative RS, and a missing series does
    not establish it. *)

val count_long_phases :
  weights:scoring_weights ->
  thresholds:grade_thresholds ->
  min_grade:Weinstein_types.grade ->
  min_score_override:int option ->
  max_score_override:int option ->
  volume_ratio_exclude_range:volume_ratio_band option ->
  min_price:float ->
  failed_breakout_tolerance_pct:float ->
  early_stage2_max_weeks:int ->
  min_rs_normalized:float ->
  candidates:(Stock_analysis.t * sector_context) list ->
  int * int * int
(** Long-side cascade-phase counts [(breakout, sector, grade)] for the
    diagnostics record. Each phase short-circuits (a [false] earlier phase keeps
    later phases [false]) so the triple is monotone non-increasing. The
    [min_price] liquidity floor and the [failed_breakout_tolerance_pct]
    re-validation both fold into the breakout phase. [early_stage2_max_weeks] is
    the early-Stage2 admission window (see
    [Screener.config.early_stage2_max_weeks]) threaded into both the breakout
    gate and the score so the diagnostic count tracks the live cascade.

    {b [min_rs_normalized] folds into the grade phase}, unlike the short side,
    where {!count_short_phases} reports its RS gate as a phase of its own. The
    long triple is deliberately left at three components so the
    cascade-diagnostics record — and every report built on it — is untouched,
    which is what makes the [0.0] default a provable no-op. The cost is
    attribution: with the gate armed, RS drops are indistinguishable from score
    drops in [grade]. Splitting it out is a follow-up, and is only worth doing
    once some config actually arms the gate. *)

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

val diagnostics_for_screen :
  weights:scoring_weights ->
  grade_thresholds:grade_thresholds ->
  min_grade:Weinstein_types.grade ->
  min_score_override:int option ->
  max_score_override:int option ->
  volume_ratio_exclude_range:volume_ratio_band option ->
  min_price:float ->
  failed_breakout_tolerance_pct:float ->
  early_stage2_max_weeks:int ->
  min_rs_normalized:float ->
  total_stocks:int ->
  candidates_after_held:int ->
  macro_trend:Weinstein_types.market_trend ->
  candidates:(Stock_analysis.t * sector_context) list ->
  buy_candidates:'a list ->
  short_candidates:'b list ->
  Screener_cascade_diagnostics.t
(** The cascade-diagnostics record for one {!Screener.screen} call: runs
    {!count_long_phases}, {!count_long_failed_breakouts} and
    {!count_short_phases} and hands the results to
    {!Screener_cascade_diagnostics.build}.

    Lives here rather than in [Screener] because this module owns the three
    counters it composes; [Screener] only needed the result. It moved out of
    [screener.ml] when that file hit the 500-line declared-large cap
    (`code-health-discipline.md`: extract, do not raise the limit).

    [buy_candidates] / [short_candidates] are only measured for their length,
    hence the free type variables. *)
