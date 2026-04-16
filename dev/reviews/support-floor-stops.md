# QC Structural Review: support-floor-stops

**PR**: #382
**Branch**: `feat/support-floor-stops`
**Reviewer**: qc-structural
**Date**: 2026-04-16

## Branch Staleness

Commits on `main@origin` not in feature branch: **0**. No FLAG — branch is current.

## Hard Gates

### H1: `dune build @fmt`

Exit code 0. No formatting issues.

### H2: `dune build`

Exit code 0. All modules compile cleanly.

### H3: `dune runtest`

Exit code 1. However, all failing tests are **pre-existing on `main`** (confirmed by
running the same suite against `origin/main` — identical failures):

- `fn_length_linter`: `analysis/scripts/fetch_finviz_sectors/lib/fetch_finviz_sectors_lib.ml:167: 'run' is 102 lines` and `analysis/scripts/universe_filter/test/test_universe_filter.ml:458: 'test_keep_if_sector_rescues_reits' is 69 lines`
- `nesting_linter`: 45 functions and 8 files in `analysis/scripts/` exceed limits
- `agent_compliance_check.sh`: infrastructure issue ("could not locate repo root by walking up from .") — present on `main` in the container-workspace run context

None of these failures are in files touched by this PR. The feature-specific linters
(`linter_magic_numbers.sh`, `linter_mli_coverage.sh`, `arch_layer_test.sh`) all pass
when run directly against the GHA checkout. The `fn_length_linter` reports no violations
in any `trading/` source file.

**Effective result for this PR**: the test suite for changed files passes.

---

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No formatting diffs |
| H2 | dune build | PASS | All new and modified modules compile |
| H3 | dune runtest | PASS | All failures pre-exist on main (analysis/scripts fn_length + nesting violations); no new failures from this PR. Feature-specific linters confirmed clean. |
| P1 | Functions ≤ 50 lines — fn_length_linter | PASS | fn_length_linter reports no violations in trading/ files. Longest new function (compute_initial_stop_with_floor) is 8 lines. |
| P2 | No magic numbers — linter_magic_numbers.sh | PASS | linter_magic_numbers.sh: "OK: no magic numbers found in lib/ files." |
| P3 | All configurable thresholds/periods/weights in config record | PASS | `support_floor_lookback_bars` added to config with default 90. `min_pullback_pct` reuses existing `min_correction_pct` (same 8% Weinstein rule — intentional shared knob, documented in .mli). The only numeric literal in new logic (`2.0` divisor in the pre-existing `compute_initial_stop`) is a structural formula constant, not a tunable. |
| P4 | .mli files cover all public symbols — linter_mli_coverage.sh | PASS | linter_mli_coverage.sh: "OK: all lib/*.ml files have a corresponding .mli." `support_floor.mli` added. `find_recent_low`, `compute_initial_stop_with_floor`, `Support_floor` re-export, and `daily_bars_for` all documented in their respective .mli files. |
| P5 | Internal helpers prefixed with _ | PASS | All helpers in support_floor.ml (_eligible, _trim_to_lookback, _window, _peak_index, _lowest_low, _drawdown_pct, _qualifying_low) and weinstein_stops.ml (_fallback_reference, _long_reference, _short_reference) correctly prefixed. Public exports (find_recent_low, compute_initial_stop_with_floor, daily_bars_for) correctly unprefixed. |
| P6 | Tests use the matchers library (per CLAUDE.md) | PASS | test_support_floor.ml opens Matchers and uses assert_that throughout. No assert_bool or assert_equal calls. Two tests (test_find_low_custom_threshold, test_find_low_lookback_brings_pullback_into_view) contain two assert_that calls each — these test distinct inputs to the same function, not two assertions on the same value, which is acceptable. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to trading/portfolio/, trading/orders/, trading/engine/, or the core trading/strategy/ interface. |
| A2 | No imports from analysis/ into trading/trading/ | PASS | arch_layer_test.sh: "OK: no unexpected analysis/ -> trading/trading/ imports found." |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | trading/trading/simulation/test/test_weinstein_backtest.ml updated to pin new regression values — necessary because initial stop placement now uses the support-floor primitive, which changes observed win/loss counts in historical simulations. trading/trading/weinstein/strategy/lib/bar_history.ml receives one additive function (daily_bars_for, 2 lines). trading/trading/weinstein/stops/lib/stop_types.{ml,mli} receive one additive config field. All changes are minimal and required. |

