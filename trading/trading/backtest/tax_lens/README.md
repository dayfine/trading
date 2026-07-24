# tax_lens — after-tax performance lens (Phase 1, #2006)

A pure **post-run report layer** over an existing scenario output directory
(`trades.csv` + `equity_curve.csv`). It runs no simulation and touches no core
trading module — it re-reads the run's realized trades and pre-tax equity path
and projects an **after-tax** equity path under a configurable tax model.

## Run it

```bash
dune exec trading/backtest/tax_lens/bin/tax_lens_bin.exe -- \
  --dir <scenario-output-dir> \
  --config trading/backtest/tax_lens/configs/realized_st_lt.sexp
```

`--config` is optional (defaults to `realized_st_lt` ST 0.35 / LT 0.238 /
lt_days 365 with carryforward). `--out FILE` writes the markdown report to a
file instead of stdout. Every rate/threshold/toggle lives in the sexp config —
nothing is hardcoded.

## Model (pinned in issue #2006)

- **Realization basis** by exit-year from `trades.csv`; open positions defer —
  final-year unrealized gains are never taxed here.
- **Year-end payment** (April deferral not modeled).
- **Losses never deducted in-year** — under `carryforward` they accumulate a
  pool that offsets future gains, **ST gains first** (taxpayer-favourable).
- **Rates:** short-term `st_rate` (0.35); long-term `lt_rate` (0.238 = 20% LTCG
  + 3.8% NIIT) for holds `>= lt_days` (365).
- **After-tax path** scales each year's tax by the after-tax/pre-tax capital
  ratio `at_start / pt_start` — a smaller portfolio realizes proportionally
  smaller gains, so pays proportionally less; the tax is paid out of the
  compounding capital.
- Modes: `mtm_flat` (mark-to-market, whole equity change at `flat_rate`) and
  `realized_st_lt` (realization basis, ST/LT split).

## Diagnostics

- **Per-year carryforward trajectory** — the loss pool per year (whipsaw years
  pay $0 tax while accumulating it).
- **Top-winners days-to-LT at exit** — how far each big winner exited from the
  365-day LT boundary, and the raw ST-vs-LT boundary tax delta. Measurement
  only; no tax-aware exit mechanic is proposed (that would touch the exit spine).

## Validation (see PR / issue #2006)

The core `Tax_model.simulate` is unit-tested against a fully hand-computed
3-year fixture. Integration checks reproduce the awk-prototype numbers on the
Run D record-convention dir bit-exactly: `realized_st_lt` + carryforward
$80.14M → $26.84M; `mtm_flat 0.35` $18.81M (no carry) / $21.80M (carry).
