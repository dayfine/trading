Reviewed SHA: cbb07da71a410135128be6423f395732e00a0402

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Exit 0; no formatting diff |
| H2 | dune build | PASS | Exit 0; all modules compile |
| H3 | dune runtest | PASS | 27 tests (bar_loader: 8 summary + 12 summary_compute + 7 metadata), 27 passed, 0 failed. Full-repo exit code 1 is pre-existing linter noise identical to what was present on origin/feat/backtest-tiered-loader (runner.ml:193 fn-length, nesting linter on analysis/scripts — all files untouched by this PR; confirmed by running dune runtest on origin/feat/backtest-tiered-loader and observing same failures). |
| P1 | Functions ≤ 50 lines — covered by fn_length_linter (dune runtest) | PASS | Longest new function is rs_line at 22 lines; compute_values at ~25 lines. fn_length_linter FAIL is pre-existing on runner.ml:193, unchanged in this PR. No bar_loader paths appear in linter output. |
| P2 | No magic numbers — covered by linter_magic_numbers.sh (dune runtest) | PASS | All numeric constants (30, 14, 52, 250) live in default_config. All implementation code reads config.ma_weeks, config.atr_days, config.rs_ma_period, config.tail_days. Semantic zeros (0.0 for _average init, List.fold) and tolerance values (1e-6 in test epsilon) are acceptable per CLAUDE.md. Linter noise is pre-existing on other files. |
| P3 | All configurable thresholds/periods/weights in config record | PASS | config record declares ma_weeks, atr_days, rs_ma_period, tail_days. All four tunables are accessed via config.* in the implementation. No domain parameter is hardcoded inline. Default values (30, 14, 52, 250) are documented in the .mli's default_config docstring. |
| P4 | .mli files cover all public symbols — covered by linter_mli_coverage.sh (dune runtest) | PASS | summary_compute.mli declares: config type, default_config val, summary_values type, ma_30w, atr_14, rs_line, stage_heuristic, compute_values. All match .ml public symbols. bar_loader.mli adds Summary module, Summary_compute re-export, updated create/promote/demote/get_summary signatures. All covered. |
| P5 | Internal helpers prefixed with _ | PASS | summary_compute.ml internal helpers: _weekly_bars, _true_range, _true_range_series, _average — all correctly prefixed. bar_loader.ml internal helpers: _default_benchmark_symbol, _load_bars_tail, _benchmark_bars_for, _promote_one_to_summary, _demote_one, _promote_fold — all correctly prefixed. |
| P6 | Tests use the matchers library (per CLAUDE.md) | PASS | test_summary_compute.ml and test_summary.ml both open Matchers and use assert_that with is_some_and, is_none, is_ok, is_error, all_of, field, float_equal, equal_to, is_between throughout. _ok_or_fail helper in test_summary.ml uses assert_failure (not nested assert_that). No nested assert_that inside matcher callbacks. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | Zero diff in trading/trading/orders/, trading/trading/portfolio/, trading/trading/engine/, trading/trading/strategy/. All changes are in bar_loader/ and dev/status/. |
| A2 | No imports from analysis/ into trading/trading/ | PASS | bar_loader.ml and summary_compute.ml import: Core, Status, Types, Fpath, Csv, Time_period, Relative_strength, Sma, Weinstein.Stage, Weinstein.Types, Trading_simulation_data.Price_cache. All are trading/ or analysis/technical/indicators libraries — no analysis/scripts or analysis/data imports. Architecture layer check on this branch passed (dune runtest triggered arch_layer_test.sh with exit 0). |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Files changed vs base (origin/feat/backtest-tiered-loader): dev/status/backtest-scale.md (status update — appropriate), bar_loader/bar_loader.{ml,mli} (extending 3b — appropriate), bar_loader/dune (new deps — appropriate), bar_loader/summary_compute.{ml,mli} (new files), bar_loader/test/{dune,test_metadata.ml,test_summary.ml,test_summary_compute.ml} (test updates — appropriate). test_metadata.ml changes are minimal: _fixture gets trailing () for new create signature; two test names renamed to reflect 3b scope (full vs summary). No extraneous module edits. |

## Rework-Delta Specific Notes

The five rework commits (1c64ef30..cbb07da7) touch only:
- `summary_compute.ml` / `summary_compute.mli` — `rs_line` now calls `_weekly_bars` on both stock and benchmark before passing to `Relative_strength.analyze`. The comment in the implementation (lines 88–92 of rs_line body) explicitly cites Weinstein §4.4 and explains why daily-feed distorts the 52-week zero-line. `.mli` docstring updated to state "Both inputs are daily bars; the helper aggregates each to weekly".
- `test_summary_compute.ml` — new `test_rs_line_uses_weekly_52_window`: 420 days, final 7-day block stock doubles. Hand-computes expected = 104/53 (52-week weekly path); epsilon 1e-6 is tight enough to reject the buggy daily path (which would yield 104/59 ≈ 1.7627 vs 104/53 ≈ 1.9623). `test_rs_line_flat_ratio` fixture resized from 30 to 140 daily bars so the weekly aggregation produces ≥10 weekly bars for rs_ma_period=10.
- `test_summary.ml` — `_summary_fixture` bumped to 420 days with explicit `summary_config` (tail_days = history_days) so the loader fetches enough history for 52-week weekly window.
- `dev/status/backtest-scale.md` — `## Interface stable` value corrected from invalid `PARTIAL — 3a landed` to `NO` with explanatory note. `status_file_integrity.sh` passes (exit 0 confirmed).

