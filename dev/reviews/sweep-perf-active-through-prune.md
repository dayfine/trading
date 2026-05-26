Reviewed SHA: 6778ca9768d65aee77b6d1deb297502110bbb883

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | All tests pass |
| P1 | Functions ≤ 50 lines (linter) | PASS | Linter passed as part of H3 |
| P2 | No magic numbers (linter) | PASS | Linter passed as part of H3 |
| P3 | Config completeness | PASS | No new magic numbers introduced; all fold_start_date threading is parameterized |
| P4 | Public-symbol export hygiene (linter) | PASS | Linter passed as part of H3 |
| P5 | Internal helpers prefixed per convention | PASS | New helpers use `_maybe_prune_deps`, `_build_initial_state`, `_date_range_error_of`, `prune_symbols_by_active_through` (public for testing) convention |
| P6 | Tests conform to test-patterns rules | PASS | 5 new tests (3 simulator + 2 weinstein_strategy) all use `assert_that` + matchers; no anti-patterns detected (no List.exists on bool, no `let _` on on_market_close/.run, no bare match-assert_failure) |
| A1 | Core module modifications (strategy-agnostic claim) | FLAG | Simulator receives optional `?active_through_for` parameter; Weinstein_strategy threading adds `?fold_start_date`. Both additive (defaults preserve baselines), parameter-driven (not Weinstein-specific logic in simulator), but touches core modules. qc-behavioral to verify generalizability and that no Weinstein-only logic leaks into simulator core. |
| A2 | No analysis/ imports into trading/trading outside backtest exception | PASS | No new analysis imports detected in dune files |
| A3 | No unnecessary modifications to existing modules | PASS | Refactor of simulator.ml (extracting `_maybe_prune_deps`, `_build_initial_state`, `_date_range_error_of`) is local to `create()` path and reduces nesting without touching other helpers. test_force_liquidation_strategy.ml parameter update is required signature change only. |

## Summary

Hard gates H1–H3 all pass. Structural checklist clean: test patterns conformant, no magic numbers, proper prefixing. The PR adds optional universe-pruning parameters to simulator and Weinstein strategy (Win #4 optimization). Changes are **additive** (default `None` preserves bit-equal baselines) and **parameter-driven** (not strategy-specific logic in simulator). A1 is FLAG-not-FAIL because the parameter is strategy-agnostic (operates on `Daily_price.active_through` field, not Weinstein concepts), but the modification does touch core modules — qc-behavioral must confirm generalizability.

## Verdict

APPROVED

### Quality Score

5 — All hard gates pass, test patterns clean, refactoring is local to the modified path with clear intent (reduce nesting while adding new feature). Optional parameters preserve baselines.

---

# Behavioral QC — sweep-perf-active-through-prune
Date: 2026-05-26
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | `simulator.mli`: (a) "drops symbols where `Core.Date.(d < fold_start_date)`" → `test_prune_symbols_by_active_through_drops_pre_fold_delistings` (OLD1995/OLD1995B drop); (b) "[None] symbols pass through unchanged" → same test ("UNKNOWN" survives); (c) "Default [None] preserves bit-equal baselines: no pruning" → `test_create_without_active_through_for_preserves_symbols`; (d) "[create] prunes once at construction" → `test_create_with_active_through_for_prunes_pre_fold_delisted` (create_exn invoked + reference assertion via pure helper). `weinstein_strategy.mli`: (a) "drop symbols whose `active_through_for` returns `Some d` with `d < fold_start_date`" → `test_prune_universe_by_active_through_drops_pre_fold_delistings`; (b) "screener pre-prunes config.universe before Phase 1" → `test_survivors_for_screening_drops_pre_fold_delisted` (asserts baseline=3, pruned=2, exact survivor tickers); (c) "Default `None` preserves baselines" → baseline arm of `test_survivors_for_screening_drops_pre_fold_delisted` and integration tests on `make` defaulting to `?fold_start_date = None`. `weinstein_strategy_macro.mli`: `_prune_args_of` returns `(None, None)` when `fold_start_date = None` — implicitly pinned by the survivors_for_screening baseline arm. |
| CP2 | Each claim in PR body "Test plan" sections has a corresponding test in the committed test file | PASS | PR body advertises 5 named tests; all 5 found verbatim in test files: `test_prune_symbols_by_active_through_drops_pre_fold_delistings` (test_simulator.ml:880), `test_create_without_active_through_for_preserves_symbols` (test_simulator.ml:904), `test_create_with_active_through_for_prunes_pre_fold_delisted` (test_simulator.ml:919), `test_prune_universe_by_active_through_drops_pre_fold_delistings` (test_weinstein_strategy.ml:1102), `test_survivors_for_screening_drops_pre_fold_delisted` (test_weinstein_strategy.ml:1123). |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are [equal_to ...] or equal_to on entire value), not just size_is | PASS | All five new tests assert identity-level equality: tests 1, 3, 4 use `assert_that kept (equal_to [list-of-strings])` (whole-list equality, including order); test 2 asserts `equal_to ["AAPL"; "MSFT"; "GOOG"]` on the unchanged symbol list; test 5 asserts `equal_to ((3, 2, ["RISE_A"; "RISE_B"]) : int * int * string list)` (pins both pruned-list count AND the exact surviving tickers). No size_is-only assertions. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | Three explicit guards: (1) "[None] active_through_for preserves baselines" — pinned by `test_create_without_active_through_for_preserves_symbols` and the baseline arm of `test_survivors_for_screening_drops_pre_fold_delisted`. (2) "active_through = None passes through unchanged" — pinned via "UNKNOWN" entries in tests 1 and 4. (3) "active_through < fold_start_date drops" — pinned via OLD1995/DEAD/DEAD_PRE_FOLD entries. Minor gap (non-blocking): the boundary case `d == fold_start_date` (which the code KEEPS via `<=`) is not explicitly tested; the implementation is correct but not pinned to a dated test. Filed as a soft follow-up below — does not affect verdict. |

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | PASS | qc-structural FLAGged `simulator.ml`'s new `?active_through_for : (string -> Core.Date.t option) option` parameter for generalizability review. Reading the implementation (simulator.ml:73-81, 105-113): the helper `prune_symbols_by_active_through` operates purely on a per-symbol date lookup vs a fold-start date. Neither concept is Weinstein-specific — `Daily_price.active_through` is a data-layer field on every price bar regardless of strategy. The simulator's `_maybe_prune_deps` reads only `deps.active_through_for` and `config.start_date` (both pre-existing or strategy-agnostic types). No Weinstein imports, no stage classification logic, no MA-period assumptions leaked into the simulator. Any STRATEGY consumer (Buy-and-hold, NoOp, Weinstein, future strategies) gets the same benefit by passing a callback. PASS. |
| S1 | Stage 1 definition matches book | NA | Pure infrastructure optimization. PR does not modify stage classification logic. |
| S2 | Stage 2 definition matches book | NA | Same as S1. |
| S3 | Stage 3 definition matches book | NA | |
| S4 | Stage 4 definition matches book | NA | |
| S5 | Buy criteria: Stage 2 entry on breakout with volume | NA | PR does not modify buy/entry logic; only the input universe to Phase-1 classification. |
| S6 | No buy signals in Stage 1/3/4 | NA | |
| L1 | Initial stop below base | NA | PR does not modify stop logic. |
| L2 | Trailing stop never lowered | NA | |
| L3 | Stop triggers on weekly close | NA | |
| L4 | Stop state machine transitions | NA | |
| C1 | Screener cascade order | NA | The cascade order is unchanged — `_classify_all` adds a pre-Phase-1 universe filter; Phase 1 → Sector → Phase 2 → Ranking order is preserved (verified in `weinstein_strategy_screening.ml:283-295` and `screen_universe` at line 357+). |
| C2 | Bearish macro blocks all buys | NA | Unchanged — `entry_transitions_if_active` gating is unchanged (weinstein_strategy_macro.ml:128-138). |
| C3 | Sector RS vs. market, not absolute | NA | Unchanged. |
| T1 | Tests cover all 4 stage transitions | NA | Not in scope for this perf PR. |
| T2 | Bearish macro → zero buy candidates test | NA | Existing tests cover this; PR does not regress. |
| T3 | Stop trailing tests | NA | |
| T4 | Tests assert domain outcomes (not just "no error") | PASS | New tests assert specific surviving-ticker lists, exact counts (baseline=3 vs pruned=2), and whole-list equality including order. No "smoke / no error thrown" tests added. The integration test (`test_survivors_for_screening_drops_pre_fold_delisted`) pins the load-bearing behavior — that pre-fold-delisted symbols are dropped BEFORE Phase 1 — via a triple `(baseline_count, pruned_count, surviving_ticker_list)`. Domain framing (NOT survivor bias) is asserted via the test setup itself: alive_2025 (a future date) is kept under a 1998 fold, demonstrating point-in-time filtering. |

