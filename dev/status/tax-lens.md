# Status: tax-lens

## Last updated: 2026-07-24

## Status
READY_FOR_REVIEW

## Owner
feat-backtest

## Open PR(s)
feat/tax-lens (#2006 Phase 1)

## Scope
After-tax performance lens (issue #2006) — a pure post-run report layer over an
existing scenario output dir (`trades.csv` + `equity_curve.csv`). No simulator
changes; no core-module edits. Surface lives at
`trading/trading/backtest/tax_lens/{lib,bin,test,configs}/`.

## Completed (2026-07-24) — Phase 1

- **[x] Report-layer exe** `trading/backtest/tax_lens/bin/tax_lens_bin.exe`.
  `--dir <scenario-dir> [--config <sexp>] [--out <file>]` → markdown report.
  Verify: build + run against any scenario dir with a `trades.csv` +
  `equity_curve.csv`.
- **[x] Two tax modes, all rates in sexp config** (`Tax_config`, no magic
  numbers): `mtm_flat` (rate) and `realized_st_lt` (st, lt, lt_days,
  carryforward). Example configs in `tax_lens/configs/`.
- **[x] Realization-basis model** (`Tax_model`): exit-year basis, year-end
  payment, in-year loss disallowed → carryforward pool offsetting ST gains
  first, after-tax path scaling tax by `at_start/pt_start`. Hand-fixture
  unit-tested (`test/test_tax_model.ml`, 6 tests) + `year_tax` offset-ordering.
- **[x] Days-to-LT diagnostic** (`Diagnostics.top_winners`): per-winner
  days_to_lt + raw ST-vs-LT boundary tax delta; measurement only, no exit
  mechanic. Unit-tested (`test/test_diagnostics.ml`).
- **[x] Carryforward trajectory** surfaced per-year in the report table.

### Acceptance numbers reproduced (integration checks)
- Run D `realized_st_lt (st 0.35)(lt 0.238)(lt_days 365)` + carryforward:
  **$80.14M → $26.84M** (CAGR 18.0% → 13.2%) — matches the awk prototype exactly.
- Run D `mtm_flat 0.35`: **$18.81M** (no carry) / **$21.80M** (carry) — exact.
- AXTI winner diagnostic: 336 days held, **29 days short of LT**, raw ST-vs-LT
  boundary delta **$7.38M** (path-scaled ≈ $2.7M, as noted in the issue).

## Follow-ups
- **Baseline-dir delta (flagged for maintainer):** on
  `scenarios-2026-07-23-162636/.../m4p-baseline` the same validated method gives
  **$87.89M → $31.18M**, not the issue's later approximate **$26.9M**. The model
  reproduces all three published Run-D numbers bit-exactly, so this is the
  issue's 07-23 "essentially unchanged" eyeball, not a model error — the extra
  final-year AXTI gain compounds more capital before the year-end tax, so
  after-tax rises above Run D's terminal. Confirm the intended baseline target.
- **Wash-sale adjustment:** deferred to a Phase-2 follow-up (optional per the
  issue). Not modeled here.
