(** Unit tests for [Backtest.Trade_context] (M5.2e per-trade context join).

    Pins the join behaviour and the 6 derived fields against synthetic
    trade_metrics + audit + stop_log inputs. Covers:
    - Stage label rendering (Stage1/Stage2/Stage2_late/Stage3/Stage4)
    - stop_trigger_kind label rendering (gap_down/intraday/end_of_period)
    - Successful join: all 6 fields populate from matching audit + stop_log
    - Missing audit: audit-derived fields are [None], symbol still propagates
    - Missing stop_log: stop_trigger_kind / days_to_first_stop_trigger are
      [None]
    - days_to_first_stop_trigger is [None] when exit was not a stop trigger
    - csv_header_fields shape pin
    - csv_row_fields formatting (None → empty cell, %.4f for floats) *)

open OUnit2
open Core
open Matchers
module TC = Backtest.Trade_context
module TA = Backtest.Trade_audit
module SL = Backtest.Stop_log

let _date d = Date.of_string d

(* Builders ----------------------------------------------------------- *)

let make_trade ?(symbol = "AAPL") ?(side = Trading_base.Types.Buy)
    ?(entry_date = _date "2024-01-15") ?(exit_date = _date "2024-04-20")
    ?(days_held = 96) ?(entry_price = 150.0) ?(exit_price = 138.0)
    ?(quantity = 100.0) ?(pnl_dollars = -1200.0) ?(pnl_percent = -8.0) () :
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

let make_entry ?(symbol = "AAPL") ?(entry_date = _date "2024-01-15")
    ?(position_id = "AAPL-wein-1") ?(side = Trading_base.Types.Long)
    ?(stage = Weinstein_types.Stage2 { weeks_advancing = 4; late = false })
    ?(volume_ratio = Some 2.4) ?(suggested_entry = 150.0)
    ?(installed_stop = 138.0) ?(cascade_score = 75) () : TA.entry_decision =
  {
    symbol;
    entry_date;
    position_id;
    macro_trend = Weinstein_types.Bullish;
    macro_confidence = 0.72;
    macro_indicators = [];
    stage;
    ma_direction = Weinstein_types.Rising;
    ma_slope_pct = 0.018;
    rs_trend = Some Weinstein_types.Positive_rising;
    rs_value = Some 1.05;
    volume_quality = Some (Weinstein_types.Strong 2.4);
    volume_ratio;
    resistance_quality = Some Weinstein_types.Clean;
    support_quality = Some Weinstein_types.Clean;
    sector_name = "Tech";
    sector_rating = Screener.Strong;
    cascade_score;
    cascade_grade = Weinstein_types.A;
    cascade_score_components = [];
    cascade_rationale = [];
    side;
    suggested_entry;
    suggested_stop = installed_stop;
    installed_stop;
    stop_floor_kind = TA.Buffer_fallback;
    risk_pct = 0.08;
    initial_position_value = 15000.0;
    initial_risk_dollars = 1200.0;
    alternatives_considered = [];
  }

let make_record ?exit_ entry : TA.audit_record = { entry; exit_ }

let make_stop_info ~position_id ~symbol
    ?(entry_date = Some (_date "2024-01-15")) ?(entry_stop = Some 138.0)
    ?(exit_stop = Some 138.0) ?exit_trigger () : SL.stop_info =
  { position_id; symbol; entry_date; entry_stop; exit_stop; exit_trigger }

(* stage_label --------------------------------------------------------- *)

let test_stage_label_distinguishes_late_stage2 _ =
  assert_that
    ( TC.stage_label (Weinstein_types.Stage1 { weeks_in_base = 0 }),
      TC.stage_label
        (Weinstein_types.Stage2 { weeks_advancing = 4; late = false }),
      TC.stage_label
        (Weinstein_types.Stage2 { weeks_advancing = 12; late = true }),
      TC.stage_label (Weinstein_types.Stage3 { weeks_topping = 2 }),
      TC.stage_label (Weinstein_types.Stage4 { weeks_declining = 3 }) )
    (equal_to ("Stage1", "Stage2", "Stage2_late", "Stage3", "Stage4"))

(* stop_trigger_kind_label -------------------------------------------- *)

let test_stop_trigger_kind_label_distinguishes_all _ =
  assert_that
    ( TC.stop_trigger_kind_label SL.Gap_down,
      TC.stop_trigger_kind_label SL.Intraday,
      TC.stop_trigger_kind_label SL.End_of_period,
      TC.stop_trigger_kind_label SL.Non_stop_exit )
    (equal_to ("gap_down", "intraday", "end_of_period", "non_stop_exit"))

