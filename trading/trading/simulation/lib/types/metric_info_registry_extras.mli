(** Per-variant metric_info for variants carved out of {!Metric_info_registry}
    to keep that file under the file-length linter limit. Each helper here
    returns [Some info] for its family's variants and [None] for any other;
    {!Metric_info_registry.get_metric_info} delegates those cases here. *)

val info_for_benchmark_relative :
  Metric_types.metric_type -> Metric_info_types.metric_info option
(** Benchmark-relative (CAPM-style) family: [BenchmarkAlphaPctAnnualized],
    [BenchmarkBeta], [TrackingErrorPctAnnualized], [InformationRatio],
    [CorrelationToBenchmark]. *)

val info_for_stability_turnover :
  Metric_types.metric_type -> Metric_info_types.metric_info option
(** Stability + turnover family: [RollingSharpeStability],
    [TradeFrequencyAnnualized], [PositionTurnover], [PositionConcentrationHhi].
*)

val info_for_distribution_antifragility :
  Metric_types.metric_type -> Metric_info_types.metric_info option
(** Distribution-shape + antifragility family: [Skewness], [Kurtosis], [CVaR95],
    [CVaR99], [TailRatio], [GainToPain], [ConcavityCoef], [BucketAsymmetry]. *)
