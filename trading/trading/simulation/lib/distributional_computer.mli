(** Distributional return-shape metrics (M5.2d).

    Sweeps the daily portfolio-value series once and emits the per-step return
    distribution's higher moments and tail statistics:

    - [Skewness] — third standardized moment.
    - [Kurtosis] — fourth standardized moment minus 3 (excess kurtosis).
    - [CVaR95], [CVaR99] — Expected Shortfall (mean of the worst 5% / 1% of step
      returns), in percent.
    - [TailRatio] — [mean(top 5%) / |mean(bottom 5%)|].
    - [GainToPain] — [Σ gains / |Σ losses|].

    All metrics are computed on per-step (one-trading-day) percent returns.
    Annualization is not meaningful for these metrics: skewness and kurtosis are
    unitless, and the tail / pain statistics describe the empirical distribution
    at the same cadence as the input.

    Pure: same step list → same output. *)

val computer :
  unit -> Trading_simulation_types.Simulator_types.any_metric_computer
(** Build the step-based computer that emits the M5.2d distributional metrics.

    Edge cases:
    - Empty input or fewer than 2 trading-day steps → all metrics 0.0.
    - Zero variance (all returns equal) → skewness and kurtosis are 0.0 (defined
      this way to avoid division-by-zero noise; a flat curve has no asymmetry or
      tail-heaviness).
    - All-positive returns → [GainToPain] is [Float.infinity]; [TailRatio] is
      [Float.infinity] when the bottom-5% mean is zero and the top-5% mean is
      positive.
    - All-zero returns → [GainToPain] and [TailRatio] are 0.0.
    - The 5% / 1% cuts use [Float.iround_down]: the bottom-N is the lowest
      [floor(n × p)] returns. With fewer than [⌈1/p⌉] returns the cut is empty
      and the corresponding metrics fall back to 0.0. *)
