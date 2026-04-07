open OUnit2
open Core
open Trading_base.Types
open Weinstein_types
open Weinstein_stops
open Matchers

(* ---- Test helpers ---- *)

let make_bar ?(open_price = 100.0) ?(high_price = 105.0) ?(low_price = 95.0)
    ?(close_price = 102.0) ?(volume = 1000000) ?(adjusted_close = 102.0) () =
  Types.Daily_price.
    {
      date = Date.of_string "2024-01-01";
      open_price;
      high_price;
      low_price;
      close_price;
      volume;
      adjusted_close;
    }

let cfg = default_config
let stage2 = Stage2 { weeks_advancing = 4; late = false }
let stage4 = Stage4 { weeks_declining = 2 }

(* ---- compute_initial_stop tests ---- *)
(* Long: raw_stop = reference_level * (1 - min_correction_pct/2) = reference_level * 0.96
   Short: raw_stop = reference_level * (1 + min_correction_pct/2) = reference_level * 1.04
   A round-number nudge is applied after: stop placed just outside the nearest half-dollar. *)

let test_compute_initial_stop_long _ =
  (* Long: reference_level=50.0 → raw_stop=48.0 → nudged to 47.875 (below 48.0) *)
  assert_that
    (compute_initial_stop ~config:cfg ~side:Long ~reference_level:50.0)
    (equal_to
       (Initial { stop_level = 47.875; reference_level = 50.0 } : stop_state))

let test_compute_initial_stop_nudge_at_whole_number _ =
  (* Long: reference_level=52.1 → raw_stop=50.016 — just above 50.0 → nudged to 49.875 *)
  assert_that
    (get_stop_level
       (compute_initial_stop ~config:cfg ~side:Long ~reference_level:52.1))
    (float_equal 49.875)

let test_compute_initial_stop_nudge_at_half_dollar _ =
  (* Long: reference_level=52.65 → raw_stop=50.544 — just above 50.5 → nudged to 50.375 *)
  assert_that
    (get_stop_level
       (compute_initial_stop ~config:cfg ~side:Long ~reference_level:52.65))
    (float_equal 50.375)

let test_compute_initial_stop_no_nudge _ =
  (* Long: reference_level=52.4 → raw_stop≈50.304 — not within 0.125 of any half-dollar → no nudge *)
  let stop =
    get_stop_level
      (compute_initial_stop ~config:cfg ~side:Long ~reference_level:52.4)
  in
  assert_that stop
    (all_of [ gt (module Float_ord) 50.25; lt (module Float_ord) 50.35 ])

let test_compute_initial_stop_short _ =
  (* Short: reference_level=50.0 → raw_stop=52.0 → nudged to 52.125 (above 52.0) *)
  assert_that
    (compute_initial_stop ~config:cfg ~side:Short ~reference_level:50.0)
    (equal_to
       (Initial { stop_level = 52.125; reference_level = 50.0 } : stop_state))

(* ---- check_stop_hit tests ---- *)

let test_check_stop_hit_long _ =
  let state = Initial { stop_level = 45.0; reference_level = 47.0 } in
  assert_that
    (check_stop_hit ~state ~side:Long ~bar:(make_bar ~low_price:44.0 ()))
    (equal_to true);
  assert_that
    (check_stop_hit ~state ~side:Long ~bar:(make_bar ~low_price:45.0 ()))
    (equal_to true);
  assert_that
    (check_stop_hit ~state ~side:Long ~bar:(make_bar ~low_price:46.0 ()))
    (equal_to false)

let test_check_stop_hit_short _ =
  let state = Initial { stop_level = 55.0; reference_level = 53.0 } in
  assert_that
    (check_stop_hit ~state ~side:Short ~bar:(make_bar ~high_price:56.0 ()))
    (equal_to true);
  assert_that
    (check_stop_hit ~state ~side:Short ~bar:(make_bar ~high_price:55.0 ()))
    (equal_to true);
  assert_that
    (check_stop_hit ~state ~side:Short ~bar:(make_bar ~high_price:54.0 ()))
    (equal_to false)

(* ---- get_stop_level tests ---- *)

