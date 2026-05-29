(** Tests for {!Trade_autopsy_lib.Trade_autopsy} and {!Missed_gain}.

    Uses synthetic weekly-bar series and synthetic Walk_step.trade records to
    drive deterministic classification cases for each of the four failure modes.
*)

open Core
open OUnit2
open Matchers
module Autopsy = Trade_autopsy_lib.Trade_autopsy
module Missed_gain = Trade_autopsy_lib.Missed_gain
module Config = Trade_autopsy_lib.Trade_autopsy_config
module Walk_step = Per_symbol_stage_strategy_lib.Walk_step

(* ------------------------------------------------------------------ *)
(* Synthetic-bar helpers                                              *)
(* ------------------------------------------------------------------ *)

(* Build a weekly bar at date [d] with all OHLC equal to [close]. *)
let _mk_bar ~date ~close : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    volume = 1_000;
    adjusted_close = close;
    active_through = None;
  }

(* Build a series of [n] weekly bars starting at [start_date], with closes
   given by [closes]. Length of [closes] must equal [n]. *)
let _mk_series ~start_date ~closes =
  List.mapi closes ~f:(fun i close ->
      _mk_bar ~date:(Date.add_days start_date (7 * i)) ~close)

let _start_date = Date.of_string "2020-01-03"

(* Construct a long trade. *)
let _long_trade ~entry_date ~exit_date ~entry_price ~exit_price :
    Walk_step.trade =
  {
    variant_side = `Long;
    entry_date;
    exit_date;
    entry_price;
    exit_price;
    return_pct = (exit_price -. entry_price) /. entry_price;
  }

(* Construct a short trade. *)
let _short_trade ~entry_date ~exit_date ~entry_price ~exit_price :
    Walk_step.trade =
  {
    variant_side = `Short;
    entry_date;
    exit_date;
    entry_price;
    exit_price;
    return_pct = (entry_price -. exit_price) /. entry_price;
  }

(* ------------------------------------------------------------------ *)
(* Missed_gain unit tests                                             *)
(* ------------------------------------------------------------------ *)

let test_close_at_offset_walks_forward _ =
  let closes = [ 100.0; 105.0; 110.0; 120.0; 130.0 ] in
  let bars = _mk_series ~start_date:_start_date ~closes in
  assert_that
    (Missed_gain.close_at_offset ~bars ~anchor_date:_start_date ~weeks:3)
    (is_some_and (float_equal 120.0))

let test_close_at_offset_returns_none_off_end _ =
  let closes = [ 100.0; 105.0; 110.0 ] in
  let bars = _mk_series ~start_date:_start_date ~closes in
  assert_that
    (Missed_gain.close_at_offset ~bars ~anchor_date:_start_date ~weeks:5)
    is_none

let test_cyclical_low_picks_minimum_close _ =
  (* Entry on week 5 (index 5); lookback 4 means window = indices 1..4 with
     closes [105; 95; 110; 100]. Minimum is 95 at index 2 → date is _start +
     2*7 days. *)
  let closes = [ 100.0; 105.0; 95.0; 110.0; 100.0; 120.0 ] in
  let bars = _mk_series ~start_date:_start_date ~closes in
  let entry_date = Date.add_days _start_date (7 * 5) in
  let expected_low_date = Date.add_days _start_date (7 * 2) in
  assert_that
    (Missed_gain.cyclical_low_close_before ~bars ~entry_date ~lookback_weeks:4)
    (is_some_and
       (all_of
          [
            field (fun (d, _) -> d) (equal_to expected_low_date);
            field (fun (_, c) -> c) (float_equal 95.0);
          ]))

(* ------------------------------------------------------------------ *)
(* classify_trades — exit_reason and force-close behaviour            *)
(* ------------------------------------------------------------------ *)

let test_final_bar_trade_classified_as_end_of_period _ =
  let closes = [ 100.0; 110.0; 120.0; 130.0 ] in
  let bars = _mk_series ~start_date:_start_date ~closes in
  let final_date = Date.add_days _start_date (7 * 3) in
  let trades =
    [
      _long_trade ~entry_date:_start_date ~exit_date:final_date
        ~entry_price:100.0 ~exit_price:130.0;
    ]
  in
  let result =
    Autopsy.classify_trades ~config:Config.default ~symbol:"FOO"
      ~weekly_bars:bars ~trades
  in
  assert_that result
    (elements_are
       [
         field (fun a -> a.Autopsy.exit_reason) (equal_to Autopsy.End_of_period);
       ])

