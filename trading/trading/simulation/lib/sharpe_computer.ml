(** Sharpe ratio metric computer. *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types

type state = { portfolio_values : float list; risk_free_rate : float }

let _mean = function
  | [] -> 0.0
  | values ->
      let sum = List.fold values ~init:0.0 ~f:( +. ) in
      sum /. Float.of_int (List.length values)

let _sq_diff mean acc x =
  let diff = x -. mean in
  acc +. (diff *. diff)

let _std = function
  | [] | [ _ ] -> 0.0
  | values ->
      let mean = _mean values in
      let sum_sq_diff = List.fold values ~init:0.0 ~f:(_sq_diff mean) in
      Float.sqrt (sum_sq_diff /. Float.of_int (List.length values))

let _compute_daily_returns values =
  let rec loop prev rest acc =
    match rest with
    | [] -> List.rev acc
    | curr :: rest' ->
        let ret = if Float.(prev = 0.0) then 0.0 else (curr -. prev) /. prev in
        loop curr rest' (ret :: acc)
  in
  match values with [] | [ _ ] -> [] | first :: rest -> loop first rest []

let _compute_sharpe daily_returns risk_free_rate =
  match daily_returns with
  | [] | [ _ ] -> 0.0
  | _ ->
      let mean_return = _mean daily_returns in
      let std_return = _std daily_returns in
      if Float.(std_return = 0.0) then 0.0
      else
        let tdpy = Metric_computer_utils.trading_days_per_year in
        let excess = mean_return -. (risk_free_rate /. tdpy) in
        excess /. std_return *. Float.sqrt tdpy

let _update ~state ~step =
  if not (Metric_computer_utils.is_trading_day_step step) then state
  else
    {
      state with
      portfolio_values =
        step.Simulator_types.portfolio_value :: state.portfolio_values;
    }

let _finalize ~state ~config:_ =
  let returns = _compute_daily_returns (List.rev state.portfolio_values) in
  let sharpe = _compute_sharpe returns state.risk_free_rate in
  Metric_types.singleton SharpeRatio sharpe

let computer ?(risk_free_rate = 0.0) () : Simulator_types.any_metric_computer =
  Simulator_types.wrap_computer
    {
      name = "sharpe_ratio";
      init = (fun ~config:_ -> { portfolio_values = []; risk_free_rate });
      update = _update;
      finalize = _finalize;
    }
