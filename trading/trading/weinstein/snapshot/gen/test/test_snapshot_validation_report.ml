(** Tests for {!Snapshot_validation_report} — the warn-first packaging of
    validator findings at the [generate_weekly_snapshot] seam (issue #2122 slice
    a).

    The classification of findings is {!Weinstein_snapshot.Snapshot_validator}'s
    job and is tested there; what is pinned here is the packaging contract:
    - no findings -> quiet OK line, exit 0 (both modes);
    - findings -> a delimited block that names each finding, exit 0 under
      warn-first and exit 1 under [strict];
    - [strict] escalates a {e warning}, not just an error, so the chart-coverage
      class (#2122 defect 1) can fail a Friday run. *)

open Core
open OUnit2
open Matchers
module Report = Weinstein_snapshot_gen.Snapshot_validation_report
module Validator = Weinstein_snapshot.Snapshot_validator

let _warning : Validator.finding =
  {
    level = Warning;
    symbol = Some "CPK";
    check = "chart_coverage";
    detail = "0 bars";
  }

let _error : Validator.finding =
  {
    level = Error;
    symbol = Some "MBX";
    check = "reconciliation_class";
    detail = "class disagrees with overshoot";
  }

let test_no_findings_is_quiet_ok _ =
  assert_that
    (Report.evaluate ~strict:false [])
    (equal_to
       ({ report = "snapshot-validator: OK — no findings.\n"; exit_code = 0 }
         : Report.outcome))

let test_no_findings_never_fails_even_strict _ =
  assert_that
    (Report.evaluate ~strict:true [])
    (field (fun o -> o.Report.exit_code) (equal_to 0))

let test_warn_first_reports_but_does_not_fail _ =
  assert_that
    (Report.evaluate ~strict:false [ _error; _warning ])
    (all_of
       [
         field (fun o -> o.Report.exit_code) (equal_to 0);
         field
           (fun o ->
             String.is_substring o.Report.report
               ~substring:"2 finding(s): 1 error(s), 1 warning(s)")
           (equal_to true);
         field
           (fun o ->
             String.is_substring o.Report.report
               ~substring:"ERROR MBX reconciliation_class")
           (equal_to true);
         field
           (fun o ->
             String.is_substring o.Report.report
               ~substring:"WARN CPK chart_coverage")
           (equal_to true);
       ])

let test_strict_fails_on_any_finding _ =
  assert_that
    (Report.evaluate ~strict:true [ _error ])
    (field (fun o -> o.Report.exit_code) (equal_to 1))

(* The load-bearing case: a warning-only snapshot (e.g. chart-coverage gap)
   must still fail under strict — that is the point of the flag for Fridays. *)
let test_strict_fails_on_warning_only _ =
  assert_that
    (Report.evaluate ~strict:true [ _warning ])
    (field (fun o -> o.Report.exit_code) (equal_to 1))

let suite =
  "snapshot_validation_report"
  >::: [
         "no_findings_is_quiet_ok" >:: test_no_findings_is_quiet_ok;
         "no_findings_never_fails_even_strict"
         >:: test_no_findings_never_fails_even_strict;
         "warn_first_reports_but_does_not_fail"
         >:: test_warn_first_reports_but_does_not_fail;
         "strict_fails_on_any_finding" >:: test_strict_fails_on_any_finding;
         "strict_fails_on_warning_only" >:: test_strict_fails_on_warning_only;
       ]

let () = run_test_tt_main suite
