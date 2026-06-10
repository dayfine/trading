---
name: project_mechanism_validation_rigor
description: "Rule .claude/rules/mechanism-validation-rigor.md — the 7-check bar a read-only validate-before-build screen must clear, and the build-vs-reject verdict calibration"
metadata: 
  node_type: memory
  type: project
  originSessionId: ef5f87b6-2ba9-4ab1-870c-61358d4e71b7
---

**`.claude/rules/mechanism-validation-rigor.md`** (created 2026-06-10 after the
harvest-rotate overclaim). A cheap read-only screen run *before* building a
strategy mechanism must clear seven checks **in its writeup**, or it's a draft not
a verdict:

1. **Estimand** — measure the realized-P&L the mechanism changes, not a proxy
   (cross-sectional forward-return avg ≠ realized P&L of a rule with stops + a
   real-time info set).
2. **Distribution, not point estimate** — n + mean + median + p10/p25/p75/p90. A
   median gap with overlapping distributions is not an edge; a sign that flips
   under winsorization is a *tail* statement.
3. **Economic magnitude, scaled** — annualize. +1.44%/4wk = +20%/yr; don't call a
   raw fraction tiny or decisive.
4. **Selection / survivorship bias** — what is each bucket conditioned on? Use the
   info set the rule has *at decision time*, not hindsight membership.
5. **Surface, not boolean** — sweep the knob (k, threshold, pick-rank, horizon);
   one point can't reject, only fail to find a free lunch there.
6. **Paired / event-level** — per-decision diff + sign-rate + distribution, plus
   trace a few events end-to-end.
7. **Uncertainty + power** — small n / wide spread → can the sample even
   distinguish the hypotheses?

**Verdict calibration (the core point):** a proxy screen may conclude *"no obvious
free lunch → don't prioritize a build"* (a decision, may lean on standing priors)
or *"promising → escalate to the real test."* It may **NOT** conclude *"decisively
rejected / the mechanism doesn't work."* Only the real test rejects — the mechanism
behind a default-off flag, backtested as a surface under WF-CV
([[project_promotion_confirmation_grid]], `experiment-gap-closing`). A weak screen
rejects *prioritization*, not the mechanism. Write "no-build decision (citing the
prior)", never "rejected because the data proves it fails," when the data only
shows no-edge-at-one-point. Origin: [[project_harvest_rotate_rejected]].
