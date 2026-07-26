# Weekly-picks execution protocol (2026-07-24)

**Goal:** make every weekly pick *executable* — an exact order instruction with
size — and thread held positions week to week. Mirror the backtest sizing so
live and simulation share the same pipeline (the project's core principle).

Sizing protocol = **mirror the backtest**: fixed-risk sizing via the existing
`Portfolio_risk.compute_position_size` (min of risk-based 1%, per-position cap
30% long, side-exposure cap, spendable-cash cap). Explicitly **not** equal-sized
— risk-normalized, so a tighter-stop name gets *more* shares for the same dollar
risk. This is the documented answer to "are all orders equally sized?": no, they
are risk-normalized.

## Phase A — portfolio state file + generator input (this PR)

1. New sexp portfolio file for LIVE holdings, canonical location
   `dev/weekly-picks/portfolio.sexp`. Shape (lib module
   `Weinstein_snapshot_gen.Live_portfolio` with sexp derivers):
   - `cash : float`
   - `as_of : Date.t`
   - `positions : position list` where
     `position = { symbol; shares : int; entry_price; entry_date : Date.t; stop_price }`
   Human-editable — the user records fills by editing this file. (A fill-CLI is
   a Phase-C+ option, not built here.)
2. `generate_weekly_snapshot.exe` gains optional `--portfolio PATH`. When given,
   populate the snapshot's `held_positions` (previously hardcoded `[]` at the
   bin `_run` seam) from the file, priced with the same `Bar_reader` (current
   close as-of the run date). Each held row renders: symbol, shares, entry,
   current price, unrealized %, CURRENT stop, and a stop-update recommendation
   (this week's recomputed Weinstein support-floor stop level side by side with
   the current stop + the delta). Reuses
   `Weinstein_stops.compute_initial_stop_with_floor` — no new stop logic is
   built; the trailing state machine is not wired in this PR.
3. Commit a template `dev/weekly-picks/portfolio.sexp` with `cash 100000.0` +
   empty positions + a comment telling the user to set real cash.

## Phase B — exact trade instructions per candidate (this PR)

1. For each long candidate, compute a sized instruction via
   `Portfolio_risk.compute_position_size` against the live portfolio snapshot
   (cash + long market value). Absent `--portfolio`, size against the template
   default and label "UNSIZED — set portfolio.sexp".
2. Extend the candidate report with a per-candidate instruction cell:
   `BUY STOP <shares> sh @ $<entry> (~$<value>, <pct>% of book, risk $<risk>);
   on fill place SELL STOP @ $<stop>, GTC; cancel if unfilled by Friday close`.
   Entry trigger = the candidate's existing `entry` field (breakout level).
3. Where the sized result is 0 shares, render the reason (cash/caps exhausted /
   invalid stop direction) rather than a blank cell.
4. Snapshot sexp: sized-instruction fields added to `candidate` and enriched
   fields to `held_position` — all additive with `[@sexp.default]` so old
   snapshots still parse (no `schema_version` bump; see weekly_snapshot.mli
   §Schema versioning).

## Phase C — HTML report + per-candidate SVG charts (next PR)

- Render the weekly report as a self-contained HTML page (in addition to the
  Markdown), with a per-candidate price/volume SVG sparkline showing the base,
  breakout level, and stop.
- Held-position mini-charts with the trailing-stop line.
- Optional fill-recording CLI (`record_fill`) that edits `portfolio.sexp` so the
  user does not hand-edit sexp.
- Full trailing-stop state machine threaded across weeks (persist stop_state per
  held position) rather than the recomputed-floor side-by-side used in Phase A.

## Test plan

- Portfolio file round-trip + template parses.
- Generator with `--portfolio` populates `held_positions` (synthetic fixture bars).
- Sizing instruction: known portfolio + candidate → exact shares/value/risk pinned.
- Old snapshot sexp back-compat load (`dev/weekly-picks/7f24f2c8d/2026-07-17.sexp`).
- Renderer: instruction cell renders; 0-share reason renders; held row renders.
