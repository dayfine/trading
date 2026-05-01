(** Portfolio state metric computer — OpenPositionCount, OpenPositionsValue,
    UnrealizedPnl, TradeFrequency. *)

val computer :
  unit -> Trading_simulation_types.Simulator_types.any_metric_computer