let test_get_stop_level_initial _ =
  assert_that
    (get_stop_level (Initial { stop_level = 45.0; reference_level = 47.0 }))
    (float_equal 45.0)

let test_get_stop_level_trailing _ =
  let state =
    Trailing
      {
        stop_level = 48.0;
        last_correction_extreme = 46.0;
        last_trend_extreme = 55.0;
        ma_at_last_adjustment = 50.0;
        correction_count = 1;
      }
  in
  assert_that (get_stop_level state) (float_equal 48.0)

let test_get_stop_level_tightened _ =
  let state =
    Tightened
      { stop_level = 52.0; last_correction_extreme = 51.0; reason = "test" }
  in
  assert_that (get_stop_level state) (float_equal 52.0)

(* ---- show/eq derivations ---- *)

let test_deriving _ =
  let state = Initial { stop_level = 45.0; reference_level = 47.0 } in
  let _ = show_stop_state state in
  let event = Stop_hit { trigger_price = 44.0; stop_level = 45.0 } in
  let _ = show_stop_event event in
  let _ = show_config default_config in
  assert_that state (equal_to (state : stop_state));
  assert_that event (equal_to (event : stop_event))

(* ---- update: stop hit detection ---- *)

let test_update_stop_hit_initial _ =
  let state = Initial { stop_level = 45.0; reference_level = 47.0 } in
  let bar = make_bar ~low_price:44.0 ~close_price:44.5 () in
  let new_state, event =
    update ~config:cfg ~side:Long ~state ~current_bar:bar ~ma_value:48.0
      ~ma_direction:Rising ~stage:stage2
  in
  assert_that event
    (equal_to
       (Stop_hit { trigger_price = 44.0; stop_level = 45.0 } : stop_event));
  (* State is preserved unchanged — the caller decides whether to close the position. *)
  assert_that new_state (equal_to (state : stop_state))

let test_update_stop_hit_trailing _ =
  let state =
    Trailing
      {
        stop_level = 48.0;
        last_correction_extreme = 46.0;
        last_trend_extreme = 55.0;
        ma_at_last_adjustment = 50.0;
        correction_count = 1;
      }
  in
  let bar = make_bar ~low_price:47.0 ~close_price:47.5 () in
  let new_state, event =
    update ~config:cfg ~side:Long ~state ~current_bar:bar ~ma_value:50.0
      ~ma_direction:Rising ~stage:stage2
  in
  assert_that event
    (equal_to
       (Stop_hit { trigger_price = 47.0; stop_level = 48.0 } : stop_event));
  assert_that new_state (equal_to (state : stop_state))

let test_update_stop_hit_short _ =
  let state =
    Trailing
      {
        stop_level = 55.0;
        last_correction_extreme = 57.0;
        last_trend_extreme = 45.0;
        ma_at_last_adjustment = 50.0;
        correction_count = 1;
      }
  in
  let bar = make_bar ~high_price:56.0 ~close_price:55.5 () in
  let _new_state, event =
    update ~config:cfg ~side:Short ~state ~current_bar:bar ~ma_value:50.0
      ~ma_direction:Declining ~stage:stage4
  in
  assert_that event
    (equal_to
       (Stop_hit { trigger_price = 56.0; stop_level = 55.0 } : stop_event))

(* ---- update: Initial → Trailing transition ---- *)

let test_update_initial_to_trailing _ =
  let state = Initial { stop_level = 45.0; reference_level = 47.0 } in
  let bar = make_bar ~low_price:49.0 ~close_price:53.0 () in
  let new_state, event =
    update ~config:cfg ~side:Long ~state ~current_bar:bar ~ma_value:48.0
      ~ma_direction:Rising ~stage:stage2
  in
  assert_that event (equal_to (No_change : stop_event));
  assert_that new_state
    (matching ~msg:"Expected Trailing state after Initial update"
       (function
         | Trailing { stop_level; correction_count; _ } ->
             Some (stop_level, correction_count)
         | _ -> None)
       (pair (float_equal 45.0) (equal_to 0)))

(* ---- update: tightening trigger ---- *)