let test_non_final_long_trade_classified_as_stage3_exit _ =
  (* Trade ends on week 2; series extends through week 5. *)
  let closes = [ 100.0; 110.0; 120.0; 115.0; 105.0; 100.0 ] in
  let bars = _mk_series ~start_date:_start_date ~closes in
  let exit_date = Date.add_days _start_date (7 * 2) in
  let trades =
    [
      _long_trade ~entry_date:_start_date ~exit_date ~entry_price:100.0
        ~exit_price:120.0;
    ]
  in
  let result =
    Autopsy.classify_trades ~config:Config.default ~symbol:"FOO"
      ~weekly_bars:bars ~trades
  in
  assert_that result
    (elements_are
       [ field (fun a -> a.Autopsy.exit_reason) (equal_to Autopsy.Stage3_exit) ])

(* ------------------------------------------------------------------ *)
(* Failure-mode classification                                         *)
(* ------------------------------------------------------------------ *)

(* Stage-3 false positive: exit at 120; price 12 weeks later (week 14) at
   130 → recovery = 130/120 - 1 = 8.3% >= 5%. Expect flag true. *)
let test_stage3_false_positive_detected _ =
  let exit_week = 2 in
  let recovery_week = exit_week + Config.default.stage3_recovery_weeks in
  (* Build 16 weekly bars: indices 0..1 climb to 120; index 2 exit at 120;
     indices 3..13 dip to ~110; index 14 recovers to 130. *)
  let closes =
    List.init (recovery_week + 2) ~f:(fun i ->
        if i <= exit_week then 100.0 +. (10.0 *. Float.of_int i)
        else if i = recovery_week then 130.0
        else 110.0)
  in
  let bars = _mk_series ~start_date:_start_date ~closes in
  let exit_date = Date.add_days _start_date (7 * exit_week) in
  let trades =
    [
      _long_trade ~entry_date:_start_date ~exit_date ~entry_price:100.0
        ~exit_price:120.0;
    ]
  in
  let result =
    Autopsy.classify_trades ~config:Config.default ~symbol:"FOO"
      ~weekly_bars:bars ~trades
  in
  assert_that result
    (elements_are
       [
         field (fun a -> a.Autopsy.modes.stage3_false_positive) (equal_to true);
       ])

(* Stage-3 false positive NOT detected: price stays below threshold. *)
let test_stage3_false_positive_not_detected_when_no_recovery _ =
  let closes =
    List.init 20 ~f:(fun i ->
        if i <= 2 then 100.0 +. (10.0 *. Float.of_int i) else 115.0)
  in
  let bars = _mk_series ~start_date:_start_date ~closes in
  let exit_date = Date.add_days _start_date (7 * 2) in
  let trades =
    [
      _long_trade ~entry_date:_start_date ~exit_date ~entry_price:100.0
        ~exit_price:120.0;
    ]
  in
  let result =
    Autopsy.classify_trades ~config:Config.default ~symbol:"FOO"
      ~weekly_bars:bars ~trades
  in
  assert_that result
    (elements_are
       [
         field (fun a -> a.Autopsy.modes.stage3_false_positive) (equal_to false);
       ])

(* Late re-entry: trade A exits at week 2 / price 120; trade B re-enters at
   week 15 / price 140. Gap = 13 weeks (> 8), missed_gain = 140/120 - 1
   ≈ 16.7% (>= 10%) → flag true on trade A. Build 25 weeks so neither
   trade is end-of-period. *)
let test_late_reentry_detected _ =
  let closes =
    List.init 25 ~f:(fun i ->
        if i <= 2 then 100.0 +. (10.0 *. Float.of_int i)
        else if i < 15 then 110.0
        else 140.0)
  in
  let bars = _mk_series ~start_date:_start_date ~closes in
  let exit_a = Date.add_days _start_date (7 * 2) in
  let entry_b = Date.add_days _start_date (7 * 15) in
  let exit_b = Date.add_days _start_date (7 * 20) in
  let trades =
    [
      _long_trade ~entry_date:_start_date ~exit_date:exit_a ~entry_price:100.0
        ~exit_price:120.0;
      _long_trade ~entry_date:entry_b ~exit_date:exit_b ~entry_price:140.0
        ~exit_price:140.0;
    ]
  in
  let result =
    Autopsy.classify_trades ~config:Config.default ~symbol:"FOO"
      ~weekly_bars:bars ~trades
  in
  (* Trade 0 should flag late_reentry. *)
  assert_that result
    (elements_are
       [
         all_of
           [
             field (fun a -> a.Autopsy.modes.late_reentry) (equal_to true);
             field
               (fun a -> a.Autopsy.weeks_to_reentry)
               (is_some_and (equal_to 13));
           ];
         field (fun a -> a.Autopsy.modes.late_reentry) (equal_to false);
       ])