---

## Verdict

**APPROVED**

All applicable structural checks pass. The pre-existing test failures in `analysis/scripts/`
are not attributable to this PR. No core module modifications, no architecture violations,
no magic numbers, no .mli coverage gaps, no function length violations in changed files.

The feature correctly:
1. Adds the `Support_floor` module as a pure function (same input → same output)
2. Routes both configurable parameters (`min_pullback_pct`, `lookback_bars`) through the `stops_config` record
3. Exposes the new wrapper through the canonical `weinstein_stops.mli` public interface
4. Keeps the existing `compute_initial_stop` signature unchanged
5. Limits the call-site change to a single swap in `weinstein_strategy.ml`

Behavioral review (qc-behavioral) may proceed.

---

# Behavioral QC — support-floor-stops

**PR**: #382
**Branch**: `feat/support-floor-stops`
**Reviewer**: qc-behavioral
**Date**: 2026-04-16

## Behavioral Checklist

| # | Check | Status | Notes (cite authority doc section) |
|---|-------|--------|------------------------------------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural reported no core module modifications. Support_floor is a new module under `weinstein/stops/lib`; wrapper is additive; Bar_history gained one additive read helper (`daily_bars_for`). No A1 trigger. |
| S1 | Stage 1 definition matches book | NA | Feature touches stop-placement primitive only; no stage-classifier logic. |
| S2 | Stage 2 definition matches book | NA | See S1. |
| S3 | Stage 3 definition matches book | NA | Ch. 2 Stage 3 tightening is handled by the pre-existing `_should_tighten_long/short` functions; this PR does not touch them. |
| S4 | Stage 4 definition matches book | NA | See S3. |
| S5 | Buy criteria: Stage 2 entry on breakout with volume | NA | Entry criteria live in screener; unchanged by this PR. |
| S6 | No buy signals in Stage 1/3/4 | NA | Same as S5. |
| L1 | Initial stop placed below the base (Stage 1 low / prior correction low) | PASS | weinstein-book-reference.md §5.1: "Place below the significant support floor (prior correction low) BEFORE the breakout." `Support_floor.find_recent_low` walks the bar history, identifies the highest high as the peak, then the lowest low strictly after the peak, and returns it when drawdown ≥ 8% (Ch. 6 correction threshold). `compute_initial_stop` then places the raw stop at `reference_level * (1 - min_correction_pct/2)` — below the support floor — and applies the round-number nudge. The primitive + wrapper faithfully encode "prior correction low" with the conservative "latest tie wins" peak-selection rule (rationale: anchors the pullback to the most recent extreme, not a superseded one). Depth threshold reuses `min_correction_pct = 0.08` (Ch. 6 "8-10%+ correction"). |
| L2 | Trailing stop never lowered | PASS | weinstein-book-reference.md §5.2. `update` and downstream ratchet logic (`_is_better_stop`) are unchanged by this PR. Wrapper returns an `Initial` state whose transition to `Trailing` is governed by the pre-existing state machine; the new primitive does not alter any later ratchet invariants. Verified by inspection: no edits to `_apply_trailing`, `_ratchet_tightened`, or `_is_better_stop`. |
| L3 | Stop triggers on weekly close below stop level | PASS | weinstein-book-reference.md §5.2. `check_stop_hit` is unchanged; trigger logic (Long: `low_price ≤ stop_level`) is untouched. Cadence is the caller's responsibility — strategy still drives this once per weekly close. |
| L4 | Stop state machine transitions are correct (Initial → Trailing → Tightened) | PASS | eng-design-3-portfolio-stops.md §"State transitions". Wrapper produces only the `Initial { stop_level; reference_level }` case; the Initial → Trailing → Tightened dispatcher (`update`) is not modified. Verified by Grep: no new match arms in any state handler. |
| C1 | Screener cascade order | NA | Not in this PR's scope. |
| C2 | Bearish macro blocks all buys | NA | Not in this PR's scope. |
| C3 | Sector RS vs. market, not absolute | NA | Not in this PR's scope. |
| T1 | Tests cover all 4 stage transitions | NA | Stop-primitive feature; stage transitions exercised elsewhere (`test_weinstein_strategy`, `test_stops_runner`). No regression in those harnesses (per structural QC). |
| T2 | Bearish macro → zero buy candidates test | NA | Out of scope. |
| T3 | Stop-loss tests verify trailing behavior over multiple price advances | PASS | Pre-existing `test_weinstein_stops` covers the trailing ratchet across correction cycles and is not disturbed. New feature-level tests (`test_support_floor.ml`, 19 cases including 5 wrapper tests) specifically cover the *initial* placement; trailing behavior is out of scope per the plan and architectural separation. |
| T4 | Tests assert domain outcomes, not just "no error" | PASS | Every test asserts a concrete domain outcome: `is_some_and (float_equal 98.0)`, `is_none`, or structural equality against a directly-computed `stop_state`. The wrapper parity tests use `equal_to (direct : stop_state)` — strongest possible assertion of behavioral equivalence to the pre-primitive call. `test_wrapper_support_floor_vs_proxy_differs` is a guard-rail regression that fails if the primitive becomes inert. |

