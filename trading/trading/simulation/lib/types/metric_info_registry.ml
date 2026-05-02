(** Per-variant metric metadata + formatting helpers.

    Carved out of {!Metric_types} so the enum file stays under the file-length
    linter limit. The pre-existing public API in {!Metric_types} ([metric_unit],
    [metric_info], [get_metric_info], [format_metric], [format_metrics]) is
    preserved as thin re-exports pointing here, so existing call sites continue
    to compile unchanged. *)

(* @large-module: per-variant dispatch table for the full metric enum;
   inherently parallel to the variant list and not splittable further. *)

open Core
open Metric_types

type metric_unit = Dollars | Percent | Days | Count | Ratio
[@@deriving show, eq]

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
  | SortinoRatioAnnualized ->
      {
        display_name = "Sortino Ratio (Annualized)";
        description =
          "CAGR divided by annualized downside deviation. Like Sharpe, but \
           penalises only negative volatility.";
        unit = Ratio;
      }
  | MarRatio ->
      {
        display_name = "MAR Ratio";
        description =
          "CAGR divided by max drawdown. Identical formula to CalmarRatio over \
           a single backtest window; exposed under both names because the \
           literature treats Calmar as a 36-month rolling figure and MAR as \
           since-inception.";
        unit = Ratio;
      }
  | OmegaRatio ->
      {
        display_name = "Omega Ratio";
        description =
          "Omega(threshold = 0%): ratio of total positive step returns to \
           absolute total negative step returns. > 1 means gains exceed losses \
           by area.";
        unit = Ratio;
      }
  | AvgDrawdownPct ->
      {
        display_name = "Avg Drawdown";
        description =
          "Mean of trough depths across all peak→trough→recovery drawdown \
           episodes (the trailing in-progress episode is included).";
        unit = Percent;
      }
  | MedianDrawdownPct ->
      {
        display_name = "Median Drawdown";
        description = "Median trough depth across drawdown episodes.";
        unit = Percent;
      }
  | MaxDrawdownDurationDays ->
      {
        display_name = "Max Drawdown Duration";
        description =
          "Longest single drawdown episode duration in days (peak to recovery, \
           or peak to end-of-run if not yet recovered).";
        unit = Days;
      }
  | AvgDrawdownDurationDays ->
      {
        display_name = "Avg Drawdown Duration";
        description = "Mean drawdown episode duration in days.";
        unit = Days;
      }
  | TimeInDrawdownPct ->
      {
        display_name = "Time in Drawdown";
        description =
          "Percentage of trading days spent below the previous peak.";
        unit = Percent;
      }
  | UlcerIndex ->
      {
        display_name = "Ulcer Index";
        description =
          "Square-root of the mean of squared per-day drawdown percent. \
           Penalises both depth and duration.";
        unit = Ratio;
      }
  | PainIndex ->
      {
        display_name = "Pain Index";
        description =
          "Arithmetic mean of per-day drawdown percent. Linear in depth × \
           duration.";
        unit = Percent;
      }
  | UnderwaterCurveArea ->
      {
        display_name = "Underwater Curve Area";
        description =
          "Sum of per-day drawdown percent across the run (= PainIndex × \
           number of trading days). Reported in percent·days.";
        unit = Ratio;
      }
  | Skewness ->
      {
        display_name = "Skewness";
        description =
          "Third standardized moment of the per-step return distribution. \
           Positive = heavier right tail (gains); negative = heavier left tail \
           (losses).";
        unit = Ratio;
      }
  | Kurtosis ->
      {
        display_name = "Kurtosis (Excess)";
        description =
          "Fourth standardized moment of the per-step return distribution \
           minus 3. 0 = Gaussian; positive = fat-tailed; negative = \
           thin-tailed.";
        unit = Ratio;
      }
  | CVaR95 ->
      {
        display_name = "CVaR (95%)";
        description =
          "Conditional Value-at-Risk at 95% (Expected Shortfall): mean of the \
           worst 5% of step returns.";
        unit = Percent;
      }
  | CVaR99 ->
      {
        display_name = "CVaR (99%)";
        description =
          "Conditional Value-at-Risk at 99%: mean of the worst 1% of step \
           returns.";
        unit = Percent;
      }
  | TailRatio ->
      {
        display_name = "Tail Ratio";
        description =
          "mean(top 5% returns) / |mean(bottom 5% returns)|. > 1 means upside \
           tail dominates downside tail.";
        unit = Ratio;
      }
  | GainToPain ->
      {
        display_name = "Gain-to-Pain";
        description =
          "Sum of positive step returns divided by absolute sum of negative \
           step returns. > 1 means cumulative gains exceed cumulative losses.";
        unit = Ratio;
      }
  | ConcavityCoef ->
      {
        display_name = "Concavity Coefficient (γ)";
        description =
          "Antifragility coefficient from r_strat = α + β·r_bench + \
           γ·r_bench². γ > 0 = convex/antifragile; γ < 0 = concave/fragile. \
           Reported as 0 when no benchmark series is supplied.";
        unit = Ratio;
      }
  | BucketAsymmetry ->
      {
        display_name = "Bucket Asymmetry";
        description =
          "(Q1 + Q5) / (Q2 + Q3 + Q4) of strategy step returns bucketed by \
           benchmark quintile. > 1 means barbell (strategy concentrates \
           returns in extremes). Reported as 0 when no benchmark series is \
           supplied.";
        unit = Ratio;
      }

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
