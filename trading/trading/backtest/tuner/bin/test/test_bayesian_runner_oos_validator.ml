(** Unit tests for {!Tuner_bin.Bayesian_runner_oos_validator}.

    Pins the no-overfit hurdle (plan
    [dev/plans/bayesian-multi-param-scaling-2026-05-16.md] §6.3) and the report
    renderer. The validator is pure — no I/O, no executor invocation — so each
    test hand-builds a list of {!Walk_forward.Walk_forward_types.fold_actual}
    rows and asserts on the resulting verdict + means.

    Coverage:

    - {!Validator.validate}: in-sample / OOS partitioning by 1-indexed fold
      position; mean Sharpe accuracy on each slice; gap sign + verdict mapping
      (Accept / Reject_overfit / Reject_insufficient_data); per-fold list shape.
    - {!Validator.render_report}: the markdown sections (title, summary,
      per-fold, verdict) appear and carry the expected numeric content. *)

open OUnit2
open Core
open Matchers
module Validator = Tuner_bin.Bayesian_runner_oos_validator
module Wf_types = Walk_forward.Walk_forward_types

(* ---------- shared helpers ---------- *)

let _epsilon = 1e-9
let _candidate_label = "bo-iter-best"
let _baseline_label = "cell-E"

(** Build one {!Wf_types.fold_actual} with only the fields the validator
    consumes. The other metric fields are set to zero — the validator filters by
    [variant_label] and means by [sharpe_ratio]; nothing else is read. *)
let _fa ~fold_name ~variant_label ~sharpe : Wf_types.fold_actual =
  {
    fold_name;
    variant_label;
    total_return_pct = 0.0;
    sharpe_ratio = sharpe;
    max_drawdown_pct = 0.0;
    calmar_ratio = 0.0;
    cagr_pct = Float.nan;
    avg_holding_days = Float.nan;
  }

(** Build N candidate-variant fold_actuals named "fold-000".."fold-(N-1)" with
    given per-fold sharpe values. The 1-indexed positions are 1..N. *)
let _make_candidate_rows sharpe_values =
  List.mapi sharpe_values ~f:(fun i s ->
      let fold_name = sprintf "fold-%03d" i in
      _fa ~fold_name ~variant_label:_candidate_label ~sharpe:s)

(* ---------- 1. Accept when gap is within hurdle ---------- *)

let test_accept_when_gap_within_hurdle _ =
  (* 5 in-sample folds (sharpe=1.0 each), 2 OOS folds (positions 6,7;
     sharpe=0.95 each). In-sample mean=1.0, OOS mean=0.95, gap=-0.05. Within
     the 0.10 hurdle → Accept. *)
  let rows = _make_candidate_rows [ 1.0; 1.0; 1.0; 1.0; 1.0; 0.95; 0.95 ] in
  let result =
    Validator.validate ~candidate_label:_candidate_label ~holdout_folds:[ 6; 7 ]
      ~fold_actuals:rows
  in
  assert_that result
    (all_of
       [
         field
           (fun (r : Validator.oos_result) -> r.verdict)
           (equal_to Validator.Accept);
         field
           (fun (r : Validator.oos_result) -> r.in_sample_mean_sharpe)
           (float_equal ~epsilon:_epsilon 1.0);
         field
           (fun (r : Validator.oos_result) -> r.oos_mean_sharpe)
           (float_equal ~epsilon:_epsilon 0.95);
         field
           (fun (r : Validator.oos_result) -> r.gap)
           (float_equal ~epsilon:_epsilon (-0.05));
         field
           (fun (r : Validator.oos_result) -> r.in_sample_fold_count)
           (equal_to 5);
         field (fun (r : Validator.oos_result) -> r.oos_fold_count) (equal_to 2);
       ])

(* ---------- 2. Reject_overfit when OOS drops more than hurdle ---------- *)

