Reviewed SHA: ffb17c4720c17c5552356d9cb1d77a23ad899b39

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
