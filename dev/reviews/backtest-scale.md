Reviewed SHA: d493f2a9da4d7f5cc5cd6715878bfd2e8872c5bc

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