let test_reject_overfit_when_oos_drops _ =
  (* 4 in-sample folds (sharpe=1.2 each), 2 OOS folds (positions 5,6;
     sharpe=0.5 each). In-sample mean=1.2, OOS mean=0.5, gap=-0.7. |gap|>0.10
     → Reject_overfit. *)
  let rows = _make_candidate_rows [ 1.2; 1.2; 1.2; 1.2; 0.5; 0.5 ] in
  let result =
    Validator.validate ~candidate_label:_candidate_label ~holdout_folds:[ 5; 6 ]
      ~fold_actuals:rows
  in
  assert_that result
    (all_of
       [
         field
           (fun (r : Validator.oos_result) -> r.verdict)
           (equal_to Validator.Reject_overfit);
         field
           (fun (r : Validator.oos_result) -> r.gap)
           (float_equal ~epsilon:_epsilon (-0.7));
       ])

(* ---------- 3. Reject_overfit also fires when OOS spikes upward ---------- *)

let test_reject_overfit_when_oos_spikes_upward _ =
  (* The hurdle is on absolute gap, not signed. A +0.5 OOS surprise also
     trips Reject_overfit — the operator wants to investigate why, not
     silently accept. *)
  let rows = _make_candidate_rows [ 0.5; 0.5; 0.5; 1.5; 1.5 ] in
  let result =
    Validator.validate ~candidate_label:_candidate_label ~holdout_folds:[ 4; 5 ]
      ~fold_actuals:rows
  in
  assert_that result
    (all_of
       [
         field
           (fun (r : Validator.oos_result) -> r.verdict)
           (equal_to Validator.Reject_overfit);
         field
           (fun (r : Validator.oos_result) -> r.gap)
           (float_equal ~epsilon:_epsilon 1.0);
       ])

(* ---------- 4. Boundary case: gap just inside hurdle → Accept ---------- *)

