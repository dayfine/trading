open OUnit2
open Core
open Trading_simulation.Metrics
open Trading_simulation.Metric_types
open Trading_simulation.Metric_computers
open Trading_simulation.Simulator
open Matchers

let date_of_string s = Date.of_string s

(** Helper to run metric computers over steps (run_computers is internal) *)
let run_computers ~computers ~config ~steps =
  List.concat_map computers ~f:(fun (c : any_metric_computer) ->
      c.run ~config ~steps)

(* ==================== Type Derivations Tests ==================== *)

let test_metric_type_show _ =
  assert_that (show_metric_type TotalPnl) (equal_to "Metric_types.TotalPnl");
  assert_that
    (show_metric_type SharpeRatio)
    (equal_to "Metric_types.SharpeRatio");
  assert_that
    (show_metric_type MaxDrawdown)
    (equal_to "Metric_types.MaxDrawdown")

let test_metric_type_eq _ =
  assert_that (equal_metric_type TotalPnl TotalPnl) (equal_to true);
  assert_that (equal_metric_type TotalPnl SharpeRatio) (equal_to false)

let test_metric_show _ =
  let m = make_metric SharpeRatio 1.5 in
  let s = show_metric m in
  assert_bool "show_metric includes name"
    (String.is_substring s ~substring:"sharpe_ratio");
  assert_bool "show_metric includes value"
    (String.is_substring s ~substring:"1.5")

let test_metric_eq _ =
  let m1 = make_metric SharpeRatio 1.0 in
  let m2 = make_metric SharpeRatio 2.0 in
  assert_that (equal_metric m1 m1) (equal_to true);
  assert_that (equal_metric m1 m2) (equal_to false)

(* ==================== Utility Function Tests ==================== *)

let test_find_metric_found _ =
  let metrics = [ make_metric TotalPnl 1.0; make_metric SharpeRatio 2.0 ] in
  assert_that
    (find_metric metrics ~name:"sharpe_ratio")
    (is_some_and (fun m -> assert_that m.value (float_equal 2.0)))

let test_find_metric_not_found _ =
  let metrics = [ make_metric TotalPnl 1.0 ] in
  assert_that (find_metric metrics ~name:"nonexistent") is_none

let test_format_metric_dollars _ =
  let m = make_metric TotalPnl 1234.56 in
  assert_that (format_metric m) (equal_to "Total P&L: $1234.56")

let test_format_metric_percent _ =
  let m = make_metric WinRate 75.5 in
  assert_that (format_metric m) (equal_to "Win Rate: 75.50%")

let test_format_metric_days _ =
  let m = make_metric AvgHoldingDays 12.5 in
  assert_that (format_metric m) (equal_to "Avg Holding Period: 12.5 days")

let test_format_metric_count _ =
  let m = make_metric WinCount 42.0 in
  assert_that (format_metric m) (equal_to "Winning Trades: 42")

let test_format_metric_ratio _ =
  let m = make_metric SharpeRatio 1.2345 in
  assert_that (format_metric m) (equal_to "Sharpe Ratio: 1.2345")

let test_format_metrics_multiple _ =
  let metrics = [ make_metric TotalPnl 100.0; make_metric WinRate 50.0 ] in
  let s = format_metrics metrics in
  assert_bool "contains Total P&L"
    (String.is_substring s ~substring:"Total P&L");
  assert_bool "contains Win Rate" (String.is_substring s ~substring:"Win Rate");
  assert_bool "contains newline" (String.is_substring s ~substring:"\n")

(* ==================== Summary Stats Conversion Tests ==================== *)

let test_summary_stats_to_metrics _ =
  let stats =
    {
      total_pnl = 1500.0;
      avg_holding_days = 5.5;
      win_count = 7;
      loss_count = 3;
      win_rate = 70.0;
    }
  in
  let metrics = summary_stats_to_metrics stats in
  assert_that metrics (size_is 5);
  assert_that
    (find_metric metrics ~name:"total_pnl")
    (is_some_and (fun m ->
         assert_that m.value (float_equal 1500.0);
         assert_that m.metric_type (equal_to (TotalPnl : metric_type))));
  assert_that
    (find_metric metrics ~name:"win_rate")
    (is_some_and (fun m ->
         assert_that m.value (float_equal 70.0);
         assert_that m.metric_type (equal_to (WinRate : metric_type))))

