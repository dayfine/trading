open OUnit2
open Core
open Matchers
open Types
module Cb = Index_circuit_breaker

let cfg = Cb.default_config

(* ------------------------------------------------------------------ *)
(* Inline fixture builders                                             *)
(* ------------------------------------------------------------------ *)

let make_bar date close =
  {
    Daily_price.date = Date.of_string date;
    open_price = close;
    high_price = close *. 1.01;
    low_price = close *. 0.99;
    close_price = close;
    adjusted_close = close;
    volume = 100_000;
    active_through = None;
  }

(* Weekly bars from a price list, 7 days apart starting 2020-01-06. *)
let weekly_bars prices =
  let base = Date.of_string "2020-01-06" in
  List.mapi prices ~f:(fun i p ->
      make_bar (Date.to_string (Date.add_days base (i * 7))) p)

(* A macro result carrying just the stage MA + A-D reading the classifier reads. *)
let macro_result ~ma_value ~ma_direction ~ad_signal : Macro.result =
  {
    index_stage =
      {
        stage = Weinstein_types.Stage4 { weeks_declining = 1 };
        ma_value;
        ma_direction;
        ma_slope_pct = 0.0;
        transition = None;
        above_ma_count = 0;
      };
    indicators =
      [ { name = "A-D Line"; signal = ad_signal; weight = 2.0; detail = "t" } ];
    trend = Weinstein_types.Bearish;
    confidence = 0.2;
    regime_changed = false;
    rationale = [];
  }

(* A tape that is not in a decline and has no breadth lead — irrelevant while
   Out_of_market (re-entry reads only the index bars). *)
let quiet_macro =
  macro_result ~ma_value:50.0 ~ma_direction:Weinstein_types.Rising
    ~ad_signal:`Neutral

(* Matcher: [Out_of_market] whose [exited_on] equals [r]. *)
let out_reason r =
  matching ~msg:"Out_of_market with reason"
    (function
      | Cb.Out_of_market { exited_on; _ } -> Some exited_on
      | Cb.In_market _ -> None)
    (equal_to r)

(* Matcher: [Out_of_market] whose [post_exit_low] equals [v]. *)
let out_low v =
  matching ~msg:"Out_of_market post_exit_low"
    (function
      | Cb.Out_of_market { post_exit_low; _ } -> Some post_exit_low
      | Cb.In_market _ -> None)
    (float_equal v)

(* ------------------------------------------------------------------ *)
(* Exit triggers                                                       *)
(* ------------------------------------------------------------------ *)

(* T1: a steep 4-week drawdown (~12%) with fast-V character (rising MA, no A-D
   lead) fires a fast-crash exit that seeds post_exit_low at the exit close. The
   drop stays above the 20% floor, so T1 — not T3 — is the trigger. *)
let test_fast_crash_exit _ =
  let index_bars =
    weekly_bars (List.init 56 ~f:(fun _ -> 100.0) @ [ 100.0; 96.0; 92.0; 88.0 ])
  in
  let macro =
    macro_result ~ma_value:70.0 ~ma_direction:Weinstein_types.Rising
      ~ad_signal:`Neutral
  in
  assert_that
    (Cb.step ~config:cfg ~state:Cb.in_market ~index_bars ~ad_macro:macro)
    (all_of
       [
         field snd (equal_to (Cb.Exit Cb.Fast_crash));
         field fst (all_of [ out_reason Cb.Fast_crash; out_low 88.0 ]);
       ])

(* T2: a shallow breadth-led grind must be sustained [grind_confirm_weeks] (3)
   consecutive steps before the slow-grind exit fires — the first two steps hold
   with a rising grind streak. *)
