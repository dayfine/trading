(** Summary statistics metric computer — produces TotalPnl, WinCount, LossCount,
    WinRate, AvgHoldingDays, and ProfitFactor from round-trip trades. *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types

type state = { steps : Simulator_types.step_result list }

let _compute_profit_factor (round_trips : Metrics.trade_metrics list) =
  let gross_profit =
    List.fold round_trips ~init:0.0 ~f:(fun acc (m : Metrics.trade_metrics) ->
        if Float.(m.pnl_dollars > 0.0) then acc +. m.pnl_dollars else acc)
  in
  let gross_loss =
    List.fold round_trips ~init:0.0 ~f:(fun acc (m : Metrics.trade_metrics) ->
        if Float.(m.pnl_dollars < 0.0) then acc +. Float.abs m.pnl_dollars
        else acc)
  in
  if Float.(gross_loss = 0.0) then
    if Float.(gross_profit > 0.0) then Float.infinity else 0.0
  else gross_profit /. gross_loss

let _finalize ~state ~config:_ =
  let steps = List.rev state.steps in
  let round_trips = Metrics.extract_round_trips steps in
  let base_metrics =
    match Metrics.compute_summary round_trips with
    | None -> Metric_types.empty
    | Some stats -> Metrics.summary_stats_to_metrics stats
  in
  let profit_factor = _compute_profit_factor round_trips in
  Metric_types.merge base_metrics
    (Metric_types.singleton ProfitFactor profit_factor)

let computer () : Simulator_types.any_metric_computer =
  Simulator_types.wrap_computer
    {
      name = "summary";
      init = (fun ~config:_ -> { steps = [] });
      update = (fun ~state ~step -> { steps = step :: state.steps });
      finalize = _finalize;
    }
