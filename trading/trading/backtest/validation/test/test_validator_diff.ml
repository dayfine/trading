(** Unit tests for the cross-arm validator gate
    ({!Post_run_validator.Validator_diff}).

    The rule under test (issue #2730, ask 2): two arms of an experiment are a
    paired read only if their validator invariant counts agree. The motivating
    specimen is the 2026-09-08 item-3 stop-width surface, where a null arm with
    [V6 = 0] was compared against a map arm with [V6 = 6] twin-position
    violations — so what these tests mostly pin is that a difference is surfaced
    loudly (with the twin that caused it) and that nothing silently passes: a
    missing check id is an error, not an agreement. *)

open Core
open OUnit2
open Matchers
module Vt = Post_run_validator.Validator_types
module Vd = Post_run_validator.Validator_diff

let _no_join : Vt.audit_join = { matched = 0; total = 0 }

let _check ?(severity = Vt.Invariant) ?(specimens = []) ~id n_violations :
    Vt.check_result =
  {
    id;
    severity;
    passed = n_violations = 0;
    n_violations;
    n_skipped = 0;
    specimens;
  }

let _arm label checks : Vd.labeled_report =
  { label; report = { checks; audit_join = _no_join } }

(* The BFX/NLS pair from the a1-map-neutral8-s0 report: one instrument held
   twice under two tickers, which the wider stop kept alive in both. *)
let _twin : Vt.specimen =
  {
    symbol = "BFX";
    entry_date = "2020-04-22";
    detail = "twin positions: BFX/NLS";
  }

let _clean_pair =
  [ _arm "null" [ _check ~id:"V6" 0 ]; _arm "map" [ _check ~id:"V6" 0 ] ]

let _twin_pair =
  [
    _arm "null" [ _check ~id:"V6" 0 ];
    _arm "map" [ _check ~id:"V6" ~specimens:[ _twin ] 1 ];
  ]

let _row ~id ~counts ~agreed =
  all_of
    [
      field (fun (r : Vd.check_row) -> r.id) (equal_to id);
      field (fun (r : Vd.check_row) -> r.counts) (equal_to counts);
      field (fun (r : Vd.check_row) -> r.agreed) (equal_to agreed);
    ]

let test_equal_counts_agree _ =
  assert_that (Vd.compute _clean_pair)
    (is_ok_and_holds
       (all_of
          [
            field Vd.agreed (equal_to true);
            field
              (fun (t : Vd.t) -> t.rows)
              (elements_are
                 [
                   _row ~id:"V6"
                     ~counts:[ ("null", 0); ("map", 0) ]
                     ~agreed:true;
                 ]);
            field (fun (t : Vd.t) -> t.specimen_deltas) is_empty;
          ]))

let test_differing_counts_name_check_and_specimen _ =
  assert_that (Vd.compute _twin_pair)
    (is_ok_and_holds
       (all_of
          [
            field Vd.agreed (equal_to false);
            field
              (fun (t : Vd.t) -> t.rows)
              (elements_are
                 [
                   _row ~id:"V6"
                     ~counts:[ ("null", 0); ("map", 1) ]
                     ~agreed:false;
                 ]);
            field
              (fun (t : Vd.t) -> t.specimen_deltas)
              (elements_are
                 [
                   equal_to
                     ({
                        check_id = "V6";
                        specimen = _twin;
                        present_in = [ "map" ];
                      }
                       : Vd.specimen_delta);
                 ]);
          ]))

(* The rendered table is what an experiment chain's log actually shows, so the
   verdict word and the offending twin must both survive rendering. *)
let test_render_shows_verdict_and_twin _ =
  let rendered =
    match Vd.compute _twin_pair with
    | Ok t -> Vd.render t
    | Error err -> assert_failure ("compute failed: " ^ Status.show err)
  in
  assert_that rendered
    (all_of
       [
         contains_substring "V6";
         contains_substring "DIFFER";
         contains_substring "twin positions: BFX/NLS";
         contains_substring "only in: map";
       ])

let _v6_equal_v7_differing =
  [
    _arm "null" [ _check ~id:"V6" 0; _check ~id:"V7" 54 ];
    _arm "map" [ _check ~id:"V6" 0; _check ~id:"V7" 66 ];
  ]

let test_default_selection_flags_any_invariant _ =
  assert_that
    (Vd.compute _v6_equal_v7_differing)
    (is_ok_and_holds (field Vd.agreed (equal_to false)))

let test_check_filter_excludes_differing_v7 _ =
  assert_that
    (Vd.compute ~check_ids:[ "V6" ] _v6_equal_v7_differing)
    (is_ok_and_holds
       (all_of
          [
            field Vd.agreed (equal_to true);
            field
              (fun (t : Vd.t) -> t.rows)
              (elements_are
                 [
                   _row ~id:"V6"
                     ~counts:[ ("null", 0); ("map", 0) ]
                     ~agreed:true;
                 ]);
          ]))

let _v9_expectation_differing =
  [
    _arm "null"
      [ _check ~id:"V6" 0; _check ~severity:Vt.Expectation ~id:"V9" 3 ];
    _arm "map" [ _check ~id:"V6" 0; _check ~severity:Vt.Expectation ~id:"V9" 8 ];
  ]

let test_expectation_ignored_by_default _ =
  assert_that
    (Vd.compute _v9_expectation_differing)
    (is_ok_and_holds
       (all_of
          [
            field Vd.agreed (equal_to true);
            field
              (fun (t : Vd.t) -> t.rows)
              (elements_are
                 [
                   _row ~id:"V6"
                     ~counts:[ ("null", 0); ("map", 0) ]
                     ~agreed:true;
                 ]);
          ]))

let test_severity_all_includes_expectation _ =
  assert_that
    (Vd.compute ~severity:Vd.All_checks _v9_expectation_differing)
    (is_ok_and_holds (field Vd.agreed (equal_to false)))

(* The gate advertises an N-report compare ("at least two"), and the item-3
   surface it was built for has three arms. A two-arm fixture cannot tell that
   contract apart from one that silently drops everything past the second, so
   both three-arm cases below must go red if [compute] ever stops folding the
   later reports in. *)
let _three_clean_arms =
  [
    _arm "null" [ _check ~id:"V6" 0 ];
    _arm "map8" [ _check ~id:"V6" 0 ];
    _arm "map10" [ _check ~id:"V6" 0 ];
  ]

let test_three_reports_all_agree _ =
  assert_that
    (Vd.compute _three_clean_arms)
    (is_ok_and_holds
       (all_of
          [
            field Vd.agreed (equal_to true);
            field
              (fun (t : Vd.t) -> t.rows)
              (elements_are
                 [
                   _row ~id:"V6"
                     ~counts:[ ("null", 0); ("map8", 0); ("map10", 0) ]
                     ~agreed:true;
                 ]);
          ]))

(* [present_in] is only interesting for N > 2 — with two arms it is always a
   singleton, so the "strictly a subset of all labels" claim never gets
   exercised. Mirrors the real a0 / a1-map-neutral8 / a2-map-neutral10 read,
   where the BFX/NLS twin appeared in both map arms and not in the null. *)
let _twin_in_two_of_three =
  [
    _arm "null" [ _check ~id:"V6" 0 ];
    _arm "map8" [ _check ~id:"V6" ~specimens:[ _twin ] 1 ];
    _arm "map10" [ _check ~id:"V6" ~specimens:[ _twin ] 1 ];
  ]

let test_specimen_present_in_two_of_three_arms _ =
  assert_that
    (Vd.compute _twin_in_two_of_three)
    (is_ok_and_holds
       (all_of
          [
            field Vd.agreed (equal_to false);
            field
              (fun (t : Vd.t) -> t.rows)
              (elements_are
                 [
                   _row ~id:"V6"
                     ~counts:[ ("null", 0); ("map8", 1); ("map10", 1) ]
                     ~agreed:false;
                 ]);
            field
              (fun (t : Vd.t) -> t.specimen_deltas)
              (elements_are
                 [
                   equal_to
                     ({
                        check_id = "V6";
                        specimen = _twin;
                        present_in = [ "map8"; "map10" ];
                      }
                       : Vd.specimen_delta);
                 ]);
          ]))

let test_missing_check_is_an_error _ =
  assert_that
    (Vd.compute
       [
         _arm "null" [ _check ~id:"V6" 0; _check ~id:"V7" 0 ];
         _arm "map" [ _check ~id:"V6" 0 ];
       ])
    (is_error_with Status.NotFound)

let test_single_report_is_an_error _ =
  assert_that
    (Vd.compute [ _arm "null" [ _check ~id:"V6" 0 ] ])
    (is_error_with Status.Invalid_argument)

let test_unknown_check_filter_is_an_error _ =
  assert_that
    (Vd.compute ~check_ids:[ "V99" ] _clean_pair)
    (is_error_with Status.NotFound)

(* The reachable empty-selection route: every check in both reports is an
   [Expectation], so the default [Invariant_only] filter leaves nothing to
   compare. An unknown [-check] id does NOT land here — that is a non-empty
   selection which fails later as [NotFound] (the test above). *)
let test_all_expectation_checks_select_nothing _ =
  assert_that
    (Vd.compute
       [
         _arm "null" [ _check ~severity:Vt.Expectation ~id:"V9" 3 ];
         _arm "map" [ _check ~severity:Vt.Expectation ~id:"V9" 8 ];
       ])
    (is_error_with Status.Invalid_argument)

let suite =
  "validator_diff"
  >::: [
         "equal counts agree" >:: test_equal_counts_agree;
         "differing counts name check and specimen"
         >:: test_differing_counts_name_check_and_specimen;
         "render shows verdict and twin" >:: test_render_shows_verdict_and_twin;
         "default selection flags any invariant"
         >:: test_default_selection_flags_any_invariant;
         "check filter excludes differing V7"
         >:: test_check_filter_excludes_differing_v7;
         "expectation ignored by default"
         >:: test_expectation_ignored_by_default;
         "severity all includes expectation"
         >:: test_severity_all_includes_expectation;
         "three reports all agree" >:: test_three_reports_all_agree;
         "specimen present in two of three arms"
         >:: test_specimen_present_in_two_of_three_arms;
         "missing check is an error" >:: test_missing_check_is_an_error;
         "single report is an error" >:: test_single_report_is_an_error;
         "unknown check filter is an error"
         >:: test_unknown_check_filter_is_an_error;
         "all expectation checks select nothing"
         >:: test_all_expectation_checks_select_nothing;
       ]

let () = run_test_tt_main suite
