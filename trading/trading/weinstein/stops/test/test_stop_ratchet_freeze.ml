(** Issue #2486 — the fallback initial stop freezes the trailing ratchet.

    {b The defect, stated as an invariant.} In [Trailing], the cycle stop
    candidate is [below (min (last_correction_extreme, ma_value))], and
    [_advance_tracking] only ever moves [last_correction_extreme] {i against}
    the position ([Float.min] for a long). The only writer that moves it back
    {i for} the position is the cycle reset — and that reset is reachable only
    through the {i raise} branch. So for a long, for the whole life of a
    [Trailing] state:

    {v
      reachable_stop  <=  A0 *. (1 -. trailing_stop_buffer_pct)
      where A0 = the bar extreme seeded at the Initial -> Trailing transition
    v}

    and that bound is monotone non-increasing. If it already sits at or below
    the installed initial stop,
    {b no cycle can ever raise the stop, so no cycle can ever reset the anchor,
       so the bound never recovers.} The ratchet is frozen for the life of the
    position, however far price advances.

    {b The precondition is the fallback stop, not the structural one.} A
    fallback stop is
    [entry *. fallback_buffer *. (1 -. min_correction_pct /. 2.)] — with the
    shipped 1.0 / 0.08 defaults, [0.96 *. entry] before the round-number nudge
    (pinned in [test_fallback_stop_width.ml]). The freeze therefore arms as soon
    as the entry bar's low sits more than ~3.03% below the entry price:

    {v   A0 *. 0.99 <= 0.96 *. entry   <=>   A0 <= 0.969697 *. entry v}

    {b The 2026-08-24 [initial_stop_buffer] flip 1.02 -> 1.0 narrows this
       precondition but does not remove it} — it moved the arming threshold from
    ~1.09% to ~3.03%, which is why the tape below seeds a 3.5%-below-entry bar
    where the pre-flip version of this file used 1.5%. The freeze remains
    reachable at the shipped defaults; that is what makes the flag's own default
    load-bearing rather than cosmetic.

    A {i structural} support-floor stop derives from a prior correction low well
    below entry, which leaves the entry-bar anchor comfortably above the stop,
    so the first cycle raises and the machine ratchets normally. That contrast
    is pinned by [test_structural_stop_ratchets_on_the_same_tape] below — same
    tape, same anchor, only the initial stop differs.

    {b What the flag does.} [reset_anchor_on_stalled_cycle] (default [true]
    since 2026-08-24) decouples the cycle {i bookkeeping} from the never-lower
    rule: a cycle that completes but cannot improve the stop still resets the
    extremes and counts, while [stop_level] is left exactly where it was. The
    phantom-cycle guard is unaffected — [Stalled] is only reachable when the
    cycle predicate (which {i includes} that guard) already fired; see
    [test_stale_anchor_still_blocked_under_flag]. Both configs are named
    explicitly below so this file keeps pinning the contrast whichever way the
    default points. *)

open OUnit2
open Core
open Trading_base.Types
open Weinstein_types
open Weinstein_stops
open Matchers

(* The strategy layer's [initial_stop_buffer] default (1.0 since 2026-08-24) —
   the value actually threaded into the fallback on the production path. *)
let fallback_buffer = 1.0
let as_of = Date.of_string "2024-01-05"
let stage2 = Stage2 { weeks_advancing = 4; late = false }

(* Both arms are named against the flag explicitly rather than one of them
   being [default_config], so the contrast this file pins survives a default
   flip in either direction. [unfrozen_config] is the shipped default today. *)
let frozen_config =
  { default_config with reset_anchor_on_stalled_cycle = false }

let unfrozen_config =
  { default_config with reset_anchor_on_stalled_cycle = true }

(* Only the long side's fields matter here: the trigger reads [low_price], the
   cycle math reads [low_price] and [close_price]. *)
let bar ~low ~close =
  Types.Daily_price.
    {
      date = as_of;
      open_price = close;
      high_price = close;
      low_price = low;
      close_price = close;
      volume = 1_000_000;
      adjusted_close = close;
      active_through = None;
    }