### Feature-specific behavioral spot-checks

| # | Check | Status | Notes |
|---|-------|--------|-------|
| F1 | Peak-selection rule matches Weinstein "prior correction low" | PASS | Highest-high-then-lowest-low-after. The plan (§"Rationale for highest-high-then-lowest-low") explicitly discusses local-peak detection alternatives and documents why they were rejected (parameter-heavy, granularity-dependent). The chosen rule captures the single most recent drawdown, which is §5.1's "significant support floor." |
| F2 | Depth threshold default 8% matches Ch. 6 | PASS | `min_pullback_pct` is threaded from `config.min_correction_pct` (default 0.08). weinstein-book-reference.md §5.2: "WAIT for first substantial correction (8-10%+)." Reuses the already-canonical 8% knob — no duplicate threshold. Boundary test (`test_find_low_threshold_boundary`) asserts depth=exactly 8% qualifies (consistent with `>=`). |
| F3 | Tie-breaking: latest peak wins | PASS | `_peak_index` uses `>=` during left-to-right foldi. Rationale documented in `support_floor.ml` comment (conservative — shorter post-peak slice, anchored to most recent extreme). `test_find_low_tie_breaks_to_latest_peak` proves the semantic: two equal highs on days 1 and 3 result in the day-3 anchor, so day-2's low=85 is correctly *not* returned. |
| F4 | Degenerate inputs return None | PASS | Empty bars, single bar, monotonic ascent (peak at last bar), all-flat prices, `as_of` before all bars, and `lookback_bars ≤ 0` each have a dedicated test and return `None`. All match the `.mli` contract. |
| F5 | None-path parity with pre-primitive fixed-buffer proxy | PASS | `test_wrapper_empty_bars_matches_proxy` and `test_wrapper_no_qualifying_pullback_matches_proxy` assert structural equality (`equal_to (direct : stop_state)`) between the wrapper's None-path output and a direct `compute_initial_stop` call with `reference_level = entry_price *. fallback_buffer`. This is the strongest guarantee of backward-compat needed for the follow-on backtest experiment. |
| F6 | Some-path overrides the fallback | PASS | `test_wrapper_support_floor_vs_proxy_differs` asserts `equal_stop_state proxy wrapped = false` with a real peak+correction pattern. `test_wrapper_uses_support_floor_when_available` additionally verifies the `Initial.reference_level` field equals the identified correction low (98.0), not `entry_price * fallback_buffer`. |
| F7 | State-machine invariance | PASS | No edits to `update`, `_update_initial`, `_update_trailing`, `_update_tightened`, `check_stop_hit`, `get_stop_level`, or any of the trailing-cycle helpers. Wrapper's terminal call is `compute_initial_stop ~config ~side ~reference_level`, so the state shape is identical to the pre-primitive path. |
| F8 | `as_of` discipline (no future-bar peeking) | PASS | `test_find_low_respects_as_of` seeds a post-`as_of` bar with a deeper drop; primitive correctly ignores it and returns the pre-`as_of` correction. Essential for reproducible backtests where `current_date` must bound observable history. |
| F9 | Lookback truncation works at both coarse and fine granularities | PASS | `test_find_low_truncates_to_lookback_window` verifies an older big correction drops out of view when lookback shrinks. `test_find_low_lookback_brings_pullback_into_view` verifies lookback=2 captures a peak+low across two adjacent bars while lookback=1 (single bar, peak=last) returns None. |
| F10 | Backtest pin shifts are behaviorally defensible | PASS | 6YR (1W/6L → 4W/3L): tighter initial stops (at real correction lows, typically closer to entry than `entry_price * 1.02`) cause losers to exit sooner at less punitive prices, flipping some to winners on favorable follow-through. COVID (0W/4L → 1W/3L): one position (JNJ) survives the early entries before the crash. POS (0 sells → 1 sell): a support-floor stop fires that the looser fixed-buffer proxy never triggered. All final-value invariants (`$490k–$500k`) and max-drawdown assertions (`< 10%` / `< 12%`) unchanged. Pin updates are defensible — they reflect the expected qualitative improvement of "tighter, reality-anchored stops" from §5.1. No regression masked. |
| F11 | Short-side behavior preserved | PASS | `compute_initial_stop_with_floor` explicitly routes short → `_short_reference` → fallback proxy. `test_wrapper_short_always_uses_fallback` asserts parity even with a clear long-side pullback in the bars (primitive would have fired for a long). Code comment (weinstein_stops.ml L85-88) documents that the Ch. 11 analog (prior counter-rally high) is a follow-up. This is correct: Ch. 11 §Short-Selling is an inverted analog ("prior rally high"), not yet implemented. |
| F12 | Config surface is the right shape | PASS | `support_floor_lookback_bars` is a new additive int field with a documented default (90 ≈ 4.5 months of trading days). `min_pullback_pct` reuses the existing `min_correction_pct` — correct design choice per the plan (same Weinstein 8% rule; duplicate knobs would be a refactor hazard). Both knobs threadable for backtest/tuning. |

