(** Unit tests for {!Backtest.Fold_health}. Pins the A2 degenerate-fold
    signature (zero in-window round-trips + flat equity + an unexplained
    terminal move all firing together — the 2009-06-26 warmup-leak repro), each
    invariant's guard in isolation, and the healthy-run silence. Uses the public
    [check] entry point with synthetic terminal facts so no backtest is run. *)

open OUnit2
open Core
open Matchers
module FH = Backtest.Fold_health

let cfg = FH.default_config

(* A flat equity curve of [n] copies of [v] — the frozen-mark signature: every
   step marks the same NAV, so the distinct/total ratio is 1/n. *)
let _flat_curve ~n ~v = List.init n ~f:(fun _ -> v)

(* A healthy equity curve: [n] strictly increasing NAV values, so every point is
   distinct and the flat-equity guard never trips. *)
let _rising_curve ~n ~start ~step =
  List.init n ~f:(fun i -> start +. (Float.of_int i *. step))

(* The exact A2 repro terminal facts: 523 in-window steps, zero round-trips, a
   flat equity curve pinned at 352220.30, and a -64.78% terminal return from
   1,000,000 initial cash. All three invariants must fire. *)
let test_a2_repro_trips_all_three _ =
  let findings =
    FH.check ~config:cfg ~initial_cash:1_000_000.0
      ~final_portfolio_value:352_220.30 ~n_round_trips:0 ~n_steps:523
      ~equity_curve:(_flat_curve ~n:523 ~v:352_220.30)
  in
  assert_that findings
    (elements_are
       [
         matching ~msg:"Expected Zero_round_trips_over_long_window"
           (function
             | FH.Zero_round_trips_over_long_window { n_steps } -> Some n_steps
             | _ -> None)
           (equal_to 523);
         matching ~msg:"Expected Flat_equity_curve"
           (function
             | FH.Flat_equity_curve { n_points; n_distinct } ->
                 Some (n_points, n_distinct)
             | _ -> None)
           (equal_to (523, 1));
         matching ~msg:"Expected Unexplained_terminal_move"
           (function
             | FH.Unexplained_terminal_move { total_return_pct } ->
                 Some total_return_pct
             | _ -> None)
           (float_equal ~epsilon:0.01 (-64.778));
       ])

(* A healthy run: many round-trips, a rising distinct equity curve, and a modest
   +30.88% terminal move (the sibling 2009-06-29 fold). No findings. *)
let test_healthy_run_silent _ =
  let findings =
    FH.check ~config:cfg ~initial_cash:1_000_000.0
      ~final_portfolio_value:1_308_774.21 ~n_round_trips:68 ~n_steps:522
      ~equity_curve:(_rising_curve ~n:522 ~start:1_000_000.0 ~step:600.0)
  in
  assert_that findings (size_is 0)

(* Zero round-trips below the step floor must NOT fire — a genuinely short window
   can legitimately have no round-trips. *)
let test_zero_round_trips_below_floor_silent _ =
  let findings =
    FH.check ~config:cfg ~initial_cash:1_000_000.0
      ~final_portfolio_value:1_010_000.0 ~n_round_trips:0
      ~n_steps:(cfg.min_steps_for_check - 1)
      ~equity_curve:(_rising_curve ~n:30 ~start:1_000_000.0 ~step:300.0)
  in
  assert_that findings (size_is 0)

(* Exactly at the step floor with zero round-trips: the zero-round-trips
   invariant fires (boundary is inclusive). Equity rising + small terminal move,
   so only that one finding. *)
let test_zero_round_trips_at_floor_fires _ =
  let findings =
    FH.check ~config:cfg ~initial_cash:1_000_000.0
      ~final_portfolio_value:1_010_000.0 ~n_round_trips:0
      ~n_steps:cfg.min_steps_for_check
      ~equity_curve:
        (_rising_curve ~n:cfg.min_steps_for_check ~start:1_000_000.0 ~step:300.0)
  in
  assert_that findings
    (elements_are
       [
         equal_to
           (FH.Zero_round_trips_over_long_window
              { n_steps = cfg.min_steps_for_check });
       ])

(* An empty equity curve never trips the flat-equity invariant (no data). With
   round-trips present and a modest move, no findings at all. *)
let test_empty_equity_curve_silent _ =
  let findings =
    FH.check ~config:cfg ~initial_cash:1_000_000.0
      ~final_portfolio_value:1_050_000.0 ~n_round_trips:10 ~n_steps:200
      ~equity_curve:[]
  in
  assert_that findings (size_is 0)

