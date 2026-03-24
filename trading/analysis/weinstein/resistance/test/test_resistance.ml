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

let make_bar ?(low = 90.0) ?(high = 110.0) date close =
  {
    Daily_price.date = Date.of_string date;
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
  (* No bars at all → Virgin territory (never traded above breakout) *)
  let result =
    analyze ~config:cfg ~bars:[] ~breakout_price:50.0 ~as_of_date:as_of
  in
  assert_that result.quality (equal_to Virgin_territory)

let test_old_history_virgin _ =
  (* All trading above breakout was 11+ years ago → Virgin territory *)
  let old_date = Date.of_string "2010-01-01" in
  (* as_of = 2024, so age = 14 years > virgin_years=10 *)
  let bars = [ make_bar ~high:80.0 (Date.to_string old_date) 75.0 ] in
  let result =
    analyze ~config:cfg ~bars ~breakout_price:60.0 ~as_of_date:as_of
  in
  assert_that result.quality (equal_to Virgin_territory)

(* ------------------------------------------------------------------ *)
(* Clean overhead                                                       *)
(* ------------------------------------------------------------------ *)

let test_clean_no_resistance_above _ =
  (* Bars that once briefly traded above breakout but not many — within
     the chart_years window but very sparse (< moderate threshold) *)
  let bars =
    [
      make_bar ~low:40.0 ~high:48.0 "2023-01-01" 45.0;
      make_bar ~low:42.0 ~high:49.0 "2023-06-01" 47.0
      (* One recent bar that briefly poked above breakout — 1 week only *);
      make_bar ~low:49.0 ~high:53.0 "2023-10-01" 51.0;
    ]
  in
  (* breakout at 50.0 — only one bar traded above 50, which is < moderate threshold (3) *)
  let result =
    analyze ~config:cfg ~bars ~breakout_price:50.0 ~as_of_date:as_of
  in
  assert_that result.quality (equal_to Clean)

(* ------------------------------------------------------------------ *)
(* Heavy resistance                                                     *)
(* ------------------------------------------------------------------ *)

let test_heavy_resistance_many_weeks _ =
  (* 10 recent bars all trading through the same zone above breakout *)
  let bars =
    List.init 10 ~f:(fun i ->
        let d = Date.add_days (Date.of_string "2023-01-02") (i * 7) in
        make_bar ~low:52.0 ~high:58.0 (Date.to_string d) 55.0)
  in
  let result =
    analyze ~config:cfg ~bars ~breakout_price:50.0 ~as_of_date:as_of
  in
  assert_that result.quality (equal_to Heavy_resistance)

(* ------------------------------------------------------------------ *)
(* Moderate resistance                                                  *)
(* ------------------------------------------------------------------ *)

let test_moderate_resistance _ =
  (* 5 bars trading above breakout — above moderate threshold (3) but below heavy (8) *)
  let bars =
    List.init 5 ~f:(fun i ->
        let d = Date.add_days (Date.of_string "2023-01-02") (i * 7) in
        make_bar ~low:52.0 ~high:58.0 (Date.to_string d) 55.0)
  in
  let result =
    analyze ~config:cfg ~bars ~breakout_price:50.0 ~as_of_date:as_of
  in
  assert_that result.quality (equal_to Moderate_resistance)

(* ------------------------------------------------------------------ *)
(* nearest_zone                                                         *)
(* ------------------------------------------------------------------ *)

let test_nearest_zone_present _ =
  let bars =
    List.init 5 ~f:(fun i ->
        let d = Date.add_days (Date.of_string "2023-06-01") (i * 7) in
        make_bar ~low:52.0 ~high:58.0 (Date.to_string d) 55.0)
  in
  let result =
    analyze ~config:cfg ~bars ~breakout_price:50.0 ~as_of_date:as_of
  in
  assert_that result.nearest_zone
    (is_some_and (fun zone ->
         assert_bool "zone starts at or above breakout"
           Float.(zone.price_low >= 50.0)))

let test_nearest_zone_absent _ =
  (* No bars above breakout → no nearest zone *)
  let bars = [ make_bar ~low:40.0 ~high:49.0 "2023-01-01" 45.0 ] in
  let result =
    analyze ~config:cfg ~bars ~breakout_price:50.0 ~as_of_date:as_of
  in
  assert_that result.nearest_zone is_none

(* ------------------------------------------------------------------ *)
(* chart_years window filtering                                         *)
(* ------------------------------------------------------------------ *)

let test_old_bars_outside_window_excluded _ =
  (* Bar from 5 years ago with heavy resistance above breakout — but
     chart_years=2.5 so it should be excluded *)
  let old_bar = make_bar ~low:52.0 ~high:58.0 "2015-01-01" 55.0 in
  let bars = [ old_bar ] in
  (* The old bar is >2.5 years ago from as_of=2024, so excluded from analysis *)
  (* Since it's also >virgin_years=10 from 2024, might be virgin *)
  let result =
    analyze ~config:cfg ~bars ~breakout_price:50.0 ~as_of_date:as_of
  in
  (* Old bar from 2015 is ~9 years old — within virgin_years (10) boundary *)
  (* So it won't be virgin but will be clean since it's excluded from 2.5y window *)
  match result.quality with
  | Clean | Virgin_territory -> ()
  | other ->
      assert_failure
        (Printf.sprintf "Expected Clean or Virgin for old bar, got %s"
           (show_overhead_quality other))

(* ------------------------------------------------------------------ *)
(* Purity                                                               *)
(* ------------------------------------------------------------------ *)

let test_pure_same_inputs_same_output _ =
  let bars =
    List.init 6 ~f:(fun i ->
        let d = Date.add_days (Date.of_string "2023-06-01") (i * 7) in
        make_bar ~low:52.0 ~high:58.0 (Date.to_string d) 55.0)
  in
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
         "test_heavy_resistance_many_weeks" >:: test_heavy_resistance_many_weeks;
         "test_moderate_resistance" >:: test_moderate_resistance;
         "test_nearest_zone_present" >:: test_nearest_zone_present;
         "test_nearest_zone_absent" >:: test_nearest_zone_absent;
         "test_old_bars_outside_window_excluded"
         >:: test_old_bars_outside_window_excluded;
         "test_pure_same_inputs_same_output"
         >:: test_pure_same_inputs_same_output;
       ]

let () = run_test_tt_main suite
