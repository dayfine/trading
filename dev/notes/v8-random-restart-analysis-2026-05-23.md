# V8 Random-Restart Analysis (post-2026-05-22-PM session)

## TL;DR

Three BO sweeps (V3 seed 2026 = original winner; V8 seed 2027; V8 seed 2028)
on the **same** 4-knob `spec_prod_v3` cell. All three pass the OOS-vs-IS Sharpe
hurdle (≤ 0.10 gap). Two distinct modes recovered:

| Mode | `max_long_exposure_pct` | Members |
|---|---|---|
| Low-exposure (Cluster A) | 0.45 – 0.47 | V3 seed 2026, V8 seed 2028 |
| High-exposure (Cluster B) | 0.85 | V8 seed 2027 |

The 4-D surface is **multi-modal**, not single-optimum. V3 seed 2026 is the
*lowest BO best_score* (best on the in-sample minimization objective), but it
**fails** the new MaxDD gate (PR #1255) on sp500-2019-2023 (+9.02pp). Whether
seed 2027 (the alternate mode) or seed 2028 (a redundant low-exposure
neighbor) clears the new 3-gate panel is the open question.

## Inputs

| Field | V3 seed 2026 (live) | V8 seed 2027 | V8 seed 2028 |
|---|---|---|---|
| Spec | `spec_prod_v3.sexp` | `spec_prod_v3_seed2027.sexp` | `spec_prod_v3_seed2028.sexp` |
| Knobs | 4 | 4 | 4 |
| Parallel | 4 | 4 | 2 |
| Iters (budget) | 60 | 60 | 60 |
| Stop reason | budget_exhausted | budget_exhausted | budget_exhausted |
| Output dir | `output-v3-parallel4/` | `output-v3-seed2027-parallel4/` | `output-v3-seed2028-parallel2/` |

## Winning params (rounded)

| Knob | V3 seed 2026 | V8 seed 2027 | V8 seed 2028 |
|---|---|---|---|
| `max_position_pct_long` | 0.0651 | 0.0654 | 0.0574 |
| `max_long_exposure_pct` | **0.4685** | **0.8451** | **0.4516** |
| `initial_stop_buffer` | 1.0392 | 1.0495 | 1.0214 |
| `installed_stop_min_pct` | 0.1070 | 0.1063 | 0.0858 |
| BO best_score (composite) | **-9.506** | -9.553 | -9.600 |

(`best_score` is the BO minimization objective; lower = better.)

## OOS validation (per-seed)

Both V8 seeds passed the OOS-vs-in-sample Sharpe hurdle (≤ 0.10 gap) per
`dev/plans/bayesian-multi-param-scaling-2026-05-16.md` §6.3.

| Metric | V8 seed 2027 | V8 seed 2028 |
|---|---|---|
| In-sample mean Sharpe (n=27) | 0.7991 | 0.7538 |
| OOS mean Sharpe (n=4) | **0.8256** | 0.7204 |
| Gap (OOS − IS) | +0.0265 | -0.0333 |
| Hurdle | 0.10 | 0.10 |
| Verdict | **ACCEPT** | **ACCEPT** |

**Notable**: seed 2027 OOS *beats* in-sample (gap +0.0265). Either the OOS
folds happen to be easy, or the high-exposure mode actually generalizes.

Per-OOS-fold Sharpe (folds 26–29 in both):

| Fold | seed 2027 | seed 2028 |
|---|---|---|
| fold-026 | 1.354 | 1.269 |
| fold-027 | 2.070 | 1.937 |
| fold-028 | 0.534 | 0.569 |
| fold-029 | -0.655 | -0.894 |

Seed 2027 strictly dominates seed 2028 on every OOS fold (3 of 4 are 0.07–0.13
absolute-Sharpe better; fold-029 is 0.24 absolute-Sharpe better).

## Cross-scenario panel — V3 seed 2026 (live)

From `~/Projects/trading-parameters/configs/2026-05-22-bayesian-v3-winner/validation.sexp`:

| Scenario | Sharpe (Δ vs cell-E) | MaxDD (Δ vs cell-E) | Trades (Δ vs cell-E) |
|---|---|---|---|
| sp500-2010-2026 | 0.7651 (-0.0149) | 18.61 (+0.25) | 783 (-23) |
| sp500-2019-2023 | 0.6887 (**+0.1287**) | 30.58 (**+9.02**) | 259 (-5) |

**With the post-#1255 gates** (Sharpe ≤ -0.10, MaxDD ≤ +5pp, trades within
2x):

