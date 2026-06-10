# Mechanism-validation rigor — the bar a "validate-before-build" screen must clear

A cheap read-only screen run *before* building a strategy mechanism is good
discipline (`experiment-flag-discipline.md`, the cascade-reweight save). But a
screen is only worth running if it is *honest about what it can and cannot
conclude*. This rule exists because the 2026-06-10 harvest-rotate screen reported
**"REJECTED, both preconditions fail decisively"** off point-estimate medians,
when the real distributions said **"coin-flip per decision, no exploitable edge,
mild tail-risk"** — a much weaker and differently-shaped claim. Same data,
overclaimed verdict. The failure mode recurs because the standard evaporates
between sessions; this file makes it load-bearing.

Source episode: `dev/experiments/harvest-rotate-validation-2026-06-10/`.

## When this fires

Any read-only analysis whose output is a **build / no-build** or **promote /
reject** decision on a strategy mechanism — autopsies, opportunity-cost probes,
forward-return studies, selection-edge checks, "is there alpha in X" screens.

## The seven checks (every screen must answer all seven *in its writeup*)

1. **Estimand — am I measuring the thing the mechanism actually does?**
   State the realized-P&L quantity the mechanism would change, then confirm the
   statistic is a faithful proxy for it. A cross-sectional forward-return average
   is **not** the realized return of a rule that trades with stops and a real-time
   information set. If the proxy and the estimand diverge, say so and bound the
   gap. (Harvest-rotate measured population forward-return buckets, not the
   realized P&L of `trim k of P, buy C, ride with stops`.)

2. **Distribution, not point estimate.** Report n, mean, median, and at least
   p10/p25/p75/p90 (or a histogram) for every headline comparison. A median gap
   with massively overlapping distributions is not an edge. A mean whose sign
   flips under winsorization is a **tail** statement, not a central-tendency one —
   name which tail and what drives it.

3. **Economic magnitude, correctly scaled.** Convert horizon returns to an
   annualized / per-unit-capital figure so "small" vs "large" is meaningful.
   +1.44% / 4 weeks is +20%/yr — do not report the raw fraction and call it tiny
   (or call it decisive) without the scale.

4. **Selection / survivorship bias.** Ask what each bucket is *conditioned on*. A
   "mature winner" bucket exists only for names that survived and kept winning —
   it is survivor-selected and reads falsely favourable. The screen must use the
   information set the rule has **at decision time**, not hindsight membership.

5. **Surface, not boolean.** A mechanism has knobs (fraction `k`, threshold,
   pick-rank, horizon). Test a **range** and show the response shape, not one
   point. A single-point probe cannot reject a mechanism — it can only fail to
   find an obvious free lunch at that point. (Per `experiment-flag-discipline.md`
   R2 the mechanism is an axis; the screen should sweep it too.)

6. **Paired / event-level, not just pooled.** When the decision is "at moment t,
   do X vs Y," compute the **paired per-event** difference and its sign-rate and
   distribution — not two pooled population means. Trace a few individual events
   end-to-end to sanity-check the aggregate.

7. **Uncertainty + power.** Small n, wide dispersion → wide CI. Say whether the
   sample can even distinguish the hypotheses. "Coin-flip at n=373 with this
   spread" is a finding; "median +1.44%" alone hides it.

## Verdict calibration — what a screen may and may not claim

A cheap read-only screen operates on a proxy with the limits above. It may
conclude:

- ✅ **"No obvious free lunch at the tested point; not worth prioritizing a build"**
  — a *decision*, which may lean on standing priors
  (`feedback_strategy_mechanic_changes_too_explorative`,
  `weinstein-faithful-core.md`).
- ✅ **"Promising signal — escalate to the real test"** (mechanism as a default-off
  surface under WF-CV + the confirmation grid).

It may **not** conclude:

- ❌ **"Decisively rejected"** / **"the mechanism does not work."** Only the real
  test rejects: the mechanism implemented behind a default-off flag and backtested
  as a surface under walk-forward CV (`experiment-gap-closing` skill,
  `promotion-confirmation.md`). A proxy screen rejects *prioritization*, not the
  mechanism.

Write the verdict as **"no-build *decision*"** (citing the prior) when the screen
is weak, never **"rejected *because the data proves it fails*"** when the data only
shows no-edge-at-one-point. The two are different epistemic objects; conflating
them is the exact error this rule guards against.

## The real deliverable is the *why*, not the verdict

A verdict (build / no-build / ACCEPT / REJECT) is the cheap part. The valuable,
compounding output is a **causal explanation of the result that transfers to other
experiments.** A screen or test is not done when it has a verdict — it is done when
it can answer *"why did it come out this way, and what does that imply for the next
lever?"* "REJECT" alone teaches nothing; "REJECT **because** the strategy's edge is
the let-winners-run fat tail and any winner-trimming mechanism taxes that tail —
so stop proposing winner-touching levers" steers every future session.

Three things every result must produce:

1. **Attribute the result to a mechanism, decomposed.** Don't stop at "no edge."
   Which failure mode? For a rotation/trim rule: is it **timing** (we act too
   early/late), **picks** (the alternative wasn't actually better), the
   **structural tax** (we occasionally give up the fat-tail monster — fundamental,
   no rule can win), or **cost/turnover**? Each implies a *different* next move; a
   bare "REJECT" collapses them and loses the guidance.
2. **Connect it to the system's known structure.** Does this result agree with or
   contradict existing findings (cascade-inversion, concentration-is-the-return,
   prior rejections)? A result that *re-derives* a known mechanism from a new angle
   is stronger evidence; one that contradicts it is a flag to dig.
3. **Derive forward guidance.** State what the *why* rules in and out for future
   search (e.g. "bias toward tail-preserving levers — breadth, entry quality,
   holding discipline; away from trim/rotate/re-time/cap"). Record it where the
   next session will see it (a `project_*` memory + the handoff), not just buried in
   an experiment writeup.

This is the antidote to the "we keep re-rejecting variants of the same idea"
treadmill: each rejection should *narrow the search*, which only happens if the why
is extracted and persisted. A verdict without a transferable why is a draft.

## The one-line self-check before publishing a screen

> *Did I report the distribution, scale it economically, name the estimand gap and
> the selection bias, sweep the knob, calibrate the verdict to what a proxy can
> actually claim — and explain WHY the result came out this way in a form that
> guides the next lever?* If any answer is no, the writeup is a draft, not a verdict.

## Relationship to the other rules

- `experiment-flag-discipline.md` — the mechanism is default-off + an axis; this
  rule says the *pre-build screen* of that axis must be rigorous before it informs
  a decision.
- `experiment-gap-closing` skill / `promotion-confirmation.md` — the **real** test
  (surface → WF-CV → DSR/Pareto → confirmation grid). This rule governs the cheap
  screen that decides whether to *enter* that pipeline.
- `weinstein-faithful-core.md` — a legitimate standing prior a weak screen may lean
  on; but lean on it *explicitly* as a prior, don't dress it up as a data verdict.
