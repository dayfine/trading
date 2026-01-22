(** Trade metrics computation for performance analysis.

    This module provides types and functions for computing trade metrics from
    simulation results. It extracts round-trip trades (buy followed by sell) and
    computes summary statistics like P&L, win rate, and holding periods.

    Also provides a generic metric framework with fold-based computation for
    advanced metrics like Sharpe ratio and maximum drawdown.

    Part of Phase 7: Performance Metrics in the simulation framework. *)

open Core

(** {1 Generic Metric Types} *)

(** Unit of measurement for a metric value *)
type metric_unit =
  | Dollars  (** Monetary value in dollars *)
  | Percent  (** Percentage value (0-100 scale) *)
  | Days  (** Time duration in days *)
  | Count  (** Discrete count *)
  | Ratio  (** Dimensionless ratio *)
[@@deriving show, eq]

type metric = {
  name : string;  (** Machine-readable identifier (e.g., "sharpe_ratio") *)
  display_name : string;  (** Human-readable name (e.g., "Sharpe Ratio") *)
  description : string;  (** Brief explanation of what this metric measures *)
  value : float;  (** The computed value *)
  unit : metric_unit;  (** Unit of measurement *)
}
[@@deriving show, eq]
(** A single computed metric with metadata *)

type metric_set = metric list
(** A collection of metrics from a simulation run *)

(** {1 Trade Metrics Types} *)

type trade_metrics = {
  symbol : string;  (** The traded symbol *)
  entry_date : Date.t;  (** Date of entry (buy) *)
  exit_date : Date.t;  (** Date of exit (sell) *)
  days_held : int;  (** Number of days position was held *)
  entry_price : float;  (** Price at entry *)
  exit_price : float;  (** Price at exit *)
  quantity : float;  (** Number of shares traded *)
  pnl_dollars : float;  (** Profit/loss in dollars *)
  pnl_percent : float;  (** Profit/loss as percentage of entry price *)
}
[@@deriving show, eq]
(** Metrics for a completed round-trip trade.

    A round-trip trade consists of an entry (buy) followed by an exit (sell) for
    the same symbol. This record captures the key performance metrics for
    analyzing trade profitability. *)

type summary_stats = {
  total_pnl : float;  (** Sum of P&L across all trades *)
  avg_holding_days : float;  (** Average holding period in days *)
  win_count : int;  (** Number of profitable trades *)
  loss_count : int;  (** Number of unprofitable trades *)
  win_rate : float;  (** Percentage of winning trades (0.0 to 100.0) *)
}
[@@deriving show, eq]
(** Summary statistics for a set of trades.

    Aggregates individual trade metrics into portfolio-level performance
    statistics useful for evaluating strategy effectiveness. *)

(** {1 Metric Computer Abstraction}

    Metric computers use a fold-based model: they maintain state that is updated
    on each simulation step, then finalized to produce metrics. *)

type 'state metric_computer = {
  name : string;  (** Identifier for this computer *)
  init : config:Simulator.config -> 'state;
      (** Create initial state from simulation config *)
  update : state:'state -> step:Simulator.step_result -> 'state;
      (** Update state with a simulation step *)
  finalize : state:'state -> config:Simulator.config -> metric list;
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
  metric_set
(** Compute metrics by running all computers over the simulation steps.

    Each computer's init/update/finalize cycle is executed, and all resulting
    metrics are collected into a single metric_set. *)

(** {1 Trade Metrics Functions} *)

val extract_round_trips : Simulator.step_result list -> trade_metrics list
(** Extract round-trip trades from simulation step results.

    A round-trip is identified by pairing buy trades with subsequent sell trades
    for the same symbol. Trades are matched in chronological order, with each
    buy paired with the next sell.

    @param steps List of step results from simulator run
    @return List of trade metrics for completed round-trips *)

val compute_summary : trade_metrics list -> summary_stats option
(** Compute summary statistics from a list of trade metrics.

    @param trades List of trade metrics to summarize
    @return Summary statistics, or None if the list is empty *)

val show_trade_metrics : trade_metrics -> string
(** Format trade metrics as a human-readable string.

    Example output:
    [AAPL: 2024-01-02 -> 2024-01-15 (13 days), entry=185.50 exit=190.25 qty=100,
     P&L=$475.00 (2.56%)] *)

val show_summary : summary_stats -> string
(** Format summary statistics as a human-readable string.

    Example output:
    [Total P&L: $1234.56 | Avg hold: 8.5 days | Win rate: 60.0% (6/10)] *)

(** {1 Metric Utilities} *)

val find_metric : metric_set -> name:string -> metric option
(** Find a metric by its machine-readable name *)

val format_metric : metric -> string
(** Format a single metric for display (e.g., "Sharpe Ratio: 1.25") *)

val format_metrics : metric_set -> string
(** Format all metrics for display, one per line *)

(** {1 Conversion Functions} *)

val summary_stats_to_metrics : summary_stats -> metric list
(** Convert legacy summary_stats to the generic metric format *)

(** {1 Run Result Type} *)

type run_result = {
  steps : Simulator.step_result list;
      (** All step results in chronological order *)
  final_portfolio : Trading_portfolio.Portfolio.t;  (** Final portfolio state *)
  metrics : metric_set;  (** Computed metrics from the simulation *)
}
(** Complete result of running a simulation with metrics *)
