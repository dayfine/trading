((date 2026-05-31) (slug exit-timing-hysteresis-revalidated)
 (hypothesis
  "Re-validation on REPAIRED data: do the stage3 exit-timing REJECTs (2026-05-30-exit-timing-surface) and the hysteresis REJECT (2026-05-29-stage3-hysteresis-wf-cv) still hold once the GSPC.INDX golden spans the full 2010-2026 window (issue #1380 / PR #1383)? Both prior verdicts were measured while the index golden floored at 2017, so folds 000-012 (2010-2016) were silently zero-trade (macro gate blocked buys with no index). This run re-tests the identical 9-cell surface (hysteresis_weeks {1,2,3} x stage3_exit_margin_pct {0.0,0.02,0.05}) + baseline on the repaired golden, so all 31 folds trade.")
 (base_scenario goldens-sp500-historical/sp500-2010-2026.sexp)
 (window_id rolling-2010-2026-365-182-31fold-gspc-repaired)
 (baseline_label baseline)
 (variants
  (((label baseline) (config_hash 236ef895264d979eefd83a50eb55663c)
    (aggregate
     (((mean_sharpe 0.6225) (mean_calmar 1.4789) (mean_return_pct 16.438)
       (mean_max_drawdown_pct 12.419)))))
   ((label hysteresis_weeks=1__stage3_exit_margin_pct=0.0)
    (config_hash e5d11c7d3f4686bb9dcefa10dd226fc3)
    (aggregate
     (((mean_sharpe 0.6225) (mean_calmar 1.4789) (mean_return_pct 16.438)
       (mean_max_drawdown_pct 12.419)))))
   ((label hysteresis_weeks=1__stage3_exit_margin_pct=0.02)
    (config_hash 9efacce4e4bdcb75f9e93e5713942413)
    (aggregate
     (((mean_sharpe 0.6225) (mean_calmar 1.4789) (mean_return_pct 16.438)
       (mean_max_drawdown_pct 12.419)))))
   ((label hysteresis_weeks=1__stage3_exit_margin_pct=0.05)
    (config_hash 974aa1358a2b6a9df33f380e663e9043)
    (aggregate
     (((mean_sharpe 0.6206) (mean_calmar 1.4764) (mean_return_pct 16.414)
       (mean_max_drawdown_pct 12.436)))))
   ((label hysteresis_weeks=2__stage3_exit_margin_pct=0.0)
    (config_hash 236ef895264d979eefd83a50eb55663c)
    (aggregate
     (((mean_sharpe 0.6208) (mean_calmar 1.4766) (mean_return_pct 16.416)
       (mean_max_drawdown_pct 12.436)))))
   ((label hysteresis_weeks=2__stage3_exit_margin_pct=0.02)
    (config_hash 9dfc464ebc778f889f6f1c3dbe82921f)
    (aggregate
     (((mean_sharpe 0.6208) (mean_calmar 1.4766) (mean_return_pct 16.416)
       (mean_max_drawdown_pct 12.436)))))
   ((label hysteresis_weeks=2__stage3_exit_margin_pct=0.05)
    (config_hash 963d1ac2ff02965d31730e904404e096)
    (aggregate
     (((mean_sharpe 0.6206) (mean_calmar 1.4764) (mean_return_pct 16.414)
       (mean_max_drawdown_pct 12.436)))))
   ((label hysteresis_weeks=3__stage3_exit_margin_pct=0.0)
    (config_hash fc4f8b391db2e9a6a024454c0160d3fb)
    (aggregate
     (((mean_sharpe 0.6208) (mean_calmar 1.4766) (mean_return_pct 16.416)
       (mean_max_drawdown_pct 12.436)))))
   ((label hysteresis_weeks=3__stage3_exit_margin_pct=0.02)
    (config_hash 9475137a07da81e42c54889f7fa65b84)
    (aggregate
     (((mean_sharpe 0.6208) (mean_calmar 1.4766) (mean_return_pct 16.416)
       (mean_max_drawdown_pct 12.436)))))
   ((label hysteresis_weeks=3__stage3_exit_margin_pct=0.05)
    (config_hash 37f7e74a8caad02057cc2c6356f8c197)
    (aggregate
     (((mean_sharpe 0.6206) (mean_calmar 1.4764) (mean_return_pct 16.414)
       (mean_max_drawdown_pct 12.436)))))))
 (verdict Reject)
 (notes
  "REJECT confirmed and STRENGTHENED on repaired data. With the GSPC golden now spanning 2009-2026, all 31 folds trade (fold-000..004 avg_holding_days 39/41/28/28/.. , non-zero returns; previously zero-trade). Baseline Sharpe rose 0.540 (truncated 2017-2026 window) -> 0.6225 (full 2010-2026) as the early folds now contribute real OOS performance. On the full window every exit-timing cell that changes behaviour is strictly worse than baseline: the best non-trivial cell (h2/h3, m=0.0/0.02) is Sharpe 0.6208 < baseline 0.6225; the worst (m=0.05) 0.6206. Only the no-op-equivalent cells (h1 m=0.0/0.02) sit on the Pareto frontier with baseline; every behaviour-changing cell is dominated. Stage3 hysteresis + exit-margin are pure drag, now confirmed on un-truncated data. This re-validation removes the GSPC-floor asterisk from BOTH dev/experiments/_ledger/2026-05-30-exit-timing-surface.sexp (the 9-cell surface, superset) and dev/experiments/_ledger/2026-05-29-stage3-hysteresis-wf-cv.sexp (the h2-m02 point, config_hash 9dfc464ebc778f889f6f1c3dbe82921f, a cell in this surface). Writeup: dev/notes/exit-timing-hysteresis-revalidated-2026-05-31.md. Run: /tmp/sweeps/exit-revalidate (31 folds, parallel=4)."))
