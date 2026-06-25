---
name: project_deep_goldens_conservative_vs_default
description: "Deep sp500 goldens are tuned more capacity-suppressing than production defaults (conc 0.14 vs 0.30, laggard hyst 2 vs 4); default beats base in both WF-CV surfaces → optimal-lens capacity gap is partly a basis artifact; re-pin + re-run lens"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6379af08-b68f-4dd7-8742-dff729a8b814
---

2026-06-25 cross-cutting finding from two WF-CV capacity surfaces (concentration +
laggard cadence, deep 2000-2026 sp500-PIT, 26 folds). **The deep-golden research
basis is tuned MORE capacity-suppressing than the canonical production defaults, and
in BOTH surfaces the default beats the deep-base value:**

| lever | deep-golden base | canonical default | winner |
|---|---|---|---|
| max_position_pct_long (concentration) | 0.14 | 0.30 | default (Sharpe 0.64 vs 0.56) |
| laggard hysteresis_weeks (turnover) | 2 | 4 | default (Sharpe 0.63 vs 0.56) |

Deep goldens cap positions tighter (0.14 → more, smaller slots) AND churn faster
(rotate after 2 neg-RS weeks vs 4) than production → both suppress how much capital
reaches each cascade-identified winner = exactly the `Insufficient_cash` symptom the
optimal-strategy lens diagnosed.

**Why it matters:** the optimal-lens "capacity gap" (misses are Insufficient_cash,
winners unfunded; see project handoff) was measured ON the deep-golden basis, so it
PARTLY OVERSTATES the gap in the production config (0.30 / hyst-4, which the lens never
tested). The gap isn't fake, but the honest next step is to measure it on a basis that
matches production.

**Recommended next P0 (needs user oversight — re-pins golden expected metrics):**
re-pin the deep LONG-ONLY goldens max_position_pct_long 0.14→0.30 + laggard
hysteresis_weeks 2→4 (catstop, 1998-2026, 2010-2026; NB long-only catstop has
enable_short_side=false so 0.14's short-diversification rationale doesn't apply —
longshort goldens may keep 0.14/2, re-pin separately if at all), run through the
confirmation grid, then RE-RUN the optimal lens on the corrected basis; the
Insufficient_cash miss rate should shrink. Only then judge whether more capacity
levers (max_positions count cap = planned lever 3) are worth surfacing.

Both individual lever verdicts INCONCLUSIVE/no-promote — see
[[project_capacity_concentration_surface]] (knife-edge overfit, return-for-DD) and the
laggard-cadence-surface ledger (weak/noisy/non-monotonic). Both confirm
[[project_edge_is_the_fat_tail]]: capacity levers amplify the tail lumpily, no free
Sharpe. Ledgers: 2026-06-25-capacity-concentration-surface +
2026-06-25-laggard-cadence-surface. Note:
dev/notes/capacity-levers-deep-basis-recalibration-2026-06-25.md.
[[project_experiment_platform]]
