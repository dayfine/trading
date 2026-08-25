(** The buffer-fallback initial stop lands 4% below entry — the floor of the
    book's §5.3 flat-stop band of 4-6%.

    {b Why this file exists when [test_support_floor.ml] already covers the
       fallback path.} That coverage pins the reference {i convention} — it
    rebuilds the expectation from its own local buffer literal, so a direction
    flip in [floor_stop._fallback_reference] {i would} break it. What it cannot
    express is whether the resulting stop {b width} is in-band: it is
    hand-re-baselined against whatever the convention currently produces, and no
    other assertion relates the produced distance to the book's §5.3 band. The
    too-narrow predicate survived in the element with the most tests
    ([feedback_pin_every_element_of_a_category]). This file pins the width
    itself — the absolute distance against the band — which is the independent
    predicate the existing tests lack.

    {b The chain, exact.} With no qualifying counter-move in the bar history the
    reference falls back to [entry *. fallback_buffer]; at the shipped [1.0]
    that is the entry price itself, and [compute_initial_stop] then takes
    [min_correction_pct /. 2.] off it:

    {v
      delta     = min_correction_pct / 2 = 0.08 / 2 = 0.04
      reference = entry * initial_stop_buffer      = entry * 1.0
      stop      = reference * (1 - delta)          = entry * 0.96
                                                   -> 4.00% below entry
    v}

    {b The defect this file was written for, and its fix.} Until 2026-08-24 the
    default was [1.02], which pushed the reference {i above} a long's entry
    before the 4% haircut and so produced a 2.08% stop — roughly {i half} the
    book band, on what
    [dev/agent-memory/project_fallback_stop_half_book_band.md] measures as the
    common path (88.7% of entries take the fallback; issue #2486). The flip to
    [1.0] moves the width from below the band to its low edge. The old
    arithmetic is still pinned, as the counterfactual, by
    [test_legacy_inflated_reference_was_the_cause] — a support level, which is
    what this reference stands in for, sits {i below} a long's entry, so
    inflating it and then subtracting 4% is what halved the stop.

    {b Provenance.} [entry = 153.98] is the real ADP 2019-02-22 entry from the
    6-month inspection run; its audit record under the old default showed
    [installed_stop 150.77721599999998] with [stop_floor_kind Buffer_fallback].
    Both the old and new levels below reproduce from config values alone — no
    bar fixture required, because the fallback path never reads the bars.

    {b Why it matters.} In that run the fallback stop covered 42 of 59 trades;
    19 of the 24 [stop_loss] exits fell on the exact 0.0208 fallback width (23
    of 24 within the <=5% tight cohort) at a 17% win rate, accounting for
    essentially the whole arm's loss. This file pins the {i arithmetic}, not a
    P&L claim. *)

open OUnit2
open Core
open Matchers
open Trading_base.Types
open Weinstein_stops

(* The strategy layer's [initial_stop_buffer] default
   ([Weinstein_strategy_config], 1.0 since 2026-08-24) — the value actually
   threaded into the fallback on the production path. Mirrored rather than
   imported: the stops library sits below the strategy layer. *)
let fallback_buffer = 1.0

(* The pre-2026-08-24 default, kept as the counterfactual reference multiplier
   in [test_legacy_inflated_reference_was_the_cause]. *)
let legacy_buffer = 1.02

(* Real ADP 2019-02-22 entry (E = local_range_top 153.21 * the screener's 0.5%
   buffer, cent-rounded). *)
let adp_entry = 153.98

(* Book §5.3 flat initial stop when no structural floor qualifies. *)
let book_band_low = 0.04
let book_band_high = 0.06

(* [entry *. 0.96] does not divide back to exactly [0.04] in binary — the
   measured distance is 0.039999999999999994, one ULP under the band edge.
   Band membership is therefore asserted against tolerance-widened edges, so the
   assertion is about the BAND and not about which side of 4% the last bit
   lands on. The exact width is pinned separately by [float_equal]. *)
let band_epsilon = 1e-9
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

let in_book_band =
  is_between
    (module Float_ord)
    ~low:(book_band_low -. band_epsilon)
    ~high:(book_band_high +. band_epsilon)

(* The exact level, reproduced from config defaults alone. Pins the whole chain
   in one number: 153.98 * 1.0 * 0.96. No round-number nudge fires — the raw
   level sits 0.1792 from the nearest half-dollar (148.00), outside the 0.125
   nudge distance. *)
let test_adp_fallback_level_is_exact _ =
  let state =
    compute_initial_stop_with_floor_with_callbacks ~config ~side:Long
      ~entry_price:adp_entry ~callbacks:empty_callbacks ~fallback_buffer
  in
  assert_that (get_stop_level state) (float_equal ~epsilon:1e-9 147.8208)

(* The independent predicate the convention tests cannot express: the resulting
   distance sits INSIDE the book's flat-stop band, at its low edge. *)
let test_long_fallback_is_in_book_band _ =
  assert_that
    (stop_distance_pct ~side:Long ~entry_price:adp_entry)
    (all_of [ float_equal ~epsilon:1e-9 book_band_low; in_book_band ])

(* Symmetric on the short side: entry /. buffer then +4%. At buffer 1.0 the
   reference is the entry itself, so the level is 153.98 * 1.04 = 160.1392 —
   0.1392 from the nearest half-dollar (160.00), again outside the 0.125 nudge
   distance, so no round-number nudge fires. Pinned so a one-sided fix cannot
   pass unnoticed. *)
let test_short_fallback_is_in_book_band _ =
  let state =
    compute_initial_stop_with_floor_with_callbacks ~config ~side:Short
      ~entry_price:adp_entry ~callbacks:empty_callbacks ~fallback_buffer
  in
  assert_that (get_stop_level state) (float_equal ~epsilon:1e-9 160.1392);
  assert_that
    (stop_distance_pct ~side:Short ~entry_price:adp_entry)
    (all_of [ float_equal ~epsilon:1e-9 book_band_low; in_book_band ])

(* Isolates the old 1.02 as the cause rather than the 4% haircut: feeding the
   INFLATED reference through the SAME [compute_initial_stop] reproduces the
   pre-fix 150.777216 / 2.08% below-band stop, while the shipped un-inflated
   reference yields exactly the book minimum. The direction of the buffer was
   the whole defect; the haircut was always the book's. *)
let test_legacy_inflated_reference_was_the_cause _ =
  let stop_from ~reference_level =
    get_stop_level (compute_initial_stop ~config ~side:Long ~reference_level)
  in
  let dist_from ~reference_level =
    Float.abs (stop_from ~reference_level -. adp_entry) /. adp_entry
  in
  assert_that
    (stop_from ~reference_level:(adp_entry *. legacy_buffer))
    (float_equal ~epsilon:1e-9 150.777216);
  assert_that
    [
      dist_from ~reference_level:(adp_entry *. legacy_buffer);
      dist_from ~reference_level:(adp_entry *. fallback_buffer);
    ]
    (elements_are
       [
         all_of
           [
             float_equal ~epsilon:1e-9 0.0208;
             lt (module Float_ord) book_band_low;
           ];
         all_of [ float_equal ~epsilon:1e-9 book_band_low; in_book_band ];
       ])

let suite =
  "fallback_stop_width"
  >::: [
         "adp_fallback_level_is_exact" >:: test_adp_fallback_level_is_exact;
         "long_fallback_is_in_book_band" >:: test_long_fallback_is_in_book_band;
         "short_fallback_is_in_book_band"
         >:: test_short_fallback_is_in_book_band;
         "legacy_inflated_reference_was_the_cause"
         >:: test_legacy_inflated_reference_was_the_cause;
       ]

let () = run_test_tt_main suite
