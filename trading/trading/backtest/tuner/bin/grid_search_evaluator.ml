open Core
module Scenario = Scenario_lib.Scenario
module Universe_file = Scenario_lib.Universe_file

type scenario = Scenario.t

let _sector_map_of_scenario ~fixtures_root (s : scenario) =
  let resolved = Filename.concat fixtures_root s.universe_path in
  Universe_file.to_sector_map_override (Universe_file.load resolved)

let _run_one ~fixtures_root (s : scenario) cell =
  let cell_overrides = Tuner.Grid_search.cell_to_overrides cell in
  let merged_overrides = s.config_overrides @ cell_overrides in
  let sector_map_override = _sector_map_of_scenario ~fixtures_root s in
  let result =
    Backtest.Runner.run_backtest ~start_date:s.period.start_date
      ~end_date:s.period.end_date ~overrides:merged_overrides
      ?sector_map_override ~strategy_choice:s.strategy ()
  in
  result.summary.metrics

let build ~fixtures_root ~scenarios_by_path : Tuner.Grid_search.evaluator =
 fun cell ~scenario ->
  match Hashtbl.find scenarios_by_path scenario with
  | Some s -> _run_one ~fixtures_root s cell
  | None ->
      failwithf
        "Grid_search_evaluator: unknown scenario path %S (must be one of the \
         spec's [scenarios] entries)"
        scenario ()
