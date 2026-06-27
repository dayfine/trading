open OUnit2
open Core
open Matchers
open Weinstein_strategy

(* Build a daily bar with explicit close + volume; OHLC default around close. *)
let make_bar date ~close ~volume =
  {
    Types.Daily_price.date = Date.of_string date;
    open_price = close;
    high_price = close *. 1.01;
    low_price = close *. 0.99;
    close_price = close;
    adjusted_close = close;
    volume;
    active_through = None;
  }

(* close 10, vol 1000 => 10_000 dollar-volume per bar. *)
let bars_uniform =
  [
    make_bar "2024-01-02" ~close:10.0 ~volume:1000;
    make_bar "2024-01-03" ~close:10.0 ~volume:1000;
    make_bar "2024-01-04" ~close:10.0 ~volume:1000;
  ]

let test_uniform_mean _ =
  assert_that
    (Liquidity_metric.dollar_adv ~lookback_days:3 bars_uniform)
    (is_some_and (float_equal 10_000.0))

let test_window_takes_trailing _ =
  (* Trailing 2 of [5000; 10000; 20000] dollar-volume = mean(10000, 20000). *)
  let bars =
    [
      make_bar "2024-01-02" ~close:5.0 ~volume:1000;
      make_bar "2024-01-03" ~close:10.0 ~volume:1000;
      make_bar "2024-01-04" ~close:20.0 ~volume:1000;
    ]
  in
  assert_that
    (Liquidity_metric.dollar_adv ~lookback_days:2 bars)
    (is_some_and (float_equal 15_000.0))

let test_window_longer_than_bars_uses_all _ =
  (* lookback 10 but only 3 bars: averages over the 3 present (no padding). *)
  assert_that
    (Liquidity_metric.dollar_adv ~lookback_days:10 bars_uniform)
    (is_some_and (float_equal 10_000.0))

let test_empty_bars_none _ =
  assert_that (Liquidity_metric.dollar_adv ~lookback_days:20 []) is_none

let test_nonpositive_lookback_none _ =
  assert_that
    (Liquidity_metric.dollar_adv ~lookback_days:0 bars_uniform)
    is_none

let suite =
  "liquidity_metric"
  >::: [
         "uniform mean" >:: test_uniform_mean;
         "window takes trailing" >:: test_window_takes_trailing;
         "window longer than bars uses all"
         >:: test_window_longer_than_bars_uses_all;
         "empty bars -> none" >:: test_empty_bars_none;
         "nonpositive lookback -> none" >:: test_nonpositive_lookback_none;
       ]

let () = run_test_tt_main suite
