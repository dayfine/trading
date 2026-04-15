# Status: portfolio-stops

## Last updated: 2026-04-14

## Status
MERGED

## QC
overall_qc: APPROVED (structural + behavioral, 2026-04-08). Merged to main as PR #227 (commit 2530fb9d).
See dev/reviews/portfolio-stops.md.

## Interface stable
YES

## Completed (all merged to main)
- Stop state machine (`weinstein/stops/`): Initial → Trailing → Tightened, Long/Short, configurable buffers
- Portfolio risk management (`weinstein/portfolio_risk/`): PR #137
- Trading state persistence (`weinstein/trading_state/`): JSON save/load, stop states, stage history, trade log — 25 tests
- `order_gen` (`trading/weinstein/order_gen/`): PR #227 — pure formatter translating `Position.transition list` → `suggested_order list`; 11 tests

## Follow-ups
- None in scope. See dev/status/strategy-wiring.md for remaining macro-input wiring.
