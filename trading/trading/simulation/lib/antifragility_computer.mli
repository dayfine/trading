(** Antifragility / barbell metrics (M5.2d).

    These metrics describe the strategy's response curve as a function of a
    {b benchmark} (default convention: SPY total return). The strategy's
    per-step return is regressed quadratically against the benchmark's per-step
    return; the curvature term [γ] (coefficient of [r_bench²]) is the
    {b concavity coefficient} after Taleb:

    - [γ > 0] → convex / antifragile (strategy gains more than linearly in
      benchmark extremes);
    - [γ < 0] → concave / fragile (strategy gives back gains in benchmark
      extremes);
    - [γ ≈ 0] → linear-tracking response.

    [BucketAsymmetry] is a non-parametric companion: bin benchmark per-step
    returns into quintiles (Q1..Q5), compute the strategy's mean return per
    bucket, then report [(Q1_mean + Q5_mean) / (Q2_mean + Q3_mean + Q4_mean)].
    Values > 1 indicate a barbell shape (strategy concentrates returns in the
    benchmark's extremes). Values ≤ 1 indicate a middle-heavy shape.

    {b Benchmark plumbing.} The simulator's [step_result] does not currently
    track benchmark returns. To avoid an invasive surface change in this PR, the
    benchmark series is supplied directly at computer construction:

    {[
      let computer = Antifragility_computer.computer ~benchmark_returns:[ ... ] ()
    ]}

    When [benchmark_returns] is [None] (the default for stand-alone backtest
    runs), both [ConcavityCoef] and [BucketAsymmetry] are emitted as [0.0]. A
    follow-up PR will plumb a benchmark feed through the simulator, at which
    point this computer will read the series from [config] instead.

    {b OLS formula.} Given paired samples [(x_i, y_i)] with [x = r_bench],
    [y = r_strat], the model is [y = α + β·x + γ·x²]. Define [u = x²]. Then
    [α, β, γ] solve the normal equations of multivariate OLS with predictors
    [(1, x, u)]. We compute the closed-form solution via the [3 × 3] matrix
    inversion of [Xᵀ X], using [Σ x^k] sums for [k ∈ {0..4}] and [Σ x^j y] for
    [j ∈ {0..2}]. Numerically stable for the small return magnitudes
    (single-digit percent) we feed in; we return [0.0] if the matrix determinant
    is ≤ a small threshold (degenerate sample).

    Pure: same step list + same benchmark series → same output. *)

val computer :
  ?benchmark_returns:float list ->
  unit ->
  Trading_simulation_types.Simulator_types.any_metric_computer
(** Build the step-based computer that emits [ConcavityCoef] and
    [BucketAsymmetry].

    @param benchmark_returns
      Optional per-step benchmark percent-return series. When supplied, the list
      must be in chronological order; the computer aligns it to the strategy's
      per-step returns by truncating the longer side. When [None], both metrics
      are emitted as [0.0].

    Edge cases:
    - Fewer than 5 paired samples → both metrics 0.0 (insufficient data for a
      stable quadratic fit and for quintile bucketing).
    - Degenerate quadratic system (zero variance in benchmark, or small
      determinant of [Xᵀ X]) → [ConcavityCoef] = 0.0.
    - Empty bucket sums in the denominator of [BucketAsymmetry] → fall back to
      0.0 to avoid division by a zero magnitude. *)
