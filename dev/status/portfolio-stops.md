# Status: portfolio-stops

## Last updated: 2026-03-30

## Status
READY_FOR_REVIEW

## Interface stable
YES

## Completed
- Stop state machine (`weinstein/stops/`): Initial → Trailing → Tightened, Long/Short, configurable buffers
- Portfolio risk management (`weinstein/portfolio_risk/`): snapshot_of_portfolio, compute_position_size, check_limits — MERGED (#137)
- Trading state persistence (`weinstein/trading_state/`): JSON save/load, stop states, stage history, trade log — 25 tests

## In Progress
— (all remaining work blocked on screener merge)

## Blocked
- `order_gen`: blocked until feat/screener merges to main (needs weinstein.screener for scored_candidate type)

## Next Steps
- `weinstein/order_gen/`: generate suggested orders from screener candidates and stop events.
  Builds alongside (not replacing) `trading/simulation/lib/order_generator.ml`, which converts
  Position.transitions → Market orders. Weinstein order_gen adds grades, rationale, and
  StopLimit entry orders from screener output.
## Recent Commits
- #147 Add stop state types, config, and basic API
- #148 Add stop update machinery (merged into #147 PR)
- #149 Improve stop module: configurable buffers, unified bar extreme, extracted dispatch
- #137 Add Portfolio risk management module
- portfolio-stops/trading-state: Add Weinstein trading state persistence (25 tests)
