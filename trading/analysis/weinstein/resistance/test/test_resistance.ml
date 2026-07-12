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
    active_through = None;
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
(* Insufficient history (min_history_bars degrade)                      *)
(* ------------------------------------------------------------------ *)

(** 52 below-breakout bars: no bar trades above 50, so the virgin check passes →
    the default (disabled) mapper labels this Virgin_territory even though only
    52 bars exist against the 520-bar virgin default. This is the false-virgin
    defect the [min_history_bars] arm exists to correct; it must persist under
    the default (bit-identical) config. *)
let short_history_bars =
  List.init 52 ~f:(fun _ -> make_bar ~low:40.0 ~high:48.0 45.0)

let test_short_history_default_still_virgin _ =
  let result =
    analyze ~config:cfg ~bars:short_history_bars ~breakout_price:50.0
      ~as_of_date:as_of
  in
  assert_that result.quality (equal_to Virgin_territory)

let test_short_history_armed_insufficient _ =
  (* Same starved window, but armed with a 100-bar minimum: 52 < 100 → the
     mapper refuses the (false) Virgin_territory grade and degrades. *)
  let armed_cfg = { cfg with min_history_bars = 100 } in
  let result =
    analyze ~config:armed_cfg ~bars:short_history_bars ~breakout_price:50.0
      ~as_of_date:as_of
  in
  assert_that result.quality (equal_to Insufficient_history)

let test_sufficient_history_armed_grades_normally _ =
  (* Armed with a 5-bar minimum and 10 bars available (all in one zone above
     breakout): history is sufficient, so the normal grade (Heavy) is assigned —
     never Insufficient_history. *)
  let armed_cfg = { cfg with min_history_bars = 5 } in
  let bars = List.init 10 ~f:(fun _ -> make_bar ~low:52.0 ~high:58.0 55.0) in
  let result =
    analyze ~config:armed_cfg ~bars ~breakout_price:50.0 ~as_of_date:as_of
  in
  assert_that result.quality (equal_to Heavy_resistance)

let test_insufficient_history_zones_still_reported _ =
  (* Even when the grade degrades to Insufficient_history, the observed zones are
     still populated from whatever bars exist. *)
  let armed_cfg = { cfg with min_history_bars = 100 } in
  let bars = List.init 5 ~f:(fun _ -> make_bar ~low:52.0 ~high:58.0 55.0) in
  let result =
    analyze ~config:armed_cfg ~bars ~breakout_price:50.0 ~as_of_date:as_of
  in
  assert_that result
    (all_of
       [
         field (fun r -> r.quality) (equal_to Insufficient_history);
         field (fun r -> r.zones_above) (size_is 1);
         field
           (fun r -> r.nearest_zone)
           (is_some_and
              (field (fun z -> z.price_low) (ge (module Float_ord) 50.0)));
       ])

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

(* ------------------------------------------------------------------ *)
(* Parity: analyze (bar-list) vs analyze_with_callbacks                *)
(*                                                                    *)
(* Builds a {!callbacks} record externally via the public               *)
(* {!callbacks_from_bars} and asserts the two entry points produce      *)
(* bit-identical results. Each scenario hits a different quality bucket *)
(* (Virgin / Clean / Moderate / Heavy) plus the chart-window edge.      *)
(* ------------------------------------------------------------------ *)

(** Bit-identity matcher for {!resistance_zone}. All fields use [equal_to]
    (Poly.equal — structural equality) so any drift fails. *)
let zone_is_bit_identical (expected : resistance_zone) : resistance_zone matcher
    =
  all_of
    [
      field
        (fun (z : resistance_zone) -> z.price_low)
        (equal_to (expected.price_low : float));
      field
        (fun (z : resistance_zone) -> z.price_high)
        (equal_to (expected.price_high : float));
      field
        (fun (z : resistance_zone) -> z.weeks_of_trading)
        (equal_to (expected.weeks_of_trading : int));
      field
        (fun (z : resistance_zone) -> z.age_years)
        (equal_to (expected.age_years : float));
    ]

(** Bit-identity matcher for {!result}. *)
let result_is_bit_identical (expected : result) : result matcher =
  all_of
    [
      field (fun (r : result) -> r.quality) (equal_to expected.quality);
      field
        (fun (r : result) -> r.breakout_price)
        (equal_to (expected.breakout_price : float));
      field
        (fun (r : result) -> r.zones_above)
        (elements_are (List.map expected.zones_above ~f:zone_is_bit_identical));
      field
        (fun (r : result) -> r.nearest_zone)
        (match expected.nearest_zone with
        | None -> is_none
        | Some z -> is_some_and (zone_is_bit_identical z));
    ]

(** Run both [analyze] and [analyze_with_callbacks] over the same input and
    assert the results are bit-equal. The callback bundle is built externally
    via the public {!callbacks_from_bars}. *)
