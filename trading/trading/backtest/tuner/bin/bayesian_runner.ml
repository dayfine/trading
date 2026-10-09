(** Bayesian-optimisation CLI — wires {!Tuner.Bayesian_opt}'s ask/tell loop to a
    {!Backtest.Runner.run_backtest}-backed evaluator. Reads a spec sexp file
    describing per-parameter bounds, the acquisition function, the objective to
    maximise, and either:

    - the list of scenario sexp files to evaluate each suggested point against
      (legacy per-scenario mode), or
    - a walk-forward spec + a baseline aggregate.sexp (Phase-3 walk-forward
      mode, per plan §7 PR-E of
      [dev/plans/bayesian-multi-param-scaling-2026-05-16.md]).

    Writes [bo_log.csv], [best.sexp], and [convergence.md] in both modes; the
    walk-forward mode additionally writes [oos_report.md] after the BO
    converges, by re-running the walk-forward executor on the best cell and
    feeding the per-fold results to
    {!Tuner_bin.Bayesian_runner_oos_validator.validate}.

    Usage:

    {v
      bayesian_runner.exe --spec <spec.sexp> --out-dir <dir>
                          [--fixtures-root <path>]
                          [--parallel N]    (default 1, max 16)
                          [--walk-forward-spec <spec.sexp>
                           --baseline-aggregate <aggregate.sexp>]
    v}

    [--spec] — path to a Bayesian spec sexp file in the shape declared by
    {!Tuner_bin.Bayesian_runner_spec.t}. The example shape is documented in that
    module's [.mli].

    [--out-dir] — directory the writers create. Created with [mkdir -p].

    [--fixtures-root] — directory each scenario's [universe_path] is resolved
    against. Defaults to [TRADING_DATA_DIR/backtest_scenarios] via
    {!Scenario_lib.Fixtures_root.resolve}, matching [scenario_runner.exe] and
    [grid_search.exe].

    [--walk-forward-spec] and [--baseline-aggregate] — when both are supplied,
    the binary switches to walk-forward mode: each BO suggestion drives one
    walk-forward CV sweep via
    {!Tuner_bin.Bayesian_runner_evaluator.build_walk_forward}, scored by
    {!Tuner_bin.Bayesian_runner_scoring.score_cell} against the supplied
    [baseline_aggregate]. After the BO completes, the binary re-runs the best
    cell on the full window and partitions the per-fold results against the BO
    spec's [holdout_folds] for OOS validation. The Bayesian spec's own
    [scenarios] list is ignored in walk-forward mode (the production fixture
    leaves it empty); the binary synthesises a single "walk-forward" scenario
    label for the [bo_log.csv] writer's per-row column.

    [--parallel N] (default [1], max [Fork_pool.max_parallel] = 16) controls
    fan-out of the (variant, fold) grid inside each BO iteration. The BO loop
    itself remains serial (each iteration's score informs the next acquisition);
    only the walk-forward CV grid parallelises. With 5 folds × 2 variants = 10
    cells per iteration, [--parallel 4] processes them in 3 batches of 4 + 1
    batch of 2. Plan #1197 §7 PR-3. *)

open Core
module Scenario = Scenario_lib.Scenario
module Fixtures_root = Scenario_lib.Fixtures_root
module Spec = Tuner_bin.Bayesian_runner_spec
module Evaluator = Tuner_bin.Bayesian_runner_evaluator
module Runner = Tuner_bin.Bayesian_runner_runner
module Wf_spec = Walk_forward.Spec
module Wf_window = Walk_forward.Window_spec
module Wf_executor = Walk_forward.Walk_forward_executor
module Oos_validator = Tuner_bin.Bayesian_runner_oos_validator
module Out_dir_check = Tuner_bin.Bayesian_runner_out_dir_check
module Successive_halving = Tuner_bin.Bayesian_runner_successive_halving
module Cli = Tuner_bin.Bayesian_runner_cli
module Wf_helpers = Tuner_bin.Bayesian_runner_wf_helpers

let _usage_msg = Cli.usage_msg

(* -------------- legacy per-scenario mode -------------- *)

let _load_scenarios paths =
  let table = Hashtbl.create (module String) in
  List.iter paths ~f:(fun p ->
      let s = Scenario.load p in
      Hashtbl.set table ~key:p ~data:s);
  table

let _run_legacy_mode ~(args : Cli.cli_args) ~(spec : Spec.t) =
  let fixtures_root =
    Fixtures_root.resolve ?fixtures_root:args.fixtures_root ()
  in
  let scenarios_by_path = _load_scenarios spec.scenarios in
  let objective = Spec.to_grid_objective spec.objective in
  let obj_label = Tuner.Grid_search.objective_label objective in
  eprintf
    "[bayesian_runner] mode=legacy; loaded %d scenario(s); total_budget=%d; \
     initial_random=%d; objective=%s\n\
     %!"
    (List.length spec.scenarios)
    spec.total_budget spec.initial_random obj_label;
  let evaluator =
    Evaluator.build ~fixtures_root ~scenarios:spec.scenarios ~scenarios_by_path
      ~objective
  in
  let result = Runner.run_and_write ~spec ~out_dir:args.out_dir ~evaluator in
  eprintf "[bayesian_runner] best_score=%.6f best_params=%s\n%!"
    result.best_score
    (Sexp.to_string
       (Sexp.List
          (Tuner.Grid_search.cell_to_overrides ~int_keys:spec.int_keys
             result.best_params)));
  eprintf "[bayesian_runner] outputs written under %s\n%!" args.out_dir

(* -------------- walk-forward mode (PR-E) -------------- *)

let _run_walk_forward_mode ~(args : Cli.cli_args) ~(spec : Spec.t)
    ~(walk_forward_spec_path : string) ~(baseline_aggregate_path : string) =
  let fixtures_root =
    Fixtures_root.resolve ?fixtures_root:args.fixtures_root ()
  in
  let walk_forward_spec = Wf_spec.load walk_forward_spec_path in
  let base_scenario_path =
    Filename.concat fixtures_root walk_forward_spec.base_scenario
  in
  let base = Scenario.load base_scenario_path in
  let baseline_aggregate = Wf_helpers.load_aggregate baseline_aggregate_path in
  let holdout_folds = Option.value spec.holdout_folds ~default:[] in
  let objective = Spec.to_grid_objective spec.objective in
  let obj_label = Tuner.Grid_search.objective_label objective in
  eprintf
    "[bayesian_runner] mode=walk-forward; total_budget=%d; initial_random=%d; \
     bounds=%d; holdout_folds=%d; parallel=%d; objective=%s\n\
     %!"
    spec.total_budget spec.initial_random (List.length spec.bounds)
    (List.length holdout_folds)
    args.parallel obj_label;
  let gate_penalty_value = Option.value spec.gate_penalty_value ~default:10.0 in
  let evaluator : Runner.evaluator =
    Evaluator.build_walk_forward ~gate_penalty_value ~int_keys:spec.int_keys
      ~executor:(Evaluator.make_executor ~parallel:args.parallel ())
      ~base ~walk_forward_spec ~baseline_aggregate ~objective ~fixtures_root ()
  in
  let runner_spec = Wf_helpers.wf_spec_with_placeholder_scenario spec in
  let result =
    Runner.run_and_write ~spec:runner_spec ~out_dir:args.out_dir ~evaluator
  in
  eprintf "[bayesian_runner] best_score=%.6f best_params=%s\n%!"
    result.best_score
    (Sexp.to_string
       (Sexp.List
          (Tuner.Grid_search.cell_to_overrides ~int_keys:spec.int_keys
             result.best_params)));
  (* OOS validation: re-run walk-forward on the best cell, partition the
     per-fold results, emit oos_report.md. *)
  let fold_actuals =
    Wf_helpers.execute_best_cell_walk_forward ~int_keys:spec.int_keys
      ~best_params:result.best_params ~walk_forward_spec ~base ~fixtures_root
      ~parallel:args.parallel ()
  in
  let oos_result =
    Oos_validator.validate
      ~candidate_label:Wf_helpers.walk_forward_candidate_label ~holdout_folds
      ~fold_actuals
  in
  Wf_helpers.write_oos_report ~out_dir:args.out_dir ~oos_result
    ~spec_path:args.spec_path ~baseline_label:walk_forward_spec.baseline_label;
  eprintf "[bayesian_runner] outputs written under %s\n%!" args.out_dir

(* -------------- successive-halving mode (M1 T1.2) -------------- *)

(** Extract a [tiered_spec] from a walk-forward [Wf_spec.t] or fail fast.
    Successive halving requires a [Tiered] window_spec — using a [Rolling] /
    [Explicit] spec is a clear operator mistake (the SH loop has no meaning
    without per-tier fold-counts). *)
let _require_tiered (wf : Wf_spec.t) : Wf_window.tiered_spec =
  match wf.window_spec with
  | Tiered ts -> ts
  | Rolling _ | Explicit _ ->
      eprintf
        "Error: --fidelity-strategy successive_halving requires a Tiered \
         window_spec in the walk-forward spec (Rolling/Explicit are not \
         supported by the SH pipeline).\n\
         %s\n"
        _usage_msg;
      Stdlib.exit 1

let _run_successive_halving_mode ~(args : Cli.cli_args) ~(spec : Spec.t)
    ~(walk_forward_spec_path : string) ~(baseline_aggregate_path : string) =
  let fixtures_root =
    Fixtures_root.resolve ?fixtures_root:args.fixtures_root ()
  in
  let walk_forward_spec = Wf_spec.load walk_forward_spec_path in
  let tiered = _require_tiered walk_forward_spec in
  let base_scenario_path =
    Filename.concat fixtures_root walk_forward_spec.base_scenario
  in
  let base = Scenario.load base_scenario_path in
  let baseline_aggregate = Wf_helpers.load_aggregate baseline_aggregate_path in
  let objective = Spec.to_grid_objective spec.objective in
  let obj_label = Tuner.Grid_search.objective_label objective in
  eprintf
    "[bayesian_runner] mode=successive_halving; total_budget=%d; \
     initial_random=%d; bounds=%d; tiers=%d; parallel=%d; objective=%s\n\
     %!"
    spec.total_budget spec.initial_random (List.length spec.bounds)
    (List.length tiered.tiers) args.parallel obj_label;
  let gate_penalty_value = Option.value spec.gate_penalty_value ~default:10.0 in
  let executor = Evaluator.make_executor ~parallel:args.parallel () in
  let build_evaluator ~(walk_forward_spec : Wf_spec.t) =
    Evaluator.build_walk_forward ~gate_penalty_value ~int_keys:spec.int_keys
      ~executor ~base ~walk_forward_spec ~baseline_aggregate ~objective
      ~fixtures_root ()
  in
  let result =
    Successive_halving.run ~spec ~tiered
      ~walk_forward_spec_template:walk_forward_spec ~build_evaluator
      ~out_dir:args.out_dir ()
  in
  eprintf "[bayesian_runner] best_score=%.6f best_params=%s\n%!"
    result.best_score
    (Sexp.to_string
       (Sexp.List
          (Tuner.Grid_search.cell_to_overrides ~int_keys:spec.int_keys
             result.best_params)));
  eprintf "[bayesian_runner] outputs written under %s\n%!" args.out_dir

let _main () =
  let argv = Sys.get_argv () |> Array.to_list |> List.tl_exn in
  let args = Cli.parse_args argv in
  (* Belt-and-suspenders even if launch_sweep.sh was bypassed. *)
  Out_dir_check.validate_or_exit ~out_dir:args.out_dir;
  let spec = Spec.load args.spec_path in
  match
    ( args.fidelity_strategy,
      args.walk_forward_spec_path,
      args.baseline_aggregate_path )
  with
  | Cli.Single, None, None -> _run_legacy_mode ~args ~spec
  | Cli.Single, Some wf_path, Some baseline_path ->
      _run_walk_forward_mode ~args ~spec ~walk_forward_spec_path:wf_path
        ~baseline_aggregate_path:baseline_path
  | Cli.Successive_halving, Some wf_path, Some baseline_path ->
      _run_successive_halving_mode ~args ~spec ~walk_forward_spec_path:wf_path
        ~baseline_aggregate_path:baseline_path
  | Cli.Successive_halving, _, _ ->
      eprintf
        "Error: --fidelity-strategy successive_halving requires both \
         --walk-forward-spec and --baseline-aggregate\n\
         %s\n"
        _usage_msg;
      Stdlib.exit 1
  | Cli.Single, _, _ ->
      eprintf
        "Error: --walk-forward-spec and --baseline-aggregate must be supplied \
         together\n\
         %s\n"
        _usage_msg;
      Stdlib.exit 1

let () = _main ()
