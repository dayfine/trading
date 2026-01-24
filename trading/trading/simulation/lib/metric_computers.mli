(** Pre-built metric computers for common performance metrics.

    This module provides ready-to-use metric computers that can be passed to the
    simulator's dependencies. *)

(** {1 Summary Statistics Computer} *)

val summary_computer : unit -> Simulator.any_metric_computer
(** Metric computer that produces summary statistics from round-trip trades.

    Metrics produced:
    - total_pnl: Total profit/loss in dollars
    - avg_holding_days: Average holding period
    - win_count: Number of winning trades
    - loss_count: Number of losing trades
    - win_rate: Win percentage *)

(** {1 Sharpe Ratio Computer} *)

val sharpe_ratio_computer :
  ?risk_free_rate:float -> unit -> Simulator.any_metric_computer
(** Metric computer that calculates the annualized Sharpe ratio.

    @param risk_free_rate
      Annual risk-free rate (default: 0.0). This is divided by 252 to get the
      daily rate.

    Metrics produced:
    - sharpe_ratio: Annualized Sharpe ratio

    Edge cases:
    - Returns 0.0 if fewer than 2 data points
    - Returns 0.0 if standard deviation is zero (no variance) *)

(** {1 Maximum Drawdown Computer} *)

val max_drawdown_computer : unit -> Simulator.any_metric_computer
(** Metric computer that calculates maximum drawdown.

    Metrics produced:
    - max_drawdown: Maximum percentage decline from peak (0-100 scale) *)

(** {1 Default Computer Set} *)

val default_computers :
  ?risk_free_rate:float -> unit -> Simulator.any_metric_computer list
(** Returns all default metric computers: summary, Sharpe ratio, and max
    drawdown.

    @param risk_free_rate
      Annual risk-free rate for Sharpe calculation (default: 0.0) *)

(** {1 Factory} *)

val create_computer : Metric_types.metric_type -> Simulator.any_metric_computer
(** Create a metric computer from a metric type.

    Note: Only SharpeRatio and MaxDrawdown are supported as individual
    computers. Summary metrics (TotalPnl, AvgHoldingDays, WinCount, LossCount,
    WinRate) are produced together by summary_computer. *)
