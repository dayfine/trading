(** Issue #2977 — {!Weinstein_stops.Stop_decision} names the decision the
    trailing-stop state machine made on each update.

    Every tape below is driven through the real {!Weinstein_stops.update}; the
    record is built from the [(before, after, event, bar, ma)] that call
    returned, exactly as the strategy's stops runner does. So these tests pin
    the classifier against the state machine, not against a re-implementation
    of it. Unless a test says otherwise: long side, Stage 2 with a rising MA
    (tightening never fires), default config. *)

open OUnit2
open Core
open Trading_base.Types
open Weinstein_types
open Weinstein_stops
open Matchers
module D = Stop_decision

let stage2 = Stage2 { weeks_advancing = 4; late = false }
let start = Date.of_string "2024-01-05"

type spec = { low : float; high : float; close : float; ma : float }
(** One tape bar plus the MA the update reads on it. *)

let s ?high ?(ma = 95.0) low close =
  { low; high = Option.value high ~default:close; close; ma }

let bar ~day (sp : spec) =
  Types.Daily_price.
    {
      date = Date.add_days start day;
      open_price = sp.close;
      high_price = sp.high;
      low_price = sp.low;
      close_price = sp.close;
      volume = 1_000_000;
      adjusted_close = sp.close;
      active_through = None;
    }

let initial ~stop = Initial { stop_level = stop; reference_level = stop }

(* Replay [specs] from [state], returning one decision per update. *)
let decisions ?(config = default_config) ?(side = Long) ?(stage = stage2)
    ?(ma_direction = Rising) ~state specs =
  List.foldi specs ~init:(state, []) ~f:(fun day (before, acc) sp ->
      let bar = bar ~day sp in
      let after, event =
        update ~config ~side ~state:before ~current_bar:bar ~ma_value:sp.ma
          ~ma_direction ~stage
      in
      let d =
        D.make ~config ~side ~position_id:"AAA-wein-1"
          { D.before; after; event; bar; ma_value = sp.ma }
      in
      (after, d :: acc))
  |> snd |> List.rev

let reasons ds = List.map ds ~f:(fun (d : D.t) -> d.reason)

(* First cycle. Seed at low 99 / close 100, run to a 115 close, dip to 104, then
   close at 120 — back through the 115 peak. The cycle gate does NOT see the
   104 dip: the first cycle's correction extreme is the running low since the
   seed bar, 99, so the depth it reads is (115 - 99) / 115 = 13.9 %. The
   candidate is [min (99, ma 95) *. 0.99 = 94.05], nudged below the 94.0 round
   number to 93.875. *)
let first_cycle = [ s 99. 100.; s 105. 115.; s 104. 106.; s 110. 120. ]

(* Second cycle, a genuine pullback. The first raise reset both extremes to the
   120 close. A 108 low (-10 % from 120) touches the reset anchor without
   recovering; a 121 close then recovers through 120. With the MA at 110 the
   candidate is [min (108, 110) *. 0.99 = 106.92] — 0.08 below 107.0, so the
   long-side nudge (which only moves a price sitting AT or ABOVE the round
   number) leaves it at 106.92. *)
let second_cycle = [ s ~ma:110. 108. 112.; s ~ma:110. 115. 121. ]

let two_cycles () =
  decisions ~state:(initial ~stop:90.0) (first_cycle @ second_cycle)

let test_first_and_second_cycles_raise _ =
  assert_that
    (reasons (two_cycles ()))
    (elements_are
       [
         equal_to D.Seeded_trailing;
         equal_to D.No_correction_yet;
         equal_to D.Correction_not_recovered;
         equal_to D.Raised;
         equal_to D.Correction_not_recovered;
         equal_to D.Raised;
       ])

let test_first_raise_is_seed_anchored _ =
  assert_that
    (List.nth (two_cycles ()) 3)
    (is_some_and
       (all_of
          [
            field (fun (d : D.t) -> d.date) (equal_to (Date.add_days start 3));
            field (fun (d : D.t) -> d.position_id) (equal_to "AAA-wein-1");
            field (fun (d : D.t) -> d.state_before) (equal_to D.Trailing);
            field (fun (d : D.t) -> d.state_after) (equal_to D.Trailing);
            field (fun (d : D.t) -> d.stop_before) (float_equal 90.0);
            field (fun (d : D.t) -> d.stop_after) (float_equal 93.875);
            field
              (fun (d : D.t) -> d.candidate)
              (is_some_and (float_equal 93.875));
            field (fun (d : D.t) -> d.correction_count_before) (equal_to 0);
            field (fun (d : D.t) -> d.correction_count) (equal_to 1);
            field
              (fun (d : D.t) -> d.last_trend_extreme)
              (is_some_and (float_equal 115.0));
            field
              (fun (d : D.t) -> d.last_correction_extreme)
              (is_some_and (float_equal 99.0));
            field (fun (d : D.t) -> d.ma_value) (float_equal 95.0);
          ]))

