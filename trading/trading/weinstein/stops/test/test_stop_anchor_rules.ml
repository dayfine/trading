(** Default-off anchor-bookkeeping flags of the stop state machine (issue #2974
    comment, 2026-09-26), pinned through {!Weinstein_stops.update}: each flag's
    OFF arm reproduces today's behaviour on a synthetic tape, its ON arm the new
    one.

    {b [correction_must_follow_peak]}. The cycle test is
    [(peak -. low) /. peak >= min_correction_pct] plus a close back at the peak.
    Off, the low may precede the peak (for the first cycle it is the entry bar's
    own low), so a pure advance of ~8.7% with no pullback "completes" a cycle.
    On, the correction extreme resets to the close at every new trend extreme,
    so only a low printed after the peak counts. *)

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
        update ~config ~side ~state
          ~current_bar:(bar ~low ~high ~close)
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
  assert_that (run peak_off, run peak_on)
    (pair (float_equal ~epsilon:1e-9 111.1) (float_equal 120.0))

let suite =
  "stop_anchor_rules"
  >::: [
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
