# Screener structural stop for live picks (issue #2084 Finding 2)

## Context

The weekly-pick report's long/short candidate rows and the sized "on fill
place SELL STOP @ $X" instruction line both come from
`Screener.scored_candidate.suggested_stop`
(`trading/analysis/weinstein/screener/lib/screener_scoring.ml:276`):

```ocaml
let suggested_stop ~initial_stop_pct entry = entry *. (1.0 -. initial_stop_pct)
```

A flat 8% below entry, always — this is why every displayed candidate shows
`Risk 8.0%` regardless of chart structure. The real strategy (both backtest and
live entry) never uses this formula to install a stop: `entry_walk.ml` (via
`Entry_audit_helpers`) computes the actual installed stop from
`Weinstein_stops.compute_initial_stop_with_floor`, which derives a real support
floor (prior correction low for longs / rally high for shorts) from the
symbol's daily bar history, falling back to a fixed buffer only when no
qualifying counter-move exists in the lookback window. The weekly-snapshot
generator already reuses this exact primitive for HELD positions'
`recommended_stop` display (`weekly_snapshot_generator.ml:211`,
`_recommended_stop`).

Consequences of the gap (from the issue): the displayed stop for a live
breakout pick (e.g. 07-17 FTH, $33.98) sits mid-air above the real chart
structure; since PR #2078 the sized instruction line tells the live trader to
place that naive stop (a live/sim divergence — the backtest's actual entry
uses the structural stop for the same symbol); and risk-based sizing always
assumes an 8% stop distance, so share counts are wrong too.

### Authority check (before citing)

`docs/design/weinstein-book-reference.md` §5.1 "Initial Stop Placement":

> "Place below the significant support floor (prior correction low) BEFORE the
> breakout."

This directly supports computing the display/instruction stop from a real
support floor rather than a flat percentage. `.claude/rules/weinstein-faithful-core.md`
spine item 5 states the same rule as a NEVER-adapt spine item. This PR is a
**correctness fix that restores the live-report path to the spine**, not a new
mechanism — see the default-branch decision below.

## Where the fix does NOT go

`Screener._build_candidate` (the pure scoring library,
`trading/analysis/weinstein/screener/lib/screener.ml`) computes
`suggested_stop` from `Stock_analysis.t`, which carries only weekly-bar-derived
sub-results (stage/RS/volume/resistance) — no raw daily bar list. There is no
bar history available inside the pure screener to run
`Weinstein_stops.compute_initial_stop_with_floor` (which needs a daily
`Types.Daily_price.t list` + `as_of`). Threading daily bars into the pure
screener library would be a much larger, riskier change touching a shared
library consumed by the backtest's "optimal-strategy counterfactual" tool
(`trading/backtest/optimal/lib/stage_transition_scanner.ml`, which reads
`Screener.scored_candidate.suggested_stop` directly into
`Optimal_types.candidate_entry.suggested_stop` — this is a deliberate design
choice documented in `optimal_types.mli`: "the counterfactual uses the
cleanest stop = suggested_stop from the screener"). Changing the pure
library's `suggested_stop` would silently change that counterfactual tool's
output and its pinned unit tests (`test_stage_transition_scanner.ml` asserts
`suggested_stop = entry * (1 - initial_stop_pct)` exactly).

**This PR does not touch `Screener.scored_candidate.suggested_stop`,
`screener_scoring.ml`, or `screener.ml` at all.** Instead, it fixes the
DISPLAY/INSTRUCTION path only, at the one place that already has both (a) the
candidate's suggested entry and (b) access to the symbol's daily bar history
via `Bar_reader`: `weekly_snapshot_generator.ml`. This exactly mirrors how
`_recommended_stop` already overlays a better stop onto held positions without
touching `Position.t.stop_price` itself.

## Default-branch decision (experiment-flag-discipline)

Per `.claude/rules/experiment-flag-discipline.md`, checked empirically:

1. **Consumers of `suggested_stop` / `Weekly_snapshot.candidate.stop`:**
   grepped the whole repo. `Screener.scored_candidate.suggested_stop` feeds:
   (a) `Snapshot_display.candidate_of_scored` → `Weekly_snapshot.candidate.stop`
   (the weekly report / live-instruction surface — the thing being fixed);
   (b) `trade_audit_recorder.ml` (an audit/report field, does not feed P&L);
   (c) `trading/backtest/optimal/lib/stage_transition_scanner.ml` →
   `Optimal_types.candidate_entry.suggested_stop` (the counterfactual report
   tool, explicitly NOT touched by this PR — see above).
   `Weekly_snapshot.candidate.stop` itself is consumed only by
   `Trade_sizing.size_candidate` (sizing) and `Report_renderer` (display) —
   both inside the snapshot/report path this PR targets.
2. **No backtest / golden / simulation path reads `Weekly_snapshot.candidate`.**
   The strategy's actual entry stop (`entry_walk.ml` /
   `Entry_audit_helpers`) is computed independently, directly from
   `Weinstein_stops.compute_initial_stop_with_floor` — it does not read
   `Screener.scored_candidate.suggested_stop` or
   `Weekly_snapshot.candidate.stop` at all. This PR does not touch that path.
3. **`dune runtest` golden check:** ran the full suite before and after the
   change (see Acceptance below) — no scenario/golden fixture under
   `trading/backtest/` moves, because none of them consume
   `Weekly_snapshot.candidate` or the generator.

**Conclusion: land on by default.** This is a display/instruction-path bug
fix with no backtest/golden path in the loop; gating a correctness fix behind
a default-off flag would perpetuate a live/sim divergence indefinitely. No
`Weinstein_strategy.config` / `Screener.config` field is added — there is
nothing to gate, since the change is confined to the report generator
constructing a display value from an already-existing, already-live, already
backtest-mirroring primitive (`compute_initial_stop_with_floor`).

