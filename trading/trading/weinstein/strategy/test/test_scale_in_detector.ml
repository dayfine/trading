(** Tests for {!Scale_in_detector} — pure pullback-hold / early-new-high
    detection (explore/exploit scale-in v1) — and the default-off config
    contract (experiment-flag-discipline R1/R2). *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy

let _bar date ~close ?low ?high ?(volume = 1_000_000) () =
  let low = Option.value low ~default:(close *. 0.99) in
  let high = Option.value high ~default:(close *. 1.01) in
  {
    Types.Daily_price.date = Date.of_string date;
    open_price = close;
    high_price = high;
    low_price = low;
    close_price = close;
    adjusted_close = close;
    volume;
    active_through = None;
  }

(* Entry at 100. Weekly bars strictly after the entry week. *)
let _entry = 100.0

let _pullback ~bars =
  Scale_in_detector.pullback_hold ~proximity_pct:0.03 ~entry_price:_entry
    ~bars_since_entry:bars

(* ------- pullback_hold ------- *)

let test_pullback_touch_then_turn_up_fires _ =
  (* Advance (108), pull back to the breakout zone (low 101 <= 103), then turn
     up while holding above entry (close 105 > 101 and >= 100). *)
  let bars =
    [
      _bar "2024-01-12" ~close:108.0 ();
      _bar "2024-01-19" ~close:101.0 ~low:101.0 ();
      _bar "2024-01-26" ~close:105.0 ~low:102.0 ();
    ]
  in
  assert_that (_pullback ~bars) (equal_to true)

let test_pullback_without_touch_does_not_fire _ =
  (* Steady advance, never near the breakout zone: no touch, no add. *)
  let bars =
    [
      _bar "2024-01-12" ~close:108.0 ~low:106.0 ();
      _bar "2024-01-19" ~close:112.0 ~low:110.0 ();
      _bar "2024-01-26" ~close:115.0 ~low:113.0 ();
    ]
  in
  assert_that (_pullback ~bars) (equal_to false)

let test_pullback_that_breaks_entry_does_not_fire _ =
  (* Touch happened but the current close sits below entry — the pullback did
     NOT hold the breakout level. *)
  let bars =
    [
      _bar "2024-01-12" ~close:104.0 ();
      _bar "2024-01-19" ~close:97.0 ~low:96.0 ();
      _bar "2024-01-26" ~close:99.0 ~low:97.0 ();
    ]
  in
  assert_that (_pullback ~bars) (equal_to false)

let test_pullback_without_turn_up_does_not_fire _ =
  (* Touched the zone but the current close is still falling (no turn). *)
  let bars =
    [
      _bar "2024-01-12" ~close:108.0 ();
      _bar "2024-01-19" ~close:104.0 ~low:101.0 ();
      _bar "2024-01-26" ~close:103.0 ~low:101.5 ();
    ]
  in
  assert_that (_pullback ~bars) (equal_to false)

let test_pullback_needs_two_bars _ =
  (* A single post-entry bar cannot be both the touch and the turn. *)
  let bars = [ _bar "2024-01-12" ~close:105.0 ~low:101.0 () ] in
  assert_that (_pullback ~bars) (equal_to false)

(* ------- early_new_high ------- *)

let test_early_new_high_fires_on_new_post_entry_high _ =
  let bars =
    [
      _bar "2024-01-12" ~close:104.0 ();
      _bar "2024-01-19" ~close:103.0 ();
      _bar "2024-01-26" ~close:106.0 ();
    ]
  in
  assert_that
    (Scale_in_detector.early_new_high ~entry_price:_entry ~bars_since_entry:bars)
    (equal_to true)

let test_early_new_high_not_fired_below_prior_high _ =
  let bars =
    [
      _bar "2024-01-12" ~close:108.0 ();
      _bar "2024-01-19" ~close:105.0 ();
      _bar "2024-01-26" ~close:107.0 ();
    ]
  in
  assert_that
    (Scale_in_detector.early_new_high ~entry_price:_entry ~bars_since_entry:bars)
    (equal_to false)

(* ------- add_signal dispatch ------- *)

let test_either_fires_on_new_high_when_pullback_does_not _ =
  (* Gap-and-go shape: never touches the zone, keeps making highs — Pullback
     misses it, Either catches it (the §3.4 monster-under-sizing fix). *)
  let bars =
    [
      _bar "2024-01-12" ~close:110.0 ~low:108.0 ();
      _bar "2024-01-19" ~close:115.0 ~low:112.0 ();
    ]
  in
  let signal trigger =
    Scale_in_detector.add_signal ~trigger ~proximity_pct:0.03
      ~consolidation:Scale_in_detector.default_consolidation_config ~ma:100.0
      ~entry_price:_entry ~bars_since_entry:bars
  in
  assert_that
    (signal Scale_in_detector.Pullback, signal Scale_in_detector.Either)
    (equal_to (false, true))

(* ------- consolidation_breakout (the book's continuation buy) ------- *)

(* A textbook continuation: 4 tight weeks near the MA (closes 100..103 with
   ma = 100), then a breakout bar above the window top on 2x volume. *)
let _consolidation_then_breakout ~breakout_close ~breakout_volume =
  [
    _bar "2024-03-01" ~close:102.0 ();
    _bar "2024-03-08" ~close:100.0 ();
    _bar "2024-03-15" ~close:103.0 ();
    _bar "2024-03-22" ~close:101.0 ();
    _bar "2024-03-29" ~close:breakout_close ~volume:breakout_volume ();
  ]

let _cont ?(cfg = Scale_in_detector.default_consolidation_config) ?(ma = 100.0)
    bars =
  Scale_in_detector.consolidation_breakout ~consolidation:cfg ~ma
    ~bars_since_entry:bars

let test_consolidation_breakout_fires _ =
  let bars =
    _consolidation_then_breakout ~breakout_close:106.0
      ~breakout_volume:2_000_000
  in
  assert_that (_cont bars) (equal_to true)

let test_consolidation_too_wide_band_does_not_fire _ =
  (* Window ranges 100 -> 115 (15% > 10% band): a trend, not a consolidation. *)
  let bars =
    [
      _bar "2024-03-01" ~close:100.0 ();
      _bar "2024-03-08" ~close:108.0 ();
      _bar "2024-03-15" ~close:115.0 ();
      _bar "2024-03-22" ~close:112.0 ();
      _bar "2024-03-29" ~close:118.0 ~volume:2_000_000 ();
    ]
  in
  assert_that (_cont bars) (equal_to false)

let test_consolidation_far_above_ma_does_not_fire _ =
  (* Same tight window, but the MA sits far below (min close 100 > 80 * 1.1):
     the stock never "dropped back close to its MA". *)
  let bars =
    _consolidation_then_breakout ~breakout_close:106.0
      ~breakout_volume:2_000_000
  in
  assert_that (_cont ~ma:80.0 bars) (equal_to false)

let test_consolidation_no_breakout_does_not_fire _ =
  (* Current close 102.5 stays inside the window (top 103): no breakout. *)
  let bars =
    _consolidation_then_breakout ~breakout_close:102.5
      ~breakout_volume:2_000_000
  in
  assert_that (_cont bars) (equal_to false)

let test_consolidation_weak_volume_does_not_fire _ =
  (* Breakout in price but volume at the window average (< 1.25x). *)
  let bars =
    _consolidation_then_breakout ~breakout_close:106.0
      ~breakout_volume:1_000_000
  in
  assert_that (_cont bars) (equal_to false)

let test_consolidation_needs_min_weeks _ =
  (* Only 3 completed bars before the breakout (< min_weeks 4). *)
  let bars =
    [
      _bar "2024-03-08" ~close:100.0 ();
      _bar "2024-03-15" ~close:103.0 ();
      _bar "2024-03-22" ~close:101.0 ();
      _bar "2024-03-29" ~close:106.0 ~volume:2_000_000 ();
    ]
  in
  assert_that (_cont bars) (equal_to false)

let test_add_signal_dispatches_consolidation_breakout _ =
  let bars =
    _consolidation_then_breakout ~breakout_close:106.0
      ~breakout_volume:2_000_000
  in
  assert_that
    (Scale_in_detector.add_signal
       ~trigger:Scale_in_detector.Consolidation_breakout ~proximity_pct:0.03
       ~consolidation:Scale_in_detector.default_consolidation_config ~ma:100.0
       ~entry_price:_entry ~bars_since_entry:bars)
    (equal_to true)

(* ------- extension gate ------- *)

let test_extended_above_ma _ =
  assert_that
    ( Scale_in_detector.extended_above_ma ~max_pct:0.15 ~close:120.0 ~ma:100.0,
      Scale_in_detector.extended_above_ma ~max_pct:0.15 ~close:110.0 ~ma:100.0,
      Scale_in_detector.extended_above_ma ~max_pct:0.15 ~close:120.0 ~ma:0.0 )
    (equal_to (true, false, false))

(* ------- config: default-off contract ------- *)

let test_config_defaults_are_no_op _ =
  assert_that Scale_in_detector.default_config
    (all_of
       [
         field
           (fun (c : Scale_in_detector.config) -> c.initial_entry_fraction)
           (float_equal 1.0);
         field
           (fun (c : Scale_in_detector.config) -> c.add_trigger)
           (equal_to Scale_in_detector.Pullback);
         field (fun (c : Scale_in_detector.config) -> c.max_adds) (equal_to 1);
         field
           (fun (c : Scale_in_detector.config) -> c.require_not_late)
           (equal_to true);
         field
           (fun (c : Scale_in_detector.config) -> c.add_fraction)
           (equal_to (None : float option));
         field
           (fun (c : Scale_in_detector.config) -> c.consolidation)
           (equal_to Scale_in_detector.default_consolidation_config);
       ])

let test_v1_config_sexp_parses_with_new_fields_defaulted _ =
  (* A v1-era scale_in_config sexp (no add_fraction / consolidation fields)
     must parse with the new knobs at their no-op defaults — recorded specs
     and the v1 ledger surface replay unchanged (R1). *)
  let v1_sexp =
    Sexplib.Sexp.of_string
      "((initial_entry_fraction 0.5)(add_trigger Either)(extension_max_pct \
       0.25))"
  in
  assert_that
    (Scale_in_detector.config_of_sexp v1_sexp)
    (all_of
       [
         field
           (fun (c : Scale_in_detector.config) -> c.add_fraction)
           (equal_to (None : float option));
         field
           (fun (c : Scale_in_detector.config) -> c.consolidation)
           (equal_to Scale_in_detector.default_consolidation_config);
         field
           (fun (c : Scale_in_detector.config) -> c.initial_entry_fraction)
           (float_equal 0.5);
         field
           (fun (c : Scale_in_detector.config) -> c.add_trigger)
           (equal_to Scale_in_detector.Either);
       ])

let test_strategy_config_omitted_fields_default_off _ =
  (* A config sexp that predates scale-in (no scale_in fields) must parse with
     enable_scale_in = false and the default knobs — old scenario sexps replay
     unchanged (experiment-flag-discipline R1). *)
  let base =
    Weinstein_strategy.default_config ~universe:[ "AAPL" ] ~index_symbol:"SPY"
  in
  let round_tripped =
    Weinstein_strategy.config_of_sexp (Weinstein_strategy.sexp_of_config base)
  in
  assert_that round_tripped
    (all_of
       [
         field
           (fun (c : Weinstein_strategy.config) -> c.enable_scale_in)
           (equal_to false);
         field
           (fun (c : Weinstein_strategy.config) -> c.scale_in_config)
           (equal_to Scale_in_detector.default_config);
       ])

let suite =
  "scale_in_detector"
  >::: [
         "pullback: touch then turn up fires"
         >:: test_pullback_touch_then_turn_up_fires;
         "pullback: no touch does not fire"
         >:: test_pullback_without_touch_does_not_fire;
         "pullback: broken entry does not fire"
         >:: test_pullback_that_breaks_entry_does_not_fire;
         "pullback: no turn up does not fire"
         >:: test_pullback_without_turn_up_does_not_fire;
         "pullback: needs two bars" >:: test_pullback_needs_two_bars;
         "early_new_high: fires on new post-entry high"
         >:: test_early_new_high_fires_on_new_post_entry_high;
         "early_new_high: not fired below prior high"
         >:: test_early_new_high_not_fired_below_prior_high;
         "add_signal: Either catches gap-and-go that Pullback misses"
         >:: test_either_fires_on_new_high_when_pullback_does_not;
         "consolidation_breakout: fires on tight window + volume breakout"
         >:: test_consolidation_breakout_fires;
         "consolidation_breakout: wide band does not fire"
         >:: test_consolidation_too_wide_band_does_not_fire;
         "consolidation_breakout: far above MA does not fire"
         >:: test_consolidation_far_above_ma_does_not_fire;
         "consolidation_breakout: no breakout does not fire"
         >:: test_consolidation_no_breakout_does_not_fire;
         "consolidation_breakout: weak volume does not fire"
         >:: test_consolidation_weak_volume_does_not_fire;
         "consolidation_breakout: needs min_weeks window"
         >:: test_consolidation_needs_min_weeks;
         "add_signal: dispatches Consolidation_breakout"
         >:: test_add_signal_dispatches_consolidation_breakout;
         "extension gate thresholds" >:: test_extended_above_ma;
         "config defaults are no-op" >:: test_config_defaults_are_no_op;
         "v1 config sexp parses with new fields defaulted"
         >:: test_v1_config_sexp_parses_with_new_fields_defaulted;
         "strategy config round-trips default-off"
         >:: test_strategy_config_omitted_fields_default_off;
       ]

let () = run_test_tt_main suite
