(** Risk-adjusted return metrics (M5.2c).

    This module emits two groups of risk-adjusted metrics:

    - [OmegaRatio] — a step-based metric requiring the per-step return series.
    - [SortinoRatioAnnualized] and [MarRatio] — derived metrics that only need
      values already produced by other computers (CAGR, downside deviation, max
      drawdown). Both are exposed via {!derived} below.

    Pure: same step list → same output. *)

val computer :
  unit -> Trading_simulation_types.Simulator_types.any_metric_computer
(** Build the step-based computer that emits [OmegaRatio].

    Omega is computed at threshold [0%]: the ratio of the sum of positive step
    returns to the absolute sum of negative step returns. > 1 means cumulative
    gains exceed cumulative losses by area; < 1 means the inverse. Returns
    [Float.infinity] if the strategy has any positive step return but no
    negative step return; returns [0.0] when there are no positive returns. *)

val sortino_ratio_derived :
  Trading_simulation_types.Simulator_types.derived_metric_computer
(** Derived computer for [SortinoRatioAnnualized].

    Computed as [CAGR / DownsideDeviationPctAnnualized] (both metrics are in
    percent, so the ratio is dimensionless). Returns [0.0] when downside
    deviation is zero (avoids division-by-zero noise). *)

val mar_ratio_derived :
  Trading_simulation_types.Simulator_types.derived_metric_computer
(** Derived computer for [MarRatio].

    Identical formula to {!Metric_computers.calmar_ratio_derived} —
    [CAGR / MaxDrawdown]. Exposed under both names because the literature treats
    Calmar as a 36-month rolling figure and MAR as the since-inception variant;
    over a single backtest window they coincide. *)
