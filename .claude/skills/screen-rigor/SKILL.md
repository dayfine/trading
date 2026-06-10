---
name: screen-rigor
description: Walk a read-only "validate-before-build" screen through the 7 rigor checks and calibrate its verdict, BEFORE concluding build/no-build or promote/reject on a strategy mechanism. Use when an autopsy / opportunity-cost probe / forward-return study / "is there alpha in X" screen is about to produce a decision, when you're tempted to write "REJECTED" or "the mechanism doesn't work" off a cheap analysis, or when the user asks to validate a mechanism, screen a hypothesis, or sanity-check a no-build call. Pairs with experiment-gap-closing (the real WF-CV test this screen decides whether to enter).
---

# Screen rigor — make a cheap read-only screen honest before it decides anything

A read-only screen run *before* building a mechanism is good discipline. But a
screen reports on a **proxy**, so it can only support a narrow class of claims.
This skill is the procedure; the spec it enforces is
`.claude/rules/mechanism-validation-rigor.md`. It exists because the 2026-06-10
harvest-rotate screen wrote **"REJECTED, both fail decisively"** off point-estimate
medians when the distributions said **"coin-flip, no edge, mild tail-risk"** — same
data, wrong verdict shape. (`dev/experiments/harvest-rotate-validation-2026-06-10/`.)

This is the **gate before** `experiment-gap-closing`: the screen decides whether a
hypothesis is worth the real WF-CV test, and reports what it found without
overclaiming. It does **not** replace that test — a screen never rejects a
mechanism, only its prioritization.

## When to run this

You're about to conclude a build/no-build or promote/reject from a read-only
analysis (no new mechanism implemented, no WF-CV). The moment you find yourself
typing a verdict sentence about a mechanism, stop and run the checklist.

## The procedure

### Step 1 — State the estimand, then the proxy, then the gap

Write one sentence: *"The mechanism changes <realized-P&L quantity> by <how>."*
Then: *"My screen measures <statistic>."* Then name the gap explicitly. If the
statistic is a cross-sectional forward-return average and the mechanism is a rule
that trades with stops and a real-time information set, the gap is large — the
proxy can fail to find an edge that the real rule would capture, or vice-versa.
Bound it: which direction does the proxy bias?

### Step 2 — Run the seven checks (all must be answered in the writeup)

1. **Estimand fidelity** — does the statistic track the realized-P&L the mechanism
   moves? (Step 1.)
2. **Distribution, not point estimate** — report n, mean, median, p10/p25/p75/p90
   (or a histogram) for every headline number. Overlapping distributions with a
   median gap = not an edge. A sign that flips under winsorization = a *tail*
   statement; name the tail.
3. **Economic magnitude, scaled** — annualize / express per-unit-capital. Don't
   call a raw horizon fraction tiny or decisive.
4. **Selection / survivorship bias** — what is each bucket conditioned on? "Mature
   winner" buckets are survivor-selected. Use the info set the rule has *at
   decision time*, not hindsight membership.
5. **Surface, not boolean** — sweep the knob(s) (fraction k, threshold, pick-rank,
   horizon) and show the response shape. One point can't reject — only fail to find
   a free lunch at that point.
6. **Paired / event-level** — when the decision is "at moment t, X vs Y," compute
   the per-event difference, its sign-rate, and its distribution; trace a few
   events end-to-end.
7. **Uncertainty + power** — small n / wide spread → wide CI. Can the sample even
   distinguish the hypotheses? (A bootstrap or sign-test beats an eyeballed median.)

### Step 3 — Calibrate the verdict to what a proxy can claim

A screen MAY conclude one of:
- **"No obvious free lunch at the tested point → don't prioritize a build"** — a
  *decision*, which may lean on a standing prior
  (`feedback_strategy_mechanic_changes_too_explorative`, `weinstein-faithful-core.md`).
  State the prior explicitly; don't dress it up as a data verdict.
- **"Promising signal → escalate to the real test"** → hand off to
  `experiment-gap-closing` (mechanism as a default-off surface, WF-CV, DSR/Pareto,
  confirmation grid per `promotion-confirmation.md`).

A screen may NOT conclude **"decisively rejected / the mechanism doesn't work."**
Only the real WF-CV test rejects. Write *"no-build decision (citing the prior)"*,
never *"rejected because the data proves it fails,"* when the data only shows
no-edge-at-one-point.

### Step 4 — Record it honestly

Writeup includes: the estimand+gap sentence, the distributions (not just medians),
the annualized magnitude, the selection-bias note, the knob sweep (or an explicit
"single-point screen — cannot reject" caveat), and a verdict that matches Step 3.
If the signal is promising, open the `experiment-gap-closing` loop; if it's a
no-build decision, say which prior it leans on.

## The one-line self-check

> *Did I state the estimand gap, show the distribution, scale it economically, name
> the selection bias, sweep the knob, and calibrate the verdict to what a proxy can
> claim?* Any "no" → it's a draft, not a verdict.

## Relationship to the other tools

- `.claude/rules/mechanism-validation-rigor.md` — the spec (auto-loaded every
  session); this skill is the procedure that applies it.
- `experiment-gap-closing` skill — the **real** test the screen decides whether to
  enter.
- `promotion-confirmation.md` / `experiment-flag-discipline.md` — the gates *after*
  the real test earns an ACCEPT.
