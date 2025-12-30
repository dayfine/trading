(** Tests for price sequence generators *)

open OUnit2
open Core
open Test_helpers
open Matchers

let date_of_string s = Date.of_string s

(** Print a price sequence for inspection *)
let print_price_sequence name prices =
  printf "\n=== %s ===\n" name;
  List.iteri prices ~f:(fun i (p : Types.Daily_price.t) ->
      printf "[%d] %s: O=%.2f H=%.2f L=%.2f C=%.2f\n" i
        (Date.to_string p.date) p.open_price p.high_price p.low_price
        p.close_price)

(** Test: Uptrend generates increasing prices *)
let test_uptrend_sequence _ =
  let prices =
    Price_generators.make_price_sequence ~symbol:"TEST"
      ~start_date:(date_of_string "2024-01-01") ~days:5 ~base_price:100.0
      ~trend:(Price_generators.Uptrend 1.0) ~volatility:0.01
  in

  print_price_sequence "Uptrend 1% daily" prices;

  (* Verify we got 5 days of prices *)
  assert_equal 5 (List.length prices);

  (* Verify dates are sequential starting from 2024-01-01 *)
  let dates = List.map prices ~f:(fun p -> p.Types.Daily_price.date) in
  assert_that dates
    (elements_are
       [
         equal_to (date_of_string "2024-01-01");
         equal_to (date_of_string "2024-01-02");
         equal_to (date_of_string "2024-01-03");
         equal_to (date_of_string "2024-01-04");
         equal_to (date_of_string "2024-01-05");
       ]);

  (* Verify prices are generally trending up (close prices) *)
  let close_prices =
    List.map prices ~f:(fun p -> p.Types.Daily_price.close_price)
  in
  (* First price should be near 100.0 (with trend and volatility applied) *)
  assert_that (List.hd_exn close_prices) (float_equal ~epsilon:2.0 100.0);
  (* Last price should be higher (roughly 100 * 1.01^5 ≈ 105.1) *)
  assert_bool "Last price should be higher than first"
    Float.(List.last_exn close_prices > List.hd_exn close_prices);

  (* Verify OHLC relationships hold *)
  List.iter prices ~f:(fun (p : Types.Daily_price.t) ->
      assert_bool "High >= Open" Float.(p.high_price >= p.open_price);
      assert_bool "High >= Close" Float.(p.high_price >= p.close_price);
      assert_bool "Low <= Open" Float.(p.low_price <= p.open_price);
      assert_bool "Low <= Close" Float.(p.low_price <= p.close_price))

(** Test: Downtrend generates decreasing prices *)
let test_downtrend_sequence _ =
  let prices =
    Price_generators.make_price_sequence ~symbol:"TEST"
      ~start_date:(date_of_string "2024-01-01") ~days:5 ~base_price:100.0
      ~trend:(Price_generators.Downtrend 2.0) ~volatility:0.01
  in

  print_price_sequence "Downtrend 2% daily" prices;

  assert_equal 5 (List.length prices);

  (* Verify prices are trending down *)
  let close_prices =
    List.map prices ~f:(fun p -> p.Types.Daily_price.close_price)
  in
  assert_bool "Last price should be lower than first"
    Float.(List.last_exn close_prices < List.hd_exn close_prices)

(** Test: Sideways trend maintains stable prices *)
let test_sideways_sequence _ =
  let prices =
    Price_generators.make_price_sequence ~symbol:"TEST"
      ~start_date:(date_of_string "2024-01-01") ~days:5 ~base_price:100.0
      ~trend:Price_generators.Sideways ~volatility:0.01
  in

  print_price_sequence "Sideways" prices;

  assert_equal 5 (List.length prices);

  (* Prices should stay close to 100.0 (within volatility range) *)
  List.iter prices ~f:(fun (p : Types.Daily_price.t) ->
      assert_bool "Price should stay near 100.0"
        Float.(abs (p.close_price -. 100.0) < 5.0))

(** Test: Price spike creates a jump at specific date *)
let test_price_spike _ =
  let base_prices =
    Price_generators.make_price_sequence ~symbol:"TEST"
      ~start_date:(date_of_string "2024-01-01") ~days:5 ~base_price:100.0
      ~trend:Price_generators.Sideways ~volatility:0.01
  in
  let spiked_prices =
    Price_generators.with_spike base_prices
      ~spike_date:(date_of_string "2024-01-03") ~spike_percent:20.0
  in

  print_price_sequence "With 20% spike on 2024-01-03" spiked_prices;

  (* Find the spiked day *)
  let spike_day =
    List.find_exn spiked_prices ~f:(fun p ->
        Date.equal p.Types.Daily_price.date (date_of_string "2024-01-03"))
  in
  let base_day =
    List.find_exn base_prices ~f:(fun p ->
        Date.equal p.Types.Daily_price.date (date_of_string "2024-01-03"))
  in

  (* Verify spike is roughly 20% higher *)
  let spike_ratio = spike_day.close_price /. base_day.close_price in
  assert_that spike_ratio (float_equal ~epsilon:0.01 1.20)

