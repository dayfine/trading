# M5.4 E3 — Stop-buffer sweep

8-cell sweep of `Weinstein_strategy.config.initial_stop_buffer` on the
canonical `goldens-sp500/sp500-2019-2023` window.

Plan: `dev/plans/m5-experiments-roadmap-2026-05-02.md` §M5.4 E3.
Hypothesis: see `hypothesis.md`.

## Status

Harness only — sweep has not been run yet. The 8 scenario sexps live at
`trading/test_data/backtest_scenarios/experiments/m5-4-e3-stop-buffer-sweep/`.

## Run metadata

- **Date harness landed**: 2026-05-03
- **Override**: `initial_stop_buffer` (top-level on `Weinstein_strategy.config`)
- **Grid**: `{1.00, 1.02, 1.05, 1.08, 1.10, 1.12, 1.15, 1.20}` (8 cells)
- **Window**: `2019-01-02` .. `2023-12-29` (full Weinstein cycle: 2019
  late-cycle advance → 2020 COVID crash → 2020-21 recovery → 2022 bear
  → 2023 rotation recovery)
- **Universe**: `universes/sp500.sexp` (491-symbol S&P 500 snapshot,
  same as canonical golden)
- **Initial cash**: $1,000,000 (inherited via Weinstein_strategy default)
- **Cell name format**: `m5-4-e3-buffer-1.XX`
- **Control within sweep**: `1.02` (matches current default); see also
  the canonical sp500-2019-2023 golden which is functionally identical.

## How to run

From repo root, with the docker dev container running:

```bash
docker exec <container> bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && \
   dune exec backtest/scenarios/scenario_runner.exe -- \
     --dir trading/test_data/backtest_scenarios/experiments/m5-4-e3-stop-buffer-sweep \
     --parallel 5'
```

Wall-clock estimate: ~5 cells in parallel × ~2h tier-3 budget per cell
= ~3-4h depending on host cores. Local-only — do not run in GHA.

The runner emits per-cell output under `dev/backtest/scenarios-<timestamp>/`:

```
dev/backtest/scenarios-YYYY-MM-DD-HHMMSS/
├── m5-4-e3-buffer-1.00/
│   ├── trades.csv
│   ├── equity_curve.csv
│   ├── summary.sexp
│   ├── stop_log.csv
│   └── ...
├── m5-4-e3-buffer-1.02/
└── ...
```

## What to look at when results come back

Pull the same metrics across all 8 cells from each `summary.sexp` and
build a comparison table similar to `dev/experiments/stop-buffer/report.md`'s
shape. Headline columns:

- **Total Return %**, **Sharpe Ratio**, **Calmar Ratio** — risk-adjusted
  performance ranking
- **Win Rate %**, **Avg Holding Days**, **Total Trades** — behavioral
  shape (whipsaw vs. ride-through)
- **Max Drawdown %** — risk side of the trade-off
- **Profit Factor**, **Expectancy** (from M5.2b once landed) — quality
  of trade selection
- **% trades exited within 1 day** — direct whipsaw measure (from
  trades.csv via M5.2e per-trade columns)

Then write `report.md` with:

1. Comparison table (all 8 cells × ~10 metrics)
2. Cell ranking on Sharpe + Calmar + Total Return
3. Verdict: which cell wins, by how much, with what error bars (compare
   against the canonical sp500-2019-2023 fuzz IQR from PR #788:
   +37.92%–+60.86%, Sharpe 0.41–0.56, MaxDD 31.28–35.99)
4. Followup: whether to promote the winner (re-pin baseline) or escalate
   to a multi-window robustness check before promoting

If signal-to-noise is too low (any cell within fuzz IQR of the control),
the verdict is **inconclusive** — escalate to a fuzz×grid joint sweep
once `--fuzz` × grid is wired.

## Why these grid points

See `hypothesis.md` §"Sweep grid" for the per-cell rationale. Summary:

- **1.00 / 1.20**: tail controls outside the book's 5–15% band
- **1.02**: current default — control cell within the sweep
- **1.05 / 1.08 / 1.10 / 1.12 / 1.15**: even spacing across the book's
  recommended band, with 1.05 / 1.08 / 1.12 / 1.15 mirroring the prior
  recovery-2023 sweep (2026-04-14) for cross-comparability

## Relationship to prior experiments

The 2026-04-14 study (`dev/experiments/stop-buffer/`) explored 5 cells
on a single recovery-2023 window. Its conclusion was **default stays at
1.02** because the single-regime sweep's verdict reversed on the
6-year golden. This M5.4 E3 sweep:

- Uses the multi-regime sp500-2019-2023 golden from the start (no
  single-window pitfall)
- Adds 3 new cells (1.00, 1.10, 1.20) for a wider grid
- Runs against the new canonical baseline (post-#744/#745/#746/#771)

If results re-confirm 1.02 as the optimum, the prior verdict stands. If
they promote a different cell, that's a baseline change requiring a
re-pin of the sp500-2019-2023 golden's expected ranges.

## Followups (out of scope for this PR)

- Run the sweep (local, by user)
- Write `report.md` with comparison table + verdict
- If a cell wins decisively: re-pin baseline, propagate to short-side
  golden + small-universe scenarios
- If signal is unclear: escalate to a `--fuzz` × grid joint sweep once
  the runner supports it (M5.4 follow-up)
- Cross-window robustness: re-run the winner on a 2008 GFC window once
  Norgate ingestion lands (M5.3)
