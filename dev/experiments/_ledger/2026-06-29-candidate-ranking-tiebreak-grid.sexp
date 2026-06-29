((date 2026-06-29) (slug candidate-ranking-tiebreak-grid)
 (hypothesis
  "candidate_ranking (PR #1786, default-off): replace the equal-score candidate tiebreak in the shared screener. Default=Alphabetical (String.compare ticker — an arbitrary determinism hack); variant=Quality (RS magnitude desc -> earliness/weeks_advancing asc -> volume ratio desc -> ticker). FRAMING: a faithfulness/realism fix (RS-for-selection is a Weinstein spine item), NOT a return-seeking lever -> success bar = DO-NO-HARM across breadth, not beat-baseline. Motivated by the 2026-06-28 live-weekly review which found the screener over-subscribed and selecting the alphabetically-first 20 of many tied grade-A breakouts (AIT 12/26 weeks etc.). Promotion-confirmation grid over the breadth axis (where over-subscription, and thus the tiebreak's impact, scales): top-500 / top-1000 / top-3000 PIT-1998, 2000-2026, 13 folds, fork-per-fold, Cell-E long-only.")
 (base_scenario "GRID 3-cell breadth x 2-variant (Alphabetical/Quality), 2000-2026, 2y non-overlapping folds (13), fork-per-fold, snapshot-warehouse mode. top-500 (327 syms w/ bars), top-1000 (514), top-3000 (1065). Cell-E long-only.")
 (window_id grid-3cell-breadth-wfcv-2000-2026-13fold-2y)
 (baseline_label baseline)
 (variants
  (;; --- top-500 (narrow): Quality DOMINATED (worse Sharpe + Calmar) ---
   ((label top500-alphabetical) (config_hash "")
    (aggregate (((mean_sharpe 0.667) (mean_calmar 0.850) (mean_return_pct 17.80) (mean_max_drawdown_pct 14.79)))))
   ((label top500-quality) (config_hash "")
    (aggregate (((mean_sharpe 0.636) (mean_calmar 0.676) (mean_return_pct 16.85) (mean_max_drawdown_pct 15.17)))))
   ;; --- top-1000 (mid): ~tied Sharpe, lower Calmar, lower MaxDD (most favorable cell) ---
   ((label top1000-alphabetical) (config_hash "")
    (aggregate (((mean_sharpe 0.660) (mean_calmar 0.690) (mean_return_pct 18.68) (mean_max_drawdown_pct 17.29)))))
   ((label top1000-quality) (config_hash "")
    (aggregate (((mean_sharpe 0.666) (mean_calmar 0.669) (mean_return_pct 17.71) (mean_max_drawdown_pct 15.17)))))
   ;; --- top-3000 (broad): Quality WORSE Sharpe + Calmar ---
   ((label top3000-alphabetical) (config_hash "")
    (aggregate (((mean_sharpe 0.735) (mean_calmar 0.861) (mean_return_pct 23.73) (mean_max_drawdown_pct 15.72)))))
   ((label top3000-quality) (config_hash "")
    (aggregate (((mean_sharpe 0.667) (mean_calmar 0.761) (mean_return_pct 21.23) (mean_max_drawdown_pct 15.66)))))))
 (verdict Reject)
 (notes
  "REJECT for default-flip; KEEP candidate_ranking=Alphabetical as the default. Quality (RS-primary tiebreak) does NOT clear do-no-harm across the breadth grid: it lowers Calmar in ALL 3 cells (0.850->0.676, 0.690->0.669, 0.861->0.761), lowers mean Sharpe in 2 of 3 (top-500 0.667->0.636, top-3000 0.735->0.667; top-1000 ~tied 0.660->0.666), and is DOMINATED (off the Pareto frontier) in the narrow top-500 cell. The only thing Quality consistently buys is LOWER DISPERSION (Sharpe sigma down in all cells; Deflated Sharpe up: ~0.997 vs ~0.99) and lower MaxDD in 2 of 3 -- not enough to offset the return-adjusted (Calmar/Sharpe) degradation. The top-1000 single cell looked do-no-harm-favorable (the run that triggered the grid); the grid shows that was the EXCEPTION, not the rule -- a textbook promotion-confirmation save (cf. early-admission 2026-05-30). WHY (transferable): RS-magnitude-PRIMARY tiebreak preferentially picks the highest-RS = most EXTENDED (already-run-up) names among ties -- exactly the 'do not buy extended Stage-2' setups the book warns against -- mildly taxing the fat tail / Calmar; alphabetical, being random w.r.t. RS, picks a more diversified cross-section that does as well or better. Consistent with project_edge_is_the_fat_tail (you cannot pre-pick winners; ranking that chases strength can SELECT-AGAINST the fat tail). DISTORTION QUESTION ANSWERED: the alphabetical tiebreak DOES materially reshuffle per-fold broad-universe results (fold-level deltas of 10-30pp), BUT it is NOT inferior -- it is marginally BETTER on return-adjusted metrics -- so the prior backtest corpus is NOT degraded by the alphabetical default and needs NO re-pin. FORWARD DIRECTIVE (capitalize-findings): if revisited, test an EARLINESS-PRIMARY ordering (prefer FRESH breakouts over extended ones -- the more faithful reading of 'don't buy extended'); the current Quality key relegates earliness to secondary behind RS, which is likely why it underperforms. Mechanism stays merged as a default-off config axis (#1786, both QC APPROVED) -- no revert needed. Artifacts: dev/experiments/candidate-ranking-wfcv-2026-06-29/ (FINDINGS.md + spec/base/out for all 3 cells). Warehouses (gitignored): dev/data/snapshots/wfcv-top{500,1000,3000}-1998."))
