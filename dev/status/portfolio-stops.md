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

### P1 sector cap (in flight, 2026-05-15)
- PR #1098 — `feat/sector-concentration-cap` branch
- Adds `max_sector_exposure_pct : float option` to `Portfolio_risk.config`
  (default `None`, opt-in) + `sector_exposures` field on `portfolio_snapshot`
  + `Sector_exposure_exceeded` limit violation + `Sector_exposure_cap` skip
  reason in `Audit_recorder` / `Trade_audit`.
- Wires the gate into the strategy entry walk via
  `Entry_audit_capture.check_sector_exposure_cap`, mirroring the existing
  short-notional cap pattern.
- Plan: `dev/plans/sector-concentration-cap-2026-05-15.md`.
- Unit tests: 6 in `test_portfolio_risk` (cap on/off, named/unknown sector,
  composes with count-cap, snapshot exposure aggregation).
- Integration tests: 5 in `test_entry_audit_capture` (cap on/off, accumulator
  bumps + persistence, empty-sector exempt).
- Default-off path bit-equal — all goldens pass unchanged.
- State: tests pass, draft PR open. Pending: ready-for-review handoff.
- Out of scope: 16y sp500 backtest experiment (deferred to `feat-backtest`).
