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

let suite =
  "decline_character"
  >::: [
         "fast_v" >:: test_fast_v;
         "slow_grind" >:: test_slow_grind;
         "not_declining_rising_ma" >:: test_not_declining_rising_ma;
         "not_declining_above_ma" >:: test_not_declining_above_ma;
         "empty_bars" >:: test_empty_bars;
         "ambiguous_shallow_dip" >:: test_ambiguous_shallow_dip;
       ]

let () = run_test_tt_main suite