## Verdict

APPROVED

All hard gates pass. 27 targeted tests pass. Linter failures are pre-existing on the base branch and touch no files in this diff. rs_line correctly routes through _weekly_bars before Relative_strength.analyze. No new magic numbers. .mli docstring matches implementation. Tests use the matchers library with no nested assert_that. Status file integrity linter passes.

---

# Behavioral QC — backtest-scale 3b (Summary-tier rework: rs_line daily→weekly)
Date: 2026-04-19
Reviewer: qc-behavioral
Re-review after D4 rework (prior pass at 1c64ef30 returned NEEDS_REWORK on D4).

## Behavioral Checklist

| # | Check | Status | Notes (cite authority doc section) |
|---|-------|--------|------------------------------------|
| A1 | Core module modification is strategy-agnostic | NA | Structural APPROVED without A1 flag; no Portfolio/Orders/Engine/Strategy diff in rework commits (cbb07da..463ffd2). |
| S1 | Stage 1 definition matches book | NA | 3b doesn't re-implement stage logic — `stage_heuristic` delegates to existing `Stage.classify` (weinstein/stage), which is covered by that module's own tests. |
| S2 | Stage 2 definition matches book | NA | Same as S1 — delegation to `Stage.classify`. |
| S3 | Stage 3 definition matches book | NA | Same as S1. |
| S4 | Stage 4 definition matches book | NA | Same as S1. |
| S5 | Buy criteria: Stage 2 entry on breakout with volume | NA | 3b is loader scalars, not signal generation. |
| S6 | No buy signals in Stage 1/3/4 | NA | Same as S5. |
| L1 | Initial stop below base | NA | 3b has no stop logic. |
| L2 | Trailing stop never lowered | NA | Same as L1. |
| L3 | Stop triggers on weekly close | NA | Same as L1. |
| L4 | Stop state machine transitions | NA | Same as L1. |
| C1 | Screener cascade order | NA | 3b produces tier-shaped data; cascade orchestration is 3f. |
| C2 | Bearish macro blocks all buys | NA | Same as C1. |
| C3 | Sector RS vs. market, not absolute | NA | Same as C1 — sector RS aggregation is not in this PR. |
| T1 | Tests cover all 4 stage transitions | NA | Delegation — `Stage.classify` module owns stage-transition tests. |
| T2 | Bearish macro → zero buy candidates test | NA | Out of scope for tier loader. |
| T3 | Stop trailing tests | NA | Out of scope. |
| T4 | Tests assert domain outcomes (not just "no error") | PASS | `test_summary_compute.ml` asserts hand-computed numeric values: `atr_14_zero_on_flat_bars`, `atr_14_constant_range=2.0`, `rs_line_flat_ratio=1.0`, and now `rs_line_uses_weekly_52_window=104/53`. `test_summary.ml` asserts specific Summary record fields populated with finite values, not just "Ok". |
| D1 | 30-week MA is computed on weekly-aggregated bars (not 30 daily bars) | PASS | `summary_compute.ml:ma_30w` calls `_weekly_bars` then averages the last `config.ma_weeks` weekly closes. weinstein-book-reference.md §1 "30-week MA is the core trend filter". |
| D2 | MA uses adjusted close, not raw close | PASS | `ma_30w` maps `b.Types.Daily_price.adjusted_close` — correct per Weinstein's long-horizon trend identification. |
| D3 | Stage heuristic fed weekly, not daily, bars | PASS | `stage_heuristic` calls `_weekly_bars` and passes them to `Stage.classify` with `ma_period = config.ma_weeks`. |
| D4 | RS line computed on weekly bars with ~1-year MA window | PASS (was FAIL at 1c64ef30) | weinstein-book-reference.md §4.4: "RS = price_of_stock / price_of_market_average (computed weekly)". `rs_line` now aggregates both stock and benchmark bars to weekly via `_weekly_bars` before invoking `Relative_strength.analyze ~config:{rs_ma_period=52}`. Comment at summary_compute.ml:88-93 explicitly cites §4.4 and states rs_ma_period is interpreted in weekly bars. `.mli` docstring for `rs_ma_period` (lines 20-23) and for `rs_line` (lines 59-66) both state WEEKLY. |
| D5 | Mansfield zero line is a trailing SMA (not a forward or centered average) | PASS | `Relative_strength.analyze` uses `Sma.calculate_sma` (trailing). Verified by reading relative_strength.ml:67 and by construction: `rs_line_flat_ratio` yields exactly 1.0 only with trailing MA of flat series. |
| D6 | Normalized RS is raw_rs / MA(raw_rs), not raw_rs - MA | PASS | weinstein-book-reference.md §4.4 "Mansfield zero line: RS divided by its own long-term average. Above 1.0 = positive territory". `relative_strength.ml:_build_history` computes `rs_value /. rs_ma`, consistent with "divided by". `summary_compute.ml` reads `last.rs_normalized` unchanged. |
| D7 | ATR is Wilder true-range (max of range / gap-up / gap-down) | PASS | `summary_compute.ml:_true_range` computes `max(high-low, |high-prev_close|, |low-prev_close|)`. Matches standard Wilder TR. |
| D8 | All thresholds configurable (no hardcoded numbers in domain logic) | PASS | `ma_weeks=30`, `atr_days=14`, `rs_ma_period=52`, `tail_days=250` all live on `config` record; implementation reads `config.*` throughout. Structural P2/P3 already confirmed this and the rework did not re-introduce hardcoding. |
| D9 | Fixtures sized to exercise the real window (not just pass the minimum-bar check) | PASS (strengthened by rework) | Old `rs_line_flat_ratio` at 30 daily bars was too short to meaningfully exercise weekly aggregation (~6 weekly bars). Bumped to 140 daily bars → 20 weekly bars for `rs_ma_period=10`, giving a 10-bar trailing window with 10 prior bars. `_summary_fixture` in test_summary.ml now uses 420 days with explicit `tail_days=420` — the new rs_line 52-week test spans 60 weekly bars so the 52-week MA window is fully exercised and positioned sensitively over the elevated week. |

