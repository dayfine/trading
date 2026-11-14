open Core
open Friday_trace_format
module P = Friday_trace
module Audit_recorder = Weinstein_strategy.Audit_recorder

(* ------------------------------------------------------------------ *)
(* Stage 6: scoring                                                     *)
(* ------------------------------------------------------------------ *)

let _scored (d : Audit_recorder.cascade_drop) =
  match d.outcome.phase with
  | Dropped_at_grade | Dropped_at_top_n | Admitted -> true
  | Dropped_at_macro | Dropped_at_breakout _ | Dropped_at_sector | Dropped_at_rs
    ->
      false

let _components (sc : Screener.config) (d : Audit_recorder.cascade_drop) =
  match d.side with
  | Long ->
      Screener.long_score_components
        ~early_stage2_max_weeks:sc.early_stage2_max_weeks ~weights:sc.weights
        ~sector:d.sector d.analysis
  | Short ->
      Screener.short_score_components ~weights:sc.weights ~sector:d.sector
        d.analysis

let _grade_scale (sc : Screener.config) =
  let g = sc.grade_thresholds in
  sprintf
    "A+ >= %d, A >= %d, B >= %d, C >= %d, D >= %d. The lowest grade bought is \
     %s."
    g.a_plus g.a g.b g.c g.d
    (Weinstein_types.grade_to_string sc.min_grade)

let _stage6 buf (t : P.t) =
  let sc = t.setup.config.screening_config in
  header buf ~n:6 ~title:"SCORING"
    ~does:
      [
        "adds up points for each signal a breakout carries. The total maps to \
         a grade:";
        _grade_scale sc;
      ]
    ~input:"the stocks that passed the breakout gates."
    ~output:"a score and a grade per stock; a grade below the lowest stops it.";
  List.iter (List.filter t.cascade ~f:_scored) ~f:(fun d ->
      row buf "%-12s score %d, grade %s%s" d.outcome.ticker d.outcome.score
        (Weinstein_types.grade_to_string d.outcome.grade)
        (match d.outcome.phase with
        | Dropped_at_grade -> ": below the lowest grade, stops here"
        | _ -> "");
      List.iter (_components sc d) ~f:(fun (label, points) ->
          row buf "%-12s %+4d  %s" "" points label))

(* ------------------------------------------------------------------ *)
(* Stage 7: ranking                                                     *)
(* ------------------------------------------------------------------ *)

let _tiebreak_text (sc : Screener.config) ~date =
  match sc.candidate_ranking with
  | Seeded | Price_band_seeded ->
      sprintf "a seeded hash of the ticker (seed %d, date %s), smallest first"
        sc.tiebreak_seed (Date.to_string date)
  | other ->
      sprintf "the %s rule"
        (Sexp.to_string (Screener.sexp_of_candidate_ranking other))

let _same_side (a : P.ranked_row) (b : P.ranked_row) =
  Trading_base.Types.equal_position_side a.side b.side

let _cap (sc : Screener.config) : Trading_base.Types.position_side -> int =
  function
  | Long -> sc.max_buy_candidates
  | Short -> sc.max_short_candidates

