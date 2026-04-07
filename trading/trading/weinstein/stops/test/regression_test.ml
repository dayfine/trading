(** Stop state machine regression tests.

    Each scenario walks the state machine through a sequence of weekly bars,
    asserting the terminal state. These tests lock in behavioural correctness:
    any future change to the stop logic that breaks them must be intentional. *)

open OUnit2
open Core
open Trading_base.Types
open Weinstein_types
open Weinstein_stops
open Matchers

(* ------------------------------------------------------------------ *)
(* Shared helpers                                                        *)
(* ------------------------------------------------------------------ *)

let cfg = default_config

let make_bar ?(high_price = 105.0) ?(low_price = 95.0) close_price =
  {
    Types.Daily_price.date = Date.of_string "2024-01-01";
    open_price = close_price;
    high_price;
    low_price;
    close_price;
    adjusted_close = close_price;
    volume = 1000000;
  }

(** Apply a sequence of (close, low, high, ma, ma_dir, stage) tuples and return
    the final (state, last_event). *)
let run_sequence initial_state side steps =
  List.fold steps ~init:(initial_state, No_change)
    ~f:(fun (state, _) (close, low, high, ma, ma_dir, stage) ->
      let bar = make_bar ~low_price:low ~high_price:high close in
      update ~config:cfg ~side ~state ~current_bar:bar ~ma_value:ma
        ~ma_direction:ma_dir ~stage)

let stage2 = Stage2 { weeks_advancing = 4; late = false }
let stage3 = Stage3 { weeks_topping = 3 }
let stage4 = Stage4 { weeks_declining = 3 }

(* ------------------------------------------------------------------ *)
(* Scenario 1: Stage 2 long — stop raised through two correction cycles *)
(* ------------------------------------------------------------------ *)
(* A stock in a clean Stage 2 uptrend.
   - Advance phase: price runs from 100 to 120
   - First correction: 120 → 105 (12.5% pullback ≥ 8% threshold)
   - Recovery: price returns above 120 → stop raised to ~103.95
   - Second advance: 120 → 140
   - Second correction: 140 → 122 (12.9% pullback)
   - Recovery: price returns above 140 → stop raised again
   After 11 bars (4 cycles detected): stop > original 95, correction_count = 4. *)

let scenario1_stage2_trailing_stop_raised _ =
  let initial_state =
    Trailing
      {
        stop_level = 95.0;
        last_correction_extreme = 100.0;
        last_trend_extreme = 100.0;
        ma_at_last_adjustment = 98.0;
        correction_count = 0;
      }
  in
  let steps =
    [
      (* Advance phase: trend extreme builds to 120 *)
      (108.0, 105.0, 110.0, 100.0, Rising, stage2);
      (115.0, 112.0, 118.0, 103.0, Rising, stage2);
      (120.0, 117.0, 122.0, 106.0, Rising, stage2);
      (* First correction: low of 105, pullback = (120-105)/120 = 12.5% *)
      (110.0, 105.0, 112.0, 107.0, Rising, stage2);
      (107.0, 104.0, 111.0, 108.0, Rising, stage2);
      (* Recovery above prior peak of 120 — cycle 1 completes, stop raised *)
      (122.0, 119.0, 124.0, 109.0, Rising, stage2);
      (* Second advance: trend extreme builds to 140 *)
      (131.0, 128.0, 133.0, 112.0, Rising, stage2);
      (140.0, 137.0, 142.0, 116.0, Rising, stage2);
      (* Second correction: low of 122, pullback = (140-122)/140 = 12.9% *)
      (130.0, 126.0, 132.0, 117.0, Rising, stage2);
      (125.0, 122.0, 127.0, 118.0, Rising, stage2);
      (* Recovery above prior peak of 140 — cycle 2 completes, stop raised *)
      (143.0, 140.0, 145.0, 120.0, Rising, stage2);
    ]
  in
  let final_state, last_event = run_sequence initial_state Long steps in
  assert_that last_event
    (matching ~msg:"Expected Stop_raised in final step"
       (function Stop_raised { new_level; _ } -> Some new_level | _ -> None)
       (gt (module Float_ord) 95.0));
  assert_that final_state
    (matching ~msg:"Expected Trailing with stop above original and count = 4"
       (function
         | Trailing { stop_level; correction_count; _ } ->
             Some (stop_level, correction_count)
         | _ -> None)
       (pair (gt (module Float_ord) 95.0) (equal_to 4)))

