open Core

type fold_actual = {
  fold_name : string;
  variant_label : string;
  total_return_pct : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
  calmar_ratio : float;
  cagr_pct : float;
}
[@@deriving sexp]

type per_metric_stats = {
  mean : float;
  stdev : float;
  min : float;
  max : float;
}
[@@deriving sexp]

type variant_stability = {
  variant_label : string;
  total_return_pct : per_metric_stats;
  sharpe_ratio : per_metric_stats;
  max_drawdown_pct : per_metric_stats;
  calmar_ratio : per_metric_stats;
  cagr_pct : per_metric_stats;
}
[@@deriving sexp]

type variant_sensitivity = {
  variant_label : string;
  sharpe_wins : int;
  calmar_wins : int;
  total_return_wins : int;
  max_drawdown_wins : int;
}
[@@deriving sexp]

type aggregate = {
  fold_count : int;
  baseline_label : string;
  metric_label : string;
  stability : variant_stability list;
  sensitivity : variant_sensitivity list;
  verdicts : (string * Fold_gate.verdict) list;
}
[@@deriving sexp]
