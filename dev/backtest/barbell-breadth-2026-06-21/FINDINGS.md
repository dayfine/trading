# Barbell breadth-confirmation — FINDINGS (2026-06-21)

**P0 gate #1** from `next-session-priorities-2026-06-21.md`: the 2026-06-20
barbell grid promoted 70/30, but its universe-diversity leg was thin (3/4 cells
shared SP500 PIT-2000). This re-runs the ENGINE leg on genuinely broader
universes — same window (2000-26) and same floor (`floor-2000-deep`) as grid
cell A — to test whether the **70/30 weight transfers to breadth**.

Two breadth cells: **top-1000 PIT-2000** (~2× SP500-515; the engine's documented
*trough* universe) and **top-3000 PIT-2000** (~6× breadth; the engine's
documented *strong-edge* universe — `project_deep_1998_2026_contiguous`). Both
snapshot mode (CSV OOMs ≥1000), cache=1024, current code, 5bps-spread cost model
(matches grid cells A-D). Floor reused from `scenarios-2026-06-20-235722`.

## Engine-leg standalone (pure w=0) by universe — the headline

| universe (2000-26) | ret% | Sharpe | MaxDD% | Calmar | trades |
|---|---|---|---|---|---|
| SP500-515 (grid cell A) | 1570 | 0.80 | 36.8 | 0.296 | 988 |
| **top-1000** | **58** | **0.19** | **54.3** | **0.031** | 911 |
| **top-3000** | **332** | **0.47** | **43.3** | **0.128** | 667 |
| floor (SPY-only) | 387 | 0.58 | 18.8 | 0.319 | — |

**The top-1000 engine collapses** (58%/54%DD/0.19 Sharpe) — far below both SP500
and the floor itself. This reproduces the known `project_factor_lens` finding
("top-3000 beats, top-1000 trails"): top-1000 is the engine's worst universe —
too broad for SP500 mega-cap quality, too narrow to hold the small-cap fat-tail
monsters that carry the top-3000 return. It is NOT a clean breadth test of the
weight; it is a test at the engine's trough.

## Blend surface — top-1000 cell (floor = floor-2000-deep)

| w_floor | ret% | Sharpe | MaxDD% | Calmar | Ulcer% |
|---|---|---|---|---|---|
| 0.00 (pure engine) | 58.4 | 0.188 | 54.3 | 0.031 | 27.97 |
| 0.50 | 197.3 | 0.421 | 30.6 | 0.134 | 11.56 |
| 0.60 | 231.8 | 0.468 | 26.3 | 0.172 | 9.50 |
| 0.70 | 268.2 | 0.509 | 21.9 | 0.225 | 8.15 |
| 0.80 | 306.4 | 0.542 | 18.5 | 0.286 | 7.80 |
| 1.00 (pure floor) | 386.9 | 0.575 | 18.8 | **0.319** | 8.08 |

**Calmar and Sharpe rise MONOTONICALLY to pure floor.** At top-1000 the
risk-adjusted optimum is **max-floor (w=1.0)**, not 70/30. 70/30 (Calmar 0.225)
still beats pure-engine (0.031) — the grid rule's "blend beats baseline" survives
— but it leaves a lot on the table vs pure floor (0.319).

### What top-1000 teaches (transferable)

The barbell's **optimal weight is engine-quality-dependent**, and engine quality
is **universe-dependent**. Where the engine has edge (SP500 cells A-D: per-cell
optimum 0.5-0.7, 70/30 robust), the blend's value is genuine diversification.
Where the engine is weak (top-1000), the "blend" degenerates into "lean on the
floor" — the floor isn't diversifying the engine, it's *replacing* it. So a
single fixed 70/30 is NOT universally optimal across breadth; it is the robust
compromise **conditional on the engine being deployed in a universe where it has
edge** (SP500 or top-3000, per the factor-lens). Practical implication: the
deployable barbell should pair the floor with the engine **on a universe where
the engine earns its keep** (top-3000 / SP500), not top-1000.

