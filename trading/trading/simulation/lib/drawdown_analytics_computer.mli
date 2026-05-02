(** Drawdown analytics computer (M5.2c).

    Sweeps the daily equity curve once and emits the M5.2c drawdown-block
    metrics:

    - [AvgDrawdownPct]
    - [MedianDrawdownPct]
    - [MaxDrawdownDurationDays]
    - [AvgDrawdownDurationDays]
    - [TimeInDrawdownPct]
    - [UlcerIndex]
    - [PainIndex]
    - [UnderwaterCurveArea]

    The {b episode model} (used by all four "by-episode" metrics above): a
    drawdown episode runs from a peak (running maximum) through a trough back to
    recovery (the next day whose value reaches a new all-time high). The
    trailing in-progress episode at end-of-run is included as a final episode
    whose end date is the last sample's date.

    The {b per-day model} (used by [TimeInDrawdownPct], [UlcerIndex],
    [PainIndex], [UnderwaterCurveArea]): for each trading-day step, drawdown
    percent = [(running_peak - portfolio_value) / running_peak × 100].

    Pure: same step list → same output. *)

val computer :
  unit -> Trading_simulation_types.Simulator_types.any_metric_computer
