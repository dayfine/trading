# M5.4 E4 — Scoring-weight sweep

8-cell sweep of `Weinstein_strategy.config.screening_config.weights`
(the `Screener.scoring_weights` record) on the canonical
`goldens-sp500/sp500-2019-2023` window.

Plan: `dev/plans/m5-experiments-roadmap-2026-05-02.md` §M5.4 E4.
Hypothesis: see `hypothesis.md`.

## Status

Harness only — sweep has not been run yet. The 8 scenario sexps live at
`trading/test_data/backtest_scenarios/experiments/m5-4-e4-scoring-weight-sweep/`.

## Run metadata

- **Date harness landed**: 2026-05-03
- **Override**: `screening_config.weights.*` (one or two fields per cell)
- **Window**: `2019-01-02` .. `2023-12-29` (full Weinstein cycle: 2019
  late-cycle advance → 2020 COVID crash → 2020-21 recovery → 2022 bear
  → 2023 rotation recovery)
- **Universe**: `universes/sp500.sexp` (491-symbol S&P 500 snapshot,
  same as canonical golden)
- **Initial cash**: $1,000,000 (inherited via Weinstein_strategy default)
- **Cell name format**: `m5-4-e4-<axis>` (e.g. `m5-4-e4-stage-heavy`)
- **Control within sweep**: `baseline` (zero overrides; functionally
  equivalent to the canonical sp500-2019-2023 golden)

## Cells

| Cell | Override | Tests |
|---|---|---|
| `baseline` | (none) | Control / sanity check vs canonical golden |
| `equal-weights` | 4 primary axes all = 20 | Whether weight hierarchy matters at all |
| `stage-heavy` | `w_stage2_breakout=60` (2x) | Stage-transition signal dominance |
| `volume-heavy` | `w_strong_volume=40, w_adequate_volume=20` (2x) | Volume confirmation weight |
| `rs-heavy` | `w_positive_rs=40, w_bullish_rs_crossover=20` (2x) | Relative-strength leadership weight |
| `resistance-heavy` | `w_clean_resistance=30` (2x) | Clean-overhead breakout weight |
| `sector-heavy` | `w_sector_strong=20` (2x) | Sector context bonus |
| `late-stage-strict` | `w_late_stage2_penalty=-30` (2x harsher) | Late-stage penalty severity |

All other weights remain at default
(`Screener.default_scoring_weights`). The "2x default" choice is uniform
across positive-weight cells so the magnitude axis stays comparable.

## How to run

From repo root, with the docker dev container running:

```bash
docker exec <container> bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && \
   dune exec backtest/scenarios/scenario_runner.exe -- \
     --dir trading/test_data/backtest_scenarios/experiments/m5-4-e4-scoring-weight-sweep \
     --parallel 5'
```

Wall-clock estimate: ~5 cells in parallel × ~2h tier-3 budget per cell
= ~3-4h depending on host cores. Local-only — do not run in GHA.

The runner emits per-cell output under `dev/backtest/scenarios-<timestamp>/`:

```
dev/backtest/scenarios-YYYY-MM-DD-HHMMSS/
├── m5-4-e4-baseline/
│   ├── trades.csv
│   ├── equity_curve.csv
│   ├── summary.sexp
│   ├── stop_log.csv
│   └── ...
├── m5-4-e4-stage-heavy/
└── ...
```

## What to look at when results come back

Pull the same metrics across all 8 cells from each `summary.sexp` and
build a comparison table. Headline columns:

- **Total Return %**, **Sharpe Ratio**, **Calmar Ratio** — risk-adjusted
  performance ranking
- **Win Rate %**, **Avg Holding Days**, **Total Trades** — behavioural
  shape (selectivity vs activity)
- **Max Drawdown %** — risk side
- **Profit Factor**, **Expectancy** (from M5.2b once landed) — quality
  of trade selection
- **% trades originating from each axis-dominant grade band** — reveals
  WHICH candidates actually changed ranking, distinguishing
  "score moved but symbols stayed" from "different symbols entered
  top-20"

Then write `report.md` with:

1. Comparison table (all 8 cells × ~10 metrics)
2. Cell ranking on Sharpe + Calmar + Total Return
3. Verdict: which axis dominates (if any), by how much, with what
   error bars (compare against the canonical sp500-2019-2023 fuzz IQR
   from PR #788: +37.92%–+60.86%, Sharpe 0.41–0.56, MaxDD 31.28–35.99)
4. Followup: feed the dominant axis (if found) into M5.5 T-A grid
   search as the prior; if no axis dominates, the tuner runs the full
   4-D grid with the noise floor from this sweep informing early-stop

If signal-to-noise is too low (any cell within fuzz IQR of the
control), the verdict is **inconclusive** — escalate to a fuzz×grid
joint sweep once that's wired.

## Why these cells

See `hypothesis.md` §"Sweep grid" for the per-cell rationale. Summary:

- **`baseline`**: zero overrides → reproduces canonical golden;
  control cell within the sweep.
- **`equal-weights`**: meta-cell that tests whether the four-axis
  hierarchy produces a different selection at all. If equal ≈ baseline
  → tuning weights is the wrong knob; redirect to grade thresholds /
  candidate caps / pricing.
- **`stage-heavy` / `volume-heavy` / `rs-heavy` / `resistance-heavy`**:
  the four primary positive-signal axes from the cascade scoring
  function. Doubling each in turn isolates per-axis signal.
- **`sector-heavy`**: fifth axis (sector bonus); included for
  completeness even though the upstream sector pre-filter already does
  most of the sector work.
- **`late-stage-strict`**: the only negative weight in the default;
  doubling its severity tests the symmetric question (does penalising
  bad setups matter as much as rewarding good ones?). Likely the
  cleanest predicted effect.

## Config-surface gaps (none blocking)

The eight `scoring_weights` fields on `Screener.config.weights` are all
independently tunable via `(config_overrides (((screening_config ((weights
((<field> <value>))))))))`. The runner's deep-merge primitives
(`Backtest.Runner._merge_sexp`) handle partial-record overlays — only
the changed weight fields need to appear in the override sexp; the
others inherit from `Screener.default_scoring_weights`.

No structural gap was discovered while writing this harness; the cascade
is fully tunable on these axes. The 81-cell grid envisioned by the plan
(§M5.4 E4) is mechanically buildable today; the only reason to do this
8-cell prequel first is to constrain the search before paying for it.

## Relationship to prior experiments

- **E3 stop-buffer sweep** (`dev/experiments/m5-4-e3-stop-buffer-sweep/`,
  PR #815): orthogonal axis (stop-distance, not score). E3 + E4
  together cover the two cheapest single-knob tunings before the M5.5
  tuner lands.
- **stop-buffer 2026-04-14**
  (`dev/experiments/stop-buffer/`): pre-canonical-baseline; superseded
  by E3.
- No prior scoring-weight experiments exist in the repo. This is the
  first.

## Followups (out of scope for this PR)

- Run the sweep (local, by user or follow-up agent)
- Write `report.md` with comparison table + verdict
- If a single axis dominates: redirect M5.5 T-A grid search to 1-D on
  that axis (cheap)
- If multiple axes have signal: run M5.5 T-A as full 4-D grid (3×3×3×3
  = 81 cells) with this sweep's noise floor as the early-stop
  threshold
- If no axis dominates: redirect tuning effort to grade thresholds,
  `candidate_params`, or structural cascade changes
- Cross-window robustness: re-run the dominant-axis cell on a 2008 GFC
  window once Norgate ingestion lands (M5.3)
