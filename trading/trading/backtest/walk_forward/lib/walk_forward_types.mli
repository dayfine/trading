(** Shared types for walk-forward CV reports.

    Split out of {!Walk_forward_report} so that {!Walk_forward_render} (the
    markdown emitter) can depend on the types without creating a cycle with the
    [compute → render] call edge. *)

type fold_actual = {
  fold_name : string;
  variant_label : string;
  total_return_pct : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
  calmar_ratio : float;
}
[@@deriving sexp]
(** One per-(fold, variant) measurement row. *)

type per_metric_stats = {
  mean : float;
  stdev : float;  (** Sample stdev; [Float.nan] when N < 2. *)
  min : float;  (** Minimum over folds; [Float.nan] when N = 0. *)
  max : float;  (** Maximum over folds; [Float.nan] when N = 0. *)
}
[@@deriving sexp]
(** Cross-fold summary statistics for one (variant, metric) cell. *)

type variant_stability = {
  variant_label : string;
  total_return_pct : per_metric_stats;
  sharpe_ratio : per_metric_stats;
  max_drawdown_pct : per_metric_stats;
  calmar_ratio : per_metric_stats;
}
[@@deriving sexp]
(** All four metric summaries for one variant. *)

type variant_sensitivity = { variant_label : string; wins_on_gate_metric : int }
[@@deriving sexp]
(** Per-variant win-count on the gate's metric. Excludes the baseline itself. *)

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
