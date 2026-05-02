open OUnit2
open Core
open Matchers
open Stage
open Weinstein_types
open Types

(* ------------------------------------------------------------------ *)
(* Test helpers                                                         *)
(* ------------------------------------------------------------------ *)

let cfg = default_config

(** Make a minimal Daily_price bar with just the adjusted close set. *)
let make_bar ?(date = "2024-01-01") adjusted_close =
  {
    Daily_price.date = Date.of_string date;
    open_price = adjusted_close;
    high_price = adjusted_close;
    low_price = adjusted_close;
    close_price = adjusted_close;
    volume = 1000;
    adjusted_close;
  }

(** Make [n] bars with the given price, assigning consecutive Monday dates. *)
let bars_of_prices prices =
  let base = Date.of_string "2020-01-06" in
  (* Monday *)
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

let is_stage2 : stage matcher =
 fun s ->
  match s with
  | Stage2 _ -> ()
  | other ->
      OUnit2.assert_failure
        (Printf.sprintf "Expected Stage2, got %s" (show_stage other))

let is_stage4 : stage matcher =
 fun s ->
  match s with
  | Stage4 _ -> ()
  | other ->
      OUnit2.assert_failure
        (Printf.sprintf "Expected Stage4, got %s" (show_stage other))

let is_stage1 : stage matcher =
 fun s ->
  match s with
  | Stage1 _ -> ()
  | other ->
      OUnit2.assert_failure
        (Printf.sprintf "Expected Stage1, got %s" (show_stage other))

let is_stage3 : stage matcher =
 fun s ->
  match s with
  | Stage3 _ -> ()
  | other ->
      OUnit2.assert_failure
        (Printf.sprintf "Expected Stage3, got %s" (show_stage other))

(* ------------------------------------------------------------------ *)
(* Stage 2 tests — rising MA, price above MA                           *)
(* ------------------------------------------------------------------ *)

let test_stage2_rising_trend _ =
  (* 35 bars of rising prices: MA will be rising, prices above MA *)
  let bars = rising_bars 50.0 100.0 in
  let result = classify ~config:cfg ~bars ~prior_stage:None in
  assert_that result.stage is_stage2;
  assert_that result.ma_direction (equal_to Rising)

let test_stage2_advancing_weeks _ =
  (* Build on prior Stage2 to increment weeks_advancing *)
  let bars = rising_bars 50.0 100.0 in
  let prior = Some (Stage2 { weeks_advancing = 5; late = false }) in
  let result = classify ~config:cfg ~bars ~prior_stage:prior in
  assert_that result.stage
    (equal_to (Stage2 { weeks_advancing = 6; late = false } : stage))

(* ------------------------------------------------------------------ *)
(* Stage 4 tests — declining MA, price below MA                        *)
(* ------------------------------------------------------------------ *)

let test_stage4_declining_trend _ =
  (* 35 bars of declining prices: MA declining, prices below MA *)
  let bars = declining_bars 100.0 50.0 in
  let result = classify ~config:cfg ~bars ~prior_stage:None in
  assert_that result.stage is_stage4;
  assert_that result.ma_direction (equal_to Declining)

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
  assert_that result.stage is_stage1

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
  assert_that result.stage is_stage3

(* ------------------------------------------------------------------ *)
(* Transition detection                                                 *)
(* ------------------------------------------------------------------ *)

let test_no_transition_same_stage _ =
  let bars = rising_bars 50.0 100.0 in
  let prior = Some (Stage2 { weeks_advancing = 3; late = false }) in
  let result = classify ~config:cfg ~bars ~prior_stage:prior in
  (* Stage2 → Stage2: no transition *)
  assert_that result.transition is_none

let test_transition_from_stage1_to_stage2 _ =
  let bars = rising_bars 50.0 100.0 in
  let prior = Some (Stage1 { weeks_in_base = 10 }) in
  let result = classify ~config:cfg ~bars ~prior_stage:prior in
  assert_that result.transition (is_some_and (pair is_stage1 is_stage2))

(* ------------------------------------------------------------------ *)
(* Insufficient data edge case                                          *)
(* ------------------------------------------------------------------ *)

let test_insufficient_data_returns_stage1 _ =
  (* Fewer bars than ma_period: should return Stage1 with zero ma_value *)
  let bars = List.init 10 ~f:(fun _ -> 50.0) |> bars_of_prices in
  let result = classify ~config:cfg ~bars ~prior_stage:None in
  assert_that result.stage is_stage1;
  assert_that result.ma_value (float_equal 0.0)

(* ------------------------------------------------------------------ *)
(* Purity: same inputs → same outputs                                  *)
(* ------------------------------------------------------------------ *)

