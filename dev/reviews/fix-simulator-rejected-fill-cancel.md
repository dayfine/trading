Reviewed SHA: ee94cae1a135a99880bf06520a72a3a91b819309

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | All tests passed |
| P1 | Functions ≤ 50 lines — covered by language-specific linter | PASS | All new functions under 50 lines: cancel_handler.ml 47 lines total; largest function transitions_for_rejected_trades is 4 lines |
| P2 | No magic numbers — covered by language-specific linter | PASS | No numeric literals in new code |
| P3 | All configurable thresholds/periods/weights in config record | PASS | No tunable parameters introduced |
| P4 | Public-symbol export hygiene — covered by language-specific linter | PASS | Both new modules (cancel_handler, margin_runner.tick) have complete .mli signatures |
| P5 | Internal helpers prefixed per project convention | PASS | All private helpers in cancel_handler.ml and margin_runner.ml prefixed with underscore |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | PASS | No test files modified in PR; only golden data regenerated. Existing test suite covers simulator end-to-end |
| A1 | Core module modifications | PASS | No modifications to Portfolio/Orders/Position/Strategy/Engine modules |
| A2 | No new `analysis/` imports into `trading/trading/` | PASS | Modified dune file (trading/trading/simulation/lib/dune) contains no new analysis imports |
| A3 | No unnecessary modifications to existing modules | PASS | All file changes (cancel_handler extract, margin_runner.tick consolidation, simulator.ml refactor) are scoped to the rejected-fill fix and margin-consolidation: cancel_handler bridges rejected fills to CancelEntry transitions; margin_runner.tick is extracted from simulator._apply_margin_tick to keep file under 500-line declared-large limit; simulator.ml refactored to delegate fill rejection handling to Cancel_handler + margin mechanics to Margin_runner.tick |

## Verdict

APPROVED

## Summary

This PR fixes a critical silent-swallow bug where the simulator dropped rejected fills (e.g., on next-day-open gap-ups exceeding position-sizing headroom) without notifying the strategy, leaving positions stuck in `Entering` state. The fix routes rejected fills through `Cancel_handler` to emit `CancelEntry` transitions, allowing positions to move to `Closed` and strategies to retry.

**Structural quality:** Excellent. New modules (cancel_handler, margin_runner.tick consolidation) are minimal, well-scoped, and properly exported. Simulator.ml stays under 500-line declared-large limit. All gates pass. Golden data confirms the fix resolves the 0.00% CAGR zero-trade cell (2023-11-13 now 59.24%).

**Architecture:** Respects all project rules — no core-module creep, no dependency inversion, extraction-only pattern on margin mechanics to keep simulator file manageable.

---

