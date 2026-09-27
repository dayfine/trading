(** Default-off anchor-bookkeeping flags of the stop state machine (issue #2974
    comment, 2026-09-26), pinned through {!Weinstein_stops.update}: each flag's
    OFF arm reproduces today's behaviour on a synthetic tape, its ON arm the new
    one.

    {b [correction_must_follow_peak]}. The cycle test is
    [(peak -. low) /. peak >= min_correction_pct] plus a close back at the peak.
    Off, the low may precede the peak (for the first cycle it is the entry bar's
    own low), so a pure advance of ~8.7% with no pullback "completes" a cycle.
    On, the correction extreme resets to the close at every new trend extreme,
    so only a low printed after the peak counts.

    {b [tightened_can_ratchet]}. Off, the [Tightened] anchor is a running min
    (long) that only falls, so the stop is frozen after one step. On, the stop
    is raised under each confirmed topping-zone reaction low: a pullback of at
    least [tightened_min_reaction_pct] from the swing peak, then a close back at
    the peak. Noise that never confirms a reaction moves nothing. *)

open OUnit2
open Core
open Trading_base.Types
open Weinstein_types
open Weinstein_stops
open Matchers

let as_of = Date.of_string "2024-01-05"
let stage2 = Stage2 { weeks_advancing = 4; late = false }
let stage4 = Stage4 { weeks_declining = 4 }

let bar ~low ~high ~close =
  Types.Daily_price.
    {
      date = as_of;
      open_price = close;
      high_price = high;
      low_price = low;
      close_price = close;
      volume = 1_000_000;
      adjusted_close = close;
      active_through = None;
    }

(* Fold [update] over [tape] ((low, high, close) per bar) and return the stop
   level after each bar. The MA and stage are held fixed in the no-tighten pose
   for the side, so only the cycle detector moves the stop. *)
let stop_levels ~config ~side ~ma_value ~state tape =
  let ma_direction, stage =
    match side with Long -> (Rising, stage2) | Short -> (Declining, stage4)
  in
  List.folding_map tape ~init:state ~f:(fun state (low, high, close) ->
      let state, _event =
        update ~config ~side ~state ~current_bar:(bar ~low ~high ~close)
          ~ma_value ~ma_direction ~stage
      in
      (state, get_stop_level state))

let peak_off = { default_config with correction_must_follow_peak = false }
let peak_on = { default_config with correction_must_follow_peak = true }
let long_initial = Initial { stop_level = 80.0; reference_level = 85.0 }

(* ---- correction_must_follow_peak ---- *)

(* A pure advance: every bar a new closing high, no pullback. The seed (entry
   bar) low is 99; by bar 6 the prior peak is 108, and (108 - 99) / 108 = 8.3%
   >= 8%, with the close 109 back above it. *)
let pure_advance =
  [
    (99.0, 100.0, 100.0);
    (101.0, 102.0, 102.0);
    (103.0, 104.0, 104.0);
    (105.0, 106.0, 106.0);
    (107.0, 108.0, 108.0);
    (108.5, 109.0, 109.0);
  ]

(* OFF (today): the seed low stands in for a correction, a cycle "completes" on
   bar 6 and the stop is raised to below min (99, MA 90) = 90 * 0.99, nudged
   under the 89 round number to 88.875. *)
let test_pure_advance_raises_when_off _ =
  assert_that
    (stop_levels ~config:peak_off ~side:Long ~ma_value:90.0 ~state:long_initial
       pure_advance)
    (elements_are
       [
         float_equal 80.0;
         float_equal 80.0;
         float_equal 80.0;
         float_equal 80.0;
         float_equal 80.0;
         float_equal ~epsilon:1e-9 88.875;
       ])

(* ON: every new closing high resets the correction extreme to that close, so
   no bar ever sees a pullback from its peak and the stop never moves. *)
