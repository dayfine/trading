(** Stop state machine regression tests.

    Each scenario walks the state machine through a sequence of weekly bars,
    asserting the terminal state. These tests lock in behavioural correctness:
    any future change to the stop logic that breaks them must be intentional.

    correction_count semantics: increments by 1 for each complete cycle — one
    cycle = a pullback of ≥8% from the trend extreme followed by a close that
    recovers back above that extreme. Correction + recovery = 1 increment. *)

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
(* Stage 2 long — trailing stop raised through two correction phases    *)
(* ------------------------------------------------------------------ *)
(* A stock breaks out of a base at 100. Initial stop from
   compute_initial_stop (95.875). Entry bar seeds the Trailing state
   with corr=98 (bar low) and trend=100 (bar close).

   Phase A (entry + 6 bars): two correction cycles.
     cycle 1 at c=115: entry low=98 is the correction anchor; trend
       reached 108 on bar 1, (108-98)/108=9.3%, close=115 ≥ 108.
       Stop 95.875→96.875.
     cycle 2 at c=122: real pullback to lows 105/104 from the 120 high;
       (120-104)/120=13.3%, close=122 ≥ 120. Stop 96.875→102.96.

   Phase B (5 bars): price continues up through 131→140, pulls back to 122,
   recovers to 143. One more cycle completes:
     cycle 3 at c=143: trend=140, corr=122 (reset by fix), (140-122)/140=13%,
       stop 102.96→120.78 *)

let stage2_trailing_stop_raised_phase_a _ =
  let state0 =
    compute_initial_stop ~config:cfg ~side:Long ~reference_level:100.0
  in
  assert_that (get_stop_level state0) (float_equal 95.875);
  let entry_bar = make_bar ~low_price:98.0 ~high_price:103.0 100.0 in
  let initial_state, _ =
    update ~config:cfg ~side:Long ~state:state0 ~current_bar:entry_bar
      ~ma_value:98.0 ~ma_direction:Rising ~stage:stage2
  in
  (* cycle 1: entry low=98 held through bars 1-2; trend reached 108 on
     bar 1, then (108-98)/108=9.3% depth fires when close=115 ≥ 108 *)
  let steps_to_cycle1 =
    [
      (108.0, 105.0, 110.0, 100.0, Rising, stage2);
      (115.0, 112.0, 118.0, 103.0, Rising, stage2);
    ]
  in
  let state1, event1 = run_sequence initial_state Long steps_to_cycle1 in
  assert_that event1
    (matching ~msg:"cycle 1: stop raised to 96.875"
       (function Stop_raised { new_level; _ } -> Some new_level | _ -> None)
       (float_equal 96.875));
  assert_that state1
    (matching ~msg:"Trailing: stop=96.875, count=1"
       (function
         | Trailing { stop_level; correction_count; _ } ->
             Some (stop_level, correction_count)
         | _ -> None)
       (pair (float_equal 96.875) (equal_to 1)));
  (* cycle 2: real pullback — lows 105/104 after a 120 high;
     (120-104)/120=13.3%, close=122 ≥ trend=120 *)
  let steps_to_cycle2 =
    [
      (120.0, 117.0, 122.0, 106.0, Rising, stage2);
      (110.0, 105.0, 112.0, 107.0, Rising, stage2);
      (107.0, 104.0, 111.0, 108.0, Rising, stage2);
      (122.0, 119.0, 124.0, 109.0, Rising, stage2);
    ]
  in
  let final_state, last_event = run_sequence state1 Long steps_to_cycle2 in
  assert_that last_event
    (matching ~msg:"cycle 2: stop raised to 102.96"
       (function Stop_raised { new_level; _ } -> Some new_level | _ -> None)
       (float_equal 102.96));
  assert_that final_state
    (matching ~msg:"Trailing: stop=102.96, count=2"
       (function
         | Trailing { stop_level; correction_count; _ } ->
             Some (stop_level, correction_count)
         | _ -> None)
       (pair (float_equal 102.96) (equal_to 2)))