# Behavioral QC — fix-simulator-rejected-fill-cancel
Date: 2026-05-18
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | FAIL | `cancel_handler.mli` makes four substantive claims, none of which have a focused unit test: (1) "emits one CancelEntry transition per rejected trade, matched by symbol against Entering positions" — no test; (2) "rejected trades whose symbol has no Entering match are silently skipped" — no test exercising the no-match path; (3) `apply_to_positions` "drops position when Closed" — partially pinned by `test_position.ml:241 test_cancel_entry_no_fills` (verifies the state transition Entering→Closed) but the *Map removal* behavior in `Cancel_handler.apply_to_positions` is not tested; (4) "returns original map unchanged when position_id absent" — no test. Integration coverage exists via sweep golden regen (4→0 zero-trade cells) and the BAH gap-up Monday regression test (test_bah_runner_e2e_gap_up_monday on 2023-06-12), but no test directly exercises a rejected-fill→CancelEntry path with assertions on the resulting position-Map state. **This is the soft-finding the dispatch prompt flagged**: the PR explicitly defers `Cancel_handler` unit tests to follow-ups. See verdict-section reasoning below. |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | PASS-with-nit | (a) `dune build && dune runtest` clean — VERIFIED in docker (EXIT=0). (b) `test_bah_runner_e2e` "5 tests" all pass — VERIFIED, but the test file actually contains **6** tests (the suite at line 365 lists 6 cases: bah_runner_e2e, bah_runner_e2e_brk_b_5y, gap_up_monday, default_strategy_is_weinstein, bah_benchmark_strategy_roundtrips, bah_brk_b_15y_scenario_parses). All 6 pass (OUnit reports "Ran: 6 tests in: 3.93 seconds. OK"). PR body's "5 tests" is a count-typo, not a missing test. (c) Sweep golden regen 0/157 zero-trade cells — VERIFIED in `trading/test_data/weekly-start-sweep-bah-spy.sexp`: 157 cells total, 0 cells with `final_value = 100000` (the no-trade signature). Best 267.25% / worst 9.16% / median 18.25% in `dev/sweep/weekly-start-sweep-bah-spy.md` exactly matches PR body. |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are [equal_to ...] or equal_to on entire value), not just size_is | PASS | The "Baseline impact: NONE" claim is pinned by `test_bah_runner_e2e.ml:108` (`_expected_final_equity = 1_903_976.65` for SPY 2019-2023) and `:118` (`_expected_final_equity_brk_b_5y = 1_769_354.38` for BRK-B 2019-2023), both wrapped in a 0.05% `is_between` band (line 125: `_equity_tolerance_pct = 0.05`). Running the test suite confirms both equity values pin unchanged after the simulator-fix lands. The gap-down day-1 entry path that the PR cites (2019-01-02 close → 2019-01-03 open) is unchanged behavior — no rejection occurs, so the new Cancel_handler code path doesn't fire, equity stays bit-identical. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | FAIL | Two guard claims in `cancel_handler.mli`/`.ml` are not exercised by tests: (1) `_cancel_transition_for_symbol` returns `None` for rejected trades with no matching Entering position ("silently skipped (defensive — should not happen given the strategy invariant)" — `cancel_handler.mli:28`) — no test exercises this defensive path; (2) `apply_to_positions` returns the original map unchanged when `position_id` is absent ("Returns the original map unchanged when the transition's position_id has no entry in [positions]" — `cancel_handler.mli:40`) — no test exercises this defensive path. The pre-existing invariants in CP4 dispatch question are sound: (a) `simulator._process_step_day` order verified — `_process_fills_and_cancels` runs first, applying fills/cancels for orders submitted yesterday from the previous day's CreateEntering transitions. The Entering position is created on day N (in `_apply_transitions` for `CreateEntering`) and the order submitted via `Order_generator.transitions_to_orders` on day N executes on day N+1, so when the fill is rejected on day N+1, the corresponding Entering position exists in `t.positions`. (b) One Entering per symbol — verified by `bah_benchmark_strategy.ml:96-102 _has_position_for_symbol` (excludes Closed only) and `weinstein_strategy_screening.ml:20-24 held_symbols` (same exclusion). Strategy guarantees at most one Entering per symbol per step. So the defensive paths really are defensive — but they're still untested. |

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural's A1 row was PASS — no core-module modifications |
| S1–S6 | Stage definitions / buy criteria | NA | Pure simulator-core fix; no Weinstein stage logic touched |
| L1–L4 | Stop-loss rules / state machine | NA | No stop-loss code touched |
| C1–C3 | Screener cascade / macro / sector | NA | No screener code touched |
| T1–T4 | Domain tests | NA | No domain-feature tests required |

## Quality Score

3 — Correct, minimal fix that resolves a real silent-swallow bug; baseline pinned and sweep coverage confirmed. But the new `Cancel_handler` module ships zero focused unit tests for its 4 docstring contracts and 2 defensive guards, leaning entirely on integration coverage (sweep regen + existing simulator/backtest tests). The author flagged this as a follow-up in the PR body, which is honest, but the docstring promises don't match the test coverage at landing time.

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### CP1: Cancel_handler contracts unpinned by focused tests
- Finding: `cancel_handler.mli` makes four substantive contracts (symbol-match emit, no-match silent skip, Closed→drop, position_id-absent→identity). None has a focused unit test. The PR's test plan relies on integration coverage (sweep golden regen 4→0 zero-trade cells + existing `test_bah_runner_e2e` tests passing). Integration coverage proves the bridge works end-to-end on real BAH+SPY scenarios, but it doesn't pin individual contract claims for regression — a future refactor that breaks one branch (e.g., wrong Map key on Closed-drop) could survive integration tests if BAH happens not to exercise it. **The PR body's "Follow-ups" section explicitly acknowledges this gap** ("Unit tests for `Cancel_handler` (the bridge is covered by the sweep regen, but a focused unit test pinning the rejected-fill → CancelEntry → Closed path would catch regressions sooner").
- Location: `trading/trading/simulation/lib/cancel_handler.mli` lines 20-42; no corresponding `trading/trading/simulation/test/test_cancel_handler.ml` exists.
- Authority: `.claude/agents/qc-behavioral.md` §"Contract Pinning Checklist" CP1: "Each non-trivial claim in new .mli docstrings has an identified test that pins it." All four claims in `cancel_handler.mli` are non-trivial and load-bearing (the symbol-match logic in particular is the entire mechanism of the fix).
- Required fix: Add a focused `test_cancel_handler.ml` with at minimum four tests pinning: (a) one rejected trade with a matching Entering position → one CancelEntry transition with that position_id; (b) one rejected trade with no matching Entering position → empty transition list (defensive no-match path); (c) `apply_to_positions` on a CancelEntry transition for an Entering position → position removed from map; (d) `apply_to_positions` on a CancelEntry transition with absent position_id → original map returned unchanged. None of these tests require simulator state — they operate directly on `Position.t String.Map.t` fixtures, so they're cheap to add.
- harness_gap: LINTER_CANDIDATE — a deterministic golden scenario test for each of the four contracts above is the canonical CP1 fix. The current sweep-regen pattern (run a 157-cell sweep and check no zero-trade cells) is an expensive integration proof; cheap unit tests for the bridge module would catch regressions in seconds instead of minutes.

