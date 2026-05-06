open OUnit2
open Core
open Matchers
open Stage3_force_exit

(* --- helpers --- *)

let stage1 = Weinstein_types.Stage1 { weeks_in_base = 5 }
let stage2 = Weinstein_types.Stage2 { weeks_advancing = 3; late = false }
let stage3 = Weinstein_types.Stage3 { weeks_topping = 1 }
let stage4 = Weinstein_types.Stage4 { weeks_declining = 2 }
let cfg_k2 = { hysteresis_weeks = 2 }
let cfg_k1 = { hysteresis_weeks = 1 }
let cfg_k3 = { hysteresis_weeks = 3 }

(* --- pure observe --- *)

let test_observe_stage2_returns_hold _ =
  assert_that
    (observe ~config:cfg_k2 ~prior_consecutive_stage3:0 ~current_stage:stage2)
    (equal_to ((0, Hold) : int * decision))

let test_observe_stage1_returns_hold_resets_count _ =
  (* Even after a streak, a non-Stage-3 read resets the consecutive count to
     zero and emits Hold. *)
  assert_that
    (observe ~config:cfg_k2 ~prior_consecutive_stage3:5 ~current_stage:stage1)
    (equal_to ((0, Hold) : int * decision))

let test_observe_stage4_returns_hold_resets_count _ =
  assert_that
    (observe ~config:cfg_k2 ~prior_consecutive_stage3:7 ~current_stage:stage4)
    (equal_to ((0, Hold) : int * decision))

let test_observe_stage3_first_week_below_threshold _ =
  (* prior_count=0 → new_count=1 < threshold=2 → Hold. *)
  assert_that
    (observe ~config:cfg_k2 ~prior_consecutive_stage3:0 ~current_stage:stage3)
    (equal_to ((1, Hold) : int * decision))

let test_observe_stage3_at_threshold_fires _ =
  (* prior_count=1 → new_count=2 ≥ threshold=2 → Force_exit. *)
  assert_that
    (observe ~config:cfg_k2 ~prior_consecutive_stage3:1 ~current_stage:stage3)
    (equal_to ((2, Force_exit { weeks_in_stage3 = 2 }) : int * decision))

let test_observe_stage3_above_threshold_keeps_firing _ =
  (* prior_count=4 → new_count=5 ≥ threshold=2 → Force_exit (still firing
     while Stage 3 persists). The wiring layer is responsible for not
     re-issuing exits on already-exiting positions; the detector itself just
     reports the signal. *)
  assert_that
    (observe ~config:cfg_k2 ~prior_consecutive_stage3:4 ~current_stage:stage3)
    (equal_to ((5, Force_exit { weeks_in_stage3 = 5 }) : int * decision))

let test_observe_k1_fires_first_week _ =
  assert_that
    (observe ~config:cfg_k1 ~prior_consecutive_stage3:0 ~current_stage:stage3)
    (equal_to ((1, Force_exit { weeks_in_stage3 = 1 }) : int * decision))

let test_observe_k3_requires_three_weeks _ =
  (* prior=0, new=1, 2, 3 — only the third fires. Build the sequence. *)
  let r1 =
    observe ~config:cfg_k3 ~prior_consecutive_stage3:0 ~current_stage:stage3
  in
  let r2 =
    observe ~config:cfg_k3 ~prior_consecutive_stage3:(fst r1)
      ~current_stage:stage3
  in
  let r3 =
    observe ~config:cfg_k3 ~prior_consecutive_stage3:(fst r2)
      ~current_stage:stage3
  in
  assert_that [ r1; r2; r3 ]
    (elements_are
       [
         equal_to ((1, Hold) : int * decision);
         equal_to ((2, Hold) : int * decision);
         equal_to ((3, Force_exit { weeks_in_stage3 = 3 }) : int * decision);
       ])

let test_observe_k0_treated_as_k1 _ =
  (* Defensive: hysteresis_weeks <= 0 is treated as 1, so a single Stage-3
     read fires immediately. *)
  let config = { hysteresis_weeks = 0 } in
  assert_that
    (observe ~config ~prior_consecutive_stage3:0 ~current_stage:stage3)
    (equal_to ((1, Force_exit { weeks_in_stage3 = 1 }) : int * decision))

let test_observe_negative_k_treated_as_k1 _ =
  let config = { hysteresis_weeks = -5 } in
  assert_that
    (observe ~config ~prior_consecutive_stage3:0 ~current_stage:stage3)
    (equal_to ((1, Force_exit { weeks_in_stage3 = 1 }) : int * decision))

let test_observe_stage3_then_stage2_resets _ =
  (* A whipsaw scenario: 1 week Stage 3, then 1 week Stage 2.
     The next Stage-3 read should be treated as a fresh first week (count=1),
     not as a continuation of the prior streak. *)
  let r1 =
    observe ~config:cfg_k2 ~prior_consecutive_stage3:0 ~current_stage:stage3
  in
  let r2 =
    observe ~config:cfg_k2 ~prior_consecutive_stage3:(fst r1)
      ~current_stage:stage2
  in
  let r3 =
    observe ~config:cfg_k2 ~prior_consecutive_stage3:(fst r2)
      ~current_stage:stage3
  in
  assert_that [ r1; r2; r3 ]
    (elements_are
       [
         equal_to ((1, Hold) : int * decision);
         equal_to ((0, Hold) : int * decision);
         equal_to ((1, Hold) : int * decision);
       ])

