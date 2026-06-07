open Core
module Scenario = Scenario_lib.Scenario
module Universe_file = Scenario_lib.Universe_file
module Metric_types = Trading_simulation_types.Metric_types

let enumerate_starts ~scenario_start ~end_date ~stride_days =
  if stride_days <= 0 then
    invalid_arg
      (sprintf "enumerate_starts: stride_days must be positive, got %d"
         stride_days);
  let rec loop acc d =
    if Date.( >= ) d end_date then List.rev acc
    else loop (d :: acc) (Date.add_days d stride_days)
  in
  loop [] scenario_start

(** Inclusive calendar-day count of [start_date .. end_date]. *)
let _inclusive_days ~start_date ~end_date = Date.diff end_date start_date + 1

let per_start_of_summary ~start_date ~end_date (summary : Backtest.Summary.t) :
    Rolling_start_types.per_start =
  let get k = Map.find summary.metrics k |> Option.value ~default:Float.nan in
  let total_return_pct =
    (summary.final_portfolio_value -. summary.initial_cash)
    /. summary.initial_cash *. 100.0
  in
  let test_days = _inclusive_days ~start_date ~end_date in
  {
    Rolling_start_types.start_date;
    cagr_pct =
      Walk_forward.Walk_forward_runner.cagr_pct ~test_days ~total_return_pct;
    max_underwater_vs_initial_pct = get Metric_types.MaxUnderwaterVsInitialPct;
    max_drawdown_pct = get Metric_types.MaxDrawdown;
  }

type config = {
  scenario : Scenario.t;
  end_date : Date.t;
  stride_days : int;
  fixtures_root : string;
  bar_data_source : Backtest.Bar_data_source.t option;
}

(** Resolve the scenario's [universe_path] (relative to [fixtures_root]) into
    the optional sector-map override [Backtest.Runner] uses as its universe.
    Mirrors [scenario_runner._sector_map_of_universe_file]. *)
let _sector_map_override ~fixtures_root (scenario : Scenario.t) =
  let resolved = Filename.concat fixtures_root scenario.universe_path in
  Universe_file.to_sector_map_override (Universe_file.load resolved)

(** Run one backtest from [start_date] to [config.end_date], threading the
    scenario's overrides / strategy / cost knobs and the shared sector-map
    override + optional snapshot source, and project the terminal summary into a
    {!Rolling_start_types.per_start}. *)
let _run_one ~config ~sector_map_override ~start_date =
  let result =
    Backtest.Runner.run_backtest ~start_date ~end_date:config.end_date
      ~overrides:config.scenario.config_overrides ?sector_map_override
      ~strategy_choice:config.scenario.strategy
      ?slippage_bps:config.scenario.slippage_bps
      ?cost_model:config.scenario.cost_model
      ?bar_data_source:config.bar_data_source ()
  in
  per_start_of_summary ~start_date ~end_date:config.end_date result.summary

let run config =
  let starts =
    enumerate_starts ~scenario_start:config.scenario.period.start_date
      ~end_date:config.end_date ~stride_days:config.stride_days
  in
  let sector_map_override =
    _sector_map_override ~fixtures_root:config.fixtures_root config.scenario
  in
  let per_starts =
    List.map starts ~f:(fun start_date ->
        _run_one ~config ~sector_map_override ~start_date)
  in
  Rolling_start_types.build ~end_date:config.end_date per_starts
