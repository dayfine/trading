open OUnit2
open Core
open Trading_simulation.Metrics
open Trading_simulation.Metric_types
open Trading_simulation.Metric_computers
open Trading_simulation.Simulator
open Matchers

let date_of_string s = Date.of_string s

(* ==================== Type Derivations Tests ==================== *)

let test_metric_unit_show _ =
  assert_that (show_metric_unit Dollars) (equal_to "Metric_types.Dollars");
  assert_that (show_metric_unit Percent) (equal_to "Metric_types.Percent");
  assert_that (show_metric_unit Days) (equal_to "Metric_types.Days");
  assert_that (show_metric_unit Count) (equal_to "Metric_types.Count");
  assert_that (show_metric_unit Ratio) (equal_to "Metric_types.Ratio")

let test_metric_unit_eq _ =
  assert_that (equal_metric_unit Dollars Dollars) (equal_to true);
  assert_that (equal_metric_unit Dollars Percent) (equal_to false)

let test_metric_show _ =
  let m =
    {
      name = "test";
      display_name = "Test Metric";
      description = "A test";
      value = 42.5;
      unit = Dollars;
    }
  in
  let s = show_metric m in
  assert_bool "show_metric includes name"
    (String.is_substring s ~substring:"test");
  assert_bool "show_metric includes value"
    (String.is_substring s ~substring:"42.5")

let test_metric_eq _ =
  let m1 =
    {
      name = "test";
      display_name = "Test";
      description = "desc";
      value = 1.0;
      unit = Dollars;
    }
  in
  let m2 = { m1 with value = 2.0 } in
  assert_that (equal_metric m1 m1) (equal_to true);
  assert_that (equal_metric m1 m2) (equal_to false)

(* ==================== Utility Function Tests ==================== *)

let test_find_metric_found _ =
  let metrics =
    [
      {
        name = "a";
        display_name = "A";
        description = "";
        value = 1.0;
        unit = Count;
      };
      {
        name = "b";
        display_name = "B";
        description = "";
        value = 2.0;
        unit = Count;
      };
    ]
  in
  assert_that
    (find_metric metrics ~name:"b")
    (is_some_and (fun m -> assert_that m.value (float_equal 2.0)))

let test_find_metric_not_found _ =
  let metrics =
    [
      {
        name = "a";
        display_name = "A";
        description = "";
        value = 1.0;
        unit = Count;
      };
    ]
  in
  assert_that (find_metric metrics ~name:"z") is_none

let test_format_metric_dollars _ =
  let m =
    {
      name = "pnl";
      display_name = "P&L";
      description = "";
      value = 1234.56;
      unit = Dollars;
    }
  in
  assert_that (format_metric m) (equal_to "P&L: $1234.56")

let test_format_metric_percent _ =
  let m =
    {
      name = "rate";
      display_name = "Win Rate";
      description = "";
      value = 75.5;
      unit = Percent;
    }
  in
  assert_that (format_metric m) (equal_to "Win Rate: 75.50%")

let test_format_metric_days _ =
  let m =
    {
      name = "hold";
      display_name = "Hold Time";
      description = "";
      value = 12.5;
      unit = Days;
    }
  in
  assert_that (format_metric m) (equal_to "Hold Time: 12.5 days")

let test_format_metric_count _ =
  let m =
    {
      name = "wins";
      display_name = "Wins";
      description = "";
      value = 42.0;
      unit = Count;
    }
  in
  assert_that (format_metric m) (equal_to "Wins: 42")

let test_format_metric_ratio _ =
  let m =
    {
      name = "sharpe";
      display_name = "Sharpe";
      description = "";
      value = 1.2345;
      unit = Ratio;
    }
  in
  assert_that (format_metric m) (equal_to "Sharpe: 1.2345")

let test_format_metrics_multiple _ =
  let metrics =
    [
      {
        name = "a";
        display_name = "A";
        description = "";
        value = 1.0;
        unit = Count;
      };
      {
        name = "b";
        display_name = "B";
        description = "";
        value = 2.0;
        unit = Count;
      };
    ]
  in
  let s = format_metrics metrics in
  assert_bool "contains A" (String.is_substring s ~substring:"A: 1");
  assert_bool "contains B" (String.is_substring s ~substring:"B: 2");
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
         assert_that m.unit (equal_to (Dollars : metric_unit))));
  assert_that
    (find_metric metrics ~name:"win_rate")
    (is_some_and (fun m ->
         assert_that m.value (float_equal 70.0);
         assert_that m.unit (equal_to (Percent : metric_unit))))

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
  let metrics = compute_metrics ~computers:[ computer ] ~config ~steps:[] in
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
  let metrics = compute_metrics ~computers:[ computer ] ~config ~steps in
  assert_that
    (find_metric metrics ~name:"sharpe_ratio")
    (is_some_and (fun m -> assert_that m.value (float_equal 0.0)))

let test_sharpe_ratio_zero_with_constant_value _ =
  (* Zero variance should result in zero Sharpe *)
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
  let metrics = compute_metrics ~computers:[ computer ] ~config ~steps in
  assert_that
    (find_metric metrics ~name:"sharpe_ratio")
    (is_some_and (fun m -> assert_that m.value (float_equal 0.0)))