let stage2_trailing_stop_raised_phase_b _ =
  (* Start from the state left by phase A *)
  (* Initial state reflects what the fix produces after phase A: both extremes
     reset to close_price=122 of the cycle-completion bar, not the bar's low. *)
  let initial_state =
    Trailing
      {
        stop_level = 102.96;
        last_correction_extreme = 122.0;
        last_trend_extreme = 122.0;
        ma_at_last_adjustment = 109.0;
        correction_count = 2;
      }
  in
  let steps =
    [
      (* trend extends to 131; corr stays at 122 — no pullback below 122 *)
      (131.0, 128.0, 133.0, 112.0, Rising, stage2);
      (* trend extends to 140; (131-122)/131=6.9% < 8% — not a full correction *)
      (140.0, 137.0, 142.0, 116.0, Rising, stage2);
      (* price pulls back: lows reach 122, still below the 140 peak *)
      (130.0, 126.0, 132.0, 117.0, Rising, stage2);
      (125.0, 122.0, 127.0, 118.0, Rising, stage2);
      (* cycle 3: (140-122)/140=13%, close 143 ≥ trend 140 *)
      (143.0, 140.0, 145.0, 120.0, Rising, stage2);
    ]
  in
  let final_state, last_event = run_sequence initial_state Long steps in
  assert_that last_event
    (matching ~msg:"cycle 3: stop raised to 120.78"
       (function Stop_raised { new_level; _ } -> Some new_level | _ -> None)
       (float_equal 120.78));
  assert_that final_state
    (matching ~msg:"Trailing: stop=120.78, count=3"
       (function
         | Trailing { stop_level; correction_count; _ } ->
             Some (stop_level, correction_count)
         | _ -> None)
       (pair (float_equal 120.78) (equal_to 3)))

(* ------------------------------------------------------------------ *)
(* Stage 3 transition — flat MA triggers tightening                     *)
(* ------------------------------------------------------------------ *)
(* A stock that was in Stage 2 now shows a flattening MA and Stage 3
   topping action.
   - Bar 1 (c=133, Rising): cycle 3 completes immediately — prior state
     already had 11.5% pullback, stop raised 110→113.85
   - Bar 2 (c=131, Rising): no cycle, tracking continues
   - Bar 3 (c=129, Flat MA, Stage3): tightening fires, stop→126.72 *)

let stage3_tightening _ =
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
      (133.0, 130.0, 135.0, 122.0, Rising, stage2);
      (131.0, 128.0, 134.0, 123.0, Rising, stage2);
      (* MA flattens, Stage 3 topping — tightening fires *)
      (129.0, 126.0, 131.0, 123.0, Flat, stage3);
    ]
  in
  let final_state, last_event = run_sequence initial_state Long steps in
  assert_that last_event
    (matching ~msg:"Entered_tightening on Stage 3 with flat MA"
       (function Entered_tightening { reason } -> Some reason | _ -> None)
       (field String.length (gt (module Int_ord) 0)));
  assert_that final_state
    (matching ~msg:"Tightened: stop=126.72"
       (function Tightened { stop_level; _ } -> Some stop_level | _ -> None)
       (float_equal 126.72))

(* ------------------------------------------------------------------ *)
(* Stop hit — long position crosses stop during correction              *)
(* ------------------------------------------------------------------ *)
(* A position in Initial state (stop at 47.875) experiences a sharp
   decline below the stop. Stop_hit fires; no further state evolution. *)

let stop_hit_long _ =
  let initial_state =
    compute_initial_stop ~config:cfg ~side:Long ~reference_level:50.0
  in
  assert_that (get_stop_level initial_state) (float_equal 47.875);
  let bar = make_bar ~low_price:45.0 ~high_price:52.0 49.0 in
  let _new_state, event =
    update ~config:cfg ~side:Long ~state:initial_state ~current_bar:bar
      ~ma_value:50.0 ~ma_direction:Rising ~stage:stage2
  in
  assert_that event
    (matching ~msg:"Stop_hit: trigger=45.0, stop=47.875"
       (function
         | Stop_hit { trigger_price; stop_level } ->
             Some (trigger_price, stop_level)
         | _ -> None)
       (pair (float_equal 45.0) (float_equal 47.875)))

(* ------------------------------------------------------------------ *)
(* Short side — Stage 4 short, stop lowered through 2 cycles            *)
(* ------------------------------------------------------------------ *)
(* A short position in Stage 4 (price declining). For a short the stop
   is above price and is lowered (improved) after each cycle.
   - cycle 1 at c=88: counter-rally high=97 on bar 1, (97-95)/95=2.1%
     wait: actually (108-95)/95=13.7%, close=88 ≤ trend=95 → fires
   - cycle 2 at c=78: (90-80)/80=12.5%, close=78 ≤ trend=80 → fires *)

