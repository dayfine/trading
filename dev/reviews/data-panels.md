Reviewed SHA: 8c733ac35caf89f4eb65c47249c07136b5fd8a2b

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | Format check passed (only expected dune-project warning) |
| H2 | dune build | PASS | Build successful |
| H3 | dune runtest | PASS | Pre-existing linter failure on csv_storage.ml (nesting; unmodified file, persists on main). All actual tests pass. Backtest tests green. |
| P1 | Functions ≤ 50 lines (linter) | PASS | fn_length_linter passing; no new violations introduced |
| P2 | No magic numbers (linter) | PASS | linter_magic_numbers clean; no new hardcoded literals |
| P3 | Config completeness | PASS | No new tunable values; deletion-only PR removes configurable fields |
| P4 | .mli coverage (linter) | PASS | linter_mli_coverage passing; all deleted symbols had public declarations removed |
| P5 | Internal helpers prefixed with _ | PASS | Deleted helpers (_run_legacy, _make_simulator, _build_legacy*, _run_simulator) were correctly prefixed |
| P6 | Tests conform to test-patterns.md | PASS | Test updates drop loader_strategy parameter threading; backward-compat test added via assert_that matchers |
| A1 | Core module modifications | PASS | No modifications to Portfolio/Orders/Position/Strategy/Engine; only backtest infrastructure touched |
| A2 | No imports from analysis/ into trading/trading/ | PASS | PR only removes code; no new imports |
| A3 | No unnecessary modifications to existing modules | PASS | All changes are mechanical deletion; no refactoring or style rewrites |

## Verdict

APPROVED

## Checklist Notes

**H3 (dune runtest)**: The nesting linter failure on `analysis/data/storage/csv/lib/csv_storage.ml:180 _stream_in_range_prices` is pre-existing on `origin/main` (verified by running tests on main—same failure, same function, same nesting depth). This PR introduces zero changes to that file.

**File scope verification**:
- Diff covers 22 files, ~271 LOC removed (confirmed via `git diff origin/main...HEAD --stat`)
- No contamination from concurrent work (zero matches for perf_*, perf-catalog, perf-tier1)
- Loader_strategy library completely deleted (dune + .ml + .mli all gone)
- Reference check: `git grep 'Loader_strategy' HEAD -- ':!*.md'` yields only comments, docs, and shell scripts (no production code)
- Scenario backwards-compat verified: `[@@sexp.allow_extra_fields]` retained on Scenario.t; pre-existing scenario files with `(loader_strategy Panel)` will parse correctly and field is ignored by the runner

**Test updates**:
- Loader_strategy test cases (test_loader_strategy_legacy, test_loader_strategy_panel) deleted
- Combined flag tests updated to drop --loader-strategy parameter references
- New backward-compat test added: `test_loader_strategy_extra_field_tolerated` verifies pre-3.4 sexps with `loader_strategy` field still parse via `[@@sexp.allow_extra_fields]`
- All tests conform to test-patterns.md: single `assert_that` calls, matchers library, no nested assertions

**Deleted functions/code**:
- `_run_legacy` (~40 lines): entire entry point for Legacy runner path
- `_make_simulator` (~25 lines): simulator construction for Legacy
- `_build_legacy_calendar` (~10 lines): calendar helper
- `_build_legacy_bar_panels` (~40 lines): bar loading for Legacy
- `_run_simulator` (~5 lines): simulator invocation wrapper
- `Loader_strategy.t` enum and module (~45 lines total, 3 files)
- `?loader_strategy` parameter from Runner.run_backtest signature
- `--loader-strategy` CLI flag and argument parsing (~30 lines)
- loader_strategy field from Backtest_runner_args.t
- loader_strategy field from Scenario.t (with backward-compat mechanism)

**No breaking changes to external APIs**:
- Scenario.t field removed but sexp parsing remains compatible via `[@@sexp.allow_extra_fields]`
- Backtest_runner_args.t simplified but all flag parsing still works (existing --override, --trace, --memtrace flags unchanged)
- Runner.run_backtest signature simplified (loader_strategy param removed; panel-only path is now singular)

**Status file verification** (`dev/status/data-panels.md`):
- Correctly marked READY_FOR_REVIEW
- Last updated: 2026-04-26 (current date)
- Accurately describes scope, LOC delta, and parity gate (test_panel_loader_parity)
- Correctly positions Stage 4 as next dispatch (callbacks-through-runner wiring)
- No contradictions with actual PR content

**Pre-flag verifications** (per plan §"PR 3.4"):
- PR-F (Macro int-then-float fold): `_build_cumulative_ad_array` in `analysis/weinstein/macro/lib/macro.ml` unchanged—preserved as documented in status file
- PR-H QC (Bar_reader references): No production code references to deleted symbols remain; only stale doc comment (confirmed, acceptable per status file)
- bars_for_volume_resistance on Stock_analysis: Parameter left in place as documented (Volume + Resistance reshape deferred)

