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
    - win_rate: Win percentage
    - profit_factor: Gross profit / gross loss *)

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

(** {1 CAGR Computer} *)

val cagr_computer : unit -> Simulator.any_metric_computer
(** Metric computer that calculates compound annual growth rate.

    Metrics produced:
    - CAGR: Annualized return as percentage *)

(** {1 Portfolio State Computer} *)

val portfolio_state_computer : unit -> Simulator.any_metric_computer
(** Metric computer that captures end-of-simulation portfolio state.

    Metrics produced:
    - OpenPositionCount: Number of open positions at end
    - UnrealizedPnl: Unrealized P&L (final value - current cash)
    - TradeFrequency: Average trades per month *)

(** {1 Default Computer Set} *)

val default_computers :
  ?risk_free_rate:float -> unit -> Simulator.any_metric_computer list
(** Returns all default step-based metric computers: summary (including profit
    factor), Sharpe ratio, max drawdown, CAGR, and portfolio state.

    @param risk_free_rate
      Annual risk-free rate for Sharpe calculation (default: 0.0) *)

(** {1 Derived Metric Computers} *)

val calmar_ratio_derived : Simulator.derived_metric_computer
(** Computes CalmarRatio = CAGR / MaxDrawdown. Depends on CAGR and MaxDrawdown
    being computed first by step-based computers. *)

val default_derived_computers : unit -> Simulator.derived_metric_computer list
(** Returns all default derived metric computers (currently: CalmarRatio). *)

val default_metric_suite :
  ?risk_free_rate:float -> unit -> Simulator.metric_suite
(** Returns a complete metric suite with all step-based and derived computers.
*)

(** {1 Factory} *)

val create_computer :
  Trading_simulation_types.Metric_types.metric_type ->
  Simulator.any_metric_computer
(** Create a metric computer from a metric type.

    Note: Summary metrics (TotalPnl, AvgHoldingDays, WinCount, LossCount,
    WinRate, ProfitFactor) are produced together by summary_computer.
    CalmarRatio is a derived metric computed post-hoc by the simulator. *)
