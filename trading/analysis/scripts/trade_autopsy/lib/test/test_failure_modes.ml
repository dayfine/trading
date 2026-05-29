(** Tests for {!Trade_autopsy_lib.Trade_autopsy} failure-mode classification:
    Stage3 false-positive, late re-entry, late Stage2 admission, and stop-out
    whipsaw. *)

open Core
open OUnit2
open Matchers
module Autopsy = Trade_autopsy_lib.Trade_autopsy
module Config = Trade_autopsy_lib.Trade_autopsy_config
open Test_helpers

(* ------------------------------------------------------------------ *)
(* Matcher-selector shorthands                                         *)
(* ------------------------------------------------------------------ *)

(* Naming these as top-level let-bindings keeps each test's assertion shallow:
   the matcher tree composes as a list of named pieces rather than nested
   field/all_of structures. *)

let _stage3_fp a = a.Autopsy.modes.stage3_false_positive
let _late_reentry_mode a = a.Autopsy.modes.late_reentry
let _late_stage2_mode a = a.Autopsy.modes.late_stage2_admission
let _stop_whipsaw_mode a = a.Autopsy.modes.stop_out_whipsaw
let _weeks_to_reentry a = a.Autopsy.weeks_to_reentry
let _weeks_since_low a = a.Autopsy.weeks_since_cyclical_low

(* ------------------------------------------------------------------ *)
(* Synthetic-bar builders specialized for each test scenario           *)
(* ------------------------------------------------------------------ *)

(* Indices 0..2 climb to 120; index = exit_week + stage3_recovery_weeks
   recovers to 130; in between, price dips to 110. *)
let _stage3_recovery_closes ~exit_week ~recovery_week =
  let close_for i =
    if i <= exit_week then 100.0 +. (10.0 *. Float.of_int i)
    else if i = recovery_week then 130.0
    else 110.0
  in
  List.init (recovery_week + 2) ~f:close_for

(* Climb to 120 then stay at 115 — no recovery above stage3 threshold. *)
let _stage3_no_recovery_closes =
  let close_for i =
    if i <= 2 then 100.0 +. (10.0 *. Float.of_int i) else 115.0
  in
  List.init 20 ~f:close_for

(* Climb to 120, dip to 110 through week 14, then jump to 140 at week 15+. *)
let _late_reentry_closes =
  let close_for i =
    if i <= 2 then 100.0 +. (10.0 *. Float.of_int i)
    else if i < 15 then 110.0
    else 140.0
  in
  List.init 25 ~f:close_for

(* Index 0 is the cyclical low at 80; indices 1..9 climb; index 10+ at 110. *)
let _late_stage2_closes =
  let close_for i =
    if i = 0 then 80.0 else if i < 10 then 90.0 +. Float.of_int i else 110.0
  in
  List.init 25 ~f:close_for

(* ------------------------------------------------------------------ *)
(* Stage 3 false positive                                              *)
(* ------------------------------------------------------------------ *)

(* Stage-3 false positive: exit at 120; price 12 weeks later (week 14) at
   130 → recovery = 130/120 - 1 = 8.3% >= 5%. Expect flag true. *)
let test_stage3_false_positive_detected _ =
  let exit_week = 2 in
  let recovery_week = exit_week + Config.default.stage3_recovery_weeks in
  let closes = _stage3_recovery_closes ~exit_week ~recovery_week in
  let bars = mk_series ~start_date ~closes in
  let exit_date = Date.add_days start_date (7 * exit_week) in
  let trades =
    [
      long_trade ~entry_date:start_date ~exit_date ~entry_price:100.0
        ~exit_price:120.0;
    ]
  in
  let result =
    Autopsy.classify_trades ~config:Config.default ~symbol:"FOO"
      ~weekly_bars:bars ~trades
  in
  let one_flagged_stage3 = field _stage3_fp (equal_to true) in
  assert_that result (elements_are [ one_flagged_stage3 ])

(* Stage-3 false positive NOT detected: price stays below threshold. *)
let test_stage3_false_positive_not_detected_when_no_recovery _ =
  let closes = _stage3_no_recovery_closes in
  let bars = mk_series ~start_date ~closes in
  let exit_date = Date.add_days start_date (7 * 2) in
  let trades =
    [
      long_trade ~entry_date:start_date ~exit_date ~entry_price:100.0
        ~exit_price:120.0;
    ]
  in
  let result =
    Autopsy.classify_trades ~config:Config.default ~symbol:"FOO"
      ~weekly_bars:bars ~trades
  in
  let one_unflagged_stage3 = field _stage3_fp (equal_to false) in
  assert_that result (elements_are [ one_unflagged_stage3 ])

(* ------------------------------------------------------------------ *)
(* Late re-entry                                                       *)
(* ------------------------------------------------------------------ *)

(* Late re-entry: trade A exits at week 2 / price 120; trade B re-enters at
   week 15 / price 140. Gap = 13 weeks (> 8), missed_gain = 140/120 - 1
   ≈ 16.7% (>= 10%) → flag true on trade A. *)
