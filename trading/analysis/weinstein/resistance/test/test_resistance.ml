open OUnit2
open Core
open Matchers
open Resistance
open Weinstein_types
open Types

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let cfg = default_config
let as_of = Date.of_string "2024-01-01"

(** Bar with optional low/high overrides; date is fixed (irrelevant to
    bar-count-based window logic, used only for [age_years] computation). *)
let make_bar ?(low = 90.0) ?(high = 110.0) close =
  {
    Daily_price.date = Date.of_string "2023-06-01";
    open_price = close;
    high_price = high;
    low_price = low;
    close_price = close;
    adjusted_close = close;
    volume = 1000;
  }

(* ------------------------------------------------------------------ *)
(* Virgin territory tests                                               *)
(* ------------------------------------------------------------------ *)

let test_no_prior_history_virgin _ =
  (* No bars at all → Virgin territory *)
  let result =
    analyze ~config:cfg ~bars:[] ~breakout_price:50.0 ~as_of_date:as_of
  in
  assert_that result.quality (equal_to Virgin_territory)

let test_old_history_virgin _ =
  (* Above-breakout bars are older than virgin_lookback_bars → Virgin territory.
     virgin_lookback_bars=10: the 5 old above-breakout bars are outside the tail
     of 10, so the virgin check sees only 10 recent below-breakout bars. *)
  let small_cfg = { cfg with virgin_lookback_bars = 10 } in
  let bars =
    List.init 5 ~f:(fun _ -> make_bar ~high:80.0 75.0) (* old, above breakout *)
    @ List.init 10 ~f:(fun _ -> make_bar ~high:50.0 45.0)
    (* recent, below *)
  in
  let result =
    analyze ~config:small_cfg ~bars ~breakout_price:60.0 ~as_of_date:as_of
  in
  assert_that result.quality (equal_to Virgin_territory)

(* ------------------------------------------------------------------ *)
(* Clean overhead                                                       *)
(* ------------------------------------------------------------------ *)

let test_clean_no_resistance_above _ =
  (* Only 1 bar traded above breakout — below moderate threshold (3) → Clean. *)
  let bars =
    [
      make_bar ~low:40.0 ~high:48.0 45.0;
      make_bar ~low:42.0 ~high:49.0 47.0;
      make_bar ~low:49.0 ~high:53.0 51.0 (* only this one is above 50 *);
    ]
  in
  let result =
    analyze ~config:cfg ~bars ~breakout_price:50.0 ~as_of_date:as_of
  in
  assert_that result.quality (equal_to Clean)

(* ------------------------------------------------------------------ *)
(* Heavy resistance                                                     *)
(* ------------------------------------------------------------------ *)

let test_heavy_resistance_many_bars _ =
  (* 10 bars all in the same zone above breakout → heavy (threshold 8). *)
  let bars = List.init 10 ~f:(fun _ -> make_bar ~low:52.0 ~high:58.0 55.0) in
  let result =
    analyze ~config:cfg ~bars ~breakout_price:50.0 ~as_of_date:as_of
  in
  assert_that result.quality (equal_to Heavy_resistance)

(* ------------------------------------------------------------------ *)
(* Moderate resistance                                                  *)
(* ------------------------------------------------------------------ *)

let test_moderate_resistance _ =
  (* 5 bars above breakout: above moderate threshold (3) but below heavy (8). *)
  let bars = List.init 5 ~f:(fun _ -> make_bar ~low:52.0 ~high:58.0 55.0) in
  let result =
    analyze ~config:cfg ~bars ~breakout_price:50.0 ~as_of_date:as_of
  in
  assert_that result.quality (equal_to Moderate_resistance)

(* ------------------------------------------------------------------ *)
(* nearest_zone                                                         *)
(* ------------------------------------------------------------------ *)

let test_nearest_zone_present _ =
  let bars = List.init 5 ~f:(fun _ -> make_bar ~low:52.0 ~high:58.0 55.0) in
  let result =
    analyze ~config:cfg ~bars ~breakout_price:50.0 ~as_of_date:as_of
  in
  assert_that result.nearest_zone
    (is_some_and
       (field (fun zone -> zone.price_low) (ge (module Float_ord) 50.0)))

let test_nearest_zone_absent _ =
  let bars = [ make_bar ~low:40.0 ~high:49.0 45.0 ] in
  let result =
    analyze ~config:cfg ~bars ~breakout_price:50.0 ~as_of_date:as_of
  in
  assert_that result.nearest_zone is_none

(* ------------------------------------------------------------------ *)
(* chart_lookback_bars window filtering                                 *)
(* ------------------------------------------------------------------ *)

let test_old_bars_outside_chart_window_excluded _ =
  (* 10 old above-breakout bars + 5 recent below-breakout bars.
     chart_lookback_bars=5: zone analysis only sees the 5 recent bars (below)
     → no zones → Clean.
     virgin_lookback_bars=15: virgin check sees all 15 bars → has above-breakout
     bars → not Virgin. *)
  let small_cfg =
    { cfg with chart_lookback_bars = 5; virgin_lookback_bars = 15 }
  in
  let bars =
    List.init 10 ~f:(fun _ -> make_bar ~low:52.0 ~high:58.0 55.0)
    @ List.init 5 ~f:(fun _ -> make_bar ~high:48.0 45.0)
  in
  let result =
    analyze ~config:small_cfg ~bars ~breakout_price:50.0 ~as_of_date:as_of
  in
  assert_that result.quality (equal_to Clean)

(* ------------------------------------------------------------------ *)
(* Purity                                                               *)
(* ------------------------------------------------------------------ *)

let test_pure_same_inputs_same_output _ =
  let bars = List.init 6 ~f:(fun _ -> make_bar ~low:52.0 ~high:58.0 55.0) in
  let r1 = analyze ~config:cfg ~bars ~breakout_price:50.0 ~as_of_date:as_of in
  let r2 = analyze ~config:cfg ~bars ~breakout_price:50.0 ~as_of_date:as_of in
  assert_that r1.quality (equal_to (r2.quality : overhead_quality));
  assert_that r1.zones_above (size_is (List.length r2.zones_above))

let suite =
  "resistance_tests"
  >::: [
         "test_no_prior_history_virgin" >:: test_no_prior_history_virgin;
         "test_old_history_virgin" >:: test_old_history_virgin;
         "test_clean_no_resistance_above" >:: test_clean_no_resistance_above;
         "test_heavy_resistance_many_bars" >:: test_heavy_resistance_many_bars;
         "test_moderate_resistance" >:: test_moderate_resistance;
         "test_nearest_zone_present" >:: test_nearest_zone_present;
         "test_nearest_zone_absent" >:: test_nearest_zone_absent;
         "test_old_bars_outside_chart_window_excluded"
         >:: test_old_bars_outside_chart_window_excluded;
         "test_pure_same_inputs_same_output"
         >:: test_pure_same_inputs_same_output;
       ]

let () = run_test_tt_main suite