(* One ranked row, numbered within its side, with the cut line drawn where the
   side's admitted names end. *)
let _ranking_row buf sc ~rows i (r : P.ranked_row) =
  let before = List.take rows i in
  (match List.last before with
  | Some p when _same_side p r && p.above_cut && not r.above_cut ->
      row buf "----- cut: only the top %d %s names go on -----" (_cap sc r.side)
        (side_name r.side)
  | _ -> ());
  row buf "%3d  %-12s %-5s %5d  %-5s  %s"
    (List.count before ~f:(_same_side r) + 1)
    r.ticker (side_name r.side) r.score
    (Weinstein_types.grade_to_string r.grade)
    (opt Int.to_string r.tiebreak_key)

let _stage7 buf (t : P.t) =
  let sc = t.setup.config.screening_config in
  header buf ~n:7 ~title:"RANKING"
    ~does:
      [
        "orders the graded stocks by score, highest first. Equal scores go by";
        _tiebreak_text sc ~date:t.setup.date ^ ".";
        sprintf "Only the top %d (max_buy_candidates) go on to the entry walk."
          sc.max_buy_candidates;
      ]
    ~input:"the graded stocks." ~output:"the ranked list, and the cut.";
  row buf "%3s  %-12s %-5s %5s  %-5s  %s" "#" "ticker" "side" "score" "grade"
    "tiebreak key";
  List.iteri t.ranking ~f:(_ranking_row buf sc ~rows:t.ranking)

(* ------------------------------------------------------------------ *)
(* Stage 8: entry walk                                                  *)
(* ------------------------------------------------------------------ *)

let _floor_text : Audit_recorder.stop_floor_kind -> string = function
  | Support_floor -> "under the last correction low"
  | Buffer_fallback -> "fallback: no correction low found"

let _skip_text ~max_pct : Audit_recorder.skip_reason -> string = function
  | Stop_too_wide -> sprintf "stop more than %s below the trigger" (pct max_pct)
  | No_structural_stop _ -> "no correction low to put the stop under"
  | Insufficient_cash -> "not enough cash left"
  | Already_held -> "already held"
  | Sized_to_zero -> "sized to zero shares"
  | Short_notional_cap -> "short exposure cap"
  | Sector_exposure_cap -> "sector exposure cap"
  | Long_exposure_cap -> "long exposure cap"
  | Share_class_held -> "another share class is held"

let _gate_line buf (w : P.walk_row) =
  match w.gate with
  | None -> row buf "%-12s no stop measurable" w.candidate.ticker
  | Some g ->
      row buf "%-12s trigger %.2f, stop %.2f (%s), %s below" w.candidate.ticker
        g.entry g.stop (_floor_text g.floor_kind) (pct g.distance_pct)

let _outcome_line buf ~budget ~max_pct (w : P.walk_row) =
  match (w.outcome, w.entry) with
  | Placed, Some e ->
      row buf "%-12s PLACED %d shares: risk %s of the %s budget, cost %s" ""
        e.shares
        (money e.initial_risk_dollars)
        (money budget)
        (money (w.cash_before -. w.cash_after));
      row buf "%-12s cash %s -> %s" "" (money w.cash_before)
        (money w.cash_after)
  | Placed, None -> row buf "%-12s PLACED" ""
  | Skipped reason, _ ->
      row buf "%-12s SKIPPED: %s. Cash unchanged." ""
        (_skip_text ~max_pct reason)

let _walk_row buf ~budget ~max_pct (w : P.walk_row) =
  _gate_line buf w;
  _outcome_line buf ~budget ~max_pct w

let _trigger_basis (c : Weinstein_strategy.Weinstein_strategy_config.config) =
  if c.sim_entry_trigger_at_suggested && c.enable_sim_entry_stoplimit then
    "the breakout level"
  else "the last close"

let _fallback_rule (c : Weinstein_strategy.Weinstein_strategy_config.config) =
  if c.require_structural_stop then
    ", and so is a fallback stop (investor preset)."
  else "."

let _walk_rules (c : Weinstein_strategy.Weinstein_strategy_config.config) =
  [
    sprintf "takes the names above the cut in rank order. The trigger is %s."
      (_trigger_basis c);
    sprintf
      "The initial stop goes just under the low of the last pullback of %s or"
      (pct c.stops_config.min_correction_pct);
    sprintf
      "more; with no such pullback it is a fallback stop. A stop over %s below"
      (pct c.stops_config.max_stop_distance_pct);
    "the trigger is skipped (book 5.1)" ^ _fallback_rule c;
    sprintf "Shares: %s of the portfolio at risk to the stop, within cash."
      (pct c.portfolio_config.risk_per_trade_pct);
  ]

let _stage8 buf (t : P.t) =
  let c = t.setup.config in
  let max_pct = c.stops_config.max_stop_distance_pct in
  let budget =
    t.setup.portfolio_value *. c.portfolio_config.risk_per_trade_pct
  in
  header buf ~n:8 ~title:"ENTRY WALK" ~does:(_walk_rules c)
    ~input:
      (sprintf "the names above the cut, and %s cash." (money t.setup.cash))
    ~output:"an entry ticket, or the reason for skipping, per name.";
  List.iter t.walk ~f:(_walk_row buf ~budget ~max_pct)

(* ------------------------------------------------------------------ *)
(* Stage 9: orders                                                      *)
(* ------------------------------------------------------------------ *)

let _stage9 buf (t : P.t) =
  header buf ~n:9 ~title:"ORDERS"
    ~does:
      [
        "the day's output: one stop-entry ticket per placed name, for its \
         shares at";
        "its trigger, with the initial stop the position starts under once \
         filled.";
      ]
    ~input:"the placed names."
    ~output:"the tickets, worked from the next session.";
  row buf "%-12s %-5s %7s %9s %13s" "symbol" "side" "shares" "trigger"
    "initial stop";
  List.iter t.orders ~f:(fun (o : P.order) ->
      row buf "%-12s %-5s %7.0f %9.2f %13s" o.symbol (side_name o.side)
        o.quantity o.trigger
        (opt (sprintf "%.2f") o.stop));
  if List.is_empty t.orders then row buf "(none)"

let render buf (t : P.t) =
  _stage6 buf t;
  _stage7 buf t;
  _stage8 buf t;
  _stage9 buf t
