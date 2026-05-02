(** Basic metric types with no dependencies.

    This module provides the fundamental types for the metrics framework. It has
    no dependencies on other simulation modules, allowing it to be used as a
    foundation for both Simulator and Metrics modules. *)

open Core

(** {1 Metric Type Enum} *)

(** Module containing the metric type enum with Map-compatible comparator *)
module Metric_type : sig
  type t =
    | TotalPnl  (** Total profit/loss in dollars *)
    | AvgHoldingDays  (** Average holding period *)
    | WinCount  (** Number of winning trades *)
    | LossCount  (** Number of losing trades *)
    | WinRate  (** Win percentage *)
    | SharpeRatio  (** Risk-adjusted return metric *)
    | MaxDrawdown  (** Maximum peak-to-trough decline *)
    | ProfitFactor  (** Gross profit / gross loss *)
    | CAGR  (** Compound annual growth rate *)
    | CalmarRatio  (** CAGR / max drawdown *)
    | OpenPositionCount  (** Open positions at end of simulation *)
    | OpenPositionsValue
        (** Signed mark-to-market value of all open positions at end of
            simulation: [Σ position_quantity(p) * current_close(p)] across each
            held position. Positive sum dominated by long mark-to-market;
            negative when shorts dominate. Equal to
            [portfolio_value - current_cash] on a marked-to-market step. NOT
            unrealized P&L — that requires subtracting cost basis (see
            [UnrealizedPnl]). *)
    | UnrealizedPnl
        (** True unrealized profit/loss on open positions at end of simulation:
            [Σ (current_close(p) - entry_price(p)) * signed_qty(p)] across each
            held position. Equal to [OpenPositionsValue - Σ position_cost_basis]
            (longs and shorts both fold in via signed quantity). Positive means
            paper gains on the open book; negative means paper losses. *)
    | TradeFrequency  (** Trades per month *)
    (* ---- M5.2b returns block ---- *)
    | TotalReturnPct
        (** Total period return as a percent:
            [(final - initial) / initial * 100]. Raw, not annualized — see
            [CAGR] for the annualized counterpart. *)
    | VolatilityPctAnnualized
        (** Annualized standard deviation of step-over-step portfolio returns,
            in percent. Multiplies the per-step stdev by [sqrt(252)] (assumes
            daily steps). *)
    | DownsideDeviationPctAnnualized
        (** Annualized standard deviation of {b negative} step returns only
            (returns above zero are treated as zero, in line with Sortino's
            convention). Reported in percent. *)
    | BestDayPct
        (** Largest single-step (one trading day) return, in percent. *)
    | WorstDayPct
        (** Smallest single-step (one trading day) return, in percent. *)
    | BestWeekPct
        (** Largest cumulative return over a calendar week, in percent. *)
    | WorstWeekPct
        (** Smallest cumulative return over a calendar week, in percent. *)
    | BestMonthPct  (** Largest cumulative return over a calendar month. *)
    | WorstMonthPct  (** Smallest cumulative return over a calendar month. *)
    | BestQuarterPct  (** Largest cumulative return over a calendar quarter. *)
    | WorstQuarterPct
        (** Smallest cumulative return over a calendar quarter. *)
    | BestYearPct  (** Largest cumulative return over a calendar year. *)
    | WorstYearPct  (** Smallest cumulative return over a calendar year. *)
    (* ---- M5.2b trade aggregates ---- *)
    | NumTrades  (** Total number of round-trip trades (= win + loss). *)
    | LossRate  (** Loss percentage (0–100); equals [100 - WinRate]. *)
    | AvgWinDollar  (** Mean P&L of winning round-trips, in dollars. *)
    | AvgWinPct
        (** Mean per-trade percent return of winning round-trips
            (entry-price-relative), in percent. *)
    | AvgLossDollar
        (** Mean P&L of losing round-trips, in dollars (negative). *)
    | AvgLossPct
        (** Mean per-trade percent return of losing round-trips, in percent
            (negative). *)
    | LargestWinDollar  (** Single largest winning round-trip, in dollars. *)
    | LargestLossDollar
        (** Single largest losing round-trip, in dollars (most negative). *)
    | AvgTradeSizeDollar
        (** Mean entry notional ([entry_price × quantity]) across all
            round-trips. *)
    | AvgTradeSizePct  (** Mean entry notional as a percent of initial cash. *)
    | AvgHoldingDaysWinners
        (** Mean [days_held] across winning round-trips only. *)
    | AvgHoldingDaysLosers
        (** Mean [days_held] across losing round-trips only. *)
    | Expectancy
        (** Per-trade expected dollars:
            [(win_rate × avg_win_dollar) - (loss_rate × |avg_loss_dollar|)]. *)
    | WinLossRatio
        (** [avg_win_dollar / |avg_loss_dollar|]; [Float.infinity] when there
            are wins but no losses. *)
    | MaxConsecutiveWins
        (** Longest run of consecutive winning round-trips (chronologically by
            entry date). *)
    | MaxConsecutiveLosses
        (** Longest run of consecutive losing round-trips. *)
  [@@deriving show, eq, compare, sexp]

  include Comparator.S with type t := t
