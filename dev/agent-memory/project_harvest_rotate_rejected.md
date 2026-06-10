---
name: project_harvest_rotate_rejected
description: Harvest-and-rotate (allocate capital by forward expected return) REJECTED at read-only validation 2026-06-10 — forward return does not decay with maturity/extension
metadata: 
  node_type: memory
  type: project
  originSessionId: ef5f87b6-2ba9-4ab1-870c-61358d4e71b7
---

**Harvest-and-rotate thesis REJECTED at validation (2026-06-10), no build.** The
P0 from `next-session-priorities-2026-06-10-PM`: trim a mature/extended Stage-2
winner to fund a cash-blocked fresh early-S2 candidate (AAPL-dividend logic —
return capital when its forward IRR drops below the alternative). Validated
read-only on the Cell-E **top-3000** baseline run (scenarios-2026-06-10-184414,
761%/650 trades) BEFORE building, per the discipline that saved the cascade-reweight.

Both required preconditions FAIL decisively:
- **(a) forward-return decay — FALSE.** fwd-4w return (adj_close; median; winsor)
  is flat-to-*rising* with both extension above the 150d MA (most-extended >50%
  bucket highest median +1.49%) and weeks-since-entry (wk27-52 highest +1.79%).
  Fresh early-S2 median +0.38% vs **mature-extended +1.44%** — mature earns MORE.
- **(b) opportunity cost — REVERSED.** Best cash-blocked skipped candidate fwd-4w
  +0.37% vs the most-extended held position (the harvest target) **+2.16%** (~6×);
  win-rate ~50%. Rotating capital out of the extended winner DESTROYS value.

The "declining forward rate" premise is simply false: a still-advancing Stage-2
winner's forward rate does not decline. This is let-winners-run / momentum showing
up directly, and is consistent with [[project_cascade_selection_inversion]] (the
breakout earns the fat tail) + the entry-cap probe (concentration IS the return).

**Consequences:** drop the harvest-rotate dial AND the P1 partial-exit core change
(only needed to fund it). The whole concentration-TRIM direction
(`concentration-rebalance-2026-06-10.md`) is on the same dead end — trimming an
extended winner moves capital to a lower-forward-return use. Only residual reason
to bound single-name NAV% is unrealised-mark/tail-RISK
([[project_broad_universe_790_mtm_inflated]]), a risk argument, and prior risk-cap
probes were already strictly dominated. Full record:
`dev/experiments/harvest-rotate-validation-2026-06-10/` (README + scripts + data).

**Harness gap noted:** `Trade_audit.exit_decision.max_favorable_excursion_pct` (and
`max_adverse_excursion_pct`) are **always 0** in every recent run — the simulator
step-stream never populates them. Killed the audit-only give-back proxy; had to
compute forward returns from bars instead. Worth fixing if MFE/MAE-based analysis
is wanted later.