(* ------------------------------------------------------------------ *)
(* Scenario 2: Stage 3 transition — flat MA triggers tightening        *)
(* ------------------------------------------------------------------ *)
(* A stock that was in Stage 2 now shows a flattening MA and Stage 3
   topping action. After two Stage 2 weeks with a rising MA, the third
   bar has a flat MA and Stage 3 classification → tightening triggered. *)

let scenario2_stage3_tightening _ =
  let initial_state =
    Trailing
      {
        stop_level = 110.0;
        last_correction_extreme = 115.0;
        last_trend_extreme = 130.0;
        ma_at_last_adjustment = 118.0;
        correction_count = 2;
      }
  in
  let steps =
    [
      (* Still Stage 2, rising MA *)
      (133.0, 130.0, 135.0, 122.0, Rising, stage2);
      (131.0, 128.0, 134.0, 123.0, Rising, stage2);
      (* MA flattens, Stage 3 topping — tightening fires *)
      (129.0, 126.0, 131.0, 123.0, Flat, stage3);
    ]
  in
  let final_state, last_event = run_sequence initial_state Long steps in
  assert_that last_event
    (matching ~msg:"Expected Entered_tightening on Stage 3 with flat MA"
       (function Entered_tightening { reason } -> Some reason | _ -> None)
       (field String.length (gt (module Int_ord) 0)));
  assert_that final_state
    (matching ~msg:"Expected Tightened state with stop >= 110"
       (function Tightened { stop_level; _ } -> Some stop_level | _ -> None)
       (ge (module Float_ord) 110.0))

(* ------------------------------------------------------------------ *)
(* Scenario 3: Stop hit — long position crosses stop during correction  *)
(* ------------------------------------------------------------------ *)
(* A position in Initial state (stop at 47.875) experiences a sharp
   decline below the stop. Stop_hit fires; no further state evolution. *)

let scenario3_stop_hit_long _ =
  let initial_state =
    compute_initial_stop ~config:cfg ~side:Long ~reference_level:50.0
  in
  (* Verify the initial stop is placed correctly *)
  assert_that (get_stop_level initial_state) (float_equal 47.875);
  (* Sharp decline: low pierces the stop *)
  let bar = make_bar ~low_price:45.0 ~high_price:52.0 49.0 in
  let _new_state, event =
    update ~config:cfg ~side:Long ~state:initial_state ~current_bar:bar
      ~ma_value:50.0 ~ma_direction:Rising ~stage:stage2
  in
  assert_that event
    (matching ~msg:"Expected Stop_hit"
       (function
         | Stop_hit { trigger_price; stop_level } ->
             Some (trigger_price, stop_level)
         | _ -> None)
       (pair (float_equal 45.0) (float_equal 47.875)))

(* ------------------------------------------------------------------ *)
(* Scenario 4: Short side — Stage 4 short, stop lowered through cycle  *)
(* ------------------------------------------------------------------ *)
(* A short position in Stage 4 (price declining). For a short, the stop
   is above price and is lowered (improved) after correction cycles.
   - Decline phase: price drops from 100 to 80
   - First correction (counter-rally): 80 → 88 (10% rally from trough)
   - Renewed decline: price falls below 80 → cycle completes, stop lowered *)

let scenario4_short_stage4_stop_lowered _ =
  let initial_state =
    Trailing
      {
        stop_level = 115.0;
        (* Stop above entry for short *)
        last_correction_extreme = 108.0;
        last_trend_extreme = 108.0;
        ma_at_last_adjustment = 110.0;
        correction_count = 0;
      }
  in
  let steps =
    [
      (* Decline phase: trend extreme builds down to 80 *)
      (95.0, 92.0, 97.0, 108.0, Declining, stage4);
      (88.0, 85.0, 90.0, 105.0, Declining, stage4);
      (80.0, 78.0, 82.0, 102.0, Declining, stage4);
      (* Counter-rally: high of 88, rally = (88-80)/80 = 10% ≥ 8% threshold *)
      (85.0, 82.0, 88.0, 101.0, Declining, stage4);
      (87.0, 84.0, 89.0, 100.0, Declining, stage4);
      (* Renewed decline below prior trough of 80 — cycle completes, stop lowered *)
      (78.0, 75.0, 79.0, 98.0, Declining, stage4);
    ]
  in
  let final_state, last_event = run_sequence initial_state Short steps in
  assert_that last_event
    (matching ~msg:"Expected Stop_raised (= lowered for short)"
       (function Stop_raised { new_level; _ } -> Some new_level | _ -> None)
       (lt (module Float_ord) 115.0));
  assert_that final_state
    (matching ~msg:"Expected Trailing with stop below 115 and count = 2"
       (function
         | Trailing { stop_level; correction_count; _ } ->
             Some (stop_level, correction_count)
         | _ -> None)
       (pair (lt (module Float_ord) 115.0) (equal_to 2)))

