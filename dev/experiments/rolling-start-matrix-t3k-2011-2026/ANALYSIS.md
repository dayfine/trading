# Factor-lens causal analysis — top-3000 2011-2026 rolling-start matrix

**Date:** 2026-06-17 · **Matrix:** `matrix-t3k-2011-26-raw.md` (22 starts, all
benchmarked) · Cell-E over PIT `top-3000-2011` universe, `snap_top3000_2011_v2`
warehouse (columnar mmap), stride 255, end 2026-04-30, `SNAPSHOT_CACHE_MB=1024`,
parallel 2, ~5.5h wall.

**This is the macro-regime-diverse confirmation cell** (per
`.claude/rules/promotion-confirmation.md`) for the top-3000 2000-2026 lens
(`../rolling-start-matrix-t3k-2000-2026/ANALYSIS.md`, PR #1639). The 2000-26 cell
is **bear-inclusive** (dotcom 2000-02 + GFC 2008); this 2011-26 cell is the
**bull-dominated contrast** — its only deep index drawdown is COVID-2020. It tests
whether the H1 dodge-correction shape holds when there is much less index
drawdown to dodge.

## Headline

- **H1 dodge-correction REPLICATES AND STRENGTHENS:** realized edge vs
  `forward index max-DD` **Pearson r = −0.892** (n=22) — stronger than top-3000
  2000-26 (−0.744) and top-1000 2000-26 (−0.79). Terciles by forward DD are
  monotonic with a sharp jump in the shallowest bucket.
- **Realized edge negative in all 22 starts** (median −10.58%, worst −35.53%, best
  −3.32%) — and *more* negative than 2000-26 (median −5.82%). The bull-dominated
  window has less drawdown to dodge, so the strategy's relative position is worse,
  exactly as the dodge-correction thesis predicts.
- **MTM edge median −2.63%, 45.5% of starts beat GSPC** — vs 2000-26's +1.93% /
  60.5%. Breadth still delivers fat-tail winners, but with COVID as the only deep
  forward DD the MTM edge no longer clears zero in the median.
- Median MaxDD 34.2% (vs 2000-26's 44.6%) — the bull window has a shorter left
  tail; the deep-DD GFC-bearing starts that drove 2000-26's volatility are absent.

## Hypothesis tests (Pearson r, realized edge unless noted; n=22)

| hypothesis | factor | top-3000 2011-26 | t3k 2000-26 (ref) | t1k 2000-26 (ref) | verdict |
|---|---|---|---|---|---|
| **H1 dodge-correction** | forward index max-DD | **r = −0.892**; terciles (by fwd-DD) **−7.79 / −8.61 / −23.40** monotonic | r = −0.744; −4.21/−6.46/−16.39 | r = −0.79; −4.98/−9.65/−15.01 | **SUPPORTED (strongest of the three) — REPLICATES across macro regime** |
| **H2 melt-up tax** | (H1 flip side) | shallowest-DD / smooth-bull starts (post-COVID 2020-10..2025) carry the worst realized edge (−23.40 mean third) | same | same | **SUPPORTED (sharp)** |
| **H3 fresh-supply** | Stage-2 candidate count | r = +0.43 | r = +0.44 | r = +0.11 | **NOT clean** — same confound as 2000-26: Stage-2 count tracks the macro tape (bear-onset starts have low counts AND distinct edge), so it is not independent evidence for entry-supply |

## Read

The strategy's *relative* performance is governed by **how much index drawdown
there is to dodge** (regime) — and the relationship is now confirmed across three
independent cells spanning two universes (top-1000, top-3000) and two macro
regimes (bear-inclusive 2000-26, bull-dominated 2011-26). r ∈ {−0.74, −0.79,
−0.89}, all strong-negative, all with monotonic terciles. **The regime-conditioning
shape is universe-robust AND macro-regime-robust** — the fifth independent
re-derivation of `project_factor_lens_regime_governs_edge` /
`project_accuracy_is_unreachable_diversify_instead`: regime is the lever,
entry-selection (H3) is inert.

The 2011-26 cell sharpens the picture in two ways:

1. **The strongest correlation comes from the bull-dominated window**, because its
   spread of forward-DD is bimodal: pre-COVID starts (2011-2020) all face the
   −33.92% COVID drawdown ahead of them and earn the *least-bad* realized edge
   (≈ −7.8); post-COVID starts (2020-10 onward) face shrinking forward DD
   (−25 → −9%) with **almost nothing to dodge** and earn the *worst* realized edge
   (down to −35.5). The dodge mechanism is laid bare: no drawdown ahead ⇒ pure
   relative drag.

2. **Even the deepest-DD tercile is realized-edge-negative (−7.79).** As at
   top-3000 2000-26 (max realized edge −0.31, all 38 negative), the honest
   realized-CAGR-vs-GSPC-price view never turns positive on a bull-heavy modern
   window. This is the expected signature of a winner-touching strategy on a
   bull tape (`project_index_beating_structural_bar`,
   `project_edge_is_the_fat_tail`): the edge is bear-regime drawdown avoidance,
   not bull-regime CAGR.

## What this confirms for the lever

The regime-gated-deploy thesis is now confirmation-grid-supported on the *causal
shape*: **deploy the strategy when forward drawdown is likely; prefer a SPY-timing
floor in melt-ups.** The 2011-26 post-COVID starts are the cleanest illustration —
deploying Cell-E into a smooth late-cycle bull (no DD to dodge) costs ~20pp of
realized edge versus simply holding the index.

**Caveat unchanged:** the deploy signal (forward index max-DD) is **ex-post**. A
*tradeable* regime proxy (macro gate state, breadth, index-vs-MA) must be
validated on its own before any regime-gated-deploy mechanism is built — this lens
establishes that the regime lever *exists and is robust*, not that a real-time
proxy can capture it. That proxy validation is the next research step.

## Provenance / reproducibility

- Scenario `/tmp/cell-e-top3000-2011-15y.sexp` (PIT `top-3000-2011` composition
  golden, window 2011-01-03 → 2026-04-30).
- Warehouse `/tmp/snap_top3000_2011_v2` (columnar mmap, 3015 symbols incl
  GSPC.INDX + sector ETFs).
- `rolling_start_eval --stride-days 255 --benchmark GSPC.INDX --parallel 2`,
  `SNAPSHOT_CACHE_MB=1024`.
- Pearson r / terciles computed from the per-start table (cols: realized edge %,
  forward index max-DD %, Stage-2 count). 22 starts, all benchmarked, none
  excluded.
