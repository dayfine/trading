open Core
module Scenario = Scenario_lib.Scenario
module Universe_file = Scenario_lib.Universe_file
module Runner = Barbell.Barbell_runner

type leg_spec = {
  name : string;
  strategy : Backtest.Strategy_choice.t;
  overrides : Sexp.t list;
}

let _default_floor_symbol = "SPY"
let _default_floor_ma_period_weeks = 30

let spy_floor_leg ?(symbol = _default_floor_symbol)
    ?(ma_period_weeks = _default_floor_ma_period_weeks) ?(overrides = []) () =
  {
    name = "floor";
    strategy =
      Backtest.Strategy_choice.Spy_only_weinstein
        { symbol; ma_period_weeks; enable_stage4_short = false };
    overrides;
  }

let engine_leg ?(strategy = Backtest.Strategy_choice.default) ?(overrides = [])
    () =
  { name = "engine"; strategy; overrides }

(* Resolve the scenario's [universe_path] (relative to [fixtures_root]) into the
   sector-map override both legs trade over. Mirrors
   [scenario_runner._sector_map_of_universe_file] and
   [rolling_start_runner._sector_map_override]. *)
let _sector_map_override ~fixtures_root (scenario : Scenario.t) =
  let resolved = Filename.concat fixtures_root scenario.universe_path in
  Universe_file.to_sector_map_override (Universe_file.load resolved)

(* Build one leg's thunk: run [run_backtest] over the scenario's period with the
   leg's strategy + overrides (and the shared universe + bar source), then
   project the run's steps into the equity series the blend core consumes. *)
let _leg_thunk ~(scenario : Scenario.t) ~sector_map_override ~bar_data_source
    (leg : leg_spec) () : Runner.leg_result =
  let result =
    Backtest.Runner.run_backtest ~start_date:scenario.period.start_date
      ~end_date:scenario.period.end_date ~overrides:leg.overrides
      ?sector_map_override ~strategy_choice:leg.strategy ?bar_data_source ()
  in
  {
    Runner.name = leg.name;
    equity_curve = Runner.equity_curve_of_steps result.steps;
  }

let run ~(scenario : Scenario.t) ~fixtures_root ~bar_data_source ~config ~floor
    ~engine =
  let sector_map_override = _sector_map_override ~fixtures_root scenario in
  let floor_leg =
    _leg_thunk ~scenario ~sector_map_override ~bar_data_source floor
  in
  let engine_leg =
    _leg_thunk ~scenario ~sector_map_override ~bar_data_source engine
  in
  Runner.run ~config ~floor_leg ~engine_leg
