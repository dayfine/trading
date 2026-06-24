open OUnit2
open Core
open Matchers
open Types

let cfg = Decline_character.default_config

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

(* An "A-D Line" indicator reading with the given signal. *)
let ad_line signal : Macro.indicator_reading =
  { name = "A-D Line"; signal; weight = 2.0; detail = "test" }

(* A stage result carrying just the fields the classifier reads. *)
let stage_result ~ma_value ~ma_direction : Stage.result =
  {
    stage = Weinstein_types.Stage4 { weeks_declining = 1 };
    ma_value;
    ma_direction;
    ma_slope_pct = 0.0;
    transition = None;
    above_ma_count = 0;
  }

(* A macro result with the given index stage and A-D Line reading. *)
let macro_result ~ma_value ~ma_direction ~ad_signal : Macro.result =
  {
    index_stage = stage_result ~ma_value ~ma_direction;
    indicators = [ ad_line ad_signal ];
    trend = Weinstein_types.Bearish;
    confidence = 0.2;
    regime_changed = false;
    rationale = [];
  }

(* ------------------------------------------------------------------ *)
(* Tests                                                               *)
(* ------------------------------------------------------------------ *)

(* A sharp V-crash: index plunges steeply over the last 4 weeks below a falling
   MA, A-D line collapses WITH the index (Neutral/Bearish-but-deep, no lead). *)
let test_fast_v _ =
  (* 60 flat weeks at 100, then a steep 4-week plunge to ~75 (~25% drop). *)
  let prices = List.init 56 ~f:(fun _ -> 100.0) @ [ 100.0; 92.0; 84.0; 75.0 ] in
  let index_bars = weekly_bars prices in
  (* MA above the crashed close, declining; A-D Bearish but index already
     down >10% from its high, so NOT leading. *)
  let macro =
    macro_result ~ma_value:98.0 ~ma_direction:Weinstein_types.Declining
      ~ad_signal:`Bearish
  in
  assert_that
    (Decline_character.classify ~config:cfg ~macro ~index_bars)
    (equal_to Decline_character.Fast_v)

(* A slow grind: shallow decline, many weeks below a falling MA, A-D diverged
   (leading) while the index is still close to its high. *)
let test_slow_grind _ =
  (* Long shallow drift down: 100 down to ~96 over 20 weeks (each week below
     the MA), only a ~1% drop over any 4-week window. *)
  let prices = List.init 20 ~f:(fun i -> 100.0 -. (Float.of_int i *. 0.2)) in
  let index_bars = weekly_bars prices in
  let macro =
    macro_result ~ma_value:101.0 ~ma_direction:Weinstein_types.Declining
      ~ad_signal:`Bearish
  in
  assert_that
    (Decline_character.classify ~config:cfg ~macro ~index_bars)
    (equal_to Decline_character.Slow_grind)

(* A rising-MA / near-high tape: not declining at all. *)
let test_not_declining_rising_ma _ =
  let prices = List.init 30 ~f:(fun i -> 100.0 +. (Float.of_int i *. 1.0)) in
  let index_bars = weekly_bars prices in
  let macro =
    macro_result ~ma_value:110.0 ~ma_direction:Weinstein_types.Rising
      ~ad_signal:`Bullish
  in
  assert_that
    (Decline_character.classify ~config:cfg ~macro ~index_bars)
    (equal_to Decline_character.Not_declining)

(* Close above a declining MA is also Not_declining (no decline in progress). *)
let test_not_declining_above_ma _ =
  let prices = List.init 30 ~f:(fun _ -> 120.0) in
  let index_bars = weekly_bars prices in
  let macro =
    macro_result ~ma_value:100.0 ~ma_direction:Weinstein_types.Declining
      ~ad_signal:`Neutral
  in
  assert_that
    (Decline_character.classify ~config:cfg ~macro ~index_bars)
    (equal_to Decline_character.Not_declining)

