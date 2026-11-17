open Core
open Weinstein_types
open Screener_scoring
open Screener_admission
open Screener_macro_gate

type candidate_params = {
  entry_buffer_pct : float;
  initial_stop_pct : float;
  short_stop_pct : float;
  base_low_proxy_pct : float;
  breakout_fallback_pct : float;
  installed_stop_min_pct : float; [@sexp.default 0.0]
}
[@@deriving sexp]

type scored_candidate = {
  ticker : string;
  analysis : Stock_analysis.t;
  sector : sector_context;
  side : Trading_base.Types.position_side;
  grade : grade;
  score : int;
  suggested_entry : float;
  suggested_stop : float;
  risk_pct : float;
  swing_target : float option;
  rationale : string list;
}

let _build_candidate ~params ~sector ~(a : Stock_analysis.t) ~score ~reasons
    ~thresholds ~is_short : scored_candidate =
  let breakout =
    Option.value a.breakout_price
      ~default:(a.stage.ma_value *. (1.0 +. params.breakout_fallback_pct))
  in
  (* #3131: a short's default is the MA fallback mirrored below the MA, and its
     buffer goes downward (a sell-stop a little under the breakdown). *)
  let side_sign = if is_short then -1.0 else 1.0 in
  let default_anchor =
    if is_short then a.stage.ma_value *. (1.0 -. params.breakout_fallback_pct)
    else breakout
  in
  let entry_anchor =
    snd (Screener_entry_anchor.choose ~is_short a)
    |> Option.value ~default:default_anchor
  in
  let entry =
    suggested_entry
      ~entry_buffer_pct:(side_sign *. params.entry_buffer_pct)
      entry_anchor
  in
  let stop_ =
    if is_short then entry *. (1.0 +. params.short_stop_pct)
    else suggested_stop ~initial_stop_pct:params.initial_stop_pct entry
  in
  let risk_pct =
    if Float.(entry = 0.0) then 0.0 else Float.abs ((entry -. stop_) /. entry)
  in
  let base_low_val = base_low ~base_low_proxy_pct:params.base_low_proxy_pct a in
  let swing =
    if is_short then None else swing_target ~breakout ~base_low_opt:base_low_val
  in
  let side : Trading_base.Types.position_side =
    if is_short then Short else Long
  in
  {
    ticker = a.ticker;
    analysis = a;
    sector;
    side;
    grade = grade_of_score ~thresholds score;
    score;
    suggested_entry = entry;
    suggested_stop = stop_;
    risk_pct;
    swing_target = swing;
    rationale = reasons;
  }

(** Score, grade, and build a candidate after passing preliminary gates. Returns
    [None] if [score] does not pass {!Screener_admission.passes_score_floor}. *)
let _score_and_build ~weights ~thresholds ~params ~min_grade ~min_score_override
    ~max_score_override ~is_short ~scorer ~sector a =
  let score, reasons = scorer ~weights ~sector a in
  if
    not
      (passes_score_floor ~thresholds ~min_grade ~min_score_override
         ~max_score_override score)
  then None
  else
    Some
      (_build_candidate ~params ~sector ~a ~score ~reasons ~thresholds ~is_short)

(** Evaluate one (analysis, sector) pair as a long candidate. Returns [None] if
    excluded by the price floor, sector gate, breakout test, volume band, or
    score floor. *)
let _long_candidate ~weights ~thresholds ~params ~min_grade ~min_score_override
    ~max_score_override ~volume_ratio_exclude_range ~min_price
    ~failed_breakout_tolerance_pct ~early_stage2_max_weeks ~min_rs_normalized
    (a, sector) =
  if not (passes_price_floor ~min_price ~price:a.Stock_analysis.breakout_price)
  then None
  else if equal_sector_rating sector.rating Weak then None
  else if not (Stock_analysis.is_breakout_candidate ~early_stage2_max_weeks a)
  then None
  else if
    not
      (passes_failed_breakout ~tolerance_pct:failed_breakout_tolerance_pct
         ~breakout_price:a.Stock_analysis.breakout_price
         ~current_raw_close:a.Stock_analysis.current_raw_close)
  then None
  else if rs_blocks_long ~min_rs_normalized a.Stock_analysis.rs then None
  else if not (passes_volume_band ~excl:volume_ratio_exclude_range a) then None
  else
    _score_and_build ~weights ~thresholds ~params ~min_grade ~min_score_override
      ~max_score_override ~is_short:false
      ~scorer:(score_long ~early_stage2_max_weeks)
      ~sector a

(** Evaluate one (analysis, sector) pair as a short candidate. Bearish/Neutral
    only: score must pass {!Screener_admission.passes_score_floor}. *)
let _short_candidate ~weights ~thresholds ~params ~min_grade ~min_score_override
    ~max_score_override ~volume_ratio_exclude_range ~min_price (a, sector) =
  if not (passes_price_floor ~min_price ~price:a.Stock_analysis.breakdown_price)
  then None
  else if equal_sector_rating sector.rating Strong then None
  else if not (Stock_analysis.is_breakdown_candidate a) then None
  else if rs_blocks_short a.Stock_analysis.rs then None
  else if not (passes_volume_band ~excl:volume_ratio_exclude_range a) then None
  else
    _score_and_build ~weights ~thresholds ~params ~min_grade ~min_score_override
      ~max_score_override ~is_short:true ~scorer:score_short ~sector a

let evaluate_longs ~weights ~thresholds ~params ~min_grade ~min_score_override
    ~max_score_override ~volume_ratio_exclude_range ~min_price
    ~failed_breakout_tolerance_pct ~early_stage2_max_weeks ~min_rs_normalized
    ~max_buy_candidates ~longs_admitted ~compare ~candidates :
    scored_candidate list =
  if not longs_admitted then []
  else
    let candidate_fn =
      _long_candidate ~weights ~thresholds ~params ~min_grade
        ~min_score_override ~max_score_override ~volume_ratio_exclude_range
        ~min_price ~failed_breakout_tolerance_pct ~early_stage2_max_weeks
        ~min_rs_normalized
    in
    Screener_ranking.filter_and_cap ~compare ~candidate_fn
      ~max_n:max_buy_candidates candidates

let evaluate_shorts ~weights ~thresholds ~params ~min_grade ~min_score_override
    ~max_score_override ~volume_ratio_exclude_range ~min_price
    ~max_short_candidates ~neutral_blocks_shorts ~enable_slow_grind_short_gate
    ~compare ~decline_is_slow_grind ~candidates ~macro_trend :
    scored_candidate list =
  let macro_admits =
    shorts_admitted_by_macro ~neutral_blocks_shorts macro_trend
  in
  let slow_grind_admits =
    (not enable_slow_grind_short_gate) || decline_is_slow_grind
  in
  if not (macro_admits && slow_grind_admits) then []
  else
    let candidate_fn =
      _short_candidate ~weights ~thresholds ~params ~min_grade
        ~min_score_override ~max_score_override ~volume_ratio_exclude_range
        ~min_price
    in
    Screener_ranking.filter_and_cap ~compare ~candidate_fn
      ~max_n:max_short_candidates candidates
