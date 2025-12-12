open Core
open OUnit2
open Trading_base.Types
open Trading_engine.Types
open Matchers

(* Test helpers *)
let test_timestamp = Time_ns_unix.of_string "2024-01-15 10:30:00Z"

(* fill_status tests *)
let test_fill_status_variants _ =
  let filled = Filled in
  let partially_filled = PartiallyFilled in
  let unfilled = Unfilled in
  assert_bool "Filled variant exists" (equal_fill_status filled Filled);
  assert_bool "PartiallyFilled variant exists"
    (equal_fill_status partially_filled PartiallyFilled);
  assert_bool "Unfilled variant exists" (equal_fill_status unfilled Unfilled)

let test_fill_status_show _ =
  let filled_str = show_fill_status Filled in
  let unfilled_str = show_fill_status Unfilled in
  assert_bool "Filled show function works" (String.length filled_str > 0);
  assert_bool "Unfilled show function works" (String.length unfilled_str > 0)

(* execution_report tests *)
let test_execution_report_filled _ =
  let trade =
    {
      id = "trade_1";
      order_id = "order_1";
      symbol = "AAPL";
      side = Buy;
      quantity = 100.0;
      price = 150.0;
      commission = 1.0;
      timestamp = test_timestamp;
    }
  in
  let report = { order_id = "order_1"; status = Filled; trades = [ trade ] } in
  assert_equal "order_1" report.order_id ~msg:"Order ID should match";
  assert_bool "Status should be Filled" (equal_fill_status report.status Filled);
  assert_equal 1 (List.length report.trades) ~msg:"Should have one trade"

let test_execution_report_unfilled _ =
  let report = { order_id = "order_1"; status = Unfilled; trades = [] } in
  assert_bool "Status should be Unfilled"
    (equal_fill_status report.status Unfilled);
  assert_equal 0 (List.length report.trades) ~msg:"Should have no trades"

let test_execution_report_equality _ =
  let report1 = { order_id = "order_1"; status = Filled; trades = [] } in
  let report2 = { order_id = "order_1"; status = Filled; trades = [] } in
  assert_bool "Identical reports should be equal"
    (equal_execution_report report1 report2)

let test_execution_report_with_multiple_trades _ =
  let trade1 =
    {
      id = "trade_1";
      order_id = "order_1";
      symbol = "AAPL";
      side = Buy;
      quantity = 50.0;
      price = 150.0;
      commission = 0.5;
      timestamp = test_timestamp;
    }
  in
  let trade2 =
    {
      id = "trade_2";
      order_id = "order_1";
      symbol = "AAPL";
      side = Buy;
      quantity = 50.0;
      price = 150.5;
      commission = 0.5;
      timestamp = test_timestamp;
    }
  in
  let report =
    { order_id = "order_1"; status = Filled; trades = [ trade1; trade2 ] }
  in
  assert_equal 2
    (List.length report.trades)
    ~msg:"Should have two trades for partial fills"

(* commission_config tests *)
let test_commission_config_construction _ =
  let config = { per_share = 0.01; minimum = 1.0 } in
  assert_that config.per_share (float_equal 0.01);
  assert_that config.minimum (float_equal 1.0)

let test_commission_config_equality _ =
  let config1 = { per_share = 0.01; minimum = 1.0 } in
  let config2 = { per_share = 0.01; minimum = 1.0 } in
  assert_bool "Identical configs should be equal"
    (equal_commission_config config1 config2)

let test_commission_config_show _ =
  let config = { per_share = 0.01; minimum = 1.0 } in
  let config_str = show_commission_config config in
  assert_bool "Show function works" (String.length config_str > 0)

(* engine_config tests *)
let test_engine_config_construction _ =
  let commission_config = { per_share = 0.01; minimum = 1.0 } in
  let config = { commission = commission_config } in
  assert_that config.commission.per_share (float_equal 0.01);
  assert_that config.commission.minimum (float_equal 1.0)

let test_engine_config_equality _ =
  let commission_config = { per_share = 0.01; minimum = 1.0 } in
  let config1 = { commission = commission_config } in
  let config2 = { commission = commission_config } in
  assert_bool "Identical engine configs should be equal"
    (equal_engine_config config1 config2)

let test_engine_config_show _ =
  let commission_config = { per_share = 0.01; minimum = 1.0 } in
  let config = { commission = commission_config } in
  let config_str = show_engine_config config in
  assert_bool "Show function works" (String.length config_str > 0)

(* Test suite *)
let suite =
  "Types Tests"
  >::: [
         "test_fill_status_variants" >:: test_fill_status_variants;
         "test_fill_status_show" >:: test_fill_status_show;
         "test_execution_report_filled" >:: test_execution_report_filled;
         "test_execution_report_unfilled" >:: test_execution_report_unfilled;
         "test_execution_report_equality" >:: test_execution_report_equality;
         "test_execution_report_with_multiple_trades"
         >:: test_execution_report_with_multiple_trades;
         "test_commission_config_construction"
         >:: test_commission_config_construction;
         "test_commission_config_equality" >:: test_commission_config_equality;
         "test_commission_config_show" >:: test_commission_config_show;
         "test_engine_config_construction" >:: test_engine_config_construction;
         "test_engine_config_equality" >:: test_engine_config_equality;
         "test_engine_config_show" >:: test_engine_config_show;
       ]

let () = run_test_tt_main suite
