# Status: strategy-wiring

## Last updated: 2026-04-14

## Status
READY_FOR_REVIEW

PR #355 open.

## Ownership
`feat-weinstein` agent — see `.claude/agents/feat-weinstein.md`. This
reopens the feat-weinstein scope for two narrow wiring items that hand
off cached data to macro inputs already declared in
`Weinstein_strategy.config`. Base strategy code itself is unchanged.

## Interface stable
YES

No new public types or module boundaries. Changes are confined to
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
- Item 1: Synthetic ADL composition in `Ad_bars.load` (Synthetic submodule + compose logic + tests)
- Item 2: Global indices wiring — already complete on main (`Macro_inputs.default_global_indices` + runner override)

## In Progress
- None.

## Next Steps (work items)

All items complete. Awaiting QC review.

### Follow-up (not blocking merge)
- Validation gate: run `Synthetic_adl.validate_against_golden` over the Unicorn
  overlap window and record correlation in `dev/notes/synthetic-adl-validation.md`.
  The `compute_synthetic_adl.exe` already runs this validation at generation time;
  a separate one-off recording is a documentation task.

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
