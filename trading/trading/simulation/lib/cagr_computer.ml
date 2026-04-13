(** CAGR (Compound Annual Growth Rate) metric computer. *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types

type state = { first_value : float option; last_value : float option }

let _days_per_year = 365.25

let _compute ~first ~last ~start_date ~end_date =
  let days = Float.of_int (Date.diff end_date start_date) in
  let years = days /. _days_per_year in
  if Float.(years <= 0.0) || Float.(first <= 0.0) then 0.0
  else
    let ratio = last /. first in
    (Float.( ** ) ratio (1.0 /. years) -. 1.0) *. 100.0

let _update ~state ~step =
  if not (Metric_computer_utils.is_trading_day_step step) then state
  else
    let value = step.Simulator_types.portfolio_value in
    let first_value =
      match state.first_value with None -> Some value | some -> some
    in
    { first_value; last_value = Some value }

let _finalize ~state ~(config : Simulator_types.config) =
  let cagr =
    match (state.first_value, state.last_value) with
    | Some first, Some last ->
        _compute ~first ~last ~start_date:config.start_date
          ~end_date:config.end_date
    | _ -> 0.0
  in
  Metric_types.singleton CAGR cagr

let computer () : Simulator_types.any_metric_computer =
  Simulator_types.wrap_computer
    {
      name = "cagr";
      init = (fun ~config:_ -> { first_value = None; last_value = None });
      update = _update;
      finalize = _finalize;
    }
