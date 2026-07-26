((date 2026-07-24) (slug margin-m4-leverage-surface)
 (hypothesis
  "M4.3 (levered-longshort-margin-realism plan): with leverage HONESTLY PRICED (M1-M3 stack: long buying power equity/req, 8%/yr margin interest on the debit, M2 long maintenance 0.30 force-reduce, short collateral locks + FINRA/HTB tier tables), a levered long book (initial_long_margin_req 0.75 or 0.5) and/or the short sleeve could clear the UNLEVERED frontier on risk-adjusted fold terms. Stage-1 parity gates all bit-identical (margin-off == baseline cross-commit vs 07-22 record; explicit no-ops == absent; req=1.0/rate=0 == E-capped) and stage-2 squeeze cells passed (no false fire; engagement proven on forced cell; label gap #2057) before this surface ran.")
 (base_scenario
  "staging-record-convention/top3000-2000-2026-record-convention on /tmp/snap_top3000_dedup_v5thin (promoted-bundle defaults post-#2047)")
 (window_id margin-m4-broad-13x2y-2000-2026)
 (baseline_label baseline)
 (variants
  (((label "req=1.0 shorts=off (armed-margin no-op corner)") (config_hash "")
    (aggregate
     (((mean_sharpe 0.827) (mean_calmar 1.309) (mean_return_pct 36.17)
       (mean_max_drawdown_pct 14.05)))))
   ((label "req=1.0 shorts=on (cash-account long-short, priced)") (config_hash "")
    (aggregate
     (((mean_sharpe 0.883) (mean_calmar 1.464) (mean_return_pct 41.11)
       (mean_max_drawdown_pct 14.52)))))
   ((label "req=0.75 shorts=off (1.33x long)") (config_hash "")
    (aggregate
     (((mean_sharpe 0.558) (mean_calmar 0.842) (mean_return_pct 99.59)
       (mean_max_drawdown_pct 49.63)))))
   ((label "req=0.75 shorts=on") (config_hash "")
    (aggregate
     (((mean_sharpe 0.572) (mean_calmar 0.880) (mean_return_pct 99.76)
       (mean_max_drawdown_pct 49.37)))))
   ((label "req=0.5 shorts=off (2x long)") (config_hash "")
    (aggregate
     (((mean_sharpe 0.341) (mean_return_pct 37.04)
       (mean_max_drawdown_pct 89.02)))))
   ((label "req=0.5 shorts=on") (config_hash "")
    (aggregate
     (((mean_sharpe 0.413) (mean_return_pct 28.53)
       (mean_max_drawdown_pct 88.83)))))
   ((label baseline) (config_hash "")
    (aggregate
     (((mean_sharpe 0.827) (mean_calmar 1.309) (mean_return_pct 36.17)
       (mean_max_drawdown_pct 14.05)))))))
 (verdict Reject)
 (notes
  "REJECT priced long leverage at every tested requirement; no cell clears the fold gate (>=7/13 Sharpe wins): req=1.0+shorts 6/13 (worst-fold -0.944), req=0.75 4-6/13 (worst -1.76), req=0.5 4-5/13 (worst -1.99, MaxDD ~89% = near-wipeout folds, CAGR n/a on ruined folds). CORNER SANITY: (req=1.0, shorts=off, full armed margin_config) is fold-identical to baseline on all 13 folds (0 wins, gap 0.0000) -- the armed margin stack is a true no-op on an unlevered long-only book at scenario scale, closing the M4.1 parity loop from inside the surface. WHY, decomposed: (a) leverage amplifies BOTH tails but the strategy's cost structure is a steady whipsaw premium (~30-39 stops/yr) punctuated by rare monsters -- 1.33x/2x on the premium compounds ruinously in chop folds while the monster folds were already near fully invested (min_cash 0.30 binds), so upside amplification is capped exactly where downside is not (asymmetric amplification = Sharpe collapse .827 -> .558 -> .341, monotone in leverage); (b) at req=0.5 raw return is LOWER than req=0.75 (37 vs 100) -- volatility drag + maintenance force-reduces liquidating into weakness (M2 engaging at path level; labels invisible pending #2057) mean over-leverage destroys even the return it was bought for; (c) the short sleeve is mildly additive at cash-account (req=1.0: Sharpe .827 -> .883, 6/13 -- hedge-shaped, consistent with P1a) but NOT gate-robust, and its value is INVARIANT to long leverage (0.75/0.5 pairs nearly identical) -- it hedges the tape, not the leverage. Forward guidance: leverage is not a lever on this edge; the honest-cost answer to 'can we amplify' is the same as every winner-touching probe -- the fat tail cannot be scaled, only taxed. Cash-account long-short (the .883 cell) remains the only faint positive; it may merit a dedicated surface ONLY if a future short-side mechanism changes its economics (currently fails gate + no-reversal-timing discipline applies). M4 protocol COMPLETE: stages 1-3 all run, no promotion candidate, no confirmation grid triggered, no default flips. Report /tmp/sweeps/margin-m4-surface/walk_forward_report.md; spec test_data/walk_forward/margin-m4-leverage-BROAD-2000-2026.sexp; validation record dev/notes/margin-m4-validation-2026-07-23.md."))
