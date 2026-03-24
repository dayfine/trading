open OUnit2
open Core
open Stage
open Weinstein_types
open Types

(* ------------------------------------------------------------------ *)
(* Test helpers                                                         *)
(* ------------------------------------------------------------------ *)

let cfg = default_config

(** Make a minimal Daily_price bar with just the adjusted close set. *)
let make_bar ?(date = "2024-01-01") adjusted_close =
  { Daily_price.date = Date.of_string date
  ; open_price = adjusted_close
  ; high_price = adjusted_close
  ; low_price = adjusted_close
  ; close_price = adjusted_close
  ; volume = 1000
  ; adjusted_close
  }

(** Make [n] bars with the given price, assigning consecutive Monday dates. *)
let bars_of_prices prices =
  let base = Date.of_string "2020-01-06" in (* Monday *)
  List.mapi prices ~f:(fun i p ->
      make_bar ~date:(Date.to_string (Date.add_days base (i * 7))) p)

(** Build 30 bars trending up from [start] to [stop_]. *)
let rising_bars ?(n = 35) start stop_ =
  let step = (stop_ -. start) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i -> start +. (Float.of_int i *. step)) |> bars_of_prices

(** Build [n] bars at flat price. *)
let flat_bars ?(n = 35) price =
  List.init n ~f:(fun _ -> price) |> bars_of_prices

(** Build bars declining from [start] to [stop_]. *)
let declining_bars ?(n = 35) start stop_ =
  let step = (start -. stop_) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i -> start -. (Float.of_int i *. step)) |> bars_of_prices

(* ------------------------------------------------------------------ *)
(* Stage 2 tests — rising MA, price above MA                           *)
(* ------------------------------------------------------------------ *)

let test_stage2_rising_trend _ =
  (* 35 bars of rising prices: MA will be rising, prices above MA *)
  let bars = rising_bars 50.0 100.0 in
  let result = classify ~config:cfg ~bars ~prior_stage:None in
  (match result.stage with
   | Stage2 _ -> ()
   | other ->
     assert_failure
       (Printf.sprintf "Expected Stage2, got %s" (show_stage other)));
  assert_equal Rising result.ma_slope

let test_stage2_advancing_weeks _ =
  (* Build on prior Stage2 to increment weeks_advancing *)
  let bars = rising_bars 50.0 100.0 in
  let prior = Some (Stage2 { weeks_advancing = 5; late = false }) in
  let result = classify ~config:cfg ~bars ~prior_stage:prior in
  (match result.stage with
   | Stage2 { weeks_advancing = 6; _ } -> ()
   | other ->
     assert_failure
       (Printf.sprintf "Expected Stage2 with 6 weeks, got %s" (show_stage other)))

(* ------------------------------------------------------------------ *)
(* Stage 4 tests — declining MA, price below MA                        *)
(* ------------------------------------------------------------------ *)

let test_stage4_declining_trend _ =
  (* 35 bars of declining prices: MA declining, prices below MA *)
  let bars = declining_bars 100.0 50.0 in
  let result = classify ~config:cfg ~bars ~prior_stage:None in
  (match result.stage with
   | Stage4 _ -> ()
   | other ->
     assert_failure
       (Printf.sprintf "Expected Stage4, got %s" (show_stage other)));
  assert_equal Declining result.ma_slope

(* ------------------------------------------------------------------ *)
(* Stage 1 tests — flat MA after decline, prior Stage 4                *)
(* ------------------------------------------------------------------ *)

let test_stage1_flat_after_decline _ =
  (* Start declining, then level off for many weeks so the 30-week MA flattens.
     We need enough flat bars that the MA slope falls within the flat threshold. *)
  let declining = List.init 15 ~f:(fun i -> 100.0 -. Float.of_int i) in
  let flat = List.init 50 ~f:(fun _ -> 85.0) in
  let bars = declining @ flat |> bars_of_prices in
  let prior = Some (Stage4 { weeks_declining = 10 }) in
  let result = classify ~config:cfg ~bars ~prior_stage:prior in
  (match result.stage with
   | Stage1 _ -> ()
   | other ->
     assert_failure
       (Printf.sprintf "Expected Stage1 after Stage4 flat, got %s" (show_stage other)))

(* ------------------------------------------------------------------ *)
(* Stage 3 tests — flat MA after advance, prior Stage 2                *)
(* ------------------------------------------------------------------ *)

let test_stage3_flat_after_advance _ =
  (* Start rising, then level off for many weeks so the 30-week MA flattens. *)
  let rising = List.init 15 ~f:(fun i -> 50.0 +. Float.of_int i) in
  let flat = List.init 50 ~f:(fun _ -> 65.0) in
  let bars = rising @ flat |> bars_of_prices in
  let prior = Some (Stage2 { weeks_advancing = 10; late = false }) in
  let result = classify ~config:cfg ~bars ~prior_stage:prior in
  (match result.stage with
   | Stage3 _ -> ()
   | other ->
     assert_failure
       (Printf.sprintf "Expected Stage3 after Stage2 flat, got %s" (show_stage other)))

