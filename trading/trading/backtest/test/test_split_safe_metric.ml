(** Tests for {!Backtest.Split_safe_metric} — the inert-fraction reduction over
    [Trade_audit.split_safe_basis].

    The contract under test is B6: an arm in which no decision reached the basis
    choice yields an {b undefined} [0/0], and rendering that as a blank (or as
    [0.0], or as [nan]) makes it indistinguishable from "this telemetry column
    was never wired up". Those two states demand opposite responses, so the
    reduction names the undefined case and carries the tally that says which it
    is. These tests pin (a) that the undefined case is named rather than
    numeric, (b) that its two causes stay distinguishable, and (c) that
    [Empty_window] / [Flag_off] are excluded from both terms of the ratio. *)

open OUnit2
open Matchers
module M = Backtest.Split_safe_metric
module TA = Backtest.Trade_audit

let _inertness bases = M.inertness_of_tally (M.tally_of_bases bases)
let _repeat n basis = List.init n (fun _ -> basis)

(* Counting is the input to everything below, so pin it directly rather than
   only through the ratio — a mis-routed constructor (e.g. [Empty_window]
   incrementing [raw_fallback]) would otherwise show up only as a wrong
   fraction, several inferences away from its cause. *)
let test_tally_counts_every_state _ =
  assert_that
    (M.tally_of_bases
       [
         TA.Flag_off;
         TA.Adjusted;
         TA.Adjusted;
         TA.Raw_fallback;
         TA.Raw_fallback;
         TA.Raw_fallback;
         TA.Empty_window;
       ])
    (equal_to
       ({ flag_off = 1; adjusted = 2; raw_fallback = 3; empty_window = 1 }
         : M.tally))

(* B6, the headline case. Every decision was a non-event, so the ratio has a
   zero denominator. The result must be the named [Not_exercised], never a
   number: an arm with no exposure to the mechanism carries no evidence about
   it and must not be read as "0% inert". *)
let test_all_empty_window_is_not_exercised _ =
  assert_that
    (_inertness (_repeat 4 TA.Empty_window))
    (equal_to
       (M.Not_exercised
          { flag_off = 0; adjusted = 0; raw_fallback = 0; empty_window = 4 }
         : M.inertness))

(* The other zero-denominator cause, and the one B6 says a blank cell is
   mistaken for. Both this and the case above are [Not_exercised], so the
   constructor alone cannot separate them — the carried tally is what does, and
   this asserts the two results are different values. In an arm configured
   [split_safe_floors true] this shape is a wiring alarm; the all-[Empty_window]
   shape above is a data-coverage problem. Opposite responses. *)
let test_all_flag_off_distinguishable_from_all_empty_window _ =
  assert_that
    (_inertness (_repeat 4 TA.Flag_off), _inertness (_repeat 4 TA.Empty_window))
    (all_of
       [
         field fst
           (equal_to
              (M.Not_exercised
                 {
                   flag_off = 4;
                   adjusted = 0;
                   raw_fallback = 0;
                   empty_window = 0;
                 }
                : M.inertness));
         field snd
           (equal_to
              (M.Not_exercised
                 {
                   flag_off = 0;
                   adjusted = 0;
                   raw_fallback = 0;
                   empty_window = 4;
                 }
                : M.inertness));
       ])

(* The third zero-denominator cause: nothing was recorded at all. Also
   [Not_exercised], and its all-zero tally distinguishes it from both above. *)
let test_empty_population_is_not_exercised _ =
  assert_that (_inertness [])
    (equal_to (M.Not_exercised M.empty_tally : M.inertness))

(* The defined case: one decision in four degraded to raw. *)
let test_mixed_population_reports_the_ratio _ =
  assert_that
    (_inertness [ TA.Adjusted; TA.Adjusted; TA.Adjusted; TA.Raw_fallback ])
    (equal_to (M.Inert_fraction 0.25 : M.inertness))

(* "Excluded from BOTH terms", pinned rather than only documented: padding a
   population with non-events and flag-off rows leaves the fraction untouched.
   Counting either into the denominator would drag 0.25 down; counting either
   into the numerator would push it up. *)
let test_non_events_excluded_from_both_terms _ =
  assert_that
    (_inertness
       ([ TA.Adjusted; TA.Adjusted; TA.Adjusted; TA.Raw_fallback ]
       @ _repeat 20 TA.Empty_window @ _repeat 12 TA.Flag_off))
    (equal_to (M.Inert_fraction 0.25 : M.inertness))

(* The fully-inert arm: every decision reached the basis choice and every one
   degraded. This measured baseline while appearing to test the flag — a real,
   damning reading — and must not collapse into [Not_exercised], which means the
   opposite (no reading at all). *)
let test_all_raw_fallback_is_fully_inert _ =
  assert_that
    (_inertness (_repeat 3 TA.Raw_fallback))
    (equal_to (M.Inert_fraction 1.0 : M.inertness))

(* The mechanism working everywhere. Pinned so that "0.0" is reachable and is
   therefore never a safe rendering for the undefined case. *)
let test_all_adjusted_is_zero_inert _ =
  assert_that
    (_inertness (_repeat 3 TA.Adjusted))
    (equal_to (M.Inert_fraction 0.0 : M.inertness))

let suite =
  "Split_safe_metric"
  >::: [
         "tally counts every basis state" >:: test_tally_counts_every_state;
         "all Empty_window is Not_exercised, not a number"
         >:: test_all_empty_window_is_not_exercised;
         "all Flag_off stays distinguishable from all Empty_window"
         >:: test_all_flag_off_distinguishable_from_all_empty_window;
         "empty population is Not_exercised"
         >:: test_empty_population_is_not_exercised;
         "mixed population reports the ratio"
         >:: test_mixed_population_reports_the_ratio;
         "Empty_window and Flag_off are excluded from both terms"
         >:: test_non_events_excluded_from_both_terms;
         "all Raw_fallback is fully inert, not unexercised"
         >:: test_all_raw_fallback_is_fully_inert;
         "all Adjusted is zero inert" >:: test_all_adjusted_is_zero_inert;
       ]

let () = run_test_tt_main suite
