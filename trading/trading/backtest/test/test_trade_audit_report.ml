(** Unit tests for [Trade_audit_report].

    Pins the rendered markdown on a fixture of 2-3 audit_records + matching
    trade_metrics. Covers:
    - render output shape (header, aggregate, per-trade table)
    - audit-side fields populated when (symbol, entry_date) matches; em-dash
      placeholder when no audit record matches a trade
    - best / worst selection by pnl_percent
    - empty-trade input renders gracefully with "_No trades._" body
    - load reads trades.csv + trade_audit.sexp + summary.sexp from disk *)

open OUnit2
open Core
open Matchers
module TAR = Trade_audit_report
module TA = Backtest.Trade_audit

(* Builders --------------------------------------------------------------- *)

let _date d = Date.of_string d

let make_trade ?(symbol = "AAPL") ?(side = Trading_base.Types.Buy)
    ?(entry_date = _date "2024-01-15") ?(exit_date = _date "2024-04-20")
    ?(days_held = 96) ?(entry_price = 150.50) ?(exit_price = 138.46)
    ?(quantity = 500.0) ?(pnl_dollars = -6_020.0) ?(pnl_percent = -8.0) () :
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

let make_entry_decision ?(symbol = "AAPL") ?(entry_date = _date "2024-01-15")
    ?(position_id = "AAPL-wein-1") ?(side = Trading_base.Types.Long)
    ?(macro_trend = Weinstein_types.Bullish)
    ?(stage = Weinstein_types.Stage2 { weeks_advancing = 4; late = false })
    ?(rs_trend = Some Weinstein_types.Positive_rising) ?(cascade_score = 75)
    ?(cascade_grade = Weinstein_types.A) ?(split_safe_basis = TA.Flag_off) () :
    TA.entry_decision =
  {
    symbol;
    entry_date;
    position_id;
    macro_trend;
    macro_confidence = 0.72;
    macro_indicators = [];
    stage;
    ma_direction = Weinstein_types.Rising;
    ma_slope_pct = 0.018;
    rs_trend;
    rs_value = Some 1.05;
    volume_quality = Some (Weinstein_types.Strong 2.4);
    volume_ratio = Some 2.4;
    resistance_quality = Some Weinstein_types.Clean;
    support_quality = Some Weinstein_types.Clean;
    sector_name = "Information Technology";
    sector_rating = Screener.Strong;
    cascade_score;
    cascade_grade;
    cascade_score_components = [ ("stage2_breakout", 30) ];
    cascade_rationale = [ "Stage2 breakout" ];
    side;
    suggested_entry = 150.50;
    suggested_stop = 138.46;
    installed_stop = 138.46;
    stop_floor_kind = TA.Buffer_fallback;
    split_safe_basis;
    risk_pct = 0.08;
    initial_position_value = 75_000.0;
    initial_risk_dollars = 6_000.0;
    alternatives_considered = [];
  }

let make_exit_decision ?(symbol = "AAPL") ?(exit_date = _date "2024-04-20")
    ?(position_id = "AAPL-wein-1")
    ?(exit_trigger =
      Backtest.Stop_log.Stop_loss { stop_price = 138.46; actual_price = 137.20 })
    () : TA.exit_decision =
  {
    symbol;
    exit_date;
    position_id;
    exit_trigger;
    macro_trend_at_exit = Weinstein_types.Neutral;
    macro_confidence_at_exit = 0.45;
    stage_at_exit = Weinstein_types.Stage3 { weeks_topping = 2 };
    rs_trend_at_exit = Some Weinstein_types.Positive_flat;
    distance_from_ma_pct = -0.025;
    max_favorable_excursion_pct = 0.082;
    max_adverse_excursion_pct = -0.085;
    weeks_macro_was_bearish = 0;
    weeks_stage_left_2 = 1;
  }

let make_execution ?(designed_order_type = TA.Market)
    ?(designed_trigger = 100.0) ?(fill_price = 100.0)
    ?(fill_vs_trigger_pct = 0.0) ?(fill_within_band = true) ?(faithful = true)
    () : TA.execution_faithfulness =
  {
    designed_order_type;
    designed_trigger;
    fill_price;
    fill_vs_trigger_pct;
    fill_within_band;
    faithful;
  }

let make_record ?(execution = None) entry exit_ : TA.audit_record =
  { entry; exit_ = Some exit_; external_exit = None; execution }

(* --- Header computation ------------------------------------------------- *)

let test_header_counts_winners_and_losers _ =
  let trades =
    [
      make_trade ~symbol:"AAPL" ~pnl_dollars:1000.0 ~pnl_percent:5.0 ();
      make_trade ~symbol:"MSFT" ~pnl_dollars:2000.0 ~pnl_percent:8.0 ();
      make_trade ~symbol:"NVDA" ~pnl_dollars:(-500.0) ~pnl_percent:(-3.0) ();
    ]
  in
  let report = TAR.render ~trade_audit:[] ~trades () in
  assert_that report.header
    (all_of
       [
         field
           (fun (h : TAR.scenario_header) -> h.total_round_trips)
           (equal_to 3);
         field (fun (h : TAR.scenario_header) -> h.winners) (equal_to 2);
         field (fun (h : TAR.scenario_header) -> h.losers) (equal_to 1);
         field
           (fun (h : TAR.scenario_header) -> h.win_rate_pct)
           (float_equal ~epsilon:1e-6 (200.0 /. 3.0));
         field
           (fun (h : TAR.scenario_header) -> h.total_realized_return_pct)
           (float_equal ~epsilon:1e-6 10.0);
       ])

let test_header_empty_trades _ =
  let report = TAR.render ~trade_audit:[] ~trades:[] () in
  assert_that report.header
    (all_of
       [
         field
           (fun (h : TAR.scenario_header) -> h.total_round_trips)
           (equal_to 0);
         field (fun (h : TAR.scenario_header) -> h.winners) (equal_to 0);
         field
           (fun (h : TAR.scenario_header) -> h.win_rate_pct)
           (float_equal 0.0);
         field (fun (h : TAR.scenario_header) -> h.period_start) is_none;
       ])

let test_header_period_derived_from_trades _ =
  let trades =
    [
      make_trade ~symbol:"A" ~entry_date:(_date "2024-02-01")
        ~exit_date:(_date "2024-03-01") ();
      make_trade ~symbol:"B" ~entry_date:(_date "2024-01-10")
        ~exit_date:(_date "2024-05-15") ();
    ]
  in
  let report = TAR.render ~trade_audit:[] ~trades () in
  assert_that report.header
    (all_of
       [
         field
           (fun (h : TAR.scenario_header) -> h.period_start)
           (is_some_and (equal_to (_date "2024-01-10")));
         field
           (fun (h : TAR.scenario_header) -> h.period_end)
           (is_some_and (equal_to (_date "2024-05-15")));
       ])