## Approach

1. Add `Weekly_snapshot.candidate.stop_is_structural : bool`
   (`[@sexp.default false]`, additive field, no schema-version bump — same
   pattern as `sized_shares` / `resistance_grade`). `true` when
   `Weinstein_stops.Support_floor.find_recent_level` found a qualifying
   correction low / rally high in the lookback window; `false` for the
   fixed-buffer-proxy fallback (including the "no resident daily bars" case).
2. New private helper in `weekly_snapshot_generator.ml`,
   `_overlay_structural_stop ~inputs ~side c`, mirroring `_recommended_stop`:
   - Reads `Bar_reader.daily_bars_for inputs.bar_reader ~symbol:c.symbol
     ~as_of:inputs.as_of`.
   - No bars → return `c` unchanged (`stop_is_structural` stays `false`,
     `stop` stays the screener's naive-fallback value — graceful degradation,
     same shape as `_recommended_stop`'s no-bars case).
   - Bars present → call `Weinstein_stops.compute_initial_stop_with_floor
     ~config:inputs.config.stops_config ~side ~entry_price:c.entry
     ~bars:daily ~as_of:inputs.as_of
     ~fallback_buffer:inputs.config.initial_stop_buffer` (the SAME config
     fields `entry_walk.ml`'s real entry path uses) to get the new `stop`;
     call `Support_floor.find_recent_level` with the same
     `min_correction_pct` / `support_floor_lookback_bars` to set
     `stop_is_structural`.
3. Wire it into `generate`: apply `_overlay_structural_stop ~side:Long` to
   each long candidate BEFORE `_size_long` (so sizing keys off the corrected
   stop distance, fixing consequence 3 from the issue), and
   `~side:Short` to each short candidate (shorts aren't sized today, but the
   displayed stop/risk-% is still corrected).
4. `Report_renderer`: mark a non-structural (fallback) stop with a trailing
   `*` in the Stop cell, and append a one-line legend note below the
   candidate table whenever at least one shown row is a fallback stop —
   mirrors the existing `_truncation_note` pattern.
5. Update all literal `Weekly_snapshot.candidate` construction sites (8 files
   — grepped for `resistance_grade = ` / `sizing_note` sites, the last two
   existing additive fields, as a proxy for "every literal constructor") to
   add the new field.

## Files to change

- `trading/trading/weinstein/snapshot/lib/weekly_snapshot.ml` /`.mli` — new field.
- `trading/trading/weinstein/snapshot/gen/lib/weekly_snapshot_generator.ml` —
  `_overlay_structural_stop` + wiring into `generate`.
- `trading/trading/weinstein/snapshot/gen/lib/snapshot_display.ml` — add
  `stop_is_structural = false` to the initial (pre-overlay) construction.
- `trading/trading/weinstein/snapshot/lib/report_renderer.ml`/`.mli` —
  asterisk marker + legend note.
- Test files (add the new field to literal fixtures; add new
  behavior-pinning tests): `test_weekly_snapshot_generator.ml`,
  `test_report_renderer.ml`, `test_pick_diff.ml`, `test_split_replay.ml`,
  `test_forward_trace.ml`, `test_round_trip.ml`, `test_trade_sizing.ml`,
  `trading/trading/backtest/decision_audit/test/test_weekly_adapter.ml`.

## Risks / unknowns

- Touching 8 test files for one new field is mechanical but broad — kept the
  diff minimal by only adding the field, not restructuring the builders.
- `compute_initial_stop_with_floor`'s fallback path is NOT literally
  `entry * (1 - 0.08)` — it applies the state machine's own
  `min_correction_pct / 2` nudge plus round-number nudging on top of
  `entry * initial_stop_buffer`. This means even a "fallback" (non-structural)
  stop from this new path is numerically different from the old naive 8%
  value. This is intentional (`initial_stop_buffer` is the SAME config field
  the live strategy's real fallback path uses — see `entry_walk.ml`); the old
  naive screener-library `suggested_stop` value is preserved unchanged for the
  optimal-counterfactual tool, but the display path now genuinely mirrors
  what the live strategy would install.

## Acceptance criteria

- `Weekly_snapshot.candidate.stop_is_structural` exists, additive, no schema
  bump.
- A long/short candidate with a qualifying correction in its daily bar history
  shows a structural stop (no asterisk) that differs from the pre-fix flat-8%
  value and matches what `compute_initial_stop_with_floor` would compute
  directly.
- A candidate with no daily bars (or no qualifying correction) keeps a
  fallback stop, marked with the asterisk + legend note.
- Sizing (`sized_shares`/`sized_risk_amount`) is computed from the
  post-overlay stop, not the pre-overlay screener value.
- `Screener.scored_candidate.suggested_stop`,
  `trading/backtest/optimal/**`, and their existing tests are byte-for-byte
  unchanged (confirmed via `dune runtest`).
- Full `dune build && dune runtest` green; `dune build @fmt` green.

## Out of scope

- Changing `Screener._build_candidate` / `screener_scoring.ml` /
  `screener.ml`'s pure `suggested_stop` computation, or the
  optimal-strategy-counterfactual tool.
- Round-number shading beyond what `compute_initial_stop_with_floor` already
  applies (out of scope per the original support-floor-stops item).
- The trailing-stop state machine for candidates (only the INITIAL stop is
  being corrected here; candidates are not yet positions).
- `stops.ml`/`Weinstein_stops` core logic — called, not modified.