(* --- symbol-keyed wrapper --- *)

let test_observe_position_seeds_zero_for_unknown_symbol _ =
  let state = Hashtbl.create (module String) in
  let decision =
    observe_position ~config:cfg_k2 ~state ~symbol:"AAPL" ~current_stage:stage3
  in
  assert_that decision (equal_to (Hold : decision));
  assert_that (Hashtbl.find state "AAPL") (is_some_and (equal_to 1))

let test_observe_position_two_consecutive_stage3_fires _ =
  let state = Hashtbl.create (module String) in
  let _ =
    observe_position ~config:cfg_k2 ~state ~symbol:"AAPL" ~current_stage:stage3
  in
  let decision =
    observe_position ~config:cfg_k2 ~state ~symbol:"AAPL" ~current_stage:stage3
  in
  assert_that decision
    (equal_to (Force_exit { weeks_in_stage3 = 2 } : decision))

let test_observe_position_per_symbol_isolation _ =
  (* Two symbols are tracked independently. AAPL hits Stage 3 twice (fires);
     MSFT hits Stage 3 once (no fire). *)
  let state = Hashtbl.create (module String) in
  let _ =
    observe_position ~config:cfg_k2 ~state ~symbol:"AAPL" ~current_stage:stage3
  in
  let _ =
    observe_position ~config:cfg_k2 ~state ~symbol:"MSFT" ~current_stage:stage2
  in
  let aapl =
    observe_position ~config:cfg_k2 ~state ~symbol:"AAPL" ~current_stage:stage3
  in
  let msft =
    observe_position ~config:cfg_k2 ~state ~symbol:"MSFT" ~current_stage:stage3
  in
  assert_that [ aapl; msft ]
    (elements_are
       [
         equal_to (Force_exit { weeks_in_stage3 = 2 } : decision);
         equal_to (Hold : decision);
       ])

let test_observe_position_resets_on_stage2_read _ =
  (* AAPL: Stage3 → Stage3 (fires) → Stage2 (resets). Next Stage3 read is
     a fresh first week (Hold under K=2). *)
  let state = Hashtbl.create (module String) in
  let _ =
    observe_position ~config:cfg_k2 ~state ~symbol:"AAPL" ~current_stage:stage3
  in
  let _ =
    observe_position ~config:cfg_k2 ~state ~symbol:"AAPL" ~current_stage:stage3
  in
  let _ =
    observe_position ~config:cfg_k2 ~state ~symbol:"AAPL" ~current_stage:stage2
  in
  let after_reset =
    observe_position ~config:cfg_k2 ~state ~symbol:"AAPL" ~current_stage:stage3
  in
  assert_that after_reset (equal_to (Hold : decision));
  assert_that (Hashtbl.find state "AAPL") (is_some_and (equal_to 1))

(* --- default config --- *)

let test_default_config_hysteresis_is_two _ =
  assert_that default_config.hysteresis_weeks (equal_to 2)

(* --- runner --- *)

let suite =
  "stage3_force_exit"
  >::: [
         "observe: Stage 2 returns Hold" >:: test_observe_stage2_returns_hold;
         "observe: Stage 1 returns Hold and resets count"
         >:: test_observe_stage1_returns_hold_resets_count;
         "observe: Stage 4 returns Hold and resets count"
         >:: test_observe_stage4_returns_hold_resets_count;
         "observe: first Stage 3 week below threshold returns Hold"
         >:: test_observe_stage3_first_week_below_threshold;
         "observe: Stage 3 at threshold fires Force_exit"
         >:: test_observe_stage3_at_threshold_fires;
         "observe: Stage 3 above threshold keeps firing"
         >:: test_observe_stage3_above_threshold_keeps_firing;
         "observe: K=1 fires on first Stage 3 week"
         >:: test_observe_k1_fires_first_week;
         "observe: K=3 requires three consecutive weeks"
         >:: test_observe_k3_requires_three_weeks;
         "observe: K=0 treated as K=1 (defensive)"
         >:: test_observe_k0_treated_as_k1;
         "observe: negative K treated as K=1 (defensive)"
         >:: test_observe_negative_k_treated_as_k1;
         "observe: Stage 3 then Stage 2 then Stage 3 resets streak"
         >:: test_observe_stage3_then_stage2_resets;
         "observe_position: unknown symbol seeds count to zero"
         >:: test_observe_position_seeds_zero_for_unknown_symbol;
         "observe_position: two consecutive Stage 3 reads fire"
         >:: test_observe_position_two_consecutive_stage3_fires;
         "observe_position: symbols are tracked independently"
         >:: test_observe_position_per_symbol_isolation;
         "observe_position: a Stage 2 read resets the streak"
         >:: test_observe_position_resets_on_stage2_read;
         "default_config: hysteresis is 2"
         >:: test_default_config_hysteresis_is_two;
       ]

let () = run_test_tt_main suite
