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
      printf "[%d] %s: O=%.2f H=%.2f L=%.2f C=%.2f\n" i (Date.to_string p.date)
        p.open_price p.high_price p.low_price p.close_price)

(** Test: Uptrend generates increasing prices *)
let test_uptrend_sequence _ =
  let prices =
    Price_generators.make_price_sequence ~symbol:"TEST"
      ~start_date:(date_of_string "2024-01-01")
      ~days:5 ~base_price:100.0 ~trend:(Price_generators.Uptrend 1.0)
      ~volatility:0.01
  in

  print_price_sequence "Uptrend 1% daily" prices;

  (* Verify we got 5 days with exact expected values *)
  assert_equal 5 (List.length prices);

  let day1 = List.nth_exn prices 0 in
  let day2 = List.nth_exn prices 1 in
  let day3 = List.nth_exn prices 2 in
  let day4 = List.nth_exn prices 3 in
  let day5 = List.nth_exn prices 4 in

  (* Day 1: 2024-01-01 *)
  assert_that day1.date (equal_to (date_of_string "2024-01-01"));
  assert_that day1.open_price (float_equal ~epsilon:0.01 100.82);
  assert_that day1.high_price (float_equal ~epsilon:0.01 101.55);
  assert_that day1.low_price (float_equal ~epsilon:0.01 100.45);
  assert_that day1.close_price (float_equal ~epsilon:0.01 101.18);

  (* Day 2: 2024-01-02 - prices continuing uptrend *)
  assert_that day2.date (equal_to (date_of_string "2024-01-02"));
  assert_that day2.close_price (float_equal ~epsilon:0.01 102.52);

  (* Day 3: 2024-01-03 *)
  assert_that day3.date (equal_to (date_of_string "2024-01-03"));
  assert_that day3.close_price (float_equal ~epsilon:0.01 103.55);

  (* Day 4: 2024-01-04 *)
  assert_that day4.date (equal_to (date_of_string "2024-01-04"));
  assert_that day4.close_price (float_equal ~epsilon:0.01 104.62);

  (* Day 5: 2024-01-05 - final price shows clear uptrend *)
  assert_that day5.date (equal_to (date_of_string "2024-01-05"));
  assert_that day5.close_price (float_equal ~epsilon:0.01 105.88)

(** Test: Downtrend generates decreasing prices *)
let test_downtrend_sequence _ =
  let prices =
    Price_generators.make_price_sequence ~symbol:"TEST"
      ~start_date:(date_of_string "2024-01-01")
      ~days:5 ~base_price:100.0 ~trend:(Price_generators.Downtrend 2.0)
      ~volatility:0.01
  in

  print_price_sequence "Downtrend 2% daily" prices;

  assert_equal 5 (List.length prices);

  (* Verify exact prices showing clear downtrend *)
  let day1 = List.nth_exn prices 0 in
  let day5 = List.nth_exn prices 4 in

  assert_that day1.date (equal_to (date_of_string "2024-01-01"));
  assert_that day1.close_price (float_equal ~epsilon:0.01 98.18);

  assert_that day5.date (equal_to (date_of_string "2024-01-05"));
  assert_that day5.close_price (float_equal ~epsilon:0.01 91.06);

  (* Day 5 is clearly lower than day 1: 91.06 < 98.18 *)
  assert_bool "Downtrend: day 5 < day 1"
    Float.(day5.close_price < day1.close_price)

(** Test: Sideways trend maintains stable prices *)
let test_sideways_sequence _ =
  let prices =
    Price_generators.make_price_sequence ~symbol:"TEST"
      ~start_date:(date_of_string "2024-01-01")
      ~days:5 ~base_price:100.0 ~trend:Price_generators.Sideways
      ~volatility:0.01
  in

  print_price_sequence "Sideways" prices;

  assert_equal 5 (List.length prices);

  (* Verify exact prices - all stay very close to 100.0 *)
  let close_prices =
    List.map prices ~f:(fun p -> p.Types.Daily_price.close_price)
  in
  assert_that close_prices
    (elements_are
       [
         float_equal ~epsilon:0.01 100.18;
         float_equal ~epsilon:0.01 100.50;
         float_equal ~epsilon:0.01 100.51;
         float_equal ~epsilon:0.01 100.54;
         float_equal ~epsilon:0.01 100.74;
       ]);

  (* All prices stay within ~1% of base price 100.0 *)
  List.iter prices ~f:(fun (p : Types.Daily_price.t) ->
      assert_bool "Sideways: price stays near 100.0"
        Float.(abs (p.close_price -. 100.0) < 1.0))

