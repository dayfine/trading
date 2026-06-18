# Decision-grading lens — first complete report (2026-06-18)

First end-to-end run of the decision-grading lens (`trading/trading/backtest/decision_grading/`, PRs #1646/#1647/#1649) on a **fresh** Cell-E top-3000 PIT-2011 backtest (15y contiguous, 2011-01-01 .. 2026-04-30) so per-trade MFE — and therefore the entry-capture ratio — are populated (the prior smoke-test reused a pre-#1506 run with MFE=0).

- Run: `dev/backtest/scenarios-2026-06-18-212152/cell-e-top3000-2011-15y-fresh/` (reproduces the known +790.5% / 671 trades / 29.2% MaxDD baseline, bit-identical).
- Warehouse: `/tmp/snap_top3000_2011_v2` (3000 + 15 macro/ETF context symbols), `SNAPSHOT_CACHE_MB=1024`.
- Grade horizon 13w; continuation horizons 4/13/26w.

## The report

| exit_reason | n | mean realized | post-exit cont. | % premature | % good exit | net value-add | capture |
|---|---|---|---|---|---|---|---|
| laggard_rotation | 220 | +12.8% | −1.6% | 21% | 25% | +1.6% | −0.09 |
| stage3_force_exit | 5 | +5.5% | −9.4% | 0% | 60% | +9.4% | −0.90 |
| stop_loss | 440 | −2.8% | +8.1% | 28% | 24% | −8.1% | −2.83 |
| unlabeled | 6 | −3.9% | +4.4% | 17% | 17% | −4.4% | −1.59 |

Columns: **net value-add** = realized − counterfactual-if-held = −(mean post-exit continuation); positive means exiting helped. **capture** = group mean of per-trade `realized_pct / MFE_pct` (fraction of in-trade peak realized; negative = closed for a loss despite having been up at its peak). Note mean-of-ratios ≠ ratio-of-means: a group can have positive mean realized (fat-tail winners) yet negative mean capture (the typical trade gave its peak back).

## Decision-level reading

- **stop_loss is the value-destroying decision type, quantified.** Net value-add **−8.1%** (the average stopped name rose +8.1% over the quarter *after* we sold) and capture **−2.83** (the average stopped trade had been *up* at its peak, then closed for a loss — gave back the peak and more). This is the whipsaw / stop-too-tight signature: stops fire on names that had shown a gain, exit at a loss, and then recover. 28% premature vs 24% good-exit.
- **laggard_rotation is net-positive on the exit decision (+1.6%)** and houses the fat-tail winners (mean realized +12.8%); capture ≈ 0 means the *typical* rotated-out name had stalled (captured ~none of its peak) — consistent with rotating capital out of laggards into fresher Stage-2 names. The mean is carried by a few monsters (the let-winners-run tail).
- **stage3_force_exit dodges drops** (post-exit −9.4%, 60% good exits, net +9.4%) but n=5 — directionally Weinstein-faithful (exit as the Stage-3 top forms), too small to lean on.

This re-derives `dev/experiments/trade-forensics-2026-06-12/` as a **repeatable instrument**: stops ≈ value-negative whipsaw premium, laggard-rotation = the profit channel. Consistent with the standing tail-preserving thesis (`project_edge_is_the_fat_tail`): stops are the tail-risk *insurance premium* the strategy pays; the lens now prices that premium per decision type.

## Caveats (per `mechanism-validation-rigor`)

- One window / one regime (2011-26 bull-dominated). Not a promotion verdict — a **descriptive** decision-level read on one surface. A multi-regime read (deep 1998-2026) and the paired laggard counterfactual (Phase 5) would sharpen it.
- The stop "net −8.1%" is the post-exit *continuation* counterfactual (held-with-no-stop through the horizon); it does NOT net out the tail-risk the stop insures against. The right conclusion is "the stop premium is large and measurable," not "remove stops" — removing stops is a winner-touching / tail-risk change that must go through WF-CV + the confirmation grid.

## Harness fix shipped alongside

The Phase-4 CLI originally read MFE via `Trade_audit_report`'s ratings, keyed by the **audit** entry_date (Friday decision date) — which is ~1 day off the round-trip's `trades.csv` entry_date (fill date), so the join always missed and capture rendered `n/a`. Fixed to read `exit_decision.max_favorable_excursion_pct` straight from `trade_audit.sexp` with the same nearest-within-7-days join `Trade_audit_ratings` uses.
