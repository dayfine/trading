((date 2026-06-22)
 (slug neutral-blocks-shorts-wfcv)
 (hypothesis
  "neutral_blocks_shorts=true (admit shorts only in a confirmed-Bearish macro tape, not Neutral) is helpful-or-inert vs the un-gated short leg across regimes — it removes the loss-making Neutral-tape squeeze shorts while keeping every faithful Bearish-tape short")
 (base_scenario "goldens-sp500-historical/sp500-2000-2026-longshort.sexp")
 (window_id wfcv-deep-2000-2026-26fold)
 (baseline_label baseline)
 (variants
  (((label neutral_blocks_shorts=true)
    ;; Nominal hash: keyed on the single flag (neutral_blocks_shorts true) on
    ;; top of the deep long-short Cell-E-style base. Dedup approximate; the
    ;; verdict + per-fold record are the load-bearing artifacts.
    (config_hash nbs-true-deep-2000-2026)
    (aggregate
     ((sharpe_mean 0.707) (calmar_mean 1.331) (maxdd_mean 11.61)
      (return_mean 11.38) (pareto_frontier yes) (deflated_sharpe 0.9998))))))
 (verdict Accept)
 (notes
  "Single-cell ACCEPT (helpful-or-inert), NOT a default flip — promotion-confirmation.md grid required. See dev/backtest/neutral-blocks-shorts-wfcv-2026-06-22/. true >= baseline in 25/26 folds (24 byte-identical ties + fold-003 2003 squeeze-avoidance win 19.65->28.66% / Sharpe 1.262->1.832), worse in 1 (fold-010 2010, -0.78pp). Aggregate edge small (+0.02 Sharpe) and DSR-indistinguishable (0.9998 all) -> faithful free-or-positive filter, default flip gated on a 2nd (period x universe) cell. Faithful: Weinstein shorts only in confirmed Bearish tapes. Born from faithful-short-deep-screen-2026-06-22 (the deep screen that split Build-3's two flags). Sibling: enable_slow_grind_short_gate REJECT-leaning (taxes the short tail).")
 )
