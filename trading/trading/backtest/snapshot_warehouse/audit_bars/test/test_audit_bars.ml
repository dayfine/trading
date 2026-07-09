open OUnit2
open Core
open Matchers
module Detector = Audit_bars_detector

let base = Date.of_string "2014-01-01"

(* Build a bar array from a close series, one bar per successive calendar day. *)
let make_bars closes =
  Array.of_list_mapi closes ~f:(fun i close ->
      { Detector.date = Date.add_days base i; close })

let params = Detector.default_params

(* The MSZ 2014-08-15 shape: flat ~1.9 baseline, one 25.36 spike, 1.93 revert. *)
let test_detects_msz_shape _ =
  let bars =
    make_bars [ 1.9; 1.9; 1.9; 1.9; 1.9; 25.36; 1.93; 1.9; 1.9; 1.9; 1.9 ]
  in
  assert_that
    (Detector.detect ~params bars)
    (elements_are
       [
         all_of
           [
             field (fun h -> h.Detector.date) (equal_to (Date.add_days base 5));
             field (fun h -> h.Detector.prev_close) (float_equal 1.9);
             field (fun h -> h.Detector.spike_close) (float_equal 25.36);
             field (fun h -> h.Detector.next_close) (float_equal 1.93);
             field
               (fun h -> h.Detector.ratio)
               (is_between (module Float_ord) ~low:13.0 ~high:14.0);
           ];
       ])

(* A spike whose next bar stays elevated is not a revert -> not flagged. *)
let test_no_revert_not_flagged _ =
  let bars = make_bars [ 2.0; 2.0; 2.0; 2.0; 2.0; 20.0; 18.0 ] in
  assert_that (Detector.detect ~params bars) (elements_are [])

(* Same spike-then-revert shape but at a high price level (median >= ceiling):
   a legitimate large move, not the sub-$5 artifact -> not flagged. *)
let test_high_priced_above_ceiling_not_flagged _ =
  let bars =
    make_bars
      [ 100.0; 100.0; 100.0; 100.0; 100.0; 600.0; 105.0; 100.0; 100.0; 100.0 ]
  in
  assert_that (Detector.detect ~params bars) (elements_are [])

(* Spike near the start of the series: fewer left-neighbours, still detected. *)
let test_window_edge_start_detected _ =
  let bars = make_bars [ 1.9; 25.36; 1.93; 1.9; 1.9; 1.9 ] in
  assert_that
    (Detector.detect ~params bars)
    (elements_are
       [
         all_of
           [
             field (fun h -> h.Detector.date) (equal_to (Date.add_days base 1));
             field (fun h -> h.Detector.prev_close) (float_equal 1.9);
             field (fun h -> h.Detector.spike_close) (float_equal 25.36);
             field (fun h -> h.Detector.next_close) (float_equal 1.93);
           ];
       ])

(* A spike on the final bar has no successor to check the revert -> not flagged. *)
let test_last_bar_not_flagged _ =
  let bars = make_bars [ 1.9; 1.9; 1.9; 1.9; 1.9; 25.36 ] in
  assert_that (Detector.detect ~params bars) (elements_are [])

let suite =
  "Audit_bars detector tests"
  >::: [
         "detects MSZ shape" >:: test_detects_msz_shape;
         "no revert -> not flagged" >:: test_no_revert_not_flagged;
         "high-priced above ceiling -> not flagged"
         >:: test_high_priced_above_ceiling_not_flagged;
         "window edge at start still detected"
         >:: test_window_edge_start_detected;
         "spike on last bar not flagged" >:: test_last_bar_not_flagged;
       ]

let () = run_test_tt_main suite
