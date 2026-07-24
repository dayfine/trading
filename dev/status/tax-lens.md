# Status: tax-lens

## Last updated: 2026-07-24

## Status
MERGED

## Interface stable
YES

## Owner
feat-backtest

## Open PR(s)
— (Phase 1 merged 2026-07-24 as #2066; Phase 2 wash-sale / in-sim April outflows deferred, user-gated per issue #2006)

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
- **Baseline-dir delta — RESOLVED (2026-07-24):** on
  `scenarios-2026-07-23-162636/.../m4p-baseline` the exe gives
  **$87.89M → $31.18M**; an independent dispatcher-side awk re-derivation gives
  $31.15M on the same dir. The issue's earlier **$26.9M** reference was the
  erroneous number (an "essentially unchanged vs Run D" eyeball); correction
  posted on issue #2006. Corrected headline: pre-tax $87.9M → after-tax ≈$31.2M
  (CAGR 18.4% → ~13.9%).
- **Wash-sale adjustment:** deferred to a Phase-2 follow-up (optional per the
  issue). Not modeled here.
