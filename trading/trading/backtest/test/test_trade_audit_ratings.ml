(** Unit tests for [Trade_audit_ratings].

    Coverage:
    - Per-trade rating fields (R-multiple, MFE/MAE, hold-time anomaly)
    - Each Weinstein rule R1-R8: pass / fail / marginal / N/A edge cases
    - [score_of_rules] excludes N/A from numerator and denominator
    - 4 behavioural metrics each produce expected counts + outliers
    - Cascade-quartile vs outcome matrix bucketing
    - Markdown formatters surface the expected section headers / rows *)

open OUnit2
open Core
open Matchers
module TR = Trade_audit_report.Trade_audit_ratings
module TA = Backtest.Trade_audit
module WT = Weinstein_types

(* Builders --------------------------------------------------------------- *)

let _date d = Date.of_string d

let make_entry ?(symbol = "AAPL") ?(entry_date = _date "2024-01-15")
    ?(position_id = "AAPL-1") ?(side = Trading_base.Types.Long)
    ?(macro_trend = WT.Bullish)
    ?(stage = WT.Stage2 { weeks_advancing = 4; late = false })
    ?(ma_direction = WT.Rising) ?(rs_trend = Some WT.Positive_rising)
    ?(volume_quality = Some (WT.Strong 2.4)) ?(cascade_score = 75)
    ?(cascade_grade = WT.A) ?(initial_risk_dollars = 1_000.0) () :
    TA.entry_decision =
  {
    symbol;
    entry_date;
    position_id;
    macro_trend;
    macro_confidence = 0.72;
    macro_indicators = [];
    stage;
    ma_direction;
    ma_slope_pct = 0.018;
    rs_trend;
    rs_value = Some 1.05;
    volume_quality;
    resistance_quality = Some WT.Clean;
    support_quality = Some WT.Clean;
    sector_name = "Information Technology";
    sector_rating = Screener.Strong;
    cascade_score;
    cascade_grade;
    cascade_score_components = [];
    cascade_rationale = [];
    side;
    suggested_entry = 100.0;
    suggested_stop = 90.0;
    installed_stop = 90.0;
    stop_floor_kind = TA.Buffer_fallback;
    risk_pct = 0.08;
    initial_position_value = 10_000.0;
    initial_risk_dollars;
    alternatives_considered = [];
  }

let make_exit ?(symbol = "AAPL") ?(exit_date = _date "2024-04-20")
    ?(position_id = "AAPL-1")
    ?(exit_trigger =
      Backtest.Stop_log.Stop_loss { stop_price = 90.0; actual_price = 89.0 })
    ?(macro_trend_at_exit = WT.Bullish)
    ?(stage_at_exit = WT.Stage2 { weeks_advancing = 12; late = false })
    ?(rs_trend_at_exit = Some WT.Positive_rising)
    ?(max_favorable_excursion_pct = 0.10) ?(max_adverse_excursion_pct = -0.05)
    ?(weeks_macro_was_bearish = 0) ?(weeks_stage_left_2 = 0) () :
    TA.exit_decision =
  {
    symbol;
    exit_date;
    position_id;
    exit_trigger;
    macro_trend_at_exit;
    macro_confidence_at_exit = 0.45;
    stage_at_exit;
    rs_trend_at_exit;
    distance_from_ma_pct = -0.025;
    max_favorable_excursion_pct;
    max_adverse_excursion_pct;
    weeks_macro_was_bearish;
    weeks_stage_left_2;
  }

let make_record ?(exit_ = Some (make_exit ())) entry : TA.audit_record =
  { entry; exit_ }

let make_trade ?(symbol = "AAPL") ?(side = Trading_base.Types.Buy)
    ?(entry_date = _date "2024-01-15") ?(exit_date = _date "2024-04-20")
    ?(days_held = 96) ?(entry_price = 100.0) ?(exit_price = 95.0)
    ?(quantity = 100.0) ?(pnl_dollars = -500.0) ?(pnl_percent = -5.0) () :
    Trading_simulation.Metrics.trade_metrics =
  {
    symbol;
    side;
    entry_date;
    exit_date;
    days_held;
    entry_price;
    exit_price;
    quantity;
    pnl_dollars;
    pnl_percent;
  }

