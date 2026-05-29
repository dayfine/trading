(** Tests for {!Trade_autopsy_lib.Trade_autopsy} missed-gain numerics,
    summarize, and per-symbol breakdown aggregation. *)

open Core
open OUnit2
open Matchers
module Autopsy = Trade_autopsy_lib.Trade_autopsy
module Config = Trade_autopsy_lib.Trade_autopsy_config
open Test_helpers

(* ------------------------------------------------------------------ *)
(* Matcher-selector shorthands                                         *)
(* ------------------------------------------------------------------ *)

let _missed_gain a = a.Autopsy.missed_gain_pct
let _mode_name (s : Autopsy.mode_summary) = s.mode_name
let _num_trades (b : Autopsy.per_symbol_breakdown) = b.num_trades

let _stage3_bucket (b : Autopsy.per_symbol_breakdown) =
  b.stage3_false_positive_missed_gain

let _reentry_bucket (b : Autopsy.per_symbol_breakdown) =
  b.late_reentry_missed_gain

(* ------------------------------------------------------------------ *)
(* Synthetic-bar builder                                               *)
(* ------------------------------------------------------------------ *)

(* Climbs to 120 by week 2, dips to 110 through index 14, then 150 onwards. *)
let _missed_gain_closes =
  let close_for i =
    if i <= 2 then 100.0 +. (10.0 *. Float.of_int i)
    else if i < 15 then 110.0
    else 150.0
  in
  List.init 25 ~f:close_for

(* Climbs to 120 by exit_week; recovers to 132 at recovery_week and stays
   there through end-of-window. *)
let _breakdown_closes ~exit_week ~recovery_week =
  let close_for i =
    if i <= exit_week then 100.0 +. (10.0 *. Float.of_int i)
    else if i >= recovery_week then 132.0
    else 110.0
  in
  List.init (recovery_week + 2) ~f:close_for

(* ------------------------------------------------------------------ *)
(* Missed-gain numeric value                                          *)
(* ------------------------------------------------------------------ *)

let test_missed_gain_uses_next_same_side_entry _ =
  let closes = _missed_gain_closes in
  let bars = mk_series ~start_date ~closes in
  let exit_a = Date.add_days start_date (7 * 2) in
  let entry_b = Date.add_days start_date (7 * 15) in
  let exit_b = Date.add_days start_date (7 * 20) in
  let trades =
    [
      long_trade ~entry_date:start_date ~exit_date:exit_a ~entry_price:100.0
        ~exit_price:120.0;
      long_trade ~entry_date:entry_b ~exit_date:exit_b ~entry_price:150.0
        ~exit_price:150.0;
    ]
  in
  let result =
    Autopsy.classify_trades ~config:Config.default ~symbol:"FOO"
      ~weekly_bars:bars ~trades
  in
  (* Trade 0: missed_gain = (150 - 120) / 120 = 0.25.
     Trade 1: no next same-side; uses end-of-window close (150 == entry). *)
  let trade_0_missed = field _missed_gain (float_equal 0.25) in
  let trade_1_missed = field _missed_gain (float_equal 0.0) in
  assert_that result (elements_are [ trade_0_missed; trade_1_missed ])

(* ------------------------------------------------------------------ *)
(* summarize                                                           *)
(* ------------------------------------------------------------------ *)

let test_summarize_yields_four_modes_in_fixed_order _ =
  let summary = Autopsy.summarize [] in
  let named expected = field _mode_name (equal_to expected) in
  assert_that summary
    (elements_are
       [
         named "stage3_false_positive";
         named "late_reentry";
         named "late_stage2_admission";
         named "stop_out_whipsaw";
       ])

(* ------------------------------------------------------------------ *)
(* breakdown_for_symbol                                                *)
(* ------------------------------------------------------------------ *)

(* Setup: trade exits at week 2 / price 120; closes rise to 132 by the
   recovery_week and stay there through the end of the series. End-of-
   window close = 132; missed_gain = (132 - 120) / 120 = 0.10. The
   stage3 recovery threshold (5%) fires at week 14, so the trade is
   flagged stage3_false_positive AND the breakdown sums its 0.10
   missed_gain into that bucket. *)
let test_breakdown_for_symbol_sums_missed_gain_per_mode _ =
  let exit_week = 2 in
  let recovery_week = exit_week + Config.default.stage3_recovery_weeks in
  let closes = _breakdown_closes ~exit_week ~recovery_week in
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
  let breakdown = Autopsy.breakdown_for_symbol ~symbol:"FOO" result in
  assert_that breakdown
    (all_of
       [
         field _num_trades (equal_to 1);
         field _stage3_bucket (float_equal ~epsilon:1e-6 0.10);
         field _reentry_bucket (float_equal 0.0);
       ])

(* ------------------------------------------------------------------ *)
(* Suite                                                               *)
(* ------------------------------------------------------------------ *)

let suite =
  "aggregation"
  >::: [
         "missed_gain uses next same-side entry"
         >:: test_missed_gain_uses_next_same_side_entry;
         "summarize yields four modes in fixed order"
         >:: test_summarize_yields_four_modes_in_fixed_order;
         "breakdown sums missed_gain per mode"
         >:: test_breakdown_for_symbol_sums_missed_gain_per_mode;
       ]

let () = run_test_tt_main suite
