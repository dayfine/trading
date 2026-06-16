---
name: project_factor_lens_regime_governs_edge
description: "Factor-lens causal result — forward index drawdown (regime) governs the strategy's edge (r=-0.79); entry-supply (Stage-2 count) is inert (r=0.11). Deploy-when = regime-gating, not entry-selection."
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
