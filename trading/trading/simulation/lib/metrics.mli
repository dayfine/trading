(** Trade metrics computation for performance analysis.

    This module provides types and functions for computing trade metrics from
    simulation results. It extracts round-trip trades (buy followed by sell) and
    computes summary statistics like P&L, win rate, and holding periods.

    Part of Phase 7: Performance Metrics in the simulation framework. *)

open Core

(** {1 Trade Metrics Types} *)

type trade_metrics = {
  symbol : string;  (** The traded symbol *)
  side : Trading_base.Types.side;
      (** Direction of the round-trip's {b entry} leg. [Buy] means a long
          round-trip (Buy→Sell); [Sell] means a short round-trip (Sell→Buy where
          the closing buy covers the short). Callers that distinguish long vs
          short P&L (release-report, [trades.csv], regression metrics) must
          dispatch on this field. *)
  entry_date : Date.t;  (** Date of entry — the open leg *)
  exit_date : Date.t;  (** Date of exit — the close leg *)
  days_held : int;  (** Number of days position was held *)
  entry_price : float;  (** Price at entry — i.e. the open-leg fill price *)
  exit_price : float;  (** Price at exit — i.e. the close-leg fill price *)
  quantity : float;  (** Number of shares traded *)
  pnl_dollars : float;
      (** Profit/loss in dollars. Long: [(exit − entry) × qty]. Short:
          [(entry − exit) × qty] (positive when cover price < entry). *)
  pnl_percent : float;
      (** Profit/loss as percentage of entry price. Mirrored direction so a
          positive reading always means profit, regardless of long or short. *)
}
[@@deriving show, eq]
(** Metrics for a completed round-trip trade.

    A round-trip trade consists of an entry followed by a close trade for the
    same symbol. Two directions are supported: long (Buy→Sell) and short
    (Sell→Buy, where the closing buy covers the short). [side] tags the
    direction of the entry leg so downstream consumers can dispatch P&L
    semantics. *)

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

(** {1 Trade Metrics Functions} *)

val extract_round_trips :
  Trading_simulation_types.Simulator_types.step_result list ->
  trade_metrics list
(** Extract round-trip trades from simulation step results.

    A round-trip is identified by pairing an entry trade with the next close
    trade for the same symbol. Two directions are paired:

    - {b Long} round-trip: Buy → Sell, with [side = Buy] in the result.
    - {b Short} round-trip: Sell → Buy (the buy covers the short), with
      [side = Sell] in the result.

    Trades are matched in chronological order, with each entry paired with the
    next opposite-side trade for the same symbol. A trailing entry trade with no
    matching close (e.g., an open position at the end of the simulation window)
    is dropped.

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

(** {1 Conversion Functions} *)

val summary_stats_to_metrics :
  summary_stats -> Trading_simulation_types.Metric_types.metric_set
(** Convert summary_stats to metric_set *)

val compute_profit_factor : trade_metrics list -> float
(** Compute profit factor: gross profit divided by gross loss across the given
    round-trips. Returns [Float.infinity] when there are profitable trades but
    no losses, and [0.0] when there are no trades or no profits. *)

val compute_round_trip_metric_set :
  trade_metrics list -> Trading_simulation_types.Metric_types.metric_set
(** Build the round-trip-derived metric set ([TotalPnl], [AvgHoldingDays],
    [WinCount], [LossCount], [WinRate], [ProfitFactor]) directly from a list of
    round-trips.

    Empty [round_trips] yields just [{ ProfitFactor = 0.0 }] — matching the
    legacy [Summary_computer] convention. The win/loss/PnL keys are omitted so
    an empty-range overlay leaves the simulator's pre-existing reading intact
    via [Metric_types.merge].

    This is the canonical computation of round-trip-derived metrics — callers
    that have already extracted [round_trips] should use this rather than
    re-running the simulator's [Summary_computer] over a step list, which
    re-derives [round_trips] internally and may pair across step ranges that
    differ from the caller's window. See [Backtest.Runner._make_summary] for the
    warmup-vs-range-window alignment use case. *)
