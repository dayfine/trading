(** Named per-candidate cascade trace for the Weinstein screener.

    {!Screener_admission}'s counters answer {i how many} candidates each cascade
    phase dropped; this module answers {i which ones} — the same question for
    the same candidates, off the same {!Screener_admission.long_admission} /
    {!Screener_admission.short_admission} predicates the counters fold, so the
    named trace and the counted diagnostics cannot drift. Issue #2490 gap G2,
    and the per-drop breakout sub-reason of issue #2533.

    Extracted from {!Screener_admission} when that file hit the 300-line cap
    (`code-health-discipline.md`: extract, do not raise the limit). The split is
    along a real seam — admission {i predicates and counts} below, the {i named}
    trace built on them here — and is one-directional, so nothing in the
    counting path depends on the trace.

    All functions are pure. Callers outside the screener library reference these
    through {!Screener}, which re-exports this module via
    [include module type of]. *)

open Screener_scoring

(** Where in the cascade a candidate stopped.

    The long side has no [Dropped_at_rs] case: book §4.4 rule 2 folds into the
    grade phase there (see {!Screener_admission.count_long_phases}), so only
    {!short_outcomes} ever emits it. *)
type cascade_phase =
  | Admitted  (** Survived every phase and reached the screener's top-N. *)
  | Dropped_at_macro
  | Dropped_at_breakout of Screener_admission.breakout_gate
      (** Long: the breakout phase — see {!Screener_admission.breakout_gate} for
          which dial, and for the first-failing-gate contract that makes
          per-constructor counts a partition of the dropped population. Short:
          the mirrored breakdown phase. The payload makes it impossible to
          record a breakout drop without naming its sub-reason (#2533). *)
  | Dropped_at_sector
  | Dropped_at_rs  (** Short side only. *)
  | Dropped_at_grade
  | Dropped_at_top_n
      (** Passed every gate but fell outside [max_buy_candidates] /
          [max_short_candidates]. *)
[@@deriving sexp, eq, show]

type candidate_outcome = {
  ticker : string;
  phase : cascade_phase;
  score : int;
      (** The candidate's cascade score. Computed for {b every} candidate,
          including ones dropped before the grade phase — the counting path
          skips that work, but a trace row without a score cannot be compared
          against an admitted one. *)
  grade : Weinstein_types.grade;  (** [grade_of_score] applied to [score]. *)
}
[@@deriving sexp, eq]
(** One candidate's cascade outcome plus the scoring the screener knows and
    {!Stock_analysis.t} does not. Everything else a consumer needs (stage, RS,
    volume, sector) is already on the candidate's own analysis. *)

val long_outcomes :
  weights:scoring_weights ->
  thresholds:grade_thresholds ->
  min_grade:Weinstein_types.grade ->
  min_score_override:int option ->
  max_score_override:int option ->
  volume_ratio_exclude_range:Screener_admission.volume_ratio_band option ->
  min_price:float ->
  failed_breakout_tolerance_pct:float ->
  early_stage2_max_weeks:int ->
  min_rs_normalized:float ->
  macro_admits:bool ->
  top_n_tickers:Core.String.Set.t ->
  candidates:(Stock_analysis.t * sector_context) list ->
  candidate_outcome list
(** Per-candidate long-side cascade outcome, in [candidates] order.

    Built on {!Screener_admission.long_admission}, the same predicate
    {!Screener_admission.count_long_phases} folds, so the two agree by
    construction: for any candidate set, the number of outcomes at or past a
    phase equals that phase's count in {!Screener_cascade_diagnostics.t}.

    [macro_admits] must be the {b same} gate the diagnostics record applies —
    [macro_trend <> Bearish], {e not} the [neutral_blocks_longs] variant the
    live evaluation uses — or the trace and the counts disagree on a Neutral
    tape. When [false], every candidate is [Dropped_at_macro], mirroring
    [Screener_cascade_diagnostics.build]'s zeroing of the downstream counts.

    [top_n_tickers] is the ticker set of the screener's emitted
    [buy_candidates]. A candidate that clears the grade phase but is not in the
    set was truncated by the top-N cap. *)

val short_outcomes :
  weights:scoring_weights ->
  thresholds:grade_thresholds ->
  min_grade:Weinstein_types.grade ->
  min_score_override:int option ->
  max_score_override:int option ->
  volume_ratio_exclude_range:Screener_admission.volume_ratio_band option ->
  min_price:float ->
  macro_admits:bool ->
  top_n_tickers:Core.String.Set.t ->
  candidates:(Stock_analysis.t * sector_context) list ->
  candidate_outcome list
(** Short-side mirror of {!long_outcomes}, over
    {!Screener_admission.short_admission}. [macro_admits] is
    [macro_trend <> Bullish] here. Emits [Dropped_at_rs] for the Ch. 11 hard
    gate, which the long side folds into the grade phase. *)
