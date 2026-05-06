open OUnit2
open Core
open Matchers
open Laggard_rotation

(* --- helpers --- *)

let cfg_k4 = { hysteresis_weeks = 4; rs_window_weeks = 13 }
let cfg_k1 = { hysteresis_weeks = 1; rs_window_weeks = 13 }
let cfg_k6 = { hysteresis_weeks = 6; rs_window_weeks = 13 }

(* --- pure observe --- *)

let test_observe_positive_rs_returns_hold _ =
  (* Position outperforms benchmark — RS positive — Hold, count resets. *)
  assert_that
    (observe ~config:cfg_k4 ~prior_consecutive_neg_rs:0
       ~position_13w_return:0.10 ~benchmark_13w_return:0.05)
    (equal_to ((0, Hold) : int * decision))

let test_observe_positive_rs_resets_streak _ =
  (* Even after a streak of negatives, a single positive RS read resets the
     consecutive-negative count to zero and emits Hold. *)
  assert_that
    (observe ~config:cfg_k4 ~prior_consecutive_neg_rs:5
       ~position_13w_return:0.20 ~benchmark_13w_return:0.10)
    (equal_to ((0, Hold) : int * decision))

let test_observe_tied_rs_resets_streak _ =
  (* Position return matches benchmark exactly — RS is zero, not negative.
     The detector treats this as "not lagging" and resets the streak. *)
  assert_that
    (observe ~config:cfg_k4 ~prior_consecutive_neg_rs:3
       ~position_13w_return:0.05 ~benchmark_13w_return:0.05)
    (equal_to ((0, Hold) : int * decision))

let test_observe_negative_rs_first_week_below_threshold _ =
  (* prior_count=0 → new_count=1 < threshold=4 → Hold. *)
  assert_that
    (observe ~config:cfg_k4 ~prior_consecutive_neg_rs:0
       ~position_13w_return:(-0.05) ~benchmark_13w_return:0.10)
    (equal_to ((1, Hold) : int * decision))

let test_observe_negative_rs_at_threshold_fires _ =
  (* prior_count=3 → new_count=4 ≥ threshold=4 → Laggard_exit. *)
  assert_that
    (observe ~config:cfg_k4 ~prior_consecutive_neg_rs:3
       ~position_13w_return:(-0.05) ~benchmark_13w_return:0.05)
    (equal_to ((4, Laggard_exit { rs_13w_neg_weeks = 4 }) : int * decision))

let test_observe_negative_rs_above_threshold_keeps_firing _ =
  (* prior_count=10 → new_count=11 ≥ threshold=4 → Laggard_exit (still firing
     while RS persists negative). The wiring layer is responsible for not
     re-issuing exits on already-exiting positions; the detector itself just
     reports the signal. *)
  assert_that
    (observe ~config:cfg_k4 ~prior_consecutive_neg_rs:10
       ~position_13w_return:(-0.10) ~benchmark_13w_return:0.05)
    (equal_to ((11, Laggard_exit { rs_13w_neg_weeks = 11 }) : int * decision))

let test_observe_k1_fires_first_week _ =
  (* K=1: any single negative-RS observation fires immediately. *)
  assert_that
    (observe ~config:cfg_k1 ~prior_consecutive_neg_rs:0
       ~position_13w_return:0.02 ~benchmark_13w_return:0.03)
    (equal_to ((1, Laggard_exit { rs_13w_neg_weeks = 1 }) : int * decision))

let test_observe_k6_requires_six_weeks _ =
  (* prior=0 stepped through six negative-RS observations: only the sixth fires
     under K=6. Build the sequence and assert the run of decisions. *)
  let step prior =
    observe ~config:cfg_k6 ~prior_consecutive_neg_rs:prior
      ~position_13w_return:(-0.01) ~benchmark_13w_return:0.05
  in
  let r1 = step 0 in
  let r2 = step (fst r1) in
  let r3 = step (fst r2) in
  let r4 = step (fst r3) in
  let r5 = step (fst r4) in
  let r6 = step (fst r5) in
  assert_that [ r1; r2; r3; r4; r5; r6 ]
    (elements_are
       [
         equal_to ((1, Hold) : int * decision);
         equal_to ((2, Hold) : int * decision);
         equal_to ((3, Hold) : int * decision);
         equal_to ((4, Hold) : int * decision);
         equal_to ((5, Hold) : int * decision);
         equal_to ((6, Laggard_exit { rs_13w_neg_weeks = 6 }) : int * decision);
       ])

