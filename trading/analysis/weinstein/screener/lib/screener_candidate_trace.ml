open Core
open Screener_scoring
open Screener_admission

type cascade_phase =
  | Admitted
  | Dropped_at_macro
  | Dropped_at_breakout of breakout_gate
  | Dropped_at_sector
  | Dropped_at_rs
  | Dropped_at_grade
  | Dropped_at_top_n
[@@deriving sexp, eq, show]

type candidate_outcome = {
  ticker : string;
  phase : cascade_phase;
  score : int;
  grade : Weinstein_types.grade;
}
[@@deriving sexp, eq]

(* Resolve a phase from the monotone gate flags, innermost first. [in_top_n]
   only decides between the last two, because a candidate that failed an
   earlier gate never reached the cap. The breakout slot carries the failing
   sub-gate rather than a bare [false], so [Dropped_at_breakout] can never be
   constructed without naming which dial produced it. *)
let _phase_of_gates ~gates ~in_top_n =
  match gates with
  | `Macro_blocked -> Dropped_at_macro
  | `Gates (Some gate, _, _, _) -> Dropped_at_breakout gate
  | `Gates (None, false, _, _) -> Dropped_at_sector
  | `Gates (None, _, false, _) -> Dropped_at_rs
  | `Gates (None, _, _, false) -> Dropped_at_grade
  | `Gates (None, true, true, true) ->
      if in_top_n then Admitted else Dropped_at_top_n

let _outcome_of ~gates ~top_n_tickers ~score ~thresholds ticker =
  {
    ticker;
    phase = _phase_of_gates ~gates ~in_top_n:(Set.mem top_n_tickers ticker);
    score;
    grade = grade_of_score ~thresholds score;
  }

let long_outcomes ~weights ~thresholds ~min_grade ~min_score_override
    ~max_score_override ~volume_ratio_exclude_range ~min_price
    ~failed_breakout_tolerance_pct ~early_stage2_max_weeks ~min_rs_normalized
    ~macro_admits ~top_n_tickers ~candidates =
  let admit =
    long_admission ~weights ~thresholds ~min_grade ~min_score_override
      ~max_score_override ~volume_ratio_exclude_range ~min_price
      ~failed_breakout_tolerance_pct ~early_stage2_max_weeks ~min_rs_normalized
  in
  List.map candidates ~f:(fun ((a : Stock_analysis.t), sector) ->
      (* The long triple folds RS into grade, so the RS slot is always [true]
         here — [Dropped_at_rs] is short-side-only, per the .mli. *)
      let gates =
        if not macro_admits then `Macro_blocked
        else
          let gate, ps, pg = admit (a, sector) in
          `Gates (gate, ps, true, pg)
      in
      let score, _ = score_long ~early_stage2_max_weeks ~weights ~sector a in
      _outcome_of ~gates ~top_n_tickers ~score ~thresholds a.ticker)

let short_outcomes ~weights ~thresholds ~min_grade ~min_score_override
    ~max_score_override ~volume_ratio_exclude_range ~min_price ~macro_admits
    ~top_n_tickers ~candidates =
  let admit =
    short_admission ~weights ~thresholds ~min_grade ~min_score_override
      ~max_score_override ~volume_ratio_exclude_range ~min_price
  in
  List.map candidates ~f:(fun ((a : Stock_analysis.t), sector) ->
      let gates =
        if not macro_admits then `Macro_blocked
        else
          let gate, ps, pr, pg = admit (a, sector) in
          `Gates (gate, ps, pr, pg)
      in
      let score, _ = score_short ~weights ~sector a in
      _outcome_of ~gates ~top_n_tickers ~score ~thresholds a.ticker)
