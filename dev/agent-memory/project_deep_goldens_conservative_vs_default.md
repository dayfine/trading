---
name: project_deep_goldens_conservative_vs_default
description: "Deep sp500 goldens are tuned more capacity-suppressing than production defaults (conc 0.14 vs 0.30, laggard hyst 2 vs 4); default beats base in both WF-CV surfaces → optimal-lens capacity gap is partly a basis artifact; re-pin + re-run lens"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6379af08-b68f-4dd7-8742-dff729a8b814
---

**UPDATE 2026-06-25 PM (user correction → BROAD re-run, the authoritative result):** the
SP500-515 surfaces were the WRONG basis (too narrow to exercise the capacity bottleneck).
Re-ran concentration on BROAD top-3000-2000 2000-2026 (warehouse snapshot, 13×2y folds):
**CLEAN interior optimum at 0.30 (= the production default)** — Sharpe 0.442→0.508→0.470,
CAGR 7.2→10.2→9.3% across {0.14,0.30,0.50}, monotonic up to 0.30 then 0.50 declines.
0.14→0.30 = **+3pp/yr CAGR**, robust 9/13 folds, and LOSES LESS in the worst folds.
Ledger **2026-06-25-capacity-concentration-broad = ACCEPT** (value 0.30). The SP500
knife-edge washout was a narrowness artifact; breadth shows the real signal. User
authorized promoting 0.30 by re-pinning scenarios. **Promotion = goldens re-pin (remove
the 0.14 override → 0.30), NOT a live flip** (default is already 0.30; production already
runs it) → the promotion-confirmation grid does not gate it. **⚠ NOT executed: data-store
provenance landmine** — the SAME golden, config unchanged, gives 23.5% (local data/ CSV)
vs 49.1% (warehouse) vs ≤30% band (CI test_data); different goldens are pinned vs different
stores, so re-pinning bands from the wrong store breaks main's postsubmit while user is AFK.
Re-pin procedure + scope (long-only regression goldens ONLY; NOT experiments/*, NOT
longshort, NOT catstop bases) in dev/notes/capacity-concentration-broad-2026-06-25.md.
NEXT P0: resolve which store each golden is pinned against (recommend warehouse), then
mechanical per-golden re-pin + verify. Below = the original SP500-basis finding, now
superseded-by-basis for the headline (stands as "SP500 too narrow to show the signal"):

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
