;; Walk-forward spec for V3 winner fold-29 deep dive (2026-05-21).
;;
;; fold-29 in the canonical 31-fold rolling spec spans 2024-01-02 →
;; 2025-01-01 (1-year test window). V3 winner OOS Sharpe on this fold
;; = -0.658, the single fold that fails 5-axis gate axis-3
;; (every OOS fold ≥ 0.50). Goal: re-run V3 winner + cell-E on JUST
;; this window to inspect what went wrong — per-symbol trades, max-DD
;; timing, exit triggers.
;;
;; window: step_days=365 with same start/end gives exactly 1 fold
;; matching fold-29's calendar window.
((base_scenario "/workspaces/trading-1/trading/test_data/backtest_scenarios/goldens-sp500-historical/sp500-2010-2026.sexp")
 (window_spec
  (Rolling
   ((start_date 2024-06-13)
    (end_date 2025-06-13)
    (train_days 0)
    (test_days 365)
    (step_days 365))))
 (variants
  (((label "cell-E") (overrides ()))
   ((label "v3-winner")
    (overrides
     (((portfolio_config ((max_position_pct_long 0.065089764330512848))))
      ((portfolio_config ((max_long_exposure_pct 0.46850960577901141))))
      ((initial_stop_buffer 1.0391593656980778))
      ((screening_config
        ((candidate_params ((installed_stop_min_pct 0.10703562236556739))))))
      )))))
 (baseline_label "cell-E")
 (gate ((metric Sharpe) (m 1) (n 1) (worst_delta 5.0))))