let test_header_uses_supplied_period _ =
  let report =
    TAR.render ~scenario_name:"goldens-sp500" ~period_start:(_date "2019-01-02")
      ~period_end:(_date "2023-12-29") ~universe_size:500 ~trade_audit:[]
      ~trades:
        [
          make_trade ~entry_date:(_date "2020-06-01")
            ~exit_date:(_date "2020-08-01") ();
        ]
      ()
  in
  assert_that report.header
    (all_of
       [
         field
           (fun (h : TAR.scenario_header) -> h.scenario_name)
           (is_some_and (equal_to "goldens-sp500"));
         field
           (fun (h : TAR.scenario_header) -> h.period_start)
           (is_some_and (equal_to (_date "2019-01-02")));
         field
           (fun (h : TAR.scenario_header) -> h.period_end)
           (is_some_and (equal_to (_date "2023-12-29")));
         field
           (fun (h : TAR.scenario_header) -> h.universe_size)
           (is_some_and (equal_to 500));
       ])

(* --- Best / worst ------------------------------------------------------- *)

let test_best_worst_picks_extremes _ =
  let trades =
    [
      make_trade ~symbol:"AAPL" ~entry_date:(_date "2020-04-25")
        ~pnl_percent:44.2 ();
      make_trade ~symbol:"WRB" ~entry_date:(_date "2023-10-07")
        ~pnl_percent:(-0.5) ();
      make_trade ~symbol:"MSFT" ~entry_date:(_date "2022-01-05")
        ~pnl_percent:12.0 ();
    ]
  in
  let report = TAR.render ~trade_audit:[] ~trades () in
  assert_that report.best_worst
    (all_of
       [
         field
           (fun (b : TAR.best_worst) -> b.best)
           (is_some_and
              (equal_to
                 (("AAPL", _date "2020-04-25", 44.2) : string * Date.t * float)));
         field
           (fun (b : TAR.best_worst) -> b.worst)
           (is_some_and
              (equal_to
                 (("WRB", _date "2023-10-07", -0.5) : string * Date.t * float)));
       ])

let test_best_worst_empty _ =
  let report = TAR.render ~trade_audit:[] ~trades:[] () in
  assert_that report.best_worst
    (all_of
       [
         field (fun (b : TAR.best_worst) -> b.best) is_none;
         field (fun (b : TAR.best_worst) -> b.worst) is_none;
       ])

(* --- Per-trade row population ------------------------------------------ *)

let test_row_has_audit_fields_when_matched _ =
  let trade = make_trade ~symbol:"AAPL" ~entry_date:(_date "2024-01-15") () in
  let entry =
    make_entry_decision ~symbol:"AAPL" ~entry_date:(_date "2024-01-15")
      ~cascade_grade:Weinstein_types.A ~cascade_score:75 ()
  in
  let exit_ = make_exit_decision () in
  let record = make_record entry exit_ in
  let report = TAR.render ~trade_audit:[ record ] ~trades:[ trade ] () in
  assert_that report.rows
    (elements_are
       [
         all_of
           [
             field (fun (r : TAR.per_trade_row) -> r.symbol) (equal_to "AAPL");
             field
               (fun (r : TAR.per_trade_row) -> r.cascade_grade)
               (is_some_and (equal_to Weinstein_types.A));
             field
               (fun (r : TAR.per_trade_row) -> r.cascade_score)
               (is_some_and (equal_to 75));
             field
               (fun (r : TAR.per_trade_row) -> r.entry_macro_trend)
               (is_some_and (equal_to Weinstein_types.Bullish));
             field
               (fun (r : TAR.per_trade_row) -> r.exit_trigger)
               (equal_to "stop_loss");
           ];
       ])

let test_row_has_none_audit_fields_when_unmatched _ =
  let trade =
    make_trade ~symbol:"NOAUDIT" ~entry_date:(_date "2024-06-01") ()
  in
  let report = TAR.render ~trade_audit:[] ~trades:[ trade ] () in
  assert_that report.rows
    (elements_are
       [
         all_of
           [
             field (fun (r : TAR.per_trade_row) -> r.cascade_grade) is_none;
             field (fun (r : TAR.per_trade_row) -> r.cascade_score) is_none;
             field (fun (r : TAR.per_trade_row) -> r.entry_stage) is_none;
             field (fun (r : TAR.per_trade_row) -> r.exit_trigger) (equal_to "");
           ];
       ])

