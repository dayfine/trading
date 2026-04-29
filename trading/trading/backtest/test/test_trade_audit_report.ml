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
    ?(cascade_grade = Weinstein_types.A) () : TA.entry_decision =
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

let make_record entry exit_ : TA.audit_record = { entry; exit_ = Some exit_ }

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
         | pnl_$ | pnl_% | exit_trigger | stage | rs | macro | grade | score |";
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
  let report = TAR.load ~scenario_dir in
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
  let report = TAR.load ~scenario_dir in
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
      let _ = TAR.load ~scenario_dir in
      Ok ()
    with Failure _ -> Error "raised"
  in
  assert_that result (equal_to (Error "raised" : (unit, string) Result.t))

let suite =
  "Trade_audit_report"
  >::: [
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
         "rows sorted by entry_date" >:: test_rows_sorted_by_entry_date;
         "to_markdown pinned three-trade fixture"
         >:: test_to_markdown_pinned_three_trade_fixture;
         "to_markdown zero trades" >:: test_to_markdown_zero_trades;
         "load reads full directory" >:: test_load_reads_full_directory;
         "load without audit file" >:: test_load_without_audit_file;
         "load missing trades.csv raises"
         >:: test_load_missing_trades_csv_raises;
       ]

let () = run_test_tt_main suite
