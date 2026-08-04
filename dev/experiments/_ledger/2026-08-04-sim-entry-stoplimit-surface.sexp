((date 2026-08-04) (slug sim-entry-stoplimit-surface)
 (hypothesis
  "Does the honest do-not-chase StopLimit entry fill model (#2158 Phase 2, PR #2202, default-off enable_sim_entry_stoplimit + entry_extension_max_pct cap) change fold-level risk-adjusted outcomes vs the historical Market fill model, at caps {10,15,20}pp bracketing the Phase-1 armed live value?")
 (base_scenario
  "goldens-sp500-historical/sp500-2010-2026.sexp, 31 rolling OOS folds 2010-2026 test=365d step=182d, CSV panel 525 syms, pinned worktree @ba3ec93c")
 (window_id rolling-sp500-2010-2026-31fold-365x182) (baseline_label market)
 (variants
  (((label market) (config_hash e79b8f802399c30e3e163a07d142aeea)
    (aggregate
     (((mean_sharpe 0.78886802244567233) (mean_calmar 1.5642577403497451)
       (mean_return_pct 28.702745940967752)
       (mean_max_drawdown_pct 13.431420593821331)))))
   ((label cap10) (config_hash a6c26f57ed1f7a0e10f58cd8fadf642c)
    (aggregate
     (((mean_sharpe 0.52450196936161086) (mean_calmar 1.1469152149346862)
       (mean_return_pct 24.788063110292828)
       (mean_max_drawdown_pct 14.569081648660182)))))
   ((label cap15) (config_hash 667e5c5ad0cf637acb82d2a9ba155696)
    (aggregate
     (((mean_sharpe 0.52217254060101537) (mean_calmar 1.114532986275393)
       (mean_return_pct 24.811950950879606)
       (mean_max_drawdown_pct 14.57926180611604)))))
   ((label cap20) (config_hash 0d5d1865ebee71290f56e4edc81e3707)
    (aggregate
     (((mean_sharpe 0.49581151036453935) (mean_calmar 1.1170069482516873)
       (mean_return_pct 24.147120911287423)
       (mean_max_drawdown_pct 14.549861539222986)))))))
 (verdict Reject)
 (notes
  "REJECT for arming (no default flip); mechanism KEEPS default-off axis status. Gate FAIL decisively for all three caps: Sharpe wins 2/31 (cap10), 2/31 (cap15), 1/31 (cap20) vs m=16 required; worst-fold gaps 0.62-0.68 >> 0.20; Pareto frontier = baseline alone; mean Sharpe 0.789 (market) vs 0.525/0.522/0.496; mean return 28.7% vs ~24.8%; MaxDD WORSE with caps (13.4% vs ~14.6%). THE TRANSFERABLE WHY: (1) ENTRY-SIDE FAT-TAIL TAX (11th edge_is_the_fat_tail confirmation, first on the ENTRY-fill side): the do-not-chase cap refuses fills precisely on gap-and-go launches, which are disproportionately the right-tail seeds; the refused chases the cap was meant to protect against never show up as DD relief (DD is flat-to-worse), so the trade is pure lost return. (2) CAP-INSENSITIVITY {10,15,20}pp nearly identical => the harm concentrates in gaps beyond 20pp (the monster launches refused by ALL variants), not in fill-price nuance between E and cap. (3) LIVE/SIM PARITY FLAG (the surfaces most valuable output): live order-gen ALREADY ships StopLimit(E,cap) tickets (Phase 1 #2171, armed 15pp) while every record backtest assumes Market fills -- this surface measures that divergence at approx -0.26 mean fold Sharpe / -3.9pp mean fold return on sp500 2010-26. The live do-not-chase cap plausibly costs live expectancy vs the published backtest basis; USER DECISION ITEM for the live arming (execution-honesty vs expectancy tradeoff -- the book-faithful missing-over-chasing rule is empirically expensive). FORWARD GUIDANCE: mechanism stays a default-off REALISM axis (live-parity studies), not an alpha lever; no further entry-timing/entry-price-condition levers without beating both the powered entry-selection null AND this result. Artifacts: dev/experiments/stoplimit-entry-wfcv-2026-08-04/ (report, aggregate, fold_actuals, rank). Spec: trading/test_data/walk_forward/sim_entry_stoplimit_31fold_2026_08_04.sexp (committed, parse+gate-n test-pinned)."))
