(** Bayesian-optimisation CLI — wires {!Tuner.Bayesian_opt}'s ask/tell loop to a
    {!Backtest.Runner.run_backtest}-backed evaluator. Reads a spec sexp file
    describing per-parameter bounds, the acquisition function, the objective to
    maximise, and the list of scenario sexp files to evaluate each suggested
    point against; writes [bo_log.csv], [best.sexp], and [convergence.md] under
    the requested output directory.

    Usage:

    {v
      bayesian_runner.exe --spec <spec.sexp> --out-dir <dir>
                          [--fixtures-root <path>]
    v}

    [--spec] — path to a sexp file in the shape declared by
    {!Tuner_bin.Bayesian_runner_spec.t}. The example shape is documented in that
    module's [.mli].

    [--out-dir] — directory the writers create. Created with [mkdir -p].

    [--fixtures-root] — directory each scenario's [universe_path] is resolved
    against. Defaults to [TRADING_DATA_DIR/backtest_scenarios] via
    {!Scenario_lib.Fixtures_root.resolve}, matching [scenario_runner.exe] and
    [grid_search.exe]. *)

open Core
module Scenario = Scenario_lib.Scenario
module Fixtures_root = Scenario_lib.Fixtures_root
module Spec = Tuner_bin.Bayesian_runner_spec
module Evaluator = Tuner_bin.Bayesian_runner_evaluator
module Runner = Tuner_bin.Bayesian_runner_runner

let _usage_msg =
  "Usage: bayesian_runner.exe --spec <spec.sexp> --out-dir <dir> \
   [--fixtures-root <path>]"

type cli_args = {
  spec_path : string;
  out_dir : string;
  fixtures_root : string option;
}

let _parse_args argv =
  let rec loop spec out fixtures = function
    | [] -> (
        match (spec, out) with
        | Some s, Some o ->
            { spec_path = s; out_dir = o; fixtures_root = fixtures }
        | _ ->
            eprintf "%s\n" _usage_msg;
            Stdlib.exit 1)
    | "--spec" :: p :: rest -> loop (Some p) out fixtures rest
    | "--out-dir" :: p :: rest -> loop spec (Some p) fixtures rest
    | "--fixtures-root" :: p :: rest -> loop spec out (Some p) rest
    | "--help" :: _ | "-h" :: _ ->
        printf "%s\n" _usage_msg;
        Stdlib.exit 0
    | unknown :: _ ->
        eprintf "Error: unknown argument %S\n%s\n" unknown _usage_msg;
        Stdlib.exit 1
  in
  loop None None None argv

let _load_scenarios paths =
  let table = Hashtbl.create (module String) in
  List.iter paths ~f:(fun p ->
      let s = Scenario.load p in
      Hashtbl.set table ~key:p ~data:s);
  table

let _main () =
  let argv = Sys.get_argv () |> Array.to_list |> List.tl_exn in
  let args = _parse_args argv in
  let spec = Spec.load args.spec_path in
  let fixtures_root =
    Fixtures_root.resolve ?fixtures_root:args.fixtures_root ()
  in
  let scenarios_by_path = _load_scenarios spec.scenarios in
  let objective = Spec.to_grid_objective spec.objective in
  let obj_label = Tuner.Grid_search.objective_label objective in
  eprintf
    "[bayesian_runner] loaded %d scenario(s); total_budget=%d; \
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

let () = _main ()