(* ==================== Metric Computer Tests ==================== *)

(* Helper to create a mock step_result *)
let make_step_result ~date ~portfolio_value =
  let portfolio = Trading_portfolio.Portfolio.create ~initial_cash:10000.0 () in
  { date; portfolio; portfolio_value; trades = []; orders_submitted = [] }

let make_config () =
  {
    start_date = date_of_string "2024-01-01";
    end_date = date_of_string "2024-01-10";
    initial_cash = 10000.0;
    commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 };
  }

(* ==================== Sharpe Ratio Tests ==================== *)

let test_sharpe_ratio_zero_with_no_data _ =
  let config = make_config () in
  let computer = sharpe_ratio_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps:[] in
  assert_that
    (find_metric metrics ~name:"sharpe_ratio")
    (is_some_and (fun m -> assert_that m.value (float_equal 0.0)))

let test_sharpe_ratio_zero_with_single_point _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
    ]
  in
  let computer = sharpe_ratio_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that
    (find_metric metrics ~name:"sharpe_ratio")
    (is_some_and (fun m -> assert_that m.value (float_equal 0.0)))

let test_sharpe_ratio_zero_with_constant_value _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio_value:10000.0;
    ]
  in
  let computer = sharpe_ratio_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that
    (find_metric metrics ~name:"sharpe_ratio")
    (is_some_and (fun m -> assert_that m.value (float_equal 0.0)))

let test_sharpe_ratio_positive_with_gains _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio_value:10100.0;
      make_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio_value:10200.0;
      make_step_result
        ~date:(date_of_string "2024-01-04")
        ~portfolio_value:10300.0;
    ]
  in
  let computer = sharpe_ratio_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that
    (find_metric metrics ~name:"sharpe_ratio")
    (is_some_and (fun m ->
         assert_bool "Sharpe should be positive" Float.(m.value > 0.0)))

let test_sharpe_ratio_negative_with_losses _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio_value:9900.0;
      make_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio_value:9800.0;
      make_step_result
        ~date:(date_of_string "2024-01-04")
        ~portfolio_value:9700.0;
    ]
  in
  let computer = sharpe_ratio_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that
    (find_metric metrics ~name:"sharpe_ratio")
    (is_some_and (fun m ->
         assert_bool "Sharpe should be negative" Float.(m.value < 0.0)))

let test_sharpe_ratio_with_risk_free_rate _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio_value:10100.0;
      make_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio_value:10200.0;
    ]
  in
  let computer_no_rf = sharpe_ratio_computer () in
  let computer_with_rf = sharpe_ratio_computer ~risk_free_rate:0.05 () in
  let metrics_no_rf =
    run_computers ~computers:[ computer_no_rf ] ~config ~steps
  in
  let metrics_with_rf =
    run_computers ~computers:[ computer_with_rf ] ~config ~steps
  in
  let sharpe_no_rf =
    Option.value_exn (find_metric metrics_no_rf ~name:"sharpe_ratio")
  in
  let sharpe_with_rf =
    Option.value_exn (find_metric metrics_with_rf ~name:"sharpe_ratio")
  in
  assert_bool "Sharpe with RF should be lower than without"
    Float.(sharpe_with_rf.value < sharpe_no_rf.value)

(* ==================== Maximum Drawdown Tests ==================== *)

let test_max_drawdown_zero_with_no_decline _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio_value:10100.0;
      make_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio_value:10200.0;
    ]
  in
  let computer = max_drawdown_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that
    (find_metric metrics ~name:"max_drawdown")
    (is_some_and (fun m -> assert_that m.value (float_equal 0.0)))

let test_max_drawdown_captures_decline _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio_value:11000.0;
      make_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio_value:9900.0;
    ]
  in
  let computer = max_drawdown_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that
    (find_metric metrics ~name:"max_drawdown")
    (is_some_and (fun m -> assert_that m.value (float_equal 10.0)))

let test_max_drawdown_captures_largest _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio_value:9500.0;
      make_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio_value:12000.0;
      make_step_result
        ~date:(date_of_string "2024-01-04")
        ~portfolio_value:9600.0;
    ]
  in
  let computer = max_drawdown_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that
    (find_metric metrics ~name:"max_drawdown")
    (is_some_and (fun m -> assert_that m.value (float_equal 20.0)))

