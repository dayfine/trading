Reviewed SHA: f2938ba6cfe32628fca7f9dcc54d0e1c2f891061

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No format violations |
| H2 | dune build | PASS | Clean build with no errors |
| H3 | dune runtest | PASS | 6 tests (2 skip) + 3 tests: all passed; total ~120s |
| P1 | Functions ≤ 50 lines (linter) | PASS | fn-length linter passed as part of H3 |
| P2 | No magic numbers (linter) | PASS | magic-numbers linter passed as part of H3 |
| P3 | Config completeness | PASS | No new tunable parameters; calendar parameter is architectural threading |
| P4 | Public-symbol export hygiene (linter) | PASS | mli-coverage linter passed as part of H3 |
| P5 | Internal helpers prefixed per convention | PASS | New helpers prefixed with underscore (e.g., `_synth_calendar`, `_walk_daily_view_window`, `_calendar_index_of`) |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | PASS | All test assertions use proper `assert_that` + Matchers composition; no nested `assert_that` or bare pattern matches in assertions; new tests in test_snapshot_bar_views.ml (9 existing + 5 new) and test_panel_callbacks.ml all follow pattern rules |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to core modules. Changes confined to `trading/trading/weinstein/strategy/` (Weinstein-specific strategy subtree, not the core `trading/trading/strategy/` interface). |
| A2 | No new `analysis/` imports outside backtest exception | PASS | No new dune-level imports. Existing libraries (trading.data_panel, trading.data_panel.snapshot, weinstein.*) pre-exist in dune; no new analysis imports added |
| A3 | No unnecessary modifications to existing modules | PASS | All 10 modified files are directly tied to #848 fix: Snapshot_bar_views core fix, Bar_reader/Panel_callbacks threading, diag executable (backtest-approved), and status update. No cross-feature drift. |

## Verdict

APPROVED

---

## Summary

The PR closes issue #848 (path-dependent regression in `Bar_reader.of_snapshot_views`) with two coupled fixes:

1. **Snapshot_bar_views calendar fix**: Replaced heuristic `_daily_calendar_span` window walking with explicit calendar-column iteration, mirroring `Bar_panels.daily_view_for` semantics. Now takes `~calendar` parameter and walks it bit-identically (NaN-passthrough on missing rows).

