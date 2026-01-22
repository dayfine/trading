(** Trade metrics computation for performance analysis.

    This module provides types and functions for computing trade metrics from
    simulation results. It extracts round-trip trades (buy followed by sell) and
    computes summary statistics like P&L, win rate, and holding periods.

    Part of Phase 7: Performance Metrics in the simulation framework. *)

open Core

(** {1 Types} *)

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

(** {1 Functions} *)

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