### CP4: Defensive-guard paths in Cancel_handler are unexercised
- Finding: Two defensive guards in `cancel_handler.ml` are documented but untested: (i) `_cancel_transition_for_symbol` returns `None` for rejected trades whose symbol has no Entering match (`cancel_handler.mli:28` "silently skipped"); (ii) `apply_to_positions` returns `Ok positions` unchanged when `position_id` is absent (`cancel_handler.ml:42` `None -> Ok positions`). Both are defensive against violations of the strategy-invariant ("one Entering per symbol, present when fill is attempted"). The invariant *does* hold across the codebase today (verified: `bah_benchmark_strategy.ml:96 _has_position_for_symbol` and `weinstein_strategy_screening.ml:20 held_symbols` both block re-entry on Entering/Holding/Exiting), so the defensive paths shouldn't fire in practice — but per CP4, guards called out explicitly in docstrings need exercising tests.
- Location: `cancel_handler.ml:27-32` (`_cancel_transition_for_symbol`) and `cancel_handler.ml:41-42` (`apply_to_positions` None branch).
- Authority: `.claude/agents/qc-behavioral.md` §"Contract Pinning Checklist" CP4: "Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario."
- Required fix: Same as CP1 — the two missing tests in (b) and (d) above directly satisfy this row. One additional test PR-sized.
- harness_gap: LINTER_CANDIDATE — same shape as CP1.

---

## Reviewer reasoning on verdict

The dispatch prompt explicitly asked the reviewer to choose between (a) treating the deferred-tests note as ACCEPTABLE-with-follow-up because the sweep regen counts as integration proof, vs (b) NEEDS_REWORK if the gap is unacceptable.

Calling NEEDS_REWORK for the following reasons:

1. **CP1 is mechanically FAIL.** The protocol says "Any FAIL in CP* or S*/L*/C*/T* rows → NEEDS_REWORK." The bar for CP1 is "Each non-trivial claim has an identified test." Sweep-regen integration coverage doesn't count as identified pinning of any specific docstring contract — by that standard, every docstring on every module could be defended as "well, the e2e test covers it."

2. **The follow-up tests are tiny.** Four pure-functional tests on `Position.t String.Map.t` fixtures. Looking at `test_position.ml:241 test_cancel_entry_no_fills` for the pattern, each test is ~10 lines. Total follow-up is ~50 lines including `dune` wiring. Deferring isn't a meaningful cost saving.

3. **The bridge is load-bearing.** This is not auxiliary plumbing — it's the entire mechanism of the silent-swallow fix. A regression in the symbol-match path would re-introduce the exact bug this PR is fixing.

4. **The PR is otherwise excellent.** Structural QC PASS, baseline unchanged, sweep coverage compelling, architecture clean. The fix itself is correct. The verdict is *only* about the test-coverage gap.

Recommended path: add the four-test `test_cancel_handler.ml` as a fast-follow PR, then mark this PR APPROVED on re-review. The author already planned this in the PR body's Follow-ups — making it a same-day fast-follow rather than a deferred item resolves the CP1/CP4 FAILs cleanly.
