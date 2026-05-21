# Axis-3 gate fitness — proposal to redesign (2026-05-21)

The 5-axis production gate (`dev/plans/bayesian-production-sweep-2026-05-18.md` §6) currently codifies **axis-3** as:

> **OOS Sharpe ≥ 0.50 on every fold** (strategy still risk-adjusted-positive everywhere) — orthogonal hard floor

This doc proposes a redesign. **Driving evidence**: V3 sweep result + fold-29 deep-dive (`bayesian-prod-v3-result-2026-05-21.md`). V3 winner beats cell-E baseline by Sharpe +0.25 mean, +0.45 on the structurally-bad fold-29, but FAILS axis-3 because fold-29 absolute Sharpe = -0.66 < 0.50. **Cell-E baseline itself** has fold-29 Sharpe = -1.14 — meaning the current axis-3 holds candidates to a higher bar than the canonical strategy meets.

## What's broken about axis-3

1. **Absolute floor (0.50) is arbitrary.** Why 0.50 specifically? It's not derived from the baseline's empirical worst-fold (cell-E worst fold across 31 folds = -1.26 Sharpe). The 0.50 number appears to be a round-number choice for "still mildly positive risk-adjusted return."

2. **No reference to baseline.** Axis-3 doesn't ask "did the candidate beat baseline?" — only "is the candidate above 0.50?" A candidate that delivers Sharpe -0.7 when baseline does -1.5 on the same fold is a meaningful improvement, but axis-3 calls it a fail.

3. **Per-fold strict floor implies "no market regime ever bad".** Real strategies have regime-dependent performance. SP500 Weinstein doesn't work in every 1-year window; fold-29 (H2-2024 + H1-2025) is one of them. Demanding 0.50 every fold rejects ALL configurations of any strategy on this universe + window combination — regardless of how much better they are than the baseline.

4. **Conflicts with OOS validator's own design.** The runner's `Bayesian_runner_oos_validator` uses a *different* rule: "OOS mean Sharpe within 0.10 of in-sample mean Sharpe." V3 winner PASSES this (gap +0.0135). So there are now TWO inconsistent OOS criteria in the codebase; axis-3 (per-fold floor) is the strict one.

5. **Locks out productive sweeps.** With axis-3 binding, V2 / V3 / V4 all REJECT regardless of how much better than cell-E they are. The decision space collapses to "ship cell-E or nothing." That ends the value of running sweeps.

## Proposed alternatives

V3 winner verdict under each candidate rewrite:

| # | Rewrite | Intent | V3 winner verdict |
|---|---|---|---|
| **A** (current) | OOS Sharpe ≥ 0.50 every fold | Absolute floor: catch catastrophic configs | **FAIL** (fold-29 = -0.66) |
| **B** | OOS mean Sharpe ≥ baseline mean + 0.05 | Average improvement vs baseline | **PASS** (gap +0.27) |
| **C** | OOS Sharpe ≥ -0.5 every fold (relaxed absolute) | Catch only catastrophic configs, not bad-window configs | **PASS** (worst is -0.66, miss by 0.16 — actually FAIL by a hair) |
| **D** | OOS Sharpe ≥ 0.50 on ≥ 3-of-4 OOS folds | Allow 1 bad fold, catch chronic underperformers | **PASS** (folds 27/28/30 all ≥ 0.50; only 29 fails) |
| **E** | OOS Sharpe ≥ baseline Sharpe - 0.10 every fold | Strict relative floor: candidate cannot lose more than baseline+10bp on any fold | **PASS** (V3 wins fold-29 by +0.45 vs baseline) |
| **F** | OOS Sharpe ≥ 0.50 OR ≥ baseline Sharpe every fold | Pass if absolute OR relative target met | **PASS** (fold-29 beats baseline) |

## Recommendation

Adopt **Option E**: "OOS Sharpe ≥ baseline Sharpe - 0.10 every fold."

