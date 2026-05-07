(** Shared utilities for metric computers. *)

module Simulator_types = Trading_simulation_types.Simulator_types

let trading_days_per_year = 252.0

(** True if [step] represents a real trading day — i.e. the simulator saw at
    least one bar for any symbol on [step.date]. Authoritative signal carried on
    [step_result.had_market_bars]. *)
let is_trading_day_step (step : Simulator_types.step_result) =
  step.had_market_bars