## Blend surface — top-3000 cell (floor = floor-2000-deep) — the definitive test

| w_floor | ret% | Sharpe | MaxDD% | Calmar | Ulcer% |
|---|---|---|---|---|---|
| 0.00 (pure engine) | 331.9 | 0.471 | 43.3 | 0.128 | 17.88 |
| 0.50 | 392.3 | 0.643 | 21.5 | 0.281 | 7.42 |
| 0.60 | 396.8 | **0.655** | 20.5 | 0.296 | 6.74 |
| **0.70** | 398.6 | 0.652 | 19.5 | 0.311 | 6.39 |
| 0.80 | 397.6 | 0.636 | 18.6 | **0.327** | 6.27 |
| 1.00 (pure floor) | 386.9 | 0.575 | 18.8 | 0.319 | 8.08 |

**Blending clearly helps in the engine's real breadth universe.** Pure engine
(Calmar 0.128 / Sharpe 0.471 / 43% DD) is poor; every blend dominates it. The
Calmar-optimum is **w=0.80 (0.327)**, the Sharpe-optimum **w=0.60 (0.655)**, and
**70/30 sits in the optimal region** — Sharpe 0.652 (≈peak) and Calmar 0.311
(within 5% of the 0.80 peak), beating pure-floor on Sharpe (0.652 > 0.575). The
return is nearly flat across w=0.5-0.8 (392-399%) — the blend buys a large DD
reduction (43%→18-20%) at almost no return cost. This is the genuine
diversification signature, reproduced at 6× SP500 breadth.

## Verdict — BREADTH TRANSFER CONFIRMED (where the engine has edge)

**70/30 beats the pure-engine baseline on Calmar in EVERY cell tested** —
SP500-515 0.437>0.296, top-1000 0.225>0.031, top-3000 0.311>0.128 — so the
"barbell helps" claim transfers to breadth unconditionally.

**The optimal WEIGHT transfers too, conditional on engine edge.** Across the
engine's edge universes the Calmar/Sharpe optimum lives in **w ∈ [0.6, 0.8]**:
SP500 cell A peaks at 0.70, top-3000 at 0.60 (Sharpe) / 0.80 (Calmar). **70/30 is
the robust central pick of that band** — exactly the grid's promoted weight, now
confirmed at 6× breadth. (A marginally higher 0.75-0.80 maximizes top-3000
Calmar, at a small Sharpe cost; 70/30 is the conservative-return end of the band.)

**The one exception is diagnostic, not disconfirming:** at top-1000 — the engine's
documented trough — the optimum collapses to pure-floor because the engine has no
edge to diversify. The lesson is therefore precise: **deploy the barbell with the
engine on a universe where it earns its keep (SP500 or top-3000), at floor-weight
~0.70-0.80.** Never run the engine leg on top-1000.

This **closes P0 gate #1** (`next-session-priorities-2026-06-21.md`): the 70/30
weight is confirmed robust across period (grid A/B/D) AND genuine breadth (top-3000,
6× SP500). Remaining gate: **#2 build the deployable rebalanced overlay** behind a
default-off flag.

## Caveats
- Absolute engine returns are MTM-inclusive and confounded by start-date /
  survivorship across universes (`project_broad_universe_790_mtm_inflated`); the
  blend reads `portfolio_value` so MTM flows through. The *weight-surface shape*
  (where Calmar/Sharpe peak) is the robust signal, not the absolute returns.
- top-1000 (58%) and top-3000 (332%) both undershoot the SP500-515 cell (1570%)
  and the deep-1998 contiguous baseline (+1552% realized) — the 2000 start (near
  the dotcom peak) plus PIT small-cap bar-coverage thinness early both depress the
  broad cells vs an SP500 mega-cap basis. Does not affect the weight-surface
  conclusion (each cell is internally consistent: same floor, same window).