let test_max_drawdown_with_recovery _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio_value:9000.0;
      make_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio_value:10500.0;
      make_step_result
        ~date:(date_of_string "2024-01-04")
        ~portfolio_value:10500.0;
    ]
  in
  let computer = max_drawdown_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that
    (find_metric metrics ~name:"max_drawdown")
    (is_some_and (fun m -> assert_that m.value (float_equal 10.0)))

(* ==================== Summary Computer Tests ==================== *)

let test_summary_computer_with_no_trades _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
    ]
  in
  let computer = summary_computer () in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that metrics is_empty

(* ==================== Multiple Computers Tests ==================== *)

let test_run_computers_combines_results _ =
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio_value:10100.0;
      make_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio_value:10000.0;
    ]
  in
  let computers = [ sharpe_ratio_computer (); max_drawdown_computer () ] in
  let metrics = run_computers ~computers ~config ~steps in
  assert_that
    (find_metric metrics ~name:"sharpe_ratio")
    (is_some_and (fun _ -> ()));
  assert_that
    (find_metric metrics ~name:"max_drawdown")
    (is_some_and (fun _ -> ()))

let test_default_computers _ =
  let computers = default_computers () in
  assert_that computers (size_is 3)

(* ==================== Factory Tests ==================== *)

let test_create_computer_sharpe _ =
  let computer = create_computer SharpeRatio in
  let config = make_config () in
  let steps = [] in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that
    (find_metric metrics ~name:"sharpe_ratio")
    (is_some_and (fun m -> assert_that m.value (float_equal 0.0)))

let test_create_computer_max_drawdown _ =
  let computer = create_computer MaxDrawdown in
  let config = make_config () in
  let steps = [] in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that
    (find_metric metrics ~name:"max_drawdown")
    (is_some_and (fun m -> assert_that m.value (float_equal 0.0)))

(* ==================== Test Suite ==================== *)

let suite =
  "Metrics Tests"
  >::: [
         (* Type derivation tests *)
         "metric_type show" >:: test_metric_type_show;
         "metric_type eq" >:: test_metric_type_eq;
         "metric show" >:: test_metric_show;
         "metric eq" >:: test_metric_eq;
         (* Utility function tests *)
         "find_metric found" >:: test_find_metric_found;
         "find_metric not found" >:: test_find_metric_not_found;
         "format_metric dollars" >:: test_format_metric_dollars;
         "format_metric percent" >:: test_format_metric_percent;
         "format_metric days" >:: test_format_metric_days;
         "format_metric count" >:: test_format_metric_count;
         "format_metric ratio" >:: test_format_metric_ratio;
         "format_metrics multiple" >:: test_format_metrics_multiple;
         (* Summary stats conversion *)
         "summary_stats_to_metrics" >:: test_summary_stats_to_metrics;
         (* Sharpe ratio tests *)
         "sharpe ratio zero with no data"
         >:: test_sharpe_ratio_zero_with_no_data;
         "sharpe ratio zero with single point"
         >:: test_sharpe_ratio_zero_with_single_point;
         "sharpe ratio zero with constant value"
         >:: test_sharpe_ratio_zero_with_constant_value;
         "sharpe ratio positive with gains"
         >:: test_sharpe_ratio_positive_with_gains;
         "sharpe ratio negative with losses"
         >:: test_sharpe_ratio_negative_with_losses;
         "sharpe ratio with risk free rate"
         >:: test_sharpe_ratio_with_risk_free_rate;
         (* Max drawdown tests *)
         "max drawdown zero with no decline"
         >:: test_max_drawdown_zero_with_no_decline;
         "max drawdown captures decline" >:: test_max_drawdown_captures_decline;
         "max drawdown captures largest" >:: test_max_drawdown_captures_largest;
         "max drawdown with recovery" >:: test_max_drawdown_with_recovery;
         (* Summary computer tests *)
         "summary computer with no trades"
         >:: test_summary_computer_with_no_trades;
         (* Multiple computers tests *)
         "run_computers combines results"
         >:: test_run_computers_combines_results;
         "default_computers" >:: test_default_computers;
         (* Factory tests *)
         "create_computer SharpeRatio" >:: test_create_computer_sharpe;
         "create_computer MaxDrawdown" >:: test_create_computer_max_drawdown;
       ]

let () = run_test_tt_main suite
