# QC Structural Review: strategy-wiring

Reviewer: qc-structural
Date: 2026-04-14
PR: #355
Branch: feat/strategy-wiring

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune fmt --check | PASS | Fixed in follow-up commit (style: run dune fmt on ad_bars files) |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | 59 tests across 9 suites, all passed, 0 failed |
| P1 | Functions <= 50 lines (linter) | PASS | Longest function is 18 lines (_synthetic_load). All well under limit. |
| P2 | No magic numbers (linter) | PASS | H3 passed; no linter failures. Only structural constant is string length 8 for YYYYMMDD parsing. |
| P3 | Config completeness | NA | No new tunable thresholds introduced. This is a data-loading/composition layer with no configurable parameters. |
| P4 | .mli coverage (linter) | PASS | H3 passed. ad_bars.mli updated with Synthetic submodule and load documentation. |
| P5 | Internal helpers prefixed with _ | PASS | All internal helpers use _ prefix: _parse_yyyymmdd, _parse_breadth_row, _insert_parsed_row, _read_breadth_lines, _read_count_file, _join_counts, _unicorn_load, _synthetic_load, _last_date, _compose |
| P6 | Tests use matchers library | PASS | test_ad_bars_compose.ml opens Matchers and uses assert_that, elements_are, equal_to, all_of, field, size_is, is_empty, gt |
| A1 | Core module modifications | PASS | No modifications to Portfolio/Orders/Position/Strategy/Engine |
| A2 | No analysis/ -> trading/ imports | PASS | No cross-boundary imports found |
| A3 | No unnecessary existing module modifications | PASS | Only ad_bars.ml/mli modified (the feature target). Refactored shared helpers (_parse_breadth_row, _read_count_file, _join_counts) from Unicorn-specific to generic. dune file updated to register new test. |

## Verdict

APPROVED

---

# Behavioral QC — strategy-wiring
Date: 2026-04-14
Reviewer: qc-behavioral

## Behavioral Checklist

| # | Check | Status | Notes (cite authority doc section) |
|---|-------|--------|------------------------------------|
| A1 | Core module modification is strategy-agnostic (only fill if qc-structural flagged A1) | NA | qc-structural A1 is PASS — no core module modifications. |
| S1 | Stage 1 definition matches book | NA | No stage classification logic in this feature. |
| S2 | Stage 2 definition matches book | NA | No stage classification logic in this feature. |
| S3 | Stage 3 definition matches book | NA | No stage classification logic in this feature. |
| S4 | Stage 4 definition matches book | NA | No stage classification logic in this feature. |
| S5 | Buy criteria: entry only in Stage 2, on breakout with volume confirmation | NA | No buy signal logic in this feature. |
| S6 | No buy signals generated during Stage 1, 3, or 4 | NA | No buy signal logic in this feature. |
| L1 | Initial stop placed below the base | NA | No stop-loss logic in this feature. |
| L2 | Trailing stop rises as price advances | NA | No stop-loss logic in this feature. |
| L3 | Stop triggers on weekly close below stop level | NA | No stop-loss logic in this feature. |
| L4 | Stop state machine transitions are correct | NA | No stop-loss logic in this feature. |
| C1 | Screener cascade order | NA | No screener logic in this feature. |
| C2 | Bearish macro score blocks all buy candidates | NA | No macro gate logic in this feature — `Ad_bars.load` only provides data to `Macro.analyze`. |
| C3 | Sector analysis uses relative strength vs. market | NA | No sector analysis logic in this feature. |
| T1 | Tests cover all 4 stage transitions | NA | No stage transitions in this feature. |
| T2 | Tests include a bearish macro scenario that produces zero buy candidates | NA | No macro gating in this feature. |
| T3 | Stop-loss tests verify trailing behavior | NA | No stop-loss logic in this feature. |
| T4 | Tests assert domain outcomes, not just "no error" | PASS | Tests verify specific ad_bar values (advancing/declining counts), date ordering, overlap precedence (Unicorn wins with values 1053/1800, not Synthetic 9999/7777), list sizes, and sorted+deduplicated invariants. See test_ad_bars_compose.ml lines 41-218. |

### Feature-specific domain checks

| # | Check | Status | Notes |
|---|-------|--------|------------------------------------|
| F1 | Unicorn data preferred for dates where both sources overlap | PASS | `_compose` (ad_bars.ml:108-120) filters synthetic to dates strictly after Unicorn's last date via `Date.( > ) bar.date cutoff`. Tested in `test_compose_unicorn_wins_on_overlap` (line 116-147): Unicorn values 1053/1800 retained, Synthetic values 9999/7777 discarded for overlapping dates. |
| F2 | Synthetic fills only dates AFTER Unicorn's last date | PASS | `_compose` uses strict `Date.( > )` comparison against `_last_date u` (ad_bars.ml:117-118). No Synthetic data can appear on or before Unicorn's last date. |
| F3 | Result is chronologically sorted, no duplicates | PASS | Both sub-loaders sort via `_join_counts`. `_compose` appends tail (all dates > cutoff) to u, maintaining sort order. Tested in `test_compose_result_is_sorted` (line 153-163). Real-data integration test (line 195-217) asserts both sort order and uniqueness via `dedup_and_sort` count comparison. |
| F4 | Graceful degradation when either source is missing | PASS | `_compose` handles `([], s) -> s` and `(u, []) -> u`. Each loader returns `[]` for missing files (`_read_count_file` returns empty table if file absent). Tested in `test_unicorn_only`, `test_synthetic_only`, `test_compose_both_missing`, `test_synthetic_load_missing_files`. |
| F5 | `Ad_bars.load` facade maintains same return type `Macro.ad_bar list` | PASS | Signature unchanged in ad_bars.mli:62. Callers (e.g., runner.ml) require no changes. |
| F6 | Composition does not change macro analysis behavior | PASS | `load` only provides more data to the same `Macro.analyze` function. The `ad_bar` type `{ date; advancing; declining }` matches weinstein-book-reference.md section 2.2 (NYSE Advance-Decline Line: cumulative daily advancing minus declining issues). |
| F7 | Global indices wiring (Item 2) already on main | PASS | Verified: `macro_inputs.ml:22` defines `default_global_indices` with DAX, Nikkei, FTSE. `runner.ml:105` wires `global = Macro_inputs.default_global_indices`. Matches weinstein-book-reference.md section 2.5 (Global Market Confirmation: London, Japan, Germany). |
| F8 | A-D data semantics match Weinstein's NYSE breadth definition | PASS | `Macro.ad_bar` = `{ date; advancing: int; declining: int }` maps directly to weinstein-book-reference.md section 2.2: "Cumulative daily figure: (advancing issues) - (declining issues), added to running total." The composition preserves these semantics — Unicorn provides exchange-official counts, Synthetic provides Russell 3000-derived counts as an approximation. |

## Quality Score

4 — All checks pass. Clean composition logic with thorough test coverage including overlap precedence, ordering, graceful degradation, and a real-data integration test. Minor note: the status file spec mentioned a validation gate (correlation >= 0.85 for Synthetic vs Unicorn overlap) that is deferred as a follow-up, not a code defect.

## Verdict

APPROVED