(* ------------------------------------------------------------------ *)
(* Scenario 5: Full journey — Initial → Trailing → Tightened → Stop_hit *)
(* ------------------------------------------------------------------ *)
(* A complete position lifecycle:
   1. Enter with Initial stop below support
   2. Price advances into Stage 2, records trend extremes → Trailing
   3. One correction cycle completes, stop raised
   4. MA flattens (Stage 3) → Tightened
   5. Price drops through tightened stop → Stop_hit *)

let scenario5_full_lifecycle _ =
  (* Step 1: Initial state from entry *)
  let state0 =
    compute_initial_stop ~config:cfg ~side:Long ~reference_level:52.0
  in
  assert_that state0
    (matching ~msg:"Initial state after entry"
       (function Initial _ -> Some () | _ -> None)
       (equal_to ()));
  (* Step 2: advance in Stage 2, transitions to Trailing *)
  let bar_advance = make_bar ~low_price:53.0 ~high_price:58.0 56.0 in
  let state1, _ =
    update ~config:cfg ~side:Long ~state:state0 ~current_bar:bar_advance
      ~ma_value:51.0 ~ma_direction:Rising ~stage:stage2
  in
  assert_that state1
    (matching ~msg:"Trailing after first advance bar"
       (function Trailing _ -> Some () | _ -> None)
       (equal_to ()));
  (* Step 3: build up trend extreme, correct, recover — stop raised *)
  let steps_to_raise =
    [
      (62.0, 59.0, 64.0, 53.0, Rising, stage2);
      (68.0, 65.0, 70.0, 55.0, Rising, stage2);
      (* Correction: (68-60)/68 = 11.8% *)
      (63.0, 60.0, 65.0, 56.0, Rising, stage2);
      (* Recovery above prior peak of 68 *)
      (70.0, 67.0, 72.0, 57.0, Rising, stage2);
    ]
  in
  let state2, _ = run_sequence state1 Long steps_to_raise in
  assert_that (get_stop_level state2)
    (gt (module Float_ord) (get_stop_level state0));
  (* Step 4: MA flattens, Stage 3 → Tightened *)
  let bar_top = make_bar ~low_price:68.0 ~high_price:72.0 70.0 in
  let state3, event3 =
    update ~config:cfg ~side:Long ~state:state2 ~current_bar:bar_top
      ~ma_value:58.0 ~ma_direction:Flat ~stage:stage3
  in
  assert_that event3
    (matching ~msg:"Entered_tightening on flat MA"
       (function Entered_tightening _ -> Some () | _ -> None)
       (equal_to ()));
  assert_that state3
    (matching ~msg:"Tightened state"
       (function Tightened _ -> Some () | _ -> None)
       (equal_to ()));
  (* Step 5: price drops through tightened stop → Stop_hit *)
  let tightened_stop = get_stop_level state3 in
  let bar_exit =
    make_bar ~low_price:(tightened_stop -. 2.0) ~high_price:68.0 66.0
  in
  let _state4, event4 =
    update ~config:cfg ~side:Long ~state:state3 ~current_bar:bar_exit
      ~ma_value:57.0 ~ma_direction:Flat ~stage:stage3
  in
  assert_that event4
    (matching ~msg:"Stop_hit in Tightened state"
       (function Stop_hit { stop_level; _ } -> Some stop_level | _ -> None)
       (float_equal tightened_stop))

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let () =
  run_test_tt_main
    ("weinstein_stops_regression"
    >::: [
           "scenario1: stage2 trailing stop raised through two cycles"
           >:: scenario1_stage2_trailing_stop_raised;
           "scenario2: stage3 tightening on flat MA"
           >:: scenario2_stage3_tightening;
           "scenario3: stop hit on long position" >:: scenario3_stop_hit_long;
           "scenario4: short side stop lowered through cycle"
           >:: scenario4_short_stage4_stop_lowered;
           "scenario5: full lifecycle initial to stop_hit"
           >:: scenario5_full_lifecycle;
         ])
