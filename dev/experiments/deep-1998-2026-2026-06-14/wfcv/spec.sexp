;; Deep 28y baseline-robustness WF-CV: Cell-E per-year folds 1998-2026, snapshot mode. Baseline-only (no axes).
((base_scenario "/tmp/deep-wfcv/base.sexp")
 (window_spec
  (Rolling ((start_date 1998-01-01)(end_date 2026-04-30)(train_days 0)(test_days 365)(step_days 365))))
 (variants (((label "baseline") (overrides ()))))
 (baseline_label "baseline")
 (gate ((metric Sharpe) (m 1) (n 28) (worst_delta 0.30))))
