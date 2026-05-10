(** Benchmark-relative metrics: CAPM-style alpha + beta, tracking error,
    Information Ratio, and correlation to benchmark.

    The four base metrics are produced from a single linear regression
    [r_strat = α + β · r_bench] over per-step (daily) percent returns:

    - {b BenchmarkBeta} — slope β
    - {b BenchmarkAlphaPctAnnualized} — intercept α annualized to %/year
      (multiplied by 252)
    - {b TrackingErrorPctAnnualized} — annualized stdev of the active return
      series [r_strat - r_bench]
    - {b CorrelationToBenchmark} — Pearson correlation of the two series

    The Information Ratio is folded into the same computer for cohesion:

    - {b InformationRatio} — α / TrackingError (both annualized; ratio is
      dimensionless)

    All five metrics are emitted as [0.0] when no benchmark series is supplied
    or the alignment yields fewer than the minimum paired samples. *)

val computer :
  ?benchmark_returns:float list ->
  unit ->
  Trading_simulation_types.Simulator_types.any_metric_computer
(** Build the benchmark-relative metric computer. Mirrors
    {!Antifragility_computer.computer}'s API: when [benchmark_returns] is
    [Some], that series takes precedence over per-step
    [step.benchmark_return]; when [None], the step-sourced series is used.
    The override path is for synthetic tests that pin specific benchmark
    values without going through the simulator. *)
