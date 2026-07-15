((date 2026-07-16) (slug resistance-supply-weight-surface)
 (hypothesis
  "resistance-v2 PR-E: pricing overhead supply continuously (w_overhead_supply replacing the binary virgin/clean resistance points with round(w*(1-supply_score))) recovers the value the false-virgin lottery appeared to provide; weight 0 = signal deleted; negative weight = prefer-overhead (the direction the 07-14 crash-recovery monsters implied); baseline = today's binary path")
 (base_scenario
  "staging-record-convention/top3000-2000-2026-record-convention (dedup-v3 sketch warehouse, deep-feed armed, PIT top-3000)")
 (window_id wf-2000-2026-730-730-13fold-top3000-snapshot-dedup-v3-sketch)
 (baseline_label baseline)
 (variants
  (((label baseline) (config_hash "")
    (aggregate
     (((mean_sharpe 0.691) (mean_calmar 0.921) (mean_return_pct 31.74)
       (mean_max_drawdown_pct 16.57)))))
   ((label w_overhead_supply=-15) (config_hash "")
    (aggregate
     (((mean_sharpe 0.685) (mean_calmar 0.866) (mean_return_pct 25.11)
       (mean_max_drawdown_pct 17.94)))))
   ((label w_overhead_supply=0) (config_hash "")
    (aggregate
     (((mean_sharpe 0.691) (mean_calmar 0.993) (mean_return_pct 27.91)
       (mean_max_drawdown_pct 15.49)))))
   ((label w_overhead_supply=15) (config_hash "")
    (aggregate
     (((mean_sharpe 0.787) (mean_calmar 1.151) (mean_return_pct 28.69)
       (mean_max_drawdown_pct 14.11)))))
   ((label w_overhead_supply=30) (config_hash "")
    (aggregate
     (((mean_sharpe 0.860) (mean_calmar 1.218) (mean_return_pct 33.22)
       (mean_max_drawdown_pct 14.04)))))))
 (verdict Inconclusive)
 (notes
  "Monotone improvement with positive weight: Sharpe .691->.787->.860, Calmar .921->1.151->1.218, MaxDD 16.6->14.1->14.0, and w=30 beats baseline on RETURN too (33.2 vs 31.7) -- honest supply-pricing is NOT a tail tax on fold-mean basis. Sharpe wins vs baseline: w30 9/13, w15 7/13 (MaxDD wins 10/13 and 12/13); w=-15 (prefer overhead) worse everywhere -> the structure-direction REFUTED; w=0 (signal deleted) ~neutral. Gate FAIL for all variants but solely on worst_delta=0 (single-fold-never-worse); the m-of-n substance passes for w30 (9/13 >= 7). Paired per-fold Sharpe diff w30-baseline: mean +0.169, sd 0.402, t~1.5 (n=13) -- NOT significant pre-deflation, and best-of-4 selection deflates further, so no promotion. Winner sits on the surface BOUNDARY (w=30 max tested). ANSWER TO THE NAMED QUESTION: the false virgins were LUCK (path-sizing lottery, consistent with the Run-E-capped decomposition), not structure -- fold-honest pricing of honest supply data helps, it does not hurt; the 07-14 armed single-path -55% was compounding-path artifact. FOLLOW-UP AXIS: extend {45,60} + min_history_bars/insufficient_score axes; mechanism stays default-off per R3. Sweep: /tmp/sweeps/resist-supply-w-v1 (65 fold-runs, exit 0, ~15h wall, ~14min/fold at parallel 1). Spec: test_data/walk_forward/resistance-supply-weight-BROAD-2000-2026.sexp.")
)
