(** Capital-relative drawdown computer. See .mli for spec. *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types

type state = {
  initial_cash : float;
  max_underwater_pct : float;  (** Running max of the per-day shortfall pct. *)
}

(** Per-day shortfall of [value] below [initial_cash], as a percent of initial,
    clamped at 0 when the value is at or above the initial stake. Returns [0.0]
    when [initial_cash <= 0.0] (no meaningful baseline). *)
let _underwater_pct ~initial_cash ~value =
  if Float.(initial_cash <= 0.0) then 0.0
  else Float.max 0.0 ((initial_cash -. value) /. initial_cash *. 100.0)

let _update ~state ~step =
  if not (Metric_computer_utils.is_trading_day_step step) then state
  else
    let dd =
      _underwater_pct ~initial_cash:state.initial_cash
        ~value:step.Simulator_types.portfolio_value
    in
    { state with max_underwater_pct = Float.max state.max_underwater_pct dd }

let _finalize ~state ~config:_ =
  Metric_types.singleton MaxUnderwaterVsInitialPct state.max_underwater_pct

let computer ?(initial_cash = 0.0) () : Simulator_types.any_metric_computer =
  Simulator_types.wrap_computer
    {
      name = "capital_relative_drawdown";
      init = (fun ~config:_ -> { initial_cash; max_underwater_pct = 0.0 });
      update = _update;
      finalize = _finalize;
    }
