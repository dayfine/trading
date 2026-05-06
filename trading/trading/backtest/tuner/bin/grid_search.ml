(** Grid-search CLI — wires {!Tuner.Grid_search.run} to a
    {!Backtest.Runner.run_backtest}-backed evaluator. Reads a spec sexp file
    describing the parameter grid, the objective to maximise, and the list of
    scenario sexp files to evaluate each cell against; writes [grid.csv],
    [best.sexp], and [sensitivity.md] under the requested output directory.

    Usage:

    {v
      grid_search.exe --spec <spec.sexp> --out-dir <dir>
                      [--fixtures-root <path>]
    v}

    [--spec] — path to a sexp file in the shape declared by
    {!Tuner_bin.Grid_search_spec.t}. The example shape is documented in that
    module's [.mli].

    [--out-dir] — directory the writers create. Created with [mkdir -p].

    [--fixtures-root] — directory each scenario's [universe_path] is resolved
    against. Defaults to [TRADING_DATA_DIR/backtest_scenarios] via
    {!Scenario_lib.Fixtures_root.resolve}, matching [scenario_runner.exe]. *)

open Core
module Scenario = Scenario_lib.Scenario
module Fixtures_root = Scenario_lib.Fixtures_root
module GS = Tuner.Grid_search

let _usage_msg =
  "Usage: grid_search.exe --spec <spec.sexp> --out-dir <dir> [--fixtures-root \
   <path>]"

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
  let spec = Tuner_bin.Grid_search_spec.load args.spec_path in
  let fixtures_root =
    Fixtures_root.resolve ?fixtures_root:args.fixtures_root ()
  in
  let scenarios_by_path = _load_scenarios spec.scenarios in
  let n_cells =
    List.length
      (GS.cells_of_spec
         (Tuner_bin.Grid_search_spec.to_grid_param_spec spec.params))
  in
  let obj_label =
    GS.objective_label
      (Tuner_bin.Grid_search_spec.to_grid_objective spec.objective)
  in
  eprintf "[grid_search] loaded %d scenario(s); %d cell(s); objective=%s\n%!"
    (List.length spec.scenarios)
    n_cells obj_label;
  let evaluator =
    Tuner_bin.Grid_search_evaluator.build ~fixtures_root ~scenarios_by_path
  in
  let result =
    Tuner_bin.Grid_search_runner.run_and_write ~spec ~out_dir:args.out_dir
      ~evaluator
  in
  eprintf "[grid_search] best_score=%.6f best_cell=%s\n%!" result.best_score
    (Sexp.to_string (Sexp.List (GS.cell_to_overrides result.best_cell)));
  eprintf "[grid_search] outputs written under %s\n%!" args.out_dir

let () = _main ()
