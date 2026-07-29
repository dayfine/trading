((date 2026-07-29) (slug split-basis-sp500-cell)
 (hypothesis
  "Universe-diversity cell completing the #2133 split-basis blast-radius grid (path-level 2026-07-28 + fold-level 2026-07-29 were broad top-3000): same two-arm design on the sp500 universe -- goldens-sp500-historical/sp500-2000-2026-catstop (promoted-bundle defaults) on the raw sp500 v5thin warehouse vs its split-safe clone, one pinned binary.")
 (base_scenario
  "goldens-sp500-historical/sp500-2000-2026-catstop on /tmp/snap_sp500_2000_2026_v5thin{,_adj} (promoted-bundle defaults, pinned worktree @ 9f50de924, run 2026-07-29 06:11-07:3xZ)")
 (window_id contiguous-sp500-2000-2026)
 (baseline_label raw-control)
 (variants
  (((label raw-control) (config_hash "")
    (aggregate
     (((mean_sharpe 0.0) (mean_calmar 0.0) (mean_return_pct 1476.6)
       (mean_max_drawdown_pct 30.5)))))
   ((label adjusted-split-safe) (config_hash "")
    (aggregate
     (((mean_sharpe 0.0) (mean_calmar 0.0) (mean_return_pct 1289.9)
       (mean_max_drawdown_pct 28.8)))))))
 (verdict Inconclusive)
 (notes
  "MEASUREMENT entry (grid cell; verdict n/a). Raw control +1476.6% / MaxDD 30.5 / 1183 trades / win 40.7; split-safe honest +1289.9% / MaxDD 28.8 / 1102 trades / win 38.3. sp500 blast radius: -186.7pp return (-12.6% rel), -81 trades, -2.4pp win rate, and MaxDD IMPROVES 1.7pp -- the OPPOSITE DD direction from the broad cell (+6.8pp worse honest). Reading: the DD flattering is NOT universal; it is a broad-universe marginal-cohort composition effect (split-blind grades admitted a luckier junk-adjacent marginal cohort on top-3000), while on the quality-tilted sp500 universe split-blind grading mostly OVER-admitted (81 extra trades, higher win rate but with clustered drawdown) and honest grading is slightly SAFER. Return flattering is proportionally larger on sp500 (-12.6% rel vs -3.7% rel broad) -- sp500 has proportionally more long-history dividend payers whose adjusted basis diverges from raw. Grid now complete for the R3 record re-pin decision: broad path (+8367/37.1 vs +8689/30.3), broad folds (.765 vs .827), sp500 path (+1290/28.8 vs +1477/30.5). Consistent conclusion: honest grading costs some return everywhere; risk direction is universe-dependent. Artifacts /tmp/sweeps/basis-blast/sp500/{raw,adj}/ + logs; runs from the same pinned worktree as the broad arms."))
