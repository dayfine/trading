(** Shared types for walk-forward CV reports.

    Split out of {!Walk_forward_report} so that {!Walk_forward_render} (the
    markdown emitter) can depend on the types without creating a cycle with the
    [compute → render] call edge. *)

type per_metric_stats = {
  mean : float;
  stdev : float;  (** Sample stdev; [Float.nan] when N < 2. *)
  min : float;  (** Minimum over folds; [Float.nan] when N = 0. *)
  max : float;  (** Maximum over folds; [Float.nan] when N = 0. *)
}
[@@deriving sexp]
(** Cross-fold summary statistics for one (variant, metric) cell. *)

val nan_per_metric_stats : per_metric_stats
(** All-NaN [per_metric_stats] used as the [[\@sexp.default]] for
    [variant_stability.avg_holding_days] so older [aggregate.sexp] files
    (produced before the P5 hold-cadence infra) continue to deserialise into the
    new shape with an empty hold-cadence column. *)

type fold_actual = {
  fold_name : string;
  variant_label : string;
  total_return_pct : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
  calmar_ratio : float;
  cagr_pct : float;
      (** Annualised return for the fold's test period, derived from
          [total_return_pct] and the test_period length:
          [((1 + total_return_pct/100) ^ (1/years) - 1) * 100] where
          [years = test_days / 365.25]. Equal to [total_return_pct] (within
          tolerance) when [test_days = 365]; populated by the binary that has
          access to the fold's calendar length. Producers that don't compute
          CAGR (older fold_actuals fixtures, manual constructions) may set this
          to [Float.nan]; the renderer prints "n/a" in that case. *)
  avg_holding_days : float;
      (** Average per-trade holding period for round-trip trades closed in this
          fold's test window. Populated by
          {!Walk_forward_executor._extract_fold} from
          [summary.metrics AvgHoldingDays].

          The sexp deserialiser defaults this field to [Float.nan] when absent,
          so older [aggregate.sexp] fixtures (produced before the P5 hold-
          cadence infra landed) still load — they simply carry NaN through to
          {!variant_stability.avg_holding_days} and the downstream scorer drops
          the term. *)
}
[@@deriving sexp]
(** One per-(fold, variant) measurement row. *)

type variant_stability = {
  variant_label : string;
  total_return_pct : per_metric_stats;
  sharpe_ratio : per_metric_stats;
  max_drawdown_pct : per_metric_stats;
  calmar_ratio : per_metric_stats;
  cagr_pct : per_metric_stats;
      (** Cross-fold summary of derived annualised return. Stats are NaN when
          input [fold_actual.cagr_pct] values are NaN. *)
  avg_holding_days : per_metric_stats;
      (** Cross-fold summary of per-trade average holding period (days).
          Surfaces the hold-cadence signal so the Bayesian Composite scorer can
          include an [(AvgHoldingDays w)] term in its weight list (P5 of
          [dev/plans/hold-period-deep-dive-2026-05-19.md] §P5). NaN-defaulted on
          the sexp deserialiser (via {!nan_per_metric_stats}) for back-compat
          with older aggregate.sexp fixtures. *)
}
[@@deriving sexp]
(** Six metric summaries for one variant — [total_return_pct], [sharpe_ratio],
    [max_drawdown_pct], [calmar_ratio], [cagr_pct], [avg_holding_days]. *)

type variant_sensitivity = {
  variant_label : string;
  sharpe_wins : int;
  calmar_wins : int;
  total_return_wins : int;
  max_drawdown_wins : int;
      (** "Wins" = lower MaxDrawdown% than baseline (lower is better). *)
}
[@@deriving sexp]
(** Per-variant win-counts on each of the four metrics. Excludes the baseline
    itself. The gate's metric is the column the verdict gates on; the other
    three columns are surfaced so the operator can see Sharpe-vs-MaxDD
    trade-offs at a glance. *)

type aggregate = {
  fold_count : int;
  baseline_label : string;
  metric_label : string;
  stability : variant_stability list;
  sensitivity : variant_sensitivity list;
  verdicts : (string * Fold_gate.verdict) list;
}
[@@deriving sexp]
(** Programmatic surface the Bayesian optimizer (Phase 3) consumes. *)
