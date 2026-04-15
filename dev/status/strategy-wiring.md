# Status: strategy-wiring

## Last updated: 2026-04-14

## Status
IN_PROGRESS — ready for pickup

## Ownership
`feat-weinstein` agent — see `.claude/agents/feat-weinstein.md`. This
reopens the feat-weinstein scope for two narrow wiring items that hand
off cached data to macro inputs already declared in
`Weinstein_strategy.config`. Base strategy code itself is unchanged.

## Interface stable
YES — no new public types or module boundaries. Changes are confined to
`Ad_bars.load` (façade composition) and a new `default_global_indices`
constant in `Macro_inputs`.

## Blocked on
- None. Both cached data sources are on disk.

## Summary
Two macro inputs declared in `Weinstein_strategy.config` are not populated
at runtime. Pure-function modules already exist on main; what remains is
composition inside `Ad_bars.load` and constant/override wiring in the
backtest runner.

## Current wiring (origin/main)

| input                       | module             | loader wired      | populated     |
| --------------------------- | ------------------ | ----------------- | ------------- |
| `ad_bars` (Unicorn)         | `Ad_bars.Unicorn`  | runner.ml:96      | YES (1965-2020-02-10) |
| `ad_bars` (Synthetic)       | `Synthetic_adl`    | NO                | NO            |
| `sector_etfs`               | `Macro_inputs.spdr_sector_etfs` | runner.ml:101 | YES |
| `indices.global`            | (no constant)      | NO                | NO (empty list) |

References:
- `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml:36` — default `indices.global = []`
- `trading/trading/weinstein/strategy/lib/ad_bars.mli:39-43` — façade delegates to Unicorn only
- `trading/trading/backtest/lib/runner.ml:96-103` — deps wiring
- `trading/analysis/weinstein/breadth/lib/synthetic_adl.mli` — synthetic module already on main

## Completed
- None yet in this scope.

## In Progress
- None yet in this scope.

## Next Steps (work items)

### Item 1 — compose Synthetic ADL into `Ad_bars.load` façade

Scope: `trading/trading/weinstein/strategy/lib/ad_bars.{ml,mli}`.

- Add `Synthetic` submodule or a direct call to the synthetic compute.
  Output path convention from `compute_synthetic_adl.exe`:
  `data/breadth/synthetic_nyse_advn.csv` + `_decln.csv`.
- `load ~data_dir` composes Unicorn (1965-02-10 → 2020-02-10) with
  Synthetic (2020-02-11 → present), dedupes by date, returns single
  chronologically-sorted `Macro.ad_bar list`.
- Unit tests: date ranges don't overlap, correct source wins on overlap
  (prefer Unicorn for golden dates), correct ordering.
- Validation: one-off run of `Synthetic_adl.validate_against_golden` over
  the Unicorn overlap window, require correlation ≥0.85. Record result in
  `dev/notes/synthetic-adl-validation.md`.

Estimated: ~80 lines + tests.

### Item 2 — populate `indices.global`

Scope: `trading/trading/weinstein/strategy/lib/macro_inputs.ml` +
`trading/trading/backtest/lib/runner.ml`.

- Define `default_global_indices : (string * string) list` in
  `Macro_inputs`. Candidates already implied by cached bars: confirm which
  global indices exist in `data/` and pick the canonical set (e.g.
  `^FTSE`, `^N225`, `^GDAXI`, `000001.SS`).
- Runner override: `indices = { primary = index_symbol; global = Macro_inputs.default_global_indices }`.
- Tests: smoke test that `Macro.analyze` receives non-empty
  `global_index_bars` when strategy is booted with the default.

Estimated: ~40 lines + tests + symbol-list verification against cached data.

## Dependencies
- None between items. Either can land first.
- Both read cached bars already on disk.

## Not in scope
- Pinnacle Data purchase (separate human decision — see dev/notes/adl-sources.md).
- Sector metadata Phase 1 (SSGA XLSX holdings fetcher — separate agent).

## QC
overall_qc: NOT_STARTED
structural_qc: NOT_STARTED
behavioral_qc: NOT_STARTED

Reviewers when work lands:
- qc-structural — build / pattern check, façade-composition module boundaries
- qc-behavioral — correlation threshold ≥0.85 on synthetic vs Unicorn overlap; global-index set matches Weinstein macro-regime rules (see `docs/design/weinstein-book-reference.md` §Macro Indicators)