(* csv_header_fields --------------------------------------------------- *)

let test_csv_header_fields_pinned _ =
  assert_that TC.csv_header_fields
    (elements_are
       [
         equal_to "entry_stage";
         equal_to "entry_volume_ratio";
         equal_to "stop_initial_distance_pct";
         equal_to "stop_trigger_kind";
         equal_to "days_to_first_stop_trigger";
         equal_to "screener_score_at_entry";
       ])

(* of_audit_and_stop_log: full join ----------------------------------- *)

let test_of_audit_and_stop_log_populates_all_fields _ =
  let trade = make_trade () in
  let entry = make_entry () in
  let audit = [ make_record entry ] in
  let stop_info =
    make_stop_info ~position_id:"AAPL-wein-1" ~symbol:"AAPL"
      ~exit_trigger:(SL.Stop_loss { stop_price = 138.0; actual_price = 137.99 })
      ()
  in
  let stop_infos = [ stop_info ] in
  let ctx = TC.of_audit_and_stop_log ~audit ~stop_infos ~trade in
  assert_that ctx
    (all_of
       [
         field
           (fun (c : TC.t) -> c.entry_stage)
           (is_some_and (equal_to "Stage2"));
         field
           (fun (c : TC.t) -> c.entry_volume_ratio)
           (is_some_and (float_equal 2.4));
         field
           (fun (c : TC.t) -> c.stop_initial_distance_pct)
           (is_some_and (float_equal ~epsilon:1e-6 0.08));
         field
           (fun (c : TC.t) -> c.stop_trigger_kind)
           (is_some_and (equal_to "intraday"));
         field
           (fun (c : TC.t) -> c.days_to_first_stop_trigger)
           (is_some_and (equal_to 96));
         field
           (fun (c : TC.t) -> c.screener_score_at_entry)
           (is_some_and (equal_to 75));
       ])

(* Late Stage2 propagates to entry_stage label. *)
let test_late_stage2_label _ =
  let trade = make_trade () in
  let entry =
    make_entry
      ~stage:(Weinstein_types.Stage2 { weeks_advancing = 12; late = true })
      ()
  in
  let ctx =
    TC.of_audit_and_stop_log ~audit:[ make_record entry ] ~stop_infos:[] ~trade
  in
  assert_that ctx.entry_stage (is_some_and (equal_to "Stage2_late"))

(* Gap-down stop flows through to stop_trigger_kind label. *)
let test_gap_down_stop_classified _ =
  let trade = make_trade () in
  let entry = make_entry () in
  let stop_info =
    make_stop_info ~position_id:"AAPL-wein-1" ~symbol:"AAPL"
      ~exit_trigger:(SL.Stop_loss { stop_price = 138.0; actual_price = 125.0 })
      ()
  in
  let ctx =
    TC.of_audit_and_stop_log
      ~audit:[ make_record entry ]
      ~stop_infos:[ stop_info ] ~trade
  in
  assert_that ctx.stop_trigger_kind (is_some_and (equal_to "gap_down"))

(* Take-profit exit yields non_stop_exit + None days_to_first_stop_trigger. *)
let test_take_profit_exit_is_non_stop _ =
  let trade = make_trade () in
  let entry = make_entry () in
  let stop_info =
    make_stop_info ~position_id:"AAPL-wein-1" ~symbol:"AAPL"
      ~exit_trigger:
        (SL.Take_profit { target_price = 165.0; actual_price = 165.0 })
      ()
  in
  let ctx =
    TC.of_audit_and_stop_log
      ~audit:[ make_record entry ]
      ~stop_infos:[ stop_info ] ~trade
  in
  assert_that ctx
    (all_of
       [
         field
           (fun (c : TC.t) -> c.stop_trigger_kind)
           (is_some_and (equal_to "non_stop_exit"));
         field (fun (c : TC.t) -> c.days_to_first_stop_trigger) is_none;
       ])

(* End-of-period exit. *)
let test_end_of_period_exit_classified _ =
  let trade = make_trade () in
  let entry = make_entry () in
  let stop_info =
    make_stop_info ~position_id:"AAPL-wein-1" ~symbol:"AAPL"
      ~exit_trigger:SL.End_of_period ()
  in
  let ctx =
    TC.of_audit_and_stop_log
      ~audit:[ make_record entry ]
      ~stop_infos:[ stop_info ] ~trade
  in
  assert_that ctx.stop_trigger_kind (is_some_and (equal_to "end_of_period"))

