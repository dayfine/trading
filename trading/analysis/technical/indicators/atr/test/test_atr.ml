open Core
open OUnit2
open Matchers
open Types

let _mk_ohlc_bar ~date ~o ~h ~l ~c : Daily_price.t =
  {
    date;
    open_price = o;
    high_price = h;
    low_price = l;
    close_price = c;
    volume = 0;
    adjusted_close = c;
  }

let _flat_bars ~n ~start_date ~base =
  List.init n ~f:(fun i ->
      let date = Date.add_days start_date i in
      _mk_ohlc_bar ~date ~o:base ~h:base ~l:base ~c:base)

(** Flat bars (o=h=l=c) have zero range and zero gap — ATR is exactly 0.0. *)
let test_atr_zero_on_flat_bars _ =
  let start_date = Date.create_exn ~y:2023 ~m:Jan ~d:2 in
  let bars = _flat_bars ~n:20 ~start_date ~base:100.0 in
  assert_that (Atr.atr ~period:14 bars) (is_some_and (float_equal 0.0))

(** Bars with constant high-low range of 2.0 and no gaps → ATR = 2.0. *)
let test_atr_constant_range _ =
  let start_date = Date.create_exn ~y:2023 ~m:Jan ~d:2 in
  let bars =
    List.init 20 ~f:(fun i ->
        let date = Date.add_days start_date i in
        _mk_ohlc_bar ~date ~o:50.0 ~h:51.0 ~l:49.0 ~c:50.0)
  in
  assert_that (Atr.atr ~period:14 bars) (is_some_and (float_equal 2.0))

let test_atr_none_when_too_short _ =
  let start_date = Date.create_exn ~y:2023 ~m:Jan ~d:2 in
  let bars = _flat_bars ~n:5 ~start_date ~base:100.0 in
  assert_that (Atr.atr ~period:14 bars) is_none

let test_atr_zero_period_raises _ =
  let start_date = Date.create_exn ~y:2023 ~m:Jan ~d:2 in
  let bars = _flat_bars ~n:5 ~start_date ~base:100.0 in
  assert_raises (Invalid_argument "Atr.atr: period must be positive") (fun () ->
      Atr.atr ~period:0 bars)

let test_true_range_no_gap _ =
  let bar =
    _mk_ohlc_bar
      ~date:(Date.create_exn ~y:2023 ~m:Jan ~d:2)
      ~o:100.0 ~h:101.0 ~l:99.0 ~c:100.0
  in
  assert_that (Atr.true_range ~prev_close:100.0 bar) (float_equal 2.0)

let test_true_range_gap_up _ =
  (* prev_close=90, today's high=101, low=99 → gap_up=11 dominates range=2 *)
  let bar =
    _mk_ohlc_bar
      ~date:(Date.create_exn ~y:2023 ~m:Jan ~d:2)
      ~o:100.0 ~h:101.0 ~l:99.0 ~c:100.0
  in
  assert_that (Atr.true_range ~prev_close:90.0 bar) (float_equal 11.0)

let test_true_range_series_skips_first _ =
  (* First bar has no prior close, so output is length n-1. *)
  let start_date = Date.create_exn ~y:2023 ~m:Jan ~d:2 in
  let bars = _flat_bars ~n:5 ~start_date ~base:100.0 in
  assert_that (List.length (Atr.true_range_series bars)) (equal_to 4)

let test_true_range_series_empty_when_not_enough_data _ =
  let start_date = Date.create_exn ~y:2023 ~m:Jan ~d:2 in
  let bars = _flat_bars ~n:1 ~start_date ~base:100.0 in
  assert_that (List.length (Atr.true_range_series bars)) (equal_to 0)

let suite =
  "Atr_test"
  >::: [
         "atr_zero_on_flat_bars" >:: test_atr_zero_on_flat_bars;
         "atr_constant_range" >:: test_atr_constant_range;
         "atr_none_when_too_short" >:: test_atr_none_when_too_short;
         "atr_zero_period_raises" >:: test_atr_zero_period_raises;
         "true_range_no_gap" >:: test_true_range_no_gap;
         "true_range_gap_up" >:: test_true_range_gap_up;
         "true_range_series_skips_first" >:: test_true_range_series_skips_first;
         "true_range_series_empty_when_not_enough_data"
         >:: test_true_range_series_empty_when_not_enough_data;
       ]

let () = run_test_tt_main suite
