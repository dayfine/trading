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
module Wf_executor = Walk_forward.Walk_forward_executor
module Wf_report = Walk_forward.Walk_forward_report
module Oos_validator = Tuner_bin.Bayesian_runner_oos_validator

let _usage_msg =
  "Usage: bayesian_runner.exe --spec <spec.sexp> --out-dir <dir>\n\
  \  [--fixtures-root <path>]\n\
  \  [--parallel N]    (default 1, max 16)\n\
  \  [--walk-forward-spec <spec.sexp> --baseline-aggregate <aggregate.sexp>]"

(** Default [--parallel] value. [1] preserves the pre-#1197 sequential path
    bit-exactly (no fork, no marshal). *)
let _default_parallel = 1

(** Parse and validate the [--parallel N] flag at CLI time. Out-of-range values
    would otherwise surface from inside [Fork_pool.run_parallel] as an
    [Invalid_argument] after the spec has loaded — failing fast at parse time
    gives the operator a clearer error. *)
let _parse_parallel raw =
  let n =
    try Int.of_string raw
    with _ ->
      eprintf "Error: --parallel expects an integer, got %S\n%s\n" raw
        _usage_msg;
      Stdlib.exit 1
  in
  if n < 1 || n > Fork_pool.max_parallel then begin
    eprintf "Error: --parallel must be in [1, %d], got %d\n%s\n"
      Fork_pool.max_parallel n _usage_msg;
    Stdlib.exit 1
  end;
  n

(** Label assigned to the best cell when it is re-executed end-to-end for OOS
    validation. Distinct from the [bo-iter-N] labels the evaluator's iteration
    counter emits during the BO loop. *)
let _walk_forward_candidate_label = "bo-iter-best"

(** Synthetic scenario label injected into [bo_log.csv]'s [scenario] column in
    walk-forward mode (the Bayesian spec's own [scenarios] list is empty in
    production walk-forward specs). *)
let _walk_forward_scenarios_label = "walk-forward"

type cli_args = {
  spec_path : string;
  out_dir : string;
  fixtures_root : string option;
  walk_forward_spec_path : string option;
  baseline_aggregate_path : string option;
  parallel : int;
}

let _parse_args argv =
  let rec loop spec out fixtures wf_spec baseline parallel = function
    | [] -> (
        match (spec, out) with
        | Some s, Some o ->
            {
              spec_path = s;
              out_dir = o;
              fixtures_root = fixtures;
              walk_forward_spec_path = wf_spec;
              baseline_aggregate_path = baseline;
              parallel = Option.value parallel ~default:_default_parallel;
            }
        | _ ->
            eprintf "%s\n" _usage_msg;
            Stdlib.exit 1)
    | "--spec" :: p :: rest ->
        loop (Some p) out fixtures wf_spec baseline parallel rest
    | "--out-dir" :: p :: rest ->
        loop spec (Some p) fixtures wf_spec baseline parallel rest
    | "--fixtures-root" :: p :: rest ->
        loop spec out (Some p) wf_spec baseline parallel rest
    | "--walk-forward-spec" :: p :: rest ->
        loop spec out fixtures (Some p) baseline parallel rest
    | "--baseline-aggregate" :: p :: rest ->
        loop spec out fixtures wf_spec (Some p) parallel rest
    | "--parallel" :: n :: rest ->
        loop spec out fixtures wf_spec baseline (Some (_parse_parallel n)) rest
    | "--help" :: _ | "-h" :: _ ->
        printf "%s\n" _usage_msg;
        Stdlib.exit 0
    | unknown :: _ ->
        eprintf "Error: unknown argument %S\n%s\n" unknown _usage_msg;
        Stdlib.exit 1
  in
  loop None None None None None None argv

(* -------------- legacy per-scenario mode -------------- *)

let _load_scenarios paths =
  let table = Hashtbl.create (module String) in
  List.iter paths ~f:(fun p ->
      let s = Scenario.load p in
      Hashtbl.set table ~key:p ~data:s);
  table

let _run_legacy_mode ~(args : cli_args) ~(spec : Spec.t) =
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
       (Sexp.List (Tuner.Grid_search.cell_to_overrides result.best_params)));
  eprintf "[bayesian_runner] outputs written under %s\n%!" args.out_dir

(* -------------- walk-forward mode (PR-E) -------------- *)

(** Load an [aggregate.sexp] file (the structured walk-forward report shape
    Phase 2 pinned). Used both for the BO scorer's [baseline_aggregate] arg and
    for OOS validation. *)
let _load_aggregate path =
  try Wf_report.aggregate_of_sexp (Sexp.load_sexp path)
  with exn ->
    failwithf "bayesian_runner: failed to load aggregate.sexp %s: %s" path
      (Exn.to_string exn) ()