(** Test: Price gap creates discontinuity *)
let test_price_gap _ =
  let base_prices =
    Price_generators.make_price_sequence ~symbol:"TEST"
      ~start_date:(date_of_string "2024-01-01") ~days:5 ~base_price:100.0
      ~trend:Price_generators.Sideways ~volatility:0.01
  in
  let gapped_prices =
    Price_generators.with_gap base_prices
      ~gap_date:(date_of_string "2024-01-03") ~gap_percent:10.0
  in

  print_price_sequence "With 10% gap on 2024-01-03" gapped_prices;

  (* Find the gap day and previous day *)
  let day2 =
    List.find_exn gapped_prices ~f:(fun p ->
        Date.equal p.Types.Daily_price.date (date_of_string "2024-01-02"))
  in
  let day3 =
    List.find_exn gapped_prices ~f:(fun p ->
        Date.equal p.Types.Daily_price.date (date_of_string "2024-01-03"))
  in

  (* Verify gap exists (day3 open is 10% higher than day2 close) *)
  let gap_ratio = day3.open_price /. day2.close_price in
  assert_that gap_ratio (float_equal ~epsilon:0.01 1.10)

(** Test: Trend reversal changes direction *)
let test_trend_reversal _ =
  let prices =
    Price_generators.make_price_sequence ~symbol:"TEST"
      ~start_date:(date_of_string "2024-01-01") ~days:10 ~base_price:100.0
      ~trend:(Price_generators.Uptrend 1.0) ~volatility:0.01
  in
  let reversed_prices =
    Price_generators.with_reversal prices
      ~reversal_date:(date_of_string "2024-01-06")
      ~new_trend:(Price_generators.Downtrend 1.5)
  in

  print_price_sequence "Uptrend → Downtrend at 2024-01-06" reversed_prices;

  assert_equal 10 (List.length reversed_prices);

  (* Split into before and after reversal *)
  let before_reversal =
    List.filter reversed_prices ~f:(fun p ->
        Date.(p.Types.Daily_price.date < date_of_string "2024-01-06"))
  in
  let after_reversal =
    List.filter reversed_prices ~f:(fun p ->
        Date.(p.Types.Daily_price.date >= date_of_string "2024-01-06"))
  in

  (* Before reversal: prices should be increasing *)
  let before_closes =
    List.map before_reversal ~f:(fun p -> p.Types.Daily_price.close_price)
  in
  if List.length before_closes >= 2 then
    assert_bool "Before reversal should be trending up"
      Float.(List.last_exn before_closes > List.hd_exn before_closes);

  (* After reversal: prices should be decreasing *)
  let after_closes =
    List.map after_reversal ~f:(fun p -> p.Types.Daily_price.close_price)
  in
  if List.length after_closes >= 2 then
    assert_bool "After reversal should be trending down"
      Float.(List.last_exn after_closes < List.hd_exn after_closes)

(** Test: Verify specific generated values for reproducibility *)
let test_reproducible_values _ =
  (* Generate a sequence with fixed seed *)
  let prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01") ~days:3 ~base_price:150.0
      ~trend:(Price_generators.Uptrend 0.5) ~volatility:0.01
  in

  print_price_sequence "Reproducible sequence (AAPL)" prices;

  (* Verify we got exactly 3 prices *)
  assert_equal 3 (List.length prices);

  (* The Random.init 42 seed makes this deterministic *)
  (* We can assert on the actual values generated *)
  let day1 = List.nth_exn prices 0 in
  let day2 = List.nth_exn prices 1 in
  let day3 = List.nth_exn prices 2 in

  (* Day 1: base_price = 150.0 (with trend and volatility applied) *)
  assert_that day1.date (equal_to (date_of_string "2024-01-01"));
  assert_that day1.close_price (float_equal ~epsilon:2.0 150.0);

  (* Day 2: ~150 * 1.005 ≈ 150.75 *)
  assert_that day2.date (equal_to (date_of_string "2024-01-02"));
  assert_bool "Day 2 close should be higher than day 1"
    Float.(day2.close_price > day1.close_price);

  (* Day 3: should continue uptrend *)
  assert_that day3.date (equal_to (date_of_string "2024-01-03"));
  assert_bool "Day 3 close should be higher than day 2"
    Float.(day3.close_price > day2.close_price);

  (* Print actual values for manual verification *)
  printf "\nActual generated values:\n";
  printf "Day 1: %.4f\n" day1.close_price;
  printf "Day 2: %.4f\n" day2.close_price;
  printf "Day 3: %.4f\n" day3.close_price;

  (* Assert on exact expected values (with fixed seed 42) *)
  (* These demonstrate the deterministic output of the generator *)
  assert_that day1.close_price (float_equal ~epsilon:0.01 151.02);
  assert_that day2.close_price (float_equal ~epsilon:0.01 152.26);
  assert_that day3.close_price (float_equal ~epsilon:0.01 153.03)

let suite =
  "Price Generators Tests"
  >::: [
         "uptrend sequence" >:: test_uptrend_sequence;
         "downtrend sequence" >:: test_downtrend_sequence;
         "sideways sequence" >:: test_sideways_sequence;
         "price spike" >:: test_price_spike;
         "price gap" >:: test_price_gap;
         "trend reversal" >:: test_trend_reversal;
         "reproducible values" >:: test_reproducible_values;
       ]

let () = run_test_tt_main suite
