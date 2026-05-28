# v8 round-3 critique — independent review

**Date:** 2026-05-28
**Plan:** `dev/plans/v8-bo-design-2026-05-28.md` §"Decision 2" (PR #1344, Round-3)
**Prior critiques:** Round-1 (`v8-score-weights-critique.md`), Round-2 (`v8-hard-gate-critique.md`)

---

## Summary verdict

**RECOMMENDS_REVISION.**

Round-3 addresses all six Round-2 findings substantively — single-
objective SENTINEL is the right shape for the BLOCKING fix,
margin_bonus inverts J-uniform-vs-J-skater as claimed, symmetric
holdout removes the inverted-asymmetry, G3 = 25% is closer to investor
tolerance, and the diagnostic is real operator help. Round-3 introduces
three new concerns (GP-numerical fragility at the cliff, partial skater
coverage at high alpha, smoke-sweep selection bias) and three Round-2
fixes only partially close. Design is converging but accumulating
layers; right move is one short revision on cliff-numerics +
skater-cap, then ship and let smoke sweep adjudicate empirically.

---

## Convergence assessment

| Round | New findings | Net-new structural concerns |
|---|---|---|
| 1 | 1 BLOCKING + 4 MAJOR + 6 minor/obs | blockbuster + DD-game + promote-mismatch |
| 2 | 1 BLOCKING + 5 MAJOR + 3 minor/obs | GP/EI incoherence + knife-edge + holdout asymm + G3 lax + non-actionable diagnostic + sparsity |
| 3 | 0 BLOCKING + 2 MAJOR + 4 MINOR + 1 OBS | GP-numerical at SENTINEL + partial skater coverage + smoke-sweep bias |

**Issues ARE converging.** Fewer new findings than Round-2; none
BLOCKING. Each Round-2 fix landed in proportion to its defect.
Remaining concerns are complexity-appropriate-to-9-knob-BO, not
fundamental incoherence. The design is at six layers (soft formula +
G1/G2/G3 + margin_bonus + SENTINEL + smoke sweep + diagnostic); each
added in response to a critique. Risk: defending against critique
noise more than empirical failure modes that will actually arise.

---

## Findings

### 1. GP fit at SENTINEL_REJECT = −1.0e6 is numerically pathological (MAJOR)

The doc argues `-1e6` over `-∞` for stability. Swaps one issue for another:

- **Target variance dominated by the cliff.** Yellow smoke (5–25%
  acceptable) → 75–95% of evals carry `-1e6`. Population variance
  `~p(1−p)·(1e6)² ≈ 10¹¹`. Kernel MLE fits either a very long
  lengthscale (flattens cliff, loses acceptable-region resolution) or
  very short (degenerates to nearest-neighbor).
- **EI in the acceptable region inherits massive posterior std.**
  EI = `(μ − f*)·Φ(z) + σ·φ(z)`. With σ ~ O(10⁵) away from observed
  acceptable points (almost everywhere in 9D given <25 acceptable
  samples), EI is dominated by σ·φ(z) *exploration*, not exploitation.
  BO becomes near-random search within the acceptable region.
- **The doc's consistency proof only verifies sign** (acceptable beats
  unacceptable in EI), not that EI *within* the acceptable region ranks
  correctly. The cliff dominates hyperparameter optimization; within-
  region ranking is noise.

Fix: target transformation. Fit GP on `g(y) = y if y > −10 else
−10 − tanh((-10−y)/100)`, mapping sentinel to ~−11. EI uses raw `f*`.
Preserves sentinel semantics, bounds GP targets to ~12-unit range,
kills variance explosion. Alternative: implement cBO (standard
solution, dismissed by doc as too much infra).

### 2. margin_bonus only partially closes knife-edge gaming (MAJOR)

Example J arithmetic checks out; inversion only holds in a narrow regime.

| Skater pattern | α-term | margin_bonus | Total | vs Uniform +3pp (1.20) |
|---|---|---|---|---|
| {+5, +1.01, +5}    | 0.73 | 0.003 | 0.74 | LOSES (doc) |
| {+8, +1.01, +8}    | 1.13 | 0.003 | 1.14 | LOSES |
| {+10, +1.01, +10}  | 1.40 | 0.003 | 1.40 | **WINS** |
| {+12, +1.01, +12}  | 1.67 | 0.003 | 1.67 | **WINS** |

Skater wins once two-window alpha exceeds **+9pp uniform equivalent**.
`margin_sat = 2pp × μ = 30` caps bonus at 0.60; skater alpha advantage
is unbounded. v7's ±1pp/fold is 1y; 7y regime-favorable windows (e.g.
W3 post-GFC bull for a trend-follower) can plausibly compound to +10pp+.

Fix: remove `margin_sat` cap (let bonus scale linearly) OR multiplicative
form `score ← score × (1 − exp(−k·worst_margin))` that shrinks toward
zero as worst_margin → 0. Either closes the unbounded-skater hole.

### 3. Sobol-100 smoke sweep biases toward easy-to-find configs (MINOR)

Implicit claim: "≥25/100 Sobol passes ⇒ BO finds better." True only if
the random-pass region overlaps the high-soft-score region. It needn't:
random pass clusters around low-risk regimes (low exposure, tight
stops, marginal-positive alpha); BO target may sit in a more aggressive
regime Sobol-100 rarely lands by chance. Green can mean "BO finds same
marginal-pass configs Sobol already found"; red can mean deferring v8
when BO would have found a thin region with a real peak. Fix: yellow
→ launch with elevated Sobol-40 initial-random; only red defers.

