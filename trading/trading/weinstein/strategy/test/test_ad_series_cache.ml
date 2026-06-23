open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Snapshot_bar_views = Snapshot_runtime.Snapshot_bar_views

(* ------------------------------------------------------------------ *)
(* Parity: Ad_series_cache must reproduce the OLD per-tick macro A-D path *)
(* bit-for-bit. The OLD path is exactly                                  *)
(*   Macro_inputs.ad_bars_at_or_before                                   *)
(*     |> Panel_callbacks.macro_callbacks_of_weekly_views ~ad_bars       *)
(* which internally folds _build_cumulative_ad_array /                   *)
(* _compute_momentum_ma_scalar and wraps them in _get_from_float_array / *)
(* _get_ad_momentum_ma. The NEW path is                                  *)
(*   Ad_series_cache.of_weekly_ad_bars |> callbacks_at ~as_of            *)
(* (equivalently macro_callbacks_of_weekly_views_cached). We compare the *)
(* two A-D closures' outputs across many week_offsets and as_of cutoffs. *)
(* ------------------------------------------------------------------ *)

let make_ad_bar ~year ~month ~day ~advancing ~declining : Macro.ad_bar =
  {
    date = Date.create_exn ~y:year ~m:(Month.of_int_exn month) ~d:day;
    advancing;
    declining;
  }

(* Ascending-by-date weekly A-D bars with varied (incl. negative) nets. *)
let sample_ad_bars : Macro.ad_bar list =
  [
    make_ad_bar ~year:2020 ~month:1 ~day:3 ~advancing:300 ~declining:100;
    make_ad_bar ~year:2020 ~month:1 ~day:10 ~advancing:120 ~declining:380;
    make_ad_bar ~year:2020 ~month:1 ~day:17 ~advancing:250 ~declining:250;
    make_ad_bar ~year:2020 ~month:1 ~day:24 ~advancing:90 ~declining:410;
    make_ad_bar ~year:2020 ~month:1 ~day:31 ~advancing:420 ~declining:80;
    make_ad_bar ~year:2020 ~month:2 ~day:7 ~advancing:200 ~declining:300;
  ]

let empty_weekly_view : Snapshot_bar_views.weekly_view =
  {
    closes = [||];
    raw_closes = [||];
    highs = [||];
    lows = [||];
    volumes = [||];
    dates = [||];
    n = 0;
  }

(* Build a Macro.config whose momentum_period we control, so cutoffs exercise
   both k < momentum_period and k >= momentum_period. *)
let macro_config ~momentum_period : Macro.config =
  {
    Macro.default_config with
    indicator_thresholds =
      { Macro.default_config.indicator_thresholds with momentum_period };
  }

(* The OLD A-D closures: filter to [as_of], then build the legacy callbacks. *)
let old_callbacks ~momentum_period ~as_of =
  let ad_bars =
    Macro_inputs.ad_bars_at_or_before ~ad_bars:sample_ad_bars ~as_of
  in
  let cbs =
    Panel_callbacks.macro_callbacks_of_weekly_views
      ~config:(macro_config ~momentum_period)
      ~index:empty_weekly_view ~globals:[] ~ad_bars ()
  in
  (cbs.Macro.get_cumulative_ad, cbs.Macro.get_ad_momentum_ma)

(* The NEW A-D closures from the precomputed cache. *)
let new_callbacks ~momentum_period ~as_of =
  let cache =
    Ad_series_cache.of_weekly_ad_bars ~momentum_period sample_ad_bars
  in
  Ad_series_cache.callbacks_at cache ~as_of

(* Offsets spanning in-range, the boundary, and well out of range. *)
let week_offsets = List.range (-1) 9

(* For one (momentum_period, as_of) cell, assert every cumulative-A-D offset and
   the offset-0 momentum MA from the NEW closures equal the OLD closures. The
   expected values are produced by the OLD path, so this is a true parity pin. *)
let assert_cell ~momentum_period ~as_of =
  let old_cum, old_ma = old_callbacks ~momentum_period ~as_of in
  let new_cum, new_ma = new_callbacks ~momentum_period ~as_of in
  let cum_matchers =
    List.map week_offsets ~f:(fun week_offset ->
        match old_cum ~week_offset with
        | None -> is_none
        | Some v -> is_some_and (float_equal v))
  in
  assert_that
    (List.map week_offsets ~f:(fun week_offset -> new_cum ~week_offset))
    (elements_are cum_matchers);
  let expected_ma_matcher =
    match old_ma ~week_offset:0 with
    | None -> is_none
    | Some v -> is_some_and (float_equal v)
  in
  assert_that (new_ma ~week_offset:0) expected_ma_matcher

(* Cutoffs: before all (k=0), each exact boundary date, an off-boundary mid date,
   and after all (k=n). *)
let cutoffs =
  [
    Date.create_exn ~y:2019 ~m:Month.Dec ~d:31 (* before all *);
    Date.create_exn ~y:2020 ~m:Month.Jan ~d:3 (* boundary, k=1 *);
    Date.create_exn ~y:2020 ~m:Month.Jan ~d:14 (* mid, k=2 *);
    Date.create_exn ~y:2020 ~m:Month.Jan ~d:17 (* boundary, k=3 *);
    Date.create_exn ~y:2020 ~m:Month.Jan ~d:31 (* boundary, k=5 *);
    Date.create_exn ~y:2020 ~m:Month.Feb ~d:7 (* boundary, k=6=n *);
    Date.create_exn ~y:2020 ~m:Month.Mar ~d:1 (* after all, k=n *);
  ]

(* momentum_period 3 puts several cutoffs in k < period; period 200 keeps every
   cutoff in k < period; period 1 keeps every non-empty cutoff in k >= period. *)
let momentum_periods = [ 1; 3; 200 ]

let test_parity_across_cutoffs _ =
  List.iter momentum_periods ~f:(fun momentum_period ->
      List.iter cutoffs ~f:(fun as_of -> assert_cell ~momentum_period ~as_of))

(* Empty input: cache is empty, k is always 0, both closures always None. *)
let test_empty_input _ =
  let cache = Ad_series_cache.of_weekly_ad_bars ~momentum_period:3 [] in
  assert_that (Ad_series_cache.length cache) (equal_to 0);
  let get_cum, get_ma =
    Ad_series_cache.callbacks_at cache
      ~as_of:(Date.create_exn ~y:2020 ~m:Month.Jan ~d:15)
  in
  assert_that (get_cum ~week_offset:0) is_none;
  assert_that (get_ma ~week_offset:0) is_none

(* count_at_or_before must equal the OLD filter's prefix length at every cutoff. *)
let test_prefix_length_matches_filter _ =
  let cache =
    Ad_series_cache.of_weekly_ad_bars ~momentum_period:3 sample_ad_bars
  in
  let actual =
    List.map cutoffs ~f:(fun as_of ->
        Ad_series_cache.Internal_for_test.count_at_or_before cache ~as_of)
  in
  let expected =
    List.map cutoffs ~f:(fun as_of ->
        List.length
          (Macro_inputs.ad_bars_at_or_before ~ad_bars:sample_ad_bars ~as_of))
  in
  assert_that actual (elements_are (List.map expected ~f:(fun n -> equal_to n)))

let suite =
  "Ad_series_cache parity"
  >::: [
         "parity across cutoffs and momentum periods"
         >:: test_parity_across_cutoffs;
         "empty input yields all-None closures" >:: test_empty_input;
         "prefix length matches ad_bars_at_or_before"
         >:: test_prefix_length_matches_filter;
       ]

let () = run_test_tt_main suite
