(** Basic metric types with no dependencies. *)

open Core

(** {1 Metric Type Enum} *)

module Metric_type = struct
  module T = struct
    type t =
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
  end

  include T
  include Comparator.Make (T)
end

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

include (Metric_type : Comparator.S with type t := metric_type)

(** {1 Metric Set} *)

type metric_set = float Map.M(Metric_type).t

let empty = Map.empty (module Metric_type)

let singleton metric_type value =
  Map.singleton (module Metric_type) metric_type value

let of_alist_exn alist = Map.of_alist_exn (module Metric_type) alist
let merge m1 m2 = Map.merge_skewed m1 m2 ~combine:(fun ~key:_ _v1 v2 -> v2)

let sexp_of_metric_set m =
  Map.to_alist m
  |> List.map ~f:(fun (k, v) ->
      Sexp.List [ Metric_type.sexp_of_t k; Float.sexp_of_t v ])
  |> fun l -> Sexp.List l

let _format_value v =
  if Float.is_integer v then sprintf "%.0f" v else sprintf "%.2f" v

let metric_set_to_sexp_pairs m =
  Map.to_alist m
  |> List.map ~f:(fun (k, v) ->
      let name = String.lowercase (Metric_type.show k) in
      Sexp.List [ Sexp.Atom name; Sexp.Atom (_format_value v) ])
  |> fun l -> Sexp.List l

(** {1 Metric Unit} *)

type metric_unit = Dollars | Percent | Days | Count | Ratio
[@@deriving show, eq]

(** {1 Metric Info} *)

type metric_info = {
  display_name : string;
  description : string;
  unit : metric_unit;
}