let test_update_tighten_on_stage3 _ =
  let state =
    Trailing
      {
        stop_level = 45.0;
        last_correction_extreme = 47.0;
        last_trend_extreme = 55.0;
        ma_at_last_adjustment = 50.0;
        correction_count = 1;
      }
  in
  let bar = make_bar ~low_price:52.0 ~close_price:53.0 () in
  let new_state, event =
    update ~config:cfg ~side:Long ~state ~current_bar:bar ~ma_value:52.0
      ~ma_direction:Flat
      ~stage:(Stage3 { weeks_topping = 2 })
  in
  assert_that event
    (matching ~msg:"Expected Entered_tightening event"
       (function
         | Entered_tightening { reason } -> Some (String.length reason)
         | _ -> None)
       (gt (module Int_ord) 0));
  assert_that new_state
    (matching ~msg:"Expected Tightened state"
       (function Tightened { stop_level; _ } -> Some stop_level | _ -> None)
       (ge (module Float_ord) 45.0))

let test_update_tighten_on_flat_ma _ =
  let state =
    Trailing
      {
        stop_level = 45.0;
        last_correction_extreme = 47.0;
        last_trend_extreme = 55.0;
        ma_at_last_adjustment = 50.0;
        correction_count = 1;
      }
  in
  let bar = make_bar ~low_price:52.0 ~close_price:53.0 () in
  let new_state, event =
    update ~config:cfg ~side:Long ~state ~current_bar:bar ~ma_value:52.0
      ~ma_direction:Flat ~stage:stage2
  in
  assert_that event
    (matching ~msg:"Expected Entered_tightening on flat MA in Stage 2"
       (function Entered_tightening _ -> Some () | _ -> None)
       (equal_to ()));
  assert_that new_state
    (matching ~msg:"Expected Tightened state"
       (function Tightened _ -> Some () | _ -> None)
       (equal_to ()))

let test_update_no_tighten_when_disabled _ =
  let cfg_no_tighten = { cfg with tighten_on_flat_ma = false } in
  let state =
    Trailing
      {
        stop_level = 45.0;
        last_correction_extreme = 47.0;
        last_trend_extreme = 55.0;
        ma_at_last_adjustment = 50.0;
        correction_count = 0;
      }
  in
  let bar = make_bar ~low_price:52.0 ~close_price:53.0 () in
  let new_state, event =
    update ~config:cfg_no_tighten ~side:Long ~state ~current_bar:bar
      ~ma_value:52.0 ~ma_direction:Flat ~stage:stage2
  in
  assert_that event (equal_to (No_change : stop_event));
  assert_that new_state
    (matching ~msg:"Expected Trailing state when tightening disabled"
       (function Trailing _ -> Some () | _ -> None)
       (equal_to ()))

let test_update_tighten_short_on_stage2 _ =
  (* Short: tighten when stock enters Stage 2 (advancing, bad for short) *)
  let state =
    Trailing
      {
        stop_level = 55.0;
        last_correction_extreme = 57.0;
        last_trend_extreme = 45.0;
        ma_at_last_adjustment = 50.0;
        correction_count = 1;
      }
  in
  let bar = make_bar ~high_price:48.0 ~close_price:47.0 () in
  let new_state, event =
    update ~config:cfg ~side:Short ~state ~current_bar:bar ~ma_value:48.0
      ~ma_direction:Rising ~stage:stage2
  in
  assert_that event
    (matching ~msg:"Expected Entered_tightening for short in Stage 2"
       (function Entered_tightening _ -> Some () | _ -> None)
       (equal_to ()));
  assert_that new_state
    (matching ~msg:"Expected Tightened state"
       (function Tightened _ -> Some () | _ -> None)
       (equal_to ()))

(* ---- update: stop ratchet after correction cycle ---- *)

