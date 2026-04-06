# Status: portfolio-stops

## Last updated: 2026-04-06

## Status
READY_FOR_REVIEW

## QC Status
Overall QC: PENDING (new order_gen module needs review)
Note: Prior QC review (2026-04-05) was on a stale branch; all prior code is on main.
New work: order_gen on feat/portfolio-stops-order-gen.

## Interface stable
YES

## Completed
- Stop state machine (`trading/weinstein/stops/`): Initial → Trailing → Tightened, Long/Short, configurable buffers — MERGED to main
- Portfolio risk management (`analysis/weinstein/portfolio_risk/`): snapshot_of_portfolio, compute_position_size, check_limits — MERGED to main (#137)
- Trading state persistence (`trading/weinstein/trading_state/`): sexp save/load, stop states, stage history, trade log — MERGED to main (#168)
- Order generation (`analysis/weinstein/order_gen/`): from_candidates, from_stop_adjustments, from_exits — 9 tests — on feat/portfolio-stops-order-gen

## In Progress
- QC review of order_gen pending

## Blocked
- None

## Next Steps
- QC review order_gen; merge to main

## Follow-up
- None

## Recent Commits
- feat/portfolio-stops-order-gen: Add Weinstein order generation module (9 tests)
- #172: Apply review: migrate test_weinstein_stops.ml to new matchers
- #168: Rewrite weinstein_trading_state to use sexp serialisation
- #167: Add sexp derivation to weinstein types and stops
- #137: Add Portfolio risk management module