(** Test: Price spike creates a jump at specific date *)
let test_price_spike _ =
  let base_prices =
    Price_generators.make_price_sequence ~symbol:"TEST"
      ~start_date:(date_of_string "2024-01-01")
      ~days:5 ~base_price:100.0 ~trend:Price_generators.Sideways
      ~volatility:0.01
  in
  let spiked_prices =
    Price_generators.with_spike base_prices
      ~spike_date:(date_of_string "2024-01-03")
      ~spike_percent:20.0
  in

  print_price_sequence "With 20% spike on 2024-01-03" spiked_prices;

  (* Verify exact prices before, during, and after spike *)
  let day2 = List.nth_exn spiked_prices 1 in
  let day3 = List.nth_exn spiked_prices 2 in
  let day4 = List.nth_exn spiked_prices 3 in

  (* Day 2: normal price before spike *)
  assert_that day2.date (equal_to (date_of_string "2024-01-02"));
  assert_that day2.close_price (float_equal ~epsilon:0.01 100.50);

  (* Day 3: 20% spike - jumps to 120.61 *)
  assert_that day3.date (equal_to (date_of_string "2024-01-03"));
  assert_that day3.close_price (float_equal ~epsilon:0.01 120.61);

  (* Day 4: back to normal ~100 range *)
  assert_that day4.date (equal_to (date_of_string "2024-01-04"));
  assert_that day4.close_price (float_equal ~epsilon:0.01 100.54)

(** Test: Price gap creates discontinuity *)
let test_price_gap _ =
  let base_prices =
    Price_generators.make_price_sequence ~symbol:"TEST"
      ~start_date:(date_of_string "2024-01-01")
      ~days:5 ~base_price:100.0 ~trend:Price_generators.Sideways
      ~volatility:0.01
  in
  let gapped_prices =
    Price_generators.with_gap base_prices
      ~gap_date:(date_of_string "2024-01-03")
      ~gap_percent:10.0
  in

  print_price_sequence "With 10% gap on 2024-01-03" gapped_prices;

  (* Verify exact prices showing the 10% gap *)
  let day2 = List.nth_exn gapped_prices 1 in
  let day3 = List.nth_exn gapped_prices 2 in

  (* Day 2 closes at 100.50 *)
  assert_that day2.date (equal_to (date_of_string "2024-01-02"));
  assert_that day2.close_price (float_equal ~epsilon:0.01 100.50);

  (* Day 3 opens at 110.55 (10% gap up from 100.50) and closes at 110.56 *)
  assert_that day3.date (equal_to (date_of_string "2024-01-03"));
  assert_that day3.open_price (float_equal ~epsilon:0.01 110.55);
  assert_that day3.close_price (float_equal ~epsilon:0.01 110.56);

  (* Verify the gap ratio: 110.55 / 100.50 ≈ 1.10 *)
  let gap_ratio = day3.open_price /. day2.close_price in
  assert_that gap_ratio (float_equal ~epsilon:0.01 1.10)

(** Test: Trend reversal changes direction *)
let test_trend_reversal _ =
  let prices =
    Price_generators.make_price_sequence ~symbol:"TEST"
      ~start_date:(date_of_string "2024-01-01")
      ~days:10 ~base_price:100.0 ~trend:(Price_generators.Uptrend 1.0)
      ~volatility:0.01
  in
  let reversed_prices =
    Price_generators.with_reversal prices
      ~reversal_date:(date_of_string "2024-01-06")
      ~new_trend:(Price_generators.Downtrend 1.5)
  in

  print_price_sequence "Uptrend → Downtrend at 2024-01-06" reversed_prices;

  assert_equal 10 (List.length reversed_prices);

  (* Verify exact prices showing the trend reversal *)
  let day1 = List.nth_exn reversed_prices 0 in
  let day5 = List.nth_exn reversed_prices 4 in
  let day6 = List.nth_exn reversed_prices 5 in
  let day10 = List.nth_exn reversed_prices 9 in

  (* Days 1-5: Uptrend from 101.18 to 105.88 *)
  assert_that day1.date (equal_to (date_of_string "2024-01-01"));
  assert_that day1.close_price (float_equal ~epsilon:0.01 101.18);

  assert_that day5.date (equal_to (date_of_string "2024-01-05"));
  assert_that day5.close_price (float_equal ~epsilon:0.01 105.88);

  (* Day 6: Reversal starts - slight increase to 105.95 then downtrend begins *)
  assert_that day6.date (equal_to (date_of_string "2024-01-06"));
  assert_that day6.close_price (float_equal ~epsilon:0.01 105.95);

  (* Day 10: Downtrend ends at 100.84 (lower than peak) *)
  assert_that day10.date (equal_to (date_of_string "2024-01-10"));
  assert_that day10.close_price (float_equal ~epsilon:0.01 100.84);

  (* Verify trend directions *)
  assert_bool "Uptrend: day 5 > day 1"
    Float.(day5.close_price > day1.close_price);
  assert_bool "Downtrend: day 10 < day 6"
    Float.(day10.close_price < day6.close_price)

(** Test: Verify specific generated values for reproducibility *)
let test_reproducible_values _ =
  (* Generate a sequence with fixed seed *)
  let prices =
    Price_generators.make_price_sequence ~symbol:"AAPL"
      ~start_date:(date_of_string "2024-01-01")
      ~days:3 ~base_price:150.0 ~trend:(Price_generators.Uptrend 0.5)
      ~volatility:0.01
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
