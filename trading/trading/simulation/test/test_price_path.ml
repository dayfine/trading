open OUnit2
open Core
open Trading_simulation.Price_path
open Matchers

let date_of_string s = Date.of_string s

let make_daily_price ~date ~open_price ~high ~low ~close ~volume =
  Types.Daily_price.
    {
      date;
      open_price;
      high_price = high;
      low_price = low;
      close_price = close;
      volume;
      adjusted_close = close;
    }

(* ==================== generate_path tests ==================== *)

let test_path_starts_at_open _ =
  let daily =
    make_daily_price
      ~date:(date_of_string "2024-01-02")
      ~open_price:100.0 ~high:110.0 ~low:95.0 ~close:105.0 ~volume:1000000
  in
  let path = generate_path daily in
  elements_are path
    [
      equal_to ({ fraction_of_day = 0.0; price = 100.0 } : path_point);
      equal_to ({ fraction_of_day = 0.33; price = 110.0 } : path_point);
      equal_to ({ fraction_of_day = 0.66; price = 95.0 } : path_point);
      equal_to ({ fraction_of_day = 1.0; price = 105.0 } : path_point);
    ]

let test_upward_day_visits_high_before_low _ =
  (* When close > open, path should go O → H → L → C *)
  let daily =
    make_daily_price
      ~date:(date_of_string "2024-01-02")
      ~open_price:100.0 ~high:110.0 ~low:95.0 ~close:105.0 ~volume:1000000
  in
  let path = generate_path daily in
  let high_idx =
    List.findi path ~f:(fun _ point -> Float.(point.price = 110.0))
  in
  let low_idx =
    List.findi path ~f:(fun _ point -> Float.(point.price = 95.0))
  in
  let h_idx = Option.map high_idx ~f:fst |> Option.value_exn in
  let l_idx = Option.map low_idx ~f:fst |> Option.value_exn in
  OUnit2.assert_bool "High should come before low on upward day" (h_idx < l_idx)

let test_downward_day_visits_low_before_high _ =
  (* When close < open, path should go O → L → H → C *)
  let daily =
    make_daily_price
      ~date:(date_of_string "2024-01-02")
      ~open_price:100.0 ~high:105.0 ~low:90.0 ~close:92.0 ~volume:1000000
  in
  let path = generate_path daily in
  let high_idx =
    List.findi path ~f:(fun _ point -> Float.(point.price = 105.0))
  in
  let low_idx =
    List.findi path ~f:(fun _ point -> Float.(point.price = 90.0))
  in
  let h_idx = Option.map high_idx ~f:fst |> Option.value_exn in
  let l_idx = Option.map low_idx ~f:fst |> Option.value_exn in
  OUnit2.assert_bool "Low should come before high on downward day"
    (l_idx < h_idx)

let test_path_fractions_are_increasing _ =
  let daily =
    make_daily_price
      ~date:(date_of_string "2024-01-02")
      ~open_price:100.0 ~high:110.0 ~low:95.0 ~close:105.0 ~volume:1000000
  in
  let path = generate_path daily in
  let fractions = List.map path ~f:(fun point -> point.fraction_of_day) in
  let is_sorted =
    List.for_alli fractions ~f:(fun i frac ->
        i = 0
        ||
        match List.nth fractions (i - 1) with
        | Some prev_frac -> Float.(prev_frac <= frac)
        | None -> false)
  in
  OUnit2.assert_bool "Path fractions should be in increasing order" is_sorted

(* ==================== would_fill tests - Market orders ==================== *)

let test_market_order_fills_at_open _ =
  let daily =
    make_daily_price
      ~date:(date_of_string "2024-01-02")
      ~open_price:100.0 ~high:110.0 ~low:95.0 ~close:105.0 ~volume:1000000
  in
  let path = generate_path daily in
  let result =
    would_fill ~path ~order_type:Trading_base.Types.Market
      ~side:Trading_base.Types.Buy
  in
  assert_that result
    (is_some_and
       (equal_to ({ price = 100.0; fraction_of_day = 0.0 } : fill_result)))

(* ==================== would_fill tests - Limit orders ==================== *)

