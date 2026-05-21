# V5 Bayesian production sweep — partial result + hypothesis rejection (2026-05-22)

V5 sweep launched 2026-05-21 22:07 CST, killed 2026-05-22 01:36 CST at
iter-18/60 (after 3.5h wall, ~4h+ ahead of forecast end). Kill was
deliberate: the GP-phase trajectory was clearly regressing relative
to the best random sample, replicating V3's "best=iter-1" pattern.
Continued running would have consumed ~7h more CPU for a 60-iter
completeness data point with no remaining decision value.

## TL;DR

The "V3 narrowed bounds excluded a Pass region" hypothesis (V5's
load-bearing reason for existing) is **REJECTED**. V5's wider bounds
(restored to V2's full range) produced a TIGHTER score distribution
than V3's narrow bounds, and the GP phase regressed on every
iteration — no cell crossed the gate-fail floor at composite_delta
> 0.5 (= score > -1.5 under V5's gate_penalty_value=2.0). V6 (in
flight as of this writeup) tests the remaining hypothesis:
gate-too-strict (M-of-N internal gate `worst_delta=0.30 → 0.50`).

## What V5 changed vs V3

- **Bounds restored to V2-wide** (4 axes):
  - `max_position_pct_long`: V3 (0.04, 0.15) → V5 (0.02, 0.20)
  - `max_long_exposure_pct`: V3 (0.45, 0.85) → V5 (0.30, 0.95)
  - `initial_stop_buffer`: V3 (1.00, 1.05) → V5 (0.95, 1.10)
  - `installed_stop_min_pct`: V3 (0.06, 0.13) → V5 (0.04, 0.15)
- **Gate penalty soft** (carried from V4): `gate_penalty_value = 2.0`
  (vs V3's hardcoded 10.0). Doesn't change which cell is best; only
  preserves signal magnitude in the score.

Everything else identical to V3: same seed (2026), same 60 budget,
10 random + 50 GP, same Composite (Sharpe 0.40 + Calmar 0.30 +
MaxDD -0.10), same walk-forward spec (`walk_forward_v2_baseline.sexp`),
same baseline (cell-E), same 4 OOS holdouts.

## V5 trajectory (iter 0-17, killed at iter-18)

### Random phase (iters 0-10)

| Iter | Metric | Composite_delta |
|---:|---:|---:|
| 0 | -1.71 | 0.29 |
| 1 | **-1.59** | **0.41** |
| 2 | -1.80 | 0.20 |
| 3 | -1.65 | 0.35 |
| 4 | -1.74 | 0.26 |
| 5 | -1.77 | 0.23 |
| 6 | -1.71 | 0.29 |
| 7 | -1.63 | 0.37 |
| 8 | -1.67 | 0.33 |
| 9 | -1.66 | 0.34 |
| 10 | -1.77 | 0.23 |

Random phase range: **composite_delta [0.20, 0.41]**, spread 0.21.

### GP phase (iters 11-17)

| Iter | Metric | Composite_delta | vs random best (0.41) |
|---:|---:|---:|---:|
| 11 | -1.95 | 0.05 | -0.36 |
| 12 | -1.92 | 0.08 | -0.33 |
| 13 | -1.78 | 0.22 | -0.19 |
| 14 | -1.74 | 0.26 | -0.15 |
| 15 | -2.10 | -0.10 | -0.51 |
| 16 | -1.87 | 0.13 | -0.28 |
| 17 | -1.83 | 0.17 | -0.24 |

**No GP iter beat the best random sample.** Best GP cell
(iter-14, composite_delta 0.26) is well below the random-phase
winner (iter-1, 0.41).

## Comparison to V3

| | V3 | V5 |
|---|---|---|
| Bounds | tight (post-V2 narrowing) | wide (V2-style restored) |
| Random phase composite_delta range | [0.13, 0.49] | [0.20, 0.41] |
| Random phase spread | 0.36 | 0.21 |
| Best random (= winner in both cases) | 0.49 (iter-1) | 0.41 (iter-1) |
| GP-phase improvement | NONE (all 50 GP iters at floor) | NONE (all 7 GP iters worse than random) |
| Pass cell (composite_delta > 0.5) found? | NO | NO |

Counterintuitive observation: **V5's wider bounds produced a TIGHTER
score distribution than V3's narrow bounds.** Strong signal that the
gate-fail penalty is dominating regardless of where in the surface
BO samples — every cell triggers the same M-of-N gate-fail verdict
and the composite signal can't differentiate them.

V5's winner cell (iter-1) has composite_delta 0.41 vs V3 winner's
0.49 — V5 is slightly WORSE than V3. The wider bounds didn't find a
better region; they sampled the same plateau more uniformly.

## Hypothesis status

| Hypothesis | Test | Verdict |
|---|---|---|
| Gate penalty value (10.0) drowns composite signal | V3 → V4 (soft gate=2.0) | **REJECTED** — same composite_delta lock |
| V3 narrowed bounds excluded a Pass region | V3 → V5 (wider bounds) | **REJECTED** — same plateau, no Pass cells |
| M-of-N internal gate (worst_delta=0.30) too strict | V5 → V6 (worst_delta=0.50) | **IN FLIGHT** — V6 launched 2026-05-22 01:36 CST |
| Strategy + universe combination has no Pass region at all | If V6 also fails | TBD |

## Implications

If V6 (worst_delta=0.50) ALSO produces no Pass cell:
- Strategy mechanics or universe choice are the binding constraints,
  not parameter-space topology.
- Options: change strategy mechanics (continuation buys, sector caps,
  short-side rules), change universe (broader / different), or relax
  the gate threshold further (worst_delta → 1.0 or pure mean check).

If V6 surfaces a Pass cell:
- Internal gate criteria (`worst_delta=0.30`) was the binding
  constraint. Production gate should follow suit (the external 5-axis
  gate's axis-3 was already proposed to be relaxed to "relative
  floor" per `axis-3-gate-fitness-2026-05-21.md`).
- V3 winner already accepted under Option E external gate; V6 winner
  might be a strictly better cell to promote instead.

## Files

- V5 spec: `dev/experiments/bayesian-production-sweep-2026-05-18/spec_prod_v5.sexp` (in PR #1231)
- V5 output (killed at iter-18): `dev/experiments/bayesian-production-sweep-2026-05-18/output-v5-parallel4/`
- V5 process log: `dev/logs/bayesian-prod-v5-parallel4.log`
- V5 watcher log: `dev/logs/v5-watch.log`
- V6 spec: `dev/experiments/bayesian-production-sweep-2026-05-18/spec_prod_v6.sexp` (will land in this PR or follow-up)
- V6 walk-forward: `dev/experiments/bayesian-production-sweep-2026-05-18/walk_forward_v6_baseline.sexp` (will land in this PR or follow-up)
- V6 output (in flight): `dev/experiments/bayesian-production-sweep-2026-05-18/output-v6-parallel4/`
