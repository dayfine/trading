# Status: support-floor-stops

## Last updated: 2026-04-17

## Status
MERGED

## Interface stable
YES

## Open PR
- None. Both PRs merged to main on 2026-04-17:
  - PR A (primitive, long + short) — #382
  - PR B (wrapper + strategy wiring, long side) — #390

## Completed

- `dev/plans/support-floor-stops-2026-04-16.md` — plan committed (first-deliverable plan-first trigger)
- `Support_floor.find_recent_level` primitive (long + short) — implemented in `trading/trading/weinstein/stops/lib/support_floor.{ml,mli}` with 23 unit tests covering long/short happy paths, depth thresholds, tie-breaking, lookback truncation, and degenerate inputs (empty, single bar, flat prices, zero lookback). Short-side symmetrically returns the prior counter-rally high (resistance ceiling) — lands with no caller yet; future short-side strategy will consume it.
- `Weinstein_stops.compute_initial_stop_with_floor` wrapper — implemented in `weinstein_stops.{ml,mli}`; threads `~side` through to the primitive. 6 wrapper tests covering None-path parity with the fixed-buffer proxy (long + short) and Some-path using the identified level (long + short).
- `stop_types.config` extended with `support_floor_lookback_bars : int` (default 90)
- Wired `compute_initial_stop_with_floor` into `Weinstein_strategy._make_entry_transition` (one call-site swap) via `Bar_history.daily_bars_for` helper — long side only. Short-side wiring deferred (see `dev/status/short-side-strategy.md`).
- Backtest regression pins updated on 2018-2023 cached data: 6YR round-trips 1W/6L → 4W/3L; COVID 0W/4L → 1W/3L; POS adds one sell — confirms the support-floor path fires on real entries (smoke check)
- `dune build && dune runtest` green, `dune build @fmt` clean

## 2026-07-29 addendum — anchor-mode dial (task #13, PR `feat/floor-anchor-close`)

- Added `Support_floor.anchor_mode = Wick | Close` and threaded it as
  `?anchor_mode` on `find_recent_level_with_callbacks` (default `Wick` =
  bit-identical historical behaviour). `Close` measures the correction low /
  rally high (and the anchoring peak / trough) on the bar **close** instead of
  the intraday `low_price` / `high_price`, so a lone capitulation wick no longer
  anchors the structural floor to the wick extreme. Long/short mirrored (short:
  highest close vs highest high).
- Wired as a real `Weinstein_stops.config` field `support_floor_anchor_mode`
  (`[@sexp.default Wick]`) → embedded in `Weinstein_strategy.config.stops_config`
  → resolves through `Overlay_validator` as the `Variant_matrix` axis
  `((stops_config ((support_floor_anchor_mode Close))))`. R1 (default-off, exact
  no-op) + R2 (searchable axis) satisfied; R3 promotion needs a ledger ACCEPT.
- Motivation: CLMB 2026-04-30 wick $14.64 (~4% below neighbouring closes) forced
  a 42.5% stop distance → tiny position (`dev/notes/weekly-picks-2026-07-26.md`,
  priorities-2026-07-29 P1). Faithful-core: numeric-threshold-class initial-stop
  dial; spine item 5 (stop below the base) intact under either reading.
- Tests: default=Wick bit-identity, Close-mode long (wick) + short (spike)
  fixtures, config sexp round-trip + omitted-field-defaults-to-Wick,
  variant-matrix axis expansion. Bar-list `find_recent_level` intentionally left
  Wick-only (all-labelled signature; the dial lives on the callbacks path that
  the production stop + panel callers use) — avoids an unerasable-optional
  warning and churning ~20 existing call sites.

### Decision item — split-safe floors (A2 boundary; NOT executed here)

The priorities doc also wants `support_floor` split-safe (anchor on raw,
split-unadjusted lows) via `Adjusted_basis`. `Adjusted_basis` lives in
`trading/analysis/weinstein/snapshot_pipeline/`, but `support_floor` is in
`trading/trading/weinstein/stops/`. A direct import violates architecture rule
A2 (analysis → `trading/trading/` only allowed under `backtest/**`). Proposed
resolutions for human/review decision (per CLAUDE.md "propose as a decision
item"):
  1. Feed basis-corrected lows from the **caller** layer (the snapshot / entry
     pipeline already crosses into `analysis/`), keeping `support_floor` a pure
     price-list consumer — least architectural churn.
  2. Move the split-basis helper to a **canonical shared lib** both subtrees may
     depend on (e.g. `trading/base/` or a new shared module).
Not executed in this PR; needs a scope/architecture call.

## Ownership
`feat-weinstein` agent — see `.claude/agents/feat-weinstein.md`. Dispatched per the 2026-04-16 direction change in `dev/decisions.md` to unblock feat-backtest's support-floor stops experiment (see `dev/status/backtest-infra.md` §Blocked on).

## Goal

Replace the fixed-buffer proxy (`entry_price *. (1.0 /. buffer)`) with a real support-floor value derived from price history. Weinstein Ch. 6 §5.1: "Place below the significant support floor (prior correction low) BEFORE the breakout." Short-side mirror: place ABOVE the prior counter-rally high (resistance ceiling).

## Scope

Split into two stacked PRs:

**PR A — primitive (long + short)** in `trading/trading/weinstein/stops/lib/`:
- `Support_floor.find_recent_level` — pure function with a `~side` parameter. For long it returns the prior correction low; for short the prior counter-rally high. Depth threshold shared with `min_correction_pct`; lookback configurable. Returns `None` when no qualifying counter-move exists — caller falls back to fixed buffer.

**PR B — wrapper + strategy wiring** (stacked on A):
- `Weinstein_stops.compute_initial_stop_with_floor` — threads `~side` through; behaviour under `None` identical to pre-primitive direct call.
- `Bar_history.daily_bars_for` helper.
- `Weinstein_strategy._make_entry_transition` wiring — long side only (short-side strategy is a separate track).
- Backtest parity regression tests updated.

State machine itself (Initial → Trailing → Tightened) unchanged.

## Not in scope

- The fixed-buffer vs support-floor experiment — feat-backtest follow-on.
- Short-side strategy wiring — short-side strategy is a separate track (`dev/status/short-side-strategy.md`). The primitive lands here with both sides so the wrapper doesn't need a second API churn when the short-side strategy begins.
- Round-number shading of the stop value — §Follow-ups below.
- Regime-aware buffers — separate exploration in `dev/status/backtest-infra.md`.

## References

- `docs/design/weinstein-book-reference.md` §5.1 Initial Stop Placement, §5.2 Trailing Stop
- `docs/design/eng-design-3-portfolio-stops.md` §Stop state machine
- `dev/status/backtest-infra.md` §Blocked on — downstream experiment
- `dev/status/portfolio-stops.md` — prior base-strategy stops work (merged, interface stable)
- `dev/status/short-side-strategy.md` — consumes the short-side primitive

## Follow-ups

- Round-number shading (§5.1): if computed stop lands near a round or half-point boundary, shade slightly below. New helper, probably `Support_floor.round_to_support` or inline in `Stops`.

## QC

overall_qc: PENDING
structural_qc: PENDING
behavioral_qc: PENDING

Reviewers when work lands:
- qc-structural — module boundaries, pure-function discipline, test coverage for degenerate inputs (empty bars, single bar, all-flat prices); symmetry of long/short branches in the primitive.
- qc-behavioral — spot-check against Weinstein Ch. 6 examples (Merck, Anthony Industries, National Semiconductor) — does the identified correction low match what the book calls out? For the short side, spot-check against Ch. 11 short-sell examples (resistance ceiling identification).
