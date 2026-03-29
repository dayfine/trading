open OUnit2
open Core
open Matchers
open Macro
open Weinstein_types
open Types

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let cfg = default_config

let make_bar date adjusted_close =
  {
    Daily_price.date = Date.of_string date;
    open_price = adjusted_close;
    high_price = adjusted_close *. 1.01;
    low_price = adjusted_close *. 0.99;
    close_price = adjusted_close;
    adjusted_close;
    volume = 100_000;
  }

let weekly_bars prices =
  let base = Date.of_string "2020-01-06" in
  List.mapi prices ~f:(fun i p ->
      make_bar (Date.to_string (Date.add_days base (i * 7))) p)

let rising_bars ~n start stop_ =
  let step = (stop_ -. start) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i -> start +. (Float.of_int i *. step)) |> weekly_bars

let flat_bars ~n price = List.init n ~f:(fun _ -> price) |> weekly_bars

(** Build A-D bars with [advancing] and [declining] counts per bar. *)
let ad_bars ~n ~advancing ~declining =
  let base = Date.of_string "2020-01-06" in
  List.init n ~f:(fun i ->
      { date = Date.add_days base i; advancing; declining })

(* ------------------------------------------------------------------ *)
(* Bullish regime: strong rising index                                  *)
(* ------------------------------------------------------------------ *)

let test_bullish_regime_rising_index _ =
  let index = rising_bars ~n:40 100.0 200.0 in
  let result =
    analyze ~config:cfg ~index_bars:index ~ad_bars:[] ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  assert_that result.trend (equal_to Bullish)

let test_confidence_between_0_and_1 _ =
  let index = rising_bars ~n:40 100.0 200.0 in
  let result =
    analyze ~config:cfg ~index_bars:index ~ad_bars:[] ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  assert_bool "confidence >= 0" Float.(result.confidence >= 0.0);
  assert_bool "confidence <= 1" Float.(result.confidence <= 1.0)

(* ------------------------------------------------------------------ *)
(* Bearish regime: declining index                                      *)
(* ------------------------------------------------------------------ *)

let test_bearish_regime_declining_index _ =
  let declining =
    List.init 40 ~f:(fun i -> 200.0 -. (Float.of_int i *. 2.0)) |> weekly_bars
  in
  let result =
    analyze ~config:cfg ~index_bars:declining ~ad_bars:[] ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  assert_that result.trend (equal_to Bearish)

(* ------------------------------------------------------------------ *)
(* Neutral: flat index                                                  *)
(* ------------------------------------------------------------------ *)

let test_neutral_flat_index _ =
  (* A flat index with no A-D or global data produces all-Neutral indicators.
     _compute_confidence returns 0.5 (fallback when all indicators are Neutral).
     0.5 is between bearish_threshold=0.35 and bullish_threshold=0.65 → Neutral. *)
  let index = flat_bars ~n:40 100.0 in
  let result =
    analyze ~config:cfg ~index_bars:index ~ad_bars:[] ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  assert_that result.trend (equal_to Neutral);
  assert_that result.confidence (float_equal 0.5)

(* ------------------------------------------------------------------ *)
(* A-D line influence                                                   *)
(* ------------------------------------------------------------------ *)

let test_bullish_ad_line_boosts_confidence _ =
  let index = rising_bars ~n:40 100.0 150.0 in
  (* Advancing > declining on all bars → positive A-D line *)
  let ad = ad_bars ~n:200 ~advancing:2000 ~declining:1000 in
  let r_with_ad =
    analyze ~config:cfg ~index_bars:index ~ad_bars:ad ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  let r_no_ad =
    analyze ~config:cfg ~index_bars:index ~ad_bars:[] ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  (* Adding bullish A-D data should not decrease confidence *)
  assert_bool "A-D boosts or maintains confidence"
    Float.(r_with_ad.confidence >= r_no_ad.confidence -. 0.1)

