(** Summary statistics metric computer — produces TotalPnl, WinCount, LossCount,
    WinRate, AvgHoldingDays, and ProfitFactor from round-trip trades. *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types

type state = { steps : Simulator_types.step_result list }

let _finalize ~state ~config:_ =
  let steps = List.rev state.steps in
  let round_trips = Metrics.extract_round_trips steps in
  Metrics.compute_round_trip_metric_set round_trips

let computer () : Simulator_types.any_metric_computer =
  Simulator_types.wrap_computer
    {
      name = "summary";
      init = (fun ~config:_ -> { steps = [] });
      update = (fun ~state ~step -> { steps = step :: state.steps });
      finalize = _finalize;
    }
