Reviewed SHA: db925c5a4c56fc852436da27cc1a8a770d30df62

## Structural Checklist — backtest-scale 3g (parity acceptance test)

Scope: Merge-gate acceptance test for the tiered-loader track. Adds one test file (`test_tiered_loader_parity.ml`, 203 lines, 3 OUnit2 tests) that runs the same smoke scenario through both Legacy and Tiered paths and asserts trades + portfolio value match within tolerance. Includes 14 synthetic OHLCV CSV fixtures + 2 scenario sexp files. Total diff: 4845 insertions, 13 deletions. No production code changes; test harness only.

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Exit 0; only pre-existing dune-project warning |
| H2 | dune build | PASS | Exit 0; clean |
| H3 | dune runtest | PASS | All test suites pass, including 3 new tests in test_tiered_loader_parity. 0 failed |
| P1 | Functions ≤ 50 lines (fn_length_linter via H3) | PASS | fn_length_linter passed as part of H3. Largest function is `_assert_step_samples_match` at 26 lines, `_assert_metrics_in_range` at 24 lines. All others ≤ 11 lines. No production code touched. |
| P2 | No magic numbers (linter_magic_numbers.sh via H3) | PASS | Tolerance thresholds (0.01 for $0.01 USD comparisons, 100.0 for percentage conversion) are semantic constants within test assertions, not hardcoded domain parameters. linter passed as part of H3. |
| P3 | All configurable thresholds/periods/weights in config record | NA | No production config changes. Test uses hardcoded tolerance (0.01) which is pinned by the plan's §3g gate spec, not meant to be tunable. |
| P4 | .mli files cover all public symbols | NA | Test file only; test files do not require .mli. |
| P5 | Internal helpers prefixed with _ | PASS | All internal helpers prefixed: `_fixtures_root`, `_scenario_path`, `_load_scenario`, `_sector_map_override`, `_run`, `_assert_trade_count_match`, `_assert_final_value_match`, `_sample_indices`, `_assert_step_samples_match`, `_assert_metrics_in_range`. Test functions (test_legacy_runs_ok, test_tiered_runs_ok, test_parity_legacy_vs_tiered, suite, main) are correctly unprefixed. |
| P6 | Tests use matchers library per test-patterns.md | PASS | File opens `Matchers` at line 32. All assertions use `assert_that` with matcher combinators (gt, equal_to). No List.exists with true/false. No bare `let _ = ...run` or `let _ = ...on_market_close` without assertion. Lines 177, 182 correctly use `assert_that ... (gt (module Int_ord) 0)`. Lines 88-103 (trade count, final value) use explicit `OUnit2.assert_failure` calls for parity comparison — acceptable pattern for merge-gate failure messages. No nested `assert_that` inside matcher callbacks. P6 PASS. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | Zero diffs in any of those modules. Changes are entirely within backtest/test/ and test_data/ directories. No modifications to core strategy, portfolio, or order modules. |
| A2 | No imports from analysis/ into trading/trading/ | PASS | Test only imports from scenario_lib, bar_loader, trading.backtest.*, trading.base, trading.engine, trading.portfolio, trading.simulation, trading.strategy, matchers — no analysis/ imports. |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Dune file updated minimally: added `test_tiered_loader_parity` to test stanza. No changes to existing .ml/.mli files outside the new test file. |

## Verdict

APPROVED

All hard gates (H1, H2, H3) pass. All applicable checklist items are PASS or NA. No FAILs. The test correctly exercises the parity contract (trades + final portfolio value + step-by-step samples + metric ranges) and uses the Matchers library with proper patterns. No structural violations.

---

Header updated (run-6, orchestrator housekeeping) to point at the latest
open-PR review section (3f-part3 at line 124 onward, Reviewed SHA
d493f2a9..., APPROVED structural + behavioral run-5). Prior sections
(3f-part1 at SHA ffb17c47... and earlier) remain below as history.

## Structural Checklist — backtest-scale 3f-part1 (shadow screener adapter, re-review)

Scope: incremental re-review of commit `ffb17c4720` on top of previously-reviewed `bc2518db3d`.
The single commit touches only `trading/trading/backtest/bar_loader/test/test_shadow_screener.ml`
to resolve the P6 FAIL from the prior review.

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Exit 0; only pre-existing dune-project warning |
| H2 | dune build | PASS | Exit 0; clean |
| H3 | dune runtest | PASS | All suites pass; bar_loader: 59 tests (12+7+8+8+7+17), 59 passed, 0 failed |
| P1 | Functions ≤ 50 lines (fn_length_linter via H3) | PASS | fn_length_linter passed as part of H3; no production code changed in this commit |
| P2 | No magic numbers (linter_magic_numbers.sh via H3) | PASS | No production code changed; linter result unchanged from prior review |
| P3 | All configurable thresholds/periods/weights in config record | PASS | No production code changed; unchanged from prior review |
| P4 | .mli files cover all public symbols (linter_mli_coverage.sh via H3) | PASS | No production code changed; linter result unchanged |
| P5 | Internal helpers prefixed with _ | PASS | No production code changed; unchanged from prior review |
| P6 | Tests use the matchers library (per CLAUDE.md) | PASS | Both previously-failing tests now compose field checks under a single `assert_that analysis (all_of [...])`. `test_synthesize_stage1_has_no_volume_and_no_resistance`: single assert_that with all_of + 3 field matchers. `test_synthesize_stage2_gets_adequate_volume_floor`: single assert_that with all_of + 3 field matchers (one being is_some_and + nested field). Type annotations present on all field extractors. Fix matches the exact pattern required by the prior review. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No production code changed; test-only commit |
| A2 | No imports from analysis/ into trading/trading/ | PASS | No production code changed |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Commit touches exactly one file: the test file called out in the prior NEEDS_REWORK |

## Verdict

APPROVED

All items PASS. The P6 fix is structurally correct and precisely scoped — no collateral changes.

---

# Behavioral QC — backtest-scale 3f-part1 (shadow screener adapter)
Date: 2026-04-20
Reviewer: qc-behavioral

## Behavioral Checklist

