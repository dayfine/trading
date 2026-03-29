# Review: portfolio-stops
Date: 2026-03-30
Status: APPROVED

## Build/Test
dune build: PASS
dune runtest: PASS — portfolio_risk: 16 tests, weinstein_trading_state: 25 tests; full project suite clean
dune fmt: PASS

## Summary

The portfolio-stops feature delivers two new modules, both built alongside existing modules
without modifying Portfolio, Orders, or Position:

**portfolio_risk** (analysis/weinstein/portfolio_risk/): Position sizing, exposure limits,
sector concentration checks, and portfolio snapshots. Uses a `Snapshot.t` value type
(not the mutable Portfolio.t) for pure calculations. `check_limits` returns a validated
result with all violations collected. Config-driven: all thresholds in `config` type.
`snapshot_of_portfolio` is the main integration point — it converts `Portfolio.t` to
`Snapshot.t` for risk calculations.

**weinstein_trading_state** (trading/weinstein/trading_state/): JSON persistence for
weekly session state. Atomic writes (temp + rename), stop states stored for human
inspection but intentionally not deserialized (rebuilt from bars), stage history round-
trips correctly via Scanf parsing of ppx_deriving.show output format. All 25 tests cover
happy path, edge cases, round-trips, and the intentional non-restoration of stop states.

## Findings

### Minor Issues (non-blocking)

1. **`_load_universe` still duplicated** — This issue was noted in the data-layer QC review
   (dev/reviews/data-layer.md item #3). It is in merged code on main, not in these modules.
   Tracked separately.

2. **`portfolio_risk.mli` `check_limits` return type** — Returns `unit status_or` with
   all violations as a combined error. This is correct design but the error message
   concatenates violations; callers cannot enumerate them programmatically. If future
   tooling needs structured violations, consider a `violation list` return type. Not a
   blocker.

3. **`weinstein_trading_state` stage deserialization fragile** — Uses `Scanf.sscanf`
   on `ppx_deriving.show` output. If ppx_deriving changes its format (unlikely but
   possible), stage history will silently not restore. Documented in the code; acceptable
   for now given the fallback is "rebuild from bars" (same as stop_state behavior).

## Blockers (must fix before merge)
None.

## Checklist

**Correctness**
- [x] All design-specified interfaces implemented (portfolio risk management, session state persistence)
- [x] No placeholder / TODO code
- [x] Pure functions — `check_limits`, `snapshot`, `snapshot_of_portfolio` are all pure
- [x] All parameters in config, none hardcoded

**Tests**
- [x] Tests exist for all public functions
- [x] Happy path covered
- [x] Edge cases covered (empty portfolio, zero positions, invalid limits, nonexistent file)
- [x] Tests use the matchers library

**Code quality**
- [x] dune fmt clean
- [x] .mli files document all exported symbols
- [x] No magic numbers
- [x] No modifications to existing Portfolio/Orders/Position modules
- [x] Internal helpers prefixed with _

**Design adherence**
- [x] Builds alongside existing modules (no modifications to Portfolio, Orders, Position)
- [x] `order_gen` correctly deferred (blocked on screener merge)
- [x] `weinstein_trading_state` uses atomic writes (temp file + rename)