(* Late Stage-2 admission: prior cyclical low (lowest close in 12-week
   lookback) is 8+ weeks before entry. Build bars where the low is at
   week 0 / price 80, and the long entry occurs at week 10 / price 110.
   weeks_since_cyclical_low = 10 > 8 → flag true. *)
let test_late_stage2_admission_detected _ =
  let closes =
    List.init 25 ~f:(fun i ->
        if i = 0 then 80.0 else if i < 10 then 90.0 +. Float.of_int i else 110.0)
  in
  let bars = _mk_series ~start_date:_start_date ~closes in
  let entry_date = Date.add_days _start_date (7 * 10) in
  let exit_date = Date.add_days _start_date (7 * 15) in
  let trades =
    [ _long_trade ~entry_date ~exit_date ~entry_price:110.0 ~exit_price:115.0 ]
  in
  let result =
    Autopsy.classify_trades ~config:Config.default ~symbol:"FOO"
      ~weekly_bars:bars ~trades
  in
  assert_that result
    (elements_are
       [
         all_of
           [
             field
               (fun a -> a.Autopsy.modes.late_stage2_admission)
               (equal_to true);
             field
               (fun a -> a.Autopsy.weeks_since_cyclical_low)
               (is_some_and (equal_to 10));
           ];
       ])

