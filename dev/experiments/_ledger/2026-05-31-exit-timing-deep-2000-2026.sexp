((date 2026-05-31) (slug exit-timing-deep-2000-2026)
 (hypothesis
  "Multi-regime confirmation: does the stage3 exit-timing surface (hysteresis_weeks {1,2,3} x stage3_exit_margin_pct {0.0,0.02,0.05}) still lose to baseline across the FULL 2000-2026 cycle (dot-com bust + GFC), on the point-in-time-2000 SP500 universe incl. delistings? The 2026-05-31 re-validation confirmed the REJECT on 2010-2026 (post-GFC bull); this extends it to a genuinely multi-regime window per .claude/rules/promotion-confirmation.md.")
 (base_scenario goldens-sp500-historical/sp500-2000-2026.sexp)
 (window_id rolling-2000-2026-365-182-51fold-deep-ptinpoint2000)
 (baseline_label baseline)
 (variants
  (((label baseline) (config_hash 236ef895264d979eefd83a50eb55663c)
    (aggregate
     (((mean_sharpe 0.6806) (mean_calmar 2.0376) (mean_return_pct 16.726)
       (mean_max_drawdown_pct 11.141)))))
   ((label hysteresis_weeks=1__stage3_exit_margin_pct=0.0)
    (config_hash e5d11c7d3f4686bb9dcefa10dd226fc3)
    (aggregate
     (((mean_sharpe 0.6806) (mean_calmar 2.0376) (mean_return_pct 16.726)
       (mean_max_drawdown_pct 11.141)))))
   ((label hysteresis_weeks=1__stage3_exit_margin_pct=0.02)
    (config_hash 9efacce4e4bdcb75f9e93e5713942413)
    (aggregate
     (((mean_sharpe 0.6798) (mean_calmar 2.0367) (mean_return_pct 16.710)
       (mean_max_drawdown_pct 11.146)))))
   ((label hysteresis_weeks=1__stage3_exit_margin_pct=0.05)
    (config_hash 974aa1358a2b6a9df33f380e663e9043)
    (aggregate
     (((mean_sharpe 0.6723) (mean_calmar 2.0322) (mean_return_pct 16.607)
       (mean_max_drawdown_pct 11.151)))))
   ((label hysteresis_weeks=2__stage3_exit_margin_pct=0.0)
    (config_hash 236ef895264d979eefd83a50eb55663c)
    (aggregate
     (((mean_sharpe 0.6663) (mean_calmar 2.0194) (mean_return_pct 16.484)
       (mean_max_drawdown_pct 11.152)))))
   ((label hysteresis_weeks=2__stage3_exit_margin_pct=0.02)
    (config_hash 9dfc464ebc778f889f6f1c3dbe82921f)
    (aggregate
     (((mean_sharpe 0.6662) (mean_calmar 2.0194) (mean_return_pct 16.482)
       (mean_max_drawdown_pct 11.154)))))
   ((label hysteresis_weeks=2__stage3_exit_margin_pct=0.05)
    (config_hash 963d1ac2ff02965d31730e904404e096)
    (aggregate
     (((mean_sharpe 0.6662) (mean_calmar 2.0194) (mean_return_pct 16.482)
       (mean_max_drawdown_pct 11.154)))))
   ((label hysteresis_weeks=3__stage3_exit_margin_pct=0.0)
    (config_hash fc4f8b391db2e9a6a024454c0160d3fb)
    (aggregate
     (((mean_sharpe 0.6649) (mean_calmar 2.0152) (mean_return_pct 16.449)
       (mean_max_drawdown_pct 11.155)))))
   ((label hysteresis_weeks=3__stage3_exit_margin_pct=0.02)
    (config_hash 9475137a07da81e42c54889f7fa65b84)
    (aggregate
     (((mean_sharpe 0.6649) (mean_calmar 2.0152) (mean_return_pct 16.449)
       (mean_max_drawdown_pct 11.155)))))
   ((label hysteresis_weeks=3__stage3_exit_margin_pct=0.05)
    (config_hash 37f7e74a8caad02057cc2c6356f8c197)
    (aggregate
     (((mean_sharpe 0.6649) (mean_calmar 2.0152) (mean_return_pct 16.449)
       (mean_max_drawdown_pct 11.155)))))))
 (verdict Reject)
 (notes
  "REJECT confirmed MULTI-REGIME and strengthened. On the full 2000-2026 cycle (dot-com bust + GFC, point-in-time-2000 universe incl. delistings LEH/BS/YHOO, 51 folds; early folds 2000-2002 traded, avg_holding_days 32.5/43.9/17.8) baseline (Sharpe 0.6806, Calmar 2.038, MaxDD 11.14) is the ONLY Pareto-frontier cell. Every behaviour-changing cell is strictly dominated and the drag is LARGER than on the 2010-2026 bull window: h2/h3 collapse to Sharpe 0.665-0.666 (~2.3% loss vs baseline) where 2010-2026 lost only ~0.3%; the margin knob (h1 m=0.05) drops 0.6806->0.6723. Monotone worse with more hysteresis and more margin. This matches the mechanism: stage3 false-exit costs are larger in bear regimes (2000-02, 2008), so deferring the exit (hysteresis) or widening the margin hurts most exactly when the slow 30-week MA is most protective. Config hashes are the shared axis-override hashes from the 2010-2026 surface (same cells). Baseline Sharpe 0.6806 reconciles with the early-admission deep baseline 0.68063 (same deep dataset). Confirms 2026-05-31-exit-timing-hysteresis-revalidated (2010-2026) + 2026-05-30-exit-timing-surface + 2026-05-29-stage3-hysteresis-wf-cv. Run: /tmp/sweeps/exit-deep (51 folds, parallel=4). Spec: trading/test_data/walk_forward/exit-timing-surface-deep-2000-2026.sexp."))
