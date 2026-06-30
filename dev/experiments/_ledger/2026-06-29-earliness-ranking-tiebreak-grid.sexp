((date 2026-06-30) (slug earliness-ranking-tiebreak-grid)
 (hypothesis
  "candidate_ranking=Quality_earliness (new, default-off): equal-score tiebreak led by EARLINESS (weeks_advancing ascending -> freshest Stage-2 breakout first), then RS magnitude desc -> volume desc -> ticker. The forward-directive successor to RS-primary Quality (rejected by 2026-06-29-candidate-ranking-tiebreak-grid). FRAMING: faithfulness fix ('do not buy an extended Stage 2'), do-no-harm bar NOT return-seeking. The directive guessed Quality underperformed because earliness was relegated behind RS, so leading with earliness should help. Same breadth grid as #1788: top-500/1000/3000 PIT-1998, 2000-2026, 13 folds 2y non-overlapping, fork-per-fold, snapshot mode, Cell-E long-only, baseline=Alphabetical (reproduces #1788 baselines bit-for-bit).")
 (base_scenario "GRID 3-cell breadth x 2-variant (Alphabetical baseline / Quality_earliness), 2000-2026, 13 folds. top-500 (327 syms w/ bars), top-1000 (514), top-3000 (1065). Cell-E long-only.")
 (window_id grid-3cell-breadth-wfcv-2000-2026-13fold-2y)
 (baseline_label baseline)
 (variants
  (;; --- top-500 (narrow): earliness DOMINATED (worse Sharpe + worse Calmar) ---
   ((label top500-baseline) (config_hash "")
    (aggregate (((mean_sharpe 0.667) (mean_calmar 0.850) (mean_return_pct 17.80) (mean_max_drawdown_pct 14.79)))))
   ((label top500-earliness) (config_hash "")
    (aggregate (((mean_sharpe 0.649) (mean_calmar 0.657) (mean_return_pct 17.20) (mean_max_drawdown_pct 14.98)))))
   ;; --- top-1000 (mid): earliness DOMINATED; worse than even RS-Quality (0.666) ---
   ((label top1000-baseline) (config_hash "")
    (aggregate (((mean_sharpe 0.660) (mean_calmar 0.690) (mean_return_pct 18.68) (mean_max_drawdown_pct 17.29)))))
   ((label top1000-earliness) (config_hash "")
    (aggregate (((mean_sharpe 0.590) (mean_calmar 0.586) (mean_return_pct 15.70) (mean_max_drawdown_pct 16.09)))))
   ;; --- top-3000 (broad): earliness DOMINATED (worse Sharpe + worse Calmar) ---
   ((label top3000-baseline) (config_hash "")
    (aggregate (((mean_sharpe 0.735) (mean_calmar 0.861) (mean_return_pct 23.73) (mean_max_drawdown_pct 15.72)))))
   ((label top3000-earliness) (config_hash "")
    (aggregate (((mean_sharpe 0.662) (mean_calmar 0.743) (mean_return_pct 23.43) (mean_max_drawdown_pct 16.82)))))))
 (verdict Reject)
 (notes
  "REJECT for default-flip; KEEP candidate_ranking=Alphabetical as default. Quality_earliness is Pareto-DOMINATED by baseline in ALL 3 cells -- worse Sharpe AND worse Calmar AND worse return everywhere (top-500 0.667->0.649 Sharpe / 0.850->0.657 Calmar; top-1000 0.660->0.590 / 0.690->0.586; top-3000 0.735->0.662 / 0.861->0.743). Worse than even RS-primary Quality, which at least tied baseline Sharpe in top-1000 (0.666). m-of-n Sharpe gate (7/13, Δ0.30) FAILs all 3 cells (top-500 9/13 but fold-002 Δ1.12 blowout; top-1000 6/13; top-3000 6/13). HYPOTHESIS REFUTED: leading with earliness is WORSE, not better -- it does NOT avoid the Calmar tax (top-3000 0.861->0.743 ~ RS's 0.861->0.761) and taxes Sharpe MORE. WHY (transferable): the freshest Stage-2 breakout is the LEAST-CONFIRMED (no sustained advance yet), so tilting the scarce ~5 funded slots toward it adds idiosyncratic risk without return; RS-primary tilts toward EXTENDED (taxes fat tail), earliness toward UNCONFIRMED (taxes Sharpe more) -- both biased sorts lose to unbiased Alphabetical. High per-fold dispersion (top-3000 fold-012 base -20.5 vs earl +4.1; fold-004 base +10.1 vs earl -1.3) = noise not signal. THIRD independent confirmation of project_edge_is_the_fat_tail + project_accuracy_is_unreachable: NO equal-score tiebreak on any entry feature adds return (no entry feature predicts the realized winner); scarce-cash slot allocation cannot be improved by sorting. Mechanism (where it bites): cap max_buy_candidates=20 + the DOMINANT cash/exposure ladder (~5 fundable slots, 97% of entry decisions cash-constrained per 06-27 autopsy) -- entries_from_candidates walks ranked candidates through a running cash budget, so the tiebreak decides which ~5 of many tied grade-A breakouts get funded. Mechanism stays a default-off axis (no revert). FORWARD: noise-floor control experiment (reverse-alpha / symbol-length / deterministic-hash~random) to quantify the band; if all uninformative sorts cluster and RS/earliness sit inside, 'no sort beats unbiased sampling' is proven. Artifacts: dev/experiments/earliness-ranking-wfcv-2026-06-29/ (FINDINGS.md + spec/base/out for all 3 cells). Screen that gated the build: dev/notes/earliness-primary-ranking-screen-2026-06-29.md. Warehouses (gitignored): dev/data/snapshots/wfcv-top{500,1000,3000}-1998."))
