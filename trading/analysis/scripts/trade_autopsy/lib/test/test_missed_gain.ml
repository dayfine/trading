(** Tests for {!Trade_autopsy_lib.Missed_gain}. *)

open Core
open OUnit2
open Matchers
module Missed_gain = Trade_autopsy_lib.Missed_gain
open Test_helpers

let test_close_at_offset_walks_forward _ =
  let closes = [ 100.0; 105.0; 110.0; 120.0; 130.0 ] in
  let bars = mk_series ~start_date ~closes in
  assert_that
    (Missed_gain.close_at_offset ~bars ~anchor_date:start_date ~weeks:3)
    (is_some_and (float_equal 120.0))

let test_close_at_offset_returns_none_off_end _ =
  let closes = [ 100.0; 105.0; 110.0 ] in
  let bars = mk_series ~start_date ~closes in
  assert_that
    (Missed_gain.close_at_offset ~bars ~anchor_date:start_date ~weeks:5)
    is_none

let _low_date (d, _) = d
let _low_close (_, c) = c

let test_cyclical_low_picks_minimum_close _ =
  (* Entry on week 5 (index 5); lookback 4 means window = indices 1..4 with
     closes [105; 95; 110; 100]. Minimum is 95 at index 2 → date is start +
     2*7 days. *)
  let closes = [ 100.0; 105.0; 95.0; 110.0; 100.0; 120.0 ] in
  let bars = mk_series ~start_date ~closes in
  let entry_date = Date.add_days start_date (7 * 5) in
  let expected_low_date = Date.add_days start_date (7 * 2) in
  let matches_expected_low =
    all_of
      [
        field _low_date (equal_to expected_low_date);
        field _low_close (float_equal 95.0);
      ]
  in
  assert_that
    (Missed_gain.cyclical_low_close_before ~bars ~entry_date ~lookback_weeks:4)
    (is_some_and matches_expected_low)

let suite =
  "missed_gain"
  >::: [
         "close_at_offset walks forward" >:: test_close_at_offset_walks_forward;
         "close_at_offset returns none off end"
         >:: test_close_at_offset_returns_none_off_end;
         "cyclical_low picks minimum close"
         >:: test_cyclical_low_picks_minimum_close;
       ]

let () = run_test_tt_main suite
