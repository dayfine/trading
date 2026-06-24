((date 2026-06-22)
 (slug neutral-blocks-shorts-grid)
 (hypothesis
  "neutral_blocks_shorts=true is robust across the promotion-confirmation grid (a 2nd period x universe cell) and therefore eligible for a default flip")
 (base_scenario "goldens-sp500-historical/sp500-2010-2026-longshort.sexp")
 (window_id wfcv-cell2-2010-2026-16fold)
 (baseline_label baseline)
 (variants
  (((label neutral_blocks_shorts=true)
    (config_hash nbs-true-sp500-2010-2026-16fold)
    (aggregate
     ((sharpe_mean 0.576) (calmar_mean 1.170) (maxdd_mean 11.48)
      (pareto_frontier no) (deflated_sharpe 0.9875))))))
 (verdict Reject)
 (notes
  "GRID DISAGREEMENT -> NO DEFAULT FLIP (keep ACCEPT-mechanism, promote no value). See dev/backtest/neutral-blocks-shorts-grid-2026-06-22/. Cell 1 (2000-2026 all-regime, 2026-06-22-neutral-blocks-shorts-wfcv) had true >= baseline (won 2003 squeeze +0.02 Sharpe). Cell 2 (this, 2010-2026 bull, sp500-2010 golden): true identical in 15/16 folds, marginally WORSE in fold-009 2019 (MaxDD 8.43->9.39), dominated on MaxDD / off frontier. So neutral_blocks_shorts helps in bear-containing regimes (post-bottom squeeze avoidance) but is inert-or-fractionally-worse in clean bulls (removes occasionally-useful Neutral shorts) = regime-dependent trade, NOT a free win. Per promotion-confirmation.md no single value robust across grid -> mechanism stays default-off axis. The grid PREVENTED an over-promotion cell-1 alone suggested (the methodology working as designed). Short-leg value is regime-governed (project_factor_lens_regime_governs_edge); a static global flip can't be right for both regimes. This Reject verdict is on the PROMOTION (the flip), not the mechanism (which keeps its cell-1 ACCEPT as an axis).")
 )