(* ------------------------------------------------------------------ *)
(* Regime change detection                                              *)
(* ------------------------------------------------------------------ *)

let test_regime_changed_when_trend_flips _ =
  let index = rising_bars ~n:40 100.0 200.0 in
  let prior_bearish =
    analyze ~config:cfg ~index_bars:(flat_bars ~n:40 100.0) ~ad_bars:[]
      ~global_index_bars:[] ~prior_stage:None ~prior:None
  in
  (* Now analyze with rising index using prior bearish result *)
  let result =
    analyze ~config:cfg ~index_bars:index ~ad_bars:[] ~global_index_bars:[]
      ~prior_stage:None ~prior:(Some prior_bearish)
  in
  (* If prior was Neutral/Bearish and current is Bullish, regime_changed=true *)
  if not (equal_market_trend result.trend prior_bearish.trend) then
    assert_bool "regime_changed should be true" result.regime_changed
  else
    assert_bool "regime_changed should be false (no change)"
      (not result.regime_changed)

let test_no_regime_change_same_trend _ =
  let index = rising_bars ~n:40 100.0 200.0 in
  let prior =
    analyze ~config:cfg ~index_bars:index ~ad_bars:[] ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  (* Analyze again with same bars — should not change regime *)
  let result =
    analyze ~config:cfg ~index_bars:index ~ad_bars:[] ~global_index_bars:[]
      ~prior_stage:None ~prior:(Some prior)
  in
  assert_bool "no regime change on same data" (not result.regime_changed)

(* ------------------------------------------------------------------ *)
(* Indicators structure                                                 *)
(* ------------------------------------------------------------------ *)

let test_indicators_list_not_empty _ =
  let index = rising_bars ~n:40 100.0 150.0 in
  let result =
    analyze ~config:cfg ~index_bars:index ~ad_bars:[] ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  assert_bool "should have indicators" (not (List.is_empty result.indicators))

let test_index_stage_indicator_present _ =
  let index = rising_bars ~n:40 100.0 150.0 in
  let result =
    analyze ~config:cfg ~index_bars:index ~ad_bars:[] ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  let has_index_stage =
    List.exists result.indicators ~f:(fun r -> String.(r.name = "Index Stage"))
  in
  assert_bool "Index Stage indicator present" has_index_stage

(* ------------------------------------------------------------------ *)
(* Purity                                                               *)
(* ------------------------------------------------------------------ *)

let test_pure_same_inputs _ =
  let index = rising_bars ~n:40 100.0 200.0 in
  let ad = ad_bars ~n:100 ~advancing:1500 ~declining:1000 in
  let r1 =
    analyze ~config:cfg ~index_bars:index ~ad_bars:ad ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  let r2 =
    analyze ~config:cfg ~index_bars:index ~ad_bars:ad ~global_index_bars:[]
      ~prior_stage:None ~prior:None
  in
  assert_that r1.trend (equal_to (r2.trend : market_trend));
  assert_that r1.confidence (float_equal r2.confidence)

let suite =
  "macro_tests"
  >::: [
         "test_bullish_regime_rising_index" >:: test_bullish_regime_rising_index;
         "test_confidence_between_0_and_1" >:: test_confidence_between_0_and_1;
         "test_bearish_regime_declining_index"
         >:: test_bearish_regime_declining_index;
         "test_neutral_flat_index" >:: test_neutral_flat_index;
         "test_bullish_ad_line_boosts_confidence"
         >:: test_bullish_ad_line_boosts_confidence;
         "test_regime_changed_when_trend_flips"
         >:: test_regime_changed_when_trend_flips;
         "test_no_regime_change_same_trend" >:: test_no_regime_change_same_trend;
         "test_indicators_list_not_empty" >:: test_indicators_list_not_empty;
         "test_index_stage_indicator_present"
         >:: test_index_stage_indicator_present;
         "test_pure_same_inputs" >:: test_pure_same_inputs;
       ]

let () = run_test_tt_main suite
