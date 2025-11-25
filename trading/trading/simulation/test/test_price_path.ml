open OUnit2
open Core
open Trading_simulation.Price_path
open Matchers

let date_of_string s = Date.of_string s

(* Sample daily prices for testing *)
let upward_day =
  Types.Daily_price.
    {
      date = date_of_string "2024-01-02";
      open_price = 100.0;
      high_price = 110.0;
      low_price = 95.0;
      close_price = 105.0;
      volume = 1000000;
      adjusted_close = 105.0;
    }

let downward_day =
  Types.Daily_price.
    {
      date = date_of_string "2024-01-03";
      open_price = 100.0;
      high_price = 105.0;
      low_price = 90.0;
      close_price = 92.0;
      volume = 1000000;
      adjusted_close = 92.0;
    }

(* ==================== generate_path tests ==================== *)

let test_upward_day_path _ =
  (* When close > open, path goes O → H → L → C *)
  let path = generate_path upward_day in
  assert_that path
    (elements_are
       [
         equal_to ({ fraction_of_day = 0.0; price = 100.0 } : path_point);
         equal_to ({ fraction_of_day = 0.33; price = 110.0 } : path_point);
         equal_to ({ fraction_of_day = 0.66; price = 95.0 } : path_point);
         equal_to ({ fraction_of_day = 1.0; price = 105.0 } : path_point);
       ])

let test_downward_day_path _ =
  (* When close < open, path goes O → L → H → C *)
  let path = generate_path downward_day in
  assert_that path
    (elements_are
       [
         equal_to ({ fraction_of_day = 0.0; price = 100.0 } : path_point);
         equal_to ({ fraction_of_day = 0.33; price = 90.0 } : path_point);
         equal_to ({ fraction_of_day = 0.66; price = 105.0 } : path_point);
         equal_to ({ fraction_of_day = 1.0; price = 92.0 } : path_point);
       ])

(* ==================== would_fill tests - Market orders ==================== *)

let test_market_order_fills_at_open _ =
  let path = generate_path upward_day in
  let result =
    would_fill ~path ~order_type:Trading_base.Types.Market
      ~side:Trading_base.Types.Buy
  in
  assert_that result
    (is_some_and
       (equal_to ({ price = 100.0; fraction_of_day = 0.0 } : fill_result)))

(* ==================== would_fill tests - Limit orders ==================== *)

let test_limit_buy_at_low _ =
  let path = generate_path upward_day in
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Limit 95.0)
      ~side:Trading_base.Types.Buy
  in
  assert_that result
    (is_some_and (field (fun fill -> fill.price) (float_equal 95.0)))

let test_limit_buy_below_low _ =
  (* Limit below low doesn't fill (price never reached) *)
  let path = generate_path upward_day in
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Limit 90.0)
      ~side:Trading_base.Types.Buy
  in
  assert_that result is_none

let test_limit_buy_between_low_and_close _ =
  (* Limit buy between low and close should fill *)
  let path = generate_path upward_day in
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Limit 100.0)
      ~side:Trading_base.Types.Buy
  in
  assert_that result
    (is_some_and (field (fun fill -> fill.price) (float_equal 100.0)))

let test_limit_buy_above_high _ =
  (* Limit buy above high fills at limit price (conservative assumption) *)
  let path = generate_path upward_day in
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Limit 115.0)
      ~side:Trading_base.Types.Buy
  in
  assert_that result
    (is_some_and (field (fun fill -> fill.price) (float_equal 115.0)))

let test_limit_sell_at_high _ =
  let path = generate_path upward_day in
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Limit 110.0)
      ~side:Trading_base.Types.Sell
  in
  assert_that result
    (is_some_and (field (fun fill -> fill.price) (float_equal 110.0)))

let test_limit_sell_above_high _ =
  (* Limit sell above high doesn't fill (price never reached) *)
  let path = generate_path upward_day in
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Limit 115.0)
      ~side:Trading_base.Types.Sell
  in
  assert_that result is_none

let test_limit_sell_between_open_and_high _ =
  (* Limit sell at 105 fills at limit price when market rises above it *)
  let path = generate_path upward_day in
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Limit 105.0)
      ~side:Trading_base.Types.Sell
  in
  assert_that result
    (is_some_and (field (fun fill -> fill.price) (float_equal 105.0)))

let test_limit_sell_below_low _ =
  (* Limit sell below low fills at limit price (conservative assumption) *)
  let path = generate_path upward_day in
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Limit 90.0)
      ~side:Trading_base.Types.Sell
  in
  assert_that result
    (is_some_and (field (fun fill -> fill.price) (float_equal 90.0)))

(* ==================== would_fill tests - Stop orders ==================== *)

let test_stop_buy_at_high _ =
  let path = generate_path upward_day in
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Stop 110.0)
      ~side:Trading_base.Types.Buy
  in
  assert_that result
    (is_some_and (field (fun fill -> fill.price) (float_equal 110.0)))

