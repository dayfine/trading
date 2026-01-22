(** Pre-built metric computers for common performance metrics.

    This module provides ready-to-use metric computers that can be passed to
    [Metrics.compute_metrics] or the simulator's [run_with_metrics] function. *)

(** {1 Summary Statistics Computer} *)

val summary_computer : unit -> Metrics.any_metric_computer
(** Metric computer that produces summary statistics from round-trip trades.

    This wraps the existing [Metrics.extract_round_trips] and
    [Metrics.compute_summary] functions into the fold-based metric computer
    model.

    Metrics produced:
    - total_pnl: Total profit/loss in dollars
    - avg_holding_days: Average holding period
    - win_count: Number of winning trades
    - loss_count: Number of losing trades
    - win_rate: Win percentage *)

(** {1 Sharpe Ratio Computer} *)

val sharpe_ratio_computer :
  ?risk_free_rate:float -> unit -> Metrics.any_metric_computer
(** Metric computer that calculates the annualized Sharpe ratio.

    The Sharpe ratio measures risk-adjusted returns:
    {[
      sharpe
      = (mean daily_returns - (risk_free_rate / 252))
        / std daily_returns * sqrt 252
    ]}

    @param risk_free_rate
      Annual risk-free rate (default: 0.0). This is divided by 252 to get the
      daily rate.

    Metrics produced:
    - sharpe_ratio: Annualized Sharpe ratio

    Edge cases:
    - Returns 0.0 if fewer than 2 data points
    - Returns 0.0 if standard deviation is zero (no variance) *)

(** {1 Maximum Drawdown Computer} *)

val max_drawdown_computer : unit -> Metrics.any_metric_computer
(** Metric computer that calculates maximum drawdown.

    Maximum drawdown measures the largest peak-to-trough decline in portfolio
    value during the simulation:
    {[
      For each step:
        peak = max(peak, current_value)
        drawdown = (peak - current_value) / peak
        max_drawdown = max(max_drawdown, drawdown)
    ]}

    Metrics produced:
    - max_drawdown: Maximum percentage decline from peak (0-100 scale) *)

(** {1 Default Computer Set} *)

val default_computers :
  ?risk_free_rate:float -> unit -> Metrics.any_metric_computer list
(** Returns all default metric computers: summary, Sharpe ratio, and max
    drawdown.

    @param risk_free_rate
      Annual risk-free rate for Sharpe calculation (default: 0.0) *)

(** {1 Running with Metrics} *)

val run_with_metrics :
  ?computers:Metrics.any_metric_computer list ->
  Simulator.t ->
  Metrics.run_result Status.status_or
(** Run the full simulation and compute metrics.

    @param computers
      List of metric computers to use. Defaults to [default_computers ()] if not
      specified.
    @return Complete run result including steps, final portfolio, and metrics *)
