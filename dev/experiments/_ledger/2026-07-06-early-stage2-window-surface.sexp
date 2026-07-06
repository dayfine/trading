((date 2026-07-06) (slug early-stage2-window-surface)
 (hypothesis
  "P2 (deferred from #1818, mechanism #1862): the hardcoded weeks_advancing<=4 early-Stage2 admission window is untested vs the 8-week breakout-event lookback. Widening (6,8) admits more not-yet-extended Stage-2 names = candidate tail-preserving entry-breadth lever; tightening (2) tests whether only the freshest breakouts carry the edge. Surface early_stage2_max_weeks {2,4=baseline,6,8} on broad.")
 (base_scenario
  "BROAD-ONLY surface (top-3000 PIT-2000, decisive cell for entry-admission levers), 2000-2026, 13x2y non-overlapping folds, production caps + catstop 0.10, Cell-E long-only + stage3/laggard, snapshot warehouse fork-per-fold.")
 (window_id surface-broadonly-top3000-wfcv-2000-2026-13fold-2y)
 (baseline_label baseline)
 (variants
  (((label baseline) (config_hash "")
    (aggregate
     (((mean_sharpe 0.5968746113084944) (mean_calmar 0.68270632982270452)
       (mean_return_pct 19.918805991794873)
       (mean_max_drawdown_pct 15.357873569718073)))))
   ((label w2) (config_hash "")
    (aggregate
     (((mean_sharpe 0.56512977832134426) (mean_calmar 0.72620070004897608)
       (mean_return_pct 18.763953073815991)
       (mean_max_drawdown_pct 16.297307739639816)))))
   ((label w6) (config_hash "")
    (aggregate
     (((mean_sharpe 0.588420631117596) (mean_calmar 0.80139569110968278)
       (mean_return_pct 21.623479238027624)
       (mean_max_drawdown_pct 16.470812369595226)))))
   ((label w8) (config_hash "")
    (aggregate
     (((mean_sharpe 0.40498672678997516) (mean_calmar 0.5916283421073063)
       (mean_return_pct 15.949380914615395)
       (mean_max_drawdown_pct 17.793672814134371)))))))
 (verdict Reject)
 (notes
  "REJECT all alternatives; DEFAULT <=4 STAYS and is now empirically validated (rare positive: the probe confirmed the incumbent dial rather than merely rejecting variants). Gate FAIL every variant (Sharpe wins vs baseline: w2 5/13 worst-gap f000 0.515; w6 6/13 worst-gap f011 0.519; w8 5/13 worst-gap f012 1.021; all m<7 AND worst_delta>0.30). No DSR candidate exists: no variant exceeds baseline raw mean Sharpe (baseline 0.597 vs w2 0.565 / w6 0.588 / w8 0.405). THE TRANSFERABLE WHYs: (1) WIDENING = STALE-ENTRY ADMISSION, and the damage is regime-concentrated: bear/chop folds degrade monotonically with window width (f011 2022: baseline -0.42 -> w6 -0.94 -> w8 -1.36; f012 2024-25: baseline +0.11 -> w8 -0.91). Names 5-8 weeks into Stage 2 that the screener has not already bought are later, more-extended entries with worse stop structure exactly when the regime cracks. In bull folds they DO add return (w6 return mean 21.6 vs 19.9, Calmar wins 8/13) but the bear tax dominates the risk-adjusted aggregate and dispersion rises (w6 return sigma 27.2 vs 20.6). (2) ENTRY-BREADTH IS NOT UNIVERSE-BREADTH: edge_is_the_fat_tail favors breadth of FRESH opportunities (more symbols, more markets); widening the admission window manufactures breadth from STALER entries of the same opportunities = late-chasing, a tail-taxing lever wearing a breadth costume. Sharpen the lever-classification question from does-it-touch-winners to does-it-add-fresh-opportunities-or-stale-entries. (3) TIGHTENING STARVES: w2 shows weeks-3-4 admissions carry real edge (f000 dot-com: +5.4 -> -7.9; mean Sharpe 0.565, sigma 0.71 vs baseline 0.49) - freshest-only is not purer, it shrinks the funnel and raises dispersion. (4) The fresh-breakout discipline from the book is the empirical sweet spot on broad data - second confirmation that Weinstein dials are load-bearing (after volume-1.5x in the continuation-add surface). FORWARD: early_stage2_max_weeks stays 4; keep as searchable axis for coherent PRESET bundles only (trader/investor presets per weinstein-faithful-core) - do NOT re-sweep standalone. Ops: ~8h wall, 52 fold-runs, zero failures; one false start (TRADING_DATA_DIR must be passed via docker exec -e or universe_path resolves against the wrong data root). Artifacts: dev/experiments/early-stage2-window-2026-07-05/ (spec, out_top3000, run.log). Writeup: dev/notes/early-stage2-window-wfcv-2026-07-06.md."))
