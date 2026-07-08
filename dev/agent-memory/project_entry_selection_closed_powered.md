---
name: project_entry_selection_closed_powered
description: "ENTRY-SELECTION CLOSED WITH POWER (2026-07-08): 26y×top-3000 all-eligible (162,632 tickets, n=118,729 complete-case) joint multivariate screen — return R²=0.0034 (powered null, score adds nothing beyond RS/resistance); win-FREQUENCY predictable (AUC .745) but frequency-positive features have NEGATIVE return coefs (Positive_rising +0.42 logit vs −10.1 return-pp) → frequency/magnitude tradeoff nets ~0 EV; explains the 06-29 RS-tiebreak REJECT mechanistically. Directive: no new selection levers, ever, without beating this null."
metadata: 
  node_type: memory
  type: project
  originSessionId: 6a3b1c78-78e9-47b1-82b4-6ff9c6ad695e
---

**The powered closure the 2026-07-07 P0 asked for.** Artifacts:
`dev/experiments/feature-screen-2026-07-08/FINDINGS.md` (+ report/summaries);
tooling = all-eligible feature capture #1878 + `feature_screen` exe #1880.

- Population: 884,083 raw Stage1→2 firings → 162,632 deduped grade-F tickets,
  each ridden through counterfactual exits, fixed $10k. Base rates: win 6.5%,
  median −0.17%, mean +0.63%, top 0.85% of tickets (>100%) carry all P&L.
- **OLS return: R² = 0.0034 at n=118,729.** No feature predicts magnitude.
  cascade_score directionally NEGATIVE controlled for RS/resistance.
- **Logistic win: AUC 0.745** — rs_value z+24, resistance dummies z+25-33.
  Frequency sortable, magnitude not; the two trade off (strong-RS-momentum
  names win more often and smaller). Chasing win-rate = selecting against
  the fat tail — why RS-primary tiebreak lost Calmar in all 3 grid cells.
- rs_value = only both-margins-positive + era-stable feature; return t=1.7
  (ns even at this n); portfolio implementation already WF-CV-rejected
  (2026-06-29 tiebreak grid). NO escalation.
- Grade floors: per-ticket mean F 0.63→A 2.50% with FLAT total PnL — floors
  drop junk, never touch the tail; gradient already harvested at C default.
- Gotchas: weeks_advancing ≡ 1 by construction on this population (scanner
  fires at the transition — can't test freshness here); passes_macro
  degenerate all-true (scanner path lacks breadth inputs); 26.9% RS-None
  (young names + [[project_rs_warmup_gap]]); feature_screen fails "singular
  matrix" on constant columns (follow-up: drop-with-warning).

Confirms/extends [[project_edge_is_the_fat_tail]],
[[project_accuracy_is_unreachable_diversify_instead]],
[[project_cascade_selection_inversion]], [[project_decision_audit_faithful]].
Open frontier after this: barbell deployment ([[project_barbell_on_stocks]])
+ capacity/breadth economics.
