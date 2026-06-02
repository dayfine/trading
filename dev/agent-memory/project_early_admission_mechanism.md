---
name: project_early_admission_mechanism
description: Dual-MA early Stage-2 admission flag (PR
metadata: 
  node_type: memory
  type: project
  originSessionId: b9b9ed30-f921-4bfd-a0ea-792e77271fa4
---

**Mechanism (PR #1378, merged 2026-05-30, default-off):**
`Stage.config.early_admission_ma_period : int option [@sexp.default None]`. When
`Some p`, a fast SMA of period `p` (read self-contained from the `get_close`
callback — no panel/data plumbing) promotes Stage1→Stage2 early and *holds* on
the fast MA while it stays rising + price-above, deferring entirely to the slow
30-week MA otherwise (never blocks a real slow-MA Stage2, never forces an exit).
`None` = bit-identical no-op. Module: `analysis/weinstein/stage/lib/early_admission.{ml,mli}`
(`compute` + `apply`). Targets autopsy mode `late_stage2_admission` (+505%/100
trades): 30-week MA admits Stage 2 late off bear bottoms.

**Surface sweep (2026-05-30): INCONCLUSIVE.** `{5,7,10,13}` vs `None` baseline,
nominal 31-fold 2010-2026. Within-run it looked like an ACCEPT — every cell beat
baseline on Sharpe, baseline off the Pareto frontier, best cell **ma=10** Sharpe
0.414 vs baseline 0.251, MaxDD 6.79 vs 8.95, **DSR 0.9987** (best-of-4). **But
NOT promotable**: the run hit the GSPC-2017 data floor
([[project_gspc_index_golden_2017_floor]]) → folds 000-012 zero-trade →
effective window 2017-2026 only, gate diluted (15/31 wins = ~15/18 contested),
baseline non-reconciling. Recorded INCONCLUSIVE in the ledger
(`dev/experiments/_ledger/2026-05-30-early-admission-surface.sexp`); writeup
`dev/notes/early-admission-surface-2026-05-30.md`; PR #1379.

**RESOLVED 2026-05-31 — REJECTED for promotion; mechanism stays default-off.**
The thread: data floor fixed (#1383, GSPC golden→2009); re-run beat baseline on
2010-2026 + 2019-2023 → ACCEPT (ledger v2); a 4-context post-2009 grid (#1384)
found **ma=13** grid-robust (ma=10 overfit). Recommended ma=13... **THEN the 27y
deep test killed it.** On 2000-2026 (point-in-time-2000 universe incl. delistings
LEH/BS/YHOO, 51 folds spanning dot-com bust + GFC) baseline **DOMINATES every
early-admission variant** and is the only frontier cell; ma=13 per-fold win-rate
26/51 (~coin flip). The post-2009 edge was a **bull-regime artifact** — early
admission gets whipsawed in 2000-02 + 2008 where the slow 30-week MA is
protective. Ledger `2026-05-31-early-admission-deep-27y.sexp` (Reject); writeup
`dev/notes/early-admission-deep-2026-05-31.md`. **Do not revive the promotion.**
Lesson → [[project_promotion_confirmation_grid]] now requires a macro-regime
(deep/pre-2009) cell.

Universe-dependent character (the grid's key nuance): on SP500-class universes
the mechanism is a Sharpe/drawdown improver; on broad top-3000 it's a return
booster with HIGHER drawdown (Sharpe ≈ baseline there). Writeups:
`dev/notes/early-admission-surface-v2-2026-05-30.md`,
`dev/notes/early-admission-promotion-grid-2026-05-31.md` (PRs #1383, #1384).

The gap-closing loop + the new confirmation grid worked as designed: the
discipline caught both the data artifact AND the single-window overfit (ma=10)
that a naive ACCEPT would have promoted. Related:
[[project_experiment_platform]], [[project_promotion_confirmation_grid]],
[[feedback_strategy_mechanic_changes_too_explorative]].