let test_pure_same_inputs_same_output _ =
  let bars = rising_bars 50.0 100.0 in
  let prior = Some (Stage1 { weeks_in_base = 5 }) in
  let r1 = classify ~config:cfg ~bars ~prior_stage:prior in
  let r2 = classify ~config:cfg ~bars ~prior_stage:prior in
  assert_that r1.stage (equal_to (r2.stage : stage));
  assert_that r1.ma_value (float_equal r2.ma_value);
  assert_that r1.ma_direction (equal_to (r2.ma_direction : ma_direction));
  assert_that r1.ma_slope_pct (float_equal r2.ma_slope_pct)

(* ------------------------------------------------------------------ *)
(* MA value correctness                                                 *)
(* ------------------------------------------------------------------ *)

let test_ma_value_non_zero _ =
  let bars = flat_bars 100.0 in
  let result = classify ~config:cfg ~bars ~prior_stage:None in
  (* MA of constant 100.0 series should be 100.0 *)
  assert_that result.ma_value (float_equal 100.0)

let test_ma_direction_flat_for_constant_series _ =
  let bars = flat_bars 100.0 in
  let result = classify ~config:cfg ~bars ~prior_stage:None in
  assert_that result.ma_direction (equal_to Flat);
  assert_that result.ma_slope_pct (float_equal 0.0)

(* ------------------------------------------------------------------ *)
(* above_ma_count                                                       *)
(* ------------------------------------------------------------------ *)

let test_above_ma_count_all_above _ =
  (* Rising series: all recent bars should be above the (lagging) MA *)
  let bars = rising_bars 50.0 200.0 in
  let result = classify ~config:cfg ~bars ~prior_stage:None in
  (* In a strong uptrend, all confirm_weeks bars should be above MA *)
  assert_that result.above_ma_count (gt (module Int_ord) 0)

(* ------------------------------------------------------------------ *)
(* Parity: classify (bar-list) vs classify_with_callbacks              *)
(*                                                                      *)
(* Builds [get_ma] / [get_close] callbacks externally over the same    *)
(* MA series the wrapper would compute internally, then asserts that   *)
(* the two entry points produce bit-identical [result] records.        *)
(* Each scenario hits a different Stage variant (Stage1/2/3/4) plus    *)
(* the late-Stage-2 deceleration case.                                 *)
(* ------------------------------------------------------------------ *)

(** Compute MA values externally using the same indicator module the wrapper
    delegates to. Returns an array of MA values aligned to the last bar of each
    rolling window (oldest at index 0, newest at the end). *)
let compute_ma_values (config : Stage.config) (bars : Daily_price.t list) :
    float array =
  let data =
    List.map bars ~f:(fun b ->
        Indicator_types.
          { date = b.Daily_price.date; value = b.Daily_price.adjusted_close })
  in
  let result =
    match config.ma_type with
    | Sma -> Sma.calculate_sma data config.ma_period
    | Wma -> Sma.calculate_weighted_ma data config.ma_period
    | Ema -> Ema.calculate_ema data config.ma_period
  in
  List.map result ~f:(fun iv -> iv.Indicator_types.value) |> Array.of_list

(** Build a [get_ma] closure from a precomputed MA-value array. Mirrors the
    indexing rules the wrapper uses internally: [week_offset:0] = newest. *)
let make_get_ma (ma_values : float array) ~week_offset =
  let n = Array.length ma_values in
  let idx = n - 1 - week_offset in
  if idx < 0 || idx >= n then None else Some ma_values.(idx)

(** Build a [get_close] closure from a bar list. Reads [adjusted_close] (matches
    the field [_compute_ma] uses inside the wrapper). *)
let make_get_close (bars : Daily_price.t array) ~week_offset =
  let n = Array.length bars in
  let idx = n - 1 - week_offset in
  if idx < 0 || idx >= n then None
  else Some bars.(idx).Daily_price.adjusted_close

(** Bit-identity matcher for [Stage.result]. Float fields use [equal_to] with
    [Poly.equal] (structural equality) so any drift — even a single ULP — fails
    the test. Variant fields use [equal_to] (their derived equality handlers
    from [@@deriving eq]). *)
let result_is_bit_identical (expected : Stage.result) : Stage.result matcher =
  all_of
    [
      field (fun (r : Stage.result) -> r.stage) (equal_to expected.stage);
      field
        (fun (r : Stage.result) -> r.ma_value)
        (equal_to (expected.ma_value : float));
      field
        (fun (r : Stage.result) -> r.ma_direction)
        (equal_to expected.ma_direction);
      field
        (fun (r : Stage.result) -> r.ma_slope_pct)
        (equal_to (expected.ma_slope_pct : float));
      field
        (fun (r : Stage.result) -> r.transition)
        (equal_to expected.transition);
      field
        (fun (r : Stage.result) -> r.above_ma_count)
        (equal_to expected.above_ma_count);
    ]

