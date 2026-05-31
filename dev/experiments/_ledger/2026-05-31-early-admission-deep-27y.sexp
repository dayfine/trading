((date 2026-05-31) (slug early-admission-deep-27y)
 (hypothesis
  "Does early Stage-2 admission (early_admission_ma_period {7,10,13}) hold up across the FULL 2000-2026 cycle including the dot-com bust and GFC, on a point-in-time-2000 SP500 universe (incl. delisted names)?")
 (base_scenario goldens-sp500-historical/sp500-2000-2026.sexp)
 (window_id rolling-2000-2026-365-182-51fold-deep-ptinpoint2000)
 (baseline_label baseline)
 (variants
  (((label baseline) (config_hash afb39cb5f979233bdfc57fbeface8c72)
    (aggregate
     (((mean_sharpe 0.68062766368200966) (mean_calmar 2.0375866054325793)
       (mean_return_pct 16.725599357488246)
       (mean_max_drawdown_pct 11.141270283202362)))))
   ((label "early_admission_ma_period=(7)")
    (config_hash 999c7a7617ec67419c92d3acff050401)
    (aggregate
     (((mean_sharpe 0.5567657627678767) (mean_calmar 1.4609786661543596)
       (mean_return_pct 12.022357736369161)
       (mean_max_drawdown_pct 13.433249191112962)))))
   ((label "early_admission_ma_period=(10)")
    (config_hash 83a8ee738336e814faae4128e416011a)
    (aggregate
     (((mean_sharpe 0.6087675691369876) (mean_calmar 1.874431544584193)
       (mean_return_pct 14.960226566334837)
       (mean_max_drawdown_pct 12.971592202464754)))))
   ((label "early_admission_ma_period=(13)")
    (config_hash d3cff9e3bca8e28facf68d0f061047ab)
    (aggregate
     (((mean_sharpe 0.65418110510095773) (mean_calmar 1.9139170404055028)
       (mean_return_pct 15.750196755916958)
       (mean_max_drawdown_pct 11.273952221457431)))))))
 (verdict Reject)
 (notes
  "See dev/notes/early-admission-deep-2026-05-31.md. REVERSES the 2026-05-30 ACCEPT recommendation for promotion. The early-admission mechanism beat baseline across all post-2009 contexts (15y/5y/early SP500 + top-3000; ma=13 grid-robust per #1384) but on the FULL 2000-2026 cycle - point-in-time-2000 SP500 universe incl. delisted names (LEH/BS/YHOO), 51 folds spanning dot-com bust + GFC - baseline DOMINATES every early-admission variant and is the ONLY Pareto-frontier cell. baseline Sharpe 0.681 / return 16.7% vs ma=13 0.654 / 15.8% (ma=10 0.609, ma=7 0.557). ma=13 per-fold Sharpe win-rate collapses to 26/51 (~coin flip) vs ~60-77% post-2009. The mechanism's edge was a post-2009 bull-regime ARTIFACT; early admission gets whipsawed in the 2000-02 grind + 2008, where the slow 30-week MA is protective. DECISION: do NOT promote; mechanism stays default-off. The 27y deep test (enabled by the GSPC-floor fix + the deep-history data build) caught a regime-overfit that 4 post-2009 contexts + DSR 1.0 would have promoted - the value of testing the full cycle incl. tail regimes."))