let test_boundary_gap_just_inside_hurdle_accepts _ =
  (* Gap ≈ +0.099 (strictly less than the 0.10 hurdle in floating-point).
     The hurdle uses strict ">" so anything strictly less than 0.10 must
     Accept. We avoid testing exactly 0.10 because 1.1 - 1.0 is not
     bit-exact in IEEE-754; the strict-inequality boundary is what the
     production code's [Float.(abs gap > hurdle)] guarantees. *)
  let rows = _make_candidate_rows [ 1.0; 1.0; 1.099 ] in
  let result =
    Validator.validate ~candidate_label:_candidate_label ~holdout_folds:[ 3 ]
      ~fold_actuals:rows
  in
  assert_that result.verdict (equal_to Validator.Accept)

(* ---------- 5. Boundary case: gap just past hurdle → Reject ---------- *)

let test_boundary_gap_just_past_hurdle_rejects _ =
  (* Gap > 0.10 by 1e-3 → Reject. *)
  let rows = _make_candidate_rows [ 1.0; 1.0; 1.101 ] in
  let result =
    Validator.validate ~candidate_label:_candidate_label ~holdout_folds:[ 3 ]
      ~fold_actuals:rows
  in
  assert_that result.verdict (equal_to Validator.Reject_overfit)

(* ---------- 6. Reject_insufficient_data when no OOS folds match ---------- *)

let test_reject_insufficient_data_when_no_oos_folds _ =
  (* holdout_folds is empty: no OOS rows; verdict is Reject_insufficient_data
     regardless of in-sample shape. *)
  let rows = _make_candidate_rows [ 1.0; 1.0; 1.0 ] in
  let result =
    Validator.validate ~candidate_label:_candidate_label ~holdout_folds:[]
      ~fold_actuals:rows
  in
  assert_that result
    (all_of
       [
         field
           (fun (r : Validator.oos_result) -> r.verdict)
           (equal_to Validator.Reject_insufficient_data);
         field (fun (r : Validator.oos_result) -> r.oos_fold_count) (equal_to 0);
       ])

(* ---------- 7. holdout_folds positions beyond fold count are dropped ---------- *)

let test_holdout_positions_beyond_fold_count_silently_dropped _ =
  (* Only 3 candidate rows exist; holdout positions 27..30 (from the
     production spec) reference positions that don't exist. The validator
     drops them silently — verdict becomes Reject_insufficient_data. *)
  let rows = _make_candidate_rows [ 1.0; 1.0; 1.0 ] in
  let result =
    Validator.validate ~candidate_label:_candidate_label
      ~holdout_folds:[ 27; 28; 29; 30 ] ~fold_actuals:rows
  in
  assert_that result
    (all_of
       [
         field
           (fun (r : Validator.oos_result) -> r.verdict)
           (equal_to Validator.Reject_insufficient_data);
         field (fun (r : Validator.oos_result) -> r.oos_fold_count) (equal_to 0);
         field
           (fun (r : Validator.oos_result) -> r.in_sample_fold_count)
           (equal_to 3);
       ])

(* ---------- 8. Multi-variant rows: validator filters to candidate ---------- *)

let test_filters_to_candidate_variant _ =
  (* Mixed rows: baseline + candidate, each with 3 folds. The validator
     must use only the candidate rows for both means; the baseline rows
     are noise. *)
  let baseline_rows =
    List.init 3 ~f:(fun i ->
        _fa ~fold_name:(sprintf "fold-%03d" i) ~variant_label:_baseline_label
          ~sharpe:5.0)
  in
  let candidate_rows = _make_candidate_rows [ 1.0; 1.0; 0.95 ] in
  let mixed = baseline_rows @ candidate_rows in
  let result =
    Validator.validate ~candidate_label:_candidate_label ~holdout_folds:[ 3 ]
      ~fold_actuals:mixed
  in
  assert_that result
    (all_of
       [
         field
           (fun (r : Validator.oos_result) -> r.in_sample_mean_sharpe)
           (float_equal ~epsilon:_epsilon 1.0);
         field
           (fun (r : Validator.oos_result) -> r.oos_mean_sharpe)
           (float_equal ~epsilon:_epsilon 0.95);
       ])

(* ---------- 9. Per-OOS-fold list carries (name, sharpe) in order ---------- *)

let test_per_oos_fold_list_carries_names_and_sharpe _ =
  let rows = _make_candidate_rows [ 0.8; 0.9; 1.0; 1.1 ] in
  let result =
    Validator.validate ~candidate_label:_candidate_label ~holdout_folds:[ 2; 4 ]
      ~fold_actuals:rows
  in
  assert_that result.per_oos_fold
    (elements_are
       [
         all_of
           [
             field (fun (n, _) -> n) (equal_to "fold-001");
             field (fun (_, s) -> s) (float_equal ~epsilon:_epsilon 0.9);
           ];
         all_of
           [
             field (fun (n, _) -> n) (equal_to "fold-003");
             field (fun (_, s) -> s) (float_equal ~epsilon:_epsilon 1.1);
           ];
       ])

(* ---------- 10. Candidate label preserved in result ---------- *)

let test_candidate_label_preserved_in_result _ =
  let rows = _make_candidate_rows [ 1.0; 1.0; 0.95 ] in
  let result =
    Validator.validate ~candidate_label:_candidate_label ~holdout_folds:[ 3 ]
      ~fold_actuals:rows
  in
  assert_that result.candidate_label (equal_to _candidate_label)

(* ---------- 11. Render: report contains title + verdict tag ---------- *)

let test_render_report_includes_title_and_verdict _ =
  let rows = _make_candidate_rows [ 1.0; 1.0; 0.95 ] in
  let result =
    Validator.validate ~candidate_label:_candidate_label ~holdout_folds:[ 3 ]
      ~fold_actuals:rows
  in
  let md =
    Validator.render_report result ~spec_path:"/path/to/spec.sexp"
      ~baseline_label:_baseline_label
  in
  assert_that md
    (all_of
       [
         (* Title section *)
         matching ~msg:"title section present"
           (fun s ->
             if String.is_substring s ~substring:"# OOS validation report" then
               Some ()
             else None)
           (equal_to ());
         (* Spec path threaded through *)
         matching ~msg:"spec path present"
           (fun s ->
             if String.is_substring s ~substring:"/path/to/spec.sexp" then
               Some ()
             else None)
           (equal_to ());
         (* Verdict block tag *)
         matching ~msg:"verdict ACCEPT tag present"
           (fun s ->
             if String.is_substring s ~substring:"ACCEPT" then Some () else None)
           (equal_to ());
       ])

(* ---------- 12. Render: Reject_overfit message present ---------- *)

let test_render_report_reject_overfit_message _ =
  let rows = _make_candidate_rows [ 1.2; 1.2; 0.4 ] in
  let result =
    Validator.validate ~candidate_label:_candidate_label ~holdout_folds:[ 3 ]
      ~fold_actuals:rows
  in
  let md =
    Validator.render_report result ~spec_path:"spec.sexp"
      ~baseline_label:_baseline_label
  in
  assert_that md
    (matching ~msg:"REJECT over-fit message present"
       (fun s ->
         if String.is_substring s ~substring:"REJECT (over-fit" then Some ()
         else None)
       (equal_to ()))

(* ---------- 13. Render: per-fold table rows present ---------- *)

let test_render_report_per_fold_rows_present _ =
  let rows = _make_candidate_rows [ 1.0; 1.0; 0.95; 0.93 ] in
  let result =
    Validator.validate ~candidate_label:_candidate_label ~holdout_folds:[ 3; 4 ]
      ~fold_actuals:rows
  in
  let md =
    Validator.render_report result ~spec_path:"spec.sexp"
      ~baseline_label:_baseline_label
  in
  assert_that md
    (all_of
       [
         matching ~msg:"fold-002 row present"
           (fun s ->
             if String.is_substring s ~substring:"`fold-002`" then Some ()
             else None)
           (equal_to ());
         matching ~msg:"fold-003 row present"
           (fun s ->
             if String.is_substring s ~substring:"`fold-003`" then Some ()
             else None)
           (equal_to ());
       ])

(* ---------- 14. Render: Reject_insufficient_data message present ---------- *)

let test_render_report_insufficient_data_message _ =
  let rows = _make_candidate_rows [ 1.0; 1.0 ] in
  let result =
    Validator.validate ~candidate_label:_candidate_label ~holdout_folds:[]
      ~fold_actuals:rows
  in
  let md =
    Validator.render_report result ~spec_path:"spec.sexp"
      ~baseline_label:_baseline_label
  in
  assert_that md
    (matching ~msg:"insufficient-data verdict present"
       (fun s ->
         if String.is_substring s ~substring:"insufficient data" then Some ()
         else None)
       (equal_to ()))

let suite =
  "Tuner_bin.Bayesian_runner_oos_validator"
  >::: [
         "Accept when |gap| within hurdle"
         >:: test_accept_when_gap_within_hurdle;
         "Reject_overfit when OOS Sharpe drops too far"
         >:: test_reject_overfit_when_oos_drops;
         "Reject_overfit also fires on upward OOS spike"
         >:: test_reject_overfit_when_oos_spikes_upward;
         "Boundary case: gap just inside +0.10 -> Accept"
         >:: test_boundary_gap_just_inside_hurdle_accepts;
         "Boundary case: gap just past +0.10 -> Reject_overfit"
         >:: test_boundary_gap_just_past_hurdle_rejects;
         "Reject_insufficient_data when no OOS folds match"
         >:: test_reject_insufficient_data_when_no_oos_folds;
         "holdout positions beyond fold count silently dropped"
         >:: test_holdout_positions_beyond_fold_count_silently_dropped;
         "validator filters to candidate variant"
         >:: test_filters_to_candidate_variant;
         "per_oos_fold list carries (name, sharpe) in order"
         >:: test_per_oos_fold_list_carries_names_and_sharpe;
         "candidate_label preserved in result"
         >:: test_candidate_label_preserved_in_result;
         "render_report: title + verdict tag present"
         >:: test_render_report_includes_title_and_verdict;
         "render_report: Reject_overfit message"
         >:: test_render_report_reject_overfit_message;
         "render_report: per-OOS-fold rows present"
         >:: test_render_report_per_fold_rows_present;
         "render_report: Reject_insufficient_data message"
         >:: test_render_report_insufficient_data_message;
       ]

let () = run_test_tt_main suite