let test_limit_buy_fills_when_price_drops_to_limit _ =
  let daily =
    make_daily_price
      ~date:(date_of_string "2024-01-02")
      ~open_price:100.0 ~high:110.0 ~low:95.0 ~close:105.0 ~volume:1000000
  in
  let path = generate_path daily in
  (* Limit buy at 95.0 should fill when price reaches low *)
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Limit 95.0)
      ~side:Trading_base.Types.Buy
  in
  assert_that result
    (is_some_and (field (fun fill -> fill.price) (float_equal 95.0)))

let test_limit_buy_does_not_fill_above_limit _ =
  let daily =
    make_daily_price
      ~date:(date_of_string "2024-01-02")
      ~open_price:100.0 ~high:110.0 ~low:98.0 ~close:105.0 ~volume:1000000
  in
  let path = generate_path daily in
  (* Limit buy at 95.0 should NOT fill when low is 98.0 *)
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Limit 95.0)
      ~side:Trading_base.Types.Buy
  in
  assert_that result is_none

let test_limit_sell_fills_when_price_rises_to_limit _ =
  let daily =
    make_daily_price
      ~date:(date_of_string "2024-01-02")
      ~open_price:100.0 ~high:110.0 ~low:95.0 ~close:105.0 ~volume:1000000
  in
  let path = generate_path daily in
  (* Limit sell at 110.0 should fill when price reaches high *)
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Limit 110.0)
      ~side:Trading_base.Types.Sell
  in
  assert_that result
    (is_some_and (field (fun fill -> fill.price) (float_equal 110.0)))

let test_limit_sell_does_not_fill_below_limit _ =
  let daily =
    make_daily_price
      ~date:(date_of_string "2024-01-02")
      ~open_price:100.0 ~high:108.0 ~low:95.0 ~close:105.0 ~volume:1000000
  in
  let path = generate_path daily in
  (* Limit sell at 110.0 should NOT fill when high is 108.0 *)
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Limit 110.0)
      ~side:Trading_base.Types.Sell
  in
  assert_that result is_none

(* ==================== would_fill tests - Stop orders ==================== *)

let test_stop_buy_fills_when_price_rises_to_stop _ =
  let daily =
    make_daily_price
      ~date:(date_of_string "2024-01-02")
      ~open_price:100.0 ~high:110.0 ~low:95.0 ~close:105.0 ~volume:1000000
  in
  let path = generate_path daily in
  (* Stop buy at 110.0 should trigger when price reaches high *)
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Stop 110.0)
      ~side:Trading_base.Types.Buy
  in
  assert_that result
    (is_some_and (field (fun fill -> fill.price) (float_equal 110.0)))

let test_stop_buy_does_not_fill_below_stop _ =
  let daily =
    make_daily_price
      ~date:(date_of_string "2024-01-02")
      ~open_price:100.0 ~high:108.0 ~low:95.0 ~close:105.0 ~volume:1000000
  in
  let path = generate_path daily in
  (* Stop buy at 110.0 should NOT trigger when high is 108.0 *)
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Stop 110.0)
      ~side:Trading_base.Types.Buy
  in
  assert_that result is_none

let test_stop_sell_fills_when_price_drops_to_stop _ =
  let daily =
    make_daily_price
      ~date:(date_of_string "2024-01-02")
      ~open_price:100.0 ~high:110.0 ~low:95.0 ~close:105.0 ~volume:1000000
  in
  let path = generate_path daily in
  (* Stop sell at 95.0 should trigger when price reaches low *)
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Stop 95.0)
      ~side:Trading_base.Types.Sell
  in
  assert_that result
    (is_some_and (field (fun fill -> fill.price) (float_equal 95.0)))

let test_stop_sell_does_not_fill_above_stop _ =
  let daily =
    make_daily_price
      ~date:(date_of_string "2024-01-02")
      ~open_price:100.0 ~high:110.0 ~low:98.0 ~close:105.0 ~volume:1000000
  in
  let path = generate_path daily in
  (* Stop sell at 95.0 should NOT trigger when low is 98.0 *)
  let result =
    would_fill ~path ~order_type:(Trading_base.Types.Stop 95.0)
      ~side:Trading_base.Types.Sell
  in
  assert_that result is_none

(* ==================== would_fill tests - StopLimit orders ==================== *)