let test_observe_k0_treated_as_k1 _ =
  (* Defensive: hysteresis_weeks <= 0 is treated as 1, so a single
     negative-RS read fires immediately. *)
  let config = { hysteresis_weeks = 0; rs_window_weeks = 13 } in
  assert_that
    (observe ~config ~prior_consecutive_neg_rs:0 ~position_13w_return:(-0.01)
       ~benchmark_13w_return:0.01)
    (equal_to ((1, Laggard_exit { rs_13w_neg_weeks = 1 }) : int * decision))

let test_observe_negative_k_treated_as_k1 _ =
  let config = { hysteresis_weeks = -3; rs_window_weeks = 13 } in
  assert_that
    (observe ~config ~prior_consecutive_neg_rs:0 ~position_13w_return:(-0.05)
       ~benchmark_13w_return:0.05)
    (equal_to ((1, Laggard_exit { rs_13w_neg_weeks = 1 }) : int * decision))

let test_observe_neg_then_positive_then_neg_resets _ =
  (* Whipsaw: 3 neg → 1 pos → 1 neg. Under K=4, the post-reset neg starts a
     fresh count of 1 (Hold) — not a continuation of the prior 3-streak. *)
  let neg prior =
    observe ~config:cfg_k4 ~prior_consecutive_neg_rs:prior
      ~position_13w_return:(-0.05) ~benchmark_13w_return:0.05
  in
  let pos prior =
    observe ~config:cfg_k4 ~prior_consecutive_neg_rs:prior
      ~position_13w_return:0.10 ~benchmark_13w_return:0.05
  in
  let r1 = neg 0 in
  let r2 = neg (fst r1) in
  let r3 = neg (fst r2) in
  let r4 = pos (fst r3) in
  let r5 = neg (fst r4) in
  assert_that [ r1; r2; r3; r4; r5 ]
    (elements_are
       [
         equal_to ((1, Hold) : int * decision);
         equal_to ((2, Hold) : int * decision);
         equal_to ((3, Hold) : int * decision);
         equal_to ((0, Hold) : int * decision);
         equal_to ((1, Hold) : int * decision);
       ])

let test_observe_both_returns_negative_position_worse _ =
  (* Bear-market case: both position and benchmark are negative, but the
     position is more negative — RS is still negative, count advances. *)
  assert_that
    (observe ~config:cfg_k4 ~prior_consecutive_neg_rs:3
       ~position_13w_return:(-0.20) ~benchmark_13w_return:(-0.10))
    (equal_to ((4, Laggard_exit { rs_13w_neg_weeks = 4 }) : int * decision))

let test_observe_both_returns_negative_position_better _ =
  (* Bear-market case: both negative, but the position falls less than the
     benchmark — RS is positive, count resets, no exit. *)
  assert_that
    (observe ~config:cfg_k4 ~prior_consecutive_neg_rs:3
       ~position_13w_return:(-0.10) ~benchmark_13w_return:(-0.20))
    (equal_to ((0, Hold) : int * decision))

(* --- symbol-keyed wrapper --- *)

let test_observe_position_seeds_zero_for_unknown_symbol _ =
  let state = Hashtbl.create (module String) in
  let decision =
    observe_position ~config:cfg_k4 ~state ~symbol:"AAPL"
      ~position_13w_return:(-0.05) ~benchmark_13w_return:0.05
  in
  assert_that decision (equal_to (Hold : decision));
  assert_that (Hashtbl.find state "AAPL") (is_some_and (equal_to 1))

let test_observe_position_four_consecutive_negative_rs_fires _ =
  let state = Hashtbl.create (module String) in
  let neg () =
    observe_position ~config:cfg_k4 ~state ~symbol:"AAPL"
      ~position_13w_return:(-0.05) ~benchmark_13w_return:0.05
  in
  let _ = neg () in
  let _ = neg () in
  let _ = neg () in
  let decision = neg () in
  assert_that decision
    (equal_to (Laggard_exit { rs_13w_neg_weeks = 4 } : decision))