(** Synthesise a placeholder [scenarios] list of length 1 so the runner's
    [bo_log.csv] writer (which pairs scenarios with per-iteration metric_sets
    via [List.iter2_exn]) does not raise on the production walk-forward fixture
    (which carries [scenarios = []]). The evaluator returns
    [(score, [ metric_set ])] in walk-forward mode — exactly one element. *)
let _wf_spec_with_placeholder_scenario (s : Spec.t) : Spec.t =
  { s with scenarios = [ _walk_forward_scenarios_label ] }

(** Re-execute the walk-forward sweep for the BO's best cell. Returns the
    fold_actuals list (per-fold, per-variant rows) that
    {!Oos_validator.validate} partitions into in-sample vs OOS slices. The
    [parallel] degree is threaded through so the OOS re-run fans out the same
    way the BO loop's per-iteration sweeps did. *)
let _execute_best_cell_walk_forward ~(best_params : (string * float) list)
    ~(walk_forward_spec : Wf_spec.t) ~(base : Scenario.t)
    ~(fixtures_root : string) ~(parallel : int) : Wf_report.fold_actual list =
  let candidate =
    {
      Walk_forward.Walk_forward_runner.label = _walk_forward_candidate_label;
      overrides = Tuner.Grid_search.cell_to_overrides best_params;
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

let _write_oos_report ~(out_dir : string)
    ~(oos_result : Oos_validator.oos_result) ~(spec_path : string)
    ~(baseline_label : string) : unit =
  let path = Filename.concat out_dir "oos_report.md" in
  Oos_validator.write_report path oos_result ~spec_path ~baseline_label;
  eprintf "[bayesian_runner] wrote %s (verdict=%s)\n%!" path
    (Sexp.to_string (Oos_validator.sexp_of_verdict oos_result.verdict))

let _run_walk_forward_mode ~(args : cli_args) ~(spec : Spec.t)
    ~(walk_forward_spec_path : string) ~(baseline_aggregate_path : string) =
  let fixtures_root =
    Fixtures_root.resolve ?fixtures_root:args.fixtures_root ()
  in
  let walk_forward_spec = Wf_spec.load walk_forward_spec_path in
  let base_scenario_path =
    Filename.concat fixtures_root walk_forward_spec.base_scenario
  in
  let base = Scenario.load base_scenario_path in
  let baseline_aggregate = _load_aggregate baseline_aggregate_path in
  let holdout_folds = Option.value spec.holdout_folds ~default:[] in
  eprintf
    "[bayesian_runner] mode=walk-forward; total_budget=%d; initial_random=%d; \
     bounds=%d; holdout_folds=%d; parallel=%d\n\
     %!"
    spec.total_budget spec.initial_random (List.length spec.bounds)
    (List.length holdout_folds)
    args.parallel;
  let evaluator : Runner.evaluator =
    Evaluator.build_walk_forward
      ~executor:(Evaluator.make_executor ~parallel:args.parallel ())
      ~base ~walk_forward_spec ~baseline_aggregate ~fixtures_root ()
  in
  let runner_spec = _wf_spec_with_placeholder_scenario spec in
  let result =
    Runner.run_and_write ~spec:runner_spec ~out_dir:args.out_dir ~evaluator
  in
  eprintf "[bayesian_runner] best_score=%.6f best_params=%s\n%!"
    result.best_score
    (Sexp.to_string
       (Sexp.List (Tuner.Grid_search.cell_to_overrides result.best_params)));
  (* OOS validation: re-run walk-forward on the best cell, partition the
     per-fold results, emit oos_report.md. *)
  let fold_actuals =
    _execute_best_cell_walk_forward ~best_params:result.best_params
      ~walk_forward_spec ~base ~fixtures_root ~parallel:args.parallel
  in
  let oos_result =
    Oos_validator.validate ~candidate_label:_walk_forward_candidate_label
      ~holdout_folds ~fold_actuals
  in
  _write_oos_report ~out_dir:args.out_dir ~oos_result ~spec_path:args.spec_path
    ~baseline_label:walk_forward_spec.baseline_label;
  eprintf "[bayesian_runner] outputs written under %s\n%!" args.out_dir

let _main () =
  let argv = Sys.get_argv () |> Array.to_list |> List.tl_exn in
  let args = _parse_args argv in
  let spec = Spec.load args.spec_path in
  match (args.walk_forward_spec_path, args.baseline_aggregate_path) with
  | None, None -> _run_legacy_mode ~args ~spec
  | Some wf_path, Some baseline_path ->
      _run_walk_forward_mode ~args ~spec ~walk_forward_spec_path:wf_path
        ~baseline_aggregate_path:baseline_path
  | _ ->
      eprintf
        "Error: --walk-forward-spec and --baseline-aggregate must be supplied \
         together\n\
         %s\n"
        _usage_msg;
      Stdlib.exit 1

let () = _main ()
