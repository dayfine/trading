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

let info_for_distribution_antifragility : metric_type -> metric_info option =
  function
  | Skewness ->
      Some
        (_info "Skewness"
           "Third standardized moment of the per-step return distribution. \
            Positive = heavier right tail (gains); negative = heavier left \
            tail (losses)."
           Ratio)
  | Kurtosis ->
      Some
        (_info "Kurtosis (Excess)"
           "Fourth standardized moment of the per-step return distribution \
            minus 3. 0 = Gaussian; positive = fat-tailed; negative = \
            thin-tailed."
           Ratio)
  | CVaR95 ->
      Some
        (_info "CVaR (95%)"
           "Conditional Value-at-Risk at 95% (Expected Shortfall): mean of the \
            worst 5% of step returns."
           Percent)
  | CVaR99 ->
      Some
        (_info "CVaR (99%)"
           "Conditional Value-at-Risk at 99%: mean of the worst 1% of step \
            returns."
           Percent)
  | TailRatio ->
      Some
        (_info "Tail Ratio"
           "mean(top 5% returns) / |mean(bottom 5% returns)|. > 1 means upside \
            tail dominates downside tail."
           Ratio)
  | GainToPain ->
      Some
        (_info "Gain-to-Pain"
           "Sum of positive step returns divided by absolute sum of negative \
            step returns. > 1 means cumulative gains exceed cumulative losses."
           Ratio)
  | ConcavityCoef ->
      Some
        (_info "Concavity Coefficient (γ)"
           "Antifragility coefficient from r_strat = α + β·r_bench + \
            γ·r_bench². γ > 0 = convex/antifragile; γ < 0 = concave/fragile. \
            Reported as 0 when no benchmark series is supplied."
           Ratio)
  | BucketAsymmetry ->
      Some
        (_info "Bucket Asymmetry"
           "(Q1 + Q5) / (Q2 + Q3 + Q4) of strategy step returns bucketed by \
            benchmark quintile. > 1 means barbell (strategy concentrates \
            returns in extremes). Reported as 0 when no benchmark series is \
            supplied."
           Ratio)
  | _ -> None
