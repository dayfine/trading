# Status: portfolio-stops

## Last updated: 2026-09-08

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

### Per-macro-state `initial_stop_buffer` (landed 2026-09-08)

Plan: `dev/plans/stop-width-by-macro-state-2026-09-06.md` (merged as #2700),
item 3 of the 2026-09-06 decided sequence. Implements the plan's shape (a) —
additive — so `initial_stop_buffer : float` keeps its meaning as the default
slot and stays a valid string-keyed override (eleven committed scenario specs
carry `((initial_stop_buffer X))`; the rejected shape-(b) type change would
have turned each into a mid-sweep sexp parse failure).

- New `Weinstein_strategy.Stop_buffer_by_state`
  (`trading/trading/weinstein/strategy/lib/stop_buffer_by_state.{ml,mli}`): a
  flat five-float record over `Weinstein_types.breadth_state` with a `0.0`
  `unset` sentinel, `default` (all unset), `is_no_op`, and `buffer_for` —
  which matches the five states exhaustively and falls back to the caller's
  scalar for any non-positive slot. Flat record, not `float option` /
  assoc-list, because `Overlay_validator` deep-merges against the base
  config's own sexp: a default serialising to `()` presents zero base keys and
  makes every overlay key "unknown", so the override would raise instead of
  applying.
- New config field `initial_stop_buffer_by_macro_state`
  (`[@sexp.default Stop_buffer_by_state.default]`), R1 default-off: with the
  empty map the resolved buffer is `config.initial_stop_buffer` by
  construction, so goldens are bit-identical. R2 axis, dot-path spelling
  `initial_stop_buffer_by_macro_state.deteriorating=1.0`.
- One read site: `Entry_walk._initial_stop_buffer` resolves from the `?macro`
  already threaded into `entries_from_candidates`, then hands the {i same}
  float to the ticket builder and to
  `Entry_stop_width_order.prefer_narrow_stops` (new optional
  `?initial_stop_buffer`, defaulting to the scalar). Threading one resolved
  float rather than `?macro` twice is what keeps the ordering pass and the gate
  from disagreeing about a width — `entry_stop_width_order.mli` calls that "the
  contract".
- Tests: `test_stop_buffer_by_state.ml` (9) + `test_stop_width_by_macro_state.ml`
  (4) under `weinstein/strategy/test/`, plus 3 override/axis cases in
  `backtest/test/test_runner_hypothesis_overrides.ml`.
- Motivation: the 2026-09-05 width×cadence surface (a 12% fallback stop is a
  large 26y lever but cannot be flipped as a constant — the wide arm's 2020
  crash losses landed under Bullish/Neutral labels) plus the 2026-09-04 yearly
  review's per-state entry P&L (Deteriorating −$604k record / −$668k arm;
  Recovering +$627k / +$1.81M).
- Weinstein: the flat-stop band is §5.3 (4–6%) and the §5.1 cap is ~15%; sizing
  the band by macro state is an adaptation of the width **dial** under
  `weinstein-faithful-core.md` W2 — no spine item moves, and
  `weinstein-book-reference.md` needs no amendment.
- **Not** promoted: the map ships empty, `initial_stop_buffer` stays `1.0`,
  `stop_update_cadence` stays `Daily`. R3 — the candidate map
  (Bullish/Recovering 0.9167, Neutral ~0.94–0.96, Deteriorating/Bearish 1.0) is
  documented in the `.mli` as a value to sweep, not a default to commit.
- Interaction to remember when sweeping: with
  `macro_config.breadth_direction` default-off, `Macro.result.breadth_state` is
  the projection of `trend`, so the `deteriorating` / `recovering` slots are
  inert until the breadth read is armed. Pinned by a test; stated in both
  `.mli`s.
- Out of scope (per plan §6): the weekly-report / snapshot stop-recompute paths
  (`Stop_thread.seed`, `Stop_recompute.*`) — they recompute stops for
  already-held positions from a plain float and have no macro result in scope;
  and `stop_update_cadence`, deliberately not bundled.
