(** Unit tests for [Backtest_optimal.Outcome_scorer].

    Covers, per plan §PR-2 test list:
    - One fixture per [exit_trigger] variant ([Stage3_transition], [Stop_hit],
      [End_of_run]).
    - An R-multiple computation pin test verifying the arithmetic
      [(exit_price - entry_price) / initial_risk_per_share].
    - Edge cases: 1-week run, immediate stop hit at entry+1, malformed
      candidate, Stage-3 confirmation streak resets when a non-Stage-3 week
      breaks the run.

    All tests follow the [.claude/rules/test-patterns.md] discipline: one
    [assert_that] per value, no nested asserts inside callbacks, [field] /
    [all_of] / [elements_are] for composition. *)

open OUnit2
open Core
open Matchers
module Sc = Backtest_optimal.Outcome_scorer
module OT = Backtest_optimal.Optimal_types

(* ------------------------------------------------------------------ *)
(* Builders                                                             *)
(* ------------------------------------------------------------------ *)

let _date d = Date.of_string d

(** Build a synthetic [candidate_entry]. Optional parameters let each test
    override only the fields it cares about. *)
let make_candidate ?(symbol = "AAPL") ?(entry_week = _date "2024-01-19")
    ?(side = Trading_base.Types.Long) ?(entry_price = 100.0)
    ?(suggested_stop = 92.0) ?(risk_pct = 0.08)
    ?(sector = "Information Technology") ?(cascade_grade = Weinstein_types.B)
    ?(passes_macro = true) () : OT.candidate_entry =
  {
    symbol;
    entry_week;
    side;
    entry_price;
    suggested_stop;
    risk_pct;
    sector;
    cascade_grade;
    passes_macro;
  }

(** Build a synthetic [Daily_price.t] for a weekly bar. The weekly walker only
    reads [date], [low_price], [high_price], [close_price]; the rest are filled
    with reasonable values. *)
let make_bar ~date ?(open_price = 100.0) ?(high_price = 105.0)
    ?(low_price = 95.0) ?(close_price = 100.0) ?(volume = 1_000_000)
    ?(adjusted_close = 100.0) () : Types.Daily_price.t =
  {
    date;
    open_price;
    high_price;
    low_price;
    close_price;
    volume;
    adjusted_close;
  }

(** Build a [Stage.result]. Defaults to a healthy Stage 2; tests flip [stage] to
    drive the Stage-3 detector. *)
let make_stage_result
    ?(stage = Weinstein_types.Stage2 { weeks_advancing = 4; late = false })
    ?(ma_value = 95.0) ?(ma_direction = Weinstein_types.Rising)
    ?(ma_slope_pct = 0.02) () : Stage.result =
  {
    stage;
    ma_value;
    ma_direction;
    ma_slope_pct;
    transition = None;
    above_ma_count = 5;
  }

(** Build a [weekly_outlook] from primitive arguments. *)
let make_outlook ~date ~close ?(low = 95.0) ?(high = 105.0)
    ?(stage_result = make_stage_result ()) () : Sc.weekly_outlook =
  {
    date;
    bar = make_bar ~date ~low_price:low ~high_price:high ~close_price:close ();
    stage_result;
  }

(** Successive Fridays starting at [start]. *)
let fridays_from start n =
  List.init n ~f:(fun i -> Date.add_days start (7 * (i + 1)))

(* ------------------------------------------------------------------ *)
(* End_of_run fixture                                                   *)
(* ------------------------------------------------------------------ *)

let test_score_end_of_run _ =
  (* Three healthy Stage-2 weeks, no stop hit, no Stage 3 → exit at the
     last forward outlook with End_of_run. *)
  let entry_week = _date "2024-01-19" in
  let candidate =
    make_candidate ~entry_week ~entry_price:100.0 ~suggested_stop:92.0 ()
  in
  let dates = fridays_from entry_week 3 in
  let forward =
    List.mapi dates ~f:(fun i d ->
        make_outlook ~date:d ~close:(105.0 +. Float.of_int i) ~low:100.0 ())
  in
  let result = Sc.score ~config:Sc.default_config ~candidate ~forward in
  assert_that result
    (is_some_and
       (all_of
          [
            field
              (fun (s : OT.scored_candidate) -> s.exit_trigger)
              (equal_to OT.End_of_run);
            field
              (fun (s : OT.scored_candidate) -> s.exit_week)
              (equal_to (_date "2024-02-09"));
            field
              (fun (s : OT.scored_candidate) -> s.exit_price)
              (float_equal 107.0);
            field (fun (s : OT.scored_candidate) -> s.hold_weeks) (equal_to 3);
            field
              (fun (s : OT.scored_candidate) -> s.entry.symbol)
              (equal_to "AAPL");
          ]))

(* ------------------------------------------------------------------ *)
(* Stop_hit fixture                                                     *)
(* ------------------------------------------------------------------ *)

