open OUnit2
open Core
open Test_helpers

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
  match price_opt with
  | Some _ -> ()
  | None -> assert_failure "Expected Some price"

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
  (* Should have all generated prices up to current date *)
  assert_bool "Should have prices" (List.length history > 0);
  assert_bool "Should not exceed total" (List.length history <= 10);
  (* Test lookback *)
  let recent =
    Mock_market_data.get_price_history market_data "AAPL" ~lookback_days:3 ()
  in
  assert_bool "Lookback should limit results" (List.length recent <= 3)

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
  assert_equal 5 (List.length history);
  (* Future date should return None *)
  let future_price =
    Mock_market_data.get_price
      (Mock_market_data.advance market_data ~date:(date_of_string "2024-01-20"))
      "AAPL"
  in
  match future_price with
  | None -> ()
  | Some _ -> assert_failure "Expected None for future date"

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
  (match ema_10 with Some _ -> () | None -> assert_failure "Expected EMA 10");
  let ema_20 = Mock_market_data.get_ema market_data "AAPL" 20 in
  (match ema_20 with Some _ -> () | None -> assert_failure "Expected EMA 20");
  (* EMA series should have values *)
  let ema_series = Mock_market_data.get_ema_series market_data "AAPL" 10 () in
  assert_equal 30 (List.length ema_series)

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