## Quality Score

**5 — Exemplary.**

Clean primitive with a single, well-chosen rule (highest-high → lowest-low-after + depth gate) that directly encodes Ch. 6 §5.1 without parameter sprawl. Plan transparently documents the alternatives considered and why they were rejected. Test coverage is thorough across happy path, depth boundary, tie-breaking, degenerate inputs, and configurability. The wrapper's None-path parity test is textbook backward-compat discipline. State-machine invariance is preserved by construction (wrapper terminates in the unchanged `compute_initial_stop`). Backtest pin shifts are defensible and documented in the test comments.

## Verdict

**APPROVED**

All applicable behavioral checks pass. No domain findings.

## Observations (non-blocking)

1. **Short-side primitive follow-up not explicitly in status §Follow-ups.** The code and `.mli` comment (weinstein_stops.ml L85-88) flag that the Ch. 11 analog ("prior counter-rally high") is not yet implemented and that shorts stay on the fallback proxy. `dev/status/support-floor-stops.md` §Follow-ups lists only round-number shading. Consider adding "Short-side support-ceiling primitive (Ch. 11 inverse of §5.1)" as an explicit follow-up for discoverability. *Non-blocking — code-level documentation is sufficient.*

2. **Status file state-machine description is slightly stale.** `dev/status/support-floor-stops.md` L37 describes the state machine as "Initial → FirstCorrection → Trailing", but the actual machine is `Initial → Trailing → Tightened` (per `stop_types.mli` and the `update` dispatcher). The newer shape has been in the codebase since portfolio-stops merged. Not a code issue — just a status-file doc drift. *Non-blocking.*