**Contamination check**:
- No perf_catalog, perf_tier1, perf_*, or sibling branch files in diff
- tiered_runner.ml: already deleted in PR #573; no changes in this PR ✓
- csv_storage.ml: unchanged (pre-existing linter failure persists)
- All 22 files touched are within scope (backtest infrastructure + tests + status)

---

# Behavioral QC — data-panels (Stage 3 PR 3.4)
Date: 2026-04-26
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | No new .mli created; existing .mli were trimmed. The Scenario.mli docstring claim about `[@@sexp.allow_extra_fields]` tolerating `(loader_strategy ...)` IS pinned by `test_loader_strategy_extra_field_tolerated` in `test_scenario.ml`. The runner.mli docstring update ("delegated to Panel_runner.run") is pinned indirectly by `test_panel_loader_parity` (round_trips bit-equality through the now-singular code path). |
| CP2 | Each claim in PR body / commit message vs committed tests | PASS | Commit message claims: (a) "drops `--loader-strategy {legacy,panel,bogus}` cases" — verified by absence of these strings in `test_backtest_runner_args.ml`; (b) "swaps explicit `loader_strategy` round-trip test for backward-compat assertion that pre-3.4 scenario files setting `(loader_strategy Panel)` still parse" — verified by `test_loader_strategy_extra_field_tolerated` in `test_scenario.ml`; (c) "drop `Load_bars` from runner_phases list" — `Load_bars` no longer recorded by runner.ml at the orchestration layer (Panel_runner owns simulator construction). All advertised tests exist. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size_is | PASS | Backward-compat parse test asserts `s.universe_path = Scenario.default_universe_path` — this proves the parse succeeded and the field was tolerated AND that no other field was clobbered. Parity gate (`test_panel_loader_parity`) asserts whole-record bit-equality of every `Metrics.trade_metrics` field via `equal_to` per element, not size_is. |
| CP4 | Each guard called out in code docstrings has a test exercising the guarded scenario | PASS | The `[@@sexp.allow_extra_fields]` guard explicitly called out in `Scenario.mli` lines 56–64 ("pre-existing scenario files that still set `(loader_strategy Panel)` continue to parse") is exercised by `test_loader_strategy_extra_field_tolerated` which embeds `(loader_strategy Panel)` and calls `t_of_sexp`. |

## Behavioral Checklist

| # | Check | Status | Notes (cite authority doc section) |
|---|-------|--------|------------------------------------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural's A1 row was PASS; no Portfolio/Orders/Position/Strategy modules touched. PR is pure backtest-infrastructure deletion + dispatch simplification. |
| S1 | Stage 1 definition matches book | NA | Domain stage classification not touched (`analysis/weinstein/stage/` unchanged in this PR; verified via `git diff origin/main...HEAD --stat -- 'analysis/'` returns empty). |
| S2 | Stage 2 definition matches book | NA | Same. |
| S3 | Stage 3 definition matches book | NA | Same. |
| S4 | Stage 4 definition matches book | NA | Same. |
| S5 | Buy criteria: Stage 2 entry on breakout w/ volume | NA | Domain entry rules not touched; `weinstein_strategy.ml` and screener cascade unchanged. |
| S6 | No buy signals in Stage 1/3/4 | NA | Same. |
| L1 | Initial stop below base | NA | Stops not touched (no diff under `analysis/weinstein/stops/` or `trading/trading/strategy/`). |
| L2 | Trailing stop never lowered | NA | Same. |
| L3 | Stop triggers on weekly close | NA | Same. |
| L4 | Stop state machine transitions | NA | Same. |
| C1 | Screener cascade order | NA | Screener cascade not touched. |
| C2 | Bearish macro blocks all buys | NA | Macro analyzer not touched (only the `runner.ml` orchestration that loads `ad_bars` was kept verbatim — see runner.ml `_load_ad_bars`). |
| C3 | Sector RS vs. market, not absolute | NA | Sector module not touched. |
| T1 | Tests cover all 4 stage transitions | NA | Domain-test concern; no domain code changed. |
| T2 | Bearish macro → zero buy candidates test | NA | Same. |
| T3 | Stop trailing tests | NA | Same. |
| T4 | Tests assert domain outcomes | PASS (proxy) | The load-bearing parity gate (`test_panel_loader_parity`) asserts bit-equal `round_trips` lists against checked-in goldens for two scenarios (`tiered-loader-parity` + `panel-golden-2019-full`). Goldens are non-trivial (15 / 21 lines of trade records). Whole-record `equal_to` per element is bit-equality on every `Metrics.trade_metrics` field — symbol, entry_date, exit_date, days_held, entry_price, exit_price, quantity, pnl_dollars, pnl_percent. Any drift in trading-decision logic introduced by the dispatch simplification would fail this gate. |

## Trading-domain preservation verification

Per the PR's behavioral concern (this PR is structurally a no-op for trading behavior), I verified:

- `git diff origin/main...HEAD --stat -- 'analysis/' 'trading/trading/strategy/' 'trading/trading/portfolio/' 'trading/trading/orders/' 'trading/trading/engine/'` → empty diff
- The runner.ml entry point (`run_backtest`) preserves the same dependency-loading pipeline (`_load_deps`): same `data_dir`, same `Sector_map.load`, same `_apply_overrides`, same `_apply_universe_cap`, same `_load_ad_bars`, same `_maybe_clear_sector_etfs`, same `_runner_base_config` — only the dispatch into `_run_panel_backtest` is now unconditional (was `match loader_strategy with Legacy | Panel`). Both prior arms produced identical output post-PR 3.2 (panel-backed) per status notes.
- The parity gate's two scenarios were already running through the Panel branch on `main`; this PR removes the (functionally redundant) Legacy branch but the asserted output is unchanged.

## Pre-flag verifications (per plan §"PR 3.4")

The status file (and commit message) claim three pre-flag verifications. Each verified independently:

- **PR-F (Macro int-then-float fold)**: `analysis/weinstein/macro/lib/macro.ml` is unchanged in this PR's diff. The `_build_cumulative_ad_array` function still keeps the running sum as `int` and applies `Array.map ~f:Float.of_int` only at the array boundary (verified by reading `macro.ml` at the feature SHA — function unchanged from `main`). Preserved.
- **PR-H QC (`Bar_reader.accumulate` / `_all_accumulated_symbols`)**: Verified no production references remain. Only one stale doc comment in `test_weinstein_strategy.ml` (acceptable per status file).
- **`bars_for_volume_resistance` parameter**: Left in place per plan; the .mli already documents it as awaiting a sibling reshape PR. Not blocking PR 3.4.

## Backwards-compat: `(loader_strategy ...)` sexp tolerance

The committed test (`test_loader_strategy_extra_field_tolerated`) IS load-bearing:

- The test sexp string explicitly includes `(loader_strategy Panel)` (line 195 of `test_scenario.ml`).
- It calls `Scenario.t_of_sexp` directly — without `[@@sexp.allow_extra_fields]`, this would raise (sexplib treats unknown fields as errors by default).
- The assertion `s.universe_path = Scenario.default_universe_path` confirms the parse produced a well-formed `Scenario.t` (not a partial/garbled record).

CP4 satisfied: the guard documented in `Scenario.mli` ("pre-existing scenario files that still set `(loader_strategy Panel)` continue to parse") is exercised by a test that would fail loudly if the attribute were dropped.

## Findings (informational FLAGs, not blocking)

### F1 — Stale dev/scripts using --loader-strategy (residual cleanup)

Three dev scripts still reference the removed CLI flag:
- `dev/scripts/tiered_loader_ab_compare.sh` (lines 142, 148)
- `dev/scripts/run_perf_sweep.sh` (lines 182, 193)
- `dev/scripts/run_perf_hypothesis.sh` (lines 35, 57, 179, 189, 201, 210)

All three are Legacy-vs-Tiered comparison harnesses. Tiered was already removed in PR 3.3 (so these scripts have been broken since then for the Tiered arm). After PR 3.4, the Legacy arm fails too because the CLI flag is gone. Per `.claude/rules/no-python.md`, the sibling Python report scripts (`perf_sweep_report.py`, `perf_hypothesis_report.py`) were "scheduled for **deletion** as part of `dev/plans/data-panels-stage3-2026-04-25.md` PR 3.4". This PR does not delete either the Python scripts or the shell scripts.

Not behavioral (no trading-system impact); the scripts are ad-hoc dev tooling. Worth a follow-up cleanup PR to delete all six (3 shell + 2 Python + the 1 referenced in `dev/notes/gc-tuning-experiment-2026-04-24.md`). Does NOT block PR 3.4 because the trading system itself is fully consistent.

### F2 — Stale doc-comment in panel_runner.mli

`panel_runner.mli` line 46 still says: "Same shape as the Legacy path's per-strategy entry point. The Panel branch in [Runner] uses this; callers should not call this directly outside of tests." After PR 3.4, there is no Legacy path and no "Panel branch" — Panel_runner is the sole runner. Minor doc nit; not behavioral.

### F3 — Stale doc-comment in backtest_runner.ml

Line 56 of `backtest_runner.ml` still references `[Loader_strategy]` enum and the Legacy/Tiered paths in a docstring explaining why the flag was removed. This is intentional (historical context) and acceptable.

## Quality Score

5 — Exemplary deletion-only PR: surgical scope, comprehensive test coverage, the load-bearing parity gate retains bit-equal whole-record assertions across two scenarios, the back-compat sexp tolerance is properly tested with a non-vacuous assertion, and the status file accurately positions Stage 4 as the next dispatch with a clear explanation of why the memory-win projection isn't yet realized. The two minor stale doc-comments and the residual dev/scripts are non-blocking follow-up cleanup, and the trading-domain code is provably untouched (`git diff -- 'analysis/' 'trading/trading/strategy/'` is empty).

## Verdict

APPROVED