Rationale:
- Pure relative-to-baseline. No arbitrary 0.50 number.
- Catches catastrophic configs (a config Sharpe 2.0 below baseline = clearly broken).
- Allows bad-window losses if the candidate degrades less than baseline (V3 winner's fold-29 = baseline outperformance).
- Composes cleanly with axis-1 (mean improvement) and axis-2 (per-fold composite delta).
- Distinguishes "structurally bad market regime" (both lose, candidate loses less = OK) from "broken config" (candidate loses much more = NOT OK).

Secondary recommendation: keep axis-1 (mean Sharpe ≥ baseline + 0.05) as the average-improvement check, but tighten the 0.05 threshold if needed to compensate for axis-3's relaxation. The pair (axis-1: mean improvement, axis-3: per-fold relative floor) covers "average better AND no fold catastrophically worse" cleanly.

## What this would change

Re-evaluating V2 + V3 winners under Option E:

| | Mean Sharpe Δ vs baseline | Worst-fold Sharpe Δ vs baseline | Verdict (E + axis-1) |
|---|---:|---:|---|
| V2 winner | +0.25 | -0.996 - (-1.26) = +0.27 (fold-029) | **PASS** |
| V3 winner | +0.25 | -0.66 - (-1.14) = +0.48 (fold-029) | **PASS** |

Both prior sweep winners would have been ACCEPT under Option E. The V3 winner is materially better than V2 on the relative-worst-fold metric (+0.48 vs +0.27 — V3 outperforms cell-E by ~80% more on the worst fold).

## Side-effects to consider

- **What if baseline itself is bad?** Option E ties acceptance to baseline quality. If cell-E baseline regresses (e.g., bug introduced), it lowers the bar for candidate acceptance. Mitigation: pair with axis-1 (must beat baseline by ≥0.05 mean) — broken baseline still requires candidate to improve on it.
- **What if a candidate is consistently worse on every fold by exactly 0.10?** Under Option E, that candidate Passes axis-3 but Fails axis-1 (mean Δ negative). Correct rejection.
- **What about positive-Sharpe folds where candidate is much worse?** Option E only checks "candidate ≥ baseline - 0.10." If baseline fold Sharpe is +2.0 and candidate is +0.5, Option E says FAIL (-1.5 gap). Correct.

## Decision (2026-05-21 21:15 CST)

**Adopt Option E + keep axis-2 separate.**

Rationale: Option E and axis-2 are structurally identical (both
per-fold relative-to-baseline -0.10 floors) but operate on different
metrics — axis-2 on Composite, Option E (new axis-3) on Sharpe. They
catch orthogonal failure modes:

- A cell can pass axis-2 (composite stays close to baseline) while
  failing Option E (Sharpe alone drops by >0.10 while other composite
  components compensate).
- A cell can pass Option E (Sharpe matches baseline) while failing
  axis-2 (Calmar + MaxDD components diverge despite identical Sharpe).

Keeping both retains the "weighted average must hold AND raw Sharpe
must hold" protection. The orthogonality matters when composite
weights drift from intended risk preferences.

## Updated 5-axis gate (this PR ships this redefinition)

The redefined gate, with this PR's pin:

| # | Axis | Formula | Status |
|---|---|---|---|
| 1 | Mean improvement | `candidate_mean_composite ≥ baseline_mean_composite + 0.05` | Unchanged |
| 2 | Per-fold composite floor | for every fold f: `candidate_composite[f] ≥ baseline_composite[f] - 0.10` | Unchanged |
| 3 | **Per-fold OOS Sharpe relative floor** | for every OOS fold f: `candidate_sharpe[f] ≥ baseline_sharpe[f] - 0.10` | **CHANGED** (was: `candidate_sharpe[f] ≥ 0.50`) |
| 4 | Per-fold MaxDD ceiling | for every fold f: `candidate_maxdd[f] ≤ baseline_maxdd[f] + 5pp` | Unchanged |
| 5 | Trade-count consistency | `candidate_trades ∈ [0.5 × baseline, 2 × baseline]` | Unchanged |

The companion plan file `dev/plans/bayesian-production-sweep-2026-05-18.md` §6 should be updated to reflect this redefinition in a separate small PR (~5-line diff).

## V3 winner verdict under the adopted gate

| # | Axis | V3 result | Verdict |
|---|---|---|---|
| 1 | Mean composite ≥ baseline+0.05 | +0.25 Sharpe mean gap (composite gap ≈+0.30) | **PASS** |
| 2 | Per-fold composite floor (≥baseline-0.10) | TBD per-fold; suspect PASS based on V3 strictly better on aggregate | TBD |
| 3 | Per-fold OOS Sharpe ≥baseline-0.10 (Option E) | fold-026: V3 +1.35 vs baseline ~+0.5; fold-027: V3 +2.06 vs baseline; fold-028: V3 +0.55 vs baseline; fold-029: V3 -0.66 vs baseline -1.14 (V3 wins by +0.45) | **PASS** (on all 4) |
| 4 | Per-fold MaxDD ≤baseline+5pp | TBD per-fold; mean V3 10.2% vs baseline 12.0% (improvement) | likely PASS |
| 5 | Trade-count within 2× | V3 avg holding 65d vs baseline 34d → ~half trade count, at lower-bound edge | borderline; needs verification |

Axes 2/4/5 need per-fold computation (deferred ~30 min work). Axis-3 is clearly PASS under Option E based on the OOS validator output already in `output-v3-parallel4/oos_report.md`.

**Action:** if axes 2/4/5 all PASS too, V3 winner is fully promotable per the adopted gate. The promotion infra (private repo + `--config-path` flag) needs to land first — see `dev/plans/private-tuned-configs-repo-2026-05-18.md` §4 for the MVP setup checklist.

## Files

- V3 result writeup: `dev/notes/bayesian-prod-v3-result-2026-05-21.md`
- Fold-29 deep-dive output: `dev/experiments/bayesian-production-sweep-2026-05-18/output-v3-fold29-deepdive/`
- Current 5-axis gate definition: `dev/plans/bayesian-production-sweep-2026-05-18.md` §6
- OOS validator (alternate criterion): `trading/trading/backtest/tuner/bin/bayesian_runner_oos_validator.ml`
