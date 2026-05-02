(** Pre-built metric computers — assembly and factory.

    Individual computers live in their own modules:
    - {!Summary_computer}
    - {!Sharpe_computer}
    - {!Drawdown_computer}
    - {!Cagr_computer}
    - {!Portfolio_state_computer}
    - {!Trade_aggregates_computer} (M5.2b)
    - {!Return_basics_computer} (M5.2b) *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types

(** {1 Re-exports for backwards compatibility} *)

let summary_computer = Summary_computer.computer
let sharpe_ratio_computer = Sharpe_computer.computer
let max_drawdown_computer = Drawdown_computer.computer
let cagr_computer = Cagr_computer.computer
let portfolio_state_computer = Portfolio_state_computer.computer
let trade_aggregates_computer = Trade_aggregates_computer.computer
let return_basics_computer = Return_basics_computer.computer

(** {1 Derived Metric Computers} *)

let calmar_ratio_derived : Simulator_types.derived_metric_computer =
  {
    name = "calmar_ratio";
    depends_on = [ CAGR; MaxDrawdown ];
    compute =
      (fun ~config:_ ~base_metrics ->
        let get k = Map.find base_metrics k |> Option.value ~default:0.0 in
        let cagr = get CAGR in
        let max_dd = get MaxDrawdown in
        let calmar = if Float.( = ) max_dd 0.0 then 0.0 else cagr /. max_dd in
        Metric_types.singleton CalmarRatio calmar);
  }

(** {1 Factory} *)

let _calmar_stub () =
  Simulator_types.wrap_computer
    {
      name = "calmar_stub";
      init = (fun ~config:_ -> ());
      update = (fun ~state:() ~step:_ -> ());
      finalize =
        (fun ~state:() ~config:_ -> Metric_types.singleton CalmarRatio 0.0);
    }

let create_computer (metric_type : Metric_types.metric_type) :
    Simulator_types.any_metric_computer =
  match metric_type with
  | TotalPnl | AvgHoldingDays | WinCount | LossCount | WinRate | ProfitFactor ->
      summary_computer ()
  | SharpeRatio -> sharpe_ratio_computer ()
  | MaxDrawdown -> max_drawdown_computer ()
  | CAGR -> cagr_computer ()
  | CalmarRatio -> _calmar_stub ()
  | OpenPositionCount | OpenPositionsValue | UnrealizedPnl | TradeFrequency ->
      portfolio_state_computer ()
  | NumTrades | LossRate | AvgWinDollar | AvgWinPct | AvgLossDollar | AvgLossPct
  | LargestWinDollar | LargestLossDollar | AvgTradeSizeDollar | AvgTradeSizePct
  | AvgHoldingDaysWinners | AvgHoldingDaysLosers | Expectancy | WinLossRatio
  | MaxConsecutiveWins | MaxConsecutiveLosses ->
      trade_aggregates_computer ()
  | TotalReturnPct | VolatilityPctAnnualized | DownsideDeviationPctAnnualized
  | BestDayPct | WorstDayPct | BestWeekPct | WorstWeekPct | BestMonthPct
  | WorstMonthPct | BestQuarterPct | WorstQuarterPct | BestYearPct
  | WorstYearPct ->
      return_basics_computer ()

(** {1 Default Computer Set} *)

let default_computers ?(risk_free_rate = 0.0) ?(initial_cash = 0.0) () =
  [
    summary_computer ();
    sharpe_ratio_computer ~risk_free_rate ();
    max_drawdown_computer ();
    cagr_computer ();
    portfolio_state_computer ();
    trade_aggregates_computer ~initial_cash ();
    return_basics_computer ();
  ]

let default_derived_computers () = [ calmar_ratio_derived ]

let default_metric_suite ?(risk_free_rate = 0.0) ?(initial_cash = 0.0) () :
    Simulator_types.metric_suite =
  {
    computers = default_computers ~risk_free_rate ~initial_cash ();
    derived = default_derived_computers ();
  }