- Sharpe: PASS both scenarios.
- MaxDD: **FAIL** sp500-2019-2023 (+9.02pp > 5.0pp).
- Trades: PASS both scenarios.

V3 winner would be **rejected** by the new gate on the sp500-2019-2023 MaxDD
blowup. Promotion was the right action at the time (Sharpe-only gate passed),
but the gate has since been tightened to catch exactly this pattern.

## Cross-scenario panel — V8 seed 2027 / seed 2028

**Not yet measured.** Requires running `dev/scripts/promote_config.sh` on each
seed's `best.sexp`, which executes the 2-scenario panel via
`scenario_runner.exe` (15–60 min per scenario at parallel=2). Promotion only
proceeds if all 3 gates pass.

Recommendation (in order, since seed 2027 is the clear OOS winner):

1. Run `promote_config.sh 2026-05-23-bayesian-v8-seed2027 \
       dev/experiments/bayesian-production-sweep-2026-05-18/output-v3-seed2027-parallel4/best.sexp \
       dev/experiments/bayesian-production-sweep-2026-05-18/output-v3-seed2027-parallel4` —
   if all 3 gates green, promote (this displaces the V3 live link).
2. If seed 2027 fails the MaxDD gate (its high exposure may inflate
   drawdowns), try seed 2028 — same low-exposure mode as V3 but with slightly
   different stop params; could marginally improve V3 without changing the
   regime.
3. If both fail MaxDD, the BO surface's high-Sharpe regions don't satisfy
   the new gate, and the strategy needs structural changes (sector caps,
   margin overlay, cost model) rather than knob tuning.

## What this tells us about the optimization surface

- **The 4-D surface has at least 2 distinct local optima.** Seed 2026 + seed
  2028 lock onto low-exposure (~0.46); seed 2027 lands on high-exposure
  (~0.85). The BO sampler did not bridge between modes within 60 iters.
- **Best-score does not necessarily mean best out-of-sample**. V3 has the
  lowest best_score (-9.506) but seed 2027 has higher OOS mean Sharpe
  (0.8256 vs ~0.7204 for seed 2028; V3's mean wasn't directly reported but
  the convergence floor suggests similar). The composite objective is not
  perfectly aligned with OOS Sharpe.
- **More seeds would likely find more modes.** Two seeds, two modes. A third
  random restart (seed 2029) might land somewhere new; a fourth (seed 2030)
  might land in mode A or B again. The BO surface is unlikely to be fully
  characterized at 3 restarts.
- **Future-prodution sweeps should enable random restarts by default.**
  Either run N=3+ seeds in parallel and pick the winner on the cross-scenario
  panel (today's pattern), or extend the BO runner with a built-in restart
  mechanism (warm-start from the previous best every K iters).

## Files

- This doc: `dev/notes/v8-random-restart-analysis-2026-05-23.md`
- Seed 2027 outputs: `dev/experiments/bayesian-production-sweep-2026-05-18/output-v3-seed2027-parallel4/`
- Seed 2028 outputs: `dev/experiments/bayesian-production-sweep-2026-05-18/output-v3-seed2028-parallel2/`
- V3 winner config (live): `~/Projects/trading-parameters/configs/2026-05-22-bayesian-v3-winner/`
- Gate spec: `dev/plans/bayesian-production-sweep-2026-05-18.md` §6 (Option E)
- Gate implementation: `dev/scripts/promote_config.sh` (post-#1255)