### 4. Holdout symmetry verifies predicate, not generalization (MINOR)

Identical G1/G2/G3 on W4 is predicate-confirmation on a held-out sample,
not a generalization test. BO selection bias means W4-pass | W1/W2/W3-
pass has higher prob than unconditional W4-pass. A stricter holdout
(e.g. +1.5pp on G1; G3 = 20%) provides extrapolation margin. Round-3
"identical = symmetric" framing is too binary; correct asymmetry is
"slightly stricter same-direction." Not blocker — promote_config gives
defence in depth — but "generalization test" framing in the doc is loose.

### 5. G3 = 25% per-window vs rolling-DD ambiguity (MINOR)

G3 is per-window MaxDD. Per Decision 1, each window is a disjoint
backtest with fresh capital. Per-window MaxDD = 25% does NOT bound
rolling MaxDD over the 28y continuous portfolio. Example: W1 ends at
80% of W1-start; W2 starts fresh at $100 per Decision 1; W2 takes 25%
from its own peak. Per-window 25% each, gate passes. Investor consuming
continuously sees rolling DD that the gate doesn't bound. Fix: clarify
G3 semantics + accept mismatch, OR add G4 = rolling full-period MaxDD.

### 6. Example K Section 4 suggestion (a) is unsupported by its data (MINOR)

Example says "widen `max_long_exposure_pct` (currently 0.5–1.0; closest-
rejected has 0.85)." 0.85 is mid-range, not at the bound. Suggestion
doesn't follow from data. The rule logic is defensible; the example
demonstrates the template producing a bad answer — worse than no
example. Fix the example so closest-rejected's data actually triggers
(c) "switch universe" or (b) "relax N_cagr."

### 7. Six-layer mechanism cost vs expected pivot (OBSERVATION)

Round-3 = soft formula + 3 gates + margin_bonus + SENTINEL +
smoke sweep + diagnostic. ~5 PRs infra. If v8 pivots to broader-
universe (per strategic memory), most is abandoned. Margin_bonus +
smoke + diagnostic together cost ~5–8h agent work to defend against
"BO converges to uniform instead of skating." Right answer might be
drop margin_bonus (accept skating as cosmetic) and ship simpler design.

---

## Arithmetic checks (Round-3 net-new examples)

**Example J:** J-skater α = 20·(0.05+0.0101+0.05)/3 = 0.734;
margin_bonus = 30·0.0001 = 0.003; total = 0.737 ✓ (doc: 0.74).
J-uniform α = 0.60; margin_bonus = 30·0.02 = 0.60; total = 1.20 ✓.
Inversion confirmed in narrow regime; Finding 2 shows it fails at
easy-window alpha ≥ +9pp.

**Example I':** W2 candidate CAGR α = +2pp, MaxDD = 30%, SPY MaxDD =
25%. G1 ✓ (0.02 ≥ 0.01), G2 ✓ (0.05 ≤ 0.10), G3 ✗ (0.30 > 0.25) →
REJECT ✓. Under Round-2 (G3 = 0.50) would have ACCEPTED. Catch case
is real.

**Example K:** Sections 1–3 internally consistent. Section 4 suggestion
(a) has the bug noted in Finding 6.

---

## Suggested fixes

| # | Severity | Fix |
|---|---|---|
| 1 | MAJOR | Target transformation: GP fits `g(y) = y if y > −10 else −10 − tanh((-10−y)/100)`; EI uses raw `f*`. Preserves sentinel semantics, bounds target range, kills the variance explosion. Alternative: implement cBO (the standard solution). |
| 2 | MAJOR | Remove `margin_sat` cap OR switch to multiplicative form `score × (1 − exp(−k·worst_margin))`. Closes the unbounded-skater hole at high easy-window alpha. |
| 3 | MINOR | Smoke-sweep yellow → launch with elevated initial-random; only red defers. Don't auto-defer on 100-point sample that could miss thin acceptable regions. |
| 4 | MINOR | Either rename "generalization test" → "out-of-sample predicate check," OR add stricter-on-holdout gate (e.g. +1.5pp on G1) for real extrapolation margin. |
| 5 | MINOR | Clarify G3 = per-window vs rolling; if per-window, add G4 = rolling full-period MaxDD. |
| 6 | MINOR | Fix Example K Section 4 (a) — exposure 0.85 is mid-range. Suggestion should follow from data. |

---

## META-ASSESSMENT — should round 4 happen?

The design space isn't the problem; the design is converging in shape
and Round-3 closed the BLOCKING with a sound single-objective
formulation. Round 4 should NOT be another adversarial cycle on the
same scoring surface. The remaining issues are bounded (2 MAJOR with
one-line fixes, 4 MINORs, 1 OBS) and resolvable inline. What would
genuinely change EV is implementing Round-3 with Findings 1–2 inline
fixes, running PR-3.5's smoke sweep, and letting the empirical pass-
rate adjudicate. If smoke returns red, the design isn't wrong — the
strategy/universe combination is — and pivot per the strategic backlog
memory. If green/yellow, launch v8 and treat the surface as load-
bearing rather than continuing to argue about it on paper. Three
rounds of paper-critique is the saturation point.
