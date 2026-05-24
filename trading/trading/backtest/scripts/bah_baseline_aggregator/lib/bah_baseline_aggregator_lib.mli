(** Buy-And-Hold (BAH) baseline aggregate computer for the walk-forward sweep
    pipeline.

    Implements M4 T4.3 of
    [dev/plans/tuning-research-driven-program-v2-2026-05-25.md]: produces the
    [baseline_aggregate.sexp] the Bayesian production sweep consumes via
    [--baseline-aggregate]. The BAH series stands in for the "reference cell"
    against which candidate cells' composite scores are computed.

    {1 Pricing math}

    All math is pure arithmetic on [adjusted_close]:

    - [total_return_pct = (last / first - 1) * 100]
    - [sharpe_ratio = mean(r_daily) / stdev_sample(r_daily) * sqrt(252)] with
      [rf = 0]; [NaN] when fewer than 2 returns or [stdev = 0].
    - [max_drawdown_pct = 100 * max_t ((peak_so_far_t - price_t) /
       peak_so_far_t)] — positive percent, matching the backtest pipeline's
      [MaxDrawdown] sign convention.
    - [cagr_pct = ((1 + total_return_pct/100) ^ (1/years) - 1) * 100] where
      [years = test_days_calendar / 365.25]. For [test_days = 365],
      [cagr ≈ total_return].
    - [calmar_ratio = if max_dd = 0 then 0 else cagr_pct / max_drawdown_pct] —
      matches {!Trading_simulation.Metric_computers.calmar_ratio_derived}.
    - [avg_holding_days = test_days_calendar] — BAH holds one position for the
      full fold.

    {1 Variant-label convention}

    The output aggregate's [stability] entry uses
    [variant_label = walk_forward_spec.baseline_label] (= ["cell-E"] for the v7
    fixture). The Bayesian-runner scorer looks up
    [_lookup_stability ~label:baseline_label baseline_aggregate], where
    [baseline_label] is read from the walk-forward spec — NOT from the
    aggregate's metadata field. So callers must pass [~label] equal to the
    walk-forward-spec's [baseline_label] for the BO scorer's lookup to succeed.
    The aggregate's metadata [baseline_label] field carries the same string for
    consistency; the source-of-record for what the numbers represent (BAH-SPY vs
    BAH-BRK-A vs cell-E) is the output filename + the PR / docs context. *)

val compute_fold_actual :
  prices:Types.Daily_price.t list ->
  variant_label:string ->
  fold:Walk_forward.Window_spec.fold ->
  Walk_forward.Walk_forward_types.fold_actual
(** [compute_fold_actual ~prices ~variant_label ~fold] filters [prices] to the
    fold's [test_period] (inclusive both ends) and returns the per-fold BAH
    measurement record. [variant_label] is propagated verbatim into the returned
    record's [variant_label] field.

    All metrics are [Float.nan] when the windowed price list has fewer than 2
    entries (no return / stdev possible). [max_drawdown_pct] is always [>= 0.0]
    (positive-percent sign convention). *)

val compute_bah_aggregate :
  prices:Types.Daily_price.t list ->
  spec:Walk_forward.Window_spec.t ->
  label:string ->
  Walk_forward.Walk_forward_types.aggregate
(** [compute_bah_aggregate ~prices ~spec ~label] expands [spec] via
    {!Walk_forward.Window_spec.generate}, computes a per-fold BAH measurement
    for each fold, and aggregates via
    {!Walk_forward.Walk_forward_report.compute}.

    [label] is used as both the aggregate's [baseline_label] metadata AND the
    single [stability] entry's [variant_label]. The single-variant shape
    produces empty [sensitivity] / [verdicts] lists (the aggregator filters out
    the baseline label) — which is exactly what the BO scorer wants when this
    aggregate is consumed as [--baseline-aggregate].

    Raises [Failure] when [spec] generates zero folds (empty date range, or no
    fold fits). *)