(* --- Execution-faithfulness columns + summary (#2210 follow-on) --------- *)

let test_row_has_execution_fields_when_present _ =
  let trade = make_trade ~symbol:"AAPL" ~entry_date:(_date "2024-01-15") () in
  let record =
    make_record
      ~execution:
        (Some
           (make_execution ~fill_vs_trigger_pct:0.03 ~faithful:true
              ~designed_order_type:
                (TA.Stop_limit { trigger = 150.0; limit = 172.5 })
              ()))
      (make_entry_decision ()) (make_exit_decision ())
  in
  let report = TAR.render ~trade_audit:[ record ] ~trades:[ trade ] () in
  assert_that report.rows
    (elements_are
       [
         all_of
           [
             field
               (fun (r : TAR.per_trade_row) -> r.fill_vs_trigger_pct)
               (is_some_and (float_equal 0.03));
             field
               (fun (r : TAR.per_trade_row) -> r.faithful)
               (is_some_and (equal_to true));
           ];
       ])

let test_row_execution_fields_none_when_absent _ =
  (* Matched audit record but [execution = None] (pre-#2158 capture) — both
     execution columns stay [None] and render as blank / em-dash. *)
  let trade = make_trade ~symbol:"AAPL" ~entry_date:(_date "2024-01-15") () in
  let record = make_record (make_entry_decision ()) (make_exit_decision ()) in
  let report = TAR.render ~trade_audit:[ record ] ~trades:[ trade ] () in
  assert_that report.rows
    (elements_are
       [
         all_of
           [
             field
               (fun (r : TAR.per_trade_row) -> r.fill_vs_trigger_pct)
               is_none;
             field (fun (r : TAR.per_trade_row) -> r.faithful) is_none;
           ];
       ])

let test_markdown_renders_execution_columns _ =
  let trade = make_trade ~symbol:"AAPL" ~entry_date:(_date "2024-01-15") () in
  let record =
    make_record
      ~execution:
        (Some (make_execution ~fill_vs_trigger_pct:0.03 ~faithful:true ()))
      (make_entry_decision ()) (make_exit_decision ())
  in
  let report = TAR.render ~trade_audit:[ record ] ~trades:[ trade ] () in
  let md = TAR.to_markdown report in
  let contains s = String.is_substring md ~substring:s in
  assert_that md
    (all_of
       [
         (* new table columns present in the header *)
         field (fun _ -> contains "fill_vs_trig | faithful |") (equal_to true);
         (* fraction 0.03 renders as +3.00% and faithful renders as U+2713 *)
         field (fun _ -> contains "+3.00%") (equal_to true);
         field (fun _ -> contains "\xe2\x9c\x93") (equal_to true);
         (* single-record summary line *)
         field
           (fun _ ->
             contains
               "- Execution: 1 records, 100.0% faithful, mean fill_vs_trigger \
                +3.00%")
           (equal_to true);
       ])

let test_execution_summary_math _ =
  (* 3 matched records, 2 faithful + 1 not; fractions {0.05, 0.09, 0.01} with a
     mean of 0.05 (= +5.00%). Pins the aggregate summary line arithmetic. *)
  let mk sym date frac faithful =
    ( make_trade ~symbol:sym ~entry_date:(_date date) (),
      make_record
        ~execution:
          (Some (make_execution ~fill_vs_trigger_pct:frac ~faithful ()))
        (make_entry_decision ~symbol:sym ~entry_date:(_date date)
           ~position_id:(sym ^ "-1") ())
        (make_exit_decision ~symbol:sym ~position_id:(sym ^ "-1") ()) )
  in
  let t1, r1 = mk "AAPL" "2024-01-15" 0.05 true in
  let t2, r2 = mk "MSFT" "2024-02-15" 0.09 false in
  let t3, r3 = mk "NVDA" "2024-03-15" 0.01 true in
  let report =
    TAR.render ~trade_audit:[ r1; r2; r3 ] ~trades:[ t1; t2; t3 ] ()
  in
  assert_that
    (String.is_substring (TAR.to_markdown report)
       ~substring:
         "- Execution: 3 records, 66.7% faithful, mean fill_vs_trigger +5.00%")
    (equal_to true)

let test_aggregate_byte_path_unchanged_without_execution _ =
  (* No record carries an execution — the aggregate block is byte-identical to a
     pre-execution report (no "Execution:" line spliced in). *)
  let trade = make_trade ~symbol:"AAPL" ~entry_date:(_date "2024-01-15") () in
  let record = make_record (make_entry_decision ()) (make_exit_decision ()) in
  let report = TAR.render ~trade_audit:[ record ] ~trades:[ trade ] () in
  let md = TAR.to_markdown report in
  assert_that md
    (all_of
       [
         field
           (fun _ -> String.is_substring md ~substring:"- Execution:")
           (equal_to false);
         field
           (fun _ ->
             String.is_substring md
               ~substring:
                 (String.concat ~sep:"\n"
                    [
                      "## Aggregate summary";
                      "";
                      "- Best trade: AAPL 2024-01-15 \xe2\x86\x92 -8.00%";
                      "- Worst trade: AAPL 2024-01-15 \xe2\x86\x92 -8.00%";
                      "";
                      "## Per-trade table";
                    ]))
           (equal_to true);
       ])

(* --- External (reason-only) exit fallback (#2076) ----------------------- *)

let make_external_exit ?(symbol = "AAPL") ?(exit_date = _date "2024-04-20")
    ?(position_id = "AAPL-wein-1") ?(label = "margin_call") () :
    TA.external_exit_decision =
  {
    symbol;
    exit_date;
    position_id;
    exit_trigger = Backtest.Stop_log.Strategy_signal { label; detail = None };
  }

let test_row_falls_back_to_external_exit_trigger _ =
  let trade = make_trade ~symbol:"AAPL" ~entry_date:(_date "2024-01-15") () in
  let entry = make_entry_decision () in
  let record : TA.audit_record =
    {
      entry;
      exit_ = None;
      external_exit = Some (make_external_exit ());
      execution = None;
    }
  in
  let report = TAR.render ~trade_audit:[ record ] ~trades:[ trade ] () in
  assert_that report.rows
    (elements_are
       [
         field
           (fun (r : TAR.per_trade_row) -> r.exit_trigger)
           (equal_to "margin_call");
       ])

let test_row_prefers_enriched_exit_over_external _ =
  let trade = make_trade ~symbol:"AAPL" ~entry_date:(_date "2024-01-15") () in
  let entry = make_entry_decision () in
  let record : TA.audit_record =
    {
      entry;
      exit_ = Some (make_exit_decision ());
      external_exit = Some (make_external_exit ());
      execution = None;
    }
  in
  let report = TAR.render ~trade_audit:[ record ] ~trades:[ trade ] () in
  assert_that report.rows
    (elements_are
       [
         field
           (fun (r : TAR.per_trade_row) -> r.exit_trigger)
           (equal_to "stop_loss");
       ])

let test_row_empty_trigger_when_no_exit_and_no_external _ =
  let trade = make_trade ~symbol:"AAPL" ~entry_date:(_date "2024-01-15") () in
  let entry = make_entry_decision () in
  let record : TA.audit_record =
    { entry; exit_ = None; external_exit = None; execution = None }
  in
  let report = TAR.render ~trade_audit:[ record ] ~trades:[ trade ] () in
  assert_that report.rows
    (elements_are
       [ field (fun (r : TAR.per_trade_row) -> r.exit_trigger) (equal_to "") ])

let test_row_external_exit_generic_label _ =
  let trade = make_trade ~symbol:"AAPL" ~entry_date:(_date "2024-01-15") () in
  let entry = make_entry_decision () in
  let record : TA.audit_record =
    {
      entry;
      exit_ = None;
      external_exit = Some (make_external_exit ~label:"stage3_force_exit" ());
      execution = None;
    }
  in
  let report = TAR.render ~trade_audit:[ record ] ~trades:[ trade ] () in
  assert_that report.rows
    (elements_are
       [
         field
           (fun (r : TAR.per_trade_row) -> r.exit_trigger)
           (equal_to "stage3_force_exit");
       ])

let test_markdown_renders_external_exit_trigger _ =
  let trade = make_trade ~symbol:"AAPL" ~entry_date:(_date "2024-01-15") () in
  let entry = make_entry_decision () in
  let record : TA.audit_record =
    {
      entry;
      exit_ = None;
      external_exit = Some (make_external_exit ());
      execution = None;
    }
  in
  let report = TAR.render ~trade_audit:[ record ] ~trades:[ trade ] () in
  assert_that
    (String.is_substring (TAR.to_markdown report) ~substring:"margin_call")
    (equal_to true)

let test_rows_sorted_by_entry_date _ =
  let trades =
    [
      make_trade ~symbol:"C" ~entry_date:(_date "2024-03-01") ();
      make_trade ~symbol:"A" ~entry_date:(_date "2024-01-01") ();
      make_trade ~symbol:"B" ~entry_date:(_date "2024-02-01") ();
    ]
  in
  let report = TAR.render ~trade_audit:[] ~trades () in
  assert_that
    (List.map report.rows ~f:(fun (r : TAR.per_trade_row) -> r.symbol))
    (elements_are [ equal_to "A"; equal_to "B"; equal_to "C" ])

(* --- Markdown output --------------------------------------------------- *)

let test_to_markdown_pinned_three_trade_fixture _ =
  let aapl_trade =
    make_trade ~symbol:"AAPL" ~entry_date:(_date "2020-04-25")
      ~exit_date:(_date "2020-08-01") ~days_held:98 ~entry_price:280.00
      ~exit_price:404.00 ~quantity:100.0 ~pnl_dollars:12_400.0 ~pnl_percent:44.2
      ()
  in
  let msft_trade =
    make_trade ~symbol:"MSFT" ~entry_date:(_date "2021-06-10")
      ~exit_date:(_date "2021-11-20") ~days_held:163 ~entry_price:250.00
      ~exit_price:340.00 ~quantity:200.0 ~pnl_dollars:18_000.0 ~pnl_percent:36.0
      ()
  in
  let wrb_trade =
    make_trade ~symbol:"WRB" ~entry_date:(_date "2023-10-07")
      ~exit_date:(_date "2023-10-20") ~days_held:13 ~entry_price:80.00
      ~exit_price:79.60 ~quantity:300.0 ~pnl_dollars:(-120.0)
      ~pnl_percent:(-0.5) ()
  in
  let aapl_audit =
    make_record
      (make_entry_decision ~symbol:"AAPL" ~entry_date:(_date "2020-04-25")
         ~position_id:"AAPL-1" ~cascade_grade:Weinstein_types.A
         ~cascade_score:80 ())
      (make_exit_decision ~symbol:"AAPL" ~exit_date:(_date "2020-08-01")
         ~position_id:"AAPL-1"
         ~exit_trigger:
           (Backtest.Stop_log.Signal_reversal { description = "stage3" })
         ())
  in
  let wrb_audit =
    make_record
      (make_entry_decision ~symbol:"WRB" ~entry_date:(_date "2023-10-07")
         ~position_id:"WRB-1"
         ~stage:(Weinstein_types.Stage2 { weeks_advancing = 2; late = false })
         ~cascade_grade:Weinstein_types.B ~cascade_score:55
         ~rs_trend:(Some Weinstein_types.Positive_flat) ())
      (make_exit_decision ~symbol:"WRB" ~exit_date:(_date "2023-10-20")
         ~position_id:"WRB-1"
         ~exit_trigger:
           (Backtest.Stop_log.Stop_loss
              { stop_price = 79.50; actual_price = 79.60 })
         ())
  in
  let report =
    TAR.render ~scenario_name:"goldens-sp500" ~period_start:(_date "2019-01-02")
      ~period_end:(_date "2023-12-29") ~universe_size:500
      ~trade_audit:[ aapl_audit; wrb_audit ]
      ~trades:[ aapl_trade; msft_trade; wrb_trade ]
      ()
  in
  let md = TAR.to_markdown report in
  (* Pin the core PR-3 sections (header / aggregate / per-trade table) plus
     the presence of the PR-4 analysis sections. The full PR-4 pinned content
     lives in [test_trade_audit_ratings]; this test only asserts the
     renderer wires them through. *)
  let core_lines =
    String.concat ~sep:"\n"
      [
        "# Trade audit \xe2\x80\x94 goldens-sp500";
        "";
        "- Period: 2019-01-02 \xe2\x86\x92 2023-12-29";
        "- Universe: 500";
        "- Total round-trips: 3";
        "- Winners: 2 / 3 (66.7%)";
        "- Total realized return (sum of pnl%): +79.70%";
        "";
        "## Aggregate summary";
        "";
        "- Best trade: AAPL 2020-04-25 \xe2\x86\x92 +44.20%";
        "- Worst trade: WRB 2023-10-07 \xe2\x86\x92 -0.50%";
        "";
        "## Per-trade table";
        "";
        "| symbol | entry_date | side | entry_px | exit_date | exit_px | days \
         | pnl_$ | pnl_% | exit_trigger | stage | rs | macro | grade | score | \
         fill_vs_trig | faithful |";
      ]
  in
  let contains s = String.is_substring md ~substring:s in
  assert_that md
    (all_of
       [
         field
           (fun s -> String.is_substring s ~substring:core_lines)
           (equal_to true);
         field (fun _ -> contains "## Per-trade ratings") (equal_to true);
         field (fun _ -> contains "## Behavioural metrics") (equal_to true);
         field (fun _ -> contains "## Weinstein conformance") (equal_to true);
         field
           (fun _ ->
             contains "## Decision quality (cascade quartile vs outcome)")
           (equal_to true);
       ])

let test_to_markdown_zero_trades _ =
  let report = TAR.render ~trade_audit:[] ~trades:[] () in
  let md = TAR.to_markdown report in
  assert_that md
    (all_of
       [
         field
           (fun s -> String.is_substring s ~substring:"_No trades._")
           (equal_to true);
         field
           (fun s -> String.is_substring s ~substring:"- Total round-trips: 0")
           (equal_to true);
       ])

(* --- Split-safe floor basis (F6) --------------------------------------- *)

(* One audit record per supplied basis tag, each on a distinct symbol so the
   report's symbol-keyed audit index keeps them apart. *)
let _split_safe_records bases =
  List.mapi bases ~f:(fun i basis ->
      let symbol = sprintf "SYM%d" i in
      make_record
        (make_entry_decision ~symbol ~entry_date:(_date "2024-01-15")
           ~position_id:(symbol ^ "-1") ~split_safe_basis:basis ())
        (make_exit_decision ~symbol ~position_id:(symbol ^ "-1") ()))

(* Just the [## Split-safe floor basis] section, so that "this section renders
   no percentage" is a real assertion rather than one defeated by the "0.0%"
   win-rate that the header prints for a zero-trade fixture. Returns [""] when
   the section is absent, which fails every [contains] check below. *)
let _split_safe_section bases =
  let md =
    TAR.to_markdown
      (TAR.render ~trade_audit:(_split_safe_records bases) ~trades:[] ())
  in
  match
    String.split_lines md
    |> List.drop_while ~f:(fun l ->
        not (String.equal l "## Split-safe floor basis"))
  with
  | [] -> ""
  | heading :: rest ->
      let body =
        List.take_while rest ~f:(fun l ->
            not (String.is_prefix l ~prefix:"## "))
      in
      String.concat ~sep:"\n" (heading :: body)

let test_split_safe_renders_counts_and_inert_fraction _ =
  (* adjusted 3, raw_fallback 1, flag_off 1, empty_window 1. The fraction is
     raw_fallback / (raw_fallback + adjusted) = 1/4 = 25.0% — flag_off and
     empty_window sit in neither term. *)
  let section =
    _split_safe_section
      [
        TA.Adjusted;
        TA.Adjusted;
        TA.Adjusted;
        TA.Raw_fallback;
        TA.Flag_off;
        TA.Empty_window;
      ]
  in
  assert_that section
    (all_of
       [
         field
           (fun s ->
             String.is_substring s ~substring:"## Split-safe floor basis")
           (equal_to true);
         field
           (fun s ->
             String.is_substring s
               ~substring:
                 "- Basis of 6 entry decision(s): adjusted 3, raw_fallback 1, \
                  flag_off 1, empty_window 1")
           (equal_to true);
         field
           (fun s ->
             String.is_substring s
               ~substring:
                 "- Inert fraction (raw_fallback / (raw_fallback + adjusted)): \
                  25.0%")
           (equal_to true);
         field
           (fun s -> String.is_substring s ~substring:"NOT EXERCISED")
           (equal_to false);
       ])

let test_split_safe_not_exercised_flag_off_reads_as_wiring_alarm _ =
  (* Nothing reached the basis choice because the flag never reached the scan.
     Must not render as a percentage — "0.0%" here would be read as "the
     mechanism ran and never degraded", the opposite of the truth.

     An [Empty_window] is mixed in to pin the reporting priority: with both
     causes present the flag-off one is the louder signal and is the one
     named, per {!Backtest.Split_safe_metric.inertness}. *)
  let section =
    _split_safe_section [ TA.Flag_off; TA.Flag_off; TA.Empty_window ]
  in
  assert_that section
    (all_of
       [
         field
           (fun s -> String.is_substring s ~substring:"NOT EXERCISED")
           (equal_to true);
         field
           (fun s ->
             String.is_substring s
               ~substring:
                 "2 decision(s) carry flag_off, so none reached the basis \
                  choice")
           (equal_to true);
         field
           (fun s -> String.is_substring s ~substring:"wiring alarm")
           (equal_to true);
         field
           (fun s ->
             String.is_substring s ~substring:"lookback window(s) were empty")
           (equal_to false);
         (* No percentage anywhere in the section: a reader cannot mistake it
            for a wired-but-zero column. *)
         field (fun s -> String.is_substring s ~substring:"%") (equal_to false);
       ])

let test_split_safe_not_exercised_empty_window_reads_as_no_exposure _ =
  (* Same [Not_exercised] constructor as the flag-off case, different cause:
     the flag DID reach the scan. The two must not collapse into one string. *)
  let section =
    _split_safe_section [ TA.Empty_window; TA.Empty_window; TA.Empty_window ]
  in
  assert_that section
    (all_of
       [
         field
           (fun s -> String.is_substring s ~substring:"NOT EXERCISED")
           (equal_to true);
         field
           (fun s ->
             String.is_substring s
               ~substring:
                 "the flag reached the scan, but all 3 lookback window(s) were \
                  empty")
           (equal_to true);
         field
           (fun s -> String.is_substring s ~substring:"no exposure")
           (equal_to true);
         field
           (fun s -> String.is_substring s ~substring:"wiring alarm")
           (equal_to false);
         field (fun s -> String.is_substring s ~substring:"%") (equal_to false);
       ])

let test_split_safe_not_exercised_empty_population _ =
  (* No audit records at all: the section is still emitted (an omitted section
     is indistinguishable from an inert arm) and names the third cause. *)
  let section = _split_safe_section [] in
  assert_that section
    (all_of
       [
         field
           (fun s ->
             String.is_substring s
               ~substring:
                 "- Basis of 0 entry decision(s): adjusted 0, raw_fallback 0, \
                  flag_off 0, empty_window 0")
           (equal_to true);
         field
           (fun s ->
             String.is_substring s ~substring:"no entry decisions were captured")
           (equal_to true);
         field
           (fun s -> String.is_substring s ~substring:"wiring alarm")
           (equal_to false);
         field
           (fun s ->
             String.is_substring s ~substring:"lookback window(s) were empty")
           (equal_to false);
       ])

let test_split_safe_tally_counts_audit_population_not_rows _ =
  (* Three audit records, only one of which joins a round-trip. The basis tag
     lives on the entry decision, so all three are counted — a tally taken
     over [rows] would report 1. *)
  let records =
    _split_safe_records [ TA.Adjusted; TA.Adjusted; TA.Raw_fallback ]
  in
  let trade = make_trade ~symbol:"SYM0" ~entry_date:(_date "2024-01-15") () in
  let report = TAR.render ~trade_audit:records ~trades:[ trade ] () in
  assert_that report
    (all_of
       [
         field (fun (t : TAR.t) -> t.rows) (size_is 1);
         field
           (fun (t : TAR.t) -> t.split_safe_tally)
           (equal_to
              ({
                 flag_off = 0;
                 adjusted = 2;
                 raw_fallback = 1;
                 empty_window = 0;
               }
                : Backtest.Split_safe_metric.tally));
       ])

(* --- Loader (on-disk fixtures) ---------------------------------------- *)

let _write_text path text =
  Out_channel.with_file path ~f:(fun oc -> Out_channel.output_string oc text)

let _write_trades_csv path =
  _write_text path
    "symbol,entry_date,exit_date,days_held,entry_price,exit_price,quantity,pnl_dollars,pnl_percent,entry_stop,exit_stop,exit_trigger\n\
     AAPL,2020-04-25,2020-08-01,98,280.00,404.00,100,12400.00,44.20,260.00,400.00,signal_reversal\n\
     MSFT,2021-06-10,2021-11-20,163,250.00,340.00,200,18000.00,36.00,230.00,335.00,signal_reversal\n"

let _write_summary_sexp path =
  _write_text path
    "((start_date 2019-01-02) (end_date 2023-12-29) (universe_size 500)\n\
    \ (n_steps 1300) (initial_cash 1000000.00) (final_portfolio_value \
     1184900.00)\n\
    \ (n_round_trips 2) (metrics ()))\n"

let _write_audit_sexp path =
  let aapl_audit =
    make_record
      (make_entry_decision ~symbol:"AAPL" ~entry_date:(_date "2020-04-25")
         ~position_id:"AAPL-1" ~cascade_grade:Weinstein_types.A
         ~cascade_score:80 ())
      (make_exit_decision ~symbol:"AAPL" ~exit_date:(_date "2020-08-01")
         ~position_id:"AAPL-1"
         ~exit_trigger:
           (Backtest.Stop_log.Signal_reversal { description = "stage3" })
         ())
  in
  let sexp = TA.sexp_of_audit_records [ aapl_audit ] in
  Sexp.save_hum path sexp

let test_load_reads_full_directory _ =
  let dir = Core_unix.mkdtemp "/tmp/trade_audit_report_" in
  let scenario_dir = Filename.concat dir "my-scenario" in
  Core_unix.mkdir_p scenario_dir;
  _write_trades_csv (Filename.concat scenario_dir "trades.csv");
  _write_summary_sexp (Filename.concat scenario_dir "summary.sexp");
  _write_audit_sexp (Filename.concat scenario_dir "trade_audit.sexp");
  let report = TAR.load ~scenario_dir () in
  assert_that report
    (all_of
       [
         field
           (fun (t : TAR.t) -> t.header.scenario_name)
           (is_some_and (equal_to "my-scenario"));
         field
           (fun (t : TAR.t) -> t.header.universe_size)
           (is_some_and (equal_to 500));
         field (fun (t : TAR.t) -> t.header.total_round_trips) (equal_to 2);
         field (fun (t : TAR.t) -> t.header.winners) (equal_to 2);
         field
           (fun (t : TAR.t) ->
             List.map t.rows ~f:(fun (r : TAR.per_trade_row) -> r.symbol))
           (elements_are [ equal_to "AAPL"; equal_to "MSFT" ]);
         field
           (fun (t : TAR.t) ->
             List.find t.rows ~f:(fun (r : TAR.per_trade_row) ->
                 String.equal r.symbol "AAPL"))
           (is_some_and
              (field
                 (fun (r : TAR.per_trade_row) -> r.cascade_grade)
                 (is_some_and (equal_to Weinstein_types.A))));
       ])

let test_load_without_audit_file _ =
  let dir = Core_unix.mkdtemp "/tmp/trade_audit_report_" in
  let scenario_dir = Filename.concat dir "no-audit" in
  Core_unix.mkdir_p scenario_dir;
  _write_trades_csv (Filename.concat scenario_dir "trades.csv");
  _write_summary_sexp (Filename.concat scenario_dir "summary.sexp");
  let report = TAR.load ~scenario_dir () in
  assert_that report
    (all_of
       [
         field (fun (t : TAR.t) -> t.header.total_round_trips) (equal_to 2);
         field
           (fun (t : TAR.t) ->
             List.for_all t.rows ~f:(fun r -> Option.is_none r.cascade_grade))
           (equal_to true);
       ])

let test_load_missing_trades_csv_raises _ =
  let dir = Core_unix.mkdtemp "/tmp/trade_audit_report_" in
  let scenario_dir = Filename.concat dir "empty" in
  Core_unix.mkdir_p scenario_dir;
  let result =
    try
      let _ = TAR.load ~scenario_dir () in
      Ok ()
    with Failure _ -> Error "raised"
  in
  assert_that result (equal_to (Error "raised" : (unit, string) Result.t))

(* --- Loader: post-G2 13-column trades.csv -----------------------------

   The G2 contract adds a [side] column to trades.csv, with values [LONG]
   (Buy→Sell round-trip) and [SHORT] (Sell→Buy round-trip). The {!_canonical_post_g2_header}
   literal mirrors [Backtest.Result_writer._write_trades]'s header verbatim so
   schema drift on either side fails the parser tests below loudly. The legacy
   12-column tests above continue to exercise the fallback parser branch. *)

(** Mirror of [Backtest.Result_writer._write_trades]'s post-G2 header. M5.2e
    adds 6 trailing per-trade context columns (entry_stage, entry_volume_ratio,
    stop_initial_distance_pct, stop_trigger_kind, days_to_first_stop_trigger,
    screener_score_at_entry); the trades.csv export-join fix appends a trailing
    position_id column (kept last so positional readers stay valid). *)
let _canonical_post_g2_header =
  "symbol,side,entry_date,exit_date,days_held,entry_price,exit_price,quantity,pnl_dollars,pnl_percent,entry_stop,exit_stop,exit_trigger,entry_stage,entry_volume_ratio,stop_initial_distance_pct,stop_trigger_kind,days_to_first_stop_trigger,screener_score_at_entry,position_id"

(* AAPL LONG round-trip: bought at 280, sold at 404, +12 400 / +44.20%. *)
let _post_g2_long_row =
  "AAPL,LONG,2020-04-25,2020-08-01,98,280.00,404.00,100,12400.00,44.20,260.00,400.00,signal_reversal"

(* TSLA SHORT round-trip: shorted at 200, covered at 180, +1 000 / +10.00%. *)
let _post_g2_short_row =
  "TSLA,SHORT,2024-03-04,2024-04-08,35,200.00,180.00,50,1000.00,10.00,210.00,185.00,stop_loss"

let _stage_post_g2_scenario ~prefix ~rows =
  let dir = Core_unix.mkdtemp ("/tmp/trade_audit_report_" ^ prefix ^ "_") in
  let scenario_dir = Filename.concat dir "scenario" in
  Core_unix.mkdir_p scenario_dir;
  let csv =
    String.concat ~sep:"\n" (_canonical_post_g2_header :: rows) ^ "\n"
  in
  _write_text (Filename.concat scenario_dir "trades.csv") csv;
  _write_summary_sexp (Filename.concat scenario_dir "summary.sexp");
  scenario_dir

let test_load_post_g2_long_round_trip _ =
  let scenario_dir =
    _stage_post_g2_scenario ~prefix:"post_g2_long" ~rows:[ _post_g2_long_row ]
  in
  let report = TAR.load ~scenario_dir () in
  (* TAR.load builds [per_trade_row]s whose [side] is sourced from the
     trade-audit's [entry.side] when matched, OR defaulted to [Long] when no
     audit is present. With no audit staged, the row's [side] field cannot
     pin the LONG-vs-SHORT contract — the parser-level pin runs through the
     trade_metrics list returned by [_read_trades_csv], which the report
     surfaces only via header counts. We pin: 1 winner (LONG row had +pnl)
     and the parsed pnl + price fields exposed in [per_trade_row]. *)
  assert_that report
    (all_of
       [
         field (fun (t : TAR.t) -> t.header.total_round_trips) (equal_to 1);
         field (fun (t : TAR.t) -> t.header.winners) (equal_to 1);
         field
           (fun (t : TAR.t) -> t.rows)
           (elements_are
              [
                all_of
                  [
                    field
                      (fun (r : TAR.per_trade_row) -> r.symbol)
                      (equal_to "AAPL");
                    field
                      (fun (r : TAR.per_trade_row) -> r.entry_price)
                      (float_equal 280.00);
                    field
                      (fun (r : TAR.per_trade_row) -> r.exit_price)
                      (float_equal 404.00);
                    field
                      (fun (r : TAR.per_trade_row) -> r.pnl_dollars)
                      (float_equal 12_400.00);
                  ];
              ]);
       ])

let test_load_post_g2_short_round_trip _ =
  let scenario_dir =
    _stage_post_g2_scenario ~prefix:"post_g2_short" ~rows:[ _post_g2_short_row ]
  in
  let report = TAR.load ~scenario_dir () in
  (* SHORT row produces a positive pnl (covered below entry). The [side] field
     in the parsed [trade_metrics] is [Sell] — see the parallel pin in
     [test_optimal_run_artefacts.ml]. Here we pin the row-level fields surfaced
     by the report. *)
  assert_that report
    (all_of
       [
         field (fun (t : TAR.t) -> t.header.total_round_trips) (equal_to 1);
         field (fun (t : TAR.t) -> t.header.winners) (equal_to 1);
         field
           (fun (t : TAR.t) -> t.rows)
           (elements_are
              [
                all_of
                  [
                    field
                      (fun (r : TAR.per_trade_row) -> r.symbol)
                      (equal_to "TSLA");
                    field
                      (fun (r : TAR.per_trade_row) -> r.entry_price)
                      (float_equal 200.00);
                    field
                      (fun (r : TAR.per_trade_row) -> r.exit_price)
                      (float_equal 180.00);
                    field
                      (fun (r : TAR.per_trade_row) -> r.pnl_dollars)
                      (float_equal 1_000.00);
                    field
                      (fun (r : TAR.per_trade_row) -> r.pnl_percent)
                      (float_equal 10.00);
                  ];
              ]);
       ])

let test_load_post_g2_mixed_long_and_short _ =
  let scenario_dir =
    _stage_post_g2_scenario ~prefix:"post_g2_mixed"
      ~rows:[ _post_g2_long_row; _post_g2_short_row ]
  in
  let report = TAR.load ~scenario_dir () in
  (* Both rows must parse and surface in entry-date order. *)
  assert_that report
    (all_of
       [
         field (fun (t : TAR.t) -> t.header.total_round_trips) (equal_to 2);
         field (fun (t : TAR.t) -> t.header.winners) (equal_to 2);
         field
           (fun (t : TAR.t) -> t.rows)
           (elements_are
              [
                field
                  (fun (r : TAR.per_trade_row) -> r.symbol)
                  (equal_to "AAPL");
                field
                  (fun (r : TAR.per_trade_row) -> r.symbol)
                  (equal_to "TSLA");
              ]);
       ])

(* --- Writer -> reader round-trip --------------------------------------

   The strongest CP2 closure: stage a [Runner.result] with one LONG and one
   SHORT round-trip, write it via the canonical [Result_writer.write], and
   read the resulting [trades.csv] back via [TAR.load]. Pins both sides of
   the on-disk contract at once — schema drift on either fails this test. *)

let _make_runner_result ~start_date ~end_date ~round_trips :
    Backtest.Runner.result =
  {
    summary =
      {
        start_date;
        end_date;
        universe_size = 2;
        n_steps = 1;
        initial_cash = 10_000.0;
        final_portfolio_value =
          10_000.0
          +. List.fold round_trips ~init:0.0
               ~f:(fun acc (t : Trading_simulation.Metrics.trade_metrics) ->
                 acc +. t.pnl_dollars);
        n_round_trips = List.length round_trips;
        stale_held_symbols = [];
        metrics = Trading_simulation_types.Metric_types.empty;
      };
    round_trips;
    steps = [];
    final_portfolio =
      Trading_portfolio.Portfolio.create ~initial_cash:10_000.0 ();
    n_stop_eligible_positions = 0;
    overrides = [];
    stop_infos = [];
    audit = [];
    cascade_summaries = [];
    force_liquidations = [];
    stale_holds = [];
    final_prices = [];
    universe = [];
  }

let test_writer_reader_post_g2_round_trip _ =
  let dir = Core_unix.mkdtemp "/tmp/trade_audit_report_writer_" in
  let long_trip : Trading_simulation.Metrics.trade_metrics =
    {
      symbol = "AAPL";
      side = Trading_base.Types.Buy;
      entry_date = _date "2024-01-15";
      exit_date = _date "2024-02-20";
      days_held = 36;
      entry_price = 150.00;
      exit_price = 165.00;
      quantity = 10.0;
      pnl_dollars = 150.00;
      pnl_percent = 10.00;
    }
  in
  let short_trip : Trading_simulation.Metrics.trade_metrics =
    {
      symbol = "TSLA";
      side = Trading_base.Types.Sell;
      entry_date = _date "2024-03-04";
      exit_date = _date "2024-04-08";
      days_held = 35;
      entry_price = 200.00;
      exit_price = 180.00;
      quantity = 5.0;
      pnl_dollars = 100.00;
      pnl_percent = 10.00;
    }
  in
  let result =
    _make_runner_result ~start_date:(_date "2024-01-01")
      ~end_date:(_date "2024-04-30") ~round_trips:[ long_trip; short_trip ]
  in
  Backtest.Result_writer.write ~output_dir:dir result;
  (* Pin: writer emitted the canonical post-G2 header verbatim. Schema drift on
     the writer side fails this string match. *)
  let trades_csv_path = Filename.concat dir "trades.csv" in
  let lines = In_channel.read_lines trades_csv_path in
  let header_line = List.hd_exn lines in
  assert_that header_line (equal_to _canonical_post_g2_header);
  (* Reader parses both rows back. The report aggregates over [trade_metrics]
     where [side] survives intact; we pin via the header counts (both winners)
     and the ordered symbol list. *)
  let report = TAR.load ~scenario_dir:dir () in
  assert_that report
    (all_of
       [
         field (fun (t : TAR.t) -> t.header.total_round_trips) (equal_to 2);
         field (fun (t : TAR.t) -> t.header.winners) (equal_to 2);
         field
           (fun (t : TAR.t) -> t.rows)
           (elements_are
              [
                all_of
                  [
                    field
                      (fun (r : TAR.per_trade_row) -> r.symbol)
                      (equal_to "AAPL");
                    field
                      (fun (r : TAR.per_trade_row) -> r.pnl_dollars)
                      (float_equal 150.00);
                  ];
                all_of
                  [
                    field
                      (fun (r : TAR.per_trade_row) -> r.symbol)
                      (equal_to "TSLA");
                    field
                      (fun (r : TAR.per_trade_row) -> r.pnl_dollars)
                      (float_equal 100.00);
                  ];
              ]);
       ])

(* --- Join tolerance + blob-format load (resurrection regression) -------

   Two latent breaks kept this report from working on real runs:
   (1) the loader read a bare [audit_record list] but the runner persists a
       full [audit_blob] envelope; and
   (2) the audit<->round-trip join was an exact (symbol, entry_date) match, but
       the audit carries the Friday decision date while trades.csv carries the
       next-trading-day fill, so ~every trade failed to join and the entire
       analysis layer (ratings / behavioural / Weinstein) rendered empty.
   These tests pin both fixes. *)

let test_row_matches_audit_with_off_by_one_date _ =
  (* trades.csv fill date (Mon) is 3 days after the audit's Friday decision
     date; the tolerant join must still attach the audit fields. *)
  let trade = make_trade ~symbol:"AAPL" ~entry_date:(_date "2024-01-15") () in
  let entry =
    make_entry_decision ~symbol:"AAPL" ~entry_date:(_date "2024-01-12")
      ~cascade_grade:Weinstein_types.A ~cascade_score:75 ()
  in
  let record = make_record entry (make_exit_decision ()) in
  let report = TAR.render ~trade_audit:[ record ] ~trades:[ trade ] () in
  assert_that report.rows
    (elements_are
       [
         field
           (fun (r : TAR.per_trade_row) -> r.cascade_grade)
           (is_some_and (equal_to Weinstein_types.A));
       ])

let test_analysis_nonempty_with_off_by_one_date _ =
  (* The key regression: with the off-by-one fill date, [rate_all] must still
     match the audit so [analysis] is populated (was silently [None]). *)
  let trade = make_trade ~symbol:"AAPL" ~entry_date:(_date "2024-01-15") () in
  let entry =
    make_entry_decision ~symbol:"AAPL" ~entry_date:(_date "2024-01-12") ()
  in
  let record = make_record entry (make_exit_decision ()) in
  let report = TAR.render ~trade_audit:[ record ] ~trades:[ trade ] () in
  assert_that report.analysis
    (is_some_and (field (fun (a : TAR.analysis) -> a.ratings) (size_is 1)))

let _write_blob_audit_sexp path =
  let aapl =
    make_record
      (make_entry_decision ~symbol:"AAPL" ~entry_date:(_date "2020-04-25")
         ~position_id:"AAPL-1" ~cascade_grade:Weinstein_types.A
         ~cascade_score:80 ())
      (make_exit_decision ~symbol:"AAPL" ~exit_date:(_date "2020-08-01")
         ~position_id:"AAPL-1" ())
  in
  let blob : TA.audit_blob =
    { audit_records = [ aapl ]; cascade_summaries = [] }
  in
  Sexp.save_hum path (TA.sexp_of_audit_blob blob)

let test_load_reads_blob_format_audit _ =
  (* The runner persists the [audit_blob] envelope; the loader must parse it
     (not only the legacy bare-list format). *)
  let dir = Core_unix.mkdtemp "/tmp/trade_audit_report_" in
  let scenario_dir = Filename.concat dir "blob-scenario" in
  Core_unix.mkdir_p scenario_dir;
  _write_trades_csv (Filename.concat scenario_dir "trades.csv");
  _write_summary_sexp (Filename.concat scenario_dir "summary.sexp");
  _write_blob_audit_sexp (Filename.concat scenario_dir "trade_audit.sexp");
  let report = TAR.load ~scenario_dir () in
  assert_that report
    (field
       (fun (t : TAR.t) ->
         List.find t.rows ~f:(fun (r : TAR.per_trade_row) ->
             String.equal r.symbol "AAPL"))
       (is_some_and
          (field
             (fun (r : TAR.per_trade_row) -> r.cascade_grade)
             (is_some_and (equal_to Weinstein_types.A)))))

let suite =
  "Trade_audit_report"
  >::: [
         "row matches audit with off-by-one date"
         >:: test_row_matches_audit_with_off_by_one_date;
         "analysis non-empty with off-by-one date"
         >:: test_analysis_nonempty_with_off_by_one_date;
         "load reads blob-format audit" >:: test_load_reads_blob_format_audit;
         "header counts winners and losers"
         >:: test_header_counts_winners_and_losers;
         "header empty trades" >:: test_header_empty_trades;
         "header period derived from trades"
         >:: test_header_period_derived_from_trades;
         "header uses supplied period" >:: test_header_uses_supplied_period;
         "best/worst picks extremes" >:: test_best_worst_picks_extremes;
         "best/worst empty" >:: test_best_worst_empty;
         "row has audit fields when matched"
         >:: test_row_has_audit_fields_when_matched;
         "row has none audit fields when unmatched"
         >:: test_row_has_none_audit_fields_when_unmatched;
         "row has execution fields when present"
         >:: test_row_has_execution_fields_when_present;
         "row execution fields none when absent"
         >:: test_row_execution_fields_none_when_absent;
         "markdown renders execution columns"
         >:: test_markdown_renders_execution_columns;
         "execution summary math" >:: test_execution_summary_math;
         "aggregate byte-path unchanged without execution"
         >:: test_aggregate_byte_path_unchanged_without_execution;
         "row falls back to external exit trigger"
         >:: test_row_falls_back_to_external_exit_trigger;
         "row prefers enriched exit over external"
         >:: test_row_prefers_enriched_exit_over_external;
         "row empty trigger when no exit and no external"
         >:: test_row_empty_trigger_when_no_exit_and_no_external;
         "row external exit generic label (stage3_force_exit)"
         >:: test_row_external_exit_generic_label;
         "markdown renders external exit trigger"
         >:: test_markdown_renders_external_exit_trigger;
         "rows sorted by entry_date" >:: test_rows_sorted_by_entry_date;
         "to_markdown pinned three-trade fixture"
         >:: test_to_markdown_pinned_three_trade_fixture;
         "to_markdown zero trades" >:: test_to_markdown_zero_trades;
         "split-safe renders counts and inert fraction"
         >:: test_split_safe_renders_counts_and_inert_fraction;
         "split-safe not exercised: flag_off reads as wiring alarm"
         >:: test_split_safe_not_exercised_flag_off_reads_as_wiring_alarm;
         "split-safe not exercised: empty_window reads as no exposure"
         >:: test_split_safe_not_exercised_empty_window_reads_as_no_exposure;
         "split-safe not exercised: empty population"
         >:: test_split_safe_not_exercised_empty_population;
         "split-safe tally counts audit population not rows"
         >:: test_split_safe_tally_counts_audit_population_not_rows;
         "load reads full directory" >:: test_load_reads_full_directory;
         "load without audit file" >:: test_load_without_audit_file;
         "load missing trades.csv raises"
         >:: test_load_missing_trades_csv_raises;
         "load post-G2 LONG round-trip" >:: test_load_post_g2_long_round_trip;
         "load post-G2 SHORT round-trip" >:: test_load_post_g2_short_round_trip;
         "load post-G2 mixed LONG and SHORT"
         >:: test_load_post_g2_mixed_long_and_short;
         "writer -> reader post-G2 round-trip"
         >:: test_writer_reader_post_g2_round_trip;
       ]

let () = run_test_tt_main suite
