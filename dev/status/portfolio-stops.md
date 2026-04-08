# Status: portfolio-stops

## Last updated: 2026-04-07

## Status
IN_PROGRESS

## QC
overall_qc: — (order_gen not yet implemented correctly; prior APPROVED was for a wrong implementation, PR #214 closed)

## Blocking Refactors
- None

## Interface stable
YES

## Completed
- Stop state machine (`weinstein/stops/`): Initial → Trailing → Tightened, Long/Short, configurable buffers
- Portfolio risk management (`weinstein/portfolio_risk/`): snapshot_of_portfolio, compute_position_size, check_limits — MERGED (#137)
- Trading state persistence (`weinstein/trading_state/`): JSON save/load, stop states, stage history, trade log — 25 tests

## In Progress
- `order_gen`: not yet implemented (two prior attempts closed — see decisions.md for the correct spec)

## Blocked
- None (screener MERGED to main; order_gen dependency resolved)

## Next Steps
- `trading/weinstein/order_gen/`: pure formatter — translates `Position.transition list` from
  `strategy.on_market_close` into broker order suggestions. No sizing decisions. No screener
  input. Strategy-agnostic: any strategy using Position.transition gets order formatting for free.
  See `docs/design/eng-design-3-portfolio-stops.md` §"Order Generation" for the exact interface.
## Recent Commits
- #147 Add stop state types, config, and basic API
- #148 Add stop update machinery (merged into #147 PR)
- #149 Improve stop module: configurable buffers, unified bar extreme, extracted dispatch
- #137 Add Portfolio risk management module
- portfolio-stops/trading-state: Add Weinstein trading state persistence (25 tests)
