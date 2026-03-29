# Status: portfolio-stops

## Last updated: 2026-03-29

## Status
IN_PROGRESS

## Interface stable
YES

## Completed
- Stop state machine (`weinstein/stops/`): Initial → Trailing → Tightened, Long/Short, configurable buffers
- Portfolio risk management (`weinstein/portfolio_risk/`): snapshot_of_portfolio, compute_position_size, check_limits

## In Progress
—

## Blocked
—

## Next Steps
- `weinstein/order_gen/`: generate suggested orders from screener candidates and stop events.
  Builds alongside (not replacing) `trading/simulation/lib/order_generator.ml`, which converts
  Position.transitions → Market orders. Weinstein order_gen adds grades, rationale, and
  StopLimit entry orders from screener output.
- `weinstein/trading_state/`: persist portfolio + stop states between runs (JSON, atomic write).
  Net-new — no existing persistence layer. Patterns: `portfolio.trade_history` for trade log
  shape, `analysis/data/storage/metadata/` for Sexp serialization precedent.

## Recent Commits
- #147 Add stop state types, config, and basic API
- #148 Add stop update machinery (merged into #147 PR)
- #149 Improve stop module: configurable buffers, unified bar extreme, extracted dispatch
- #137 Add Portfolio risk management module
