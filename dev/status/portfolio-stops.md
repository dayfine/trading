# Status: portfolio-stops

## Last updated: 2026-04-08

## Status
APPROVED

## QC
overall_qc: APPROVED (structural + behavioral, 2026-04-08)
See dev/reviews/portfolio-stops.md.

## Blocking Refactors
- None

## Interface stable
YES

## Completed
- Stop state machine (`weinstein/stops/`): Initial → Trailing → Tightened, Long/Short, configurable buffers
- Portfolio risk management (`weinstein/portfolio_risk/`): snapshot_of_portfolio, compute_position_size, check_limits — MERGED (#137)
- Trading state persistence (`weinstein/trading_state/`): JSON save/load, stop states, stage history, trade log — 25 tests

## In Progress
- None

## Blocked
- None (screener MERGED to main; order_gen dependency resolved)

## Next Steps
- QC review (structural + behavioral)
- Merge to main once QC APPROVED

## Completed
- Stop state machine (`weinstein/stops/`): Initial → Trailing → Tightened, Long/Short, configurable buffers
- Portfolio risk management (`weinstein/portfolio_risk/`): snapshot_of_portfolio, compute_position_size, check_limits — MERGED (#137)
- Trading state persistence (`weinstein/trading_state/`): JSON save/load, stop states, stage history, trade log — 25 tests
- `order_gen` (`trading/weinstein/order_gen/`): pure formatter — translates `Position.transition list` → `suggested_order list`; 11 tests; branch feat/weinstein, commit 8057a07b

## Recent Commits
- #147 Add stop state types, config, and basic API
- #148 Add stop update machinery (merged into #147 PR)
- #149 Improve stop module: configurable buffers, unified bar extreme, extracted dispatch
- #137 Add Portfolio risk management module
- portfolio-stops/trading-state: Add Weinstein trading state persistence (25 tests)
- feat/weinstein: order_gen — Position.transition → broker order translation (11 tests)
