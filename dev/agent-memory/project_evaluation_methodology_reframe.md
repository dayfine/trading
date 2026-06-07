---
name: project_evaluation_methodology_reframe
description: "MaxDD% misled us (scale-dependent, single noisy point, conflates 2 costs). Demote it. Real objective = return + START-DATE ROBUSTNESS (primary) + split DD (Ulcer/time-underwater + capital-relative depth) + antifragility (convexity). Build rolling-start dispersion + capital-relative DD."
metadata: 
  node_type: memory
  type: project
  originSessionId: 227b33ee-5af1-4eb1-80b9-2d487d5b7bd2
---

2026-06-07. The macro-trim study exposed that **raw MaxDD% — our de-facto top-line
risk metric — misled the read.** cap=0 15y: 65% DD off a 12× peak (trough still
4.4× the stake) vs baseline's "milder" 42% that dipped BELOW the initial stake.
MaxDD% ranked the better outcome as riskier.

**Why MaxDD% misleads (but isn't worthless):** scale-dependent (not comparable
across return profiles), a single noisy worst-point (least robust stat we track),
and conflates two different costs. Fix = demote it to one input, never read
without return context, add what it can't capture.

**The real objective (4 axes):**
1. Long-term return (CAGR) — meaningless alone, wildly start-date-sensitive.
2. **Robustness = sensitivity to regime/start-time — should be the PRIMARY lens.**
   The whole trim verdict turned on it (2011-start vs 2006-start flipped cap=0
   from +700pp to −half).
3. Drawdown split: (a) opportunity-cost/integrated = **Ulcer** (have) +
   **time-underwater** (build); (b) psychological depth = **capital-relative
   drawdown** vs initial stake / high-water (build), NOT peak-relative %MaxDD.
4. Antifragility = convexity (tail-ratio, return skew, worst-vol-regime
   conditional return). Weinstein spine is already convex (bounded stops /
   unbounded trailing winners); measure if a change increases or flattens it.
   Hold skeptically — easiest axis to fool yourself.

**Already computed in `actual.sexp`:** Sharpe, Sortino, Calmar, Ulcer. **Genuinely
new + high-value to build:** (P1) rolling-start dispersion harness — judge on the
DISTRIBUTION over many quarter-starts, not one full window; (P2) capital-relative
max drawdown — pure post-proc of `equity_curve.csv`. (P3) time-underwater +
antifragility prototypes.

**Discipline guardrail:** a 6-axis scorecard invites cherry-picking. Pre-commit a
dominance rule before looking at results (e.g. "top-half robustness AND not
worst-decile capital-DD before return counts"); the promotion-confirmation grid +
Deflated-Sharpe still gate — this changes WHAT is scored, not the gating.

Plan: `dev/plans/evaluation-objective-and-metrics-2026-06-07.md`. Surfaced by
[[project_macro_bearish_trim_lever]].