| # | Check | Status | Notes (cite authority doc section) |
|---|-------|--------|------------------------------------|
| A1 | Core module modification is strategy-agnostic | NA | Structural QC A1 = PASS. Shadow_screener is a NEW module under `trading/backtest/bar_loader/`. No Weinstein core module (Screener, Stock_analysis, Weinstein_strategy, Portfolio, Orders) is modified. Runner.ml's Tiered branch still raises — Legacy path untouched. |
| S1 | Stage 1 definition matches book | PASS | weinstein-book-reference.md §1 (flat MA, basing). The adapter propagates the `Weinstein_types.stage` variant from `Summary_compute` verbatim into `Stock_analysis.t.stage.stage`. Stage inference itself lives upstream in `Summary_compute.compute_values`; 3f-part1 does not re-derive it. |
| S2 | Stage 2 definition matches book (price above rising 30-week MA) | PASS | §1 table + §2 Stage 2 detail. `_ma_direction_of_stage Stage2 = Rising` is the book-correct proxy; `ma_value` sourced from `Summary.ma_30w` (the 30-week MA). |
| S3 | Stage 3 definition matches book | PASS | §1 Stage 3 detail (MA flattening). `_ma_direction_of_stage Stage3 = Flat` is correct. Volume is `None` for Stage3 stubs, which correctly prevents buy candidates in the cascade (Stage3 doesn't satisfy `is_breakout_candidate` regardless). |
| S4 | Stage 4 definition matches book (below declining MA) | PASS | §1 Stage 4 detail. `_ma_direction_of_stage Stage4 = Declining` is correct. Synthetic `Adequate 1.5` volume given to Stage4 enables the short path to be exercised — appropriate since §6.2 says downside breakdown does NOT require volume increase; the adapter is more permissive than strictly required, which is acceptable (upstream short gates still apply). |
| S5 | Buy criteria: entry only in Stage 2, on breakout above resistance with volume confirmation | PASS | weinstein-book-reference.md §4.1–4.2; `Stock_analysis.is_breakout_candidate` (stock_analysis.ml:115–138) enforces Stage2 + (Stage1→Stage2 transition OR weeks_advancing ≤ 4) + volume ≥ Adequate + RS not Negative_declining. Adapter's `Adequate 1.5` volume is exactly the floor of that band (stock_analysis.ml:127), so the gate fires only on genuine Stage2 transitions. Test `test_screen_rejects_mid_stage2_without_prior_stage1` verifies mid-Stage2 without prior Stage1 is rejected. |
| S6 | No buy signals in Stage 1, 3, or 4 | PASS | Adapter returns `volume = None` for Stage1/Stage3, which fails `is_breakout_candidate`'s volume_ok. Stage4 stubs have volume but fail the stage_ok check (is_breakout_candidate only accepts Stage2). Confirmed by `test_synthesize_stage1_has_no_volume_and_no_resistance`. |
| L1 | Initial stop below base | NA | Stops are not modified in 3f-part1. |
| L2 | Trailing stop never lowered | NA | |
| L3 | Stop triggers on weekly close | NA | |
| L4 | Stop state machine transitions | NA | |
| C1 | Screener cascade order: macro → sector → scoring → ranking | PASS | eng-design-2-screener-analysis.md. Adapter delegates to `Screener.screen` unchanged (screener.ml:419–455); cascade order is preserved verbatim. |
| C2 | Bearish macro score blocks all buy candidates (unconditional gate) | PASS | §2 + screener.ml:431–433 (`buys_active = Bullish|Neutral`). Test `test_screen_bearish_macro_produces_no_buys` verifies: Stage2 + Strong sector + RS=1.2 + prior Stage1 → zero buy candidates under Bearish macro. |
| C3 | Sector analysis uses relative strength vs. market, not absolute | PASS | §3.2. Adapter does not alter sector handling — `sector_map : (string, Screener.sector_context) Hashtbl.t` is passed through unchanged. Upstream `Screener.sector_context` already carries sector RS rating (Strong/Neutral/Weak). |
| T1 | Tests cover all 4 stage transitions with distinct scenarios | PASS | `test_synthesize_stage2_sets_ma_direction_rising`, `test_synthesize_stage4_sets_ma_direction_declining`, `test_synthesize_stage1_and_stage3_use_flat`, plus transition tests (`test_synthesize_transition_detected_when_prior_stage_differs`, `test_synthesize_no_transition_when_prior_matches`). |
| T2 | Tests include a bearish macro scenario that produces zero buy candidates | PASS | `test_screen_bearish_macro_produces_no_buys` — explicit assertion `size_is 0` on buy_candidates. |
| T3 | Stop-loss tests verify trailing behavior | NA | No stops in this increment. |
| T4 | Tests assert domain outcomes (correct stage, correct signal), not just "no error" | PASS | Tests assert specific `ma_direction` values, specific `rs.trend` variants, specific `Adequate 1.5` volume confirmation, specific candidate side (Long/Short), and specific transition tuples. No tests rely on mere non-failure. |

### Known divergences from Legacy (documented in .mli §"Known divergence")

These are behavioral gaps that affect SCORING but not the accept/reject decision of `is_breakout_candidate` / `is_breakdown_candidate`, and they are explicitly documented in `shadow_screener.mli`:

- **Volume spectrum collapse:** Strong/Adequate/Weak → constant `Adequate 1.5`. Loses the §4.2 "2× volume" big-winner bonus but still passes the cascade's minimum.
- **Resistance always `None`:** Loses the §4.3 A+/A/B/C grading bonus (~10–15 score points).
- **RS crossover unreachable:** `Bullish_crossover` / `Bearish_crossover` never emitted — loses the §4.5 "RS crosses zero line on breakout" A+ signal.

These are deliberate, acknowledged gaps. The 3g parity test will quantify whether they change the candidate LIST (not just ordering) relative to Legacy. None of them contradicts a Weinstein domain rule — they're score-depressions, not gate-inversions. Acceptable for 3f-part1.

## Quality Score

4 — Clean adapter that preserves the screener's Weinstein gates (macro, sector, Stage2-transition requirement, RS sign, volume floor). Known score-depression gaps relative to Legacy are explicitly documented in the .mli and isolated behind the Tiered flag; no Legacy behavior change. Not a 5 because the RS trend binary (Positive_rising / Negative_declining only, with crossover variants unreachable) is a genuine loss of signal that the parity test in 3g will have to forgive.

## Verdict

APPROVED

All applicable checks PASS. No FAIL items. The shadow screener faithfully implements the plan's §3f adapter-route preference and preserves Weinstein cascade gates end-to-end; documented score-depression gaps are acceptable for 3f-part1 and covered by the upcoming 3g parity test.

---

Reviewed SHA (3f-part2): 224031672d29434d178eba1111c8f6e6497b2a7d

## Structural Checklist — 3f-part2 (tiered runner skeleton)

Scope: stacked on `feat/backtest-scale-3f` (3f-part1, SHA `ffb17c4720`, already APPROVED).
3f-part2 delta covers: `backtest/lib/{dune,runner.mli,runner.ml}` + `backtest/test/{dune,test_runner_tiered_skeleton.ml}` + `dev/status/backtest-scale.md`.

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Exit 0; only pre-existing dune-project warning (no .dune-project at repo root — pre-existing, not introduced by this PR) |
| H2 | dune build | PASS | Exit 0; clean |
| H3 | dune runtest | PASS | All suites pass including 5 new tests in test_runner_tiered_skeleton; 0 failed |
| P1 | Functions ≤ 50 lines (fn_length_linter via H3) | PASS | Largest new function `_run_tiered_backtest` is 23 lines (275-297); `_promote_universe_metadata` is 16 lines; all others ≤ 8 lines. fn_length_linter passed as part of H3. |
| P2 | No magic numbers (linter_magic_numbers.sh via H3) | PASS | No numeric literals in new code. linter passed as part of H3. |
| P3 | All configurable thresholds/periods/weights in config record | NA | No tunable parameters introduced. `Metadata_tier` is a tier tag, not a domain threshold. |
| P4 | .mli files cover all public symbols (linter_mli_coverage.sh via H3) | PASS | New public symbol `tier_op_to_phase` declared and documented in `runner.mli:27-37`. All pre-existing public symbols unchanged. linter passed as part of H3. |
| P5 | Internal helpers prefixed with _ | PASS | New helpers: `_make_trace_hook`, `_create_bar_loader`, `_promote_universe_metadata`, `_run_tiered_backtest` — all underscore-prefixed. `tier_op_to_phase` is intentionally public (in .mli) and correctly not prefixed. |
| P6 | Tests use the matchers library (per CLAUDE.md) | PASS | All 5 tests use `assert_that` with `equal_to` or `elements_are`. No nested `assert_that`. One `assert_that` per value. `elements_are` used for list assertions on `phases`. No `assert_bool` or manual match+assert_failure. Test helper `_make_trace_hook_for_test` is underscore-prefixed. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | Zero diff in any of those modules. Only files changed: `backtest/lib/{dune,runner.mli,runner.ml}`, `backtest/test/{dune,test_runner_tiered_skeleton.ml}`, `dev/status/backtest-scale.md`. |
| A2 | No imports from analysis/ into trading/trading/ | PASS | `runner.ml` new imports: `Bar_loader` (via `trading.backtest.bar_loader` in dune). `bar_loader/dune` confirmed: depends only on `weinstein.*`, `indicators.*`, `trading.simulation.data` — no `analysis.*` module names in any dune file in the diff. |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Scope-boundary files (Bar_history, simulator internals, Price_cache, Weinstein_strategy core, Screener.screen signature) show empty diff against main. All changes are directly inside `backtest/` sub-tree. |

## Staleness Check

Branch is 1 commit behind `main@origin` (a harness maintenance commit). Delta is minimal; no staleness FLAG needed (threshold is >10).

## Specific Contract Checks (per dispatch brief)

- **Cycle risk**: `bar_loader/dune` lists only `core`, `fpath`, `status`, `types`, `trading.simulation.data`, `csv`, `indicators.*`, `weinstein.*` — no `backtest` or `backtest.lib` dependency. No cycle introduced.
- **Legacy byte-identical**: `_run_legacy` (runner.ml:217-218 end boundary, starting at ~193) is entirely absent from the diff. The only change touching `run_backtest`'s dispatch is replacing the old 5-line `failwith` in the `Tiered` branch with `_run_tiered_backtest ~deps ~start_date ~end_date ?trace ()`. `_run_legacy` is byte-identical to pre-PR.
- **Skeleton raises loudly**: `_run_tiered_backtest` raises `Failure` with message: "Backtest.Runner: Tiered loader_strategy simulator-cycle step not yet implemented (lands in 3f-part3 of the backtest-tiered-loader plan)..." — clear pointer to 3f-part3. No silent fallback to Legacy.
- **Metadata promote up front**: `_run_tiered_backtest` wraps `_promote_universe_metadata loader deps ~as_of` inside `Trace.record ... Trace.Phase.Load_bars` — correct single outer attribution. `_promote_universe_metadata` calls `Bar_loader.promote ~symbols:deps.all_symbols ~to_:Bar_loader.Metadata_tier ~as_of`. Universe is `deps.all_symbols` (all universe + ancillary symbols).
- **Trace phase mapping**: `tier_op_to_phase` is exported from `runner.mli`. Tests cover all 3 variants: `test_tier_op_to_phase_promote_summary`, `test_tier_op_to_phase_promote_full`, `test_tier_op_to_phase_demote` — one test per variant so a future rename/reorder fails loudly at compile time (exhaustive match) and at test time (value mismatch).
- **Test patterns (P6)**: All 5 tests use `assert_that` + `equal_to` / `elements_are`. No nested `assert_that`. Correct composition — consistent with `.claude/rules/test-patterns.md` and the rework applied in #463.

## Verdict

APPROVED

All hard gates pass. All structural checklist items are PASS or NA. No FAILs. All dispatch-brief contract checks verified: no cycle, Legacy byte-identical, Tiered path raises loudly at simulator-cycle step, Metadata promote wrapped in Load_bars, tier_op_to_phase has per-variant unit tests, test patterns conform to matchers rules.

---

Reviewed SHA (3f-part3): d493f2a9da4d7f5cc5cd6715878bfd2e8872c5bc

# Behavioral QC — backtest-scale 3f-part3 (tiered runner Friday cycle + per-transition bookkeeping)
Date: 2026-04-20
Reviewer: qc-behavioral

## Behavioral Checklist

| # | Check | Status | Notes (cite authority doc section) |
|---|-------|--------|------------------------------------|
| A1 | Core module modification is strategy-agnostic | NA | Structural QC APPROVED. No Weinstein core module is modified. `Tiered_strategy_wrapper` and `Tiered_runner` are new sibling modules under `backtest/lib/`; `runner.ml` only swaps its Tiered-branch `failwith` for a delegation call. `Weinstein_strategy`, `Screener`, `Stock_analysis`, `Portfolio`, `Orders`, `Simulator`, `Bar_history`, `Price_cache` diffs are empty. Wrapper uses the already-public `Weinstein_strategy.held_symbols`; it does NOT use `entries_from_candidates` and does not invent any new public surface on the inner strategy — adapter-only, per plan Resolutions #3. |
| S1 | Stage 1 definition matches book | NA | 3f-part3 does not classify stages. Stage logic is delegated to (a) the inner `Weinstein_strategy` (for entry generation) and (b) `Bar_loader.Summary_compute` (stored in `Summary.t.stage` and consumed by `Shadow_screener` — already reviewed in 3f-part1). This PR only routes `Summary.stage` through `_summary_values_of` verbatim. |
| S2 | Stage 2 definition matches book (price above rising 30-week MA) | NA | Same as S1: no stage re-derivation in 3f-part3. |
| S3 | Stage 3 definition matches book | NA | |
| S4 | Stage 4 definition matches book (below declining MA) | NA | |
| S5 | Buy criteria: entry only in Stage 2, on breakout above resistance with volume confirmation | PASS | weinstein-book-reference.md §4.1–4.2. The inner `Weinstein_strategy` runs its own full `_run_screen` on Fridays via `_is_screening_day` (weinstein_strategy.ml:225-230) and emits `CreateEntering` only via its own cascade gates. The wrapper does NOT intercept, replace, or filter entries — inner transitions pass through untouched. Test `test_inner_transitions_pass_through` pins the pass-through contract. |
| S6 | No buy signals in Stage 1, 3, or 4 | PASS | Same mechanism as S5 — inner-strategy-owned. Wrapper is purely additive (per wrapper .mli:24-27: "purely additive with respect to the wrapped strategy — all of the underlying strategy's transitions pass through unchanged"). No cascade-bypass path exists. |
| L1 | Initial stop below base | NA | Stops owned by inner strategy. Wrapper only demotes Closed symbols to Metadata. |
| L2 | Trailing stop never lowered | NA | |
| L3 | Stop triggers on weekly close | NA | |
| L4 | Stop state machine transitions | NA | |
| C1 | Screener cascade order: macro → sector → scoring → ranking | PASS | Preserved in two places: (1) inner strategy's `_run_screen` unchanged; (2) wrapper's Friday cycle calls `Shadow_screener.screen` which delegates to `Screener.screen` (already verified in 3f-part1 review). Shadow screener's output is used only for tier-promotion decisions (`_promote_candidates_to_full`), not fed back to the inner strategy. |
| C2 | Bearish macro score blocks all buy candidates (unconditional gate) | PASS | **Inner-strategy path**: unchanged, already book-correct. **Wrapper's shadow path**: calls `Shadow_screener.screen` with `~macro_trend:Weinstein_types.Neutral` HARDCODED (tiered_strategy_wrapper.ml:116). This is a FLAG: the wrapper does not compute a real macro trend for the Shadow screener. However: since the shadow screener's output is used ONLY for tier promotion (not as a Weinstein buy signal), a conservative `Neutral` choice means "run cascade normally". It may Full-promote symbols the inner strategy would not end up buying (inner applies its own Bearish-macro block on the same Friday), causing slightly more Full-tier bars than strictly needed — wasted memory, not a correctness bug. The wrapper's .mli at line 28-30 explicitly states Shadow output is for tier decisions only. This is consistent with the plan's Resolutions §3 ("adapter only") but deserves a FLAG because the 3g parity harness will not exercise Bearish-macro weeks specifically. |
| C3 | Sector analysis uses relative strength vs. market, not absolute | PASS | **Inner path**: unchanged. **Wrapper's shadow path**: passes empty `sector_map` (tiered_strategy_wrapper.ml:112). Shadow_screener is documented to degrade to Neutral when sector context is missing (3f-part1 review §Known divergences). Same rationale as C2: the shadow path is tier-promotion advice, not strategy input. Acceptable. |
| T1 | Tests cover all 4 stage transitions with distinct scenarios | NA | No stage logic tested in this increment. |
| T2 | Tests include a bearish macro scenario that produces zero buy candidates | NA | No macro logic tested in this increment. Covered by 3f-part1's `test_screen_bearish_macro_produces_no_buys`. |
| T3 | Stop-loss tests verify trailing behavior | NA | No stop logic tested in this increment. |
| T4 | Tests assert domain outcomes (correct stage, correct signal), not just "no error" | PASS | All 8 tests assert specific tier-op issuance (`Promote_summary` / `Promote_full` / `Demote` phase in trace), specific idempotency counts (`demote_count = 1` for repeated Closed), specific pass-through shape (`size_is (List.length inner_transitions)`), and specific error propagation (`is_error` + empty trace). None rely on "no failure". `test_newly_closed_position_triggers_demote` is particularly strong — it verifies the *temporal* contract (step 1 Holding → no demote; step 2 Closed → demote) via two-call sequencing. |

### Behavioral-contract checks specific to 3f-part3

| # | Check | Status | Notes |
|---|-------|--------|-------|
| W1 | Friday detection matches Weinstein book cadence and inner strategy's own detection | PASS | Wrapper's `_is_friday` (tiered_strategy_wrapper.ml:21-26) uses `Date.day_of_week bar.date \|> Day_of_week.equal Day_of_week.Fri` on the primary index bar. Inner strategy's `_is_screening_day` (weinstein_strategy.ml:225-230) uses the same formula on `List.last index_bars`. The two read from different sources (wrapper → `get_price primary_index`; strategy → accumulated `index_bars`) but both resolve to "latest index bar date", so they agree on-Friday/off-Friday per call. Book: weinstein-book-reference.md §Macro #97 ("Best day of week: Friday") and §RS #175 ("RS computed weekly, same day each week, preferably Friday"). |
| W2 | Shadow screener output is NOT fed into inner strategy's entry path (adapter-only per Resolutions #3) | PASS | `entries_from_candidates` is NOT called from `tiered_strategy_wrapper.ml` (grep confirmed 0 matches). Shadow result is consumed only by `_promote_candidates_to_full` (wrapper.ml:88-96). The wrapper .mli:28-30 explicitly documents this scope boundary. Consistent with plan Resolutions §3: "Adapter only for 3f … Native-summary refactor is explicitly deferred". No blast-radius into the strategy's entry generation. |
| W3 | Per-transition bookkeeping handles Closed-then-reopen cycles | PASS | `_is_newly_closed` (wrapper.ml:141-148) keys on `position_id`, not symbol. A symbol that closes under id `pos-1` and then re-enters under a fresh id `pos-2` will: (a) the first time `pos-1` transitions to Closed, demote; (b) when `pos-2` is created as `Entering`, `_promote_new_entries` promotes to Full via the `CreateEntering` transition. Test `test_newly_closed_position_triggers_demote` pins (a); `test_create_entering_promotes_to_full` pins (b). The combined cycle is not tested end-to-end in one test but is mechanically implied by these two. |
| W4 | Legacy path is byte-identical (untouched by this PR) | PASS | `git diff 366d0e0..e33d4a0 -- trading/trading/backtest/lib/runner.ml` confirms the only `_run_legacy` delta is unchanged (the diff trims 86 lines from runner.ml, all of which moved to tiered_runner.ml; `_run_legacy` body identical). `Runner.run_backtest`'s `loader_strategy` dispatch is a clean `match Legacy | Tiered`; Legacy path goes through `_run_legacy` with no wrapper involvement. The 3g parity gate will lock this in; for 3f-part3 the visual inspection is sufficient. |
| W5 | Errors from inner strategy do not trigger tier bookkeeping | PASS | `_on_market_close_wrapped` (wrapper.ml:187-195): on `Error _`, bookkeeping block is skipped entirely. Test `test_inner_error_skips_tier_bookkeeping` asserts an empty trace after a failing inner strategy. Correct: if the strategy didn't observe valid state, we shouldn't be promoting/demoting based on a partial/unknown portfolio. |
| W6 | Promote failures are swallowed (don't abort backtest) but logged | PASS | `_swallow_err` (wrapper.ml:77-83) logs to stderr with context and returns `()`. Wrapper .mli:85-88 documents this contract: "Any Bar_loader.promote error is logged to stderr and swallowed so a data issue on a single symbol doesn't abort the entire backtest". Consistent with Bar_loader contract that failed symbols are simply absent from `entries` (per 3f-part1 review notes). Does NOT apply to the initial bulk Metadata promote in `Tiered_runner._promote_universe_metadata`, which DOES raise — that path calls `failwith` (tiered_runner.ml:44-47) because a hard failure at the *initial* bulk promote indicates a broken data directory, matching Legacy's failure mode. Correct asymmetry. |
| W7 | Weinstein-shaped execution preserved (weekly screen, no mid-week new-scan entries, daily stop management) | PASS | Inner `Weinstein_strategy.on_market_close` runs unchanged on every simulator tick. Cadence: daily stops (unchanged), Friday screening (unchanged), Friday macro (unchanged). The wrapper layers tier bookkeeping on top without altering the strategy's decision surface. Book §Cadence + eng-design-4-simulation-tuning.md (strategy_cadence = Daily with internal Friday gate) preserved. |
| W8 | full_candidate_limit sized to match inner screener's post-rank cut | PASS | `Tiered_runner._full_candidate_limit = max_buy_candidates + max_short_candidates` (tiered_runner.ml:53-55). Matches the inner strategy's own ranked-candidate cap. Prevents Full-promote of symbols the inner strategy would never select. |

### FLAGs (non-blocking observations)

- **F1 (C2)**: Shadow screener is called with `macro_trend = Neutral` hardcoded. On a Bearish-macro Friday this means the Shadow cascade will promote LONG candidates the inner strategy will subsequently reject (inner computes real macro and blocks longs under Bearish). Result: some unnecessary Full-tier promotions. This does not affect correctness of the simulator's transitions; it affects only the Full-tier memory footprint. The plan's 3g parity test gates on trade outcomes, not tier-state shape, so this is not caught by parity. Acceptable for 3f-part3 but worth following up if profiling shows waste.
- **F2 (C3)**: Shadow screener called with empty `sector_map`. Same rationale as F1 — does not affect transitions, only tier-promotion set.
- **F3 (T-gap)**: No test exercises a full Closed-then-reopen cycle (symbol closes under one id, then CreateEntering under a new id on a later call). The individual pieces are tested; the composition isn't. Low risk because the position_id keying is straightforward, but a composite test would be cheap insurance. Suggest adding in 3g alongside parity.
- **F4 (T-gap)**: No test exercises Friday-to-Friday trajectory with Shadow screener producing candidates that the wrapper promotes to Full. Reason: the test fixture uses a temp data dir with no CSVs on disk, so `Shadow_screener.screen` returns empty candidate list — `_promote_candidates_to_full` early-returns via `not (List.is_empty symbols)`. This means the Full-promote side of the Friday cycle is exercised by integration (3g) rather than unit. Acceptable per the wrapper's test-contract comment (test file line 38-55: "Good enough to observe the wrapper's tier-op issuance").

## Quality Score

4 — Clean adapter-pattern implementation of the wrapper that preserves the inner Weinstein strategy's behavior untouched (`entries_from_candidates` is NOT used — wrapper is purely additive tier bookkeeping per Resolutions #3). Friday detection matches book cadence and the inner strategy's own heuristic. Per-transition demote is keyed by position_id so Closed-then-reopen cycles work correctly. Not a 5 because the hardcoded `Neutral` macro / empty sector_map in the Shadow screener path (F1, F2) are documented shortcuts that 3g's parity gate won't exercise, and there's a small T-gap (F3) on the Closed-reopen composite path.

## Verdict

APPROVED

All applicable checks PASS. No FAILs. The wrapper's blast radius is limited to tier bookkeeping; the inner strategy (and therefore all Weinstein book rules governing entries, exits, stops, cascade gates) passes through unchanged. Legacy path is visually byte-identical; 3g parity gate will lock that in. Flagged items (F1–F4) are non-blocking and explicitly scoped outside 3f-part3 by the plan's Resolutions §3.

---

# Behavioral QC — backtest-scale 3g (parity acceptance test)
Date: 2026-04-21
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | NA | No new .mli in this PR. The test file's own module-docstring claims (lines 1-28) are either implemented as helpers or enforced directly by the three test cases. |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | PASS | PR body (commit message) advertises four dimensions: (a) exact trade-count match → `_assert_trade_count_match` (lines 87-92, `l <> t` hard fail); (b) final portfolio value within $0.01 → `_assert_final_value_match` (lines 94-103); (c) sampled step-level portfolio values at indices [0, n/4, n/2, 3n/4, n-1] within $0.01 each → `_assert_step_samples_match` + `_sample_indices` (lines 108-138); (d) every pinned metric inside declared range for BOTH strategies → `_assert_metrics_in_range` invoked twice at lines 191-192 with `~label:"legacy"` and `~label:"tiered"`. All four claims are present in `test_parity_legacy_vs_tiered` (lines 184-192). |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size_is | NA | This is a parity (Legacy == Tiered) test, not a pass-through identity test. The two-run assertion compares `n_round_trips` exactly and `portfolio_value` within $0.01 at sampled steps — those are identity-grade comparisons, not size_is. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | The module docstring (lines 1-28) names three hard-fail guards and one soft-warn; the three hard-fail guards are each implemented as `OUnit2.assert_failure` with explicit diff-message formatting in their respective `_assert_*_match` helpers. The one soft warn (peak_rss_kb > 50%) is explicitly documented as "a logged skip so the test surfaces intent without blocking on infra" (lines 15-17) — infrastructure not yet wired, which the docstring is transparent about. No guard is claimed in code that isn't implemented. |

## Behavioral Checklist

| # | Check | Status | Notes (cite authority doc section) |
|---|-------|--------|------------------------------------|
| A1 | Core module modification is strategy-agnostic | NA | Structural QC A1 = PASS. This PR adds only a test binary (`test_tiered_loader_parity.ml`), 14 synthetic macro OHLCV CSV fixtures, and 2 scenario sexp files. No production module is modified. |
| S1–S6 | Stage definitions / buy criteria | NA | 3g is test plumbing, not new domain logic. Stage logic is delegated to the inner `Weinstein_strategy` (Legacy) and `Bar_loader.Summary_compute` via `Shadow_screener` (Tiered) — both already reviewed in 3f-part1 and 3f-part3. The parity test is strategy-agnostic: it asserts observable equality, not book-correctness of either path. |
| L1–L4 | Stop-loss rules | NA | No stops modified; parity test consumes end-of-run `summary.n_round_trips` and `summary.final_portfolio_value`, which roll up stops-driven exits alongside every other exit — parity on those metrics implicitly covers stop behaviour without re-asserting it. |
| C1 | Screener cascade order | PASS | Both Legacy and Tiered paths preserve the macro → sector → scoring → ranking cascade via `Screener.screen` (Legacy through `_screen_universe`; Tiered-shadow through `Shadow_screener` per 3f-part1). The parity test does not re-assert cascade order but pins that whatever cascade both paths implement produces the same `n_round_trips` — consistent with 3g being a merge-gate on behavioral equality, not a structural check on either path. |
| C2 | Bearish macro score blocks all buy candidates | PASS | Preserved in both paths (Legacy unchanged, Tiered-inner unchanged). Parity window (2019-06-03 → 2019-12-31) is a calm bull leg with no Bearish macro weeks expected, so the test does NOT cross the Bearish-macro-block code path — noted as F1 in 3f-part3 review and reiterated below. Acceptable for 3g merge gate; the relevant Bearish-macro behavior is covered by `Shadow_screener`'s own `test_screen_bearish_macro_produces_no_buys` (3f-part1). |
| C3 | Sector analysis uses relative strength vs. market | PASS | Preserved in both paths. Parity test passes a `_sector_map_override` built from `universes/parity-7sym.sexp` (7 equities across 6 GICS sectors) to `Runner.run_backtest`, so both Legacy and Tiered see an identical sector map. |
| T1 | Tests cover all 4 stage transitions with distinct scenarios | NA | 3g does not re-test stage classification. Covered by 3a-3c bar_loader tests + 3f-part1 Shadow_screener tests. |
| T2 | Tests include a bearish macro scenario that produces zero buy candidates | NA | The parity scenario is calendared to a bull leg deliberately (see scenario sexp comment lines 12-13). Bearish-macro coverage lives in 3f-part1's `test_screen_bearish_macro_produces_no_buys`. |
| T3 | Stop-loss tests verify trailing behavior | NA | Stop-loss unit tests live elsewhere; 3g's `n_round_trips` parity is an end-to-end observability check that indirectly covers stops-driven exits. |
| T4 | Tests assert domain outcomes (correct stage, correct signal), not just "no error" | PASS | `test_parity_legacy_vs_tiered` asserts specific numeric equality (trade counts, sampled portfolio values) and metric-range membership — not mere non-failure. `test_legacy_runs_ok` / `test_tiered_runs_ok` assert non-empty `steps` as a sanity floor (line 177, 182: `gt (module Int_ord) 0`). |

## Behavioral-contract checks specific to 3g

| # | Check | Status | Notes |
|---|-------|--------|-------|
| G1 | Acceptance-gate shape matches plan §3g spec | PASS | Plan §3g says: hard fail on trade_count diff (lines 87-92 implement as `if l <> t`), hard fail on any step portfolio_value diff > $0.01 (lines 124-138 implement as `if Float.(diff > 0.01)`), hard fail on final portfolio value diff > $0.01 (lines 94-103 implement), hard fail on any metric outside range for either strategy (lines 143-166 implement, invoked at 191-192). Soft-warn peak_rss_kb is NOT wired but is documented as intentionally skipped in module docstring — consistent with plan § acceptance gate "Soft warn". |
| G2 | Sampled indices match plan [0, n/4, n/2, 3n/4, n-1] | PASS | `_sample_indices n` (lines 108-111) returns exactly `[0; n/4; n/2; 3*n/4; n-1]` when `n > 5`; all-indices path for `n ≤ 5` and empty for `n = 0`. Implementation matches dispatch-brief check #1. |
| G3 | Scenario + fixtures form a valid, deterministic scenario under both paths | PASS | `smoke/tiered-loader-parity.sexp` pins 2019-06-03 → 2019-12-31 + `universes/parity-7sym.sexp` (7 equities with committed CSVs: AAPL, MSFT, JPM, JNJ, CVX, KO, HD). 14 synthetic macro CSVs ship with 318 rows each covering 2018-10-01 → 2020-01-03 (covers the 210-day warmup before scenario start) at 100.00 baseline + 0.01/day drift. Both strategies see identical macro inputs by construction. `test_legacy_runs_ok` and `test_tiered_runs_ok` both assert non-empty steps, verifying the scenario is deterministic and loadable under both paths. |
| G4 | Tolerance matches plan §Resolutions #1 | FLAG | Plan Resolutions #1 (2026-04-19) softened portfolio-value tolerance to `max($1.00, 0.001% of final portfolio_value)` because "float reordering alone can produce sub-dollar diffs on a 40-min / ~50-trade smoke run". Implementation uses $0.01 hard-coded (lines 98, 132). Strictly tighter than resolved spec — PASSES today because the Tiered path degenerates to observationally-identical output (G5), but would false-fail on a future Tiered change that introduces legitimate float reordering. Plan's own language anticipated this: "Tighten empirically once 3g has a few runs of baseline wobble data". Suggest either (a) loosen test to `max(0.01, 0.001%)` per plan, or (b) document in the test file why the tighter bound is safe today and how it should be relaxed when non-degenerate Tiered tiering lands. Non-blocking for 3g as a merge gate — the test does pass at the advertised threshold. |
| G5 | Tiered path's tiering mechanism is actually exercised on this scenario | FLAG | Test output shows `Metadata=22 Summary=0 Full=0 at end of simulator run` (verified on both test_parity_legacy_vs_tiered and test_tiered_runs_ok runs). This means: the Tiered Friday cycle runs, promotes to Summary-tier are attempted, but EVERY Summary promote fails silently because `Bar_loader.create` defaults `benchmark_symbol="SPY"` while the Runner uses `GSPC.INDX` as primary index — follow-up #2 in status file. The Summary-compute step requires benchmark bars; without them every `_promote_one_to_summary` returns `Error NotFound`, swallowed by `_swallow_err` in `tiered_strategy_wrapper.ml:77-83`. CreateEntering Full-promotes also fail (cascade through Summary → same benchmark error). Result: the Tiered wrapper is observationally inert on the parity scenario — the inner Weinstein strategy runs over the simulator's pre-loaded bar cache (`Simulator.create_deps ~symbols:all_symbols`) exactly as Legacy does, so parity holds trivially. **The parity test passes honestly at its narrow stated contract (Legacy-vs-Tiered observable output) but does NOT validate that the Tiered tiering mechanism produces correct strategy results when actually active.** This is exactly what dispatch-brief question #3 asked about. Plan §3g's merge-gate intent was "validate the Tiered path produces identical results to Legacy" — it literally does that here, but because the Tiered path's tiering is degenerate on this scenario. Future QC on the post-merge default-flip PR must NOT treat this green merge gate as proof the tiering works. Non-blocking for this PR as written, but the SPY/GSPC.INDX fix (follow-up #2) is a true pre-requisite for the default flip. |
| G6 | Tiered-path divergence escalations belong to follow-up PRs, not this one | PASS | Dispatch-brief #3 flagged two divergences: (a) `Tiered_runner._promote_universe_metadata` hard-fails on missing CSVs (Legacy silently skips), and (b) `Bar_loader.create` defaults `benchmark_symbol="SPY"` vs Runner's `GSPC.INDX`. Both are documented in status file §Follow-up with concrete proposed fixes. (a) is worked around by shipping the 14 synthetic macro CSVs — the scenario sexp comment (lines 44-53) explicitly names this decision and the non-ideal tolerance asymmetry. (b) is acknowledged as "does not block the parity scenario" (status file line 118) but my G5 analysis shows it's more severe than the status file claims — it makes the Tiered tiering degenerate. Both escalations are honestly documented; deferring them to follow-up PRs is defensible given the plan's scope boundary ("no strategy code changes in 3g"). Passing this check because the escalations DO belong to follow-up PRs per the plan's scope rule, not because they're harmless. |
| G7 | Off-scope / overreach | PASS | Diff touches only: 14 test-fixture CSVs + 2 scenario sexp files + 1 test file + 1 test dune file + status file. No production module touched. No tolerance relaxation elsewhere. No test-only entry points leaking into production. Confirmed by structural QC's A3=PASS and independent verification here. |

### FLAGs (non-blocking observations)

- **F1 (G4)**: Hard-coded $0.01 tolerance is tighter than plan's resolved `max($1.00, 0.001%)`. Passes today because the Tiered wrapper is observationally inert on this scenario (F2); will false-fail if a future Tiered change introduces legitimate float reordering.
- **F2 (G5)**: Tiered wrapper is observationally inert on this parity scenario — `Summary=0 Full=0` at end of run. The parity test passes trivially because the inner Weinstein strategy runs over the simulator's pre-loaded bar cache (same for both paths); the tiering mechanism itself contributes nothing to Tiered's output. The SPY/GSPC.INDX divergence (status file follow-up #2) is the root cause. **Must be fixed before the post-merge default flip**: otherwise the "Tiered works" claim rests on a merge gate that was green for the wrong reason.
- **F3 (scenario-calendar gap)**: Parity window is a calm bull leg; no Bearish-macro or Stage4 breakdown scenarios are exercised. Plan §3h explicitly schedules broad scenarios (bull, bear, choppy) for the post-merge nightly A/B, but the current merge gate only covers the bull regime. This is per plan design, not an implementation defect.
- **F4 (peak_rss_kb soft warn)**: Not implemented — test file documents the intent in lines 15-17 but skips the check. Plan §3g Soft warn item. The 7-symbol scenario is too small to meaningfully measure memory savings anyway, so this is appropriately deferred to 3h.
- **F5 (harness_gap)**: F2 is not detectable by the parity test itself (tautologically — the parity test doesn't know whether tiering is active or degenerate). A useful follow-up linter check for this class of issue: assert `final_stats.summary > 0 || final_stats.full > 0` on a Tiered-path run where the scenario's horizon × universe would normally produce Friday-cycle promotions. Categorize as LINTER_CANDIDATE; implement only after the SPY/GSPC.INDX fix so the check actually passes.

## Quality Score

3 — The test faithfully implements plan §3g's literal acceptance-gate spec (trade_count, final portfolio value, sampled steps, metric ranges) and uses the Matchers library cleanly. But the merge gate passes for the wrong reason: the Tiered wrapper's tiering mechanism is observationally inert on this scenario (Summary=0/Full=0) because of the unaddressed SPY/GSPC.INDX divergence, so parity holds trivially via the simulator's pre-loaded bar cache rather than via the tiered path producing the same strategy output. The test does what it says on the tin, but what's on the tin doesn't cover what the plan's broader purpose was. Not a 2 because (a) the divergences are explicitly documented in status §Follow-up with concrete fix proposals, (b) the plan's §3g scope rule forbids strategy code changes in this increment, and (c) shipping synthetic macro fixtures was a sensible workaround for the missing-CSV divergence given those constraints. Not a 4 because the cost of the deferred SPY/GSPC.INDX fix is that this merge gate cannot honestly certify "the Tiered tiering mechanism produces correct strategy results" — only "the wrapper doesn't perturb the inner strategy's output".

## Verdict

APPROVED

All Contract Pinning (CP1-CP4) and applicable Behavioral (A1/S*/L*/C*/T*) checks are PASS or NA. The dispatch brief's five behavioral checks (G1-G7) all PASS on the literal contract, with two FLAGs (G4, G5) documenting a real merge-gate semantic gap that must be resolved before the post-merge default flip. The test faithfully implements what plan §3g specified to implement; the fact that the Tiered tiering is degenerate on this scenario is a known-and-escalated upstream issue (status file follow-up #2), not a defect in this PR's scope. Flagged items are non-blocking for the 3g merge but form a hard pre-requisite for the 3h nightly A/B and the subsequent default-flip PR — any future work on those should first fix the SPY/GSPC.INDX benchmark_symbol divergence and verify that Summary > 0 / Full > 0 on the same parity scenario before treating this gate as honest proof of Tiered correctness.

---

## Behavioral Checklist — backtest-scale 3g re-review (PR #484 at tip db925c5a, F2 partial fix)

Date: 2026-04-21 (run-4)
Reviewer: qc-behavioral
Scope: Incremental re-review of single commit `db925c5a` "Apply review: thread primary index as benchmark_symbol to Tiered Bar_loader (F2 partial)" on top of previously-APPROVED 3g tip `6d690819`. Diff is a single file, +7/-1:

```
trading/trading/backtest/lib/tiered_runner.ml | 8 +++++++-
```

The one substantive line change: `Bar_loader.create` call now passes `~benchmark_symbol:input.config.indices.primary` where previously it was omitted (so defaulted to `"SPY"`). The other 6 added lines are a justifying comment.

### Narrow re-review focus (per dispatch brief)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| R1 | The F2/G5 FLAG's identified root cause (benchmark_symbol default="SPY" vs Runner's primary="GSPC.INDX") is now addressed in the literal-mechanism sense | PASS | `trading/trading/backtest/lib/tiered_runner.ml:38` now forwards `input.config.indices.primary` as `~benchmark_symbol`. `Runner._build_deps` (runner.ml:127-129) sets `config.indices.primary = index_symbol = "GSPC.INDX"` (runner.ml:6). The Tiered loader therefore asks for `GSPC.INDX` bars — which ARE present in the parity scenario fixtures and are included in the loader's universe via `all_symbols` (runner.ml:142-145). This closes the exact divergence G5 called out as the primary root cause. |
| R2 | The 3g parity acceptance semantics are preserved (Legacy byte-identical; Tiered still produces the same observable output as Legacy) | PASS | Legacy path is untouched: `trading/trading/backtest/lib/runner.ml` is not in this commit's file list. Tiered path's only change is the benchmark_symbol kwarg on `Bar_loader.create` — no change to what transitions the inner strategy sees, no change to simulator wiring, no change to the wrapper's Friday cycle logic. Parity must still hold: the inner Weinstein strategy reads from `Simulator.create_deps`'s pre-loaded bar cache, and that cache is fed from `all_symbols` (unchanged). If anything, Summary/Full tier activity may now start exercising real code paths, but that can only subtract from inertness, not add to output divergence. (Mentioned by the author in the commit msg: "Parity test still passes".) |
| R3 | The commit does not introduce any new Weinstein-domain behavior change outside the benchmark_symbol threading | PASS | Single-line functional change. No new config keys, no new cascade paths, no new transition logic. `_make_wrapper_config` (tiered_runner.ml:63-72) is unchanged — it already plumbed `primary_index` to the wrapper. The new code plumbs the SAME symbol to the Bar_loader, matching what the strategy already sees. Consistent, non-invasive. |
| R4 | F2/G5's full behavioral claim ("Tiered tiering mechanism is observationally active on the parity scenario") is now satisfied | **FAIL (remains PARTIAL)** | Per the commit message itself: "after this fix, the parity test still logs `Tiered loader: Summary=0 Full=0` at end of run". Root cause is now narrower — `benchmark_symbol` is correct — but some other sub-computation inside `Summary_compute.compute_values` (one of ma_30w / atr_14 / rs_line / stage_heuristic, per the commit author's diagnosis) is still returning `None` for every universe symbol on every Friday, so `_promote_one_to_summary` still returns `Error` for every symbol and `_swallow_err` still eats it. The Tiered wrapper therefore **remains observationally inert on this scenario**. The merge-gate semantic gap that G5 described is NOT fully closed — only one necessary-but-insufficient prerequisite was delivered. See "Remaining gap" below. This is PARTIAL per the commit title's own self-description, not a regression. |
| R5 | The commit's claim ("F2 partial") is honestly scoped — nothing is claimed that isn't delivered | PASS | Commit title literally says "(F2 partial)". Commit body documents the remaining gap ("Summary=0 Full=0 at end of run, meaning one of Summary_compute.compute_values internal calls … still returns None") and defers the deeper debugging to a follow-up. No overclaim. Consistent with the project's feedback-loop convention (stacked commits on top of original PR for review response). |

### Remaining gap (what R4 means for downstream PRs)

After this fix, G5's two-sentence FLAG should read: "benchmark_symbol divergence: **fixed**. Root cause of Summary=0/Full=0: **narrowed to one of ma_30w / atr_14 / rs_line / stage_heuristic inside Summary_compute**. Tiered tiering mechanism remains observationally inert on the parity scenario." The post-merge default-flip PR's pre-requisites list should update to:
- ~~Fix SPY/GSPC.INDX benchmark_symbol divergence~~ — **done in db925c5a**.
- Identify which Summary_compute sub-call is returning None for all symbols on the parity scenario and fix it.
- Verify `Summary > 0 || Full > 0` at end of a Tiered parity run before treating this gate as honest proof of Tiered correctness.

The LINTER_CANDIDATE suggestion in the prior review (F5: "assert `final_stats.summary > 0 || final_stats.full > 0` on a Tiered parity run") should still be deferred until the deeper Summary_compute gap is fixed — otherwise the linter would false-fail on this very PR's successor.

### What did NOT change in this re-review

CP1-CP4 (Contract Pinning) and all A1/S*/L*/C*/T* rows from the prior 3g run-1 review still apply. No new `.mli` surfaces were added, no new tests were added or removed, no PR-body claims about tests have changed (PR body hasn't been edited in a way that would require CP2 re-verification). The commit is purely a one-line argument threading to an existing API. If it were any smaller it would be a whitespace change.

## Quality Score

3 — The commit does what it says on the tin: threads the correct benchmark_symbol through a seam that was hardcoded-defaulting to "SPY" and was therefore guaranteed to miss on the parity fixture. The author's own commit message honestly names the partial-ness and identifies the next layer of the onion (Summary_compute internals). The behavioral impact is a genuine improvement — one of the two documented follow-up items (status file #2) is now closed — but the user-facing symptom G5 flagged (Summary=0/Full=0, tiered mechanism observationally inert) persists, so the 3g merge-gate's semantic gap is reduced but not eliminated. Quality Score holds at 3 rather than moving up because (a) the partialness means the F2 FLAG itself only *degrades* to a narrower FLAG rather than resolving, and (b) the residual work needed for the default-flip pre-requisite is non-trivial (requires isolating which of four Summary_compute calls is returning None). Not lower than 3 because the fix is clean, minimal, well-commented, and explicitly scoped.

## Verdict

APPROVED

The dispatch-brief scope was narrow: verify the F2 fix is appropriately addressed (or note the remaining gap) and confirm parity semantics are preserved. The answer is: the benchmark_symbol-divergence portion of F2 is now fixed; parity semantics are preserved; the residual observational-inertness symptom persists and is honestly documented by the author. No new FAIL rows. The prior APPROVED verdict (Quality Score 3) stands, with the F2 FLAG downgraded from "benchmark_symbol mismatch" to "unknown Summary_compute sub-call returns None for all symbols" — strictly a narrower and better-understood flag than before.