let cfg = TR.default_config

let outcome_of_rule_id evals (rid : TR.rule_id) =
  List.find_exn evals ~f:(fun (e : TR.rule_evaluation) ->
      TR.equal_rule_id e.rule rid)
  |> fun e -> e.outcome

(* -- R1 long above 30w MA flat-or-rising --------------------------------- *)

let test_r1_pass_long_stage2_ma_rising _ =
  let entry =
    make_entry
      ~stage:(WT.Stage2 { weeks_advancing = 4; late = false })
      ~ma_direction:WT.Rising ()
  in
  let evals = TR.evaluate_rules ~config:cfg (make_record entry) in
  assert_that
    (outcome_of_rule_id evals TR.R1_long_above_30w_ma_flat_or_rising)
    (equal_to TR.Pass)

let test_r1_fail_long_ma_declining _ =
  let entry = make_entry ~ma_direction:WT.Declining () in
  let evals = TR.evaluate_rules ~config:cfg (make_record entry) in
  assert_that
    (outcome_of_rule_id evals TR.R1_long_above_30w_ma_flat_or_rising)
    (equal_to TR.Fail)

let test_r1_na_for_short _ =
  let entry =
    make_entry ~side:Trading_base.Types.Short
      ~stage:(WT.Stage4 { weeks_declining = 4 })
      ~ma_direction:WT.Declining ()
  in
  let evals = TR.evaluate_rules ~config:cfg (make_record entry) in
  assert_that
    (outcome_of_rule_id evals TR.R1_long_above_30w_ma_flat_or_rising)
    (equal_to TR.Not_applicable)

(* -- R2 long breakout volume 2x ------------------------------------------ *)

let test_r2_pass_volume_2x _ =
  let entry = make_entry ~volume_quality:(Some (WT.Strong 2.5)) () in
  let evals = TR.evaluate_rules ~config:cfg (make_record entry) in
  assert_that
    (outcome_of_rule_id evals TR.R2_long_breakout_volume_2x)
    (equal_to TR.Pass)

let test_r2_marginal_adequate_volume _ =
  let entry = make_entry ~volume_quality:(Some (WT.Adequate 1.7)) () in
  let evals = TR.evaluate_rules ~config:cfg (make_record entry) in
  assert_that
    (outcome_of_rule_id evals TR.R2_long_breakout_volume_2x)
    (equal_to TR.Marginal)

let test_r2_fail_weak_volume _ =
  let entry = make_entry ~volume_quality:(Some (WT.Weak 1.1)) () in
  let evals = TR.evaluate_rules ~config:cfg (make_record entry) in
  assert_that
    (outcome_of_rule_id evals TR.R2_long_breakout_volume_2x)
    (equal_to TR.Fail)

(* -- R3 critical: never long in Stage 4 ---------------------------------- *)

let test_r3_critical_fail_long_stage_4 _ =
  let entry =
    make_entry
      ~stage:(WT.Stage4 { weeks_declining = 6 })
      ~ma_direction:WT.Declining ()
  in
  let evals = TR.evaluate_rules ~config:cfg (make_record entry) in
  assert_that
    (outcome_of_rule_id evals TR.R3_no_long_in_stage_4)
    (equal_to TR.Fail)

let test_r3_pass_long_stage_2 _ =
  let evals = TR.evaluate_rules ~config:cfg (make_record (make_entry ())) in
  assert_that
    (outcome_of_rule_id evals TR.R3_no_long_in_stage_4)
    (equal_to TR.Pass)

(* -- R4 short below 30w MA flat-or-falling ------------------------------- *)

let test_r4_pass_short_ma_declining _ =
  let entry =
    make_entry ~side:Trading_base.Types.Short
      ~stage:(WT.Stage4 { weeks_declining = 6 })
      ~ma_direction:WT.Declining ()
  in
  let evals = TR.evaluate_rules ~config:cfg (make_record entry) in
  assert_that
    (outcome_of_rule_id evals TR.R4_short_below_30w_ma_flat_or_falling)
    (equal_to TR.Pass)

