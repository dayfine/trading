((date 2026-06-10) (slug cascade-w-early-stage2-reweight-top3000)
 (hypothesis
  "Trade-forensics found the cascade score anti-predictive at the top grade: confirmed Stage1->2 breakouts (scored +30) under-perform early-Stage2 entries (scored +15 = w_stage2_breakout/2) on win-rate across breadths (dev/notes/cascade-selection-inversion-2026-06-10.md). Raising the decoupled w_early_stage2 weight (PR #1512/#1513) toward/past the breakout's 30 should let the higher-win-rate early entries out-rank breakouts and improve risk-adjusted return. In-sample (top-1000 full) w_early_stage2=30 gave Sharpe 0.36 vs baseline 0.19. Does it generalise under top-3000 WF-CV?")
 (base_scenario "goldens-custom-universe/composition/top-3000-2011 (PIT)")
 (window_id wf-2011-2026-365-365-15fold-top3000-forkperfold)
 (baseline_label baseline)
 (variants
  (((label baseline) (config_hash "w_early_stage2=None(=15)")
    (aggregate
     (((mean_sharpe 0.64281770518313874) (mean_calmar 1.3816425612264558)
       (mean_return_pct 12.950175847379974)
       (mean_max_drawdown_pct 14.790393995098752) (deflated_sharpe 0.9883)
       (sharpe_wins 15) (frontier yes)))))
   ((label w22) (config_hash "w_early_stage2=22")
    (aggregate
     (((mean_sharpe 0.39502999574280473) (mean_calmar 0.63919818494557179)
       (mean_return_pct 12.084771893523826)
       (mean_max_drawdown_pct 16.950362128521864) (deflated_sharpe 0.8393)
       (sharpe_wins 4) (frontier no)))))
   ((label w30) (config_hash "w_early_stage2=30")
    (aggregate
     (((mean_sharpe 0.14175762358725827) (mean_calmar 0.37932248792484308)
       (mean_return_pct 6.2079273233333367)
       (mean_max_drawdown_pct 17.822105632830525) (deflated_sharpe 0.4226)
       (sharpe_wins 5) (frontier no)))))
   ((label w38) (config_hash "w_early_stage2=38")
    (aggregate
     (((mean_sharpe 0.28872707768201239) (mean_calmar 0.783849968219647)
       (mean_return_pct 5.32822121066667)
       (mean_max_drawdown_pct 16.021114472497374) (deflated_sharpe 0.6497)
       (sharpe_wins 5) (frontier no)))))))
 (verdict Reject)
 (notes
  "REJECT. Decoupling + raising w_early_stage2 (up-weighting early-Stage2 entries relative to confirmed Stage1->2 breakouts) FAILS to generalise on top-3000 WF-CV. Baseline (None = the historical 2:1 breakout/early ratio) is the SOLE Pareto-frontier cell and has the highest Deflated Sharpe (0.9883); every reweight is dominated on Sharpe AND Calmar AND MaxDD (all three worse), with monotone degradation as the early weight rises (w30 worst: Sharpe 0.142 vs 0.643, DSR 0.4226). Per-fold gate: w22 4/15, w30 5/15, w38 5/15 wins (need 8) -> all FAIL. The strong in-sample top-1000 win (Sharpe 0.36 vs 0.19) was single-window overfit, the exact pattern the WF-CV exists to catch. Mechanistically it coheres with the liquidity finding (dev/notes/trade-realism-liquidity-findings-2026-06-10.md): the fat-tail winners (CALX/DEG/...) are confirmed breakouts in liquid names; up-weighting early entries de-prioritises the very monsters that earn the return. The cascade-inversion is a REAL win-rate observation but is NOT actionable via reweight -- the breakout premium is EARNING the tail, not a scoring error. w_early_stage2 stays default-off (None); the axis remains available but is not promotable. Confirms 'selection >> timing' does not imply this particular selection tweak helps. Surface: /tmp/sweeps/cascade-rw-wfcv; spec dev/experiments/cascade-reweight-wfcv-2026-06-10/."))
