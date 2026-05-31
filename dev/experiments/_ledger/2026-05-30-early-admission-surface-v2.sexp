((date 2026-05-30) (slug early-admission-surface-v2)
 (hypothesis
  "Does early Stage-2 admission (stage_config.early_admission_ma_period {5,7,10,13}) beat baseline across the FULL 2010-2026 distribution on the GSPC-repaired golden, and does the winner generalise to an independent 2019-2023 window?")
 (base_scenario goldens-sp500-historical/sp500-2010-2026.sexp)
 (window_id rolling-2010-2026-365-182-31fold-gspc2009repaired)
 (baseline_label baseline)
 (variants
  (((label baseline) (config_hash afb39cb5f979233bdfc57fbeface8c72)
    (aggregate
     (((mean_sharpe 0.62249200082635292) (mean_calmar 1.4788762829309587)
       (mean_return_pct 16.43815457935484)
       (mean_max_drawdown_pct 12.418689036712658)))))
   ((label "early_admission_ma_period=(5)")
    (config_hash fa0399d286202e0a26bd136ac7bdb5d2)
    (aggregate
     (((mean_sharpe 0.66285018616814562) (mean_calmar 1.4763146507641411)
       (mean_return_pct 17.183002639354847)
       (mean_max_drawdown_pct 12.186576703027486)))))
   ((label "early_admission_ma_period=(7)")
    (config_hash 999c7a7617ec67419c92d3acff050401)
    (aggregate
     (((mean_sharpe 0.63721950921025372) (mean_calmar 1.4285842908709654)
       (mean_return_pct 9.2384341438709612)
       (mean_max_drawdown_pct 10.050349407137146)))))
   ((label "early_admission_ma_period=(10)")
    (config_hash 83a8ee738336e814faae4128e416011a)
    (aggregate
     (((mean_sharpe 0.81581234469167185) (mean_calmar 1.7434937356463158)
       (mean_return_pct 12.161920608663586)
       (mean_max_drawdown_pct 10.116764996483706)))))
   ((label "early_admission_ma_period=(13)")
    (config_hash d3cff9e3bca8e28facf68d0f061047ab)
    (aggregate
     (((mean_sharpe 0.81478309745270527) (mean_calmar 1.7070548905779999)
       (mean_return_pct 11.401159214516129)
       (mean_max_drawdown_pct 10.446022339945271)))))))
 (verdict Accept)
 (notes
  "See dev/notes/early-admission-surface-v2-2026-05-30.md. ACCEPT the mechanism direction. Re-run of the 2026-05-30 INCONCLUSIVE surface on the GSPC-repaired golden (issue #1380 fix: index now 2009-2026, 0 zero-folds, baseline reconciles with canonical exit-timing 0.62/12.4 vs 0.54/12.28). FINDING 1 (the ACCEPT): early admission net-helps - baseline is Pareto-DOMINATED on BOTH 2010-2026 (31 folds) and the independent 2019-2023 (9 folds, different universe snapshot, unaffected by the floor). First program mechanism to beat baseline out-of-window; edge is risk-reduction (lower MaxDD, several losing folds turned positive). FINDING 2 (why promotion is held): the 15y DSR-1.0 winner ma=10 (Sharpe 0.816) does NOT generalise - it collapses to ~baseline on 5y (0.463 vs 0.435). Best period is regime-dependent: ma=10 wins 15y, ma=13 wins 5y; ma=7 is the only both-window-frontier cell (marginal 15y edge); ma=13 is best cross-window aggregate (15y 0.815, 5y 0.615); ma=5 weak on both. DO NOT auto-promote ma=10. Robust value = ma=13 (or conservative ma=7). Global-default flip (None->Some 13) re-baselines all goldens + changes live behaviour - HELD for review + ideally a broader-universe confirmation to pin the period. Mechanism stays default-off until then."))