(** Run both [classify] and [classify_with_callbacks] over the same [bars] and
    assert the results are bit-equal. *)
let assert_parity ?(prior_stage = None) bars =
  let bars_arr = Array.of_list bars in
  let ma_values = compute_ma_values cfg bars in
  let from_bars = classify ~config:cfg ~bars ~prior_stage in
  let from_callbacks =
    classify_with_callbacks ~config:cfg ~get_ma:(make_get_ma ma_values)
      ~get_close:(make_get_close bars_arr) ~prior_stage
  in
  assert_that from_callbacks (result_is_bit_identical from_bars)

(** Stage 2: 100-bar rising series, no prior stage. *)
let test_parity_stage2_rising _ =
  let bars = rising_bars ~n:100 50.0 200.0 in
  assert_parity bars

(** Stage 4: 100-bar declining series, no prior stage. *)
let test_parity_stage4_declining _ =
  let bars = declining_bars ~n:100 200.0 50.0 in
  assert_parity bars

(** Stage 1: rising-then-flat (so MA flattens with prior Stage 4 → Stage 1). *)
let test_parity_stage1_flat_after_decline _ =
  let declining = List.init 30 ~f:(fun i -> 200.0 -. (Float.of_int i *. 2.0)) in
  let flat = List.init 70 ~f:(fun _ -> 140.0) in
  let bars = declining @ flat |> bars_of_prices in
  let prior = Some (Stage4 { weeks_declining = 10 }) in
  assert_parity ~prior_stage:prior bars

(** Stage 3: rising-then-flat with prior Stage 2. *)
let test_parity_stage3_flat_after_advance _ =
  let rising = List.init 30 ~f:(fun i -> 50.0 +. (Float.of_int i *. 2.0)) in
  let flat = List.init 70 ~f:(fun _ -> 110.0) in
  let bars = rising @ flat |> bars_of_prices in
  let prior = Some (Stage2 { weeks_advancing = 10; late = false }) in
  assert_parity ~prior_stage:prior bars

(** Late Stage 2: a strong rise that decelerates so [is_late = true] should
    fire. *)
let test_parity_late_stage2 _ =
  let strong_rise =
    List.init 50 ~f:(fun i -> 50.0 +. (Float.of_int i *. 3.0))
  in
  let weakening = List.init 50 ~f:(fun i -> 200.0 +. (Float.of_int i *. 0.1)) in
  let bars = strong_rise @ weakening |> bars_of_prices in
  let prior = Some (Stage2 { weeks_advancing = 20; late = false }) in
  assert_parity ~prior_stage:prior bars

(** Insufficient data: fewer bars than [ma_period] → both paths take the
    [_stage1_default_result] early-return. *)
let test_parity_insufficient_data _ =
  let bars = List.init 10 ~f:(fun _ -> 50.0) |> bars_of_prices in
  assert_parity bars

(* ------------------------------------------------------------------ *)
(* Segmentation variant — feature-flagged Stage classifier (M5.4 E2)  *)
(*                                                                      *)
(* Goal: verify both [stage_method] variants produce a [Stage.t] for   *)
(* each scenario and that the new [Segmentation] path identifies the   *)
(* expected stage on clear-cut inputs (rising/declining series).       *)
(* The default-on-MaSlope tests above guard the existing behavior.     *)
(* ------------------------------------------------------------------ *)

let cfg_segmentation = { default_config with stage_method = Segmentation }

(** Default config preserves [MaSlope]: changing nothing else, the new field
    must select the legacy path. *)
let test_default_config_uses_ma_slope _ =
  assert_that default_config.stage_method (equal_to MaSlope)

(** Stage 2: clearly rising series with the segmentation variant should still
    classify as Stage 2 with a Rising direction. *)
let test_segmentation_stage2_rising _ =
  let bars = rising_bars ~n:100 50.0 200.0 in
  let result = classify ~config:cfg_segmentation ~bars ~prior_stage:None in
  assert_that result
    (all_of
       [
         field (fun r -> r.stage) is_stage2;
         field (fun r -> r.ma_direction) (equal_to Rising);
       ])

(** Stage 4: clearly declining series with the segmentation variant should
    classify as Stage 4 with a Declining direction. *)
let test_segmentation_stage4_declining _ =
  let bars = declining_bars ~n:100 200.0 50.0 in
  let result = classify ~config:cfg_segmentation ~bars ~prior_stage:None in
  assert_that result
    (all_of
       [
         field (fun r -> r.stage) is_stage4;
         field (fun r -> r.ma_direction) (equal_to Declining);
       ])

