(** Shared utilities for metric computers. *)

val trading_days_per_year : float
(** Standard trading days per year (252). *)

val is_trading_day_step :
  Trading_simulation_types.Simulator_types.step_result -> bool
(** True if the step has real market data (not a weekend/holiday). *)