let test_late_reentry_detected _ =
  let closes = _late_reentry_closes in
  let bars = mk_series ~start_date ~closes in
  let exit_a = Date.add_days start_date (7 * 2) in
  let entry_b = Date.add_days start_date (7 * 15) in
  let exit_b = Date.add_days start_date (7 * 20) in
  let trades =
    [
      long_trade ~entry_date:start_date ~exit_date:exit_a ~entry_price:100.0
        ~exit_price:120.0;
      long_trade ~entry_date:entry_b ~exit_date:exit_b ~entry_price:140.0
        ~exit_price:140.0;
    ]
  in
  let result =
    Autopsy.classify_trades ~config:Config.default ~symbol:"FOO"
      ~weekly_bars:bars ~trades
  in
  let trade_a_flagged =
    all_of
      [
        field _late_reentry_mode (equal_to true);
        field _weeks_to_reentry (is_some_and (equal_to 13));
      ]
  in
  let trade_b_unflagged = field _late_reentry_mode (equal_to false) in
  assert_that result (elements_are [ trade_a_flagged; trade_b_unflagged ])

(* ------------------------------------------------------------------ *)
(* Late Stage 2 admission                                              *)
(* ------------------------------------------------------------------ *)

(* Late Stage-2 admission: prior cyclical low (lowest close in 12-week
   lookback) is 8+ weeks before entry. Build bars where the low is at
   week 0 / price 80, and the long entry occurs at week 10 / price 110.
   weeks_since_cyclical_low = 10 > 8 → flag true. *)
let test_late_stage2_admission_detected _ =
  let closes = _late_stage2_closes in
  let bars = mk_series ~start_date ~closes in
  let entry_date = Date.add_days start_date (7 * 10) in
  let exit_date = Date.add_days start_date (7 * 15) in
  let trades =
    [ long_trade ~entry_date ~exit_date ~entry_price:110.0 ~exit_price:115.0 ]
  in
  let result =
    Autopsy.classify_trades ~config:Config.default ~symbol:"FOO"
      ~weekly_bars:bars ~trades
  in
  let flagged_with_weeks_10 =
    all_of
      [
        field _late_stage2_mode (equal_to true);
        field _weeks_since_low (is_some_and (equal_to 10));
      ]
  in
  assert_that result (elements_are [ flagged_with_weeks_10 ])

(* No late Stage-2 admission for short trades — the concept doesn't apply
   (shorts don't have a "cyclical low" in the same sense). *)
let test_short_trade_never_flagged_late_stage2 _ =
  let closes = _late_stage2_closes in
  let bars = mk_series ~start_date ~closes in
  let entry_date = Date.add_days start_date (7 * 10) in
  let exit_date = Date.add_days start_date (7 * 15) in
  let trades =
    [ short_trade ~entry_date ~exit_date ~entry_price:110.0 ~exit_price:115.0 ]
  in
  let result =
    Autopsy.classify_trades ~config:Config.default ~symbol:"FOO"
      ~weekly_bars:bars ~trades
  in
  let short_unflagged =
    all_of
      [
        field _late_stage2_mode (equal_to false); field _weeks_since_low is_none;
      ]
  in
  assert_that result (elements_are [ short_unflagged ])

(* ------------------------------------------------------------------ *)
(* Stop-out whipsaw                                                    *)
(* ------------------------------------------------------------------ *)

(* Stop-out whipsaw NEVER fires under the per-symbol stage strategy —
   exit_reason will never be Stop_out, so flag stays false. *)
let test_stop_whipsaw_inert_under_stage_strategy _ =
  let closes = [ 100.0; 110.0; 120.0; 130.0; 140.0 ] in
  let bars = mk_series ~start_date ~closes in
  let exit_date = Date.add_days start_date (7 * 2) in
  let trades =
    [
      long_trade ~entry_date:start_date ~exit_date ~entry_price:100.0
        ~exit_price:120.0;
    ]
  in
  let result =
    Autopsy.classify_trades ~config:Config.default ~symbol:"FOO"
      ~weekly_bars:bars ~trades
  in
  let one_unflagged_stop = field _stop_whipsaw_mode (equal_to false) in
  assert_that result (elements_are [ one_unflagged_stop ])

(* ------------------------------------------------------------------ *)
(* Suite                                                               *)
(* ------------------------------------------------------------------ *)

let suite =
  "failure_modes"
  >::: [
         "stage3 false positive detected"
         >:: test_stage3_false_positive_detected;
         "stage3 false positive not detected when no recovery"
         >:: test_stage3_false_positive_not_detected_when_no_recovery;
         "late re-entry detected" >:: test_late_reentry_detected;
         "late stage2 admission detected"
         >:: test_late_stage2_admission_detected;
         "short trade never flagged late stage2"
         >:: test_short_trade_never_flagged_late_stage2;
         "stop whipsaw inert under stage strategy"
         >:: test_stop_whipsaw_inert_under_stage_strategy;
       ]

let () = run_test_tt_main suite