## New test validation (`test_rs_line_uses_weekly_52_window`)

I re-derived the expected value by hand to confirm the test is not merely
picking up whatever the implementation emits:

- 420 days from Mon 2023-01-02 (ISO week 2023-W01) through Sun 2024-02-25
  (ISO week 2024-W08). Each ISO week Mon-Sun contains exactly 7 of these
  consecutive days → 60 ISO-week buckets.
- `daily_to_weekly ~include_partial_week:true` produces one weekly bar per
  ISO-week bucket with `adjusted_close` = the last daily `adjusted_close`
  in that week.
- `plateau_days = total_days - elevated_days = 413`. Days 0..412 → weeks
  W01-2023..W07-2024 (inclusive), with stock = benchmark = 100.0 → raw_rs = 1.0.
  The elevated block (days 413..419) is Mon..Sun of ISO week W08-2024, a
  clean single-week boundary. Week 60's stock close = 200.0, benchmark = 100.0
  → raw_rs = 2.0.
- `Relative_strength.analyze` with `rs_ma_period=52` over 60 aligned weekly
  bars produces 9 normalized values (weeks 52..60). The last one uses a
  trailing SMA over weeks 9..60, i.e. 51 bars of raw_rs=1.0 plus 1 bar of
  raw_rs=2.0. MA = (51·1.0 + 1·2.0)/52 = 53/52.
- Normalized at last bar = 2.0 / (53/52) = **104/53 ≈ 1.96226415**.
  That matches the test literal `104.0 /. 53.0` within 1e-6.
- Daily-path counterfactual (the pre-rework bug): the final 7 days are all
  elevated and weeks 54..59 (the trailing 52 daily bars prior to those)
  would mix plateau and elevated values. Worked example: trailing 52 daily
  bars = 45 plateau + 7 elevated, MA of ratio = (45·1.0 + 7·2.0)/52 = 59/52;
  normalized = 2.0/(59/52) = 104/59 ≈ 1.7627. The delta vs weekly path is
  ~14%, well outside the 1e-6 epsilon — so the assertion genuinely fails
  under the old daily code path and passes under the weekly path.

The fixture is a strong regression lock: a future regression to the daily
path, or any off-by-one in `_weekly_bars`, or swapping `rs_ma_period` to a
daily interpretation would all perturb the numerator or denominator by
more than 1e-6.

## Quality Score

4 — Rework is clean and minimal: `_weekly_bars` reused for both inputs; `rs_ma_period=52` kept and semantics clarified in docstrings; comment explicitly cites §4.4. The new test is well-designed (single terminal spike, hand-computable expected, wide epsilon margin vs the buggy alternative). Not 5 because the new test only pins the terminal normalized value — an even stronger lock would assert the MA value itself (53/52) and the series length (9 normalized bars from 60 weekly inputs), making a regression in a different spot — e.g., a one-off shift in `_build_history`'s offset — easier to pinpoint. Minor; does not warrant rework.

## Verdict

APPROVED

## NEEDS_REWORK Items

(none)
