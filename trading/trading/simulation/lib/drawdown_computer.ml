(** Maximum drawdown metric computer. *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types

type state = { peak : float; max_drawdown : float; has_data : bool }

let _step_drawdown state value =
  let peak = Float.max state.peak value in
  let drawdown =
    if Float.(peak = 0.0) then 0.0 else (peak -. value) /. peak *. 100.0
  in
  {
    peak;
    max_drawdown = Float.max state.max_drawdown drawdown;
    has_data = true;
  }

let _update_with_value state value =
  if not state.has_data then
    { peak = value; max_drawdown = 0.0; has_data = true }
  else _step_drawdown state value

let _update ~state ~step =
  if not (Metric_computer_utils.is_trading_day_step step) then state
  else _update_with_value state step.Simulator_types.portfolio_value

let computer () : Simulator_types.any_metric_computer =
  Simulator_types.wrap_computer
    {
      name = "max_drawdown";
      init =
        (fun ~config:_ -> { peak = 0.0; max_drawdown = 0.0; has_data = false });
      update = _update;
      finalize =
        (fun ~state ~config:_ ->
          Metric_types.singleton MaxDrawdown state.max_drawdown);
    }
