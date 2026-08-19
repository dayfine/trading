;; Walk-forward surface — #2158 Phase 2 simulator StopLimit entry fills.
;;
;; Question: does the honest do-not-chase entry fill model
;; (StopLimit(entry, entry*(1+pct/100)) instead of Market fills, PR #2202,
;; default-off `enable_sim_entry_stoplimit`) change fold-level risk-adjusted
;; outcomes vs the historical Market fill model — and if so, at which cap?
;; Candidate caps bracket the Phase-1 armed live value (15pp, PR #2171):
;; {10, 15, 20} percentage points.
;;
;; This is a FILL-MODEL basis question, not an alpha knob: the mechanism only
;; changes HOW an already-decided entry fills (gap past the cap = no-fill,
;; candidate re-evaluated next Friday). Expected effects are (a) skipped
;; gap-chase entries (the MBX-class 14x-risk specimens), (b) occasional missed
;; winners that gapped and kept running. The surface decides which dominates.
;; Per experiment-flag-discipline R3 the default stays off unless this surface
;; (plus the promotion-confirmation grid) earns an ACCEPT.
;;
;; Fold geometry: identical to hysteresis_30fold_2026_05_29.sexp — 31 rolling
;; OOS folds across 2010-2026 sp500 historical, test_days=365 step_days=182.
;; Gate n=31 matches the generated count (pinned by test_spec.ml for the
;; sibling fixtures); m=16 = simple majority; worst_delta 0.20 Sharpe.
;;
;; Runner invocation (multi-hour, local-only, pinned-worktree + bind-mount
;; per .claude/rules/sweep-hygiene.md). GOTCHA: walk_forward_runner loads
;; base_scenario CWD-RELATIVE (raw Scenario.load, no fixtures-root join), so
;; the working directory MUST be <tree>/test_data/backtest_scenarios/ — the
;; "cd <tree>/trading root" incantation in older spec comments crashes with
;; Sys_error on the base path. Run the built binary directly:
;;   docker exec -d trading-1-dev bash -c \
;;     "WT=/workspaces/trading-1/.claude/worktrees/<sweep-worktree>/trading && \
;;      cd \$WT/test_data/backtest_scenarios && \
;;      export TRADING_DATA_DIR=\$WT/test_data && \
;;      nohup \$WT/_build/default/trading/backtest/walk_forward/bin/walk_forward_runner.exe \
;;        --spec ../walk_forward/sim_entry_stoplimit_31fold_2026_08_04.sexp \
;;        --out-dir /tmp/sweeps/stoplimit-entry-v1 --parallel 4 \
;;        > /tmp/sweeps/stoplimit-entry-v1.log 2>&1 &"
;;
;; Measured wall ~= 1h50m (31 folds x 4 variants, parallel 4, 525-sym panel).
;;
;; RESULT 2026-08-04: REJECT — ledger
;; dev/experiments/_ledger/2026-08-04-sim-entry-stoplimit-surface.sexp;
;; artifacts dev/experiments/stoplimit-entry-wfcv-2026-08-04/. Baseline alone
;; on the Pareto frontier; caps lose ~0.26 mean fold Sharpe with WORSE MaxDD
;; (entry-side fat-tail tax — see the ledger notes for the transferable why).

((base_scenario "goldens-sp500-historical/sp500-2010-2026.sexp")
 (window_spec
  (Rolling
   ((start_date 2010-01-01)
    (end_date 2026-04-30)
    (train_days 0)
    (test_days 365)
    (step_days 182))))
 (variants
  (;; market: the historical Market fill model — matches every existing
   ;; baseline (defaults; both arming knobs off). Empty overrides.
   ((label "market") (overrides ()))
   ((label "cap10")
    (overrides
     (((enable_sim_entry_stoplimit true)) ((entry_order_max_rest_weeks 0)) ((entry_extension_max_pct 10.0)))))
   ((label "cap15")
    (overrides
     (((enable_sim_entry_stoplimit true)) ((entry_order_max_rest_weeks 0)) ((entry_extension_max_pct 15.0)))))
   ((label "cap20")
    (overrides
     (((enable_sim_entry_stoplimit true)) ((entry_order_max_rest_weeks 0)) ((entry_extension_max_pct 20.0)))))))
 (baseline_label "market")
 (gate ((metric Sharpe) (m 16) (n 31) (worst_delta 0.20))))