let get_metric_info = function
  | TotalPnl ->
      {
        display_name = "Total P&L";
        description = "Sum of profit/loss across all trades";
        unit = Dollars;
      }
  | AvgHoldingDays ->
      {
        display_name = "Avg Holding Period";
        description = "Average number of days positions were held";
        unit = Days;
      }
  | WinCount ->
      {
        display_name = "Winning Trades";
        description = "Number of profitable trades";
        unit = Count;
      }
  | LossCount ->
      {
        display_name = "Losing Trades";
        description = "Number of unprofitable trades";
        unit = Count;
      }
  | WinRate ->
      {
        display_name = "Win Rate";
        description = "Percentage of trades that were profitable";
        unit = Percent;
      }
  | SharpeRatio ->
      {
        display_name = "Sharpe Ratio";
        description =
          "Risk-adjusted return (annualized): excess return over risk-free \
           rate divided by volatility";
        unit = Ratio;
      }
  | MaxDrawdown ->
      {
        display_name = "Max Drawdown";
        description =
          "Maximum percentage decline from peak portfolio value during \
           simulation";
        unit = Percent;
      }
  | ProfitFactor ->
      {
        display_name = "Profit Factor";
        description =
          "Gross profit divided by gross loss from round-trip trades. > 1 \
           means profitable";
        unit = Ratio;
      }
  | CAGR ->
      {
        display_name = "CAGR";
        description =
          "Compound annual growth rate — this IS the annualized-return metric. \
           Expressed as a percent, it is the constant yearly rate that \
           compounds initial portfolio value to final portfolio value over the \
           backtest period. Use this to compare scenarios of different lengths \
           apples-to-apples.";
        unit = Percent;
      }
  | CalmarRatio ->
      {
        display_name = "Calmar Ratio";
        description =
          "CAGR divided by max drawdown. Higher values indicate better \
           risk-adjusted returns";
        unit = Ratio;
      }
  | OpenPositionCount ->
      {
        display_name = "Open Positions";
        description = "Number of open positions at end of simulation";
        unit = Count;
      }
  | OpenPositionsValue ->
      {
        display_name = "Open Positions Value";
        description =
          "Signed mark-to-market value of all open positions at end of \
           simulation. Equals last-marked-to-market portfolio_value minus \
           current_cash on that step (= sum of [position_quantity(p) * \
           current_close(p)] across each held position, with long \
           contributions positive and short contributions negative). Computed \
           from the most recent step whose portfolio_value actually reflects \
           position mark-to-market — non-trading days (weekends, holidays, \
           missing bars) are skipped because the simulator falls back to \
           portfolio_value = cash on those days. NOT to be confused with \
           unrealized P&L (see [UnrealizedPnl]) — this metric does not \
           subtract cost basis.";
        unit = Dollars;
      }
  | UnrealizedPnl ->
      {
        display_name = "Unrealized P&L";
        description =
          "Total unrealized profit/loss on open positions at end of \
           simulation: sum of [(current_close(p) - entry_price(p)) * \
           signed_qty(p)] across each held position, where signed_qty is \
           positive for longs and negative for shorts. Equivalently: \
           [OpenPositionsValue] minus the sum of position cost bases. Positive \
           means paper gains on the open book; negative means paper losses. \
           Computed from the most recent step whose portfolio_value actually \
           reflects position mark-to-market — non-trading days are skipped per \
           the same logic as [OpenPositionsValue].";
        unit = Dollars;
      }
  | TradeFrequency ->
      {
        display_name = "Trade Frequency";
        description = "Average number of trades per month";
        unit = Ratio;
      }
  | TotalReturnPct ->
      {
        display_name = "Total Return";
        description =
          "Total period return: (final - initial) / initial. Raw, not \
           annualized — use CAGR for annualized.";
        unit = Percent;
      }
  | VolatilityPctAnnualized ->
      {
        display_name = "Volatility (Annualized)";
        description =
          "Annualized standard deviation of step returns: per-step stdev × \
           sqrt(252).";
        unit = Percent;
      }
  | DownsideDeviationPctAnnualized ->
      {
        display_name = "Downside Deviation (Annualized)";
        description =
          "Annualized standard deviation of negative step returns only \
           (positive returns clipped to zero, Sortino convention).";
        unit = Percent;
      }
  | BestDayPct ->
      {
        display_name = "Best Day";
        description = "Largest single-step return in the period.";
        unit = Percent;
      }
  | WorstDayPct ->
      {
        display_name = "Worst Day";
        description = "Smallest single-step return in the period.";
        unit = Percent;
      }
  | BestWeekPct ->
      {
        display_name = "Best Week";
        description = "Largest cumulative return over a calendar week.";
        unit = Percent;
      }
  | WorstWeekPct ->
      {
        display_name = "Worst Week";
        description = "Smallest cumulative return over a calendar week.";
        unit = Percent;
      }
  | BestMonthPct ->
      {
        display_name = "Best Month";
        description = "Largest cumulative return over a calendar month.";
        unit = Percent;
      }
  | WorstMonthPct ->
      {
        display_name = "Worst Month";
        description = "Smallest cumulative return over a calendar month.";
        unit = Percent;
      }
  | BestQuarterPct ->
      {
        display_name = "Best Quarter";
        description = "Largest cumulative return over a calendar quarter.";
        unit = Percent;
      }
  | WorstQuarterPct ->
      {
        display_name = "Worst Quarter";
        description = "Smallest cumulative return over a calendar quarter.";
        unit = Percent;
      }
  | BestYearPct ->
      {
        display_name = "Best Year";
        description = "Largest cumulative return over a calendar year.";
        unit = Percent;
      }
  | WorstYearPct ->
      {
        display_name = "Worst Year";
        description = "Smallest cumulative return over a calendar year.";
        unit = Percent;
      }
  | NumTrades ->
      {
        display_name = "Number of Trades";
        description = "Total round-trip count (= win + loss).";
        unit = Count;
      }
  | LossRate ->
      {
        display_name = "Loss Rate";
        description = "Loss percentage; equals 100 - WinRate.";
        unit = Percent;
      }
  | AvgWinDollar ->
      {
        display_name = "Average Win";
        description = "Mean P&L of winning round-trips.";
        unit = Dollars;
      }
  | AvgWinPct ->
      {
        display_name = "Average Win %";
        description =
          "Mean per-trade percent return of winning round-trips, relative to \
           entry price.";
        unit = Percent;
      }
  | AvgLossDollar ->
      {
        display_name = "Average Loss";
        description = "Mean P&L of losing round-trips (negative).";
        unit = Dollars;
      }
  | AvgLossPct ->
      {
        display_name = "Average Loss %";
        description =
          "Mean per-trade percent return of losing round-trips (negative).";
        unit = Percent;
      }
  | LargestWinDollar ->
      {
        display_name = "Largest Win";
        description = "Single largest winning round-trip in dollars.";
        unit = Dollars;
      }
  | LargestLossDollar ->
      {
        display_name = "Largest Loss";
        description = "Single largest losing round-trip in dollars.";
        unit = Dollars;
      }
  | AvgTradeSizeDollar ->
      {
        display_name = "Average Trade Size";
        description = "Mean entry notional (entry_price × quantity) per trade.";
        unit = Dollars;
      }
  | AvgTradeSizePct ->
      {
        display_name = "Average Trade Size %";
        description = "Mean entry notional as a percent of initial cash.";
        unit = Percent;
      }
  | AvgHoldingDaysWinners ->
      {
        display_name = "Avg Holding Days (Winners)";
        description = "Mean days_held across winning round-trips only.";
        unit = Days;
      }
  | AvgHoldingDaysLosers ->
      {
        display_name = "Avg Holding Days (Losers)";
        description = "Mean days_held across losing round-trips only.";
        unit = Days;
      }
  | Expectancy ->
      {
        display_name = "Expectancy";
        description =
          "Per-trade expected dollars: win_rate × avg_win - loss_rate × \
           |avg_loss|.";
        unit = Dollars;
      }
  | WinLossRatio ->
      {
        display_name = "Win/Loss Ratio";
        description = "avg_win_dollar / |avg_loss_dollar|.";
        unit = Ratio;
      }
  | MaxConsecutiveWins ->
      {
        display_name = "Max Consecutive Wins";
        description =
          "Longest run of consecutive winning round-trips (chronological).";
        unit = Count;
      }
  | MaxConsecutiveLosses ->
      {
        display_name = "Max Consecutive Losses";
        description = "Longest run of consecutive losing round-trips.";
        unit = Count;
      }

(** {1 Formatting} *)

let format_metric metric_type value =
  let info = get_metric_info metric_type in
  match info.unit with
  | Dollars -> Printf.sprintf "%s: $%.2f" info.display_name value
  | Percent -> Printf.sprintf "%s: %.2f%%" info.display_name value
  | Days -> Printf.sprintf "%s: %.1f days" info.display_name value
  | Count -> Printf.sprintf "%s: %.0f" info.display_name value
  | Ratio -> Printf.sprintf "%s: %.4f" info.display_name value

let format_metrics metrics =
  Map.fold metrics ~init:[] ~f:(fun ~key ~data acc ->
      format_metric key data :: acc)
  |> List.rev |> String.concat ~sep:"\n"
