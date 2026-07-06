((date 2026-07-06) (slug cash-reserve-surface)
 (hypothesis
  "User-directed (2026-07-06) after the envelope-knobs-dead finding (#1861: min_cash_pct was dead code; backtests always ran ~0% reserve): does a WORKING 10-30% cash reserve (mechanism #1867, cash_reserve_pct, entry-funding only, exits exempt) buy enough DD/dispersion relief to justify the return cost? Prior from edge_is_the_fat_tail: reserve = breadth tax, likely REJECT; the 13 folds price the marginal value of the last-funded entries directly.")
 (base_scenario
  "BROAD-ONLY surface (top-3000 PIT-2000), 2000-2026, 13x2y non-overlapping folds, production caps + catstop 0.10, Cell-E long-only + stage3/laggard, snapshot warehouse fork-per-fold.")
 (window_id surface-broadonly-top3000-wfcv-2000-2026-13fold-2y)
 (baseline_label baseline)
 (variants
  (((label baseline) (config_hash "")
    (aggregate
     (((mean_sharpe 0.5968746113084944) (mean_calmar 0.68270632982270452)
       (mean_return_pct 19.918805991794873)
       (mean_max_drawdown_pct 15.357873569718073)))))
   ((label r10) (config_hash "")
    (aggregate
     (((mean_sharpe 0.41340286667604204) (mean_calmar 0.45141533014845631)
       (mean_return_pct 12.182179376923072)
       (mean_max_drawdown_pct 16.018929057684762)))))
   ((label r20) (config_hash "")
    (aggregate
     (((mean_sharpe 0.62049874969584906) (mean_calmar 0.70583851630544148)
       (mean_return_pct 16.825346661999994)
       (mean_max_drawdown_pct 13.200440617863508)))))
   ((label r30) (config_hash "")
    (aggregate
     (((mean_sharpe 0.44138858905239353) (mean_calmar 0.6085105837615733)
       (mean_return_pct 12.734340717692303)
       (mean_max_drawdown_pct 13.43981148068063)))))))
 (verdict Reject)
 (notes
  "REJECT for promotion; mechanism stays default-off (0.0) axis. Gate FAIL all variants (Sharpe wins 4/6/4 of 13, all m<7; worst-fold gaps 0.70/0.40/0.79 all > 0.30). ANSWER TO THE MOTIVATING QUESTION: the assumed-production 30% reserve is a clear LOSS (Sharpe mean 0.441 vs 0.597, return 12.7 vs 19.9%, and WORSE in the 2022 bear fold: -15.5% vs baseline -10.2%) - holding 30% cash buys only ~2pp mean-MaxDD relief (15.4->13.4) for a ~7pp return cost; the old dead-config values were never a good idea, just untested decoration. THE TRANSFERABLE WHYs: (1) THE RESERVE RESPONSE IS NON-MONOTONIC - r10 is worse than BOTH neighbors nearly everywhere (f000 -5.0 vs baseline +5.4 and r20 +7.6; f003 10.6 vs 36.3 and 22.5; f009 -5.1 vs 18.0 and 14.8) and r20 beats both neighbors on aggregate (Sharpe 0.620, MaxDD 13.2, DD wins 9/13, lowest return sigma 15.8). A funding-budget change reshuffles WHICH candidates get funded at the cash boundary (score order + alphabetical tiebreak), a chaotic path-dependence, NOT a smooth risk dial - same class as the capacity-concentration 0.25 knife-edge spike (2026-06-25 ledger). (2) r20 aggregate edge (+0.023 raw mean Sharpe) is a single-value spike between two worse neighbors driven mostly by ONE flipped fold (f011 2022: +12.7% vs baseline -10.2%, Sharpe +0.66 vs -0.42) while r30 got the OPPOSITE result in the SAME fold (-15.5%, Sharpe -1.15) - not a robust regime benefit, not DSR-survivable at n_trials=3, and it still gate-FAILs on worst-fold f001 (gap 0.40). Textbook do-not-promote. (3) DD relief is real but small and dominated by the fat-tail tax: in the monster fold f010 (2020-21) every reserve level costs return (72.0 -> 45.3/56.1/48.8) - 10th edge_is_the_fat_tail confirmation: the marginal cash-boundary entries carry positive expectancy on net; cutting their funding costs more than the cash cushion returns. FORWARD: envelope program now FULLY closed both directions (loosening impossible - already ~100% deployed, #1861; tightening tested here - rejected). cash_reserve_pct stays a searchable axis; do NOT re-sweep standalone; if capital-protection is ever wanted, the evidenced lever class is the barbell overlay (70/30 passed its grid 2026-06-20), not an entry-funding reserve. SECONDARY OBSERVATION worth a future lens (not a build): the fold-level chaos of small funding perturbations is more evidence the cash-boundary candidate selection is noise-dominated (ties + alphabetical tiebreak) - connects to project_screener_alphabetical_tiebreak. Ops: ~8.5h wall, 52 fold-runs, zero failures. Artifacts: dev/experiments/cash-reserve-2026-07-06/ (spec, out_top3000, run.log). Writeup: dev/notes/cash-reserve-wfcv-2026-07-06.md."))
