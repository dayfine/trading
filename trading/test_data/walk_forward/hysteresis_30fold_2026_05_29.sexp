;; Walk-forward fixture — stage3 hysteresis revisit via 30-fold OOS CV.
;;
;; Authored 2026-05-29 PM after PR-B panel re-pin was REJECTED on data
;; (single-window-overfit: 5y win, 15y loss). See
;; `dev/notes/stage3-hysteresis-panel-rejected-2026-05-29.md` (PR #1364).
;;
;; Question this spec answers: does the autopsy-recommended hysteresis
;; setting `(hysteresis_weeks=2, stage3_exit_margin_pct=0.02)` beat the
;; current panel pin `(hysteresis_weeks=1, stage3_exit_margin_pct=0.0)`
;; across many OOS windows, not just on one 5y or one 15y panel?
;;
;; Fold geometry: identical to cell_e_30fold_2026_05_16.sexp — 30 rolling
;; OOS folds across 2010-2026 sp500 historical, test_days=365 step_days=182.
;;
;; Baseline = "h1-m0" (matches current panel pin, empty overrides).
;; Variant  = "h2-m02" (the autopsy candidate that lost on the 15y panel).
;;
;; Gate: variant "h2-m02" must beat baseline "h1-m0" on Sharpe in
;; ≥ 16 of 31 folds (>50%, simple majority), with no fold worse than
;; baseline by more than 0.20 Sharpe. The Rolling geometry below yields
;; 31 OOS folds (fold-000..fold-030) over 2010-2026 — n is set to 31 to
;; match the generated count so the gate evaluates rather than SKIPs on a
;; fold-count guard mismatch. Calibrated to be FAILABLE on the
;; same kind of disagreement that killed the 15y panel (the 15y panel
;; was 1 window worse by 0.16 Sharpe — would have been within tolerance,
;; but the failure-mode this spec catches is fold-distribution skew,
;; not single-window magnitude).
;;
;; Runner invocation (multi-hour, local-only, route output to bind-mount):
;;   docker exec -d trading-1-dev bash -c \
;;     "mkdir -p /tmp/sweeps/hysteresis-wf-30fold-2026-05-29 && \
;;      cd /workspaces/trading-1/trading && eval \$(opam env) && \
;;      nohup dune exec --no-build trading/backtest/walk_forward/bin/walk_forward_runner.exe -- \
;;        --spec trading/test_data/walk_forward/hysteresis_30fold_2026_05_29.sexp \
;;        --out-dir /tmp/sweeps/hysteresis-wf-30fold-2026-05-29 \
;;        --parallel 4 \
;;        > /tmp/sweeps/hysteresis-wf-30fold-2026-05-29.log 2>&1 &"
;;
;; Expected wall ≈ 60-90 min (30 folds × 2 variants × ~3 min / fold ÷ 4 parallel ≈ 50 min)

((base_scenario "goldens-sp500-historical/sp500-2010-2026.sexp")
 (window_spec
  (Rolling
   ((start_date 2010-01-01)
    (end_date 2026-04-30)
    (train_days 0)
    (test_days 365)
    (step_days 182))))
 (variants
  (;; h1-m0: matches the current panel pin (sp500-2010-2026.sexp already
   ;; pins `stage3_force_exit_config.hysteresis_weeks=1` and
   ;; `stage3_exit_margin_pct` defaults to 0.0). Empty overrides.
   ((label "h1-m0") (overrides ()))
   ;; h2-m02: the autopsy-recommended candidate that lost on the 15y
   ;; panel single-window test. Both knobs overridden on top of base.
   ((label "h2-m02")
    (overrides
     (((stage3_force_exit_config ((hysteresis_weeks 2))))
      ((stage3_exit_margin_pct 0.02)))))))
 (baseline_label "h1-m0")
 (gate ((metric Sharpe) (m 16) (n 31) (worst_delta 0.20))))
