(** AXTI 2025-06-27 — the entry construction that the 15% stop-width gate
    rejected 21 times, pinned against the symbol's real bars.

    {b Why this is a unit test and not a scenario.} A [goldens-small] scenario
    cannot reproduce this decision: a small universe changes ranking, sector RS
    and the macro gate, so the candidate would be admitted or dropped for
    reasons that have nothing to do with the thing under test. What {i is}
    pinnable is the arithmetic chain from bars to gate verdict, and that chain
    is what the 2026-08-16 dissection actually turned on.

    {b Provenance of the fixture.} The 17 weekly bars below are the real AXTI
    weekly aggregation of [data/A/I/AXTI/data.csv] over 2025-03-03..2025-06-27,
    re-derived from the raw daily CSV independently of any audit artifact
    ([dev/notes/axti-entry-construction-from-raw-bars-2026-08-18.md]). The 2.70
    high is a single day — 2025-06-12 traded 6.81M shares against a ~300k
    average, i.e. the breakout bar itself.

    {b What is pinned, and why each matters.}
    - The anchor: a 4-bar local range window over these highs is 2.70, so the
      recorded [local_range_top] is reproducible from public bars.
    - The entry: [E = 2.71] via {!Screener_scoring.suggested_entry} — the range
      top plus the screener's 0.5% buffer, cent-rounded.
    - The gate: at every stop the {i book} would place — anywhere in the
      1.13-1.47 base band — the distance from [E] is 33.6-58.3%, so
      [Drop_over_max] refuses the candidate, [Size_down] admits it shrunken and
      [Demote_over_max] admits it demoted.
    - The general claim: the required 15% stop level sits
      {b above the decision week's own low}, so no structural stop can satisfy
      the gate. The exclusion is arithmetic, not a risk judgement — which is the
      finding this file exists to keep true.

    This pins the construction, {b not} a claim that admitting AXTI would have
    been right. The counterfactual is untested; what is settled is that the
    argument is about the ceiling, not about the anchor or the classifier. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy

(* Real AXTI weekly highs, most recent LAST. *)
let _weekly_highs =
  [
    (* 2025-03-07 *)
    1.655;
    (* 2025-03-14 *)
    1.81;
    (* 2025-03-21 *)
    1.8984;
    (* 2025-03-28 *)
    1.83;
    (* 2025-04-04 *)
    1.55;
    (* 2025-04-11 *)
    1.48;
    (* 2025-04-17 *)
    1.27;
    (* 2025-04-25 *)
    1.45;
    (* 2025-05-02 *)
    1.57;
    (* 2025-05-09 *)
    1.39;
    (* 2025-05-16 *)
    1.55;
    (* 2025-05-23 *)
    1.61;
    (* 2025-05-30 *)
    1.6;
    (* 2025-06-06 *)
    1.83;
    (* 2025-06-13 *)
    2.7;
    (* 2025-06-20 *)
    2.18;
    (* 2025-06-27 *)
    2.2301;
  ]

(* The base the book would anchor a stop under. Its floor is the April-May
   consolidation — 1.13 on 2025-04-11 and 04-17. The upper bound 1.47 is the
   week ending 2025-06-06, i.e. the last correction low BEFORE the breakout
   rather than part of April-May itself; it is included because §5.1 anchors on
   "the prior correction low", and 06-06 is that low. So the pair brackets every
   level the book could reasonably choose, not one contiguous consolidation. *)
let _base_low = 1.13
let _base_high_low = 1.47

(* The decision week's own low — the floor of what "inside this week's range"
   even means. *)
let _decision_week_low = 1.8

(* Scans are indexed by [week_offset], 0 = most recent. *)
let _get_high ~week_offset = List.nth (List.rev _weekly_highs) week_offset

(* No split boundary in the window, so truncation is a no-op. *)
let _get_split_factor ~week_offset:_ = None

let _range_top ~weeks =
  Stock_analysis_scans.scan_max_high ~get_high:_get_high
    ~get_split_factor:_get_split_factor ~base_end_offset:0 ~base_lookback:weeks

(* The entry is derived by calling the screener's own function rather than
   mirroring its arithmetic, so a change to the derivation (buffer, rounding)
   fails here instead of silently diverging from the thing being pinned.
   [suggested_entry] rounds to cents, which is why the audit records 2.71 and
   not the unrounded 2.7135. *)
let _entry_of range_top =
  Screener_scoring.suggested_entry
    ~entry_buffer_pct:Screener.default_candidate_params.entry_buffer_pct
    range_top

let _max_stop_distance_pct = 0.15
let _distance_from_entry ~entry ~stop = (entry -. stop) /. entry

let _gate ~mode ~ceiling ~stop_distance_pct =
  Stop_width_mode.gate
    ~policy:{ Stop_width_mode.mode; size_down_max_pct = ceiling }
    ~max_stop_distance_pct:_max_stop_distance_pct ~stop_distance_pct

(** The anchor reproduces from public bars: the 4-bar window ending on the
    decision week spans 2025-06-06..06-27, whose highs are 1.83 / 2.70 / 2.18 /
    2.2301. Its max is the 2.70 breakout bar.

    Asserted alongside the 1-bar window, which pins the {i window boundary}
    rather than the max-vs-last-bar distinction: with [weeks = 1] the scan must
    see only the decision week and return its 2.2301 high. An off-by-one that
    widened the window to two bars would return 2.70 and fail here, while still
    passing the 4-bar assertion below — so the pair brackets the window from
    both sides. (A last-bar bug is already caught by the 4-bar case, whose max
    2.70 is not its newest bar.) *)
let test_local_range_top_is_the_breakout_bar _ =
  assert_that
    [ _range_top ~weeks:1; _range_top ~weeks:4 ]
    (elements_are
       [ is_some_and (float_equal 2.2301); is_some_and (float_equal 2.7) ])

(** [E] is the range top plus the screener's entry buffer: 2.70 * 1.005 =
    2.7135, cent-rounded by {!Screener_scoring.suggested_entry} to {b 2.71} —
    the value the audit records. Calling the real function rather than mirroring
    its arithmetic means a change to buffer or rounding fails here. *)
let test_entry_is_the_range_top_plus_the_band _ =
  let range_top = Option.value_exn (_range_top ~weeks:4) in
  assert_that (_entry_of range_top) (float_equal 2.71)

(** Every stop the book could place is far outside the 15% limit. The base runs
    1.13-1.47, and even the decision week's own low — which is not a base at all
    — is 33.6% away.

    This is the load-bearing arithmetic: it is not that a particular stop
    happened to be wide, it is that the whole admissible region is. *)
let test_every_book_faithful_stop_is_far_outside_the_limit _ =
  let entry = _entry_of (Option.value_exn (_range_top ~weeks:4)) in
  assert_that
    (List.map [ _base_low; _base_high_low; _decision_week_low ] ~f:(fun stop ->
         _distance_from_entry ~entry ~stop))
    (elements_are
       [
         float_equal ~epsilon:1e-3 0.583;
         float_equal ~epsilon:1e-3 0.4576;
         float_equal ~epsilon:1e-3 0.3358;
       ])

(** The gate's required stop level sits ABOVE the decision week's own low, so no
    structural stop can satisfy it — a stop at 2.3035 would be inside the week's
    trading range (low 1.80), which is not a support level in any sense the book
    recognises.

    This is the claim that generalises: a stock that runs ~50% off its base in
    three weeks has a book-faithful stop more than 15% below its breakout
    {b by arithmetic}, so [max_stop_distance_pct] selects against fast movers
    off deep bases rather than against risk as such. *)
let test_the_required_stop_is_inside_the_weeks_own_range _ =
  let entry = _entry_of (Option.value_exn (_range_top ~weeks:4)) in
  let required_stop = entry *. (1.0 -. _max_stop_distance_pct) in
  assert_that
    [ required_stop; required_stop -. _decision_week_low ]
    (elements_are
       [
         float_equal ~epsilon:1e-3 2.3035;
         (* strictly positive ⇒ the required stop is ABOVE the week's low *)
         float_equal ~epsilon:1e-3 0.5035;
       ])

(** The three modes' verdicts at AXTI's real base-anchored distance (58.3% from
    the 1.13 base low), with a sanity ceiling above it.

    [Drop_over_max] is what the record arm runs, and it is what produced the 21
    [Stop_too_wide] rejections. The other two admit the same candidate — one by
    shrinking its size, one by demoting its rank — which is the whole
    behavioural surface the F3 axis explores. *)
let test_three_modes_disagree_on_this_candidate _ =
  let entry = _entry_of (Option.value_exn (_range_top ~weeks:4)) in
  let stop_distance_pct = _distance_from_entry ~entry ~stop:_base_low in
  assert_that
    (List.map
       [
         Stop_width_mode.Drop_over_max;
         Stop_width_mode.Size_down;
         Stop_width_mode.Demote_over_max;
       ] ~f:(fun mode -> _gate ~mode ~ceiling:0.9 ~stop_distance_pct))
    (elements_are
       [
         equal_to (Stop_width_mode.Drop : Stop_width_mode.outcome);
         equal_to (Stop_width_mode.Admit_sized_down : Stop_width_mode.outcome);
         equal_to (Stop_width_mode.Admit : Stop_width_mode.outcome);
       ])

(** Even the two non-default modes refuse it once the sanity ceiling is below
    the real distance — 58.3% is outside a 50% ceiling. So "arm [Size_down] and
    AXTI gets in" is only true for a ceiling chosen wide enough to admit it, and
    the ceiling is the actual dial under discussion. *)
let test_a_tight_ceiling_refuses_it_under_every_mode _ =
  let entry = _entry_of (Option.value_exn (_range_top ~weeks:4)) in
  let stop_distance_pct = _distance_from_entry ~entry ~stop:_base_low in
  assert_that
    (List.map
       [
         Stop_width_mode.Drop_over_max;
         Stop_width_mode.Size_down;
         Stop_width_mode.Demote_over_max;
       ] ~f:(fun mode -> _gate ~mode ~ceiling:0.5 ~stop_distance_pct))
    (elements_are
       [
         equal_to (Stop_width_mode.Drop : Stop_width_mode.outcome);
         equal_to (Stop_width_mode.Drop : Stop_width_mode.outcome);
         equal_to (Stop_width_mode.Drop : Stop_width_mode.outcome);
       ])

let suite =
  "axti_entry_construction"
  >::: [
         "local range top is the breakout bar"
         >:: test_local_range_top_is_the_breakout_bar;
         "entry is the range top plus the band"
         >:: test_entry_is_the_range_top_plus_the_band;
         "every book-faithful stop is far outside the limit"
         >:: test_every_book_faithful_stop_is_far_outside_the_limit;
         "the required stop is inside the week's own range"
         >:: test_the_required_stop_is_inside_the_weeks_own_range;
         "three modes disagree on this candidate"
         >:: test_three_modes_disagree_on_this_candidate;
         "a tight ceiling refuses it under every mode"
         >:: test_a_tight_ceiling_refuses_it_under_every_mode;
       ]

let () = run_test_tt_main suite
