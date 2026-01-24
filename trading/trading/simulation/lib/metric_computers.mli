(** Metric computers for computing performance metrics.

    This module provides the metric computer abstraction and pre-built metric
    computers that can be used to compute performance metrics from simulation
    results. *)

(** {1 Metric Computer Abstraction}

    Metric computers use a fold-based model: they maintain state that is updated
    on each simulation step, then finalized to produce metrics. *)

type 'state metric_computer = {
  name : string;  (** Identifier for this computer *)
  init : config:Simulator.config -> 'state;
      (** Create initial state from simulation config *)
  update : state:'state -> step:Simulator.step_result -> 'state;
      (** Update state with a simulation step *)
  finalize : state:'state -> config:Simulator.config -> Metric_types.metric list;
      (** Produce final metrics from accumulated state *)
}
(** A metric computer that folds over simulation steps to produce metrics.

    The 'state type parameter allows each computer to maintain its own internal
    state during the fold (e.g., collecting daily values for Sharpe ratio). *)

type any_metric_computer
(** Type-erased wrapper for heterogeneous collections of metric computers *)

val wrap_computer : 'state metric_computer -> any_metric_computer
(** Wrap a typed metric computer for use in heterogeneous collections *)

val compute_metrics :
  computers:any_metric_computer list ->
  config:Simulator.config ->
  steps:Simulator.step_result list ->
  Metric_types.metric_set
(** Compute metrics by running all computers over the simulation steps.

    Each computer's init/update/finalize cycle is executed, and all resulting
    metrics are collected into a single metric_set. *)

(** {1 Factory} *)

val create_computer : Metric_types.metric_type -> any_metric_computer
(** Create a metric computer from a metric type.

    @param metric_type The type of metric to compute
    @return A wrapped metric computer for the specified type *)

(** {1 Summary Statistics Computer} *)

val summary_computer : unit -> any_metric_computer
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

val sharpe_ratio_computer : ?risk_free_rate:float -> unit -> any_metric_computer
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

val max_drawdown_computer : unit -> any_metric_computer
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
  ?risk_free_rate:float -> unit -> any_metric_computer list
(** Returns all default metric computers: summary, Sharpe ratio, and max
    drawdown.

    @param risk_free_rate
      Annual risk-free rate for Sharpe calculation (default: 0.0) *)

(** {1 Running with Metrics} *)

val run_with_metrics :
  ?computers:any_metric_computer list ->
  Simulator.t ->
  Simulator.run_result Status.status_or
(** Run the full simulation and compute metrics.

    @param computers
      List of metric computers to use. Defaults to [default_computers ()] if not
      specified.
    @return Complete run result including steps, final portfolio, and metrics *)
