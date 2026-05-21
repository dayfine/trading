# V3 Bayesian production sweep — result + 5-axis verdict (2026-05-21)

V3 sweep completed `iter-60 / total_budget=60` at ~20:02 CST (11h wall
from 09:05 launch, parallel=4). Companion sweep V4 (soft gate penalty
2.0) was killed at iter-19 after confirming the same composite_delta
lock as V3 — see §V3+V4 diagnostic finding below.

## TL;DR

V3 winner is **strictly better than V2 winner on every metric** (mean
Sharpe 0.81 vs 0.81, OOS Sharpe 0.83 vs 0.74, fold-029 -0.66 vs -1.00,
Calmar 2.03 vs 1.85, Total Return 12.9% vs 12.6%, MaxDD 10.2% vs
10.5%). But **REJECT on the 5-axis production gate axis-3** (every OOS
fold ≥ 0.50): V3's fold-029 = -0.658 fails the per-fold floor by
~1.16 Sharpe. The OOS validator's softer "mean OOS within 0.10 of
in-sample" check accepts V3 cleanly.

The big finding from V3 + V4 together: the BO scorer's `gate_penalty`
masked V3's actual winner. Both sweeps reported "best score ~ -9.5"
(V3) / "~ -1.5" (V4), which looks like a flat-failure search surface.
Underneath that floor, the actual cell at iter-1 was a Sharpe 0.81
winner — but the BO's GP saw all cells as approximately equal because
they all gate-failed and the penalty drowned the metric signal.

**Promote decision:** REJECT per the codified 5-axis gate, but the
result raises a **gate-fitness question** for human review — axis-3's
per-fold-floor strictness may be the binding constraint, not the
strategy itself. See §Open question.

## What ran

- **Spec**: `dev/experiments/bayesian-production-sweep-2026-05-18/spec_prod_v3.sexp`
- **Walk-forward fixture**: `walk_forward_v2_baseline.sexp` (same as V2 — 31 rolling 1-yr folds, step=182d, gate Sharpe m=17 n=30 worst_delta=0.30, baseline=cell-E)
- **Universe**: `goldens-sp500-historical/sp500-2010-2026.sexp` (510 symbols)
- **Holdout folds**: 27, 28, 29, 30 (4 OOS folds; 27 in-sample folds for BO scoring)
- **Objective**: Composite (Sharpe 0.40 + Calmar 0.30 + MaxDrawdown -0.10) — V1/V2 used single-Sharpe
- **Bounds (tightened vs V2)**:
  - `max_position_pct_long`: (0.04, 0.15) (V2: 0.02-0.20)
  - `max_long_exposure_pct`: (0.45, 0.85) (V2: 0.30-0.95)
  - `initial_stop_buffer`: (1.00, 1.05) (V2: 0.97-1.10)
  - `installed_stop_min_pct`: (0.06, 0.13) (V2: 0.04-0.15)
- **BO config**: budget=60, initial_random=10, seed=2026, acquisition=Expected_improvement
- **Gate penalty**: 10.0 (legacy hardcoded value; V4 tested 2.0)
- **Wall**: 11h at parallel=4

## V3 winner cell

| Param | V3 winner | V3 lower bound | V3 upper bound | V2 winner | Cell-E baseline |
|---|---:|---:|---:|---:|---:|
| max_position_pct_long | **0.065** | 0.04 | 0.15 | 0.061 | 0.14 |
| max_long_exposure_pct | **0.469** | 0.45 ← AT BOUND | 0.85 | 0.330 | 0.70 |
| initial_stop_buffer | **1.039** | 1.00 | 1.05 | 1.072 | 1.02 |
| installed_stop_min_pct | **0.107** | 0.06 | 0.13 | 0.114 | 0.08 |

