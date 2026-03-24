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

(** Make [n] bars with [baseline_vol], then append one event bar with
    [event_vol]. *)
let build_bars ~baseline_vol ~n ~event_vol =
  let prior = List.init n ~f:(fun _ -> make_bar baseline_vol) in
  let event = make_bar event_vol in
  prior @ [ event ]

(* ------------------------------------------------------------------ *)
(* analyze_breakout — Strong confirmation                              *)
(* ------------------------------------------------------------------ *)

let test_strong_breakout _ =
  (* Baseline 1000/week × 4 weeks; event = 2500 → ratio 2.5 → Strong *)
  let bars = build_bars ~baseline_vol:1000 ~n:4 ~event_vol:2500 in
  let result = analyze_breakout ~config:cfg ~bars ~event_idx:4 in
  assert_that result
    (is_some_and (fun r ->
         (match r.confirmation with
         | Strong ratio -> assert_that ratio (float_equal ~epsilon:1e-9 2.5)
         | other ->
             assert_failure
               (Printf.sprintf "Expected Strong, got %s"
                  (show_volume_confirmation other)));
         assert_that r.event_volume (equal_to 2500);
         assert_that r.avg_volume (float_equal 1000.0)))

(* ------------------------------------------------------------------ *)
(* analyze_breakout — Adequate confirmation                            *)
(* ------------------------------------------------------------------ *)

let test_adequate_breakout _ =
  (* Baseline 1000 × 4; event = 1700 → ratio 1.7 → Adequate *)
  let bars = build_bars ~baseline_vol:1000 ~n:4 ~event_vol:1700 in
  let result = analyze_breakout ~config:cfg ~bars ~event_idx:4 in
  assert_that result
    (is_some_and (fun r ->
         match r.confirmation with
         | Adequate _ -> ()
         | other ->
             assert_failure
               (Printf.sprintf "Expected Adequate, got %s"
                  (show_volume_confirmation other))))

(* ------------------------------------------------------------------ *)
(* analyze_breakout — Weak confirmation                                *)
(* ------------------------------------------------------------------ *)

let test_weak_breakout _ =
  (* Baseline 1000 × 4; event = 1100 → ratio 1.1 → Weak *)
  let bars = build_bars ~baseline_vol:1000 ~n:4 ~event_vol:1100 in
  let result = analyze_breakout ~config:cfg ~bars ~event_idx:4 in
  assert_that result
    (is_some_and (fun r ->
         match r.confirmation with
         | Weak _ -> ()
         | other ->
             assert_failure
               (Printf.sprintf "Expected Weak, got %s"
                  (show_volume_confirmation other))))

(* ------------------------------------------------------------------ *)
(* Edge cases                                                           *)
(* ------------------------------------------------------------------ *)

let test_insufficient_prior_bars_returns_none _ =
  (* Only 2 prior bars when lookback=4 → None *)
  let bars = build_bars ~baseline_vol:1000 ~n:2 ~event_vol:3000 in
  let result = analyze_breakout ~config:cfg ~bars ~event_idx:2 in
  assert_that result is_none

let test_out_of_range_event_idx _ =
  let bars = build_bars ~baseline_vol:1000 ~n:4 ~event_vol:2500 in
  assert_that (analyze_breakout ~config:cfg ~bars ~event_idx:(-1)) is_none;
  assert_that (analyze_breakout ~config:cfg ~bars ~event_idx:99) is_none

let test_exactly_2x_is_strong _ =
  (* Exactly at the strong threshold boundary *)
  let bars = build_bars ~baseline_vol:1000 ~n:4 ~event_vol:2000 in
  let r = Option.value_exn (analyze_breakout ~config:cfg ~bars ~event_idx:4) in
  match r.confirmation with
  | Strong _ -> ()
  | other ->
      assert_failure
        (Printf.sprintf "Expected Strong at exactly 2×, got %s"
           (show_volume_confirmation other))

(* ------------------------------------------------------------------ *)
(* is_pullback_confirmed                                                *)
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
  (* Edge case: zero breakout volume → false (avoid division by zero) *)
  assert_bool "zero breakout → false"
    (not
       (is_pullback_confirmed ~config:cfg ~breakout_volume:0
          ~pullback_volume:100))

(* ------------------------------------------------------------------ *)
(* average_volume                                                       *)
(* ------------------------------------------------------------------ *)

let test_average_volume_basic _ =
  let bars = [ make_bar 1000; make_bar 2000; make_bar 3000 ] in
  let avg = average_volume ~bars ~n:3 in
  assert_that avg (float_equal 2000.0)

let test_average_volume_takes_last_n _ =
  (* [n=2] of [1000, 2000, 3000] → last 2 = [2000, 3000] → avg 2500 *)
  let bars = [ make_bar 1000; make_bar 2000; make_bar 3000 ] in
  let avg = average_volume ~bars ~n:2 in
  assert_that avg (float_equal 2500.0)

let test_average_volume_empty _ =
  assert_that (average_volume ~bars:[] ~n:3) (float_equal 0.0)

let suite =
  "volume_tests"
  >::: [
         "test_strong_breakout" >:: test_strong_breakout;
         "test_adequate_breakout" >:: test_adequate_breakout;
         "test_weak_breakout" >:: test_weak_breakout;
         "test_insufficient_prior_bars_returns_none"
         >:: test_insufficient_prior_bars_returns_none;
         "test_out_of_range_event_idx" >:: test_out_of_range_event_idx;
         "test_exactly_2x_is_strong" >:: test_exactly_2x_is_strong;
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
