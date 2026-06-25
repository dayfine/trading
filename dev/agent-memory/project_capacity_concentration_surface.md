---
name: project_capacity_concentration_surface
description: "Concentration (max_position_pct_long) WF-CV surface — real lever but return-for-DD tradeoff, no promotable value; 0.25 spike was overfit; max_long_exposure_pct inert"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6379af08-b68f-4dd7-8742-dff729a8b814
---

2026-06-25, first P1 **capacity** lever from the optimal-lens pivot (misses are
`Insufficient_cash`, not bad picks → fund the cascade-identified winners).
WF-CV deep 2000-2026 sp500-PIT, 26 folds, swept `max_position_pct_long`
{0.14,0.20,0.25,0.30,0.35,0.40} (base/goldens pinned 0.14; canonical default 0.30).

**Verdict INCONCLUSIVE / no-promote.** The mechanism is REAL+live (every cap >0.14
amplifies the fat tail: return 9.3→10-17%, Calmar 1.03→1.13-2.08) BUT it is a
**return-for-DD/dispersion tradeoff** — MaxDD 9.95→12.4, return-σ 12.6→27 rise in
lockstep; Sharpe gain modest+noisy (0.562→~0.57-0.65) outside a knife-edge spike at
exactly 0.25 (Sharpe 0.858, far above BOTH neighbors 0.20=0.572 / 0.30=0.643).
**The 0.25 spike is path-dependent overfit, not a peak:** fold-000 return
non-monotonic across cap — 52%(0.14)→131%(0.25)→97%(0.30); a higher cap funds the
monster LESS at 0.30 than 0.25 (path-dependent funding order). Textbook single-point
overfit the loop exists to catch → not promotable. No default flip; default 0.30
already in the favorable region, stays.

**Secondary:** `max_long_exposure_pct` {0.70,0.90} is **INERT** (bit-identical every
level) — the per-position cap is the SOLE binding constraint, the aggregate long
ceiling never binds. Drop it from capacity surfaces.

**Process gotcha:** the per-variant `Fold_gate` (`worst_delta=0.0`, copied from a
tail-risk-insurance spec) FAILs every cell and is MIS-SPECIFIED for a
return-amplifying lever (concentration necessarily makes some folds worse while
winning on aggregate). Read Pareto+win-rate+the full curve, not the strict gate.
Future return-amplifier surfaces: use a return/Calmar gate or `worst_delta`>0.

**Why it matters / forward guidance:** confirms [[project_edge_is_the_fat_tail]] from
a new angle — concentration is the RIGHT lever *class* (tail-amplifying, not
winner-touching) and it DOES amplify, but lumpily/knife-edge so it hands over no free
Sharpe (the tail it concentrates into is unpredictable). Narrows the remaining P1
capacity search away from size-cap tuning toward **turnover/laggard-rotation cadence**
(the churn is what exhausts cash; 280 churned trades in the optimal lens) and
**`max_positions`** (count cap vs size cap). Deep long-only goldens at 0.14 are mildly
conservative; re-pin to 0.30 only as a deliberate match-default Pareto choice (needs
the confirmation grid), NOT an alpha claim — and 0.14's short-diversification rationale
doesn't even apply to the long-only base (`enable_short_side=false`).
Ledger: 2026-06-25-capacity-concentration-surface. Note:
dev/notes/capacity-concentration-surface-2026-06-25.md. [[project_experiment_platform]]