(* (low, close, ma) per period. Chosen so that three correction cycles genuinely
   complete (>= 8% pullback from the running trend extreme, then a close back
   through it) while price closes 101 -> 140, +38.6%.

   Period 1's low, 96.5, is the entry-bar anchor A0. It sits 3.5% below the
   entry price of 100 — inside the ~3.03% arming threshold of the header, so the
   freeze arms at the SHIPPED [initial_stop_buffer = 1.0] defaults.

   Period 3 is the first completed cycle: trend extreme 110, anchor 96.5 =>
   12.27% pullback, close 115 recovers through it. Its candidate is
   [min (96.5, ma 100) *. 0.99] = 95.535, nudged to 95.375 — BELOW the 95.875
   initial stop, so it stalls.

   Periods 4-5 are a second, shallower cycle (115 -> 105 -> 120) whose low, 105,
   is well above the initial stop. It can only be seen by a machine whose anchor
   was reset at period 3. *)
let tape =
  [
    (96.5, 101.0, 100.0);
    (100.0, 110.0, 100.0);
    (108.0, 115.0, 100.0);
    (105.0, 106.0, 106.0);
    (114.0, 120.0, 106.0);
    (118.0, 140.0, 108.0);
  ]

(* No bars => no qualifying counter-move => the fallback reference is used. This
   is the common path: the support scan finds nothing for most breakouts (see
   dev/agent-memory/project_fallback_stop_half_book_band.md). *)
let fallback_initial_stop ~entry_price =
  compute_initial_stop_with_floor_with_callbacks ~config:frozen_config
    ~side:Long ~entry_price
    ~callbacks:(callbacks_from_bars ~config:frozen_config ~bars:[] ~as_of)
    ~fallback_buffer

let replay ~config ~state =
  List.folding_map tape ~init:state ~f:(fun state (low, close, ma_value) ->
      let state, _event =
        update ~config ~side:Long ~state ~current_bar:(bar ~low ~close)
          ~ma_value ~ma_direction:Rising ~stage:stage2
      in
      (state, state))

let stop_levels ~config ~state =
  List.map (replay ~config ~state) ~f:get_stop_level

let final_correction_count ~config ~state =
  match List.last_exn (replay ~config ~state) with
  | Trailing { correction_count; _ } -> Some correction_count
  | Initial _ | Tightened _ -> None

(* The seed: entry 100 => reference 100 => raw stop 96.0 (100 * 1.0 * 0.96),
   which lands exactly ON the 96.0 round number, so the nudge pushes it to
   95.875. *)
let test_fallback_seed_is_the_frozen_level _ =
  assert_that
    (get_stop_level (fallback_initial_stop ~entry_price:100.0))
    (float_equal ~epsilon:1e-9 95.875)

(* THE DEFECT. Price closes 101 -> 140 across three completed correction cycles
   and the installed stop never moves off its initial level. *)
let test_fallback_stop_never_ratchets _ =
  assert_that
    (stop_levels ~config:frozen_config
       ~state:(fallback_initial_stop ~entry_price:100.0))
    (elements_are
       [
         float_equal ~epsilon:1e-9 95.875;
         float_equal ~epsilon:1e-9 95.875;
         float_equal ~epsilon:1e-9 95.875;
         float_equal ~epsilon:1e-9 95.875;
         float_equal ~epsilon:1e-9 95.875;
         float_equal ~epsilon:1e-9 95.875;
       ])

(* The mechanism, isolated from the stop level: not one of the completed cycles
   is recorded, because the reset lives inside the raise branch. *)
let test_no_correction_cycle_is_ever_counted _ =
  assert_that
    (final_correction_count ~config:frozen_config
       ~state:(fallback_initial_stop ~entry_price:100.0))
    (is_some_and (equal_to 0))

(* Same tape, same entry-bar anchor — only the initial stop is structural
   (reference 90 => stop 86.4) instead of the fallback. The first cycle's
   candidate, 95.375, now beats it, so the machine ratchets AND resets, and the
   shallow second cycle then lifts it again to 103.95 — all WITHOUT the flag.
   This is why the freeze is a fallback-path defect, not a property of the
   tape. *)