let test_stop_limit_buy_fills_when_both_conditions_met _ =
  let daily =
    make_daily_price
      ~date:(date_of_string "2024-01-02")
      ~open_price:100.0 ~high:110.0 ~low:95.0 ~close:105.0 ~volume:1000000
  in
  let path = generate_path daily in
  (* Stop at 105.0, limit at 95.0 - stop triggers, then limit fills at low *)
  let result =
    would_fill ~path
      ~order_type:(Trading_base.Types.StopLimit (105.0, 95.0))
      ~side:Trading_base.Types.Buy
  in
  assert_that result
    (is_some_and (field (fun fill -> fill.price) (float_equal 95.0)))

let test_stop_limit_buy_does_not_fill_when_stop_not_triggered _ =
  let daily =
    make_daily_price
      ~date:(date_of_string "2024-01-02")
      ~open_price:100.0 ~high:103.0 ~low:95.0 ~close:102.0 ~volume:1000000
  in
  let path = generate_path daily in
  (* Stop at 105.0 never triggers (high is 103.0) *)
  let result =
    would_fill ~path
      ~order_type:(Trading_base.Types.StopLimit (105.0, 95.0))
      ~side:Trading_base.Types.Buy
  in
  assert_that result is_none

let test_stop_limit_buy_does_not_fill_when_limit_not_reached _ =
  let daily =
    make_daily_price
      ~date:(date_of_string "2024-01-02")
      ~open_price:100.0 ~high:110.0 ~low:98.0 ~close:105.0 ~volume:1000000
  in
  let path = generate_path daily in
  (* Stop at 105.0 triggers, but limit at 95.0 never reached (low is 98.0) *)
  let result =
    would_fill ~path
      ~order_type:(Trading_base.Types.StopLimit (105.0, 95.0))
      ~side:Trading_base.Types.Buy
  in
  assert_that result is_none

let test_stop_limit_sell_fills_when_both_conditions_met _ =
  let daily =
    make_daily_price
      ~date:(date_of_string "2024-01-02")
      ~open_price:100.0 ~high:110.0 ~low:95.0 ~close:105.0 ~volume:1000000
  in
  let path = generate_path daily in
  (* Stop at 98.0, limit at 110.0 - stop triggers at low, then limit fills at high *)
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
         "path structure is correct" >:: test_path_starts_at_open;
         "upward day visits high before low"
         >:: test_upward_day_visits_high_before_low;
         "downward day visits low before high"
         >:: test_downward_day_visits_low_before_high;
         "path fractions are increasing" >:: test_path_fractions_are_increasing;
         (* Market order tests *)
         "market order fills at open" >:: test_market_order_fills_at_open;
         (* Limit order tests *)
         "limit buy fills when price drops to limit"
         >:: test_limit_buy_fills_when_price_drops_to_limit;
         "limit buy does not fill above limit"
         >:: test_limit_buy_does_not_fill_above_limit;
         "limit sell fills when price rises to limit"
         >:: test_limit_sell_fills_when_price_rises_to_limit;
         "limit sell does not fill below limit"
         >:: test_limit_sell_does_not_fill_below_limit;
         (* Stop order tests *)
         "stop buy fills when price rises to stop"
         >:: test_stop_buy_fills_when_price_rises_to_stop;
         "stop buy does not fill below stop"
         >:: test_stop_buy_does_not_fill_below_stop;
         "stop sell fills when price drops to stop"
         >:: test_stop_sell_fills_when_price_drops_to_stop;
         "stop sell does not fill above stop"
         >:: test_stop_sell_does_not_fill_above_stop;
         (* StopLimit order tests *)
         "stop limit buy fills when both conditions met"
         >:: test_stop_limit_buy_fills_when_both_conditions_met;
         "stop limit buy does not fill when stop not triggered"
         >:: test_stop_limit_buy_does_not_fill_when_stop_not_triggered;
         "stop limit buy does not fill when limit not reached"
         >:: test_stop_limit_buy_does_not_fill_when_limit_not_reached;
         "stop limit sell fills when both conditions met"
         >:: test_stop_limit_sell_fills_when_both_conditions_met;
       ]

let () = run_test_tt_main suite