let test_score_stop_hit _ =
  (* Two healthy weeks, then week 3's low pierces the stop. The stop walker's
     [check_stop_hit] for longs triggers on [low_price ≤ stop_level]. With
     [suggested_stop = 92.0], setting low=90.0 on week 3 should fire Stop_hit
     at week 3's close. *)
  let entry_week = _date "2024-01-19" in
  let candidate =
    make_candidate ~entry_week ~entry_price:100.0 ~suggested_stop:92.0 ()
  in
  let dates = fridays_from entry_week 3 in
  let forward =
    match dates with
    | [ d1; d2; d3 ] ->
        [
          make_outlook ~date:d1 ~close:103.0 ~low:99.0 ();
          make_outlook ~date:d2 ~close:101.0 ~low:97.0 ();
          make_outlook ~date:d3 ~close:91.0 ~low:90.0 ();
        ]
    | _ -> assert_failure "expected 3 fridays"
  in
  let result = Sc.score ~config:Sc.default_config ~candidate ~forward in
  assert_that result
    (is_some_and
       (all_of
          [
            field
              (fun (s : OT.scored_candidate) -> s.exit_trigger)
              (equal_to OT.Stop_hit);
            field
              (fun (s : OT.scored_candidate) -> s.exit_week)
              (equal_to (_date "2024-02-09"));
            field
              (fun (s : OT.scored_candidate) -> s.exit_price)
              (float_equal 91.0);
            field (fun (s : OT.scored_candidate) -> s.hold_weeks) (equal_to 3);
          ]))

(* ------------------------------------------------------------------ *)
(* Stage3_transition fixture                                            *)
(* ------------------------------------------------------------------ *)

let test_score_stage3_transition _ =
  (* Two healthy weeks, then two consecutive Stage-3 weeks (with default
     stage3_confirm_weeks = 2). The exit is anchored to the FIRST Stage-3
     week — the earliest signal — not the confirmation week. *)
  let entry_week = _date "2024-01-19" in
  let candidate =
    make_candidate ~entry_week ~entry_price:100.0 ~suggested_stop:92.0 ()
  in
  let dates = fridays_from entry_week 4 in
  let stage3 =
    make_stage_result
      ~stage:(Stage3 { weeks_topping = 1 })
      ~ma_direction:Flat ~ma_slope_pct:0.0 ()
  in
  let forward =
    match dates with
    | [ d1; d2; d3; d4 ] ->
        [
          make_outlook ~date:d1 ~close:105.0 ~low:99.0 ();
          make_outlook ~date:d2 ~close:108.0 ~low:101.0 ();
          make_outlook ~date:d3 ~close:112.0 ~low:105.0 ~stage_result:stage3 ();
          make_outlook ~date:d4 ~close:110.0 ~low:103.0 ~stage_result:stage3 ();
        ]
    | _ -> assert_failure "expected 4 fridays"
  in
  let result = Sc.score ~config:Sc.default_config ~candidate ~forward in
  assert_that result
    (is_some_and
       (all_of
          [
            field
              (fun (s : OT.scored_candidate) -> s.exit_trigger)
              (equal_to OT.Stage3_transition);
            field
              (fun (s : OT.scored_candidate) -> s.exit_week)
              (equal_to (_date "2024-02-09"));
            field
              (fun (s : OT.scored_candidate) -> s.exit_price)
              (float_equal 112.0);
            field (fun (s : OT.scored_candidate) -> s.hold_weeks) (equal_to 3);
          ]))

(* ------------------------------------------------------------------ *)
(* R-multiple pin test                                                  *)
(* ------------------------------------------------------------------ *)

let test_r_multiple_arithmetic _ =
  (* Pin the R-multiple formula: with entry=100, stop=90, exit=130, the
     initial risk is 10/share and the gain is 30/share, so R-multiple = 3.0.
     Drives an End_of_run exit so the only variable is the arithmetic. *)
  let entry_week = _date "2024-01-19" in
  let candidate =
    make_candidate ~entry_week ~entry_price:100.0 ~suggested_stop:90.0 ()
  in
  let dates = fridays_from entry_week 1 in
  let d = List.hd_exn dates in
  let forward = [ make_outlook ~date:d ~close:130.0 ~low:125.0 () ] in
  let result = Sc.score ~config:Sc.default_config ~candidate ~forward in
  assert_that result
    (is_some_and
       (all_of
          [
            field
              (fun (s : OT.scored_candidate) -> s.initial_risk_per_share)
              (float_equal 10.0);
            field
              (fun (s : OT.scored_candidate) -> s.r_multiple)
              (float_equal 3.0);
            field
              (fun (s : OT.scored_candidate) -> s.raw_return_pct)
              (float_equal 0.30);
            field
              (fun (s : OT.scored_candidate) -> s.exit_trigger)
              (equal_to OT.End_of_run);
          ]))

(* ------------------------------------------------------------------ *)
(* Edge cases                                                           *)
(* ------------------------------------------------------------------ *)

let test_score_empty_forward_returns_none _ =
  let candidate = make_candidate () in
  let result = Sc.score ~config:Sc.default_config ~candidate ~forward:[] in
  assert_that result is_none

let test_score_immediate_stop_hit _ =
  (* Stop hit on the very first forward week — a one-week trade. *)
  let entry_week = _date "2024-01-19" in
  let candidate =
    make_candidate ~entry_week ~entry_price:100.0 ~suggested_stop:92.0 ()
  in
  let d1 = Date.add_days entry_week 7 in
  let forward = [ make_outlook ~date:d1 ~close:88.0 ~low:87.0 () ] in
  let result = Sc.score ~config:Sc.default_config ~candidate ~forward in
  assert_that result
    (is_some_and
       (all_of
          [
            field
              (fun (s : OT.scored_candidate) -> s.exit_trigger)
              (equal_to OT.Stop_hit);
            field (fun (s : OT.scored_candidate) -> s.hold_weeks) (equal_to 1);
            field
              (fun (s : OT.scored_candidate) -> s.exit_price)
              (float_equal 88.0);
          ]))

let test_score_invalid_candidate_returns_none _ =
  (* Zero entry price is rejected. *)
  let candidate = make_candidate ~entry_price:0.0 () in
  let dates = fridays_from candidate.entry_week 1 in
  let d = List.hd_exn dates in
  let forward = [ make_outlook ~date:d ~close:100.0 () ] in
  let result = Sc.score ~config:Sc.default_config ~candidate ~forward in
  assert_that result is_none

let test_stage3_streak_resets_on_break _ =
  (* A Stage-3 week followed by a Stage-2 week should NOT trigger the
     Stage3_transition exit at default confirmation = 2. The streak resets,
     and the run completes End_of_run when no stop hit and no streak forms. *)
  let entry_week = _date "2024-01-19" in
  let candidate =
    make_candidate ~entry_week ~entry_price:100.0 ~suggested_stop:92.0 ()
  in
  let dates = fridays_from entry_week 3 in
  let stage3 =
    make_stage_result
      ~stage:(Stage3 { weeks_topping = 1 })
      ~ma_direction:Flat ~ma_slope_pct:0.0 ()
  in
  let forward =
    match dates with
    | [ d1; d2; d3 ] ->
        [
          make_outlook ~date:d1 ~close:105.0 ~low:100.0 ~stage_result:stage3 ();
          make_outlook ~date:d2 ~close:107.0 ~low:101.0 ();
          make_outlook ~date:d3 ~close:109.0 ~low:103.0 ();
        ]
    | _ -> assert_failure "expected 3 fridays"
  in
  let result = Sc.score ~config:Sc.default_config ~candidate ~forward in
  assert_that result
    (is_some_and
       (field
          (fun (s : OT.scored_candidate) -> s.exit_trigger)
          (equal_to OT.End_of_run)))

let test_stage3_confirm_weeks_one _ =
  (* With stage3_confirm_weeks = 1, a single Stage-3 week fires the exit
     immediately. Useful as a sensitivity-test pin. *)
  let entry_week = _date "2024-01-19" in
  let candidate =
    make_candidate ~entry_week ~entry_price:100.0 ~suggested_stop:92.0 ()
  in
  let dates = fridays_from entry_week 2 in
  let stage3 =
    make_stage_result
      ~stage:(Stage3 { weeks_topping = 1 })
      ~ma_direction:Flat ~ma_slope_pct:0.0 ()
  in
  let forward =
    match dates with
    | [ d1; d2 ] ->
        [
          make_outlook ~date:d1 ~close:105.0 ~low:100.0 ~stage_result:stage3 ();
          make_outlook ~date:d2 ~close:107.0 ~low:101.0 ();
        ]
    | _ -> assert_failure "expected 2 fridays"
  in
  let cfg =
    {
      Sc.stops_config = Weinstein_stops.default_config;
      stage3_confirm_weeks = 1;
    }
  in
  let result = Sc.score ~config:cfg ~candidate ~forward in
  assert_that result
    (is_some_and
       (all_of
          [
            field
              (fun (s : OT.scored_candidate) -> s.exit_trigger)
              (equal_to OT.Stage3_transition);
            field
              (fun (s : OT.scored_candidate) -> s.exit_week)
              (equal_to (_date "2024-01-26"));
          ]))

(* ------------------------------------------------------------------ *)
(* Test suite                                                          *)
(* ------------------------------------------------------------------ *)

let suite =
  "Outcome_scorer"
  >::: [
         "End_of_run when no exit fires" >:: test_score_end_of_run;
         "Stop_hit when weekly low pierces stop" >:: test_score_stop_hit;
         "Stage3_transition fires on confirmed streak"
         >:: test_score_stage3_transition;
         "R-multiple arithmetic pinned" >:: test_r_multiple_arithmetic;
         "empty forward returns None" >:: test_score_empty_forward_returns_none;
         "stop hit on first forward week" >:: test_score_immediate_stop_hit;
         "invalid candidate (zero entry) returns None"
         >:: test_score_invalid_candidate_returns_none;
         "Stage-3 streak resets on Stage-2 break"
         >:: test_stage3_streak_resets_on_break;
         "stage3_confirm_weeks = 1 fires immediately"
         >:: test_stage3_confirm_weeks_one;
       ]

let () = run_test_tt_main suite
