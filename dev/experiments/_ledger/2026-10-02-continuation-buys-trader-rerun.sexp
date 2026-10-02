((date 2026-10-02) (slug continuation-buys-trader-rerun)
 (hypothesis
  "Continuation buys (enable_continuation_buys, Weinstein's Trader's Way re-breakout) add to the hybrid trader preset once the entry ticket is anchored at the continuation detector's consolidation_high (#3067; before it, T1 was trade-identical to H in all 6 cells of the 09-29 matrix, #3056). Pre-registered 2026-10-01 (trader-presets-rerun-2026-10-02/README.md, commit 61dfc6db2): rules 1-5 of the 09-29 matrix verbatim - V6 gate per salt, 2 of 3 valid salts, Calmar primary with a 5 pp max-DD guard; 'adds' in both windows permits a ledger entry, promotion only via the confirmation grid.")
 (base_scenario
  "trader-presets-rerun-2026-10-02: tp-t1-{5r,5d} vs tp-h-{5r,5d}, salts 0-2, PIT top-3000 schedule on _v11pit, one build f86d38f54 (main after #3067), pinned worktree; H cells byte-identical to the 09-29 matrix on trades.csv + actual.sexp; validator_diff -check V6 exit 0 every pair.")
 (window_id trader-presets-5r-2021-2026-and-5d-2007-2012-3salt) (baseline_label tp-h-hybrid)
 (variants
  (
   ((label t1-5r) (config_hash continuation-buys-on)
    (aggregate (((mean_calmar 0.0388) (mean_return_pct 10.34) (mean_max_drawdown_pct 40.33)))))
   ((label t1-5d) (config_hash continuation-buys-on)
    (aggregate (((mean_calmar 0.0369) (mean_return_pct 3.34) (mean_max_drawdown_pct 17.60)))))
  ))
 (verdict Accept)
 (notes
  "ACCEPT by rule ('adds' 2/3 at 5r, 3/3 at 5d, DD never > 5 pp worse; 5d DD 12 pp better), NOT PROMOTABLE: each window's delta is one ticket the old anchor could not fill. 5d: FNSR 2009-08-24 -> 2010-08-23 +$153-155k in all 3 salts (T1 suggested_entry 0.80 = consolidation_high vs H 1.51 against a 0.72 close, never filled). 5r: ADMA 2023-12-19 -> 2024-12-23 +$230k at s0/s2, a 17-week resting ticket H never placed; s1 (the losing salt) has no ADMA. Without those two, T1's unshared trades sum -$83k/-$112k/+$9k (5r) and -$8k/-$22k/-$18k (5d); shared trades lose $7-64k in all 6 cells (smaller sizing). Tail-lottery shape (project_clock26_is_a_tail_lottery, project_edge_is_the_fat_tail). Rule-9 entry-type classifier void (H has 6-14 entries with weeks_advancing > 4; FNSR's continuation ticket has weeks_advancing 1) - the continuation vs base-breakout split is not measurable until #3074 tags the anchor kind. FORWARD: no default flip; any grid needs a pre-2009 cell and a per-event read keyed on anchor kind. Same chain: T2 (10-week trail) dilutes 5r 0/3, adds 5d 2/3 -> regime-dependent; T0S (10-week stages, 30-week stop) adds vs H 2/3 at 5r, not separable from T0 at n=3, book prior rules out 10-week stage arms. Artifacts: trader-presets-rerun-2026-10-02/results/tp-*-v11-*; writeup results-2026-10-02.md."))
