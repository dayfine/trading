(** Optimal-strategy counterfactual binary.

    Thin CLI wrapper over {!Backtest_optimal.Optimal_strategy_runner.run}. Reads
    the artefacts written by a prior [scenario_runner.exe] run from
    [--output-dir] and writes [<output_dir>/optimal_strategy.md] — see the
    runner module's docstrings for the pipeline.

    {1 Usage}

    {[
    optimal_strategy.exe --output-dir dev/backtest/scenarios-XYZ/sp500-2019-2023/
    ]} *)

open Core

type cli_args = { output_dir : string; warehouse_dir : string option }

let _usage_and_exit () =
  eprintf
    "Usage: optimal_strategy --output-dir <path> [--snapshot-dir <warehouse>]\n";
  Stdlib.exit 1

let _parse_args () : cli_args =
  let argv = Sys.get_argv () |> Array.to_list |> List.tl_exn in
  let rec loop output_dir warehouse_dir = function
    | [] -> (output_dir, warehouse_dir)
    | "--output-dir" :: v :: rest -> loop (Some v) warehouse_dir rest
    | "--snapshot-dir" :: v :: rest -> loop output_dir (Some v) rest
    | _ :: _ -> _usage_and_exit ()
  in
  match loop None None argv with
  | Some d, warehouse_dir -> { output_dir = d; warehouse_dir }
  | None, _ -> _usage_and_exit ()

let () =
  let { output_dir; warehouse_dir } = _parse_args () in
  Backtest_optimal.Optimal_strategy_runner.run ?warehouse_dir ~output_dir ()
