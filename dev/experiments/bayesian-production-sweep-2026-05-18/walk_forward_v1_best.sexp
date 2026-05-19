;; Walk-forward spec for the v1 Bayesian sweep winner (iter 26 of #1207 spec_prod).
;; Re-runs the canonical 30-fold sp500-2010-2026 with two variants:
;;   baseline = cell-E (production defaults)
;;   v1-winner = cell-E + 4 tuned knobs
;; Output goes to a sibling dir so we can run promote-gate (plan §6) on the
;; full fold_actuals.sexp / aggregate.sexp.
((base_scenario "goldens-sp500-historical/sp500-2010-2026.sexp")
 (window_spec
  (Rolling
   ((start_date 2010-01-01)
    (end_date 2026-04-30)
    (train_days 0)
    (test_days 365)
    (step_days 182))))
 (variants
  (((label "cell-E") (overrides ()))
   ((label "v1-winner")
    (overrides
     (((portfolio_config ((max_position_pct_long 0.054312762227437125))))
      ((portfolio_config ((max_long_exposure_pct 0.5157450808219769))))
      ((initial_stop_buffer 1.0067805762900115))
      ((screening_config
        ((candidate_params ((installed_stop_min_pct 0.12739158445159726))))))
      )))))
 (baseline_label "cell-E")
 (gate ((metric Sharpe) (m 17) (n 30) (worst_delta 0.30))))
