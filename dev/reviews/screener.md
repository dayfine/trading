# Review: screener
Date: 2026-03-30
Status: APPROVED

## Build/Test
dune build: PASS
dune runtest: PASS — 113 tests across 7 modules, 0 failures, 0 errors
dune fmt: PASS (clean, no changes needed)

## Summary

All four blockers from the 2026-03-28 review have been resolved in commit `2df5076d`.
The feature delivers 7 analysis modules (stage, rs, volume, macro, sector, resistance,
stock_analysis) plus the screener cascade, all as pure functions. Magic numbers are now
in config types with named defaults. Tests use the matchers library throughout.

Modules delivered:
- `weinstein.stage`: Weinstein stage classifier (Stage1–4) — 9 tests
- `weinstein.rs`: Relative strength trend vs. benchmark — 18 tests
- `weinstein.volume`: Volume confirmation for breakouts — 8 tests
- `weinstein.macro`: Market regime (A/D line, new-high/low ratio) — 15 tests
- `weinstein.sector`: Sector rating and confidence — 11 tests
- `weinstein.resistance`: Overhead resistance detection — 5 tests
- `weinstein.stock_analysis`: Breakout detection and price analysis — 47 tests (stage + stock_analysis combined)
- `weinstein.screener`: Cascade filter producing ranked buy/short candidates

## Resolved Since Prior Review (2026-03-28)

- DONE: Magic numbers extracted to config — `grade_thresholds`, `candidate_params` in screener.mli; `indicator_params` in macro.mli; `breakout_params` in stock_analysis.mli; `confidence_weights`, `stage_scores`, `rs_scores` in sector.mli
- DONE: Tests migrated to Matchers — all `assert_bool`, raw `assert_failure` pattern matches, and `match` guards replaced with `assert_that` throughout all 7 test files
- DONE: Dead branch in rs.ml `_classify_rs_trend` removed — `(true, true)` case collapsed to a single expression without unreachable branch
- DONE: `dev/reviews/screener.md` created (this file)

## Blockers (must fix before merge)
None.

## Should Fix
1. **`candidate_params` not in `screener.mli` config type** — `screener.mli` exports `grade_thresholds` and `candidate_params` as standalone types and `default_grade_thresholds` / `default_candidate_params` as values, but these are referenced in tests through `Screener.default_candidate_params`. Confirm public names are stable (minor naming concern, not a blocker since tests pass and interface is accessible).

2. **`indicator_params` default values not exported from `macro.mli`** — unlike screener, `macro.ml` has `default_indicator_params` but it is not in `macro.mli`. If callers outside tests need defaults they must duplicate them. Low priority but worth adding for completeness.

## Suggestions
- Add a `default_config` convenience value to screener.mli that assembles all sub-defaults so callers don't need to construct the full record manually.
- Consider documenting in `stock_analysis.mli` that `breakout_params.breakout_scan_weeks` must be <= the bar history length to avoid silent no-breakout results.

## Checklist

**Correctness**
- [x] All design-specified interfaces implemented (stage, rs, volume, macro, sector, resistance, breakout, screener cascade)
- [x] No placeholder / TODO code in non-trivial paths
- [x] Pure functions — no hidden state, all analysis functions are side-effect free
- [x] All parameters in config, none hardcoded in logic

**Tests**
- [x] Tests exist for all public functions
- [x] Happy path covered
- [x] Edge cases covered (empty bars, insufficient history, stage transitions, macro regime changes)
- [x] Tests use the matchers library (no assert_bool, no raw pattern matches with assert_failure)
- [x] No magic numbers in test assertions

**Code quality**
- [x] dune fmt clean
- [x] .mli files document all exported symbols
- [x] No magic numbers in implementations
- [x] Functions under 50 lines
- [x] Internal helpers prefixed with _
- [x] No modifications to existing Portfolio/Orders/Position modules

**Design adherence**
- [x] All analysis functions are pure (same input → same output, no I/O, no mutable state)
- [x] Screener implements cascade filter producing scored_candidate list
- [x] Config types group all thresholds — callers pass the whole config record