let test_r4_fail_short_ma_rising _ =
  let entry =
    make_entry ~side:Trading_base.Types.Short ~ma_direction:WT.Rising ()
  in
  let evals = TR.evaluate_rules ~config:cfg (make_record entry) in
  assert_that
    (outcome_of_rule_id evals TR.R4_short_below_30w_ma_flat_or_falling)
    (equal_to TR.Fail)

(* -- R5 short Stage 4 breakdown ------------------------------------------ *)

let test_r5_pass_short_stage_4 _ =
  let entry =
    make_entry ~side:Trading_base.Types.Short
      ~stage:(WT.Stage4 { weeks_declining = 6 })
      ~ma_direction:WT.Declining ()
  in
  let evals = TR.evaluate_rules ~config:cfg (make_record entry) in
  assert_that
    (outcome_of_rule_id evals TR.R5_short_stage_4_breakdown)
    (equal_to TR.Pass)

let test_r5_fail_short_not_stage_4 _ =
  let entry =
    make_entry ~side:Trading_base.Types.Short
      ~stage:(WT.Stage3 { weeks_topping = 4 })
      ~ma_direction:WT.Flat ()
  in
  let evals = TR.evaluate_rules ~config:cfg (make_record entry) in
  assert_that
    (outcome_of_rule_id evals TR.R5_short_stage_4_breakdown)
    (equal_to TR.Fail)

(* -- R6 documented gap (NA until pre-entry bar history is wired) --------- *)

let test_r6_na _ =
  let evals = TR.evaluate_rules ~config:cfg (make_record (make_entry ())) in
  assert_that
    (outcome_of_rule_id evals TR.R6_no_recent_plunge)
    (equal_to TR.Not_applicable)

(* -- R7 stop discipline on Stage3 -> Stage4 transition ------------------- *)

let test_r7_pass_long_exit_in_stage_4_via_stop _ =
  let exit_ =
    make_exit
      ~stage_at_exit:(WT.Stage4 { weeks_declining = 4 })
      ~exit_trigger:
        (Backtest.Stop_log.Stop_loss { stop_price = 90.0; actual_price = 89.0 })
      ()
  in
  let evals =
    TR.evaluate_rules ~config:cfg
      (make_record ~exit_:(Some exit_) (make_entry ()))
  in
  assert_that
    (outcome_of_rule_id evals TR.R7_exit_on_stage_3_to_4)
    (equal_to TR.Pass)

let test_r7_fail_held_through_stage_4_via_time _ =
  let exit_ =
    make_exit
      ~stage_at_exit:(WT.Stage4 { weeks_declining = 8 })
      ~exit_trigger:
        (Backtest.Stop_log.Time_expired { days_held = 365; max_days = 365 })
      ()
  in
  let evals =
    TR.evaluate_rules ~config:cfg
      (make_record ~exit_:(Some exit_) (make_entry ()))
  in
  assert_that
    (outcome_of_rule_id evals TR.R7_exit_on_stage_3_to_4)
    (equal_to TR.Fail)

let test_r7_na_when_position_open _ =
  let evals =
    TR.evaluate_rules ~config:cfg (make_record ~exit_:None (make_entry ()))
  in
  assert_that
    (outcome_of_rule_id evals TR.R7_exit_on_stage_3_to_4)
    (equal_to TR.Not_applicable)

(* -- R8 macro alignment -------------------------------------------------- *)

let test_r8_pass_long_macro_bullish _ =
  let evals = TR.evaluate_rules ~config:cfg (make_record (make_entry ())) in
  assert_that
    (outcome_of_rule_id evals TR.R8_macro_alignment)
    (equal_to TR.Pass)

let test_r8_fail_long_macro_bearish _ =
  let entry = make_entry ~macro_trend:WT.Bearish () in
  let evals = TR.evaluate_rules ~config:cfg (make_record entry) in
  assert_that
    (outcome_of_rule_id evals TR.R8_macro_alignment)
    (equal_to TR.Fail)

