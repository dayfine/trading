open Core
module T = Walk_forward_types

let _per_fold_table (folds : T.fold_actual list) =
  let header =
    "| Fold | Variant | Return % | Sharpe | MaxDD % | Calmar |\n\
     |------|---------|---------:|-------:|--------:|-------:|"
  in
  let rows =
    List.map folds ~f:(fun (fa : T.fold_actual) ->
        sprintf "| %s | %s | %.2f | %.3f | %.2f | %.3f |" fa.fold_name
          fa.variant_label fa.total_return_pct fa.sharpe_ratio
          fa.max_drawdown_pct fa.calmar_ratio)
  in
  String.concat ~sep:"\n" (header :: rows)

let _stability_row (s : T.variant_stability) =
  sprintf "| %s | %.2f ± %.2f | %.3f ± %.3f | %.2f ± %.2f | %.3f ± %.3f |"
    s.variant_label s.total_return_pct.mean s.total_return_pct.stdev
    s.sharpe_ratio.mean s.sharpe_ratio.stdev s.max_drawdown_pct.mean
    s.max_drawdown_pct.stdev s.calmar_ratio.mean s.calmar_ratio.stdev

let _stability_table (agg : T.aggregate) =
  let header =
    "| Variant | Return % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar \
     (μ ± σ) |\n\
     |---------|-----------------:|---------------:|----------------:|--------------:|"
  in
  let rows = List.map agg.stability ~f:_stability_row in
  String.concat ~sep:"\n" (header :: rows)

let _sensitivity_row ~fold_count (s : T.variant_sensitivity) =
  sprintf "| %s | %d | %d |" s.variant_label s.wins_on_gate_metric fold_count

let _sensitivity_table (agg : T.aggregate) =
  let header =
    sprintf
      "Variant wins per fold on **%s** (vs baseline `%s`, %d folds total):\n\n\
       | Variant | Wins | of |\n\
       |---------|-----:|---:|"
      agg.metric_label agg.baseline_label agg.fold_count
  in
  let rows =
    List.map agg.sensitivity ~f:(_sensitivity_row ~fold_count:agg.fold_count)
  in
  String.concat ~sep:"\n" (header :: rows)

let _is_skipped_fail ~worst_fold ~worst_gap =
  String.is_empty worst_fold && Float.is_nan worst_gap

let _fail_line ~variant_label ~wins ~n ~worst_fold ~worst_gap ~reason =
  if _is_skipped_fail ~worst_fold ~worst_gap then
    sprintf "- **%s**: SKIPPED — %s" variant_label reason
  else
    sprintf
      "- **%s**: FAIL (%d / %d wins; worst fold `%s` gap %.4f). Reason: %s"
      variant_label wins n worst_fold worst_gap reason

let _one_verdict ~(gate : Fold_gate.t) ~variant_label (v : Fold_gate.verdict) =
  match v with
  | Fold_gate.Pass { wins; n } ->
      sprintf "- **%s**: PASS (%d / %d wins, Δ≤%.4f satisfied)" variant_label
        wins n gate.worst_delta
  | Fold_gate.Fail { wins; n; worst_fold; worst_gap; reason } ->
      _fail_line ~variant_label ~wins ~n ~worst_fold ~worst_gap ~reason

let _verdict_block ~(gate : Fold_gate.t) (agg : T.aggregate) =
  let header =
    sprintf
      "Gate: variant wins ≥%d of %d folds on **%s** vs baseline `%s`, no fold \
       worse by Δ>%.4f.\n"
      gate.m gate.n agg.metric_label agg.baseline_label gate.worst_delta
  in
  let lines =
    List.map agg.verdicts ~f:(fun (variant_label, v) ->
        _one_verdict ~gate ~variant_label v)
  in
  String.concat ~sep:"\n" (header :: lines)

let to_markdown ~(gate : Fold_gate.t) ~(fold_actuals : T.fold_actual list)
    (agg : T.aggregate) =
  String.concat ~sep:"\n\n"
    [
      "# Walk-forward CV report";
      "## 1. Per-fold metrics";
      _per_fold_table fold_actuals;
      "## 2. Stability (mean ± stdev across folds)";
      _stability_table agg;
      "## 3. Cross-fold sensitivity";
      _sensitivity_table agg;
      "## 4. Go/no-go verdict";
      _verdict_block ~gate agg;
    ]
