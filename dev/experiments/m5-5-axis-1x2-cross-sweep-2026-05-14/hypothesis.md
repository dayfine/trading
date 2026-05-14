# M5.5 axis-1 × axis-2 cross-sweep — hypothesis

Date: 2026-05-14
Scenario: `sp500-2019-2023.sexp` (Cell E config, shorts ON)

## Setup

- **Axis-1 winner** (PR #1079): `screening_config.candidate_params.installed_stop_min_pct = 0.08`. On 5y Cell E:
  Calmar 0.40 → 0.53 (+0.13). MaxDD 21.6 → 25.5 (worsens).
- **Axis-2 winner** (PR #1083): `stops_config.min_correction_pct = 0.10`. On 5y Cell E:
  Calmar 0.40 → 0.77 (+0.37). MaxDD 21.6 → 18.4 (improves).

Both individually beat baseline on Calmar; axis-2 dominates on MaxDD.

## Cells

| Cell         | installed_stop_min_pct | min_correction_pct |
|--------------|------------------------|--------------------|
| baseline     | default (0.0)          | default (0.08)     |
| axis-2-only  | default (0.0)          | 0.10               |
| combined     | 0.08                   | 0.10               |

(Axis-1-only is already pinned in PR #1079, replicated here only via #1079's reported numbers.)

## Hypothesis

Combined Calmar reaches ~0.90+ if axes are additive — axis-1 raises the
installed-stop floor (entry-side risk), axis-2 widens the trailing
support-floor + buffer (in-trade risk). Plausibly orthogonal levers
acting on distinct stop-machine stages.

## Falsifiable predictions

- **Additive**: combined Calmar ≥ max(axis-1-only, axis-2-only) + 0.05 → promote `combined`
- **Dominated**: combined Calmar within ±0.05 of axis-2-only → promote axis-2-only (simpler)
- **Destructive**: combined Calmar < axis-2-only by > 0.05 → keep axis-2-only, investigate interaction

## Risk

Both overlays target the stop-machine. axis-1 floors the *installed* stop
percentage at entry; axis-2 floors the *correction percentage* used by the
trailing stop. If axis-2's wider corrections subsume axis-1's floor (i.e.
the trailing stop is always more relaxed than the installed floor in
practice), combining will double-count slack without further benefit.

---

# Results (recorded post-run, 2026-05-14)

Output: `dev/backtest/scenarios-2026-05-14-013815/`. All 3 cells PASS the
(wide BASELINE_PENDING-style) expected ranges. Local docker, parallel-3.

| Cell | Return | Trades | WR | Sharpe | MaxDD | Calmar | Sortino | AvgHold |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| baseline | 50.66% | 264 | 37.50% | 0.56 | 21.56% | 0.40 | 0.75 | 40.78d |
| **axis-2-only** | **93.76%** | **195** | **36.41%** | **0.88** | **18.36%** | **0.77** | **1.35** | **56.05d** |
| combined | 47.38% | 176 | 37.50% | 0.50 | 31.24% | **0.26** | 0.65 | 69.24d |
| _axis-1-only (PR #1079 ref)_ | _87.1%_ | _174_ | _40.8%_ | _0.75_ | _25.5%_ | _0.53_ | — | _68.4d_ |

## Δ vs axis-2-only (does combining help?)

- Return 93.8 → 47.4% (**−46.4 pp**)
- Sharpe 0.88 → 0.50 (**−0.38**)
- MaxDD 18.4 → 31.2% (**+12.9 pp**)
- Calmar 0.77 → 0.26 (**−0.51**)
- Sortino 1.35 → 0.65 (−0.70)

Combining strictly dominates axis-2-only on the wrong side of every
risk-adjusted metric. Drops far exceed the PR #788 fuzz noise band.

## Verdict: DESTRUCTIVE

Combined Calmar 0.26 vs axis-2-only 0.77. Per the falsifiable prediction
above (additive ≥ +0.05, dominated within ±0.05, destructive < −0.05),
the cell lands clearly in "destructive."

## Mechanism

Both axes widen the stop. Stacked, the effective stop is widened twice
(installed floor + trailing-correction floor). Symptoms:

- Avg-hold longest of all cells (69d vs 41d baseline) — both levers
  individually lengthen holds.
- Avg-loss% widens 46% (−4.19 → −6.13%) — each stop-out is deeper.
- Ulcer 8.41 → 13.96, Pain 6.20 → 9.85, worst-year −11.6% → −20.3%.
- Win rate unchanged (37.5%) — same names, just bigger losses.

axis-2 alone works because the un-floored installed stop still exits
losers tight on the first leg while the wider trailing buffer protects
against support-level whipsaws. Adding axis-1's installed-stop floor
removes the early-exit safety net — positions now carry **both** a slack
initial stop and a slack trailing stop. The two levers are redundant on
the same risk dimension (stop slack); they don't combine, they compound
the hazard.

## Recommendation

1. **Promote `stops_config.min_correction_pct = 0.10` as the Cell E
   default** (axis-2-only). Single best lever in the M5.5 sweep on 5y.
2. **Do NOT also set `installed_stop_min_pct = 0.08`.** PR #1079's lift
   is real but doesn't stack; axis-2-only beats axis-1-only head-to-head
   (Calmar 0.77 vs 0.53).
3. **Validate axis-2-only on 10y decade + 16y long-only** before pinning.