let test_second_raise_is_pullback_driven _ =
  assert_that
    (List.last (two_cycles ()))
    (is_some_and
       (all_of
          [
            field (fun (d : D.t) -> d.stop_before) (float_equal 93.875);
            field (fun (d : D.t) -> d.stop_after) (float_equal 106.92);
            field
              (fun (d : D.t) -> d.candidate)
              (is_some_and (float_equal 106.92));
            field (fun (d : D.t) -> d.correction_count_before) (equal_to 1);
            field (fun (d : D.t) -> d.correction_count) (equal_to 2);
            field
              (fun (d : D.t) -> d.last_trend_extreme)
              (is_some_and (float_equal 120.0));
            field
              (fun (d : D.t) -> d.last_correction_extreme)
              (is_some_and (float_equal 108.0));
          ]))

(* Creeps 100 -> 104 without ever pulling back: the depth from the running peak
   to the 99 seed low never reaches 8 %. *)
let steady_advance =
  [ s 99. 100.; s 100. 101.; s 101. 102.; s 102. 103.; s 103. 104. ]

let test_steady_advance_holds_with_no_correction _ =
  assert_that
    (decisions ~state:(initial ~stop:90.0) steady_advance)
    (elements_are
       (field (fun (d : D.t) -> d.reason) (equal_to D.Seeded_trailing)
       :: List.init 4 ~f:(fun _ ->
              all_of
                [
                  field
                    (fun (d : D.t) -> d.reason)
                    (equal_to D.No_correction_yet);
                  field (fun (d : D.t) -> d.stop_after) (float_equal 90.0);
                  field (fun (d : D.t) -> d.candidate) is_none;
                ])))

(* After the first raise resets both extremes to 120, price advances with every
   low above 120 — no bar touches the anchor. By the 131 peak the depth to the
   120 anchor reads (131 - 120) / 131 = 8.4 % and the 135 close is a new high,
   but the phantom-cycle guard rejects the cycle. *)
let test_advance_after_reset_is_anchor_not_fresh _ =
  let after_reset =
    [
      s ~ma:110. 121. 125.;
      s ~ma:110. 126. 128.;
      s ~ma:110. 129. 131.;
      s ~ma:110. 132. 135.;
    ]
  in
  assert_that
    (List.drop
       (reasons (decisions ~state:(initial ~stop:90.0) (first_cycle @ after_reset)))
       4)
    (elements_are
       [
         equal_to D.No_correction_yet;
         equal_to D.No_correction_yet;
         equal_to D.No_correction_yet;
         equal_to D.Anchor_not_fresh;
       ])

(* Resting stop 97 sits above the first cycle's 93.875 candidate: the cycle
   completes and the never-lower rule keeps the stop. Pinned under both
   [reset_anchor_on_stalled_cycle] values — the bookkeeping differs, the tag
   does not. *)
let _stalled_tail ~reset =
  let config = { default_config with reset_anchor_on_stalled_cycle = reset } in
  List.last (decisions ~config ~state:(initial ~stop:97.0) first_cycle)

let test_stalled_cycle_with_anchor_reset _ =
  assert_that (_stalled_tail ~reset:true)
    (is_some_and
       (all_of
          [
            field (fun (d : D.t) -> d.reason) (equal_to D.Cycle_stalled);
            field (fun (d : D.t) -> d.stop_after) (float_equal 97.0);
            field
              (fun (d : D.t) -> d.candidate)
              (is_some_and (float_equal 93.875));
            field (fun (d : D.t) -> d.correction_count) (equal_to 1);
          ]))

let test_stalled_cycle_with_frozen_anchor _ =
  assert_that (_stalled_tail ~reset:false)
    (is_some_and
       (all_of
          [
            field (fun (d : D.t) -> d.reason) (equal_to D.Cycle_stalled);
            field (fun (d : D.t) -> d.stop_after) (float_equal 97.0);
            field (fun (d : D.t) -> d.correction_count) (equal_to 0);
          ]))