let assert_parity ?(config = cfg) ~bars ~breakout_price () =
  let bar_result = analyze ~config ~bars ~breakout_price ~as_of_date:as_of in
  let callbacks = callbacks_from_bars ~bars in
  let callback_result =
    analyze_with_callbacks ~config ~callbacks ~breakout_price ~as_of_date:as_of
  in
  assert_that callback_result (result_is_bit_identical bar_result)

let test_parity_virgin_no_history _ =
  assert_parity ~bars:[] ~breakout_price:50.0 ()

let test_parity_clean_overhead _ =
  let bars =
    [
      make_bar ~low:40.0 ~high:48.0 45.0;
      make_bar ~low:42.0 ~high:49.0 47.0;
      make_bar ~low:49.0 ~high:53.0 51.0;
    ]
  in
  assert_parity ~bars ~breakout_price:50.0 ()

let test_parity_heavy_resistance _ =
  let bars = List.init 10 ~f:(fun _ -> make_bar ~low:52.0 ~high:58.0 55.0) in
  assert_parity ~bars ~breakout_price:50.0 ()

let test_parity_moderate_resistance _ =
  let bars = List.init 5 ~f:(fun _ -> make_bar ~low:52.0 ~high:58.0 55.0) in
  assert_parity ~bars ~breakout_price:50.0 ()

let test_parity_insufficient_history _ =
  let armed_cfg = { cfg with min_history_bars = 100 } in
  assert_parity ~config:armed_cfg ~bars:short_history_bars ~breakout_price:50.0
    ()

let test_parity_chart_window_filtering _ =
  let small_cfg =
    { cfg with chart_lookback_bars = 5; virgin_lookback_bars = 15 }
  in
  let bars =
    List.init 10 ~f:(fun _ -> make_bar ~low:52.0 ~high:58.0 55.0)
    @ List.init 5 ~f:(fun _ -> make_bar ~high:48.0 45.0)
  in
  assert_parity ~config:small_cfg ~bars ~breakout_price:50.0 ()

(* NaN/inf guard regression — see _bucket_idx guard. With
   congestion_band_pct = 0.0, band_size becomes 0.0 and the
   (mid - breakout_price) / band_size division yields inf/-inf, which
   pre-guard would crash at Int.of_float. Post-guard: bucket index is
   Int.min_value, filtered out by the bkt >= 0 check; zone list ends up
   empty so quality = Clean (no virgin pass either, since bars are above
   breakout). *)
let test_zero_band_size_no_crash _ =
  let zero_band_cfg = { cfg with congestion_band_pct = 0.0 } in
  let bars = List.init 5 ~f:(fun _ -> make_bar ~low:52.0 ~high:58.0 55.0) in
  let result =
    analyze ~config:zero_band_cfg ~bars ~breakout_price:50.0 ~as_of_date:as_of
  in
  assert_that result.zones_above (size_is 0)

let suite =
  "resistance_tests"
  >::: [
         "test_no_prior_history_virgin" >:: test_no_prior_history_virgin;
         "test_old_history_virgin" >:: test_old_history_virgin;
         "test_short_history_default_still_virgin"
         >:: test_short_history_default_still_virgin;
         "test_short_history_armed_insufficient"
         >:: test_short_history_armed_insufficient;
         "test_sufficient_history_armed_grades_normally"
         >:: test_sufficient_history_armed_grades_normally;
         "test_insufficient_history_zones_still_reported"
         >:: test_insufficient_history_zones_still_reported;
         "test_clean_no_resistance_above" >:: test_clean_no_resistance_above;
         "test_heavy_resistance_many_bars" >:: test_heavy_resistance_many_bars;
         "test_moderate_resistance" >:: test_moderate_resistance;
         "test_nearest_zone_present" >:: test_nearest_zone_present;
         "test_nearest_zone_absent" >:: test_nearest_zone_absent;
         "test_old_bars_outside_chart_window_excluded"
         >:: test_old_bars_outside_chart_window_excluded;
         "test_pure_same_inputs_same_output"
         >:: test_pure_same_inputs_same_output;
         "test_parity_virgin_no_history" >:: test_parity_virgin_no_history;
         "test_parity_clean_overhead" >:: test_parity_clean_overhead;
         "test_parity_heavy_resistance" >:: test_parity_heavy_resistance;
         "test_parity_moderate_resistance" >:: test_parity_moderate_resistance;
         "test_parity_insufficient_history" >:: test_parity_insufficient_history;
         "test_parity_chart_window_filtering"
         >:: test_parity_chart_window_filtering;
         "test_zero_band_size_no_crash" >:: test_zero_band_size_no_crash;
       ]

let () = run_test_tt_main suite
