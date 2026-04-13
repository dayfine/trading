(** Shared utilities for metric computers. *)

open Core
module Simulator_types = Trading_simulation_types.Simulator_types

let trading_days_per_year = 252.0
let _cash_epsilon = 0.01

(** True if [step] represents a real trading day. On non-trading days the
    simulator has no bars, so positions are valued at 0 and portfolio_value
    equals just cash. *)
let is_trading_day_step (step : Simulator_types.step_result) =
  let has_positions = not (List.is_empty step.portfolio.positions) in
  let value_is_just_cash =
    Float.( <= )
      (Float.abs (step.portfolio_value -. step.portfolio.current_cash))
      _cash_epsilon
  in
  (not has_positions) || not value_is_just_cash
