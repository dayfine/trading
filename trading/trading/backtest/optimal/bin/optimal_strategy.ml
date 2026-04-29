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

type cli_args = { output_dir : string }

let _usage_and_exit () =
  eprintf "Usage: optimal_strategy --output-dir <path>\n";
  Stdlib.exit 1

let _parse_args () : cli_args =
  let argv = Sys.get_argv () |> Array.to_list |> List.tl_exn in
  let rec loop output_dir = function
    | [] -> output_dir
    | "--output-dir" :: v :: rest -> loop (Some v) rest
    | _ :: _ -> _usage_and_exit ()
  in
  match loop None argv with
  | Some d -> { output_dir = d }
  | None -> _usage_and_exit ()

let () =
  let { output_dir } = _parse_args () in
  Backtest_optimal.Optimal_strategy_runner.run ~output_dir
