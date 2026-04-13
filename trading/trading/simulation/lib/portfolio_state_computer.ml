(** Portfolio state metric computer — captures end-of-simulation state:
    OpenPositionCount, UnrealizedPnl, TradeFrequency. *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types

type state = {
  last_step : Simulator_types.step_result option;
  total_trades : int;
}

let _trade_frequency ~total_trades ~start_date ~end_date =
  let days = Float.of_int (Date.diff end_date start_date) in
  let months = days /. 30.44 in
  if Float.(months <= 0.0) then 0.0 else Float.of_int total_trades /. months

let _metrics_from_step ~(step : Simulator_types.step_result) ~total_trades
    ~start_date ~end_date =
  Metric_types.of_alist_exn
    [
      (OpenPositionCount, Float.of_int (List.length step.portfolio.positions));
      (UnrealizedPnl, step.portfolio_value -. step.portfolio.current_cash);
      (TradeFrequency, _trade_frequency ~total_trades ~start_date ~end_date);
    ]

let _update ~state ~step =
  {
    last_step = Some step;
    total_trades = state.total_trades + List.length step.trades;
  }

let _finalize ~state ~(config : Simulator_types.config) =
  match state.last_step with
  | None -> Metric_types.empty
  | Some step ->
      _metrics_from_step ~step ~total_trades:state.total_trades
        ~start_date:config.start_date ~end_date:config.end_date

let computer () : Simulator_types.any_metric_computer =
  Simulator_types.wrap_computer
    {
      name = "portfolio_state";
      init = (fun ~config:_ -> { last_step = None; total_trades = 0 });
      update = _update;
      finalize = _finalize;
    }
