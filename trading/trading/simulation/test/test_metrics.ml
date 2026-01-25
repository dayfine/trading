open OUnit2
open Core
open Trading_simulation.Metrics
open Trading_simulation_types.Metric_types
open Trading_simulation.Metric_computers
open Trading_simulation.Simulator
open Matchers

let date_of_string s = Date.of_string s

(** Helper to run metric computers over steps and merge results *)
let run_computers ~computers ~config ~steps =
  List.fold computers ~init:empty ~f:(fun acc (c : any_metric_computer) ->
      merge acc (c.run ~config ~steps))

(* ==================== Metric Set Tests ==================== *)

let test_singleton _ =
  let metrics = singleton SharpeRatio 1.5 in
  assert_that (Map.find metrics SharpeRatio) (is_some_and (float_equal 1.5))

let test_of_alist_exn _ =
  let metrics =
    of_alist_exn [ (TotalPnl, 100.0); (SharpeRatio, 1.5); (MaxDrawdown, 5.0) ]
  in
  assert_that (Map.find metrics TotalPnl) (is_some_and (float_equal 100.0));
  assert_that (Map.find metrics SharpeRatio) (is_some_and (float_equal 1.5));
  assert_that (Map.find metrics MaxDrawdown) (is_some_and (float_equal 5.0))

let test_merge _ =
  let m1 = of_alist_exn [ (TotalPnl, 100.0); (SharpeRatio, 1.0) ] in
  let m2 = of_alist_exn [ (SharpeRatio, 2.0); (MaxDrawdown, 5.0) ] in
  let merged = merge m1 m2 in
  (* TotalPnl from m1 *)
  assert_that (Map.find merged TotalPnl) (is_some_and (float_equal 100.0));
  (* SharpeRatio overwritten by m2 *)
  assert_that (Map.find merged SharpeRatio) (is_some_and (float_equal 2.0));
  (* MaxDrawdown from m2 *)
  assert_that (Map.find merged MaxDrawdown) (is_some_and (float_equal 5.0))

(* ==================== Format Tests ==================== *)

let test_format_metric_dollars _ =
  assert_that (format_metric TotalPnl 1234.56) (equal_to "Total P&L: $1234.56")

let test_format_metric_percent _ =
  assert_that (format_metric WinRate 75.5) (equal_to "Win Rate: 75.50%")

let test_format_metric_days _ =
  assert_that
    (format_metric AvgHoldingDays 12.5)
    (equal_to "Avg Holding Period: 12.5 days")

let test_format_metric_count _ =
  assert_that (format_metric WinCount 42.0) (equal_to "Winning Trades: 42")

let test_format_metric_ratio _ =
  assert_that
    (format_metric SharpeRatio 1.2345)
    (equal_to "Sharpe Ratio: 1.2345")

let test_format_metrics_multiple _ =
  let metrics = of_alist_exn [ (TotalPnl, 100.0); (WinRate, 50.0) ] in
  let s = format_metrics metrics in
  assert_bool "contains Total P&L"
    (String.is_substring s ~substring:"Total P&L");
  assert_bool "contains Win Rate" (String.is_substring s ~substring:"Win Rate")

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
  assert_that (Map.length metrics) (equal_to 5);
  assert_that (Map.find metrics TotalPnl) (is_some_and (float_equal 1500.0));
  assert_that (Map.find metrics WinRate) (is_some_and (float_equal 70.0));
  assert_that (Map.find metrics WinCount) (is_some_and (float_equal 7.0));
  assert_that (Map.find metrics LossCount) (is_some_and (float_equal 3.0));
  assert_that (Map.find metrics AvgHoldingDays) (is_some_and (float_equal 5.5))

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
  assert_that (Map.find metrics SharpeRatio) (is_some_and (float_equal 0.0))

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
  assert_that (Map.find metrics SharpeRatio) (is_some_and (float_equal 0.0))

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
  assert_that (Map.find metrics SharpeRatio) (is_some_and (float_equal 0.0))

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
  (* Consistent ~1% daily gains yield high Sharpe due to low volatility *)
  assert_that
    (Map.find metrics SharpeRatio)
    (is_some_and (float_equal ~epsilon:100.0 1963.0))

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
  (* Consistent ~1% daily losses yield negative Sharpe with low volatility *)
  assert_that
    (Map.find metrics SharpeRatio)
    (is_some_and (float_equal ~epsilon:100.0 (-1925.0)))

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
  let sharpe_no_rf = Map.find_exn metrics_no_rf SharpeRatio in
  let sharpe_with_rf = Map.find_exn metrics_with_rf SharpeRatio in
  assert_bool "Sharpe with RF should be lower than without"
    Float.(sharpe_with_rf < sharpe_no_rf)

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
  assert_that (Map.find metrics MaxDrawdown) (is_some_and (float_equal 0.0))

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
  assert_that (Map.find metrics MaxDrawdown) (is_some_and (float_equal 10.0))

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
  assert_that (Map.find metrics MaxDrawdown) (is_some_and (float_equal 20.0))

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
  assert_that (Map.find metrics MaxDrawdown) (is_some_and (float_equal 10.0))

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
  assert_that (Map.is_empty metrics) (equal_to true)

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
  assert_that (Map.length metrics) (equal_to 2);
  (* Sharpe: 1% gain then ~1% loss, near-zero mean return *)
  assert_that
    (Map.find metrics SharpeRatio)
    (is_some_and (float_equal ~epsilon:1.0 0.0));
  (* Max drawdown: peak 10100 -> 10000 = 0.99% decline *)
  assert_that
    (Map.find metrics MaxDrawdown)
    (is_some_and (float_equal ~epsilon:0.01 0.99))

let test_default_computers _ =
  let computers = default_computers () in
  (* Default set: summary_computer, sharpe_ratio_computer, max_drawdown_computer *)
  assert_that computers (size_is 3)

(* ==================== Factory Tests ==================== *)

let test_create_computer_sharpe _ =
  let computer = create_computer SharpeRatio in
  let config = make_config () in
  let steps = [] in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that (Map.length metrics) (equal_to 1);
  assert_that (Map.find metrics SharpeRatio) (is_some_and (float_equal 0.0))

let test_create_computer_max_drawdown _ =
  let computer = create_computer MaxDrawdown in
  let config = make_config () in
  let steps = [] in
  let metrics = run_computers ~computers:[ computer ] ~config ~steps in
  assert_that (Map.length metrics) (equal_to 1);
  assert_that (Map.find metrics MaxDrawdown) (is_some_and (float_equal 0.0))

(* ==================== Test Suite ==================== *)

let suite =
  "Metrics Tests"
  >::: [
         (* Metric set tests *)
         "singleton" >:: test_singleton;
         "of_alist_exn" >:: test_of_alist_exn;
         "merge" >:: test_merge;
         (* Format tests *)
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
