(* Walk-forward-mode helpers for bayesian_runner.exe. See
   bayesian_runner_wf_helpers.mli. *)
open Core
module Scenario = Scenario_lib.Scenario
module Wf_spec = Walk_forward.Spec
module Wf_executor = Walk_forward.Walk_forward_executor
module Wf_report = Walk_forward.Walk_forward_report
module Spec = Bayesian_runner_spec
module Oos_validator = Bayesian_runner_oos_validator

(** Label assigned to the best cell when it is re-executed end-to-end for OOS
    validation. Distinct from the [bo-iter-N] labels the evaluator's iteration
    counter emits during the BO loop. *)
let walk_forward_candidate_label = "bo-iter-best"

(** Synthetic scenario label injected into [bo_log.csv]'s [scenario] column in
    walk-forward mode (the Bayesian spec's own [scenarios] list is empty in
    production walk-forward specs). *)
let _walk_forward_scenarios_label = "walk-forward"

(** Load an [aggregate.sexp] file (the structured walk-forward report shape
    Phase 2 pinned). Used both for the BO scorer's [baseline_aggregate] arg and
    for OOS validation. *)
let load_aggregate path =
  try Wf_report.aggregate_of_sexp (Sexp.load_sexp path)
  with exn ->
    failwithf "bayesian_runner: failed to load aggregate.sexp %s: %s" path
      (Exn.to_string exn) ()

(** Synthesise a placeholder [scenarios] list of length 1 so the runner's
    [bo_log.csv] writer (which pairs scenarios with per-iteration metric_sets
    via [List.iter2_exn]) does not raise on the production walk-forward fixture
    (which carries [scenarios = []]). The evaluator returns
    [(score, [ metric_set ])] in walk-forward mode — exactly one element. *)
let wf_spec_with_placeholder_scenario (s : Spec.t) : Spec.t =
  { s with scenarios = [ _walk_forward_scenarios_label ] }

(** Re-execute the walk-forward sweep for the BO's best cell. Returns the
    fold_actuals list (per-fold, per-variant rows) that
    {!Oos_validator.validate} partitions into in-sample vs OOS slices. The
    [parallel] degree is threaded through so the OOS re-run fans out the same
    way the BO loop's per-iteration sweeps did. *)
let execute_best_cell_walk_forward ?(int_keys = [])
    ~(best_params : (string * float) list) ~(walk_forward_spec : Wf_spec.t)
    ~(base : Scenario.t) ~(fixtures_root : string) ~(parallel : int) () :
    Wf_report.fold_actual list =
  let candidate =
    {
      Walk_forward.Walk_forward_runner.label = walk_forward_candidate_label;
      overrides = Tuner.Grid_search.cell_to_overrides ~int_keys best_params;
    }
  in
  let two_variant_spec : Wf_spec.t =
    {
      walk_forward_spec with
      variants =
        [
          { label = walk_forward_spec.baseline_label; overrides = [] };
          candidate;
        ];
    }
  in
  eprintf
    "[bayesian_runner] re-running walk-forward on best cell for OOS validation \
     (parallel=%d)\n\
     %!"
    parallel;
  let result =
    Wf_executor.execute_spec ~base ~spec:two_variant_spec ~fixtures_root
      ~progress:Wf_executor.noop_progress ~parallel ()
  in
  result.fold_actuals

let write_oos_report ~(out_dir : string)
    ~(oos_result : Oos_validator.oos_result) ~(spec_path : string)
    ~(baseline_label : string) : unit =
  let path = Filename.concat out_dir "oos_report.md" in
  Oos_validator.write_report path oos_result ~spec_path ~baseline_label;
  eprintf "[bayesian_runner] wrote %s (verdict=%s)\n%!" path
    (Sexp.to_string (Oos_validator.sexp_of_verdict oos_result.verdict))