(* No late Stage-2 admission for short trades — the concept doesn't apply
   (shorts don't have a "cyclical low" in the same sense). *)
let test_short_trade_never_flagged_late_stage2 _ =
  let closes =
    List.init 25 ~f:(fun i ->
        if i = 0 then 80.0 else if i < 10 then 90.0 +. Float.of_int i else 110.0)
  in
  let bars = _mk_series ~start_date:_start_date ~closes in
  let entry_date = Date.add_days _start_date (7 * 10) in
  let exit_date = Date.add_days _start_date (7 * 15) in
  let trades =
    [ _short_trade ~entry_date ~exit_date ~entry_price:110.0 ~exit_price:115.0 ]
  in
  let result =
    Autopsy.classify_trades ~config:Config.default ~symbol:"FOO"
      ~weekly_bars:bars ~trades
  in
  assert_that result
    (elements_are
       [
         all_of
           [
             field
               (fun a -> a.Autopsy.modes.late_stage2_admission)
               (equal_to false);
             field (fun a -> a.Autopsy.weeks_since_cyclical_low) is_none;
           ];
       ])

(* Stop-out whipsaw NEVER fires under the per-symbol stage strategy —
   exit_reason will never be Stop_out, so flag stays false. *)
let test_stop_whipsaw_inert_under_stage_strategy _ =
  let closes = [ 100.0; 110.0; 120.0; 130.0; 140.0 ] in
  let bars = _mk_series ~start_date:_start_date ~closes in
  let exit_date = Date.add_days _start_date (7 * 2) in
  let trades =
    [
      _long_trade ~entry_date:_start_date ~exit_date ~entry_price:100.0
        ~exit_price:120.0;
    ]
  in
  let result =
    Autopsy.classify_trades ~config:Config.default ~symbol:"FOO"
      ~weekly_bars:bars ~trades
  in
  assert_that result
    (elements_are
       [ field (fun a -> a.Autopsy.modes.stop_out_whipsaw) (equal_to false) ])

(* ------------------------------------------------------------------ *)
(* Missed-gain numeric value                                          *)
(* ------------------------------------------------------------------ *)

let test_missed_gain_uses_next_same_side_entry _ =
  let closes =
    List.init 25 ~f:(fun i ->
        if i <= 2 then 100.0 +. (10.0 *. Float.of_int i)
        else if i < 15 then 110.0
        else 150.0)
  in
  let bars = _mk_series ~start_date:_start_date ~closes in
  let exit_a = Date.add_days _start_date (7 * 2) in
  let entry_b = Date.add_days _start_date (7 * 15) in
  let exit_b = Date.add_days _start_date (7 * 20) in
  let trades =
    [
      _long_trade ~entry_date:_start_date ~exit_date:exit_a ~entry_price:100.0
        ~exit_price:120.0;
      _long_trade ~entry_date:entry_b ~exit_date:exit_b ~entry_price:150.0
        ~exit_price:150.0;
    ]
  in
  let result =
    Autopsy.classify_trades ~config:Config.default ~symbol:"FOO"
      ~weekly_bars:bars ~trades
  in
  (* Trade 0: missed_gain = (150 - 120) / 120 = 0.25. *)
  assert_that result
    (elements_are
       [
         field (fun a -> a.Autopsy.missed_gain_pct) (float_equal 0.25);
         (* Trade 1 has no next same-side; uses end-of-window close. *)
         field
           (fun a -> a.Autopsy.missed_gain_pct)
           (float_equal ((150.0 -. 150.0) /. 150.0));
       ])

(* ------------------------------------------------------------------ *)
(* Aggregation                                                         *)
(* ------------------------------------------------------------------ *)

let test_summarize_yields_four_modes_in_fixed_order _ =
  let autopsies = [] in
  let summary = Autopsy.summarize autopsies in
  assert_that summary
    (elements_are
       [
         field
           (fun (s : Autopsy.mode_summary) -> s.mode_name)
           (equal_to "stage3_false_positive");
         field
           (fun (s : Autopsy.mode_summary) -> s.mode_name)
           (equal_to "late_reentry");
         field
           (fun (s : Autopsy.mode_summary) -> s.mode_name)
           (equal_to "late_stage2_admission");
         field
           (fun (s : Autopsy.mode_summary) -> s.mode_name)
           (equal_to "stop_out_whipsaw");
       ])

let test_breakdown_for_symbol_sums_missed_gain_per_mode _ =
  (* Setup: trade exits at week 2 / price 120; closes rise to 132 by the
     recovery_week and stay there through the end of the series. End-of-
     window close = 132; missed_gain = (132 - 120) / 120 = 0.10. The
     stage3 recovery threshold (5%) fires at week 14, so the trade is
     flagged stage3_false_positive AND the breakdown sums its 0.10
     missed_gain into that bucket. *)
  let exit_week = 2 in
  let recovery_week = exit_week + Config.default.stage3_recovery_weeks in
  let closes =
    List.init (recovery_week + 2) ~f:(fun i ->
        if i <= exit_week then 100.0 +. (10.0 *. Float.of_int i)
        else if i >= recovery_week then 132.0
        else 110.0)
  in
  let bars = _mk_series ~start_date:_start_date ~closes in
  let exit_date = Date.add_days _start_date (7 * exit_week) in
  let trades =
    [
      _long_trade ~entry_date:_start_date ~exit_date ~entry_price:100.0
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
         field
           (fun (b : Autopsy.per_symbol_breakdown) -> b.num_trades)
           (equal_to 1);
         field
           (fun (b : Autopsy.per_symbol_breakdown) ->
             b.stage3_false_positive_missed_gain)
           (float_equal ~epsilon:1e-6 0.10);
         field
           (fun (b : Autopsy.per_symbol_breakdown) ->
             b.late_reentry_missed_gain)
           (float_equal 0.0);
       ])

(* ------------------------------------------------------------------ *)
(* Suite                                                               *)
(* ------------------------------------------------------------------ *)

let suite =
  "trade_autopsy"
  >::: [
         "close_at_offset walks forward" >:: test_close_at_offset_walks_forward;
         "close_at_offset returns none off end"
         >:: test_close_at_offset_returns_none_off_end;
         "cyclical_low picks minimum close"
         >:: test_cyclical_low_picks_minimum_close;
         "final-bar trade is end_of_period"
         >:: test_final_bar_trade_classified_as_end_of_period;
         "non-final long trade is stage3_exit"
         >:: test_non_final_long_trade_classified_as_stage3_exit;
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
         "missed_gain uses next same-side entry"
         >:: test_missed_gain_uses_next_same_side_entry;
         "summarize yields four modes in fixed order"
         >:: test_summarize_yields_four_modes_in_fixed_order;
         "breakdown sums missed_gain per mode"
         >:: test_breakdown_for_symbol_sums_missed_gain_per_mode;
       ]

let () = run_test_tt_main suite
