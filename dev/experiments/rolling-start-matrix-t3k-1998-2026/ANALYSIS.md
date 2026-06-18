# Factor-lens causal analysis — top-3000 1998-2026 rolling-start matrix

**Date:** 2026-06-18 · **Matrix:** `matrix-t3k-1998-28-raw.md` (41 starts, all
benchmarked) · Cell-E over PIT `top-3000-1998` universe, `snap_top3000_1998_2026_v2`
warehouse (columnar mmap), stride 255, end 2026-04-30, `SNAPSHOT_CACHE_MB=1024`,
parallel 2, ~12h wall.

**This is the deepest / final confirmation cell** of the factor-lens confirmation
grid. It is the only cell whose early starts face **both** the dot-com bust (2000-02)
**and** the GFC (2008) ahead of them — forward index max-DD reaches −56.78%, far
deeper than the 2000-26 cell's −33.92% headline or the 2011-26 cell's COVID-only
−33.92%. It tests the sharpest prediction of H1: with the deepest possible forward
drawdown to dodge, does realized edge finally turn **positive**?

## Headline

- **YES — the two deepest-forward-DD starts post POSITIVE realized edge:**
  **1998-01-01 +1.20%** and **1999-05-26 +0.46%** (both at fwd index max-DD −56.78%).
  These are the **only positive-realized-edge starts across all four cells**
  (t1k-2000, t3k-2000, t3k-2011 had zero). The 1998-01 start is exactly the deep
  contiguous run that BEAT on realized P&L (+1552% vs +599%,
  `[[project_deep_1998_2026_contiguous]]`) — the lens reproduces it and explains
  why: deepest drawdown ahead ⇒ maximal dodge benefit.
- **H1 dodge-correction REPLICATES (4th cell):** realized edge ~ forward index
  max-DD **Pearson r = −0.820** (n=41). Terciles by forward DD monotonic:
  deepest **−3.52** / mid −8.45 / shallow −16.45. The deepest tercile (−3.52) is
  the least-negative tercile mean of any cell — closest to break-even.
- **Overall still net-negative** (median realized edge −7.72%, only 9.76% of starts
  beat) — because 41 starts over 1998-2026 are dominated by post-2009 starts whose
  forward windows are bull-heavy (little DD to dodge). The negative bulk and the
  positive deep-DD head are the **same dodge mechanism**, not a contradiction.
- CAGR compression: median CAGR 4.54% (vs the index's higher modern CAGR) — the
  long deep window includes two ~50% bear markets that cap absolute CAGR; the
  strategy's edge is relative drawdown avoidance, not absolute return.

## Hypothesis tests (Pearson r, realized edge unless noted; n=41)

| hypothesis | factor | t3k 1998-26 | t3k 2011-26 | t3k 2000-26 | t1k 2000-26 | verdict |
|---|---|---|---|---|---|---|
| **H1 dodge-correction** | forward index max-DD | **r = −0.820**; terciles −3.52 / −8.45 / −16.45 | −0.892; −7.79/−8.61/−23.40 | −0.744; −4.21/−6.46/−16.39 | −0.79; −4.98/−9.65/−15.01 | **SUPPORTED — replicates in the 4th, deepest cell** |
| **H2 melt-up tax** | (H1 flip side) | shallow-DD (post-2017) starts worst (−16.45 third, down to −31.97) | same | same | same | **SUPPORTED** |
| **H3 fresh-supply** | Stage-2 candidate count | r = +0.42 | +0.43 | +0.44 | +0.11 | **NOT clean** — same regime confound across all t3k cells |

## Read — the confirmation grid is closed

Across **four independent cells** spanning two universes (top-1000, top-3000) and
the full macro-regime span (bull-dominated 2011-26; bear-inclusive 2000-26;
deepest dot-com+GFC 1998-26):

| cell | H1 r | deepest-DD tercile | shallow-DD tercile |
|---|---|---|---|
| t1k 2000-26 | −0.79 | −4.98 | −15.01 |
| t3k 2000-26 | −0.744 | −4.21 | −16.39 |
| t3k 2011-26 | −0.892 | −7.79 | −23.40 |
| **t3k 1998-26** | **−0.820** | **−3.52** | −16.45 |

H1 r ∈ {−0.74, −0.79, −0.82, −0.89} — uniformly strong-negative, monotonic
terciles in every cell. **Regime (depth of forward drawdown) governs the strategy's
relative edge; this is universe-robust and macro-regime-robust.** Entry-supply (H3)
is confounded with regime in every cell and is not an independent lever — the 5th/6th
re-derivation of `[[project_accuracy_is_unreachable_diversify_instead]]`.

**The new, sharper fact from this cell:** the relationship is not merely
directional — it crosses zero. With a deep enough forward drawdown (dot-com + GFC),
realized edge goes **positive** (1998-01 +1.20, 1999-05 +0.46). The strategy is a
**drawdown-avoidance instrument**: it pays off precisely and only when there is a
large drop to avoid, and it is a relative drag in its absence. This is the honest,
mechanistic statement of the edge — consistent with
`[[project_index_beating_structural_bar]]` and `[[project_edge_is_the_fat_tail]]`.

## Caveat (unchanged, and now reinforced)

The deploy signal (forward index max-DD) is **ex-post** — known only with
hindsight. This grid establishes that the regime lever *exists and is robust*, but
NOT that a real-time proxy can capture it. Per user direction 2026-06-18, building
a regime-gated deploy rule is a **dead end** — it is market-timing on SPY, which is
hard and already shown to be worse (`[[project_next_lever_decision_grading]]`). The
crash-dodging is already built into the strategy's Stage-3/4 exits. The grid's value
is explanatory closure on *why* the edge behaves as it does, not a new mechanism.

## Provenance

- Scenario `/tmp/cell-e-top3000-1998-28y.sexp` (PIT `top-3000-1998`, 1998-01-01 →
  2026-04-30). Warehouse `/tmp/snap_top3000_1998_2026_v2` (columnar mmap, 3015 sym
  incl GSPC.INDX). `rolling_start_eval --stride-days 255 --benchmark GSPC.INDX
  --parallel 2`, `SNAPSHOT_CACHE_MB=1024`. Pearson r / terciles via awk over the
  per-start table (realized edge %, forward index max-DD %, Stage-2 count); 41
  starts, none excluded.
