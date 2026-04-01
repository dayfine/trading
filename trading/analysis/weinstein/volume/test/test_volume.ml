open OUnit2
open Core
open Matchers
open Volume
open Weinstein_types
open Types

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let cfg = default_config

let make_bar ?(price = 100.0) volume =
  {
    Daily_price.date = Date.of_string "2024-01-01";
    open_price = price;
    high_price = price;
    low_price = price;
    close_price = price;
    adjusted_close = price;
    volume;
  }

(** [n] baseline bars followed by one event bar. *)
let build_bars ~baseline_vol ~n ~event_vol =
  List.init n ~f:(fun _ -> make_bar baseline_vol) @ [ make_bar event_vol ]

(* ------------------------------------------------------------------ *)
(* analyze_breakout — confirmation classes                             *)
(* ------------------------------------------------------------------ *)

let test_strong_breakout _ =
  (* Baseline 1000/bar × 4; event = 2500 → ratio 2.5 → Strong *)
  let bars = build_bars ~baseline_vol:1000 ~n:4 ~event_vol:2500 in
  assert_that
    (analyze_breakout ~config:cfg ~bars ~event_idx:4)
    (is_some_and (fun r ->
         assert_that r.confirmation
           (equal_to (Strong 2.5 : volume_confirmation));
         assert_that r.event_volume (equal_to 2500);
         assert_that r.avg_volume (float_equal 1000.0)))

let test_adequate_breakout _ =
  (* event = 1700 → ratio 1.7, between adequate (1.5) and strong (2.0) *)
  let bars = build_bars ~baseline_vol:1000 ~n:4 ~event_vol:1700 in
  assert_that
    (analyze_breakout ~config:cfg ~bars ~event_idx:4)
    (is_some_and
       (field
          (fun r -> r.confirmation)
          (matching
             (function Adequate _ -> Some () | _ -> None)
             (equal_to ()))))

let test_weak_breakout _ =
  (* event = 1100 → ratio 1.1, below adequate threshold (1.5) *)
  let bars = build_bars ~baseline_vol:1000 ~n:4 ~event_vol:1100 in
  assert_that
    (analyze_breakout ~config:cfg ~bars ~event_idx:4)
    (is_some_and
       (field
          (fun r -> r.confirmation)
          (matching (function Weak _ -> Some () | _ -> None) (equal_to ()))))

(* ------------------------------------------------------------------ *)
(* analyze_breakout — boundary and edge cases                          *)
(* ------------------------------------------------------------------ *)

let test_exactly_2x_is_strong _ =
  let bars = build_bars ~baseline_vol:1000 ~n:4 ~event_vol:2000 in
  assert_that
    (analyze_breakout ~config:cfg ~bars ~event_idx:4)
    (is_some_and (fun r ->
         assert_that r.confirmation
           (equal_to (Strong 2.0 : volume_confirmation))))

let test_insufficient_prior_bars_returns_none _ =
  (* Only 2 prior bars when lookback_bars=4 → None *)
  let bars = build_bars ~baseline_vol:1000 ~n:2 ~event_vol:3000 in
  assert_that (analyze_breakout ~config:cfg ~bars ~event_idx:2) is_none

let test_out_of_range_event_idx _ =
  let bars = build_bars ~baseline_vol:1000 ~n:4 ~event_vol:2500 in
  assert_that (analyze_breakout ~config:cfg ~bars ~event_idx:(-1)) is_none;
  assert_that (analyze_breakout ~config:cfg ~bars ~event_idx:99) is_none

(* ------------------------------------------------------------------ *)
(* is_pullback_confirmed                                               *)
(* ------------------------------------------------------------------ *)

let test_pullback_confirmed_low_volume _ =
  (* Breakout 2000, pullback 400 → ratio 0.2 ≤ 0.25 → confirmed *)
  assert_bool "pullback confirmed"
    (is_pullback_confirmed ~config:cfg ~breakout_volume:2000
       ~pullback_volume:400)

let test_pullback_rejected_high_volume _ =
  (* Breakout 2000, pullback 600 → ratio 0.3 > 0.25 → not confirmed *)
  assert_bool "pullback not confirmed"
    (not
       (is_pullback_confirmed ~config:cfg ~breakout_volume:2000
          ~pullback_volume:600))

let test_pullback_zero_breakout_volume _ =
  assert_bool "zero breakout → false"
    (not
       (is_pullback_confirmed ~config:cfg ~breakout_volume:0
          ~pullback_volume:100))

(* ------------------------------------------------------------------ *)
(* average_volume                                                      *)
(* ------------------------------------------------------------------ *)

let test_average_volume_basic _ =
  let bars = [ make_bar 1000; make_bar 2000; make_bar 3000 ] in
  assert_that (average_volume ~bars ~n:3) (float_equal 2000.0)

let test_average_volume_takes_last_n _ =
  (* last 2 of [1000, 2000, 3000] → avg 2500 *)
  let bars = [ make_bar 1000; make_bar 2000; make_bar 3000 ] in
  assert_that (average_volume ~bars ~n:2) (float_equal 2500.0)

let test_average_volume_empty _ =
  assert_that (average_volume ~bars:[] ~n:3) (float_equal 0.0)

let suite =
  "volume_tests"
  >::: [
         "test_strong_breakout" >:: test_strong_breakout;
         "test_adequate_breakout" >:: test_adequate_breakout;
         "test_weak_breakout" >:: test_weak_breakout;
         "test_exactly_2x_is_strong" >:: test_exactly_2x_is_strong;
         "test_insufficient_prior_bars_returns_none"
         >:: test_insufficient_prior_bars_returns_none;
         "test_out_of_range_event_idx" >:: test_out_of_range_event_idx;
         "test_pullback_confirmed_low_volume"
         >:: test_pullback_confirmed_low_volume;
         "test_pullback_rejected_high_volume"
         >:: test_pullback_rejected_high_volume;
         "test_pullback_zero_breakout_volume"
         >:: test_pullback_zero_breakout_volume;
         "test_average_volume_basic" >:: test_average_volume_basic;
         "test_average_volume_takes_last_n" >:: test_average_volume_takes_last_n;
         "test_average_volume_empty" >:: test_average_volume_empty;
       ]

let () = run_test_tt_main suite