(* ------------------------------------------------------------------ *)
(* Transition detection                                                 *)
(* ------------------------------------------------------------------ *)

let test_no_transition_same_stage _ =
  let bars = rising_bars 50.0 100.0 in
  let prior = Some (Stage2 { weeks_advancing = 3; late = false }) in
  let result = classify ~config:cfg ~bars ~prior_stage:prior in
  (* Stage2 → Stage2: no transition *)
  (match result.transition with
   | None -> ()
   | Some (from, to_) ->
     assert_failure
       (Printf.sprintf "Expected no transition, got %s → %s"
          (show_stage from) (show_stage to_)))

let test_transition_from_stage1_to_stage2 _ =
  let bars = rising_bars 50.0 100.0 in
  let prior = Some (Stage1 { weeks_in_base = 10 }) in
  let result = classify ~config:cfg ~bars ~prior_stage:prior in
  (match result.transition with
   | Some (Stage1 _, Stage2 _) -> ()
   | Some (from, to_) ->
     assert_failure
       (Printf.sprintf "Expected Stage1→Stage2 transition, got %s → %s"
          (show_stage from) (show_stage to_))
   | None -> assert_failure "Expected a transition but got None")

(* ------------------------------------------------------------------ *)
(* Insufficient data edge case                                          *)
(* ------------------------------------------------------------------ *)

let test_insufficient_data_returns_stage1 _ =
  (* Fewer bars than ma_period: should return Stage1 with zero ma_value *)
  let bars = List.init 10 ~f:(fun _ -> 50.0) |> bars_of_prices in
  let result = classify ~config:cfg ~bars ~prior_stage:None in
  (match result.stage with
   | Stage1 _ -> ()
   | other ->
     assert_failure
       (Printf.sprintf "Expected Stage1 for insufficient data, got %s"
          (show_stage other)));
  assert_equal 0.0 result.ma_value

(* ------------------------------------------------------------------ *)
(* Purity: same inputs → same outputs                                  *)
(* ------------------------------------------------------------------ *)

let test_pure_same_inputs_same_output _ =
  let bars = rising_bars 50.0 100.0 in
  let prior = Some (Stage1 { weeks_in_base = 5 }) in
  let r1 = classify ~config:cfg ~bars ~prior_stage:prior in
  let r2 = classify ~config:cfg ~bars ~prior_stage:prior in
  assert_equal (show_stage r1.stage) (show_stage r2.stage);
  assert_equal r1.ma_value r2.ma_value;
  assert_equal r1.ma_slope r2.ma_slope;
  assert_equal r1.ma_slope_pct r2.ma_slope_pct

(* ------------------------------------------------------------------ *)
(* MA value correctness                                                 *)
(* ------------------------------------------------------------------ *)

let test_ma_value_non_zero _ =
  let bars = flat_bars 100.0 in
  let result = classify ~config:cfg ~bars ~prior_stage:None in
  (* MA of constant 100.0 series should be 100.0 *)
  assert_equal 100.0 result.ma_value

let test_ma_slope_flat_for_constant_series _ =
  let bars = flat_bars 100.0 in
  let result = classify ~config:cfg ~bars ~prior_stage:None in
  assert_equal Flat result.ma_slope;
  assert_equal 0.0 result.ma_slope_pct

(* ------------------------------------------------------------------ *)
(* above_ma_count                                                       *)
(* ------------------------------------------------------------------ *)

let test_above_ma_count_all_above _ =
  (* Rising series: all recent bars should be above the (lagging) MA *)
  let bars = rising_bars 50.0 200.0 in
  let result = classify ~config:cfg ~bars ~prior_stage:None in
  (* In a strong uptrend, all confirm_weeks bars should be above MA *)
  assert_bool "above_ma_count > 0" (result.above_ma_count > 0)

let suite =
  "stage_tests"
  >::: [ "test_stage2_rising_trend" >:: test_stage2_rising_trend
       ; "test_stage2_advancing_weeks" >:: test_stage2_advancing_weeks
       ; "test_stage4_declining_trend" >:: test_stage4_declining_trend
       ; "test_stage1_flat_after_decline" >:: test_stage1_flat_after_decline
       ; "test_stage3_flat_after_advance" >:: test_stage3_flat_after_advance
       ; "test_no_transition_same_stage" >:: test_no_transition_same_stage
       ; "test_transition_from_stage1_to_stage2"
         >:: test_transition_from_stage1_to_stage2
       ; "test_insufficient_data_returns_stage1"
         >:: test_insufficient_data_returns_stage1
       ; "test_pure_same_inputs_same_output"
         >:: test_pure_same_inputs_same_output
       ; "test_ma_value_non_zero" >:: test_ma_value_non_zero
       ; "test_ma_slope_flat_for_constant_series"
         >:: test_ma_slope_flat_for_constant_series
       ; "test_above_ma_count_all_above" >:: test_above_ma_count_all_above
       ]

let () = run_test_tt_main suite
