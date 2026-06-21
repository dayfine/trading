---
name: project_edge_is_the_fat_tail
description: Cross-experiment meta-insight — the broad-universe strategy edge IS the let-winners-run fat right tail; winner-touching mechanisms (trim/rotate/re-time/cap) systematically tax it and get rejected. Bias search to tail-PRESERVING levers.
metadata: 
  node_type: memory
  type: project
  originSessionId: ef5f87b6-2ba9-4ab1-870c-61358d4e71b7
---

**The strategy's edge is the let-winners-run fat right tail — and that explains a
whole class of rejections.** Not a single experiment; the *generalisation* of
several, surfaced as the standing guidance for future search (the "explain WHY to
guide later work" principle, `.claude/rules/mechanism-validation-rigor.md`).

**The pattern.** On the broad (top-3000) universe the realised return is dominated
by a few right-tail monsters (AXTI 36×, etc.) ridden through a long Stage-2 advance.
Independent findings keep re-deriving this from different angles:

- **Cascade-selection inversion** — the confirmed breakout (lower win-rate) earns
  the **fat tail**; the breakout premium IS the return, not a scoring error.
  ([[project_cascade_selection_inversion]])
- **Entry-cap probe** — shrinking the entry cap 0.14→0.07 cut return ~6× for ~5pp
  MaxDD: **concentration IS the return; the monsters need size.**
- **Harvest-rotate — WF-CV REJECTED** (2026-06-11, built + tested as a surface):
  trimming `Stage2{late}` winners + recycling is **dispersion-amplifying noise**
  (best variant Sharpe 0.627 ≈ baseline 0.645; return σ 37 vs 22.6), with the
  gate-killers being folds where baseline rode winners to high Sharpe and harvest
  trimmed them (the structural tax). All `harvest_fraction` fail.
  ([[project_harvest_rotate_rejected]])

**The mechanism of failure (the transferable why).** Any mechanism that **touches
winners** — trims, rotates out of, re-times, or caps a still-advancing Stage-2
position — *taxes the right tail*, because the tail is exactly the positions those
mechanisms act on. Since the edge lives in that tail, the expected effect is
negative-or-neutral, which is what the WF-CV rejections (laggard, force-exit,
stage2-ma-hold, late-flag stop-tighten, macro-bearish-trim, and now harvest-rotate)
keep showing. This is **structural, not a tuning failure** — no knob value rescues a
lever whose action is "tax the source of the edge."

**Forward guidance (what this rules in/out):**
- **AWAY from** winner-touching levers: profit-trims, concentration caps,
  harvest/rotate, winner re-timing, anything that recycles a still-advancing
  position on a return argument. Revive only as explicit **tail-RISK insurance**
  (capital-relative DD / Ulcer objective, `project_broad_universe_790_mtm_inflated`)
  — never as a return improvement.
- **TOWARD tail-PRESERVING levers:** universe **breadth** (more shots at a monster),
  **entry quality / quantity** (catch more of the tail-makers earlier without
  abandoning them), and **holding discipline** (don't exit early). The barbell
  finding ([[project_barbell_on_stocks]]) fits: pair a DD-defensive floor with the
  tail-bearing engine rather than clipping the engine's tail.
- When a new mechanism is proposed, first ask: *does it touch winners?* If yes, the
  prior is strongly negative and the burden is to show it does NOT tax the tail
  (the decomposition in `dev/plans/harvest-rotate-rigorous-test-2026-06-10.md`:
  timing vs picks vs structural-tax vs cost).

## 2026-06-21 — MA-period dial (30→10wk) = MTM/capacity mirage, NOT an edge
Probed Weinstein's faithful 10wk trader MA to fix the engine's 2009-26 bull-lag
(+130% vs S&P +631%). 10wk FULL 1998-26 = +25,602% (vs 30wk +1100%), bull +4207%
(vs +130%) — looks like it crushes the lag, BUT Sharpe COLLAPSED 0.54→0.21; ONE
trade realized +$209M, open positions $195M of $257M NAV (76%). Pure
fat-tail-compounding/capacity mirage (capacity-infeasible position sizes), amplified
by faster MA catching more monsters. NO-BUILD. Lesson: MA period is the most
impactful dial but faster≠better — any lever that works by catching MORE fat-tail
names hits the capacity wall; the realistic edge is capacity-bounded, not MA-bounded.
The 30wk bull-lag is partly the PRICE of a capacity-realistic book. Bull-lag is
STRUCTURAL; address via barbell floor (capacity-safe), not faster MA. Record:
`dev/backtest/engine-edge-1998-2026/PHASE-C-ma-period.md` (#TBD).
