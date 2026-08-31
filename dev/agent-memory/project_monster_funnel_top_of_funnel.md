---
name: project-monster-funnel-top-of-funnel
description: "#2490 answered 08-24: 86% of >=100%-run monsters die at production-breakout-gate (46%) + top-N capacity (40%) BEFORE funding/stops; only 4/1686 episodes held >=13wk; RS gate drops zero monsters; capacity dial trades capture vs concentration law"
metadata: 
  node_type: memory
  type: project
  originSessionId: 41ec5d1b-6286-4c79-b63e-e9772f9eb5d9
  modified: 2026-08-24T18:08:33.313Z
---

Monster capture funnel (issue #2490, `monster_scan` PR #2519 over the split-safe
warehouse × instr-null artifacts, 26y top-3000, build 2b11c60dd):

- Monster set v2 — BOOK-FAITHFUL definition after qc-behavioral caught v1's
  volume basis (26wk×1.5 ≠ book's 4wk×2.0): close > 26wk high, vol ≥2.0× prior
  4wk mean, production Stage2; fwd 52wk run: **1,303 episodes ≥100%** (~50/yr),
  422 ≥200%. (v1: 1,686 with loose rule — superseded.)
- Funnel v2: surfaced 90.9% → **production breakout gate kills 51.0%** →
  **top-N capacity kills 36.4%** → grade 0 → admitted 3.5% → filled ~2% →
  **held ≥13wk 0.6% (8 episodes)**. ≥200% tier same shape. The breakout-gate
  share is now genuine production strictness (resistance-mapped E, volume
  bands, price floor, failed-breakout tolerance), not definitional mismatch.
- `Dropped_at_rs` = 0 — the RS gate passes monsters.
- Admitted→ticket is ALSO brutal: 61 of 66 admitted monsters got no ticket
  (entry-walk cash/caps; 24k Insufficient_cash skips).

**Transferable why:** funding (G2/G3) and stop levers operate below the leak —
almost no monsters survive to where those programs looked
([[project-funding-grid-monster-lottery]] "protect monster entries" must reach
ABOVE admission). The two real dials: (1) production breakout-gate strictness
(bundles definitional mismatch vs the reduced rule — needs per-drop sub-reason
in candidates.sexp to decompose, filed as the follow-up axis); (2) top-N
capacity — but ranking has no skill ([[project-entry-selection-closed-powered]])
so top-N survival is a lottery, and widening capacity collides with the
concentration law ([[project-record-gap-is-concentration]]). The funnel
quantifies that trade instead of sloganeering it.

Artifacts: `dev/experiments/instrumented-record-2026-08-23/results/monster-ep{100,200}-outcomes.tsv`
(+ README addendum 2, issue comment 08-24). Estimand = capture of ex-post
winners; NOT a tradable signal.

**08-25 update — the 51% bucket is now decomposable (#2533 / PR #2550):**
`Dropped_at_breakout` rows in candidates.sexp carry a sub-reason
(first-failing gate, a true partition): `Price_floor | Stage_setup |
Breakout_volume | Rs_declining | Failed_breakout | Volume_band`.
First liveness read (recovery-2023 smoke, NOT the 26y broad funnel —
direction only, not a verdict): 11,789 drops = **94% Stage_setup + 6%
Breakout_volume**, other four zero at no-op defaults — pointing at the
stage/entry-FRESHNESS clock, not volume confirmation. The real
decomposition needs the 26y instrumented regeneration (~4.5h,
run_chain.sh) against the record baseline — that run is the #2490
follow-up's next step.