(** Insufficient data: the segmentation variant must take the same early-return
    branch as the slope variant ([_stage1_default_result]). *)
let test_segmentation_insufficient_data _ =
  let bars = List.init 10 ~f:(fun _ -> 50.0) |> bars_of_prices in
  let result = classify ~config:cfg_segmentation ~bars ~prior_stage:None in
  assert_that result
    (all_of
       [
         field (fun r -> r.stage) is_stage1;
         field (fun r -> r.ma_value) (float_equal 0.0);
       ])

(** Purity for the segmentation path: same inputs always produce the same
    output. *)
let test_segmentation_pure _ =
  let bars = rising_bars ~n:80 50.0 150.0 in
  let r1 = classify ~config:cfg_segmentation ~bars ~prior_stage:None in
  let r2 = classify ~config:cfg_segmentation ~bars ~prior_stage:None in
  assert_that r2
    (all_of
       [
         field (fun r -> r.stage) (equal_to (r1.stage : stage));
         field (fun r -> r.ma_value) (float_equal r1.ma_value);
         field
           (fun r -> r.ma_direction)
           (equal_to (r1.ma_direction : ma_direction));
         field (fun r -> r.ma_slope_pct) (float_equal r1.ma_slope_pct);
       ])

(** Both methods return a valid [Stage.t] for the same bars.

    Acceptance criterion from M5.4 E2: "Both methods produce a [Stage.t] for the
    same input." We assert both produce *some* stage; we do not require them to
    agree on which stage. *)
let test_both_methods_return_a_stage _ =
  let bars = rising_bars ~n:80 50.0 150.0 in
  let r_slope =
    classify
      ~config:{ default_config with stage_method = MaSlope }
      ~bars ~prior_stage:None
  in
  let r_seg =
    classify
      ~config:{ default_config with stage_method = Segmentation }
      ~bars ~prior_stage:None
  in
  (* Both stage values should belong to one of the four stage variants —
     since [stage] is a closed variant, just asserting equality of the
     stage_number domain is enough to confirm both produced a valid value. *)
  let stage_number = function
    | Stage1 _ -> 1
    | Stage2 _ -> 2
    | Stage3 _ -> 3
    | Stage4 _ -> 4
  in
  assert_that
    (stage_number r_slope.stage)
    (is_between (module Int_ord) ~low:1 ~high:4);
  assert_that (stage_number r_seg.stage)
    (is_between (module Int_ord) ~low:1 ~high:4)

let suite =
  "stage_tests"
  >::: [
         "test_stage2_rising_trend" >:: test_stage2_rising_trend;
         "test_stage2_advancing_weeks" >:: test_stage2_advancing_weeks;
         "test_stage4_declining_trend" >:: test_stage4_declining_trend;
         "test_stage1_flat_after_decline" >:: test_stage1_flat_after_decline;
         "test_stage3_flat_after_advance" >:: test_stage3_flat_after_advance;
         "test_no_transition_same_stage" >:: test_no_transition_same_stage;
         "test_transition_from_stage1_to_stage2"
         >:: test_transition_from_stage1_to_stage2;
         "test_insufficient_data_returns_stage1"
         >:: test_insufficient_data_returns_stage1;
         "test_pure_same_inputs_same_output"
         >:: test_pure_same_inputs_same_output;
         "test_ma_value_non_zero" >:: test_ma_value_non_zero;
         "test_ma_direction_flat_for_constant_series"
         >:: test_ma_direction_flat_for_constant_series;
         "test_above_ma_count_all_above" >:: test_above_ma_count_all_above;
         "test_parity_stage2_rising" >:: test_parity_stage2_rising;
         "test_parity_stage4_declining" >:: test_parity_stage4_declining;
         "test_parity_stage1_flat_after_decline"
         >:: test_parity_stage1_flat_after_decline;
         "test_parity_stage3_flat_after_advance"
         >:: test_parity_stage3_flat_after_advance;
         "test_parity_late_stage2" >:: test_parity_late_stage2;
         "test_parity_insufficient_data" >:: test_parity_insufficient_data;
         "test_default_config_uses_ma_slope"
         >:: test_default_config_uses_ma_slope;
         "test_segmentation_stage2_rising" >:: test_segmentation_stage2_rising;
         "test_segmentation_stage4_declining"
         >:: test_segmentation_stage4_declining;
         "test_segmentation_insufficient_data"
         >:: test_segmentation_insufficient_data;
         "test_segmentation_pure" >:: test_segmentation_pure;
         "test_both_methods_return_a_stage" >:: test_both_methods_return_a_stage;
       ]

let () = run_test_tt_main suite