let test_structural_stop_ratchets_on_the_same_tape _ =
  let structural =
    compute_initial_stop ~config:frozen_config ~side:Long ~reference_level:90.0
  in
  assert_that
    (stop_levels ~config:frozen_config ~state:structural)
    (elements_are
       [
         float_equal ~epsilon:1e-9 86.4;
         float_equal ~epsilon:1e-9 86.4;
         float_equal ~epsilon:1e-9 95.375;
         float_equal ~epsilon:1e-9 95.375;
         float_equal ~epsilon:1e-9 103.95;
         float_equal ~epsilon:1e-9 103.95;
       ])

(* THE FIX. With the anchor reset decoupled from the raise, the stalled cycle at
   period 3 still resets, so the shallow 115 -> 105 -> 120 cycle is visible and
   ratchets the stop to [min (105, ma 106) *. 0.99] = 103.95 at period 5.
   Periods 1-4 are unchanged, including the stalled period 3: the flag never
   moves [stop_level], only bookkeeping. *)
let test_flag_unfreezes_the_ratchet _ =
  assert_that
    (stop_levels ~config:unfrozen_config
       ~state:(fallback_initial_stop ~entry_price:100.0))
    (elements_are
       [
         float_equal ~epsilon:1e-9 95.875;
         float_equal ~epsilon:1e-9 95.875;
         float_equal ~epsilon:1e-9 95.875;
         float_equal ~epsilon:1e-9 95.875;
         float_equal ~epsilon:1e-9 103.95;
         float_equal ~epsilon:1e-9 103.95;
       ])

let test_flag_counts_the_cycles _ =
  assert_that
    (final_correction_count ~config:unfrozen_config
       ~state:(fallback_initial_stop ~entry_price:100.0))
    (is_some_and (equal_to 2))

(* The flag does not weaken the phantom-cycle guard. A stale post-reset anchor
   ([correction_count > 0] with no counter-move touch since the reset) fails the
   cycle predicate outright, so it never reaches the [Stalled] branch the flag
   governs: no reset, no count, no stop move — identically under both configs.
   Guards the property [test_no_phantom_cycle_on_continuous_advance] pins for
   the default path. *)
let test_stale_anchor_still_blocked_under_flag _ =
  let state =
    Trailing
      {
        stop_level = 85.0;
        last_correction_extreme = 90.0;
        last_trend_extreme = 110.0;
        ma_at_last_adjustment = 92.0;
        correction_count = 1;
        correction_observed_since_reset = false;
      }
  in
  let advance config =
    update ~config ~side:Long ~state
      ~current_bar:(bar ~low:111.0 ~close:115.0)
      ~ma_value:95.0 ~ma_direction:Rising ~stage:stage2
  in
  assert_that
    [ advance frozen_config; advance unfrozen_config ]
    (elements_are
       [
         pair
           (matching ~msg:"Expected Trailing with the stale anchor intact"
              (function
                | Trailing { last_correction_extreme; correction_count; _ } ->
                    Some (last_correction_extreme, correction_count)
                | Initial _ | Tightened _ -> None)
              (pair (float_equal 90.0) (equal_to 1)))
           (equal_to (No_change : stop_event));
         pair
           (matching ~msg:"Expected Trailing with the stale anchor intact"
              (function
                | Trailing { last_correction_extreme; correction_count; _ } ->
                    Some (last_correction_extreme, correction_count)
                | Initial _ | Tightened _ -> None)
              (pair (float_equal 90.0) (equal_to 1)))
           (equal_to (No_change : stop_event));
       ])

let suite =
  "stop_ratchet_freeze"
  >::: [
         "fallback_seed_is_the_frozen_level"
         >:: test_fallback_seed_is_the_frozen_level;
         "fallback_stop_never_ratchets" >:: test_fallback_stop_never_ratchets;
         "no_correction_cycle_is_ever_counted"
         >:: test_no_correction_cycle_is_ever_counted;
         "structural_stop_ratchets_on_the_same_tape"
         >:: test_structural_stop_ratchets_on_the_same_tape;
         "flag_unfreezes_the_ratchet" >:: test_flag_unfreezes_the_ratchet;
         "flag_counts_the_cycles" >:: test_flag_counts_the_cycles;
         "stale_anchor_still_blocked_under_flag"
         >:: test_stale_anchor_still_blocked_under_flag;
       ]

let () = run_test_tt_main suite
