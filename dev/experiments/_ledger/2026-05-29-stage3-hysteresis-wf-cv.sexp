((date 2026-05-29)
 (slug stage3-hysteresis-wf-cv)
 (hypothesis
  "autopsy-recommended stage3 hysteresis (hysteresis_weeks=2 + stage3_exit_margin_pct=0.02) recovers missed gain from false Stage 2->3 exits")
 (base_scenario "goldens-sp500-historical/sp500-2010-2026.sexp")
 (window_id rolling-2010-2026-365-182-31fold)
 (baseline_label h1-m0)
 (variants
  (((label h1-m0)
    (config_hash 236ef895264d979eefd83a50eb55663c)
    (aggregate
     (((mean_sharpe 0.540) (mean_calmar 1.249) (mean_return_pct 8.17)
       (mean_max_drawdown_pct 12.28)))))
   ((label h2-m02)
    (config_hash 9dfc464ebc778f889f6f1c3dbe82921f)
    (aggregate
     (((mean_sharpe 0.519) (mean_calmar 1.185) (mean_return_pct 7.88)
       (mean_max_drawdown_pct 12.34)))))))
 (verdict Reject)
 (notes
  "See dev/notes/stage3-hysteresis-walkforward-cv-2026-05-29.md. Variant won 4/31 folds on Sharpe, gate needed 16; net drag on every aggregate axis."))
