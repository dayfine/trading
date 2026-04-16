# Status: support-floor-stops

## Last updated: 2026-04-16

## Status
NOT_STARTED

## Interface stable
NO

## Ownership
`feat-weinstein` agent — see `.claude/agents/feat-weinstein.md`. Dispatched per the 2026-04-16 direction change in `dev/decisions.md` to unblock feat-backtest's support-floor stops experiment (see `dev/status/backtest-infra.md` §Blocked on).

## Goal

Replace the fixed-buffer proxy (`entry_price *. (1.0 /. buffer)`) with a real support-floor value derived from price history. Weinstein Ch. 6 §5.1: "Place below the significant support floor (prior correction low) BEFORE the breakout."

## Scope

Two items, both in `trading/trading/weinstein/stops/lib/`:

1. **`Support_floor.find_recent_low`** — new module. Pure function that, given a daily-bar series and `as_of`, returns the most recent qualifying correction low. Depth threshold default 8%; lookback configurable. Returns `None` if no qualifying pullback — caller falls back to fixed buffer.

2. **Wire into `Stops.compute_initial_stop`** — accept the new value; behaviour under `None` identical to today. State machine itself (Initial → FirstCorrection → Trailing) unchanged.

See `.claude/agents/feat-weinstein.md` §"Scope: support-floor-based stops" for signature sketch + acceptance checklist.

## Not in scope

- The fixed-buffer vs support-floor experiment — feat-backtest follow-on.
- Round-number shading of the stop value — §Follow-ups below.
- Regime-aware buffers — separate exploration in `dev/status/backtest-infra.md`.

## References

- `docs/design/weinstein-book-reference.md` §5.1 Initial Stop Placement, §5.2 Trailing Stop
- `docs/design/eng-design-3-portfolio-stops.md` §Stop state machine
- `dev/status/backtest-infra.md` §Blocked on — downstream experiment
- `dev/status/portfolio-stops.md` — prior base-strategy stops work (merged, interface stable)

## Follow-ups

- Round-number shading (§5.1): if computed stop lands near a round or half-point boundary, shade slightly below. New helper, probably `Support_floor.round_to_support` or inline in `Stops`.

## QC

overall_qc: NOT_STARTED
structural_qc: NOT_STARTED
behavioral_qc: NOT_STARTED

Reviewers when work lands:
- qc-structural — module boundaries, pure-function discipline, test coverage for degenerate inputs (empty bars, single bar, all-flat prices).
- qc-behavioral — spot-check against Weinstein Ch. 6 examples (Merck, Anthony Industries, National Semiconductor) — does the identified correction low match what the book calls out?
