((date 2026-05-30) (slug exit-timing-surface)
 (hypothesis
  "Does ANY cell of the exit-timing knob surface (hysteresis_weeks {1,2,3} x stage3_exit_margin_pct {0.0,0.02,0.05}) beat baseline across the 31-fold 2010-2026 distribution, recovering the autopsy's exit-timing missed gain?")
 (base_scenario goldens-sp500-historical/sp500-2010-2026.sexp)
 (window_id rolling-2010-2026-365-182-31fold) (baseline_label baseline)
 (variants
  (((label baseline) (config_hash 236ef895264d979eefd83a50eb55663c)
    (aggregate
     (((mean_sharpe 0.54) (mean_calmar 1.249) (mean_return_pct 8.17)
       (mean_max_drawdown_pct 12.28)))))
   ((label hysteresis_weeks=1__stage3_exit_margin_pct=0.0)
    (config_hash e5d11c7d3f4686bb9dcefa10dd226fc3)
    (aggregate
     (((mean_sharpe 0.54) (mean_calmar 1.249) (mean_return_pct 8.17)
       (mean_max_drawdown_pct 12.28)))))
   ((label hysteresis_weeks=1__stage3_exit_margin_pct=0.02)
    (config_hash 9efacce4e4bdcb75f9e93e5713942413)
    (aggregate
     (((mean_sharpe 0.532) (mean_calmar 1.193) (mean_return_pct 8.04)
       (mean_max_drawdown_pct 12.29)))))
   ((label hysteresis_weeks=1__stage3_exit_margin_pct=0.05)
    (config_hash 974aa1358a2b6a9df33f380e663e9043)
    (aggregate
     (((mean_sharpe 0.519) (mean_calmar 1.186) (mean_return_pct 7.89)
       (mean_max_drawdown_pct 12.34)))))
   ((label hysteresis_weeks=2__stage3_exit_margin_pct=0.0)
    (config_hash 236ef895264d979eefd83a50eb55663c)
    (aggregate
     (((mean_sharpe 0.519) (mean_calmar 1.185) (mean_return_pct 7.89)
       (mean_max_drawdown_pct 12.33)))))
   ((label hysteresis_weeks=2__stage3_exit_margin_pct=0.02)
    (config_hash 9dfc464ebc778f889f6f1c3dbe82921f)
    (aggregate
     (((mean_sharpe 0.519) (mean_calmar 1.185) (mean_return_pct 7.88)
       (mean_max_drawdown_pct 12.34)))))
   ((label hysteresis_weeks=2__stage3_exit_margin_pct=0.05)
    (config_hash 963d1ac2ff02965d31730e904404e096)
    (aggregate
     (((mean_sharpe 0.519) (mean_calmar 1.185) (mean_return_pct 7.88)
       (mean_max_drawdown_pct 12.34)))))
   ((label hysteresis_weeks=3__stage3_exit_margin_pct=0.0)
    (config_hash fc4f8b391db2e9a6a024454c0160d3fb)
    (aggregate
     (((mean_sharpe 0.519) (mean_calmar 1.185) (mean_return_pct 7.87)
       (mean_max_drawdown_pct 12.33)))))
   ((label hysteresis_weeks=3__stage3_exit_margin_pct=0.02)
    (config_hash 9475137a07da81e42c54889f7fa65b84)
    (aggregate
     (((mean_sharpe 0.519) (mean_calmar 1.185) (mean_return_pct 7.87)
       (mean_max_drawdown_pct 12.33)))))
   ((label hysteresis_weeks=3__stage3_exit_margin_pct=0.05)
    (config_hash 37f7e74a8caad02057cc2c6356f8c197)
    (aggregate
     (((mean_sharpe 0.518) (mean_calmar 1.184) (mean_return_pct 7.87)
       (mean_max_drawdown_pct 12.33)))))))
 (verdict Reject)
 (notes
  "See dev/notes/exit-timing-surface-2026-05-30.md. Whole surface rejected: every cell <= baseline on mean Sharpe/Calmar/return, monotonically degrading with more hysteresis / more margin (gradient points back to baseline). Best cell wins 4/31 folds on Sharpe (gate needs 16); no cell raw-beats baseline so no DSR candidate. Exit-timing missed gain is NOT recoverable by these knobs. h2-m0.02 reproduces the prior single-point rejection (#1366)."))