## Domain framing verification (point-in-time vs survivor bias)

The PR's load-bearing domain claim is "this is NOT survivor bias". Verified:

1. **Code-level**: The filter predicate is `Core.Date.( <= ) fold_start_date d` (simulator.ml:79; weinstein_strategy_screening.ml:273). Symbols are kept iff their last-active date is on or after the FOLD start, never compared against `Date.today ()` or any present-relative date. Inspected both helper sites.
2. **Docstring-level**: Both `.mli` files prominently distinguish "filter on fold start = point-in-time" from "filter on `active_today` = survivor bias", and call out that the latter cut is NOT performed. The docstring framing matches the implementation.
3. **Test-level**: `test_prune_symbols_by_active_through_drops_pre_fold_delistings` includes ALIVE_2025 (a future date relative to the fold) and asserts it is KEPT. This directly demonstrates that "future-active symbols" (which a survivor-bias filter would also keep, but for the wrong reason) participate normally regardless of fold date. The test also keeps ALIVE_1999 (delisted during the 1998+ fold), which would be DROPPED by a survivor-bias filter that gated on "still trading today" — proving the implementation is point-in-time, not survivor-biased.

## Quality Score

5 — Domain framing is unambiguous in both docstrings and tests, the integration pin (baseline=3 vs pruned=2 with explicit surviving tickers) directly satisfies the plan's acceptance criterion, and the simulator-side change is genuinely strategy-agnostic (no Weinstein leak into core). A1 FLAG resolves cleanly to PASS.

## Soft follow-up (non-blocking, does not affect verdict)

- Boundary case `active_through == fold_start_date` is correct in the implementation (kept via `<=`) but not explicitly pinned to a dated test. Adding a single line to either of the pure-helper tests with `active_through = fold_start_date` would close CP4 to fully exhaustive coverage. Soft-fix in a follow-up PR.

## Verdict

APPROVED

overall_qc: APPROVED
behavioral_qc: APPROVED
