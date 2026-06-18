---
name: project_factor_lens_regime_governs_edge
description: "Factor-lens causal result — forward index drawdown (regime) governs the strategy's edge (r=-0.79 t1k, -0.74 t3k, -0.89 t3k-2011-bull-cell; CONFIRMATION-GRID ROBUST across universe AND macro regime); entry-supply inert. Breadth flips MTM beat-rate +8%→60% but realized edge stays negative every start. Deploy-when = regime-gating, not entry-selection."
metadata: 
  node_type: memory
  type: project
  originSessionId: b7df10ed-d46a-4d6b-a9b7-31437a8b7311
---

The factor-decomposition lens (H1/H2/H3) was run on the **top-1000 2000-2026**
rolling-start matrix (38 starts, #1607 factor columns; the in-container stand-in
for the OOM-blocked top-3000 — see [[project_panel_runner_memory_ceiling]]).
Writeup: `dev/experiments/rolling-start-matrix-t1k-2000-2026/ANALYSIS.md` (#1620).

**Result (n=36, Pearson on realized edge):**
- **H1 dodge-correction: SUPPORTED (strong).** `realized_edge ~ forward_index_max_DD
  r = -0.79` (fdd is negative → deeper drawdown ahead = higher edge). Monotonic
  terciles: deepest-DD third -4.98, mid -9.65, shallowest (recent smooth bull) -15.01.
- **H2 melt-up tax: SUPPORTED** (the flip side — smooth-bull starts lag hardest).
- **H3 fresh-supply: NOT supported.** Stage-2 candidate count `r = +0.11`. Entry-
  supply does not predict edge. **Third independent re-derivation of
  [[project_accuracy_is_unreachable_diversify_instead]]** — regime is the lever,
  entry-selection/supply-timing is a dead end.
- MTM edge ~ fdd `r = +0.09` (vs realized -0.79): the MTM edge is noise (recent
  open-position marks); **realized edge is the only honest measure** here.

**Deploy-when guidance:** the strategy is drawdown insurance — deploy it (vs a
SPY-timing floor) when a correction/bear is likely (it dodges the drop → relative
edge); prefer the floor in melt-ups. Regime, not entry quality, decides. Next
lever = a **regime-gated deploy rule**, NOT another entry knob. Caveat: the deploy
signal (forward DD) is ex-post here; a *tradeable* proxy (macro gate / breadth)
needs its own validation.

**TOP-3000 CONFIRMATION (2026-06-17, #after-S4; matrix unblocked by format-v2).**
Ran the same lens on the **top-3000 2000-2026** matrix (38 starts, GSPC.INDX,
stride 255, over the v2 mmap warehouse). Writeup:
`dev/experiments/rolling-start-matrix-t3k-2000-2026/ANALYSIS.md`.
- **H1 REPLICATES across breadth:** `realized_edge ~ fwd_index_maxDD r = -0.744`
  (t1k -0.79); terciles **-4.21 / -6.46 / -16.39** monotonic. The regime-shape is
  universe-robust — the solid, transferable result.
- **Net-edge sign answered (it's metric-dependent):** MTM edge flips POSITIVE
  (median **+1.93%, 60.5% of starts beat** GSPC, vs t1k -5.45% / 8.3%) — breadth
  delivers the fat-tail winners. BUT **realized edge stays negative in ALL 38
  starts** (median -5.82 vs t1k -8.90, mean -9.41, **max -0.31**). Breadth
  compresses the realized lag + flips the beat-rate, does NOT flip the realized
  sign. The +edge is still-open fat-tail winners ([[project_edge_is_the_fat_tail]],
  [[project_broad_universe_790_mtm_inflated]]). Median MaxDD 44.6% (vs 34.4% t1k —
  more volatile).
- **H3 r=+0.44** (vs t1k +0.11) but confounded with regime (Stage-2 count tracks
  macro) — NOT clean support. H1 remains the only lever. **4th re-derivation of
  [[project_accuracy_is_unreachable_diversify_instead]].**

**MACRO-REGIME CONFIRMATION CELL (2026-06-17, #1642; promotion-confirmation grid).**
Ran the lens on the **top-3000 2011-2026** matrix (22 starts, bull-dominated — only
deep forward DD is COVID-2020; the contrast to the bear-inclusive 2000-26 cell).
Writeup: `dev/experiments/rolling-start-matrix-t3k-2011-2026/ANALYSIS.md`.
- **H1 REPLICATES AND STRENGTHENS:** `realized_edge ~ fwd_index_maxDD r = -0.892`
  (strongest of the 3 cells: t1k -0.79, t3k-2000 -0.744, t3k-2011 **-0.892**).
  Terciles monotonic **-7.79 / -8.61 / -23.40** — post-COVID smooth-bull starts
  (nothing to dodge) carry the worst realized edge. The dodge mechanism laid bare:
  no forward DD ⇒ pure relative drag (~-20pp).
- H3 r=+0.43 (≈ t3k-2000's +0.44) — same regime-confound, NOT clean. **5th
  re-derivation** that regime is the lever, entry-selection inert.
- Realized edge negative in all 22 starts (even deepest tercile -7.79), median
  -10.58 (worse than 2000-26's -5.82 — less DD to dodge). MTM median -2.63 / 45.5%
  beat (vs 2000-26 +1.93 / 60.5%).
- **The regime lever is now confirmation-grid-supported on the CAUSAL SHAPE** across
  universe breadth (t1k/t3k) AND macro regime (bear-incl/bull-dom). Next step is
  unchanged: validate a *tradeable* regime proxy (the deploy signal fwd-DD is ex-post).

**4th/FINAL CELL — grid CLOSED (2026-06-18, #1645).** top-3000 **1998-2026** (41
starts, deepest window; early starts face dot-com+GFC ahead, fwd DD to −56.78%).
Writeup `dev/experiments/rolling-start-matrix-t3k-1998-2026/ANALYSIS.md`.
- H1 r = **−0.820**; terciles **−3.52 / −8.45 / −16.45** monotonic.
- **FIRST positive realized edge anywhere:** 1998-01-01 **+1.20%**, 1999-05-26
  **+0.46%** — exactly the two deepest-fwd-DD starts. Reproduces+explains the
  deep-contiguous beat ([[project_deep_1998_2026_contiguous]]). The relationship
  CROSSES ZERO: deep enough drawdown ahead ⇒ realized edge positive.
- **4-cell grid: H1 r ∈ {−0.74, −0.79, −0.82, −0.89}**, monotonic terciles every
  cell, across 2 universes + full macro span. **GRID CLOSED — regime governs the
  edge, universe- AND macro-regime-robust.** The edge is a drawdown-AVOIDANCE
  instrument (positive only when there's a deep drop to dodge; relative drag
  otherwise). Deploy-timing on the signal = DEAD (ex-post; = SPY market-timing,
  [[project_next_lever_decision_grading]]). Next lever = the decision-grading lens,
  NOT more top-level grids.

**Load-bearing caveats:**
1. **Realized edge is ALL-NEGATIVE on top-1000** — even the deepest-DD third
   averages -4.98. H1 *compresses* the underperformance + halves drawdown (MaxDD
   ~34% vs index -57%), it does NOT flip it to outperformance.
2. **Breadth matters — top-1000 is too thin.** The 28y **top-3000** deep run BEAT
   on realized (+1552% vs +599%, [[project_deep_1998_2026_contiguous]]); top-1000
   trails everywhere. The net-edge *sign* needs the top-3000 fat-tail winners
   ([[project_edge_is_the_fat_tail]]). The lens establishes the regime-conditioning
   *shape*, not the net-edge sign for top-3000.
3. Confounds inflate r=-0.79: forward-DD correlates with calendar era + recent
   starts are under-realized (open positions). Directional, not a clean causal
   estimate. Cleanest read = early fully-realized deep-DD starts (2000-2007:
   realized edge -2 to -7, MaxDD ~35% vs index -57%).
4. Benchmark GSPC.INDX is price-only (no dividends) → flatters edge ~2pp/yr.
