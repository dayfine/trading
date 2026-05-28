# v8 hard-gate + soft-score critique — independent review

**Date:** 2026-05-28
**Plan:** `dev/plans/v8-bo-design-2026-05-28.md` §"Decision 2" (PR #1342)
**Prior critique:** `dev/reviews/v8-score-weights-critique.md`
**Authorities:** `dev/notes/v7-results-2026-05-28.md`, PR #1342 diff

## Summary verdict

**RECOMMENDS_REVISION.**

The hard gate correctly resolves the prior BLOCKING finding F1
(single-window blockbuster). All nine worked examples (A-I) reproduce
arithmetically. However, the redesign introduces three new structural
issues and one inconsistency. The most serious — **GP/EI is
undefined under the disjoint acceptance set** the doc describes
(Finding 4) — is BLOCKING for the BO mechanic itself; the pseudocode
is mathematically incoherent as written.

---

## Findings

### 1. Knife-edge gaming at the N_cagr floor (MAJOR)

The gate is **discontinuous at exactly +1pp CAGR alpha per window**.
`{1.01, 1.01, 1.01}` passes; `{4.0, 0.99, 4.0}` fails despite higher
mean alpha. Within the acceptable set, the BO ranks by a soft score
whose dominant term (α=20·CAGR-alpha) rewards aggregate alpha — but
the gate has just eliminated the high-aggregate / one-marginal-window
candidates.

Predictable BO trajectory: GP learns the gate boundary; suggests
configs that **barely clear the floor in the worst-train-window** to
keep optimization headroom for the soft score elsewhere. This is a
new overfit mode ("min-window-skater") the soft-only design did not
have, and it scores "decisively" within the redesigned sanity table.

### 2. Acceptable-set size at convergence likely too small (MAJOR)

Assume realistic σ ≈ 3pp on per-7y-window CAGR-alpha (consistent with
v7's per-fold dispersion). For true +2pp alpha: per-window pass-prob
≈ Φ(1/3) ≈ 0.63; joint over 3 train windows = 0.63³ ≈ **0.25**. For
v7-realistic +1.5pp: joint ≈ **0.18**.

80 BO iters × 0.2 ≈ 16 acceptable points in 11-dim space. The GP
**cannot meaningfully interpolate** between 16 points in 11 dims —
the BO degenerates from "BO within acceptable region" to "exhaustive
search over a sparse cloud."

If the strategy class truly delivers ≤ +1pp (v7-iter42 lost Sharpe
to cell-E by 0.155, suggesting modest baseline alpha), the acceptable
set could be 0-3 points — fallback territory.

### 3. Holdout verdict contradicts the train-gate philosophy (MAJOR)

Decision 2 § "Holdout treatment" applies on W4:

- **Strict:** G1+G2+G3 (same thresholds as train)
- **Softer fallback:** CAGR Δ ≥ 0 (vs train's +1pp), MaxDD ≤ 25% (vs
  train's G3=50%)

Two inconsistencies:

(a) **CAGR fallback is LOOSER than train.** If "winning is +1pp or it
doesn't count" is the design's structural claim, accepting +0pp
holdout as marginal-pass undermines that claim. Either +1pp is the
real bar (drop the fallback) or +0pp is (train gate is too tight).

(b) **MaxDD fallback is TIGHTER than G3.** Train allows up to 50%
per-window DD; holdout requires ≤ 25%. A config passing train at
W2-DD=48% might fail holdout at W4-DD=26%. Asymmetry is *backward*:
holdout should be the same criterion as train, applied out-of-sample.
The doc's "verdict cares more about absolute risk than BO does" is
hand-wavy — investor risk tolerance doesn't change between W3 and W4.

### 4. GP surrogate / Expected Improvement is undefined under disjoint acceptance (BLOCKING)

Pseudocode says:

> the GP surrogate sees ALL evaluations (acceptable or not) … Only
> the "iter-best" reporting and the acquisition function's
> exploitation target use the filtered set.

**Mathematically incoherent.** Expected Improvement is `E[max(0, f(x)
− f*)]` where `f*` is best-so-far. If `f*` is taken from the
acceptable set but `f(x)` comes from a GP fit to all points, EI is
maximized wherever the GP predicts high `f(x)` — typically in the
unacceptable region (where the blockbuster peaks live). BO will burn
iterations re-sampling unacceptable configurations the GP correctly
identifies as high-score-but-rejected.

Concrete failure: an Example-E blockbuster region sits at soft-score
+2.45 but fails G1. GP fits that high value. Acceptable best-so-far
= +0.82. EI computes large gain everywhere near the blockbuster peak.
BO concentrates sampling there. Acceptable set grows slowly.

Standard fix is constrained BO (cBO/PESC): train a *second* GP on the
acceptance indicator, multiply EI by `P(acceptable(x))`. The doc
mentions cBO but doesn't implement it; the hybrid described is
neither standard cBO nor sound vanilla BO.

### 5. Sobol-fallback warning is non-actionable (MAJOR)

`NO_ACCEPTABLE_CONFIG` cannot distinguish (a) gate too tight, (b)
strategy fundamentally weak, (c) BO/spec bug, (d) windows/SPY-bench
misconfigured. The operator sees only "BO failed." Recommend the
fallback report include a **per-gate failure histogram** (G1/G2/G3
counts per train window) and the **closest config** (smallest
gate-violation distance) so the operator can see *how close* and
*which constraint* was binding.

### 6. G3=50% absolute DD is unacceptably permissive (MAJOR)

A config with W2-MaxDD=45% (SPY 55%, G2-passing) and W3-MaxDD=12%
(SPY 5%, +7pp G2-passing) **passes both gates with a 45% DD on one
window**. For a real-money strategy a 45% per-window DD requires
+82% subsequent return to break even.

The doc's rationale (SPY itself took ~55% in W2 GFC, so 50% is
"better than passive") buys "non-cratering," not "structurally
acceptable to an investor." Compounds with Finding 3: holdout
fallback says MaxDD ≤ 25%. If 25% reflects actual investor tolerance,
**G3=50% is twice too loose**. G3=25% (symmetric with holdout) is
more defensible.

### 7. Example D depends on assumed CAGR vector (OBSERVATION)

Example D rejects v7-iter42 on the assumed vector `{-0.03, -0.05,
+0.04, +0.10}`. v7's checkpoint reports per-fold *Sharpe* deltas, not
per-window CAGR alphas. The rejection holds *conditional on the
assumed CAGR pattern* (plausible; matches Sharpe sign-pattern) but
unverified. Worth confirming against the WF checkpoint before
claiming "v7-iter42 structurally rejected."

### 8. F2 response incomplete on Sharpe-α-only blowouts (MINOR)

"Mostly moot" overstates the resolution. A Sharpe-α-only blowout
within the CAGR-acceptable set still slips through: CAGR alphas
`{1.5, 1.5, 1.5, 1.5}` (G1 ✓), Sharpe alphas `{0, 0, 0, +2.0}` (low
Sharpe-α var, ε ≈ 0, soft score boosted by W4 β contribution).

### 9. Arithmetic verification (all examples reproduce)

With N_cagr=0.01, N_dd_rel=0.10, N_dd_abs=0.50:

- **A** (SPY): G1: 0 < 0.01 in every window → REJECT ✓
- **B** (+2pp/+0.3/-5pp DD all): G1 ✓; G2 (-0.05 ≤ 0.10) ✓; G3 ✓ →
  ACCEPT, soft 0.82 ✓
- **C** (matches SPY, +2pp DD): G1: 0 < 0.01 → REJECT ✓
- **D** (assumed v7-iter42 vector): G1 fails W1/W2 → REJECT ✓ (see
  Finding 7)
- **E** (matches SPY W1-W3, +20pp W4): G1: 0 < 0.01 on W1/W2/W3 →
  REJECT ✓ *(BLOCKING-finding case from prior critique — structurally
  resolved)*
- **F** (matches SPY W1-W3, +50pp W4): identical train structure to E
  → REJECT ✓
- **G** (+0.5pp/+0.5pp/-0.5pp): G1 fails all 3 (0.5 < 1.0; -0.5 < 1.0)
  → REJECT ✓ (see Finding 1: knife-edge — +1.01pp variant would pass)
- **H** (calm-window DD: matches SPY W1/W2, +5pp/+15pp DD W3): G1
  fails W1/W2; G2 fails W3 (15 > 10) → REJECT ✓
- **I** (W2: cand_DD=54%, SPY=45%, excess=9pp ≤ G2, abs > G3):
  G3 fails W2 → REJECT ✓

---

## Suggested fixes

| # | Fix |
|---|---|
| 1 | Smooth sub-threshold penalty on gate margin (penalize G1-passing-by-<+0.5pp), OR use fuzzy gate (require P(pass) ≥ 0.95). Softens discontinuity without re-opening F1. |
| 2 | Run a Sobol-100 smoke sweep on v7's spec *before* launching v8 to measure empirical pass-rate. If <5%, the gate is wrong for the strategy/universe — relax N_cagr OR widen knob bounds OR change strategy before the v8 spend. |
| 3 | Pick one: either tighten train G3 to 25% (drop holdout MaxDD fallback as redundant), or relax holdout fallback to 50% (criteria looser than BO acceptance — backward but consistent). |
| 4 | Either (a) implement true cBO (separate GP on acceptance indicator, EI × P(acceptable)), OR (b) set `score(unacceptable) := -∞` (or large negative below any soft-score extremum). Option (b) is simplest, mathematically valid, preserves gate discontinuity, removes the GP/EI ambiguity. Cost: slightly degraded GP fit at the boundary. |
| 5 | On `NO_ACCEPTABLE_CONFIG`, report (i) per-gate failure histogram, (ii) closest config + gate-violation distance, (iii) SPY benchmark per window. |
| 6 | Tighten G3 to 25-30% (symmetric with holdout). Use 50% only if holdout MaxDD fallback is also 50%. |
| 7 | Pull v7-iter42's per-fold CAGR alphas from the WF checkpoint; replace Example D's assumed vector with actual values OR mark assumption explicit. |
| 8 | OBSERVATION only. Future iteration could replace ε with count-based fragility detector. |

---

## Net-new BLOCKING finding

**Finding 4 (GP/EI undefined under disjoint acceptance) is BLOCKING.**
The pseudocode as written describes a BO mechanic that does not
converge to the stated target — the GP fits the unacceptable peaks,
EI keeps suggesting points there, and BO budget is burned on configs
the runner correctly classifies as rejected. The "best-so-far" pointer
sits stuck on whatever acceptable point the Sobol phase happened to
find, while the BO body explores around irrelevant maxima.

This is independently fatal and **net-new** — not the prior critique's
F1 re-litigated. The gate-first redesign introduced it.

**Recommended unblock:** adopt fix 4(b) — set `score(unacceptable) :=
-∞`. Simple, mathematically valid, preserves the hard discontinuity,
removes the GP/EI ambiguity at the cost of a slightly noisier GP fit
at the gate boundary. If the design adopts 4(b) and addresses
Findings 3 and 6 (holdout / G3 thresholds), the redesign is sound. As
written, the BO mechanic is broken.
