(** Per-candidate evaluation for the screener cascade: the price-parameter and
    scored-candidate types, and the long / short evaluate-sort-cap passes.
    Extracted from {!Screener} to keep that file under the declared-large
    file-length cap. {!Screener.candidate_params} and
    {!Screener.scored_candidate} are type aliases of the types here, so existing
    consumers continue to spell them as [Screener.candidate_params] /
    [Screener.scored_candidate]; the full per-field documentation lives on those
    aliases in [screener.mli]. *)

open Screener_scoring
open Screener_admission

type candidate_params = {
  entry_buffer_pct : float;
  initial_stop_pct : float;
  short_stop_pct : float;
  base_low_proxy_pct : float;
  breakout_fallback_pct : float;
  installed_stop_min_pct : float; [@sexp.default 0.0]
}
[@@deriving sexp]
(** Per-candidate price computation parameters. See {!Screener.candidate_params}
    for the meaning of each field. *)

type scored_candidate = {
  ticker : string;
  analysis : Stock_analysis.t;
  sector : sector_context;
  side : Trading_base.Types.position_side;
  grade : Weinstein_types.grade;
  score : int;
  suggested_entry : float;
  suggested_stop : float;
  risk_pct : float;
  swing_target : float option;
  rationale : string list;
}
(** A scored and graded candidate ready for the weekly report. See
    {!Screener.scored_candidate} for the meaning of each field. *)

val evaluate_longs :
  weights:scoring_weights ->
  thresholds:grade_thresholds ->
  params:candidate_params ->
  min_grade:Weinstein_types.grade ->
  min_score_override:int option ->
  max_score_override:int option ->
  volume_ratio_exclude_range:volume_ratio_band option ->
  min_price:float ->
  failed_breakout_tolerance_pct:float ->
  early_stage2_max_weeks:int ->
  min_rs_normalized:float ->
  max_buy_candidates:int ->
  longs_admitted:bool ->
  compare:(scored_candidate -> scored_candidate -> int) ->
  candidates:(Stock_analysis.t * sector_context) list ->
  scored_candidate list
(** Filter, score, grade, sort, and cap long candidates. [longs_admitted] is the
    caller's answer for the whole macro / breadth / index-stage gate, already
    evaluated; [false] returns [[]]. Otherwise each (analysis, sector) pair in
    [candidates] is dropped if excluded by the price floor, sector gate,
    breakout test, failed-breakout re-validation, relative-strength floor,
    volume band, or score floor; the survivors are sorted by [compare] and
    capped at [max_buy_candidates]. *)

val evaluate_shorts :
  weights:scoring_weights ->
  thresholds:grade_thresholds ->
  params:candidate_params ->
  min_grade:Weinstein_types.grade ->
  min_score_override:int option ->
  max_score_override:int option ->
  volume_ratio_exclude_range:volume_ratio_band option ->
  min_price:float ->
  max_short_candidates:int ->
  neutral_blocks_shorts:bool ->
  enable_slow_grind_short_gate:bool ->
  compare:(scored_candidate -> scored_candidate -> int) ->
  decline_is_slow_grind:bool ->
  candidates:(Stock_analysis.t * sector_context) list ->
  macro_trend:Weinstein_types.market_trend ->
  scored_candidate list
(** Filter, score, grade, sort, and cap short candidates.

    Two default-off gates tighten short admission toward Weinstein's
    confirmed-bear short rule:
    - [neutral_blocks_shorts]: when [true], a [Neutral] tape no longer admits
      shorts (see {!Screener_macro_gate.shorts_admitted_by_macro}).
    - [enable_slow_grind_short_gate]: when [true], shorts are admitted only when
      the current index decline is a slow grind ([decline_is_slow_grind]).
      [decline_is_slow_grind] is computed by the caller (the strategy lib, which
      owns the macro/decline-character classification) and passed in as a plain
      bool so this lib stays macro-agnostic. When the gate is [false] (default)
      the bool is ignored entirely — bit-identical to the prior behaviour. *)