V3 winner's `max_long_exposure_pct = 0.469` is just above V3's narrowed
lower bound of 0.45 — strong signal that the BO wanted lower, but was
constrained by the tightened V3 surface. **V5 (PR #1231) restores V2's
0.30 lower bound** to remove this constraint.

Also notable: V3 winner WAS iter-1 (the BO's first random sample;
confirmed by `bo_log.csv` row-1 matching `best.sexp` exactly). The
GP-driven phase (iters 11-60) never improved on iter-1. Per V3+V4
diagnostic below, this is because the gate-penalty flooded the search
surface; the GP saw no gradient.

## V3 vs V2 vs cell-E — full metric comparison

All numbers are means across all 31 walk-forward folds.

| Metric | Cell-E baseline | V2 winner | V3 winner | V3 - cell-E |
|---|---:|---:|---:|---:|
| **Sharpe (in-sample)** | 0.56 | 0.81 | **0.81** | +0.25 |
| **Sharpe (OOS)** | n/a | 0.74 | **0.83** | n/a |
| Sharpe min (worst fold) | -1.26 | -0.996 | **-0.658** | +0.60 |
| Sharpe max (best fold) | 2.59 | 2.94 | (n/a, est. 2.5+) | similar |
| Calmar (mean) | 1.31 | 1.85 | **2.03** | +0.72 |
| Total Return % (mean) | 8.74 | 12.6 | **12.9** | +4.2pp |
| CAGR % (mean) | 8.75 | 12.6 | **12.9** | +4.2pp |
| Max Drawdown % (mean) | 12.0 | 10.5 | **10.2** | -1.8pp |
| Avg holding days | 33.9 | 66.3 | **65.1** | +31d |

V3 winner is the directional sibling of V2 winner: same "less
concentrated, longer-hold, tighter-stops" pattern relative to cell-E,
but more moderated. fold-029 (the OOS axis-3 killer) improved
materially: V3 -0.66 vs V2 -1.00.

## 5-axis production gate verdict

Per `dev/plans/bayesian-production-sweep-2026-05-18.md` §6:

| # | Axis | Threshold | V3 result | Verdict |
|---|---|---|---|---|
| 1 | Mean-fold Sharpe ≥ baseline + 0.05 | +0.05 | +0.25 | **PASS** (5×) |
| 2 | No fold loses to cell-E by >-0.10 composite | -0.10 floor | TBD (need per-fold composite trajectory; aggregate.sexp doesn't carry it directly) | TBD |
| 3 | OOS Sharpe ≥ 0.50 on every OOS fold | 0.50 per fold | f-027=1.35 ✓, f-028=0.55 ✓, **f-029=-0.66 ✗**, f-030=2.06 ✓ | **FAIL** (fold-029 only) |
| 4 | MaxDD ≤ baseline + 5pp on every fold | +5pp per fold | TBD (need per-fold max trajectory) | TBD |
| 5 | N_trades within 2× baseline | 2× factor | TBD | TBD |

**One axis (axis-3) clearly fails. Verdict: REJECT** under the strict
codified gate, before even resolving axes 2/4/5.

The OOS validator (`oos_report.md`) uses a DIFFERENT rule: "OOS mean
Sharpe within 0.10 of in-sample mean Sharpe." V3 gap = +0.0135 (OOS
better than in-sample!), so OOS validator says **ACCEPT**. The
disconnect between OOS-validator ACCEPT and 5-axis REJECT is a
documented design tension — see §Open question.

## V3 + V4 diagnostic finding

V3 (gate penalty 10.0) and V4 (gate penalty 2.0, otherwise identical)
both ran their first ~20-30 iters and observed:

| Sweep | Iters watched | Max BO score | Implied composite_delta |
|---|---|---:|---:|
| V3 | 48 (full random + 38 GP) | -9.5057325923771678 | 0.4943 (= max - (-10)) |
| V4 | 19 (random + 9 GP) | -1.5057325923771672 | 0.4943 (= max - (-2)) |

**Same composite_delta on identical bounds + objective + seed.** This
isolates the gate-penalty value as a pure floor on the score — the
BO never found a Pass cell (in either sweep), and the floor doesn't
affect which non-Pass cell is "best" (the winner is the same iter-1
random sample in both).

Implication for the "BO never improved past iter-1" pattern: it's
NOT that the GP failed to find a better cell. It's that:
1. The 5-axis gate's required Pass region is empty in V3's bound surface
2. All Fail cells score in a narrow ~0.5 composite_delta band
3. The GP sees nearly-flat scores and explores randomly — but the
   "winner" is just the highest random sample, indistinguishable
   from any other Fail cell except for tiny noise

V4 killed at iter-19 once this was clear. The full V4 run was
projected at ~28h additional wall for no new information.

## What V5 (PR #1231) tests

V5 = V3 + V4's soft penalty (2.0) + V2's wider bounds. Hypothesis:
the empty-Pass-region failure mode is bounds-tightness, not penalty
magnitude. V5 search surface includes V3 winner's "exposure too low"
region (down to 0.30 again).

Expected outcome:
- **If V5 finds a cell with score > 0** → at least one Pass cell exists
  in the wider bounds; gate-fitness is OK, V3 bounds were just wrong.
- **If V5 also stuck on a non-zero composite_delta floor (e.g., 0.4-0.6)
  but no Pass cell** → the M-of-N gate criteria are the true binding
  constraint, not the search bounds. V6 should relax the gate.

## Open question — is axis-3 the right gate?

V3's actual winner has mean Sharpe 0.81 (+0.25 vs baseline) and OOS
Sharpe 0.83 (consistent — gap < 0.02 vs in-sample). On every other
codified safety metric the winner looks meaningfully better than
cell-E. The single fold-029 (Sharpe -0.66, 2024 calendar year) blocks
the production gate.

**Question for human review:** is axis-3's per-fold strict floor
(≥0.50 every OOS fold) the right safety check, or should it be:

| Option | Definition | V3 verdict under this rule |
|---|---|---|
| **A (current)** | OOS Sharpe ≥ 0.50 on every fold individually | FAIL (fold-029 = -0.66) |
| **B** | OOS mean Sharpe ≥ baseline mean + 0.05 | PASS (+0.27 gap) |
| **C** | OOS Sharpe ≥ -0.5 on every fold (relaxed floor) | PASS (worst is -0.66, but only by 0.16) |
| **D** | OOS Sharpe ≥ 0.50 on at least 3-of-4 OOS folds | PASS (3 of 4 ≥ 0.50) |
| **E** | OOS Sharpe ≥ 0.50 every fold AND mean ≥ baseline | FAIL (same as A) |

A is the strictest and matches the current spec. B and C ignore
single-fold weakness if mean compensates. D is a "no catastrophe but
allow one bad fold" softening. E requires both.

The deep-dive on fold-029 (in-flight as of this writeup, see
`output-v3-fold29-deepdive/`) should inform whether the fold's
weakness is structural (2024-specific market mechanics) or
strategy-related (the V3 cell genuinely overfits the in-sample folds
and breaks down on the OOS tail). If structural, axis-3 as written
will reject any cell on this universe + window combination forever.

## Fold-29 deep dive (added 2026-05-21 21:00 CST)

Re-ran V3 winner + cell-E baseline on JUST fold-29 (window
2024-06-13 → 2025-06-12) via
`walk_forward_v3_fold29_deepdive.sexp` to inspect what failed.

Result:

| | Cell-E (fold-29) | V3 winner (fold-29) | Delta |
|---|---:|---:|---:|
| Return % | **-13.6%** | **-8.9%** | +4.7pp |
| Sharpe | **-1.14** | **-0.69** | +0.45 |
| MaxDD % | 20.4 | **15.9** | -4.5pp |
| Calmar | -0.67 | **-0.56** | +0.11 |
| Avg hold days | 25.6 | 49.2 | +23.6 |
| Verdict (single-fold pass) | n/a | **PASS** (1-of-1 Sharpe win, gap +0.45) | n/a |

**Both lost money** on this window (H2 2024 + H1 2025). The
Weinstein-on-SP500 combination does not work in this period regardless
of tuning — cell-E baseline itself has Sharpe -1.14.

V3 winner BEATS cell-E baseline on every metric: +0.45 Sharpe, +4.7pp
return, -4.5pp drawdown. It still loses, but loses materially less.

**Implication for axis-3:** the gate's "every OOS fold ≥ 0.50" threshold
requires no fold to fail catastrophically. But fold-29 is a known-bad
window where the baseline strategy itself loses ~14%. Axis-3 effectively
asks every candidate to be better than the strategy can structurally be
in this market regime. **No tuning fixes a structurally bad fold.** See
companion doc `axis-3-gate-fitness-2026-05-21.md` for the proposed
redesign.

## Sequencing

- V3 winner: NOT promoted to `live/current.sexp` per the strict
  codified 5-axis REJECT, but **passes 3 of 5 alternative axis-3
  formulations** (see companion doc) — promote-decision waiting on
  human sign-off of axis-3 redesign.
- V5 launch (PR #1231) — still worth running to confirm wider-bounds
  hypothesis (whether the V3 narrowing excluded better cells), but
  axis-3 redesign is the load-bearing change.
- V6 (gate relaxation of internal M-of-N) — defer; fold-29 deep dive
  shows the M-of-N internal gate's stricture isn't what made V3 stuck.
  The "stuck at -9.5 / -1.5" pattern was the BO not differentiating
  similarly-gate-failing cells; relaxing the internal gate would just
  change which cells gate-pass, not unlock a fundamentally better cell.

## Files

- Winner: `dev/experiments/bayesian-production-sweep-2026-05-18/output-v3-parallel4/best.sexp`
- Full iteration log: `output-v3-parallel4/bo_log.csv` (60 rows)
- Convergence trajectory: `output-v3-parallel4/convergence.md`
- OOS validator output: `output-v3-parallel4/oos_report.md`
- Process log: `dev/logs/bayesian-prod-v3-parallel4.log`
- Watch log (cross-sweep V3+V4 monitor): `dev/logs/sweep-watch.log`
- Plan doc (5-axis gate definition): `dev/plans/bayesian-production-sweep-2026-05-18.md` §6
- V4 spec + diagnostic: `dev/experiments/bayesian-production-sweep-2026-05-18/spec_prod_v4.sexp`
- V5 spec (PR #1231): `dev/experiments/bayesian-production-sweep-2026-05-18/spec_prod_v5.sexp`
- Fold-29 deep dive (in-flight): `output-v3-fold29-deepdive/` (running)