end

(** Alias for convenience *)
type metric_type = Metric_type.t =
  | TotalPnl
  | AvgHoldingDays
  | WinCount
  | LossCount
  | WinRate
  | SharpeRatio
  | MaxDrawdown
  | ProfitFactor
  | CAGR
  | CalmarRatio
  | OpenPositionCount
  | OpenPositionsValue
  | UnrealizedPnl
  | TradeFrequency
  | TotalReturnPct
  | VolatilityPctAnnualized
  | DownsideDeviationPctAnnualized
  | BestDayPct
  | WorstDayPct
  | BestWeekPct
  | WorstWeekPct
  | BestMonthPct
  | WorstMonthPct
  | BestQuarterPct
  | WorstQuarterPct
  | BestYearPct
  | WorstYearPct
  | NumTrades
  | LossRate
  | AvgWinDollar
  | AvgWinPct
  | AvgLossDollar
  | AvgLossPct
  | LargestWinDollar
  | LargestLossDollar
  | AvgTradeSizeDollar
  | AvgTradeSizePct
  | AvgHoldingDaysWinners
  | AvgHoldingDaysLosers
  | Expectancy
  | WinLossRatio
  | MaxConsecutiveWins
  | MaxConsecutiveLosses
[@@deriving show, eq, compare, sexp]

(** {1 Metric Set} *)

type metric_set = float Map.M(Metric_type).t
(** A collection of metrics keyed by type. Use [Map.find] for lookup. *)

val empty : metric_set
(** Empty metric set *)

val singleton : metric_type -> float -> metric_set
(** Create a metric set with a single entry *)

val of_alist_exn : (metric_type * float) list -> metric_set
(** Create from association list. Raises if duplicate keys. *)

val merge : metric_set -> metric_set -> metric_set
(** Merge two metric sets. Later values override earlier ones. *)

val sexp_of_metric_set : metric_set -> Sexp.t
(** Serialize a metric set to sexp. *)

val metric_set_to_sexp_pairs : metric_set -> Sexp.t
(** Convert to a sexp list of [(key value)] pairs for human-readable output. *)

(** {1 Metric Unit} *)

(** Unit of measurement for formatting *)
type metric_unit =
  | Dollars  (** Monetary value in dollars *)
  | Percent  (** Percentage value (0-100 scale) *)
  | Days  (** Time duration in days *)
  | Count  (** Discrete count *)
  | Ratio  (** Dimensionless ratio *)
[@@deriving show, eq]

(** {1 Metric Info} *)

type metric_info = {
  display_name : string;  (** Human-readable name *)
  description : string;  (** Brief explanation *)
  unit : metric_unit;  (** Unit for formatting *)
}
(** Metadata about a metric type *)

val get_metric_info : metric_type -> metric_info
(** Get display info for a metric type *)

(** {1 Formatting} *)

val format_metric : metric_type -> float -> string
(** Format a single metric for display (e.g., "Sharpe Ratio: 1.25") *)

val format_metrics : metric_set -> string
(** Format all metrics for display, one per line *)
