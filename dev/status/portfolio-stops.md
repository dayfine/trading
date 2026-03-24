# Status: portfolio-stops

## Last updated: 2026-03-24

## Status
IN_PROGRESS

## Interface stable
YES

## Completed
- `weinstein_types` module: Stage (1-4), ma_slope (Rising/Flat/Falling), grade (A/B/C) types with show/eq
- `weinstein_stops` module: Trailing stop state machine (Initial → Trailing → Tightened), round-number nudge, correction-cycle detection, Stage-3 tightening, full test suite
- `portfolio_risk` module: Fixed-risk position sizing, portfolio snapshot, exposure/cash/sector/risk limit checks, full test suite
- `portfolio_manager` module: Stateful integration — wraps Portfolio.t + Position.t + stop states, update cycle, apply_transition, log_trade, test suite
- All modules under `trading/analysis/weinstein/` with single `dune-project`
- Portfolio Manager .mli finalized — marks interface as stable

## In Progress
- Build verification in Docker (cannot run dune directly in this environment)
- `trading_state` persistence module (JSON serialization via yojson) — not yet started

## Blocked
- Cannot run `dune build && dune runtest` directly (Docker socket not available in agent environment). Code written to match existing patterns exactly. Build verification needed.

## Next Steps
1. PRIORITY: Run `dune build && dune runtest` in Docker and fix any compilation errors
2. Implement `trading_state` persistence (JSON load/save, atomic writes)
3. Verify and fix any edge cases found in build/test
4. Once all tests pass: update status to READY_FOR_REVIEW

## Open Issues / Build Verification Needed
- `Trading_strategy.Position.id` field: verify field named `id` in position.t
- `Trading_strategy.Position.StopLoss` constructor field names (stop_price, actual_price, loss_percent)
- `[@@deriving show]` on `tracked_position` with Date.t fields — should match position.mli pattern
- `create_entering transition` optional arg defaults — verify compilation

## Files Created
- `trading/analysis/weinstein/dune-project`
- `trading/analysis/weinstein/types/lib/weinstein_types.{ml,mli}` + dune + test
- `trading/analysis/weinstein/stops/lib/weinstein_stops.{ml,mli}` + dune + test
- `trading/analysis/weinstein/portfolio_risk/lib/portfolio_risk.{ml,mli}` + dune + test
- `trading/analysis/weinstein/portfolio_manager/lib/portfolio_manager.{ml,mli}` + dune + test

## Recent Commits
- f393900 Add Weinstein analysis modules: types, stops, portfolio_risk
- 3542e7f Add Portfolio Manager module integrating stops and risk management
- 3ee0db5 Fix portfolio_manager: add time_ns_unix dep, remove show from portfolio_update
