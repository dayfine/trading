---
name: project_harvest_rotate_rejected
description: Harvest-and-rotate (allocate capital by forward expected return) — read-only screen 2026-06-10 found no exploitable per-decision edge; NO-BUILD decision (not a rigorous rejection)
metadata:
  node_type: memory
  type: project
  originSessionId: ef5f87b6-2ba9-4ab1-870c-61358d4e71b7
---

**Harvest-and-rotate: NO-BUILD decision (2026-06-10).** The P0 from
`next-session-priorities-2026-06-10-PM`: trim a mature/extended Stage-2 winner to
fund a cash-blocked fresh early-S2 candidate (AAPL-dividend logic). Screened
read-only on the Cell-E **top-3000** baseline (scenarios-2026-06-10-184414,
761%/650 trades) BEFORE building.

**⚠ Honest revision (user pushback 2026-06-10): the first writeup OVERCLAIMED.**
It said "REJECTED, both fail decisively" off point-estimate medians. The real
distributions are weaker and differently shaped — this episode produced the rule
[[project_mechanism_validation_rigor]] (`.claude/rules/mechanism-validation-rigor.md`):

- **(b) realizable per-event test** `diff = C_fwd − P_mostext_fwd` over 373 actual
  cash-blocked decisions: **median −0.12%, mean −1.79%, C beats P 49.9%** — a
  **coin flip** per decision. The negative *mean* is a fat-LEFT-tail effect
  (p10 −23%, p90 +16%): occasionally you rotate out of a name that then rips
  (abandoning the let-winners-run monster). No exploitable per-decision edge; only
  a mild tail-risk cost to rotating.
- **(a) fresh-early vs mature-extended** fwd-4w: early mean +1.15% (+14.9%/yr),
  mature +2.59% (+33.6%/yr) — large *mean* gap BUT distributions overlap almost
  fully, n small (114 vs 311), and **mature-extended is survivor-selected** (only
  names that survived 27+ wk and stayed 20%+ extended). Not the decision the rule
  faces in real time; biased favourable to "mature wins."

What the screen legitimately supports: no obvious free lunch + a plausible
tail-risk cost. That + the standing prior against explorative position-management
(`feedback_strategy_mechanic_changes_too_explorative`, `weinstein-faithful-core.md`)
= **don't prioritize a build.** It is NOT a rigorous rejection — that needs the
mechanism as a default-off **surface** (k, late-thresh, pick-rank) under WF-CV.
Consistent-with (not proven-by): [[project_cascade_selection_inversion]] + the
entry-cap probe (concentration IS the return).

**Consequences:** harvest-rotate not prioritized; P1 partial-exit core change not
motivated by this (only existed to fund it). Concentration-TRIM generally is on the
same footing — revive only if framed as explicit tail-RISK insurance
([[project_broad_universe_790_mtm_inflated]]) with a metric that rewards it, not as
a return improvement. Full record (incl. the corrected distributions):
`dev/experiments/harvest-rotate-validation-2026-06-10/`.

**Harness gap noted:** `Trade_audit.exit_decision.max_favorable_excursion_pct` (and
`max_adverse_excursion_pct`) are **always 0** in every recent run — the simulator
step-stream never populates them. Killed the audit-only give-back proxy; had to
compute forward returns from bars instead. Worth fixing if MFE/MAE-based analysis
is wanted later.