(* Edge: empty bars never crash and yield Not_declining. *)
let test_empty_bars _ =
  let macro =
    macro_result ~ma_value:100.0 ~ma_direction:Weinstein_types.Declining
      ~ad_signal:`Bearish
  in
  assert_that
    (Decline_character.classify ~config:cfg ~macro ~index_bars:[])
    (equal_to Decline_character.Not_declining)

(* Edge: shallow decline below a falling MA but too few weeks below it and no
   A-D lead → ambiguous → Not_declining (neither grind nor crash). *)
let test_ambiguous_shallow_dip _ =
  (* Just dipped below the MA for 2 weeks, shallow, no A-D lead. *)
  let prices = List.init 10 ~f:(fun _ -> 100.0) @ [ 99.0; 98.5 ] in
  let index_bars = weekly_bars prices in
  let macro =
    macro_result ~ma_value:100.0 ~ma_direction:Weinstein_types.Declining
      ~ad_signal:`Neutral
  in
  assert_that
    (Decline_character.classify ~config:cfg ~macro ~index_bars)
    (equal_to Decline_character.Not_declining)

(* ------------------------------------------------------------------ *)
(* fast_v_ignores_ma_filter — arming-speed dial                        *)
(* ------------------------------------------------------------------ *)

(* Config with the fast-V arming-speed dial enabled. *)
let cfg_arm_on_rate = { cfg with fast_v_ignores_ma_filter = true }

(* A steep recent plunge while the weekly MA is still RISING (the 2020 lag: the
   crash leads the MA roll-over). The close is still above the MA, so no decline
   is "in progress" by the MA test, but the 4-week drawdown is ~25%. *)
let steep_crash_with_rising_ma () =
  let prices = List.init 56 ~f:(fun _ -> 100.0) @ [ 100.0; 92.0; 84.0; 75.0 ] in
  let index_bars = weekly_bars prices in
  let macro =
    macro_result ~ma_value:60.0 ~ma_direction:Weinstein_types.Rising
      ~ad_signal:`Neutral
  in
  (index_bars, macro)

(* Flag OFF (default): a steep crash with a rising MA is still Not_declining —
   the fast-V path cannot arm until the MA rolls over. Pins backward-compat. *)
let test_arm_off_rising_ma_steep_is_not_declining _ =
  let index_bars, macro = steep_crash_with_rising_ma () in
  assert_that
    (Decline_character.classify ~config:cfg ~macro ~index_bars)
    (equal_to Decline_character.Not_declining)

(* Flag ON: the same steep-crash-with-rising-MA input now arms as Fast_v on rate
   alone (drops the falling-MA precondition for the fast-V path). *)
let test_arm_on_rising_ma_steep_is_fast_v _ =
  let index_bars, macro = steep_crash_with_rising_ma () in
  assert_that
    (Decline_character.classify ~config:cfg_arm_on_rate ~macro ~index_bars)
    (equal_to Decline_character.Fast_v)

(* Flag ON but a SHALLOW pullback with a rising MA: the rate gate still applies,
   so this stays Not_declining (a slow dip never arms the fast-V stop). *)
let test_arm_on_rising_ma_shallow_is_not_declining _ =
  (* ~2% drop over the last 4 weeks — below [fast_v_min_rate_pct] (8%). *)
  let prices = List.init 56 ~f:(fun _ -> 100.0) @ [ 100.0; 99.0; 98.5; 98.0 ] in
  let index_bars = weekly_bars prices in
  let macro =
    macro_result ~ma_value:80.0 ~ma_direction:Weinstein_types.Rising
      ~ad_signal:`Neutral
  in
  assert_that
    (Decline_character.classify ~config:cfg_arm_on_rate ~macro ~index_bars)
    (equal_to Decline_character.Not_declining)

(* Flag ON must NOT change an already-declining classification: a real
   falling-MA slow grind is still Slow_grind, and a falling-MA steep drop is
   still Fast_v (the falling-MA branch is unchanged by the dial). *)
