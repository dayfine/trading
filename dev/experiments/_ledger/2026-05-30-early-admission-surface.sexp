((date 2026-05-30) (slug early-admission-surface)
 (hypothesis
  "Does early Stage-2 admission on a fast MA (stage_config.early_admission_ma_period in {5,7,10,13}) recover the autopsy's late_stage2_admission missed gain across the 2010-2026 fold distribution?")
 (base_scenario goldens-sp500-historical/sp500-2010-2026.sexp)
 (window_id rolling-2010-2026-365-182-31fold) (baseline_label baseline)
 (variants
  (((label baseline) (config_hash afb39cb5f979233bdfc57fbeface8c72)
    (aggregate
     (((mean_sharpe 0.25087196678875079) (mean_calmar 0.82905609504720779)
       (mean_return_pct 12.000353608064513)
       (mean_max_drawdown_pct 8.952500176820207)))))
   ((label "early_admission_ma_period=(5)")
    (config_hash fa0399d286202e0a26bd136ac7bdb5d2)
    (aggregate
     (((mean_sharpe 0.33973853175524626) (mean_calmar 1.0412548644908342)
       (mean_return_pct 13.398472838709679)
       (mean_max_drawdown_pct 8.9101194780737263)))))
   ((label "early_admission_ma_period=(7)")
    (config_hash 999c7a7617ec67419c92d3acff050401)
    (aggregate
     (((mean_sharpe 0.33408703469855172) (mean_calmar 0.78813189030224118)
       (mean_return_pct 5.3610074932258049)
       (mean_max_drawdown_pct 6.8248638169250349)))))
   ((label "early_admission_ma_period=(10)")
    (config_hash 83a8ee738336e814faae4128e416011a)
    (aggregate
     (((mean_sharpe 0.41426595354120327) (mean_calmar 0.9107590472516508)
       (mean_return_pct 7.2383037922580575)
       (mean_max_drawdown_pct 6.7881665129133673)))))
   ((label "early_admission_ma_period=(13)")
    (config_hash d3cff9e3bca8e28facf68d0f061047ab)
    (aggregate
     (((mean_sharpe 0.40520294054525091) (mean_calmar 1.0220770916237485)
       (mean_return_pct 6.2110119541935465)
       (mean_max_drawdown_pct 6.7702391769945462)))))))
 (verdict Inconclusive)
 (notes
  "See dev/notes/early-admission-surface-2026-05-30.md. INCONCLUSIVE, not a verdict on the mechanism: the sp500-2010-2026 scenario's index golden (GSPC.INDX) covers only 2017-01-03..2026-04-09 and NYSE A/D breadth only 2017-2020, so the Weinstein macro gate blocked all buys in 2010-2016 -> folds 000-012 are zero-trade for EVERY variant (baseline + all 4 cells). The surface was therefore evaluated on ~18 real folds (2017-2026), not the nominal 31-fold 2010-2026 distribution; the gate's n=31 counts 13 forced ties against every cell (best cell ma=10 wins 15/31 -> ~15/18 contested, 'fails' the 16/31 gate purely on dilution). Within the 2017-2026 sub-period the mechanism shows a CONSISTENT improvement (all 4 cells beat baseline on mean Sharpe; baseline off the Pareto frontier; best cell ma=10 Sharpe 0.414 vs baseline 0.251, MaxDD 6.79 vs 8.95, DSR 0.9987 best-of-4) incl. the 2020 COVID bottom (a target regime of autopsy mode late_stage2_admission). But the run cannot be promoted: it did not test 2010-2016, and its baseline does not reconcile with the canonical exit-timing baseline (0.54). This GSPC-2017 floor compromises ALL experiments on sp500-2010-2026 (exit-timing, hysteresis included). Next: extend the index/breadth goldens to 2010 and re-run the surface on the true distribution before any verdict. Mechanism stays default-off (PR #1378)."))
