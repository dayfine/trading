(** The buffer-fallback initial stop lands 2.08% below entry — roughly half the
    book's §5.3 flat-stop band of 4-6%.

    {b Why this file exists when [test_support_floor.ml] already covers the
       fallback path.} That coverage pins the reference {i convention} — it
    rebuilds the expectation from its own local [1.02] literal, so a direction
    flip in [floor_stop._fallback_reference] {i would} break it. What it cannot
    express is whether the resulting stop {b width} is in-band: it is
    hand-re-baselined against whatever the convention currently produces, and no
    assertion anywhere related the produced distance to the book's §5.3 band.
    The too-narrow predicate survived in the element with the most tests
    ([feedback_pin_every_element_of_a_category]). This file pins the width
    itself — the absolute distance against the band — which is the independent
    predicate the existing tests lack.

    {b The chain, exact.} With no qualifying counter-move in the bar history the
    reference falls back to [entry *. fallback_buffer], which for a {i long}
    sits {b above} the entry — then [compute_initial_stop] takes
    [min_correction_pct /. 2.] off that inflated level:

    {v
      delta     = min_correction_pct / 2 = 0.08 / 2 = 0.04
      reference = entry * initial_stop_buffer      = entry * 1.02
      stop      = reference * (1 - delta)          = entry * 0.9792
                                                   -> 2.08% below entry
    v}

    A support level, which is what this reference stands in for, sits {i below}
    a long's entry. Pushing it up by 1.02 and then subtracting 4% is what halves
    the intended stop.

    {b Provenance.} [entry = 153.98] is the real ADP 2019-02-22 entry from the
    6-month inspection run; its audit record shows
    [installed_stop 150.77721599999998] with [stop_floor_kind Buffer_fallback],
    and the value below reproduces it exactly from the config defaults alone —
    no bar fixture required, because the fallback path never reads the bars.

    {b Why it matters.} In that run the fallback stop covered 42 of 59 trades;
    19 of the 24 [stop_loss] exits fell on the exact 0.0208 fallback width (23
    of 24 within the <=5% tight cohort) at a 17% win rate, accounting for
    essentially the whole arm's loss. This file pins the {i arithmetic}, not a
    P&L claim.

    {b This test is expected to change.} It characterises current behaviour so
    that any change to the fallback direction fires loudly. When the fix lands,
    update the pinned constants and move the band assertion from "below the book
    minimum" to "inside the book band". *)

open OUnit2
open Core
open Matchers
open Trading_base.Types
open Weinstein_stops

(* The strategy layer's [initial_stop_buffer] default
   ([Weinstein_strategy_config], 1.02) — the value actually threaded into the
   fallback on the production path. *)
let fallback_buffer = 1.02

(* Real ADP 2019-02-22 entry (E = local_range_top 153.21 * the screener's 0.5%
   buffer, cent-rounded). *)
let adp_entry = 153.98

(* Book §5.3 flat initial stop when no structural floor qualifies. *)
let book_band_low = 0.04
let book_band_high = 0.06
let config = default_config

(* No bars => no qualifying counter-move => the fallback reference is used. *)
let empty_callbacks =
  callbacks_from_bars ~config ~bars:[] ~as_of:(Date.of_string "2019-02-22")

let stop_distance_pct ~side ~entry_price =
  let state =
    compute_initial_stop_with_floor_with_callbacks ~config ~side ~entry_price
      ~callbacks:empty_callbacks ~fallback_buffer
  in
  Float.abs (get_stop_level state -. entry_price) /. entry_price

(* The exact level, reproduced from config defaults alone. Pins the whole chain
   in one number: 153.98 * 1.02 * 0.96. *)
let test_adp_fallback_level_is_exact _ =
  let state =
    compute_initial_stop_with_floor_with_callbacks ~config ~side:Long
      ~entry_price:adp_entry ~callbacks:empty_callbacks ~fallback_buffer
  in
  assert_that (get_stop_level state) (float_equal ~epsilon:1e-9 150.777216)

(* The independent predicate the convention tests cannot express: the
   resulting distance is BELOW the book's flat-stop minimum. *)
let test_long_fallback_is_below_book_band _ =
  assert_that
    (stop_distance_pct ~side:Long ~entry_price:adp_entry)
    (all_of
       [ float_equal ~epsilon:1e-9 0.0208; lt (module Float_ord) book_band_low ])

(* Symmetric on the short side: entry /. buffer then +4% => ~1.96%. With this
   entry the raw level lands exactly on 157.00, so the round-number nudge
   (0.125, away from the position) fires too: 153.98 * 1.04 / 1.02 = 157.0,
   nudged to 157.125 => 2.0425%. Pinned so a one-sided fix cannot pass
   unnoticed. *)
let test_short_fallback_is_below_book_band _ =
  let state =
    compute_initial_stop_with_floor_with_callbacks ~config ~side:Short
      ~entry_price:adp_entry ~callbacks:empty_callbacks ~fallback_buffer
  in
  assert_that (get_stop_level state) (float_equal ~epsilon:1e-9 157.125);
  assert_that
    (stop_distance_pct ~side:Short ~entry_price:adp_entry)
    (lt (module Float_ord) book_band_low)

(* Isolates the 1.02 as the cause rather than the 4% haircut: feeding the
   un-inflated reference through the SAME [compute_initial_stop] yields exactly
   the book minimum, and the un-inflated-the-other-way reference yields 5.88%.
   Both land inside the band, so the direction of the buffer is the whole
   defect. *)
let test_reference_direction_is_the_cause _ =
  let dist_from ~reference_level =
    let state = compute_initial_stop ~config ~side:Long ~reference_level in
    Float.abs (get_stop_level state -. adp_entry) /. adp_entry
  in
  assert_that
    [
      dist_from ~reference_level:adp_entry;
      dist_from ~reference_level:(adp_entry /. fallback_buffer);
    ]
    (elements_are
       [
         float_equal ~epsilon:1e-9 0.04;
         (* 1 - 0.96/1.02 *)
         float_equal ~epsilon:1e-9 0.058823529412;
       ]);
  assert_that
    (dist_from ~reference_level:(adp_entry /. fallback_buffer))
    (is_between (module Float_ord) ~low:book_band_low ~high:book_band_high)

let suite =
  "fallback_stop_width"
  >::: [
         "adp_fallback_level_is_exact" >:: test_adp_fallback_level_is_exact;
         "long_fallback_is_below_book_band"
         >:: test_long_fallback_is_below_book_band;
         "short_fallback_is_below_book_band"
         >:: test_short_fallback_is_below_book_band;
         "reference_direction_is_the_cause"
         >:: test_reference_direction_is_the_cause;
       ]

let () = run_test_tt_main suite
