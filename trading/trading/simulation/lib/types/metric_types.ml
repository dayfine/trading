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
      | SortinoRatioAnnualized
      | MarRatio
      | OmegaRatio
      | AvgDrawdownPct
      | MedianDrawdownPct
      | MaxDrawdownDurationDays
      | AvgDrawdownDurationDays
      | TimeInDrawdownPct
      | UlcerIndex
      | PainIndex
      | UnderwaterCurveArea
      | Skewness
      | Kurtosis
      | CVaR95
      | CVaR99
      | TailRatio
      | GainToPain
      | ConcavityCoef
      | BucketAsymmetry
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
  | SortinoRatioAnnualized
  | MarRatio
  | OmegaRatio
  | AvgDrawdownPct
  | MedianDrawdownPct
  | MaxDrawdownDurationDays
  | AvgDrawdownDurationDays
  | TimeInDrawdownPct
  | UlcerIndex
  | PainIndex
  | UnderwaterCurveArea
  | Skewness
  | Kurtosis
  | CVaR95
  | CVaR99
  | TailRatio
  | GainToPain
  | ConcavityCoef
  | BucketAsymmetry
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
