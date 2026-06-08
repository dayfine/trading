(** Pure antifragility / time-underwater prototype metrics over a [float list].

    Companion to {!Dispersion_stats}: a small set of additive, analysis-only
    metrics from the evaluation scorecard (plan
    [dev/plans/evaluation-objective-and-metrics-2026-06-07.md] §P3). Every
    function here is pure (same input -> same output, no I/O, no backtest), so
    each is unit-tested directly against hand-built series.

    {b Additive only.} These are reported metrics. They do not change any
    strategy behaviour, are not wired into the default metric suite, and so
    leave every existing golden result bit-identical. The simulation layer
    already exposes step-based counterparts ([TimeInDrawdownPct], [TailRatio],
    [Skewness] in {!Trading_simulation_types.Metric_types}); these are the
    equity-curve / period-return-series formulations the rolling-start harness
    consumes.

    Treat the antifragility (convexity) metrics skeptically — per the plan they
    are prototypes, validated for non-noise before promotion to the scorecard.

    {b Deferred:} the worst-volatility-decile conditional return prototype
    requires a per-period volatility / regime tag that is not available from a
    plain return series; it is out of scope for this module. *)

val time_underwater_pct : float list -> float
(** [time_underwater_pct equity_curve] is the fraction of observations in the
    chronological NAV series [equity_curve] that sit {b strictly below} the
    running prior high-water mark (the max of all {e earlier} points), expressed
    as a percent in [0.0, 100.0].

    The first point establishes the initial high-water and is never counted as
    underwater. Each subsequent point is underwater iff it is strictly less than
    the high-water established by the points before it; the high-water then
    advances to include that point.

    - A monotone non-decreasing series (every point a new high or a tie) -> 0.0.
    - A flat series -> 0.0 (no point is strictly below the prior high).
    - An empty or singleton series -> 0.0 (no prior high to be below). *)

val tail_ratio : float list -> float
(** [tail_ratio returns] is the convexity tail-ratio [|p95| / |p5|] of the
    period-return series [returns] (plan §1.4): the magnitude of the 95th
    percentile return over the magnitude of the 5th percentile return. Both
    percentiles use the type-7 (linear-interpolation) method via
    {!Dispersion_stats.percentile}.

    A value [> 1] means the upper tail dominates the lower tail (a convex,
    barbell-shaped return distribution); [< 1] means the downside tail
    dominates.

    - Returns [Float.infinity] when the 5th-percentile magnitude is [0.0] while
      the 95th-percentile magnitude is positive (an all-upside tail).
    - Returns [0.0] for an empty list, and when both tail magnitudes are [0.0].
*)

val return_skew : float list -> float
(** [return_skew returns] is the skewness (third standardized moment) of the
    period-return series [returns]: [E[(r - mean)^3] / sigma^3], using the
    {b population} variance (divide by N), matching the simulation-layer
    [Skewness] metric's convention.

    [0.0] for a symmetric distribution; positive means a heavier right (gain)
    tail; negative means a heavier left (loss) tail.

    - Returns [0.0] for an empty or singleton list (no defined spread).
    - Returns [0.0] when the variance is [0.0] (a flat series). *)
