# Status: tax-lens

## Last updated: 2026-07-24

## Status
READY_FOR_REVIEW

## Interface stable
YES

## Owner
feat-backtest

## Open PR(s)
- #2073 — test-only: pins `Loader.load_exn` error-path contract (Phase-1
  qc-behavioral CP4 follow-up). Not yet merged.
- (Phase 1 merged 2026-07-24 as #2066; Phase 2 wash-sale / in-sim April outflows deferred, user-gated per issue #2006)

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

## Completed (2026-07-24) — Phase 1 follow-up (CP4 gap)

- **[x] `Loader.load_exn` error-path tests** — PR #2073,
  `trading/backtest/tax_lens/test/test_loader.ml` (new, 6 tests). Closes the
  qc-behavioral CP4 non-blocking note on #2066: `Loader` had zero tests, so
  the `.mli`'s "Raises if either file is missing or malformed" claim was
  entirely unpinned. Pins: dir missing, `trades.csv` missing,
  `equity_curve.csv` missing, malformed `trades.csv` row, malformed
  `equity_curve.csv` first row, plus a happy-path fixture (row counts + field
  spot-checks) so the raise tests can't pass vacuously. Fixtures are written
  to a fresh `Filename_unix.temp_dir` at runtime — no committed fixture data.
  **Discovered + fixed a docstring/code mismatch**: `Loader._trade_of_line`
  silently dropped malformed-arity `trades.csv` rows via `List.filter_map`
  instead of raising; fixed with the smallest change (`filter_map` → `map` +
  explicit `failwithf` on non-matching rows) in `loader.ml`. No `.mli` change
  needed. Verify: `dune runtest trading/backtest/tax_lens/`.

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
