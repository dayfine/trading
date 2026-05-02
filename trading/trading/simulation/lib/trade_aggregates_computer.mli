(** Trade-aggregate metric computer (M5.2b).

    Produces per-trade derived metrics from the round-trips reconstructed from a
    simulation's [step_result] list. Complements [Summary_computer], which emits
    the basic count/PnL/win-rate group; this module covers the richer statistics
    — average win/loss, expectancy, consecutive runs, etc.

    Pure (in the same sense as the other computers): same step list → same
    output. *)

val computer :
  ?initial_cash:float ->
  unit ->
  Trading_simulation_types.Simulator_types.any_metric_computer
(** Build a metric computer that emits the trade-aggregate group:

    - [NumTrades], [LossRate]
    - [AvgWinDollar], [AvgWinPct], [AvgLossDollar], [AvgLossPct]
    - [LargestWinDollar], [LargestLossDollar]
    - [AvgTradeSizeDollar], [AvgTradeSizePct]
    - [AvgHoldingDaysWinners], [AvgHoldingDaysLosers]
    - [Expectancy], [WinLossRatio]
    - [MaxConsecutiveWins], [MaxConsecutiveLosses]

    @param initial_cash
      Used as the denominator for [AvgTradeSizePct]. When omitted (default
      [0.0]), [AvgTradeSizePct] is reported as [0.0] to avoid division by zero.
      Callers wiring this computer into the default suite should pass the
      simulator's configured [initial_cash] explicitly. *)