let test_slow_grind_exit_after_confirm _ =
  let index_bars =
    weekly_bars (List.init 20 ~f:(fun i -> 100.0 -. (Float.of_int i *. 0.2)))
  in
  let macro =
    macro_result ~ma_value:101.0 ~ma_direction:Weinstein_types.Declining
      ~ad_signal:`Bearish
  in
  let s1, a1 =
    Cb.step ~config:cfg ~state:Cb.in_market ~index_bars ~ad_macro:macro
  in
  let s2, a2 = Cb.step ~config:cfg ~state:s1 ~index_bars ~ad_macro:macro in
  let s3, a3 = Cb.step ~config:cfg ~state:s2 ~index_bars ~ad_macro:macro in
  assert_that [ a1; a2; a3 ]
    (elements_are
       [ equal_to Cb.Hold; equal_to Cb.Hold; equal_to (Cb.Exit Cb.Slow_grind) ]);
  assert_that s3 (out_reason Cb.Slow_grind)

(* T3: a slow drift whose last 4 weeks barely move (no fast-V, no confirmed
   grind) but whose close sits below 80% of the trailing-window high fires the
   absolute-floor backstop. *)
let test_floor_exit_on_trailing_window_breach _ =
  let index_bars =
    weekly_bars
      (List.init 40 ~f:(fun _ -> 100.0)
      @ [ 95.0; 90.0; 85.0; 80.0; 78.0; 77.0; 76.0; 75.5; 75.2; 75.0 ])
  in
  let macro =
    macro_result ~ma_value:60.0 ~ma_direction:Weinstein_types.Rising
      ~ad_signal:`Neutral
  in
  assert_that
    (Cb.step ~config:cfg ~state:Cb.in_market ~index_bars ~ad_macro:macro)
    (all_of
       [
         field snd (equal_to (Cb.Exit Cb.Absolute_floor));
         field fst (all_of [ out_reason Cb.Absolute_floor; out_low 75.0 ]);
       ])

(* ------------------------------------------------------------------ *)
(* Re-entry (asymmetric by exit reason)                                *)
(* ------------------------------------------------------------------ *)

(* Fast re-entry: after a fast-crash exit, a deeper dip lowers post_exit_low and
   re-entry is measured as a 5% recovery OFF THAT LOW — so a close of 87 (below
   the original 88 low) still re-enters once the low has decayed to 82. *)
let test_fast_reentry_off_post_exit_low _ =
  let s0 =
    Cb.Out_of_market
      {
        exited_on = Cb.Fast_crash;
        exit_date = Date.of_string "2020-06-01";
        post_exit_low = 88.0;
      }
  in
  let r1 =
    Cb.step ~config:cfg ~state:s0
      ~index_bars:[ make_bar "2020-06-08" 82.0 ]
      ~ad_macro:quiet_macro
  in
  assert_that r1
    (all_of [ field snd (equal_to Cb.Hold); field fst (out_low 82.0) ]);
  let r2 =
    Cb.step ~config:cfg ~state:(fst r1)
      ~index_bars:[ make_bar "2020-06-15" 87.0 ]
      ~ad_macro:quiet_macro
  in
  assert_that r2
    (all_of
       [ field snd (equal_to Cb.Re_enter); field fst (equal_to Cb.in_market) ])

(* Slow re-entry: after a grind exit, re-entry needs price above a turning
   30-week MA. A recovered V (declining then rising past the MA) re-enters; a
   still-declining tape holds. *)
let test_slow_reentry_above_turning_ma _ =
  let out_state reason =
    Cb.Out_of_market
      {
        exited_on = reason;
        exit_date = Date.of_string "2020-06-01";
        post_exit_low = 80.0;
      }
  in
  let recover_bars =
    weekly_bars
      (List.init 20 ~f:(fun i -> 100.0 -. Float.of_int i)
      @ List.init 20 ~f:(fun i -> 82.0 +. Float.of_int i))
  in
  let declining_bars =
    weekly_bars (List.init 40 ~f:(fun i -> 100.0 -. Float.of_int i))
  in
  assert_that
    (Cb.step ~config:cfg ~state:(out_state Cb.Slow_grind)
       ~index_bars:recover_bars ~ad_macro:quiet_macro)
    (all_of
       [ field snd (equal_to Cb.Re_enter); field fst (equal_to Cb.in_market) ]);
  assert_that
    (Cb.step ~config:cfg ~state:(out_state Cb.Slow_grind)
       ~index_bars:declining_bars ~ad_macro:quiet_macro)
    (field snd (equal_to Cb.Hold))