let test_r8_marginal_long_macro_neutral _ =
  let entry = make_entry ~macro_trend:WT.Neutral () in
  let evals = TR.evaluate_rules ~config:cfg (make_record entry) in
  assert_that
    (outcome_of_rule_id evals TR.R8_macro_alignment)
    (equal_to TR.Marginal)

(* -- score_of_rules excludes N/A ----------------------------------------- *)

let test_score_excludes_na _ =
  (* A long Stage2 trade scores Pass on R1, R2 (Strong 2.4), R3, R8;
     N/A on R4, R5, R6, R7 (we'll use exit:None to make R7 N/A). *)
  let entry = make_entry ~volume_quality:(Some (WT.Strong 2.5)) () in
  let evals = TR.evaluate_rules ~config:cfg (make_record ~exit_:None entry) in
  let score = TR.score_of_rules evals in
  assert_that score (float_equal ~epsilon:1e-9 1.0)

let test_score_marginal_counts_half _ =
  (* All same as above, but volume Marginal -> 0.5 contribution; total
     applicable = 4 (R1, R2, R3, R8); 3 Pass + 0.5 Marginal = 3.5 / 4. *)
  let entry = make_entry ~volume_quality:(Some (WT.Adequate 1.7)) () in
  let evals = TR.evaluate_rules ~config:cfg (make_record ~exit_:None entry) in
  let score = TR.score_of_rules evals in
  assert_that score (float_equal ~epsilon:1e-9 (3.5 /. 4.0))

(* -- Per-trade rating ---------------------------------------------------- *)

let test_rate_r_multiple _ =
  let entry = make_entry ~initial_risk_dollars:1_000.0 () in
  let trade = make_trade ~pnl_dollars:2_500.0 () in
  let rating = TR.rate ~config:cfg (make_record entry) trade in
  assert_that rating
    (all_of
       [
         field (fun (r : TR.rating) -> r.symbol) (equal_to "AAPL");
         field
           (fun (r : TR.rating) -> r.r_multiple)
           (float_equal ~epsilon:1e-9 2.5);
         field (fun (r : TR.rating) -> r.outcome) (equal_to TR.Win);
       ])

let test_rate_r_multiple_negative _ =
  let entry = make_entry ~initial_risk_dollars:1_000.0 () in
  let trade = make_trade ~pnl_dollars:(-1_500.0) () in
  let rating = TR.rate ~config:cfg (make_record entry) trade in
  assert_that rating
    (all_of
       [
         field
           (fun (r : TR.rating) -> r.r_multiple)
           (float_equal ~epsilon:1e-9 (-1.5));
         field (fun (r : TR.rating) -> r.outcome) (equal_to TR.Loss);
       ])

let test_rate_hold_time_anomaly_immediate _ =
  let trade = make_trade ~days_held:2 () in
  let rating = TR.rate ~config:cfg (make_record (make_entry ())) trade in
  assert_that rating.hold_time_anomaly (equal_to TR.Stopped_immediately)

let test_rate_hold_time_anomaly_indefinite _ =
  let trade = make_trade ~days_held:400 () in
  let rating = TR.rate ~config:cfg (make_record (make_entry ())) trade in
  assert_that rating.hold_time_anomaly (equal_to TR.Held_indefinitely)

let test_rate_mfe_mae_threaded _ =
  let exit_ =
    make_exit ~max_favorable_excursion_pct:0.25
      ~max_adverse_excursion_pct:(-0.08) ()
  in
  let rating =
    TR.rate ~config:cfg
      (make_record ~exit_:(Some exit_) (make_entry ()))
      (make_trade ())
  in
  assert_that rating
    (all_of
       [
         field
           (fun (r : TR.rating) -> r.mfe_pct)
           (float_equal ~epsilon:1e-9 0.25);
         field
           (fun (r : TR.rating) -> r.mae_pct)
           (float_equal ~epsilon:1e-9 (-0.08));
       ])

(* -- Behavioural metric (a) — over-trading ------------------------------- *)

let test_over_trading_burst_detection _ =
  (* Two AAPL trades 10 days apart → both flagged as in-burst; one MSFT
     standalone → not flagged. *)
  let aapl_a =
    make_record (make_entry ~symbol:"AAPL" ~entry_date:(_date "2024-01-01") ())
  in
  let aapl_b =
    make_record
      (make_entry ~symbol:"AAPL" ~entry_date:(_date "2024-01-11")
         ~position_id:"AAPL-2" ())
  in
  let msft =
    make_record
      (make_entry ~symbol:"MSFT" ~entry_date:(_date "2024-06-01")
         ~position_id:"MSFT-1" ())
  in
  let trades =
    [
      make_trade ~symbol:"AAPL" ~entry_date:(_date "2024-01-01")
        ~exit_date:(_date "2024-02-01") ();
      make_trade ~symbol:"AAPL" ~entry_date:(_date "2024-01-11")
        ~exit_date:(_date "2024-03-01") ();
      make_trade ~symbol:"MSFT" ~entry_date:(_date "2024-06-01")
        ~exit_date:(_date "2024-09-01") ();
    ]
  in
  let audit = [ aapl_a; aapl_b; msft ] in
  let ratings = TR.rate_all ~config:cfg ~audit ~trades in
  let m = TR.behavioral_metrics_of ~config:cfg ~ratings ~audit ~trades in
  assert_that m.over_trading
    (all_of
       [
         field (fun (m : TR.over_trading) -> m.total_trades) (equal_to 3);
         field
           (fun (m : TR.over_trading) -> List.length m.outliers)
           (equal_to 2);
         field
           (fun (m : TR.over_trading) -> m.concentrated_burst_pct)
           (float_equal ~epsilon:1e-9 (200.0 /. 3.0));
       ])

(* -- Behavioural metric (b) — exit winners too early --------------------- *)

let test_exit_winners_flagged_when_realized_below_half_mfe _ =
  let entry = make_entry ~initial_risk_dollars:1_000.0 () in
  let exit_ =
    make_exit ~max_favorable_excursion_pct:0.30
      ~max_adverse_excursion_pct:(-0.02) ()
  in
  (* realized 5% < 50% × 30% = 15% → flagged. *)
  let trade = make_trade ~pnl_dollars:500.0 ~pnl_percent:5.0 () in
  let record = make_record ~exit_:(Some exit_) entry in
  let ratings = TR.rate_all ~config:cfg ~audit:[ record ] ~trades:[ trade ] in
  let m =
    TR.behavioral_metrics_of ~config:cfg ~ratings ~audit:[ record ]
      ~trades:[ trade ]
  in
  assert_that m.exit_winners_too_early
    (all_of
       [
         field
           (fun (e : TR.exit_winners_too_early) -> e.winners_evaluated)
           (equal_to 1);
         field
           (fun (e : TR.exit_winners_too_early) -> e.flagged_count)
           (equal_to 1);
       ])

(* -- Behavioural metric (c) — exit losers too late ----------------------- *)

let test_exit_losers_flagged_when_r_multiple_exceeds_threshold _ =
  let entry = make_entry ~initial_risk_dollars:1_000.0 () in
  let exit_ =
    make_exit
      ~exit_trigger:
        (Backtest.Stop_log.Stop_loss { stop_price = 90.0; actual_price = 89.0 })
      ~max_favorable_excursion_pct:0.05 ~max_adverse_excursion_pct:(-0.20) ()
  in
  (* R = -2.0 > 1.5 threshold → flagged. *)
  let trade = make_trade ~pnl_dollars:(-2_000.0) ~pnl_percent:(-20.0) () in
  let record = make_record ~exit_:(Some exit_) entry in
  let ratings = TR.rate_all ~config:cfg ~audit:[ record ] ~trades:[ trade ] in
  let m =
    TR.behavioral_metrics_of ~config:cfg ~ratings ~audit:[ record ]
      ~trades:[ trade ]
  in
  assert_that m.exit_losers_too_late
    (all_of
       [
         field
           (fun (l : TR.exit_losers_too_late) -> l.losers_evaluated)
           (equal_to 1);
         field
           (fun (l : TR.exit_losers_too_late) -> l.flagged_count)
           (equal_to 1);
         field
           (fun (l : TR.exit_losers_too_late) -> l.stop_discipline_pct)
           (float_equal ~epsilon:1e-9 0.0);
       ])

let test_exit_losers_stop_discipline_pct _ =
  (* 1 disciplined loser (R=-0.8) + 1 undisciplined (R=-2.0) → 50%. *)
  let make_loser ~symbol ~r ~entry_date =
    let entry =
      make_entry ~symbol ~entry_date ~initial_risk_dollars:1_000.0 ()
    in
    let trade =
      make_trade ~symbol ~entry_date ~pnl_dollars:(-1_000.0 *. r)
        ~pnl_percent:(-10.0 *. r) ()
    in
    let exit_ =
      make_exit ~max_favorable_excursion_pct:0.02
        ~max_adverse_excursion_pct:(-0.10) ()
    in
    (make_record ~exit_:(Some exit_) entry, trade)
  in
  let r1, t1 =
    make_loser ~symbol:"DISC" ~r:0.8 ~entry_date:(_date "2024-01-01")
  in
  let r2, t2 =
    make_loser ~symbol:"UND" ~r:2.0 ~entry_date:(_date "2024-02-01")
  in
  let audit = [ r1; r2 ] in
  let trades = [ t1; t2 ] in
  let ratings = TR.rate_all ~config:cfg ~audit ~trades in
  let m = TR.behavioral_metrics_of ~config:cfg ~ratings ~audit ~trades in
  assert_that m.exit_losers_too_late.stop_discipline_pct
    (float_equal ~epsilon:1e-9 50.0)

(* -- Behavioural metric (d) — entering losers too often + matrix --------- *)

let test_entering_losers_flags_bottom_quartile_loser _ =
  (* 4 trades with cascade scores 90 / 70 / 50 / 30. Bottom = 30 (Q4). Make
     it a loser — should be flagged. Make others winners. *)
  let make_pair ~symbol ~score ~pnl ~ed =
    let entry =
      make_entry ~symbol ~cascade_score:score ~initial_risk_dollars:1_000.0
        ~entry_date:ed ()
    in
    let trade =
      make_trade ~symbol ~entry_date:ed ~pnl_dollars:pnl
        ~pnl_percent:(pnl /. 100.0) ()
    in
    (make_record entry, trade)
  in
  let pairs =
    [
      make_pair ~symbol:"A" ~score:90 ~pnl:1_000.0 ~ed:(_date "2024-01-01");
      make_pair ~symbol:"B" ~score:70 ~pnl:500.0 ~ed:(_date "2024-02-01");
      make_pair ~symbol:"C" ~score:50 ~pnl:200.0 ~ed:(_date "2024-03-01");
      make_pair ~symbol:"D" ~score:30 ~pnl:(-500.0) ~ed:(_date "2024-04-01");
    ]
  in
  let audit = List.map pairs ~f:fst in
  let trades = List.map pairs ~f:snd in
  let ratings = TR.rate_all ~config:cfg ~audit ~trades in
  let m = TR.behavioral_metrics_of ~config:cfg ~ratings ~audit ~trades in
  assert_that m.entering_losers_often
    (all_of
       [
         field
           (fun (e : TR.entering_losers_often) -> e.flagged_count)
           (equal_to 1);
         field
           (fun (e : TR.entering_losers_often) -> List.length e.per_quartile)
           (equal_to 4);
       ])

(* -- Decision quality matrix --------------------------------------------- *)

let test_decision_quality_matrix _ =
  let make_pair ~symbol ~r_input ~ed =
    let entry =
      make_entry ~symbol ~entry_date:ed ~initial_risk_dollars:1_000.0 ()
    in
    let trade =
      make_trade ~symbol ~entry_date:ed ~pnl_dollars:(r_input *. 1_000.0)
        ~pnl_percent:(r_input *. 10.0) ()
    in
    (make_record entry, trade)
  in
  let pairs =
    [
      make_pair ~symbol:"A" ~r_input:3.0 ~ed:(_date "2024-01-01");
      make_pair ~symbol:"B" ~r_input:1.0 ~ed:(_date "2024-02-01");
      make_pair ~symbol:"C" ~r_input:(-0.5) ~ed:(_date "2024-03-01");
      make_pair ~symbol:"D" ~r_input:(-2.0) ~ed:(_date "2024-04-01");
    ]
  in
  let audit = List.map pairs ~f:fst in
  let trades = List.map pairs ~f:snd in
  let ratings = TR.rate_all ~config:cfg ~audit ~trades in
  let m = TR.decision_quality_matrix_of ~ratings in
  assert_that m
    (all_of
       [
         field
           (fun (d : TR.decision_quality_matrix) -> d.total_trades)
           (equal_to 4);
         field
           (fun (d : TR.decision_quality_matrix) -> d.overall_win_rate_pct)
           (float_equal ~epsilon:1e-9 50.0);
       ])

(* -- Weinstein aggregate ------------------------------------------------- *)

let test_weinstein_aggregate_per_rule_counts _ =
  let entry_pass = make_entry ~symbol:"PASS" () in
  let entry_fail_r3 =
    make_entry ~symbol:"FAIL3" ~entry_date:(_date "2024-02-01")
      ~stage:(WT.Stage4 { weeks_declining = 4 })
      ~ma_direction:WT.Declining ()
  in
  let audit = [ make_record entry_pass; make_record entry_fail_r3 ] in
  let trades =
    [
      make_trade ~symbol:"PASS" ();
      make_trade ~symbol:"FAIL3" ~entry_date:(_date "2024-02-01") ();
    ]
  in
  let ratings = TR.rate_all ~config:cfg ~audit ~trades in
  let agg = TR.weinstein_aggregate_of ~config:cfg ~ratings ~audit in
  let r3_summary =
    List.find_exn agg.per_rule ~f:(fun (s : TR.rule_violation_summary) ->
        TR.equal_rule_id s.rule TR.R3_no_long_in_stage_4)
  in
  assert_that agg
    (all_of
       [
         field
           (fun (a : TR.weinstein_aggregate) ->
             List.length a.trades_with_critical_violation)
           (equal_to 1);
         field
           (fun (_ : TR.weinstein_aggregate) -> r3_summary.fail_count)
           (equal_to 1);
         field
           (fun (_ : TR.weinstein_aggregate) -> r3_summary.applicable_count)
           (equal_to 2);
       ])

(* -- Markdown formatters ------------------------------------------------- *)

let test_format_per_trade_extras_contains_header _ =
  let rating : TR.rating =
    {
      symbol = "AAPL";
      entry_date = _date "2024-01-15";
      r_multiple = 2.5;
      mfe_pct = 0.30;
      mae_pct = -0.05;
      hold_time_anomaly = TR.Normal;
      outcome = TR.Win;
      weinstein_score = 0.875;
    }
  in
  let lines = TR.format_per_trade_extras ~ratings:[ rating ] in
  let md = String.concat ~sep:"\n" lines in
  assert_that md
    (all_of
       [
         field
           (fun s -> String.is_substring s ~substring:"## Per-trade ratings")
           (equal_to true);
         field
           (fun s -> String.is_substring s ~substring:"+2.50R")
           (equal_to true);
         field
           (fun s -> String.is_substring s ~substring:"AAPL")
           (equal_to true);
         field
           (fun s -> String.is_substring s ~substring:"0.88")
           (equal_to true);
       ])

let test_format_weinstein_section_lists_all_rules _ =
  let agg : TR.weinstein_aggregate =
    {
      per_rule =
        List.map TR.all_rules ~f:(fun rule ->
            ({
               rule;
               fail_count = 0;
               marginal_count = 0;
               applicable_count = 1;
               pass_rate_pct = 100.0;
             }
              : TR.rule_violation_summary));
      spirit_score = 1.0;
      trades_with_critical_violation = [];
    }
  in
  let lines = TR.format_weinstein_section agg in
  let md = String.concat ~sep:"\n" lines in
  assert_that md
    (all_of
       [
         field
           (fun s ->
             String.is_substring s ~substring:"## Weinstein conformance")
           (equal_to true);
         field (fun s -> String.is_substring s ~substring:"R1") (equal_to true);
         field (fun s -> String.is_substring s ~substring:"R8") (equal_to true);
         field
           (fun s ->
             String.is_substring s ~substring:"No critical (R3) violations")
           (equal_to true);
       ])

(* -- Suite --------------------------------------------------------------- *)

let suite =
  "Trade_audit_ratings"
  >::: [
         "R1 pass long stage2 ma rising" >:: test_r1_pass_long_stage2_ma_rising;
         "R1 fail long ma declining" >:: test_r1_fail_long_ma_declining;
         "R1 NA for short" >:: test_r1_na_for_short;
         "R2 pass volume 2x" >:: test_r2_pass_volume_2x;
         "R2 marginal adequate volume" >:: test_r2_marginal_adequate_volume;
         "R2 fail weak volume" >:: test_r2_fail_weak_volume;
         "R3 critical fail long stage 4" >:: test_r3_critical_fail_long_stage_4;
         "R3 pass long stage 2" >:: test_r3_pass_long_stage_2;
         "R4 pass short ma declining" >:: test_r4_pass_short_ma_declining;
         "R4 fail short ma rising" >:: test_r4_fail_short_ma_rising;
         "R5 pass short stage 4" >:: test_r5_pass_short_stage_4;
         "R5 fail short not stage 4" >:: test_r5_fail_short_not_stage_4;
         "R6 NA documented gap" >:: test_r6_na;
         "R7 pass long exit stage 4 via stop"
         >:: test_r7_pass_long_exit_in_stage_4_via_stop;
         "R7 fail held through stage 4 via time"
         >:: test_r7_fail_held_through_stage_4_via_time;
         "R7 NA when position open" >:: test_r7_na_when_position_open;
         "R8 pass long macro bullish" >:: test_r8_pass_long_macro_bullish;
         "R8 fail long macro bearish" >:: test_r8_fail_long_macro_bearish;
         "R8 marginal long macro neutral"
         >:: test_r8_marginal_long_macro_neutral;
         "score excludes NA" >:: test_score_excludes_na;
         "score marginal counts half" >:: test_score_marginal_counts_half;
         "rate r-multiple positive" >:: test_rate_r_multiple;
         "rate r-multiple negative" >:: test_rate_r_multiple_negative;
         "rate hold-time anomaly stopped immediately"
         >:: test_rate_hold_time_anomaly_immediate;
         "rate hold-time anomaly held indefinitely"
         >:: test_rate_hold_time_anomaly_indefinite;
         "rate mfe / mae threaded" >:: test_rate_mfe_mae_threaded;
         "over-trading burst detection" >:: test_over_trading_burst_detection;
         "exit winners flagged when realized below half mfe"
         >:: test_exit_winners_flagged_when_realized_below_half_mfe;
         "exit losers flagged when r-multiple exceeds threshold"
         >:: test_exit_losers_flagged_when_r_multiple_exceeds_threshold;
         "exit losers stop discipline pct"
         >:: test_exit_losers_stop_discipline_pct;
         "entering losers flags bottom-quartile loser"
         >:: test_entering_losers_flags_bottom_quartile_loser;
         "decision quality matrix" >:: test_decision_quality_matrix;
         "weinstein aggregate per-rule counts"
         >:: test_weinstein_aggregate_per_rule_counts;
         "format per-trade extras contains header"
         >:: test_format_per_trade_extras_contains_header;
         "format weinstein section lists all rules"
         >:: test_format_weinstein_section_lists_all_rules;
       ]

let () = run_test_tt_main suite
