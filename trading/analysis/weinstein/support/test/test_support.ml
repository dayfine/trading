open OUnit2
open Core
open Matchers
open Support
open Weinstein_types
open Types

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let cfg = default_config
let as_of = Date.of_string "2024-01-01"

(** Bar with optional low/high overrides; date is fixed (irrelevant to
    bar-count-based window logic). *)
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

(** No bars → Virgin territory. Mirror of {!Resistance}'s no-bars test. *)
let test_no_history_virgin _ =
  let result =
    analyze ~config:cfg ~bars:[] ~breakdown_price:50.0 ~as_of_date:as_of
  in
  assert_that result
    (all_of
       [
         field
           (fun r -> r.quality)
           (equal_to (Virgin_territory : overhead_quality));
         field (fun r -> r.breakdown_price) (float_equal 50.0);
       ])

(** All bars trade above breakdown_price (i.e. no low ever pierced the breakdown
    floor) → Virgin territory below. The stock has never traded down to this
    level. *)
let test_no_below_history_virgin _ =
  let bars = List.init 50 ~f:(fun _ -> make_bar ~low:80.0 ~high:120.0 100.0) in
  let result =
    analyze ~config:cfg ~bars ~breakdown_price:60.0 ~as_of_date:as_of
  in
  assert_that result.quality (equal_to (Virgin_territory : overhead_quality))

(** Below-breakdown bars older than [virgin_lookback_bars] are excluded from the
    virgin check tail. Mirror of {!Resistance.test_old_history_virgin}. *)
let test_old_below_history_virgin _ =
  let small_cfg = { cfg with Resistance.virgin_lookback_bars = 10 } in
  let bars =
    List.init 5 ~f:(fun _ -> make_bar ~low:40.0 ~high:48.0 45.0)
    @ List.init 10 ~f:(fun _ -> make_bar ~low:80.0 ~high:90.0 85.0)
  in
  let result =
    analyze ~config:small_cfg ~bars ~breakdown_price:50.0 ~as_of_date:as_of
  in
  assert_that result.quality (equal_to (Virgin_territory : overhead_quality))

(* ------------------------------------------------------------------ *)
(* Heavy support below                                                 *)
(* ------------------------------------------------------------------ *)

(** Many bars trading in the same zone below breakdown → Heavy support. *)
let test_heavy_support_many_bars _ =
  let bars = List.init 10 ~f:(fun _ -> make_bar ~low:42.0 ~high:48.0 45.0) in
  let result =
    analyze ~config:cfg ~bars ~breakdown_price:50.0 ~as_of_date:as_of
  in
  assert_that result.quality (equal_to (Heavy_resistance : overhead_quality))

(** A handful of bars below — clears the moderate threshold (3) but not heavy
    (8). *)
let test_moderate_support_few_bars _ =
  let bars =
    List.init 3 ~f:(fun _ -> make_bar ~low:42.0 ~high:48.0 45.0)
    @ List.init 30 ~f:(fun _ -> make_bar ~low:55.0 ~high:65.0 60.0)
  in
  let result =
    analyze ~config:cfg ~bars ~breakdown_price:50.0 ~as_of_date:as_of
  in
  assert_that result.quality (equal_to (Moderate_resistance : overhead_quality))

(** Only 1 bar below breakdown — below the moderate threshold (3) → Clean. *)
let test_clean_few_bars_below _ =
  let bars =
    [
      make_bar ~low:55.0 ~high:65.0 60.0;
      make_bar ~low:55.0 ~high:65.0 60.0;
      make_bar ~low:42.0 ~high:48.0 45.0;
    ]
  in
  let result =
    analyze ~config:cfg ~bars ~breakdown_price:50.0 ~as_of_date:as_of
  in
  assert_that result.quality (equal_to (Clean : overhead_quality))

let test_pure_same_inputs _ =
  let bars = List.init 10 ~f:(fun _ -> make_bar ~low:42.0 ~high:48.0 45.0) in
  let r1 = analyze ~config:cfg ~bars ~breakdown_price:50.0 ~as_of_date:as_of in
  let r2 = analyze ~config:cfg ~bars ~breakdown_price:50.0 ~as_of_date:as_of in
  assert_that r1.quality (equal_to (r2.quality : overhead_quality))

(** [analyze] should produce the same quality grade as [analyze_with_callbacks]
    when given equivalent bar / callback inputs. *)
let test_analyze_matches_callback _ =
  let bars = List.init 10 ~f:(fun _ -> make_bar ~low:42.0 ~high:48.0 45.0) in
  let bar_list_result =
    analyze ~config:cfg ~bars ~breakdown_price:50.0 ~as_of_date:as_of
  in
  let callbacks = Resistance.callbacks_from_bars ~bars in
  let callback_result =
    analyze_with_callbacks ~config:cfg ~callbacks ~breakdown_price:50.0
      ~as_of_date:as_of
  in
  assert_that bar_list_result.quality
    (equal_to (callback_result.quality : overhead_quality))

let () =
  run_test_tt_main
    ("support_tests"
    >::: [
           "no history → virgin" >:: test_no_history_virgin;
           "no bars below → virgin" >:: test_no_below_history_virgin;
           "old bars below outside virgin window → virgin"
           >:: test_old_below_history_virgin;
           "heavy support below" >:: test_heavy_support_many_bars;
           "moderate support below" >:: test_moderate_support_few_bars;
           "clean: only 1 bar below" >:: test_clean_few_bars_below;
           "pure: same inputs" >:: test_pure_same_inputs;
           "analyze matches analyze_with_callbacks"
           >:: test_analyze_matches_callback;
         ])
