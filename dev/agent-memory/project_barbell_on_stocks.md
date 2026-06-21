---
name: project-barbell-on-stocks
description: Barbell (SPY-timing floor + Cell-E stock-selection engine) NAV blend dominates both legs on Calmar; 70/30 regime-robust. 2026-06-20 PROMOTION GRID PASSED — first lever to clear a grid; 70/30 beats pure-engine Calmar 3/4 cells, highest worst-cell Calmar+Sharpe. Genuine diversification (DD falls faster than return), does NOT tax the fat tail.
metadata: 
  node_type: memory
  type: project
  originSessionId: ca50bd58-52e8-4bfa-b1b2-6e777091a945
---

P0 of the 2026-06-03 arc, DONE 2026-06-02 (PRs #1434/#1435). Post-hoc
constant-weight daily-return NAV blend of two legs, both re-run fresh on deep
(2000-2026) and bull (2010-2026): FLOOR = `Spy_only_weinstein` SPY 30wk
long/flat (index-timing); ENGINE = full Cell E production strategy on clean PIT
S&P 500 (`universes/sp500-historical/sp500-2000-01-01.sexp`).

**Result — the barbell strictly dominates BOTH pure legs on Calmar in BOTH
regimes; diversification pushes blended DD *below the floor leg itself*.**

| | pure floor | 70/30 | pure engine |
|---|---|---|---|
| deep 2000-26 | 387%/18.8%/0.32 | **534%/17.8%/0.39** | 918%/37.3%/0.24 |
| bull 2010-26 | 239%/18.8%/0.40 | **247%/16.4%/0.47** | 238%/17.5%/0.43 |

- Deep: return trades monotonically for DD; Calmar-max at defensive **80/20**
  (0.414, DD 16.2% < floor's 18.8%). Bull: legs ~equal return → blend is pure DD
  reduction; Calmar-max at **50/50** (0.479). **70/30 beats both pure legs in
  each regime → regime-robust.** Matches ETF-lab barbell's 70/30 (#1426).
- 70/30 ≈ raw BAH-SPY return at HALF the drawdown.
- Deep engine reproduced doc's 918%/37.3%/0.25 exactly; bull engine 237.6%.

**Why:** resolves the 918%-vs-DD tension — you trade return for DD along the
frontier but never pick between the two pure strategies. The mandate picks the
point (drawdown-defense → 80/20; return-respecting-risk → 70/30).

Tool: `/tmp/blendw.awk` (`awk -v w=<floor-weight> -f blendw.awk floor.csv engine.csv`).
Writeup: `dev/notes/barbell-on-stocks-2026-06-02.md`. Extends
[[project_sector_rotation_layer_attribution]] (ETF lab) onto individual stocks;
relates to [[project_cell_e_2020_stall_regime]] (breadth is the lever for the
engine leg). Next: few-feature carrier as a better engine leg (lighter machinery
→ engine return at lower DD?).

## 2026-06-20 PM — PROMOTION GRID PASSED (70/30 robust)

Took the barbell to a `promotion-confirmation.md` grid. 4 engine cells (SPY-only
floor per window), all current-code CSV mode: A=2000-26 SP500-2000 (full,
bear-macro), B=2010-26 SP500-2000 (bull), C=2010-26 SP500-**2010** (diff
composition), D=2000-2010 SP500-2000 (bear decade). Sweep floor-weight
{0,.5,.6,.7,.8,1}. Record: `dev/backtest/barbell-grid-2026-06-20/FINDINGS.md`,
blend tool `blend.awk`, outputs `dev/backtest/scenarios-2026-06-20-235722/`.

**Calmar by w_floor (min-cell in []):** .50→[.369] .60→[.398] **.70→[.413]**
.80→[.407]. 70/30 = highest worst-cell Calmar AND Sharpe (.699); beats
pure-engine Calmar in 3/4 (A .437>.296, B .451>.303, C .457>.403), loses only
narrowly in D (.413<.435). Per-cell winners DISAGREE (.70/.60/.50/.00) → single-
window winner not promotable; 70/30 is the robust pick. **PROMOTE 70/30.**

**Why real (transferable):** genuine diversification, not less-risk. Cell A
annret −30% but MaxDD −53% (imperfectly-correlated legs) → Calmar UP. Barbell
does NOT touch the fat tail (engine winners run fully in the engine leg; floor
only reweights capital) — this is why it PASSES where 8 `edge_is_the_fat_tail`
tail-touching levers were rejected. Confirms the diversification-layer guardrail.

**Regime nuance:** benefit concentrates in bull/mixed (B,C: Sharpe+Calmar up) +
high-DD full window (A); VANISHES in the isolated bear decade D, where the
engine's own stage3-exit+laggard machinery already gives Sharpe 1.01 — barbell &
internal crash-defense are partial substitutes.

**Two gates before live capital (next-session-priorities-2026-06-21.md P0):**
(1) one BREADTH cell (top-1000/3000 deep) re-blended at 70/30 — grid's
universe-diversity leg is thin (3/4 cells same SP500-2000; C is a snapshot
variant not a breadth jump); needs rebuilt snapshot warehouse (/tmp cleared).
(2) build the barbell as deployable rebalanced overlay behind a default-off flag
(`experiment-flag-discipline.md`) — today's blend is post-hoc, no `enable_barbell`
config exists. The 70/30 ACCEPT from this grid satisfies R3's prerequisite.

NB absolute engine returns drifted up vs 06-02 (cell A 1570% vs doc 918%) —
current code carries 18d of fixes (#1481/#1556/#1487); MaxDD reproduced
(36.8 vs 37.3). Grid is internally valid; don't compare absolutes to the old doc.

## 2026-06-21 — BREADTH gate CLOSED (70/30 confirmed at 6× breadth)

P0 gate #1 (next-session-priorities-2026-06-21). Re-ran the ENGINE leg on
broader universes, 2000-26, vs the same `floor-2000-deep`:
`dev/backtest/barbell-breadth-2026-06-21/FINDINGS.md`. Engine standalone by
universe (pure w=0): SP500-515 1570%/.296-Calmar · top-1000 58%/.031 · top-3000
332%/.128 · floor 387%/.319.

**70/30 beats pure-engine Calmar in EVERY cell** (SP500 .437, top-1000 .225,
top-3000 .311). In the engine's real breadth universe **top-3000** the
Calmar/Sharpe optimum is **w∈[0.6,0.8]** and **70/30 is the robust central pick**
(Sharpe .652 ≈ peak; Calmar .311 within 5% of the .80 peak; blend cuts DD
43%→19% at ~flat return = the diversification signature at 6× breadth). 70/30 is
the conservative-return end of the band; .75-.80 maxes top-3000 Calmar.

**The barbell's optimal weight tracks ENGINE QUALITY, which is universe-dependent**
— diagnostic exception at **top-1000** (the engine's documented trough,
[[project_factor_lens_regime_governs_edge]] "top-3000 beats, top-1000 trails"):
the optimum collapses to PURE-FLOOR because the engine has no edge to diversify.
Lesson: **deploy the barbell with the engine on an edge universe (SP500/top-3000)
at floor-weight ~.70-.80; never run the engine leg on top-1000.**

Only gate #2 remains before live: build the deployable rebalanced overlay behind
a default-off flag. Caveat: broad-cell absolute returns are MTM-inclusive +
start-date/survivorship-confounded; the weight-SURFACE SHAPE (where Calmar/Sharpe
peak) is the robust signal, each cell internally consistent (same floor/window).