(* A large terminal move that IS explained by in-window round-trips (n>0) must
   NOT trip the unexplained-move invariant — a real +120% winner is healthy. The
   rising curve keeps the flat-equity guard silent too. *)
let test_large_move_with_round_trips_silent _ =
  let findings =
    FH.check ~config:cfg ~initial_cash:1_000_000.0
      ~final_portfolio_value:2_200_000.0 ~n_round_trips:42 ~n_steps:400
      ~equity_curve:(_rising_curve ~n:400 ~start:1_000_000.0 ~step:3_000.0)
  in
  assert_that findings (size_is 0)

(* Non-positive initial cash suppresses the unexplained-move invariant (return
   undefined) even with zero round-trips and a depleted final value. The flat
   curve still trips its own invariant; zero round-trips trips its own. So two
   findings, but NOT the terminal-move one. *)
let test_nonpositive_initial_cash_suppresses_move _ =
  let findings =
    FH.check ~config:cfg ~initial_cash:0.0 ~final_portfolio_value:200_000.0
      ~n_round_trips:0 ~n_steps:300
      ~equity_curve:(_flat_curve ~n:300 ~v:200_000.0)
  in
  assert_that findings
    (elements_are
       [
         equal_to (FH.Zero_round_trips_over_long_window { n_steps = 300 });
         equal_to (FH.Flat_equity_curve { n_points = 300; n_distinct = 1 });
       ])

(* [has_findings] mirrors [check]: true for the A2 signature, false for a healthy
   run. *)
let test_has_findings_mirrors_check _ =
  let suspect =
    FH.has_findings ~config:cfg ~initial_cash:1_000_000.0
      ~final_portfolio_value:352_220.30 ~n_round_trips:0 ~n_steps:523
      ~equity_curve:(_flat_curve ~n:523 ~v:352_220.30)
  in
  assert_that suspect (equal_to true)

let test_has_findings_false_when_healthy _ =
  let suspect =
    FH.has_findings ~config:cfg ~initial_cash:1_000_000.0
      ~final_portfolio_value:1_308_774.21 ~n_round_trips:68 ~n_steps:522
      ~equity_curve:(_rising_curve ~n:522 ~start:1_000_000.0 ~step:600.0)
  in
  assert_that suspect (equal_to false)

(* #1553 divergence guard: portfolio holds more open positions than the strategy
   monitors under stop evaluation. The default [max_stuck_held_positions = 0]
   means any positive gap trips a single [Stuck_held_positions] finding. *)
let test_check_divergence_fires_on_gap _ =
  let findings =
    FH.check_divergence ~config:cfg ~n_open_positions:24 ~n_stop_eligible:23
  in
  assert_that findings
    (elements_are
       [
         equal_to
           (FH.Stuck_held_positions
              { n_open_positions = 24; n_stop_eligible = 23 });
       ])

(* No gap (every open position is under stop evaluation): silent. *)
let test_check_divergence_silent_when_aligned _ =
  let findings =
    FH.check_divergence ~config:cfg ~n_open_positions:10 ~n_stop_eligible:10
  in
  assert_that findings (size_is 0)

(* A wider tolerance suppresses a small gap: gap of 1 with
   [max_stuck_held_positions = 1] does not fire (boundary is strict-greater). *)
let test_check_divergence_respects_tolerance _ =
  let findings =
    FH.check_divergence
      ~config:{ cfg with max_stuck_held_positions = 1 }
      ~n_open_positions:11 ~n_stop_eligible:10
  in
  assert_that findings (size_is 0)

let suite =
  "fold_health"
  >::: [
         "a2_repro_trips_all_three" >:: test_a2_repro_trips_all_three;
         "healthy_run_silent" >:: test_healthy_run_silent;
         "zero_round_trips_below_floor_silent"
         >:: test_zero_round_trips_below_floor_silent;
         "zero_round_trips_at_floor_fires"
         >:: test_zero_round_trips_at_floor_fires;
         "empty_equity_curve_silent" >:: test_empty_equity_curve_silent;
         "large_move_with_round_trips_silent"
         >:: test_large_move_with_round_trips_silent;
         "nonpositive_initial_cash_suppresses_move"
         >:: test_nonpositive_initial_cash_suppresses_move;
         "has_findings_mirrors_check" >:: test_has_findings_mirrors_check;
         "has_findings_false_when_healthy"
         >:: test_has_findings_false_when_healthy;
         "check_divergence_fires_on_gap" >:: test_check_divergence_fires_on_gap;
         "check_divergence_silent_when_aligned"
         >:: test_check_divergence_silent_when_aligned;
         "check_divergence_respects_tolerance"
         >:: test_check_divergence_respects_tolerance;
       ]

let () = run_test_tt_main suite