let short_stage4_stop_lowered _ =
  let initial_state =
    Trailing
      {
        stop_level = 115.0;
        last_correction_extreme = 108.0;
        last_trend_extreme = 108.0;
        ma_at_last_adjustment = 110.0;
        correction_count = 0;
      }
  in
  let steps =
    [
      (95.0, 92.0, 97.0, 108.0, Declining, stage4);
      (* cycle 1: (108-95)/95=13.7% counter-rally, close 88 ≤ trend 95 *)
      (88.0, 85.0, 90.0, 105.0, Declining, stage4);
      (80.0, 78.0, 82.0, 102.0, Declining, stage4);
      (85.0, 82.0, 88.0, 101.0, Declining, stage4);
      (87.0, 84.0, 89.0, 100.0, Declining, stage4);
      (* cycle 2: (90-80)/80=12.5% counter-rally, close 78 ≤ trend 80 *)
      (78.0, 75.0, 79.0, 98.0, Declining, stage4);
    ]
  in
  let final_state, last_event = run_sequence initial_state Short steps in
  (* After the fix, cycle 1 resets corr to close=88 (not bar high=90).
     Cycle 2's corr tracks up to 89 (bar5 high=89 > 88), so stop = 89*1.01≈90.125. *)
  assert_that last_event
    (matching ~msg:"cycle 2: stop lowered to 90.125"
       (function Stop_raised { new_level; _ } -> Some new_level | _ -> None)
       (float_equal 90.125));
  assert_that final_state
    (matching ~msg:"Trailing: stop=90.125, count=2"
       (function
         | Trailing { stop_level; correction_count; _ } ->
             Some (stop_level, correction_count)
         | _ -> None)
       (pair (float_equal 90.125) (equal_to 2)))

(* ------------------------------------------------------------------ *)
(* Full lifecycle long — Initial → Trailing → Tightened → Stop_hit      *)
(* ------------------------------------------------------------------ *)
(* Complete long position lifecycle:
   1. Entry: Initial stop at 49.92 (= 52 × 0.96)
   2. First advance bar transitions to Trailing (stop unchanged)
   3. Four-bar sequence: 2 correction cycles raise stop 49.92→52.375→59.4
   4. Flat MA + Stage 3 → Tightened at 69.3 (corr reset to close=70 by fix)
   5. Price drops through tightened stop → Stop_hit: trigger=67.3, stop=69.3 *)

let full_lifecycle_long _ =
  let state0 =
    compute_initial_stop ~config:cfg ~side:Long ~reference_level:52.0
  in
  assert_that state0
    (matching ~msg:"Initial state"
       (function Initial _ -> Some () | _ -> None)
       (equal_to ()));
  assert_that (get_stop_level state0) (float_equal 49.92);
  let bar_advance = make_bar ~low_price:53.0 ~high_price:58.0 56.0 in
  let state1, _ =
    update ~config:cfg ~side:Long ~state:state0 ~current_bar:bar_advance
      ~ma_value:51.0 ~ma_direction:Rising
      ~stage:(Stage2 { weeks_advancing = 1; late = false })
  in
  assert_that state1
    (matching ~msg:"Trailing after first advance bar"
       (function Trailing _ -> Some () | _ -> None)
       (equal_to ()));
  let steps_to_raise =
    [
      (62.0, 59.0, 64.0, 53.0, Rising, stage2);
      (68.0, 65.0, 70.0, 55.0, Rising, stage2);
      (63.0, 60.0, 65.0, 56.0, Rising, stage2);
      (70.0, 67.0, 72.0, 57.0, Rising, stage2);
    ]
  in
  let state2, _ = run_sequence state1 Long steps_to_raise in
  assert_that state2
    (matching ~msg:"Trailing: stop=59.4, count=2 after raise steps"
       (function
         | Trailing { stop_level; correction_count; _ } ->
             Some (stop_level, correction_count)
         | _ -> None)
       (pair (float_equal 59.4) (equal_to 2)));
  let bar_top = make_bar ~low_price:68.0 ~high_price:72.0 70.0 in
  let state3, event3 =
    update ~config:cfg ~side:Long ~state:state2 ~current_bar:bar_top
      ~ma_value:58.0 ~ma_direction:Flat ~stage:stage3
  in
  assert_that event3
    (matching ~msg:"Entered_tightening on flat MA"
       (function Entered_tightening _ -> Some () | _ -> None)
       (equal_to ()));
  (* After the fix, cycle 2 resets corr to close=70 (not bar low=67).
     Tightened stop = 70 * 0.99 = 69.3. *)
  assert_that (get_stop_level state3) (float_equal 69.3);
  let tightened_stop = get_stop_level state3 in
  let bar_exit =
    make_bar ~low_price:(tightened_stop -. 2.0) ~high_price:68.0 66.0
  in
  let _state4, event4 =
    update ~config:cfg ~side:Long ~state:state3 ~current_bar:bar_exit
      ~ma_value:57.0 ~ma_direction:Flat ~stage:stage3
  in
  assert_that event4
    (matching ~msg:"Stop_hit: trigger=67.3, stop=69.3"
       (function
         | Stop_hit { trigger_price; stop_level } ->
             Some (trigger_price, stop_level)
         | _ -> None)
       (pair (float_equal 67.3) (float_equal 69.3)))

(* ------------------------------------------------------------------ *)
(* Full lifecycle short — Initial → Trailing → Tightened → Stop_hit     *)
(* ------------------------------------------------------------------ *)
(* Complete short position lifecycle:
   1. Entry: Initial stop at 52.125 (= 50 × 1.04, nudged up to 52.125)
   2. First decline bar transitions to Trailing (stop unchanged)
   3. Five-bar sequence: 2 correction cycles lower stop 52.125→48.625→43.625
   4. Stage 1 recovery signal → Tightened at 35.35 (corr reset to close=35 by fix)
   5. Price rallies through tightened stop → Stop_hit: trigger=37.35, stop=35.35 *)

let full_lifecycle_short _ =
  let state0 =
    compute_initial_stop ~config:cfg ~side:Short ~reference_level:50.0
  in
  assert_that state0
    (matching ~msg:"Initial state"
       (function Initial _ -> Some () | _ -> None)
       (equal_to ()));
  assert_that (get_stop_level state0) (float_equal 52.125);
  let bar_decline = make_bar ~low_price:44.0 ~high_price:48.0 46.0 in
  let state1, _ =
    update ~config:cfg ~side:Short ~state:state0 ~current_bar:bar_decline
      ~ma_value:51.0 ~ma_direction:Declining ~stage:stage4
  in
  assert_that state1
    (matching ~msg:"Trailing after first decline bar"
       (function Trailing _ -> Some () | _ -> None)
       (equal_to ()));
  let steps =
    [
      (42.0, 40.0, 44.0, 50.0, Declining, stage4);
      (* cycle 1: (48-42)/42=14.3% counter-rally, close=38 ≤ trend=42 *)
      (38.0, 36.0, 40.0, 49.0, Declining, stage4);
      (41.0, 39.0, 43.0, 48.0, Declining, stage4);
      (* cycle 2: (43-38)/38=13.2% counter-rally, close=35 ≤ trend=38 *)
      (35.0, 33.0, 37.0, 47.0, Declining, stage4);
      (* Stage 1 recovery signal — tightening fires *)
      (36.0, 34.0, 38.0, 46.0, Rising, Stage1 { weeks_in_base = 3 });
    ]
  in
  let state2, _ = run_sequence state1 Short steps in
  (* After the fix, cycle 2 resets corr to close=35 (not bar high=37).
     Tightened stop = 35 * 1.01 = 35.35. *)
  assert_that (get_stop_level state2) (float_equal 35.35);
  assert_that state2
    (matching ~msg:"Tightened at 35.35"
       (function Tightened _ -> Some () | _ -> None)
       (equal_to ()));
  let tightened_stop = get_stop_level state2 in
  let bar_exit =
    make_bar ~low_price:30.0 ~high_price:(tightened_stop +. 2.0) 32.0
  in
  let _state3, event3 =
    update ~config:cfg ~side:Short ~state:state2 ~current_bar:bar_exit
      ~ma_value:46.0 ~ma_direction:Rising
      ~stage:(Stage1 { weeks_in_base = 4 })
  in
  assert_that event3
    (matching ~msg:"Stop_hit: trigger=37.35, stop=35.35"
       (function
         | Stop_hit { trigger_price; stop_level } ->
             Some (trigger_price, stop_level)
         | _ -> None)
       (pair (float_equal 37.35) (float_equal 35.35)))

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let () =
  run_test_tt_main
    ("weinstein_stops_regression"
    >::: [
           "stage2 trailing stop raised — phase A (2 cycles, stop→102.96)"
           >:: stage2_trailing_stop_raised_phase_a;
           "stage2 trailing stop raised — phase B (1 more cycle, stop→120.78)"
           >:: stage2_trailing_stop_raised_phase_b;
           "stage3 tightening on flat MA" >:: stage3_tightening;
           "stop hit on long position" >:: stop_hit_long;
           "short stage4 stop lowered through 2 cycles"
           >:: short_stage4_stop_lowered;
           "full lifecycle long (initial→trailing→tightened→stop_hit)"
           >:: full_lifecycle_long;
           "full lifecycle short (initial→trailing→tightened→stop_hit)"
           >:: full_lifecycle_short;
         ])
