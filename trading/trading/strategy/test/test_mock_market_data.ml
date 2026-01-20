open OUnit2
open Core
open Test_helpers
open Matchers

let date_of_string s = Date.of_string s

let test_create_and_query _ =
  let prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:10 ~base_price:150.0 ~trend:(Uptrend 0.5) ~volatility:0.02
  in
  let market_data =
    Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[ 5 ]
      ~current_date:(date_of_string "2024-01-05")
  in
  assert_equal
    (date_of_string "2024-01-05")
    (Mock_market_data.current_date market_data);
  let price_opt = Mock_market_data.get_price market_data "AAPL" in
  (* Day 5 with 0.5% daily uptrend from 150.0, deterministic from Random.init 42 *)
  assert_that price_opt
    (is_some_and
       (field
          (fun (p : Types.Daily_price.t) -> p.close_price)
          (float_equal ~epsilon:0.01 156.06)))

let test_advance_date _ =
  let prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:10 ~base_price:150.0 ~trend:Sideways ~volatility:0.01
  in
  let market_data =
    Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[]
      ~current_date:(date_of_string "2024-01-01")
  in
  let market_data' =
    Mock_market_data.advance market_data ~date:(date_of_string "2024-01-05")
  in
  assert_equal
    (date_of_string "2024-01-05")
    (Mock_market_data.current_date market_data')

let test_price_history _ =
  let prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:10 ~base_price:150.0 ~trend:Sideways ~volatility:0.01
  in
  let market_data =
    Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[]
      ~current_date:(date_of_string "2024-01-10")
  in
  let history = Mock_market_data.get_price_history market_data "AAPL" () in
  (* Should have all 10 days with deterministic values from Random.init 42 *)
  assert_that history (size_is 10);
  let close_prices =
    List.map history ~f:(fun (p : Types.Daily_price.t) -> p.close_price)
  in
  assert_that close_prices
    (elements_are
       [
         float_equal ~epsilon:0.01 150.27;
         float_equal ~epsilon:0.01 150.75;
         float_equal ~epsilon:0.01 150.76;
         float_equal ~epsilon:0.01 150.81;
         float_equal ~epsilon:0.01 151.11;
         float_equal ~epsilon:0.01 151.44;
         float_equal ~epsilon:0.01 151.52;
         float_equal ~epsilon:0.01 152.15;
         float_equal ~epsilon:0.01 152.25;
         float_equal ~epsilon:0.01 152.46;
       ]);
  (* Test lookback - should only get last 3 days *)
  let recent =
    Mock_market_data.get_price_history market_data "AAPL" ~lookback_days:3 ()
  in
  assert_that recent (size_is 3);
  let recent_close_prices =
    List.map recent ~f:(fun (p : Types.Daily_price.t) -> p.close_price)
  in
  assert_that recent_close_prices
    (elements_are
       [
         float_equal ~epsilon:0.01 152.15;
         float_equal ~epsilon:0.01 152.25;
         float_equal ~epsilon:0.01 152.46;
       ])

let test_no_lookahead _ =
  let prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:10 ~base_price:150.0 ~trend:Sideways ~volatility:0.01
  in
  let market_data =
    Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[]
      ~current_date:(date_of_string "2024-01-05")
  in
  (* Should only get prices up to current date *)
  let history = Mock_market_data.get_price_history market_data "AAPL" () in
  assert_that history (size_is 5);
  (* Future date should return None *)
  let future_price =
    Mock_market_data.get_price
      (Mock_market_data.advance market_data ~date:(date_of_string "2024-01-20"))
      "AAPL"
  in
  assert_that future_price is_none

let test_ema_computation _ =
  let prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:30 ~base_price:150.0 ~trend:(Uptrend 0.5) ~volatility:0.01
  in
  let market_data =
    Mock_market_data.create
      ~data:[ ("AAPL", prices) ]
      ~ema_periods:[ 10; 20 ]
      ~current_date:(date_of_string "2024-01-30")
  in
  (* EMA should be computed *)
  let ema_10 = Mock_market_data.get_ema market_data "AAPL" 10 in
  assert_that ema_10
    (is_some_and (fun ema ->
         assert_bool "EMA 10 should be positive" Float.(ema > 0.0)));
  let ema_20 = Mock_market_data.get_ema market_data "AAPL" 20 in
  assert_that ema_20
    (is_some_and (fun ema ->
         assert_bool "EMA 20 should be positive" Float.(ema > 0.0)));
  (* EMA series should have values starting from period-1 *)
  (* For 30 days with period 10: 30 - (10 - 1) = 21 values *)
  let ema_series = Mock_market_data.get_ema_series market_data "AAPL" 10 () in
  assert_that ema_series (size_is 21)

let test_price_spike _ =
  let base_prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:10 ~base_price:150.0 ~trend:Sideways ~volatility:0.01
  in
  let prices_with_spike =
    Price_generators.with_spike base_prices
      ~spike_date:(date_of_string "2024-01-05")
      ~spike_percent:10.0
  in
  (* Find the spike day *)
  let spike_day =
    List.find_exn prices_with_spike ~f:(fun (p : Types.Daily_price.t) ->
        Date.equal p.date (date_of_string "2024-01-05"))
  in
  (* Price should be ~10% higher *)
  assert_bool "Spike day price should be elevated"
    Float.(spike_day.close_price > 160.0)

let suite =
  "Mock Market Data Tests"
  >::: [
         "create and query" >:: test_create_and_query;
         "advance date" >:: test_advance_date;
         "price history" >:: test_price_history;
         "no lookahead" >:: test_no_lookahead;
         "ema computation" >:: test_ema_computation;
         "price spike" >:: test_price_spike;
       ]

let () = run_test_tt_main suite