let test_sharpe_ratio_positive_with_gains _ =
  (* Steadily increasing portfolio should have positive Sharpe *)
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
  let metrics = compute_metrics ~computers:[ computer ] ~config ~steps in
  assert_that
    (find_metric metrics ~name:"sharpe_ratio")
    (is_some_and (fun m ->
         assert_bool "Sharpe should be positive" Float.(m.value > 0.0)))

let test_sharpe_ratio_negative_with_losses _ =
  (* Steadily decreasing portfolio should have negative Sharpe *)
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
  let metrics = compute_metrics ~computers:[ computer ] ~config ~steps in
  assert_that
    (find_metric metrics ~name:"sharpe_ratio")
    (is_some_and (fun m ->
         assert_bool "Sharpe should be negative" Float.(m.value < 0.0)))

let test_sharpe_ratio_with_risk_free_rate _ =
  (* With positive risk-free rate, Sharpe should be lower *)
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
    compute_metrics ~computers:[ computer_no_rf ] ~config ~steps
  in
  let metrics_with_rf =
    compute_metrics ~computers:[ computer_with_rf ] ~config ~steps
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
  (* Steadily increasing portfolio should have zero drawdown *)
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
  let metrics = compute_metrics ~computers:[ computer ] ~config ~steps in
  assert_that
    (find_metric metrics ~name:"max_drawdown")
    (is_some_and (fun m -> assert_that m.value (float_equal 0.0)))

let test_max_drawdown_captures_decline _ =
  (* 10000 -> 11000 -> 9900 should have drawdown of (11000-9900)/11000 = 10% *)
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
  let metrics = compute_metrics ~computers:[ computer ] ~config ~steps in
  assert_that
    (find_metric metrics ~name:"max_drawdown")
    (is_some_and (fun m -> assert_that m.value (float_equal 10.0)))

let test_max_drawdown_captures_largest _ =
  (* Multiple declines - should capture the largest *)
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio_value:9500.0;
      (* 5% dd *)
      make_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio_value:12000.0;
      (* new peak *)
      make_step_result
        ~date:(date_of_string "2024-01-04")
        ~portfolio_value:9600.0;
      (* 20% dd from 12000 *)
    ]
  in
  let computer = max_drawdown_computer () in
  let metrics = compute_metrics ~computers:[ computer ] ~config ~steps in
  assert_that
    (find_metric metrics ~name:"max_drawdown")
    (is_some_and (fun m -> assert_that m.value (float_equal 20.0)))

let test_max_drawdown_with_recovery _ =
  (* Recovery after drawdown should not reduce max drawdown *)
  let config = make_config () in
  let steps =
    [
      make_step_result
        ~date:(date_of_string "2024-01-01")
        ~portfolio_value:10000.0;
      make_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio_value:9000.0;
      (* 10% dd *)
      make_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio_value:10500.0;
      (* recovery, new peak *)
      make_step_result
        ~date:(date_of_string "2024-01-04")
        ~portfolio_value:10500.0;
      (* no change *)
    ]
  in
  let computer = max_drawdown_computer () in
  let metrics = compute_metrics ~computers:[ computer ] ~config ~steps in
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
  let metrics = compute_metrics ~computers:[ computer ] ~config ~steps in
  (* No trades means no summary metrics *)
  assert_that metrics is_empty

(* ==================== Multiple Computers Tests ==================== *)

let test_compute_metrics_combines_results _ =
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
  let metrics = compute_metrics ~computers ~config ~steps in
  assert_that
    (find_metric metrics ~name:"sharpe_ratio")
    (is_some_and (fun _ -> ()));
  assert_that
    (find_metric metrics ~name:"max_drawdown")
    (is_some_and (fun _ -> ()))

let test_default_computers _ =
  let computers = default_computers () in
  (* Should have at least summary, sharpe, and drawdown computers *)
  assert_that computers (size_is 3)

(* ==================== Factory Tests ==================== *)

let test_create_computer_summary _ =
  let computer = create_computer Summary in
  let config = make_config () in
  let steps = [] in
  let metrics = compute_metrics ~computers:[ computer ] ~config ~steps in
  (* Empty steps means no summary metrics *)
  assert_that metrics is_empty

let test_create_computer_sharpe _ =
  let computer = create_computer SharpeRatio in
  let config = make_config () in
  let steps = [] in
  let metrics = compute_metrics ~computers:[ computer ] ~config ~steps in
  assert_that
    (find_metric metrics ~name:"sharpe_ratio")
    (is_some_and (fun m -> assert_that m.value (float_equal 0.0)))

let test_create_computer_max_drawdown _ =
  let computer = create_computer MaxDrawdown in
  let config = make_config () in
  let steps = [] in
  let metrics = compute_metrics ~computers:[ computer ] ~config ~steps in
  assert_that
    (find_metric metrics ~name:"max_drawdown")
    (is_some_and (fun m -> assert_that m.value (float_equal 0.0)))

(* ==================== Test Suite ==================== *)

let suite =
  "Metrics Tests"
  >::: [
         (* Type derivation tests *)
         "metric_unit show" >:: test_metric_unit_show;
         "metric_unit eq" >:: test_metric_unit_eq;
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
         "compute_metrics combines results"
         >:: test_compute_metrics_combines_results;
         "default_computers" >:: test_default_computers;
         (* Factory tests *)
         "create_computer Summary" >:: test_create_computer_summary;
         "create_computer SharpeRatio" >:: test_create_computer_sharpe;
         "create_computer MaxDrawdown" >:: test_create_computer_max_drawdown;
       ]

let () = run_test_tt_main suite
