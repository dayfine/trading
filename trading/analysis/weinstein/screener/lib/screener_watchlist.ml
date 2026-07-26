open Core
open Weinstein_types
open Screener_scoring
open Screener_admission

(** Grade-based watchlist entry: a near-miss (C/D) breakout candidate. Anything
    stronger belongs in the buy list, anything weaker is not worth watching. *)
let _grade_entry ~thresholds ~score (sa : Stock_analysis.t) =
  let grade = grade_of_score ~thresholds score in
  if equal_grade grade C || equal_grade grade D then
    Some
      ( sa.ticker,
        Printf.sprintf "Grade %s, score %d" (grade_to_string grade) score )
  else None

let entry ~weights ~thresholds ~early_stage2_max_weeks
    ~failed_breakout_tolerance_pct ~buy_tickers ((sa : Stock_analysis.t), sector)
    =
  if not (Stock_analysis.is_breakout_candidate ~early_stage2_max_weeks sa) then
    None
  else if Set.mem buy_tickers sa.ticker then None
  else
    (* A failed breakout is demoted, not silently dropped: it lands on the
       watchlist carrying its own drop reason so the weekly report shows why a
       would-be buy disappeared. *)
    match
      failed_breakout_reason ~tolerance_pct:failed_breakout_tolerance_pct
        ~breakout_price:sa.breakout_price ~current_close:sa.current_close
    with
    | Some reason -> Some (sa.ticker, reason)
    | None ->
        let score, _ = score_long ~early_stage2_max_weeks ~weights ~sector sa in
        _grade_entry ~thresholds ~score sa

let build ~weights ~thresholds ~early_stage2_max_weeks
    ~failed_breakout_tolerance_pct ~candidates ~buy_tickers ~buys_active =
  if not buys_active then []
  else
    List.filter_map candidates
      ~f:
        (entry ~weights ~thresholds ~early_stage2_max_weeks
           ~failed_breakout_tolerance_pct ~buy_tickers)