let test_observe_position_per_symbol_isolation _ =
  (* AAPL hits negative-RS four times (fires); MSFT hits negative once then
     positive once (no fire). State keys are independent. *)
  let state = Hashtbl.create (module String) in
  let aapl_neg () =
    observe_position ~config:cfg_k4 ~state ~symbol:"AAPL"
      ~position_13w_return:(-0.05) ~benchmark_13w_return:0.05
  in
  let msft_neg () =
    observe_position ~config:cfg_k4 ~state ~symbol:"MSFT"
      ~position_13w_return:(-0.02) ~benchmark_13w_return:0.05
  in
  let msft_pos () =
    observe_position ~config:cfg_k4 ~state ~symbol:"MSFT"
      ~position_13w_return:0.10 ~benchmark_13w_return:0.05
  in
  let _ = aapl_neg () in
  let _ = aapl_neg () in
  let _ = msft_neg () in
  let _ = aapl_neg () in
  let _ = msft_pos () in
  let aapl_final = aapl_neg () in
  let msft_final = msft_neg () in
  assert_that [ aapl_final; msft_final ]
    (elements_are
       [
         equal_to (Laggard_exit { rs_13w_neg_weeks = 4 } : decision);
         equal_to (Hold : decision);
       ])

let test_observe_position_resets_on_positive_rs _ =
  (* AAPL: neg → neg (count=2) → pos (resets to 0) → neg (count=1, Hold). *)
  let state = Hashtbl.create (module String) in
  let neg () =
    observe_position ~config:cfg_k4 ~state ~symbol:"AAPL"
      ~position_13w_return:(-0.05) ~benchmark_13w_return:0.05
  in
  let pos () =
    observe_position ~config:cfg_k4 ~state ~symbol:"AAPL"
      ~position_13w_return:0.10 ~benchmark_13w_return:0.05
  in
  let _ = neg () in
  let _ = neg () in
  let _ = pos () in
  let after_reset = neg () in
  assert_that after_reset (equal_to (Hold : decision));
  assert_that (Hashtbl.find state "AAPL") (is_some_and (equal_to 1))

(* --- default config --- *)

let test_default_config_hysteresis_is_four _ =
  assert_that default_config.hysteresis_weeks (equal_to 4)

let test_default_config_window_is_thirteen _ =
  assert_that default_config.rs_window_weeks (equal_to 13)

(* --- runner --- *)

let suite =
  "laggard_rotation"
  >::: [
         "observe: positive RS returns Hold"
         >:: test_observe_positive_rs_returns_hold;
         "observe: positive RS resets streak"
         >:: test_observe_positive_rs_resets_streak;
         "observe: tied RS resets streak (strict comparison)"
         >:: test_observe_tied_rs_resets_streak;
         "observe: first negative-RS week below threshold returns Hold"
         >:: test_observe_negative_rs_first_week_below_threshold;
         "observe: negative RS at threshold fires Laggard_exit"
         >:: test_observe_negative_rs_at_threshold_fires;
         "observe: negative RS above threshold keeps firing"
         >:: test_observe_negative_rs_above_threshold_keeps_firing;
         "observe: K=1 fires on first negative-RS week"
         >:: test_observe_k1_fires_first_week;
         "observe: K=6 requires six consecutive weeks"
         >:: test_observe_k6_requires_six_weeks;
         "observe: K=0 treated as K=1 (defensive)"
         >:: test_observe_k0_treated_as_k1;
         "observe: negative K treated as K=1 (defensive)"
         >:: test_observe_negative_k_treated_as_k1;
         "observe: neg → pos → neg resets streak"
         >:: test_observe_neg_then_positive_then_neg_resets;
         "observe: both returns negative, position worse, fires"
         >:: test_observe_both_returns_negative_position_worse;
         "observe: both returns negative, position better, no fire"
         >:: test_observe_both_returns_negative_position_better;
         "observe_position: unknown symbol seeds count to zero"
         >:: test_observe_position_seeds_zero_for_unknown_symbol;
         "observe_position: four consecutive negative-RS reads fire"
         >:: test_observe_position_four_consecutive_negative_rs_fires;
         "observe_position: symbols are tracked independently"
         >:: test_observe_position_per_symbol_isolation;
         "observe_position: a positive-RS read resets the streak"
         >:: test_observe_position_resets_on_positive_rs;
         "default_config: hysteresis is 4"
         >:: test_default_config_hysteresis_is_four;
         "default_config: window is 13"
         >:: test_default_config_window_is_thirteen;
       ]

let () = run_test_tt_main suite
