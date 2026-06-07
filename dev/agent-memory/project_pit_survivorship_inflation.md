---
name: project_pit_survivorship_inflation
description: "Survivorship inflation is LARGE — same Cell-E config 15y: SP500-survivor 237%/17.5%DD vs PIT top-1000 29.6%/42%DD. Most apparent Weinstein alpha on SP500/sectors universes is survivorship. Re-baseline on PIT composition series."
metadata: 
  node_type: memory
  type: project
  originSessionId: 227b33ee-5af1-4eb1-80b9-2d487d5b7bd2
---

2026-06-07 (macro-bearish-trim breadth study). Measured the magnitude of
survivorship bias directly, same Cell-E config + same 15y window (2011-2026):

- **SP500-survivor universe:** 237% return / 17.5% MaxDD
- **PIT top-1000 (survivorship-correct):** 29.6% return / **42% MaxDD**

Return collapses ~8× and drawdown more than doubles once the delisted losers are
included. **Most of the apparent Weinstein "alpha" we have been pinning baselines
and judging experiments against is survivorship inflation**, not edge.

**The honest substrate exists and is now tractable:** the PIT composition series
`test_data/goldens-custom-universe/composition/top-{500,1000,3000}-{1998..2025}.sexp`
— one frozen point-in-time membership per year × breadth, **delisted-aware**
(verified: top-3000-2019 has SIVB/FRC/BBBY which failed after 2019; top-3000-1998
has LEH/AIG; top-1000-2001 has 34 delisted "Q" tickers). The OLD
[[project_composition_golden_survivor_bias]] finding (2026-05-17, "composition
goldens are survivor-biased") was superseded by the 2026-06-05 delisted-aware
rebuild. **Caveat:** top-**500** carries a mega-cap SIZE bias (outperforms) — use
top-1000+ for representative breadth; size bias ≠ survivorship bias.

**Follow-up (higher value than the trim that surfaced it):** re-baseline core
strategies (Cell E, the barbell legs, the accepted mechanisms) on PIT, and
re-check past ACCEPT/REJECT verdicts — some ACCEPTs may be survivor artifacts,
some REJECTs may have been judged on inflated numbers. Tractable now via snapshot
mode ([[feedback_large_n_needs_snapshot_mode]]); N=3000 needs the cheap cache
bump (`panel_runner.ml:_snapshot_cache_mb`). Writeup:
`dev/notes/macro-bearish-trim-grid-2026-06-07.md` §5.
