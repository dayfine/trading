open Core
module Cash_yield = Trading_simulation_cash_yield.Cash_yield
module Dividend_crediting = Trading_simulation_dividends.Dividend_crediting
module Metric_types = Trading_simulation_types.Metric_types

type t = {
  cash_yield : Cash_yield.Accrual.t option;
  dividends : Dividend_crediting.t option;
}

let step t ~date portfolio =
  let open Result.Let_syntax in
  let%bind portfolio = Cash_yield.Accrual.step t.cash_yield ~date portfolio in
  Dividend_crediting.step t.dividends ~date portfolio

let _dividend_metrics (totals : Dividend_crediting.totals) =
  [
    (Metric_types.DividendIncomeTotal, totals.long_income);
    (Metric_types.DividendPaidShortTotal, totals.short_paid);
    ( Metric_types.DividendSkippedNoAmountCount,
      Float.of_int totals.skipped_no_amount );
    (Metric_types.DividendMissingFileCount, Float.of_int totals.missing_files);
  ]

let _with_dividends metrics dividends =
  match dividends with
  | None -> metrics
  | Some d ->
      List.fold
        (_dividend_metrics (Dividend_crediting.totals d))
        ~init:metrics
        ~f:(fun acc (key, data) -> Map.set acc ~key ~data)

let add_metrics t metrics =
  let metrics = Simulator_metrics.with_cash_interest metrics t.cash_yield in
  _with_dividends metrics t.dividends