let test_update_stop_raised_after_cycle _ =
  (* Scenario: price had a correction (pullback >= 8%), now recovered *)
  let peak = 55.0 in
  let correction_low = 49.0 in
  (* pullback = (55 - 49)/55 = 10.9% > 8% ✓ *)
  let state =
    Trailing
      {
        stop_level = 45.0;
        last_correction_extreme = correction_low;
        last_trend_extreme = peak;
        ma_at_last_adjustment = 50.0;
        correction_count = 1;
      }
  in
  (* Current bar: close above the previous rally peak — cycle complete *)
  let bar = make_bar ~low_price:53.0 ~close_price:56.0 () in
  let new_state, event =
    update ~config:cfg ~side:Long ~state ~current_bar:bar ~ma_value:51.0
      ~ma_direction:Rising ~stage:stage2
  in
  assert_that event
    (matching ~msg:"Expected Stop_raised event after correction cycle"
       (function
         | Stop_raised { old_level; new_level; _ } -> Some (old_level, new_level)
         | _ -> None)
       (pair (float_equal 45.0)
          (all_of [ gt (module Float_ord) 45.0; gt (module Float_ord) 47.0 ])));
  assert_that new_state
    (matching ~msg:"Expected Trailing state"
       (function
         | Trailing { stop_level; correction_count; _ } ->
             Some (stop_level, correction_count)
         | _ -> None)
       (pair (gt (module Float_ord) 45.0) (equal_to 2)))

let test_update_no_ratchet_insufficient_correction _ =
  (* Correction is only 4.5%, below min_correction_pct of 8% — no ratchet *)
  let peak = 55.0 in
  let correction_low = 52.5 in
  (* pullback = (55 - 52.5)/55 = 4.5% < 8% *)
  let state =
    Trailing
      {
        stop_level = 45.0;
        last_correction_extreme = correction_low;
        last_trend_extreme = peak;
        ma_at_last_adjustment = 50.0;
        correction_count = 0;
      }
  in
  let bar = make_bar ~low_price:53.0 ~close_price:56.0 () in
  let new_state, event =
    update ~config:cfg ~side:Long ~state ~current_bar:bar ~ma_value:51.0
      ~ma_direction:Rising ~stage:stage2
  in
  assert_that event (equal_to (No_change : stop_event));
  assert_that new_state
    (matching ~msg:"Expected Trailing state with unchanged stop level"
       (function Trailing { stop_level; _ } -> Some stop_level | _ -> None)
       (float_equal 45.0))

(* ---- update: tightened state ---- *)

let test_update_tightened_stop_hit _ =
  let state =
    Tightened
      { stop_level = 50.0; last_correction_extreme = 51.0; reason = "Stage 3" }
  in
  let bar = make_bar ~low_price:49.5 ~close_price:49.8 () in
  let _new_state, event =
    update ~config:cfg ~side:Long ~state ~current_bar:bar ~ma_value:51.0
      ~ma_direction:Flat
      ~stage:(Stage3 { weeks_topping = 2 })
  in
  assert_that event
    (matching ~msg:"Expected Stop_hit"
       (function Stop_hit { stop_level; _ } -> Some stop_level | _ -> None)
       (float_equal 50.0))

(* ---- stop never moved against the position ---- *)

let test_stop_never_lowered_for_long _ =
  (* Correction low is below current stop level — candidate stop would be lower *)
  let state =
    Trailing
      {
        stop_level = 50.0;
        last_correction_extreme = 48.0;
        (* 48.0 * (1 - trailing_stop_buffer_pct=1%) ≈ 47.52 < current stop 50.0 *)
        last_trend_extreme = 55.0;
        ma_at_last_adjustment = 50.0;
        correction_count = 1;
      }
  in
  let bar = make_bar ~low_price:53.0 ~close_price:56.0 () in
  let new_state, event =
    update ~config:cfg ~side:Long ~state ~current_bar:bar ~ma_value:51.0
      ~ma_direction:Rising ~stage:stage2
  in
  assert_that event (equal_to (No_change : stop_event));
  assert_that (get_stop_level new_state) (float_equal 50.0)