(* ------------------------------------------------------------------ *)
(* GME-lesson regressions                                              *)
(* ------------------------------------------------------------------ *)

(* Windowed peak decays: a parabolic spike to 300 then collapse to 100 fires the
   floor while the spike is still inside the trailing window, but once the spike
   scrolls out (60+ weeks later, all at 100) the floor reference decays to 100
   and the machine HOLDS instead of firing forever. A monotonic high-water mark
   would keep 0.8*300=240 as the floor and re-fire indefinitely (the GME
   pathology). *)
let test_windowed_peak_decays_no_permanent_disable _ =
  let macro =
    macro_result ~ma_value:50.0 ~ma_direction:Weinstein_types.Rising
      ~ad_signal:`Neutral
  in
  let soon_after_collapse =
    weekly_bars
      (List.init 40 ~f:(fun _ -> 100.0) @ [ 150.0; 220.0; 300.0; 100.0 ])
  in
  let long_after_collapse =
    weekly_bars
      (List.init 40 ~f:(fun _ -> 100.0)
      @ [ 150.0; 220.0; 300.0; 100.0 ]
      @ List.init 60 ~f:(fun _ -> 100.0))
  in
  let action bars =
    snd
      (Cb.step ~config:cfg ~state:Cb.in_market ~index_bars:bars ~ad_macro:macro)
  in
  assert_that
    [ action soon_after_collapse; action long_after_collapse ]
    (elements_are [ equal_to (Cb.Exit Cb.Absolute_floor); equal_to Cb.Hold ])

(* Whipsaw: drop -> recover -> drop must exit, re-enter, then be able to re-exit
   (the state machine is not permanently locked in either state). *)
let test_whipsaw_exit_reenter_reexit _ =
  let crash_bars =
    weekly_bars (List.init 56 ~f:(fun _ -> 100.0) @ [ 100.0; 96.0; 92.0; 88.0 ])
  in
  let crash_macro =
    macro_result ~ma_value:70.0 ~ma_direction:Weinstein_types.Rising
      ~ad_signal:`Neutral
  in
  let s1, a1 =
    Cb.step ~config:cfg ~state:Cb.in_market ~index_bars:crash_bars
      ~ad_macro:crash_macro
  in
  let s2, a2 =
    Cb.step ~config:cfg ~state:s1
      ~index_bars:[ make_bar "2020-07-01" 93.0 ]
      ~ad_macro:quiet_macro
  in
  let _s3, a3 =
    Cb.step ~config:cfg ~state:s2 ~index_bars:crash_bars ~ad_macro:crash_macro
  in
  assert_that [ a1; a2; a3 ]
    (elements_are
       [
         equal_to (Cb.Exit Cb.Fast_crash);
         equal_to Cb.Re_enter;
         equal_to (Cb.Exit Cb.Fast_crash);
       ])

(* Edge: empty bars are a safe no-op — the state is returned unchanged, Hold. *)
let test_empty_bars_is_noop _ =
  assert_that
    (Cb.step ~config:cfg ~state:Cb.in_market ~index_bars:[]
       ~ad_macro:quiet_macro)
    (all_of [ field fst (equal_to Cb.in_market); field snd (equal_to Cb.Hold) ])

let suite =
  "index_circuit_breaker"
  >::: [
         "fast_crash_exit" >:: test_fast_crash_exit;
         "slow_grind_exit_after_confirm" >:: test_slow_grind_exit_after_confirm;
         "floor_exit_on_trailing_window_breach"
         >:: test_floor_exit_on_trailing_window_breach;
         "fast_reentry_off_post_exit_low"
         >:: test_fast_reentry_off_post_exit_low;
         "slow_reentry_above_turning_ma" >:: test_slow_reentry_above_turning_ma;
         "windowed_peak_decays_no_permanent_disable"
         >:: test_windowed_peak_decays_no_permanent_disable;
         "whipsaw_exit_reenter_reexit" >:: test_whipsaw_exit_reenter_reexit;
         "empty_bars_is_noop" >:: test_empty_bars_is_noop;
       ]

let () = run_test_tt_main suite