let test_pure_advance_does_not_raise_when_on _ =
  assert_that
    (stop_levels ~config:peak_on ~side:Long ~ma_value:90.0 ~state:long_initial
       pure_advance)
    (elements_are (List.init 6 ~f:(fun _ -> float_equal 80.0)))

(* A real correction AFTER the peak still completes under the flag: peak close
   104 on bar 3, low 95 on bar 4 (-8.65% from the peak), close 105 on bar 6
   recovers it. The pullback is measured on the bar that completes the cycle —
   before bar 6's own new high resets the extreme. *)
let post_peak_correction =
  [
    (99.0, 100.0, 100.0);
    (101.0, 102.0, 102.0);
    (103.0, 104.0, 104.0);
    (95.0, 97.0, 96.0);
    (97.0, 100.0, 100.0);
    (101.0, 105.0, 105.0);
  ]

let test_post_peak_correction_raises_when_on _ =
  assert_that
    (stop_levels ~config:peak_on ~side:Long ~ma_value:90.0 ~state:long_initial
       post_peak_correction)
    (elements_are
       [
         float_equal 80.0;
         float_equal 80.0;
         float_equal 80.0;
         float_equal 80.0;
         float_equal 80.0;
         float_equal ~epsilon:1e-9 88.875;
       ])

(* Short mirror: a pure decline with no counter-rally. OFF, the seed high 101
   against the prior trough 92 is a 9.8% "counter-rally" and the stop falls to
   above max (101, MA 110) = 110 * 1.01 = 111.1 on bar 6; ON it stays at 120. *)
let pure_decline =
  [
    (100.0, 101.0, 100.0);
    (98.0, 99.0, 98.0);
    (96.0, 97.0, 96.0);
    (94.0, 95.0, 94.0);
    (92.0, 93.0, 92.0);
    (91.0, 91.5, 91.0);
  ]

let short_initial = Initial { stop_level = 120.0; reference_level = 115.0 }

let test_short_pure_decline_mirror _ =
  let run config =
    List.last_exn
      (stop_levels ~config ~side:Short ~ma_value:110.0 ~state:short_initial
         pure_decline)
  in
  assert_that
    (run peak_off, run peak_on)
    (pair (float_equal ~epsilon:1e-9 111.1) (float_equal 120.0))

(* ---- tightened_can_ratchet ---- *)

let ratchet_off = { default_config with tightened_can_ratchet = false }
let ratchet_on = { default_config with tightened_can_ratchet = true }

(* A long just tightened: stop 80 under an 85 anchor, no swing tracked yet. *)
let long_tightened =
  Tightened
    {
      stop_level = 80.0;
      last_correction_extreme = 85.0;
      reason = "Stage 3 detected";
      swing_peak = None;
    }

(* Three topping-zone swings after tightening (default reaction depth 8%):
   - bar 1 starts the swing at close 100;
   - bars 2-3 pull back to 91 (-9%), bar 4 closes 101 >= 100: reaction low 91
     confirmed -> 91 * 0.995 = 90.545, nudged under 90.5 to 90.375;
   - bar 5 is a new high (105); bar 6 pulls back to 96 (-8.6%), bar 7 closes
     106 >= 105: reaction low 96 -> 95.52, nudged to 95.375;
   - bar 8 pulls back to 95.6 (-9.8% from 106), bar 9 closes 106.5: confirmed,
     but 95.6 * 0.995 = 95.122 nudges to 94.875, below the 95.375 stop — the
     stop is not lowered. *)
let topping_swings =
  [
    (99.0, 101.0, 100.0);
    (93.0, 97.0, 94.0);
    (91.0, 95.0, 92.0);
    (95.0, 101.5, 101.0);
    (104.0, 106.0, 105.0);
    (96.0, 99.0, 97.0);
    (100.0, 106.5, 106.0);
    (95.6, 99.0, 97.0);
    (99.0, 107.0, 106.5);
  ]

(* OFF (today): bar 1's candidate from the 85 anchor (84.575 -> 84.375) is the
   only move; the running-min anchor never rises again. *)
let test_tightened_frozen_when_off _ =
  assert_that
    (stop_levels ~config:ratchet_off ~side:Long ~ma_value:90.0
       ~state:long_tightened topping_swings)
    (elements_are (List.init 9 ~f:(fun _ -> float_equal ~epsilon:1e-9 84.375)))

let test_tightened_raises_under_reaction_lows _ =
  assert_that
    (stop_levels ~config:ratchet_on ~side:Long ~ma_value:90.0
       ~state:long_tightened topping_swings)
    (elements_are
       [
         float_equal 80.0;
         float_equal 80.0;
         float_equal 80.0;
         float_equal ~epsilon:1e-9 90.375;
         float_equal ~epsilon:1e-9 90.375;
         float_equal ~epsilon:1e-9 90.375;
         float_equal ~epsilon:1e-9 95.375;
         float_equal ~epsilon:1e-9 95.375;
         float_equal ~epsilon:1e-9 95.375;
       ])

(* Daily noise in the topping zone: dips of 4-5.5% and marginal new highs, but
   no pullback of 8% followed by a recovery, so no reaction low is confirmed and
   the stop stays at 80. (A rule that trails the latest daily lows would have
   ratcheted up under this tape.) *)
let test_tightened_noise_does_not_move _ =
  let noise =
    [
      (99.0, 101.0, 100.0);
      (96.0, 99.0, 97.0);
      (98.0, 101.0, 100.5);
      (95.0, 98.0, 96.0);
      (97.0, 100.0, 99.5);
      (98.5, 101.5, 101.0);
    ]
  in
  assert_that
    (stop_levels ~config:ratchet_on ~side:Long ~ma_value:90.0
       ~state:long_tightened noise)
    (elements_are (List.init 6 ~f:(fun _ -> float_equal 80.0)))

(* Short mirror: stop 120 with a 115 anchor. Swing trough 100 (bar 1); bar 2
   rallies to a 109.5 high (+9.5%); bar 3 closes 99 <= 100: reaction high 109.5
   confirmed -> 109.5 * 1.005 = 110.0475 (not nudged: it sits above the 110
   half). OFF moves once, from the 115 anchor, to 115.575, and stays. *)
let test_tightened_short_mirror _ =
  let state =
    Tightened
      {
        stop_level = 120.0;
        last_correction_extreme = 115.0;
        reason = "Stage 1/2 detected";
        swing_peak = None;
      }
  in
  let tape =
    [ (99.0, 101.0, 100.0); (103.0, 109.5, 109.0); (98.0, 100.5, 99.0) ]
  in
  let run config =
    List.last_exn (stop_levels ~config ~side:Short ~ma_value:110.0 ~state tape)
  in
  assert_that
    (run ratchet_off, run ratchet_on)
    (pair
       (float_equal ~epsilon:1e-9 115.575)
       (float_equal ~epsilon:1e-9 110.0475))

let suite =
  "stop_anchor_rules"
  >::: [
         "tightened_can_ratchet off: frozen after one step (today)"
         >:: test_tightened_frozen_when_off;
         "tightened_can_ratchet on: raised under each reaction low"
         >:: test_tightened_raises_under_reaction_lows;
         "tightened_can_ratchet on: noise without a reaction moves nothing"
         >:: test_tightened_noise_does_not_move;
         "tightened_can_ratchet: short mirror" >:: test_tightened_short_mirror;
         "correction_must_follow_peak off: pure advance raises (today)"
         >:: test_pure_advance_raises_when_off;
         "correction_must_follow_peak on: pure advance never raises"
         >:: test_pure_advance_does_not_raise_when_on;
         "correction_must_follow_peak on: post-peak correction raises"
         >:: test_post_peak_correction_raises_when_on;
         "correction_must_follow_peak: short mirror"
         >:: test_short_pure_decline_mirror;
       ]

let () = run_test_tt_main suite
