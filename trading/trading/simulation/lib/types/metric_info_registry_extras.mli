(** Per-variant metric_info for the benchmark-relative (CAPM-style) family —
    [BenchmarkAlphaPctAnnualized], [BenchmarkBeta],
    [TrackingErrorPctAnnualized], [InformationRatio], [CorrelationToBenchmark].
    Returns [Some info] for those five variants and [None] for any other.
    {!Metric_info_registry.get_metric_info} delegates those cases here so that
    file stays under the file-length linter limit. *)

val info_for_benchmark_relative :
  Metric_types.metric_type -> Metric_info_types.metric_info option
