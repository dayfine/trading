open Core
open OUnit2
open Trading_base.Types
open Trading_engine.Types
open Matchers

(* Test helpers *)
let test_timestamp = Time_ns_unix.of_string "2024-01-15 10:30:00Z"

(* market_data tests *)
let test_market_data_construction _ =
  let md =
    {
      symbol = "AAPL";
      bid = Some 150.0;
      ask = Some 150.5;
      last = Some 150.25;
      timestamp = test_timestamp;
    }
  in
  assert_equal "AAPL" md.symbol ~msg:"Symbol should match";
  assert_equal (Some 150.0) md.bid ~msg:"Bid should match";
  assert_equal (Some 150.5) md.ask ~msg:"Ask should match";
  assert_equal (Some 150.25) md.last ~msg:"Last should match"

let test_market_data_with_missing_prices _ =
  let md =
    {
      symbol = "AAPL";
      bid = None;
      ask = None;
      last = Some 150.0;
      timestamp = test_timestamp;
    }
  in
  assert_equal None md.bid ~msg:"Bid should be None";
  assert_equal None md.ask ~msg:"Ask should be None";
  assert_equal (Some 150.0) md.last ~msg:"Last should be Some"

let test_market_data_equality _ =
  let md1 =
    {
      symbol = "AAPL";
      bid = Some 150.0;
      ask = Some 150.5;
      last = Some 150.25;
      timestamp = test_timestamp;
    }
  in
  let md2 =
    {
      symbol = "AAPL";
      bid = Some 150.0;
      ask = Some 150.5;
      last = Some 150.25;
      timestamp = test_timestamp;
    }
  in
  assert_bool "Identical market data should be equal"
    (equal_market_data md1 md2)

let test_market_data_inequality _ =
  let md1 =
    {
      symbol = "AAPL";
      bid = Some 150.0;
      ask = Some 150.5;
      last = Some 150.25;
      timestamp = test_timestamp;
    }
  in
  let md2 =
    {
      symbol = "AAPL";
      bid = Some 151.0;
      ask = Some 150.5;
      last = Some 150.25;
      timestamp = test_timestamp;
    }
  in
  assert_bool "Different market data should not be equal"
    (not (equal_market_data md1 md2))

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
  let report =
    {
      order_id = "order_1";
      status = Filled;
      filled_quantity = 100.0;
      remaining_quantity = 0.0;
      average_price = Some 150.0;
      trades = [ trade ];
      timestamp = test_timestamp;
    }
  in
  assert_equal "order_1" report.order_id ~msg:"Order ID should match";
  assert_bool "Status should be Filled" (equal_fill_status report.status Filled);
  assert_float_equal 100.0 report.filled_quantity ~msg:"Filled quantity";
  assert_float_equal 0.0 report.remaining_quantity ~msg:"Remaining quantity";
  assert_equal (Some 150.0) report.average_price ~msg:"Average price";
  assert_equal 1 (List.length report.trades) ~msg:"Should have one trade"

let test_execution_report_unfilled _ =
  let report =
    {
      order_id = "order_1";
      status = Unfilled;
      filled_quantity = 0.0;
      remaining_quantity = 100.0;
      average_price = None;
      trades = [];
      timestamp = test_timestamp;
    }
  in
  assert_bool "Status should be Unfilled"
    (equal_fill_status report.status Unfilled);
  assert_float_equal 0.0 report.filled_quantity
    ~msg:"Filled quantity should be 0";
  assert_float_equal 100.0 report.remaining_quantity
    ~msg:"Remaining quantity should be 100";
  assert_equal None report.average_price ~msg:"Average price should be None";
  assert_equal 0 (List.length report.trades) ~msg:"Should have no trades"

let test_execution_report_equality _ =
  let report1 =
    {
      order_id = "order_1";
      status = Filled;
      filled_quantity = 100.0;
      remaining_quantity = 0.0;
      average_price = Some 150.0;
      trades = [];
      timestamp = test_timestamp;
    }
  in
  let report2 =
    {
      order_id = "order_1";
      status = Filled;
      filled_quantity = 100.0;
      remaining_quantity = 0.0;
      average_price = Some 150.0;
      trades = [];
      timestamp = test_timestamp;
    }
  in
  assert_bool "Identical reports should be equal"
    (equal_execution_report report1 report2)

(* commission_config tests *)
let test_commission_config_construction _ =
  let config = { per_share = 0.01; minimum = 1.0 } in
  assert_float_equal 0.01 config.per_share ~msg:"Per share commission";
  assert_float_equal 1.0 config.minimum ~msg:"Minimum commission"

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
  assert_float_equal 0.01 config.commission.per_share
    ~msg:"Engine config commission per share";
  assert_float_equal 1.0 config.commission.minimum
    ~msg:"Engine config commission minimum"

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
         "test_market_data_construction" >:: test_market_data_construction;
         "test_market_data_with_missing_prices"
         >:: test_market_data_with_missing_prices;
         "test_market_data_equality" >:: test_market_data_equality;
         "test_market_data_inequality" >:: test_market_data_inequality;
         "test_fill_status_variants" >:: test_fill_status_variants;
         "test_fill_status_show" >:: test_fill_status_show;
         "test_execution_report_filled" >:: test_execution_report_filled;
         "test_execution_report_unfilled" >:: test_execution_report_unfilled;
         "test_execution_report_equality" >:: test_execution_report_equality;
         "test_commission_config_construction"
         >:: test_commission_config_construction;
         "test_commission_config_equality" >:: test_commission_config_equality;
         "test_commission_config_show" >:: test_commission_config_show;
         "test_engine_config_construction" >:: test_engine_config_construction;
         "test_engine_config_equality" >:: test_engine_config_equality;
         "test_engine_config_show" >:: test_engine_config_show;
       ]

let () = run_test_tt_main suite