(* Missing audit record yields None for all audit-derived fields, but
   stop_trigger_kind still populates from stop_log via symbol fallback. *)
let test_missing_audit_yields_none_for_audit_fields _ =
  let trade = make_trade () in
  let stop_info =
    make_stop_info ~position_id:"AAPL-wein-1" ~symbol:"AAPL"
      ~exit_trigger:(SL.Stop_loss { stop_price = 138.0; actual_price = 137.99 })
      ()
  in
  let ctx =
    TC.of_audit_and_stop_log ~audit:[] ~stop_infos:[ stop_info ] ~trade
  in
  assert_that ctx
    (all_of
       [
         field (fun (c : TC.t) -> c.entry_stage) is_none;
         field (fun (c : TC.t) -> c.entry_volume_ratio) is_none;
         field (fun (c : TC.t) -> c.stop_initial_distance_pct) is_none;
         field (fun (c : TC.t) -> c.screener_score_at_entry) is_none;
         field
           (fun (c : TC.t) -> c.stop_trigger_kind)
           (is_some_and (equal_to "intraday"));
       ])

(* Missing stop_log yields None for stop-derived fields; audit fields
   still populate. *)
let test_missing_stop_log_yields_none_for_stop_fields _ =
  let trade = make_trade () in
  let entry = make_entry () in
  let ctx =
    TC.of_audit_and_stop_log ~audit:[ make_record entry ] ~stop_infos:[] ~trade
  in
  assert_that ctx
    (all_of
       [
         field
           (fun (c : TC.t) -> c.entry_stage)
           (is_some_and (equal_to "Stage2"));
         field
           (fun (c : TC.t) -> c.screener_score_at_entry)
           (is_some_and (equal_to 75));
         field (fun (c : TC.t) -> c.stop_trigger_kind) is_none;
         field (fun (c : TC.t) -> c.days_to_first_stop_trigger) is_none;
       ])

(* csv_row_fields formatting ----------------------------------------- *)

let test_csv_row_fields_formats_correctly _ =
  let ctx : TC.t =
    {
      symbol = "AAPL";
      entry_date = _date "2024-01-15";
      entry_stage = Some "Stage2";
      entry_volume_ratio = Some 2.4;
      stop_initial_distance_pct = Some 0.08;
      stop_trigger_kind = Some "intraday";
      days_to_first_stop_trigger = Some 96;
      screener_score_at_entry = Some 75;
    }
  in
  assert_that (TC.csv_row_fields ctx)
    (elements_are
       [
         equal_to "Stage2";
         equal_to "2.4000";
         equal_to "0.0800";
         equal_to "intraday";
         equal_to "96";
         equal_to "75";
       ])

let test_csv_row_fields_renders_none_as_empty _ =
  let ctx : TC.t =
    {
      symbol = "AAPL";
      entry_date = _date "2024-01-15";
      entry_stage = None;
      entry_volume_ratio = None;
      stop_initial_distance_pct = None;
      stop_trigger_kind = None;
      days_to_first_stop_trigger = None;
      screener_score_at_entry = None;
    }
  in
  assert_that (TC.csv_row_fields ctx)
    (elements_are
       [
         equal_to "";
         equal_to "";
         equal_to "";
         equal_to "";
         equal_to "";
         equal_to "";
       ])

let suite =
  "Trade_context"
  >::: [
         "stage_label distinguishes Stage2_late"
         >:: test_stage_label_distinguishes_late_stage2;
         "stop_trigger_kind_label all variants"
         >:: test_stop_trigger_kind_label_distinguishes_all;
         "csv_header_fields pinned" >:: test_csv_header_fields_pinned;
         "of_audit_and_stop_log full join"
         >:: test_of_audit_and_stop_log_populates_all_fields;
         "late stage2 label" >:: test_late_stage2_label;
         "gap_down stop classified" >:: test_gap_down_stop_classified;
         "take_profit exit is non_stop" >:: test_take_profit_exit_is_non_stop;
         "End_of_period exit classified" >:: test_end_of_period_exit_classified;
         "missing audit -> audit fields None"
         >:: test_missing_audit_yields_none_for_audit_fields;
         "missing stop_log -> stop fields None"
         >:: test_missing_stop_log_yields_none_for_stop_fields;
         "csv_row_fields formats correctly"
         >:: test_csv_row_fields_formats_correctly;
         "csv_row_fields renders None as empty"
         >:: test_csv_row_fields_renders_none_as_empty;
       ]

let () = run_test_tt_main suite
