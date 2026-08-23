open Core

type per_metric_stats = {
  mean : float;
  stdev : float;
  min : float;
  max : float;
}
[@@deriving sexp]

let nan_per_metric_stats : per_metric_stats =
  { mean = Float.nan; stdev = Float.nan; min = Float.nan; max = Float.nan }

type fold_actual = {
  fold_name : string;
  variant_label : string;
  total_return_pct : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
  calmar_ratio : float;
  cagr_pct : float;
  avg_holding_days : float; [@sexp.default Float.nan]
      (** Average holding period (days) over round-trip trades in this fold.
          NaN-defaulted on the sexp deserialiser so baseline aggregate.sexp
          fixtures produced before P5 infra continue to load. *)
  total_trades : int; [@sexp.default 0]
      (** Round-trip trade count for this fold ([NumTrades]). Zero-defaulted on
          the sexp deserialiser so aggregate.sexp fixtures produced before this
          column existed continue to load. *)
  max_trade_pnl_dollars : float; [@sexp.default Float.nan]
      (** Largest single winning round-trip in this fold, in dollars
          ([LargestWinDollar]). NaN-defaulted for the same back-compat reason as
          [avg_holding_days]. *)
}
[@@deriving sexp]

type variant_stability = {
  variant_label : string;
  total_return_pct : per_metric_stats;
  sharpe_ratio : per_metric_stats;
  max_drawdown_pct : per_metric_stats;
  calmar_ratio : per_metric_stats;
  cagr_pct : per_metric_stats;
  avg_holding_days : per_metric_stats; [@sexp.default nan_per_metric_stats]
      (** Cross-fold summary of per-fold [avg_holding_days]. NaN-defaulted on
          the sexp deserialiser so older aggregate.sexp files (pre-P5 infra)
          continue to load with a zeroed-out hold-cadence column; the scorer
          dropping NaN means the Composite formula collapses gracefully if the
          field is missing on either side. *)
  total_trades : per_metric_stats; [@sexp.default nan_per_metric_stats]
      (** Cross-fold summary of per-fold [total_trades] (int counts widened to
          float). NaN-defaulted on the sexp deserialiser for back-compat with
          aggregate.sexp files written before this column existed. *)
  max_trade_pnl_dollars : per_metric_stats; [@sexp.default nan_per_metric_stats]
      (** Cross-fold summary of per-fold [max_trade_pnl_dollars]. NaN-defaulted
          for the same back-compat reason as [total_trades]. *)
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
