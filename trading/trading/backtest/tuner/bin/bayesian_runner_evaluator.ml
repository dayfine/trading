open Core
module Scenario = Scenario_lib.Scenario
module Universe_file = Scenario_lib.Universe_file
module GS = Tuner.Grid_search
module Metric_types = Trading_simulation_types.Metric_types

type scenario = Scenario.t

type t =
  parameters:(string * float) list -> float * Metric_types.metric_set list

let _sector_map_of_scenario ~fixtures_root (s : scenario) =
  let resolved = Filename.concat fixtures_root s.universe_path in
  Universe_file.to_sector_map_override (Universe_file.load resolved)

let _run_one ~fixtures_root (s : scenario) parameters =
  let cell_overrides = GS.cell_to_overrides parameters in
  let merged_overrides = s.config_overrides @ cell_overrides in
  let sector_map_override = _sector_map_of_scenario ~fixtures_root s in
  let result =
    Backtest.Runner.run_backtest ~start_date:s.period.start_date
      ~end_date:s.period.end_date ~overrides:merged_overrides
      ?sector_map_override ~strategy_choice:s.strategy ()
  in
  result.summary.metrics

let _lookup_scenario scenarios_by_path path =
  match Hashtbl.find scenarios_by_path path with
  | Some s -> s
  | None ->
      failwithf
        "Bayesian_runner_evaluator: unknown scenario path %S (must be one of \
         the spec's [scenarios] entries)"
        path ()

let _mean = function
  | [] -> Float.neg_infinity
  | xs -> List.fold xs ~init:0.0 ~f:( +. ) /. Float.of_int (List.length xs)

let build ~fixtures_root ~scenarios ~scenarios_by_path ~objective : t =
 fun ~parameters ->
  let metric_sets =
    List.map scenarios ~f:(fun path ->
        let s = _lookup_scenario scenarios_by_path path in
        _run_one ~fixtures_root s parameters)
  in
  let scalars = List.map metric_sets ~f:(GS.evaluate_objective objective) in
  (_mean scalars, metric_sets)