(* A low at the stop is a hit. No cycle test ran, so the recorded correction
   extreme is the pre-step seed low (99), not the bar's 89. *)
let test_low_through_stop_is_stop_hit _ =
  assert_that
    (List.last (decisions ~state:(initial ~stop:90.0) [ s 99. 100.; s 89. 95. ]))
    (is_some_and
       (all_of
          [
            field (fun (d : D.t) -> d.reason) (equal_to D.Stop_hit);
            field (fun (d : D.t) -> d.stop_after) (float_equal 90.0);
            field
              (fun (d : D.t) -> d.last_correction_extreme)
              (is_some_and (float_equal 99.0));
            field (fun (d : D.t) -> d.candidate) is_none;
          ]))

(* Stage 3 from the first bar: tighten to 99 *. 0.99 = 98.01 -> 97.875; the
   tight ratchet then re-buffers the same 99 low at 0.5 %: 98.505 -> 98.375;
   after that the low never improves, so it holds. *)
let test_stage3_tightens_ratchets_then_holds _ =
  assert_that
    (decisions
       ~stage:(Stage3 { weeks_topping = 1 })
       ~state:(initial ~stop:90.0)
       [ s 99. 100.; s 100. 101.; s 101. 102. ])
    (elements_are
       [
         all_of
           [
             field (fun (d : D.t) -> d.reason) (equal_to D.Entered_tightening);
             field (fun (d : D.t) -> d.state_after) (equal_to D.Tightened);
             field (fun (d : D.t) -> d.stop_after) (float_equal 97.875);
           ];
         all_of
           [
             field (fun (d : D.t) -> d.reason) (equal_to D.Tightened_ratchet);
             field (fun (d : D.t) -> d.stop_after) (float_equal 98.375);
           ];
         all_of
           [
             field (fun (d : D.t) -> d.reason) (equal_to D.Tightened_hold);
             field (fun (d : D.t) -> d.stop_after) (float_equal 98.375);
           ];
       ])

(* Short side: the correction extreme is the running HIGH ([Float.max]). Seed
   high 101 / close 100; the next bar's high of 99 must not lower it. *)
let test_short_tracks_the_running_high _ =
  assert_that
    (decisions ~side:Short
       ~stage:(Stage4 { weeks_declining = 4 })
       ~ma_direction:Declining ~state:(initial ~stop:110.0)
       [ s ~high:101. 100. 100.; s ~high:99. 95. 95. ])
    (elements_are
       [
         field (fun (d : D.t) -> d.reason) (equal_to D.Seeded_trailing);
         all_of
           [
             field (fun (d : D.t) -> d.reason) (equal_to D.No_correction_yet);
             field
               (fun (d : D.t) -> d.last_trend_extreme)
               (is_some_and (float_equal 100.0));
             field
               (fun (d : D.t) -> d.last_correction_extreme)
               (is_some_and (float_equal 101.0));
           ];
       ])

let test_is_hold_splits_holds_from_decisions _ =
  assert_that
    (List.map
       [
         D.No_correction_yet;
         D.Correction_not_recovered;
         D.Anchor_not_fresh;
         D.Tightened_hold;
         D.Other_hold;
         D.Raised;
         D.Cycle_stalled;
         D.Seeded_trailing;
         D.Entered_tightening;
         D.Tightened_ratchet;
         D.Stop_hit;
       ]
       ~f:D.is_hold)
    (equal_to
       [ true; true; true; true; true; false; false; false; false; false; false ])

let test_sexp_round_trip _ =
  let d : D.t =
    {
      D.date = Date.of_string "2024-03-15";
      position_id = "AAA-wein-1";
      state_before = D.Trailing;
      state_after = D.Trailing;
      stop_before = 90.0;
      stop_after = 93.875;
      candidate = Some 93.875;
      correction_count_before = 0;
      correction_count = 1;
      last_trend_extreme = Some 115.0;
      last_correction_extreme = None;
      ma_value = 95.0;
      reason = D.Raised;
    }
  in
  assert_that (D.t_of_sexp (D.sexp_of_t d)) (equal_to d)

let suite =
  "Stop_decision"
  >::: [
         "first and second cycles raise"
         >:: test_first_and_second_cycles_raise;
         "first raise is seed-anchored" >:: test_first_raise_is_seed_anchored;
         "second raise is pullback-driven"
         >:: test_second_raise_is_pullback_driven;
         "steady advance holds with no correction"
         >:: test_steady_advance_holds_with_no_correction;
         "advance after reset is anchor-not-fresh"
         >:: test_advance_after_reset_is_anchor_not_fresh;
         "stalled cycle with anchor reset"
         >:: test_stalled_cycle_with_anchor_reset;
         "stalled cycle with frozen anchor"
         >:: test_stalled_cycle_with_frozen_anchor;
         "low through the stop is a hit" >:: test_low_through_stop_is_stop_hit;
         "stage 3 tightens, ratchets, then holds"
         >:: test_stage3_tightens_ratchets_then_holds;
         "short tracks the running high" >:: test_short_tracks_the_running_high;
         "is_hold splits holds from decisions"
         >:: test_is_hold_splits_holds_from_decisions;
         "sexp round trip" >:: test_sexp_round_trip;
       ]

let () = run_test_tt_main suite
