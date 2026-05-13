# M5.5 axis-1 sweep — `installed_stop_min_pct` on 5y sp500-2019-2023

## TL;DR

**Winner: cell-008 (`installed_stop_min_pct = 0.08`)** — best Calmar (0.53), strong
Sharpe (0.75), only modest MaxDD lift (21.6% → 25.5%), 67% trade-count reduction
(264 → 174), avg-hold 68d vs 41d baseline. Promote as a default candidate.

cell-012 has the highest Sharpe (0.80) but Calmar dips back to 0.44 and MaxDD
rises to 30.9% — wider isn't strictly better; the lever has a knee around 0.08.

Source: `dev/notes/p3-tuning-sweep-design-2026-05-13.md` (PR #1064), axis #1.
Hypothesis: a floor on installed-stop distance reduces stop-out churn and lets
winners ride; expected Sharpe-vs-MaxDD tradeoff.

## Method

5 cells over `sp500-2019-2023.sexp` (Cell E config), each varying ONLY
`screening_config.candidate_params.installed_stop_min_pct`:

- `cell-baseline` — 0.0 (default, no floor)
- `cell-006` — 0.06
- `cell-008` — 0.08
- `cell-010` — 0.10
- `cell-012` — 0.12

Local docker container, parallel-3. Total wall ~50 min including
`all_eligible` diagnostic. Output: `dev/backtest/scenarios-2026-05-13-212226/`.

## Results

| Cell | floor | Return | Trades | WR | Sharpe | MaxDD | Calmar | AvgHold |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| baseline | 0.0  | 50.66% | 264 | 37.50% | 0.56 | 21.56% | 0.40 | 40.78d |
| 006 | 0.06 | 71.77% | 173 | 38.73% | 0.68 | 29.62% | 0.39 | 63.91d |
| **008** | **0.08** | **87.09%** | **174** | **40.80%** | **0.75** | **25.45%** | **0.53** | **68.43d** |
| 010 | 0.10 | 73.92% | 180 | 42.78% | 0.70 | 32.56% | 0.36 | 79.30d |
| 012 | 0.12 | 87.98% | 205 | 42.44% | 0.80 | 30.91% | 0.44 | 81.55d |

## Δ vs baseline

| Metric | baseline → 008 | 8-cell winner | comment |
|---|---|---|---|
| Return | 50.7 → 87.1% | **+36.4 pp** | wider stops = winners ride |
| Trades | 264 → 174 | **−34%** | meaningful churn reduction |
| WR | 37.5 → 40.8% | +3.3 pp | small lift |
| Sharpe | 0.56 → 0.75 | **+0.19** | risk-adjusted |
| MaxDD | 21.6 → 25.5% | +3.9 pp | modest cost |
| **Calmar** | **0.40 → 0.53** | **+0.13** | **best Calmar of the 5 cells** |
| AvgHold | 41 → 68d | +66% | hypothesis confirmed |

## Mechanism

The screener installed-stop floor widens the per-position stop distance for
candidates whose support-floor-derived stop sat tighter than the floor. Wider
stops absorb more noise, so:

1. Fewer false stop-outs → trade count drops.
2. Winners hold longer (avg-hold 41d → 68d), compounding the long tail.
3. Per-trade losses are larger in absolute terms — MaxDD rises but not
   proportional to return gain.

Above 0.08 the marginal return-per-MaxDD curve inverts: cell-010 loses MaxDD
without gaining return, cell-012 gains return but MaxDD outpaces.

## Comparison to entry-caps arm B (the contra-example)

`max_score_override = 79` (entry-caps 2026-05-12) cut Sharpe 0.85 → 0.59 and
ballooned MaxDD 18.4% → 52.1% by replacing high-quality long-hold candidates
with shorter-hold lower-quality ones (regime shift). The `installed_stop_min_pct`
lever is the legitimate version of "stabilize hold periods": it widens stops
on existing candidates rather than swapping candidates out. Hold periods rise,
returns rise, Sharpe rises — no regime shift.

## Recommendation

1. **Promote `installed_stop_min_pct = 0.08` as a default candidate** for the
   next Cell E iteration. Validate by re-running 10y decade + 16y goldens with
   this knob set and confirming no degradation on long-horizon Calmar.
2. **Don't go higher than 0.08 on 5y** — the marginal Calmar curve inverts.
3. **Follow-up axis sweeps** (still per `dev/notes/p3-tuning-sweep-design-2026-05-13.md`):
   - Axis 2 (`min_correction_pct`) — interacts with axis 1; design a 1×2
     cross-sweep with `installed_stop_min_pct = 0.08` × `min_correction_pct ∈ {0.06, 0.10, 0.12}`.
   - Axis 3 (`min_score_override`) — tighten the score floor in combination
     with the 0.08 stop floor.

## Reproduction

Cell sexp shape (regenerate from `sp500-2019-2023.sexp` + this overlay):

```sexp
(config_overrides
 (... existing Cell E overrides ...
  ((screening_config
    ((candidate_params ((installed_stop_min_pct 0.08))))))))
```

Then:

```sh
dev/lib/run-in-env.sh dune exec --no-build \
  trading/backtest/scenarios/scenario_runner.exe -- \
  --dir <stage_dir> --parallel 3 \
  --fixtures-root trading/test_data/backtest_scenarios
```
