(** Sharpe ratio metric computer. *)

val computer :
  ?risk_free_rate:float ->
  unit ->
  Trading_simulation_types.Simulator_types.any_metric_computer
