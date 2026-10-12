(** Pins the contracts of the helpers extracted from [bayesian_runner.exe] by
    #3233: {!Tuner_bin.Bayesian_runner_cli.parse_args} defaults, and the
    walk-forward helpers in {!Tuner_bin.Bayesian_runner_wf_helpers}. *)

open OUnit2
open Core
open Matchers
module Cli = Tuner_bin.Bayesian_runner_cli
module Wf = Tuner_bin.Bayesian_runner_wf_helpers
module Spec = Tuner_bin.Bayesian_runner_spec

let test_parse_args_defaults _ =
  assert_that
    (Cli.parse_args [ "--spec"; "s.sexp"; "--out-dir"; "o" ])
    (all_of
       [
         field (fun (a : Cli.cli_args) -> a.spec_path) (equal_to "s.sexp");
         field (fun (a : Cli.cli_args) -> a.out_dir) (equal_to "o");
         field (fun (a : Cli.cli_args) -> a.parallel) (equal_to 1);
         field
           (fun (a : Cli.cli_args) -> a.fidelity_strategy)
           (equal_to Cli.Single);
         field
           (fun (a : Cli.cli_args) -> a.fixtures_root)
           (equal_to (None : string option));
         field
           (fun (a : Cli.cli_args) -> a.walk_forward_spec_path)
           (equal_to (None : string option));
         field
           (fun (a : Cli.cli_args) -> a.baseline_aggregate_path)
           (equal_to (None : string option));
       ])

let test_parse_args_all_flags _ =
  assert_that
    (Cli.parse_args
       [
         "--spec";
         "s.sexp";
         "--out-dir";
         "o";
         "--parallel";
         "4";
         "--walk-forward-spec";
         "wf.sexp";
         "--baseline-aggregate";
         "agg.sexp";
         "--fidelity-strategy";
         "successive_halving";
         "--fixtures-root";
         "fx";
       ])
    (all_of
       [
         field (fun (a : Cli.cli_args) -> a.spec_path) (equal_to "s.sexp");
         field (fun (a : Cli.cli_args) -> a.out_dir) (equal_to "o");
         field (fun (a : Cli.cli_args) -> a.parallel) (equal_to 4);
         field
           (fun (a : Cli.cli_args) -> a.walk_forward_spec_path)
           (equal_to (Some "wf.sexp"));
         field
           (fun (a : Cli.cli_args) -> a.baseline_aggregate_path)
           (equal_to (Some "agg.sexp"));
         field
           (fun (a : Cli.cli_args) -> a.fidelity_strategy)
           (equal_to Cli.Successive_halving);
         field
           (fun (a : Cli.cli_args) -> a.fixtures_root)
           (equal_to (Some "fx"));
       ])

let test_walk_forward_candidate_label _ =
  assert_that Wf.walk_forward_candidate_label (equal_to "bo-iter-best")

let test_placeholder_scenario _ =
  let spec : Spec.t =
    {
      bounds = [ ("k", (0.1, 0.5)) ];
      acquisition = Spec.Expected_improvement;
      initial_random = 5;
      total_budget = 30;
      seed = None;
      n_acquisition_candidates = None;
      objective = Spec.Sharpe;
      scenarios = [ "a"; "b" ];
      holdout_folds = None;
      sentinel_bounds = None;
      length_scales = None;
      early_stop = None;
      gate_penalty_value = None;
      int_keys = [ "k"; "unbound" ];
    }
  in
  assert_that
    (Wf.wf_spec_with_placeholder_scenario spec)
    (equal_to ({ spec with scenarios = [ "walk-forward" ] } : Spec.t))

let test_load_aggregate_error_message _ =
  let path = "/nonexistent/aggregate.sexp" in
  let msg =
    try
      let _ = Wf.load_aggregate path in
      ""
    with Failure m -> m
  in
  let expected_prefix =
    "bayesian_runner: failed to load aggregate.sexp " ^ path ^ ": "
  in
  assert_that
    (String.prefix msg (String.length expected_prefix))
    (equal_to expected_prefix)

let suite =
  "bayesian_runner_cli_helpers"
  >::: [
         "parse_args defaults" >:: test_parse_args_defaults;
         "parse_args all flags" >:: test_parse_args_all_flags;
         "walk_forward_candidate_label" >:: test_walk_forward_candidate_label;
         "placeholder scenario" >:: test_placeholder_scenario;
         "load_aggregate error message" >:: test_load_aggregate_error_message;
       ]

let () = run_test_tt_main suite