let test_arm_on_preserves_declining_classification _ =
  let slow_prices =
    List.init 20 ~f:(fun i -> 100.0 -. (Float.of_int i *. 0.2))
  in
  let slow_bars = weekly_bars slow_prices in
  let slow_macro =
    macro_result ~ma_value:101.0 ~ma_direction:Weinstein_types.Declining
      ~ad_signal:`Bearish
  in
  let fast_prices =
    List.init 56 ~f:(fun _ -> 100.0) @ [ 100.0; 92.0; 84.0; 75.0 ]
  in
  let fast_bars = weekly_bars fast_prices in
  let fast_macro =
    macro_result ~ma_value:98.0 ~ma_direction:Weinstein_types.Declining
      ~ad_signal:`Bearish
  in
  assert_that
    [
      Decline_character.classify ~config:cfg_arm_on_rate ~macro:slow_macro
        ~index_bars:slow_bars;
      Decline_character.classify ~config:cfg_arm_on_rate ~macro:fast_macro
        ~index_bars:fast_bars;
    ]
    (elements_are
       [
         equal_to Decline_character.Slow_grind;
         equal_to Decline_character.Fast_v;
       ])

(* ------------------------------------------------------------------ *)
(* fast_v_min_rate_pct — arming rate threshold (whipsaw-suppression)   *)
(* ------------------------------------------------------------------ *)

(* A MODERATE 4-week drawdown of ~10% below a falling MA, A-D Neutral (not
   leading). At the default threshold (8%) the 10% drop classifies as Fast_v;
   raising the threshold to 16% requires a steeper drop, so the same input is
   Not_declining. Both share this fixture. *)
let moderate_drawdown_below_falling_ma () =
  let prices = List.init 56 ~f:(fun _ -> 100.0) @ [ 100.0; 97.0; 94.0; 90.0 ] in
  let index_bars = weekly_bars prices in
  let macro =
    macro_result ~ma_value:98.0 ~ma_direction:Weinstein_types.Declining
      ~ad_signal:`Neutral
  in
  (index_bars, macro)

(* Default config (threshold 8%): a ~10% drawdown arms Fast_v. Also pins that
   the default reproduces today's classification on the steep-drop fixture. *)
let test_default_rate_threshold_arms_fast_v _ =
  let index_bars, macro = moderate_drawdown_below_falling_ma () in
  assert_that
    [
      Decline_character.classify ~config:cfg ~macro ~index_bars;
      (let steep_bars, steep_macro = steep_crash_with_rising_ma () in
       (* default 0.08 == today's classification on the steep fixture *)
       Decline_character.classify ~config:cfg_arm_on_rate ~macro:steep_macro
         ~index_bars:steep_bars);
    ]
    (elements_are
       [ equal_to Decline_character.Fast_v; equal_to Decline_character.Fast_v ])

(* Raising fast_v_min_rate_pct to 16%: the same ~10% drawdown no longer meets
   the (steeper) rate bar, so it is Not_declining — the whipsaw-suppression
   behaviour (a moderate dip that would have armed Fast_v at 8% no longer does). *)
let test_higher_rate_threshold_suppresses_fast_v _ =
  let index_bars, macro = moderate_drawdown_below_falling_ma () in
  let cfg_high_rate = { cfg with fast_v_min_rate_pct = 0.16 } in
  assert_that
    (Decline_character.classify ~config:cfg_high_rate ~macro ~index_bars)
    (equal_to Decline_character.Not_declining)

let suite =
  "decline_character"
  >::: [
         "fast_v" >:: test_fast_v;
         "slow_grind" >:: test_slow_grind;
         "not_declining_rising_ma" >:: test_not_declining_rising_ma;
         "not_declining_above_ma" >:: test_not_declining_above_ma;
         "empty_bars" >:: test_empty_bars;
         "ambiguous_shallow_dip" >:: test_ambiguous_shallow_dip;
         "arm_off_rising_ma_steep_is_not_declining"
         >:: test_arm_off_rising_ma_steep_is_not_declining;
         "arm_on_rising_ma_steep_is_fast_v"
         >:: test_arm_on_rising_ma_steep_is_fast_v;
         "arm_on_rising_ma_shallow_is_not_declining"
         >:: test_arm_on_rising_ma_shallow_is_not_declining;
         "arm_on_preserves_declining_classification"
         >:: test_arm_on_preserves_declining_classification;
         "default_rate_threshold_arms_fast_v"
         >:: test_default_rate_threshold_arms_fast_v;
         "higher_rate_threshold_suppresses_fast_v"
         >:: test_higher_rate_threshold_suppresses_fast_v;
       ]

let () = run_test_tt_main suite
