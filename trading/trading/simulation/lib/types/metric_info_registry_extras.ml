(** Per-variant metric_info for variants carved out of {!Metric_info_registry}
    to keep that file under the file-length linter limit.
    {!Metric_info_registry.get_metric_info} delegates the cases handled here. *)

open Metric_types
open Metric_info_types

let _info name desc unit = { display_name = name; description = desc; unit }

let info_for_benchmark_relative : metric_type -> metric_info option = function
  | BenchmarkAlphaPctAnnualized ->
      Some
        (_info "Alpha (annualized)"
           "OLS intercept α (annualized %) from r_strat = α + β·r_bench. 0 \
            with no benchmark."
           Percent)
  | BenchmarkBeta ->
      Some
        (_info "Beta" "OLS slope β. 0 when benchmark variance is zero." Ratio)
  | TrackingErrorPctAnnualized ->
      Some
        (_info "Tracking Error (annualized)"
           "Annualized stdev of (r_strat − r_bench). 0 with no benchmark."
           Percent)
  | InformationRatio ->
      Some
        (_info "Information Ratio"
           "Annualized α / Tracking Error. 0 when TE is zero." Ratio)
  | CorrelationToBenchmark ->
      Some
        (_info "Correlation to Benchmark"
           "Pearson r in [−1, 1]. 0 when either series is constant." Ratio)
  | _ -> None

let info_for_stability_turnover : metric_type -> metric_info option = function
  | RollingSharpeStability ->
      Some
        (_info "Rolling Sharpe Stability"
           "Stdev of rolling-90-day Sharpe across the equity curve. Lower = \
            steadier risk-adjusted return through time; 0 when fewer than two \
            full windows."
           Ratio)
  | TradeFrequencyAnnualized ->
      Some
        (_info "Trade Frequency (Annualized)"
           "Round-trips per calendar year (NumTrades × 365.25 / window days). \
            Distinct from TradeFrequency, which is trades/month."
           Ratio)
  | PositionTurnover ->
      Some
        (_info "Position Turnover"
           "Average daily churn intensity: Σ |Δ position notional| / \
            (mean(portfolio_value) × n_trading_days). 0 for buy-and-hold."
           Ratio)
  | PositionConcentrationHhi ->
      Some
        (_info "Position Concentration (HHI)"
           "Herfindahl-Hirschman index of position-value weights, sampled \
            every Friday and averaged. 1.0 = single position; lower = more \
            diversified."
           Ratio)
  | _ -> None
