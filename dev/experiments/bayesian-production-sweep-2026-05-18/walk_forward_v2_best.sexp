;; Walk-forward spec for the v2 Bayesian sweep winner (iter 1 of #1207-v2 spec_prod_v2).
;; Re-runs the canonical 31-fold sp500-2010-2026 with two variants:
;;   cell-E    = production defaults (baseline)
;;   v2-winner = cell-E + 4 tuned knobs
;; V2 widened the lower bounds vs v1 (max_position_pct_long 0.02, max_long_exposure_pct 0.30,
;; initial_stop_buffer wider) — see bayesian-prod-v1-result-2026-05-20.md §V2 recommendations.
;; Output goes to a sibling dir so we can run promote-gate (plan §6) on the full
;; fold_actuals.sexp / aggregate.sexp.
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
   ((label "v2-winner")
    (overrides
     (((portfolio_config ((max_position_pct_long 0.061055977995384675))))
      ((portfolio_config ((max_long_exposure_pct 0.33007810939089355))))
      ((initial_stop_buffer 1.0718143508150022))
      ((screening_config
        ((candidate_params ((installed_stop_min_pct 0.11391312086017732))))))
      )))))
 (baseline_label "cell-E")
 (gate ((metric Sharpe) (m 17) (n 30) (worst_delta 0.30))))