let test_stop_buy_between_open_and_high _ =
  (* Stop buy at 105 triggers when price reaches high at 110 *)
  let path = generate_path upward_day in
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Stop 105.0)
      ~side:Trading_base.Types.Buy
  in
  assert_that result
    (is_some_and (field (fun fill -> fill.price) (float_equal 110.0)))

let test_stop_buy_above_high _ =
  (* Stop buy above high should not trigger *)
  let path = generate_path upward_day in
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Stop 115.0)
      ~side:Trading_base.Types.Buy
  in
  assert_that result is_none

let test_stop_sell_at_low _ =
  let path = generate_path upward_day in
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Stop 95.0)
      ~side:Trading_base.Types.Sell
  in
  assert_that result
    (is_some_and (field (fun fill -> fill.price) (float_equal 95.0)))

let test_stop_sell_between_low_and_open _ =
  (* Stop sell at 98 triggers when price reaches low at 95 *)
  let path = generate_path upward_day in
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Stop 98.0)
      ~side:Trading_base.Types.Sell
  in
  assert_that result
    (is_some_and (field (fun fill -> fill.price) (float_equal 95.0)))

let test_stop_sell_below_low _ =
  (* Stop sell below low should not trigger *)
  let path = generate_path upward_day in
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Stop 90.0)
      ~side:Trading_base.Types.Sell
  in
  assert_that result is_none

(* ==================== would_fill tests - StopLimit orders ==================== *)

let test_stop_limit_buy_both_conditions_met _ =
  (* Stop at 105.0 triggers, limit at 95.0 fills *)
  let path = generate_path upward_day in
  let result =
    would_fill ~path
      ~order_type:(Trading_base.Types.StopLimit (105.0, 95.0))
      ~side:Trading_base.Types.Buy
  in
  assert_that result
    (is_some_and (field (fun fill -> fill.price) (float_equal 95.0)))

let test_stop_limit_buy_stop_not_triggered _ =
  (* Stop at 115.0 never triggers (high is 110.0) *)
  let path = generate_path upward_day in
  let result =
    would_fill ~path
      ~order_type:(Trading_base.Types.StopLimit (115.0, 95.0))
      ~side:Trading_base.Types.Buy
  in
  assert_that result is_none

let test_stop_limit_buy_limit_not_reached _ =
  (* Stop at 105.0 triggers, but limit at 92.0 not reached (low is 95.0) *)
  let path = generate_path upward_day in
  let result =
    would_fill ~path
      ~order_type:(Trading_base.Types.StopLimit (105.0, 92.0))
      ~side:Trading_base.Types.Buy
  in
  assert_that result is_none

let test_stop_limit_sell_both_conditions_met _ =
  (* Stop at 98.0 triggers, limit at 110.0 fills *)
  let path = generate_path upward_day in
  let result =
    would_fill ~path
      ~order_type:(Trading_base.Types.StopLimit (98.0, 110.0))
      ~side:Trading_base.Types.Sell
  in
  assert_that result
    (is_some_and (field (fun fill -> fill.price) (float_equal 110.0)))

(* ==================== Test Suite ==================== *)

let suite =
  "Price_path Tests"
  >::: [
         (* Path generation tests *)
         "upward day path O→H→L→C" >:: test_upward_day_path;
         "downward day path O→L→H→C" >:: test_downward_day_path;
         (* Market order tests *)
         "market order fills at open" >:: test_market_order_fills_at_open;
         (* Limit order tests *)
         "limit buy at low" >:: test_limit_buy_at_low;
         "limit buy below low" >:: test_limit_buy_below_low;
         "limit buy between low and close"
         >:: test_limit_buy_between_low_and_close;
         "limit buy above high" >:: test_limit_buy_above_high;
         "limit sell at high" >:: test_limit_sell_at_high;
         "limit sell above high" >:: test_limit_sell_above_high;
         "limit sell between open and high"
         >:: test_limit_sell_between_open_and_high;
         "limit sell below low" >:: test_limit_sell_below_low;
         (* Stop order tests *)
         "stop buy at high" >:: test_stop_buy_at_high;
         "stop buy between open and high"
         >:: test_stop_buy_between_open_and_high;
         "stop buy above high" >:: test_stop_buy_above_high;
         "stop sell at low" >:: test_stop_sell_at_low;
         "stop sell between low and open"
         >:: test_stop_sell_between_low_and_open;
         "stop sell below low" >:: test_stop_sell_below_low;
         (* StopLimit order tests *)
         "stop limit buy both conditions met"
         >:: test_stop_limit_buy_both_conditions_met;
         "stop limit buy stop not triggered"
         >:: test_stop_limit_buy_stop_not_triggered;
         "stop limit buy limit not reached"
         >:: test_stop_limit_buy_limit_not_reached;
         "stop limit sell both conditions met"
         >:: test_stop_limit_sell_both_conditions_met;
       ]

let () = run_test_tt_main suite