let test_stop_never_raised_for_short _ =
  (* Correction high is above current stop level — candidate stop would be higher *)
  let state =
    Trailing
      {
        stop_level = 55.0;
        last_correction_extreme = 57.0;
        (* 57.0 * 1.01 ≈ 57.57 > current stop of 55.0, but cycle hasn't completed *)
        last_trend_extreme = 45.0;
        ma_at_last_adjustment = 50.0;
        correction_count = 1;
      }
  in
  (* Close above last_trend_extreme (45.0) — but this is a SHORT, so close above
     trough means recovery hasn't occurred for a short (short recovery = close below trough) *)
  let bar = make_bar ~high_price:51.0 ~close_price:50.0 () in
  let _new_state, event =
    update ~config:cfg ~side:Short ~state ~current_bar:bar ~ma_value:50.0
      ~ma_direction:Declining ~stage:stage4
  in
  (* close=50.0 is NOT <= last_trend_extreme=45.0, so no cycle completion *)
  assert_that event (equal_to (No_change : stop_event))

(* ---- no phantom cycle on continuous advance after reset ---- *)

let test_no_phantom_cycle_on_continuous_advance _ =
  (* After a cycle completes at close=100, the state resets with both
     last_correction_extreme and last_trend_extreme = 100.0.
     A bar that advances to close=110 (low=107) should NOT trigger another
     cycle: the "correction" depth is (110-100)/110=9%, but the low=107 never
     actually fell below last_trend_extreme=100, so no pullback occurred.
     Before the fix, _raised_trailing seeded last_correction_extreme with the
     bar's low (e.g. 97), which made a continuous advance look like a pullback. *)
  let state =
    Trailing
      {
        stop_level = 85.0;
        last_correction_extreme = 100.0;
        (* Both equal after fix: next cycle starts fresh *)
        last_trend_extreme = 100.0;
        ma_at_last_adjustment = 90.0;
        correction_count = 1;
      }
  in
  let bar = make_bar ~low_price:107.0 ~close_price:110.0 () in
  let new_state, event =
    update ~config:cfg ~side:Long ~state ~current_bar:bar ~ma_value:92.0
      ~ma_direction:Rising ~stage:stage2
  in
  (* No phantom cycle — close=110 advances trend_extreme but no correction occurred *)
  assert_that event (equal_to (No_change : stop_event));
  assert_that new_state
    (matching ~msg:"Expected Trailing with count=1 (no new cycle)"
       (function
         | Trailing { correction_count; _ } -> Some correction_count | _ -> None)
       (equal_to 1))

let suite =
  "weinstein_stops"
  >::: [
         "initial_stop_long" >:: test_compute_initial_stop_long;
         "initial_stop_nudge_whole"
         >:: test_compute_initial_stop_nudge_at_whole_number;
         "initial_stop_nudge_half"
         >:: test_compute_initial_stop_nudge_at_half_dollar;
         "initial_stop_no_nudge" >:: test_compute_initial_stop_no_nudge;
         "initial_stop_short" >:: test_compute_initial_stop_short;
         "check_stop_hit_long" >:: test_check_stop_hit_long;
         "check_stop_hit_short" >:: test_check_stop_hit_short;
         "get_stop_level_initial" >:: test_get_stop_level_initial;
         "get_stop_level_trailing" >:: test_get_stop_level_trailing;
         "get_stop_level_tightened" >:: test_get_stop_level_tightened;
         "update_stop_hit_initial" >:: test_update_stop_hit_initial;
         "update_stop_hit_trailing" >:: test_update_stop_hit_trailing;
         "update_stop_hit_short" >:: test_update_stop_hit_short;
         "update_initial_to_trailing" >:: test_update_initial_to_trailing;
         "update_tighten_on_stage3" >:: test_update_tighten_on_stage3;
         "update_tighten_on_flat_ma" >:: test_update_tighten_on_flat_ma;
         "update_no_tighten_when_disabled"
         >:: test_update_no_tighten_when_disabled;
         "update_tighten_short_on_stage2"
         >:: test_update_tighten_short_on_stage2;
         "update_stop_raised_after_cycle"
         >:: test_update_stop_raised_after_cycle;
         "update_no_ratchet_insufficient_correction"
         >:: test_update_no_ratchet_insufficient_correction;
         "update_tightened_stop_hit" >:: test_update_tightened_stop_hit;
         "stop_never_lowered_for_long" >:: test_stop_never_lowered_for_long;
         "stop_never_raised_for_short" >:: test_stop_never_raised_for_short;
         "no_phantom_cycle_on_continuous_advance"
         >:: test_no_phantom_cycle_on_continuous_advance;
         "deriving" >:: test_deriving;
       ]

let () = run_test_tt_main suite
