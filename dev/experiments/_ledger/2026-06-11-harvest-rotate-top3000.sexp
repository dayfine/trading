((date 2026-06-11) (slug harvest-rotate-top3000)
 (hypothesis
  "Harvest-and-rotate (user-greenlit rigorous test of the 2026-06-10 read-only screen): on the Stage2 `late` flag (MA-deceleration topping precursor), trim a fraction `harvest_fraction` of a held long via the new TriggerPartialExit transition (#1525) and let the freed capital recycle through the normal entry pipeline. Weinstein-faithful as the book's 'sell half / protect the rest as Stage 3 forms' (weinstein-book-reference.md Stage 3). The read-only screen (dev/experiments/harvest-rotate-validation-2026-06-10/) was INCONCLUSIVE not a rejection (per-decision coin flip, mild tail-risk). Does trimming-late-winners-and-recycling generalise under top-3000 WF-CV on any harvest_fraction?")
 (base_scenario "goldens-custom-universe/composition/top-3000-2011 (PIT)")
 (window_id wf-2011-2026-365-365-15fold-top3000-forkperfold)
 (baseline_label baseline)
 (variants
  (((label baseline) (config_hash "enable_harvest_rotate=false")
    (aggregate
     (((mean_sharpe 0.6452) (mean_calmar 1.3800) (mean_return_pct 12.99)
       (mean_max_drawdown_pct 14.77) (return_stdev 22.59) (sharpe_wins 15)
       (avg_holding_days 33.2)))))
   ((label harvest_k033) (config_hash "enable_harvest_rotate=true harvest_fraction=0.33")
    (aggregate
     (((mean_sharpe 0.4109) (mean_calmar 0.9785) (mean_return_pct 11.06)
       (mean_max_drawdown_pct 15.46) (return_stdev 29.81) (sharpe_wins 7)
       (avg_holding_days 29.8) (gate FAIL)))))
   ((label harvest_k050) (config_hash "enable_harvest_rotate=true harvest_fraction=0.50")
    (aggregate
     (((mean_sharpe 0.6268) (mean_calmar 1.3144) (mean_return_pct 17.63)
       (mean_max_drawdown_pct 14.44) (return_stdev 37.01) (sharpe_wins 8)
       (avg_holding_days 29.0) (gate FAIL)))))
   ((label harvest_k100) (config_hash "enable_harvest_rotate=true harvest_fraction=1.00")
    (aggregate
     (((mean_sharpe 0.4140) (mean_calmar 1.3100) (mean_return_pct 13.25)
       (mean_max_drawdown_pct 15.50) (return_stdev 27.75) (sharpe_wins 6)
       (gate FAIL)))))))
 (verdict Reject)
 (notes
  "REJECT. No harvest_fraction passes the per-fold gate (>=8/15 Sharpe wins, no fold worse by dSharpe>0.30): k033 7/15 (FAIL M), k050 8/15 but worst fold fold-006 trails by 1.57 (FAIL delta), k100 6/15 (FAIL M+delta). DECOMPOSED WHY (the real deliverable, per .claude/rules/mechanism-validation-rigor.md): harvest-rotate is dispersion-amplifying NOISE, not Sharpe-improving signal. (1) No risk-adjusted edge: the best variant (k050) has mean Sharpe 0.627 ~= baseline 0.645 (slightly WORSE); k033/k100 clearly worse (0.41). (2) Dispersion amplification: k050 return stdev 37.0 vs baseline 22.6 (1.64x) -- the trim-and-redeploy scrambles the return distribution. (3) NOT timing skill: the per-fold return-delta vs baseline is noise with no regime pattern -- harvest helps in some strong folds (fold-002 +29pp, fold-010 +50pp) and hurts in others (fold-006 -12pp, fold-009 -24pp). (4) The STRUCTURAL TAX is the gate-killer: the worst folds are exactly where baseline rode winners to high Sharpe and harvest trimmed them -- fold-006 (2017) baseline Sharpe 2.48 -> k050 0.91, fold-009 baseline return 31% -> k050 7%. Trimming the winner gave up the fat tail. Net: the timing-wins and structural-tax-losses cancel on return (mean 12.99 vs 17.63 is within noise given sigma 22-37) while Sharpe is unchanged and variance rises. This is a quantified instance of project_edge_is_the_fat_tail: TOUCHING WINNERS (trimming them) scrambles the return distribution without improving risk-adjusted return. The mechanism stays default-off; the axis remains available but is NOT promotable. Surface: /tmp/sweeps/harvest-wfcv; spec dev/experiments/harvest-rotate-wfcv-2026-06-11/. A trade-level structural-tax-vs-timing split (per-trim forward return of the trimmed position vs the redeployed capital) would further quantify (3)/(4) but cannot change the unanimous gate-FAIL verdict."))