2. **Open field fix**: `_assemble_daily_bars` now reads `Snapshot_schema.Open` (available since Phase A.1/#786, previously unused) instead of returning `Float.nan`. Ensures assembled bars match panel-backed bars field-for-field.

3. **Threading**: Calendar parameter threaded through `Bar_reader.of_snapshot_views` (with backward-compatible synthetic calendar for tests) and `Panel_callbacks.support_floor_callbacks_of_snapshot_views`.

All tests pass (including 14 new/regression tests in snapshot_bar_views and panel_callbacks parity suites). No structural violations. Minimal, focused changes with no cross-module side effects.

---

# Behavioral QC — data-foundations-pr861 (#848 forward fix)
Date: 2026-05-05
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new/changed `.mli` docstrings has an identified test that pins it | PASS | Per-claim mapping below: (a) `Snapshot_bar_views.daily_view_for ~calendar` walks calendar columns mirroring panel + NaN-passthrough → `test_daily_view_walks_calendar_with_holiday_gap` (n_days=9 = lookback 10 − 1 holiday; gap date excluded) plus full-window parity tests `test_daily_view_parity_full` / `test_daily_view_parity_short_lookback`. (b) `_assemble_daily_bars` populates `open_price` from `Snapshot_schema.Open` → `test_daily_bars_for_open_price_populated` (panel-vs-snap field equality on every bar) AND `test_daily_bars_for_open_price_is_not_nan` (every bar's open is finite). (c) `low_window ~calendar` mirrors panel slice with NaN cells on holidays → `test_low_window_walks_calendar_with_holiday_gap` (asserts both `pa.(4)` AND `sa.(4)` are NaN at the gap offset; bit-equal arrays). (d) `Panel_callbacks.support_floor_callbacks_of_snapshot_views ~calendar` (now required) returns same anchor/counter-move as panel path → `test_support_floor_snapshot_parity` (Long side, rally-then-pullback fixture; Some r1, Some r2 → `float_equal`). (e) `as_of` not in calendar yields empty view → `test_daily_view_as_of_not_in_calendar_yields_empty`. Every concrete claim in `snapshot_bar_views.mli`, `bar_reader.mli`, `panel_callbacks.mli` is pinned. |
| CP2 | Each claim in PR body / commit message has a corresponding test in committed test files | PASS | Commit message claims pinned: (a) "calendar-column walking bit-equal to Bar_panels' window definition" → 14-test parity suite in `test_snapshot_bar_views.ml`. (b) "missing rows degrade to NaN, matching the panel's Ohlcv_panels NaN-cell semantics" → `test_low_window_walks_calendar_with_holiday_gap` asserts NaN at the gap offset on BOTH paths. (c) "_assemble_daily_bars Open NaN ... read Open field history alongside the other OHLCV fields" → `test_daily_bars_for_open_price_populated` + `_is_not_nan`. (d) "Panel_callbacks.support_floor_callbacks_of_snapshot_views (~calendar required)" → `test_support_floor_snapshot_parity` exercises the new required arg. The diag-exec 0-diffs claim is explicitly marked unverifiable in GHA in the commit body — not a test claim. |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are [equal_to ...] or whole-value equal_to), not just size_is | PASS | The parity tests use `_float_arrays_bit_equal` (per-cell `Float.equal` with NaN-equals-NaN) and `_date_arrays_equal` for both `closes`, `raw_closes`, `highs`, `lows`, `volumes`, `dates` — not size_is. `test_daily_view_walks_calendar_with_holiday_gap` does `_assert_daily_views_equal panel_view snap_view` (full per-array bit-equality) AFTER the n_days size check. `test_daily_bars_for_open_price_populated` uses `List.iter2_exn ... float_equal p.open_price` (per-element value equality, not just length). `test_macro_snapshot_globals_filter_missing` uses `elements_are [ equal_to "DAX" ]` for the filter result. |
| CP4 | Each guard/edge case called out in code docstrings has a test exercising it | PASS | Guarded scenarios from `snapshot_bar_views.mli` `daily_view_for`: (1) `lookback <= 0` → `test_zero_n_or_lookback_yields_empty_views`. (2) `as_of` not in calendar → `test_daily_view_as_of_not_in_calendar_yields_empty`. (3) symbol not in manifest → `test_unknown_symbol_yields_empty_views`. (4) no resident snapshot rows in window → `test_pre_history_as_of_yields_empty_views`. (5) NaN close skip → `test_nan_close_skipped_in_daily_view`. (6) Holiday gap → `test_daily_view_walks_calendar_with_holiday_gap`. `low_window` symmetric guards: `test_unknown_symbol_yields_empty_views` (None on unknown symbol), `test_zero_n_or_lookback_yields_empty_views` (None on len=0), `test_daily_view_as_of_not_in_calendar_yields_empty` (None on as_of-not-in-calendar), `test_low_window_walks_calendar_with_holiday_gap` (NaN cells on missing rows). The investigation note's specific divergent samples (GSPC 2019-01-04 panel n_days=56 snap n_days=60; open=2753.25 vs nan) map to the holiday-gap test (mirrors n_days reduction by holiday count) and the open-price tests respectively. |

## Behavioral Checklist (project-specific)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural did not flag A1; no core-module modifications. |
| S1–S6, L1–L4, C1–C3, T1–T4 | Domain checklist rows | NA | Pure snapshot-engine infrastructure fix; domain checklist not applicable per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely". This PR fixes the snapshot bar-view shim's calendar-walking semantics and Open-field read; no Weinstein domain logic (stage classification, stops, screener cascade, macro gate) is added or modified. |

## Quality Score

5 — Exemplary forward-fix: precise scoping (only the two coupled bugs identified by the investigation note, nothing more), comprehensive test pinning (5 new tests covering both bugs and all guarded edge cases including the holiday-gap regression that the bisect explicitly named), bit-equal panel-vs-snapshot parity asserted via per-cell `_float_arrays_bit_equal` rather than size proxies, and the load-bearing `support_floor_callbacks_of_snapshot_views ~calendar` required-arg change exercised end-to-end through `Weinstein_stops.Support_floor.find_recent_level_with_callbacks`. The `?calendar` synthesis fallback in `Bar_reader.of_snapshot_views` is documented as "tests-only; production must pass real calendar," which matches the actual call-site discipline. The `.mli` docstrings are explicit about the #848 framing so future readers can trace the change to its motivating bug.

## Verdict

APPROVED
