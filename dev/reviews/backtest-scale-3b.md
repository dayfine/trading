Reviewed SHA: 1c64ef30ce3d164a0b8f595b15c6217376328d23

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Exit 0, no formatting issues |
| H2 | dune build | PASS | Exit 0, clean build |
| H3 | dune runtest | FAIL | Exit 1 — two pre-existing linter failures, zero new failures introduced by 3b. See note below. |
| P1 | Functions ≤ 50 lines (fn_length_linter) | PASS | The fn_length_linter failure is pre-existing: `trading/backtest/lib/runner.ml:193 run_backtest` at 56 lines. No 3b file appears in the linter output. Longest 3b function is `_promote_one_to_summary` at 36 lines. |
| P2 | No magic numbers (linter_magic_numbers.sh) | PASS | Magic-number linter did not flag any 3b files. All numeric thresholds/windows (30, 14, 52, 250) are declared as fields of `default_config` and consumed via `config.*`. The `+1` guard in `atr_14` (needs at least `atr_days + 1` bars for a prior-close) is an algorithmic constant, not a domain threshold. `0.0` in `_average` is a fold accumulator. |
| P3 | All configurable thresholds/periods/weights in config record | PASS | `Summary_compute.config` holds `ma_weeks`, `atr_days`, `rs_ma_period`, `tail_days`. All indicator primitives receive `~config` and thread through `config.*`. The `benchmark_symbol` default (`"SPY"`) is a loader-level optional arg surfaced in `t.benchmark_symbol`, not a hardcoded string in compute logic. |
| P4 | .mli files cover all public symbols | PASS | `summary_compute.mli` exposes `config`, `default_config`, `summary_values`, `ma_30w`, `atr_14`, `rs_line`, `stage_heuristic`, `compute_values`. `bar_loader.mli` exposes `Summary_compute` re-export, `tier`, `Metadata`, `Summary`, `t`, `stats_counts`, `create`, `promote`, `demote`, `tier_of`, `get_metadata`, `get_summary`, `get_full`, `stats`. mli_coverage linter did not flag any 3b file. |
| P5 | Internal helpers prefixed with _ | PASS | `summary_compute.ml`: `_weekly_bars`, `_true_range`, `_true_range_series`, `_average`. `bar_loader.ml`: `_default_benchmark_symbol`, `_tier_rank`, `_load_metadata`, `_promote_one_to_metadata`, `_load_bars_tail`, `_benchmark_bars_for`, `_promote_one_to_summary`, `_unimplemented_tier`, `_promote_fold`, `_demote_one`. All private; all prefixed. |
| P6 | Tests use the matchers library (per CLAUDE.md) | PASS | Both `test_summary_compute.ml` and `test_summary.ml` open `Matchers` and use `assert_that` throughout. `is_some_and`, `is_none`, `is_ok`, `float_equal`, `is_between`, `field`, `all_of`, `equal_to` are used correctly. No nested `assert_that` inside matcher callbacks. The `__` wildcard is from `Matchers`. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to any core trading modules. |
| A2 | No imports from analysis/ into trading/trading/ | NA | The entire `trading/trading/` tree already depends on `weinstein.*` and `indicators.*` (from `analysis/`) — see `trading/weinstein/strategy`, `trading/simulation`, `trading/backtest/lib`. This is established architectural practice, not a new constraint violation. The 3b additions (`indicators.time_period`, `indicators.relative_strength`, `indicators.sma`, `weinstein.stage`, `weinstein.types`) are consistent with this pattern. |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | The only modification to an existing file is `test_metadata.ml`: (1) adds the required `()` unit arg to `Bar_loader.create` (signature changed in 3b), (2) removes the now-incorrect `test_higher_tier_promotions_unimplemented` test (Summary promotion is implemented in 3b), (3) renames `test_summary_full_getters_return_none` → `test_summary_getter_none_on_metadata_only` with corrected semantics. All changes are necessary adaptations. `bar_loader.ml`/`bar_loader.mli` are the feature files themselves. No other existing modules modified. |

### H3 pre-existing failures — not introduced by 3b

The `dune runtest` exit code is 1 due to:

1. **fn_length_linter**: `trading/backtest/lib/runner.ml:193 run_backtest` at 56 lines. This file was unchanged in the 3b diff. Confirmed pre-existing on the 3a branch (`origin/feat/backtest-tiered-loader`).
2. **nesting_linter**: 25 functions in `analysis/scripts/universe_filter/`, `analysis/scripts/fetch_finviz_sectors/`, and `trading/weinstein/strategy/lib/ad_bars.ml`. None are in the 3b diff files. Confirmed pre-existing on the 3a branch.

No 3b file appears in either linter output.

### §Resolutions verification

- **Tier-internal cache (option b)**: Benchmark bars are cached in `t.benchmark_bars` (mutable field on the loader, `Types.Daily_price.t list option`). Raw bars from `_load_bars_tail` go to `Csv_storage` directly, bypassing `Price_cache`. Verified: `Price_cache.get_prices` is only called in `_load_metadata` for Metadata-tier last-close lookups. Summary promotion does not touch `Price_cache`. PASS.
- **`Bar_history` / `weinstein_strategy.ml` / `backtest_runner_lib` untouched**: Confirmed by `git diff --name-only`. PASS.
- **`demote ~to_:Summary_tier` is a no-op in 3b**: Confirmed — the `_demote_one` function's `Summary_tier` branch returns `{ entry with tier = Summary_tier }` (a no-op since Full tier doesn't exist yet). PASS.

## Verdict

APPROVED

(All applicable items are PASS or NA. H3 exit code is 1 due to pre-existing linter failures that are not in the 3b diff and were present on the 3a base branch. Zero new structural violations introduced by 3b.)

---

# Behavioral QC — backtest-scale 3b (Summary tier)
Date: 2026-04-19
Reviewer: qc-behavioral

## Behavioral Checklist

| # | Check | Status | Notes (cite authority doc section) |
|---|-------|--------|------------------------------------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural did not flag A1; no core module modified. |
| S1 | Stage 1 definition matches book | NA | 3b does not define stage criteria; it delegates to the existing `Stage.classify` (§Stage Definitions already vetted elsewhere). |
| S2 | Stage 2 definition matches book | NA | Same — 3b is a consumer of the existing classifier, not a reimplementation. |
| S3 | Stage 3 definition matches book | NA | Same. |
| S4 | Stage 4 definition matches book | NA | Same. |
| S5 | Buy criteria (Stage 2 entry on breakout with volume) | NA | 3b is the loader tier; buy-signal logic is out of scope. |
| S6 | No buy signals in Stage 1/3/4 | NA | Same. |
| L1 | Initial stop below base | NA | Stops not in this feature. |
| L2 | Trailing stop never lowered | NA | |
| L3 | Stop triggers on weekly close | NA | |
| L4 | Stop state machine transitions correct | NA | |
| C1 | Screener cascade order | NA | Screener integration lands in 3f; 3b is the data layer. |
| C2 | Bearish macro blocks all buys | NA | Macro analysis out of scope for 3b. |
| C3 | Sector RS vs. market, not absolute | NA | Sector analyzer not touched by 3b. |
| T1 | Tests cover all 4 stage transitions | NA | Tier-loader tests; not stage-machine tests. |
| T2 | Bearish macro → zero buy candidates test | NA | Out of scope. |
| T3 | Stop trailing tests | NA | |
| T4 | Tests assert domain outcomes | PASS | Summary tests assert ATR = 1.0 / RS = 1.0 on synthetic flat bars (derivable by hand), insufficient-history leaves symbol at Metadata (exact tier assertion), demotion drops the Summary record. `test_compute_values_assembles_all_four` asserts `rs_line = 1.0` when stock ≡ benchmark. Not just "no error." |
| D1 (domain) | 30-week MA window matches Weinstein §1 | PASS | `ma_weeks = 30` in `default_config`; `_weekly_bars` uses `Time_period.Conversion.daily_to_weekly` (last-bar-of-week, Friday-aligned when complete); `ma_30w` takes the last 30 weekly closes via `List.sub ~pos:(n-30) ~len:30`. The `tail_days = 250` calendar window yields ~178 trading days ≈ 35 weekly bars ending at `as_of`, which is sufficient for a 30-week MA. Matches weinstein-book-reference.md §1 (30-week MA on weekly bars). |
| D2 (domain) | 30-week MA is computed on weekly-sampled bars, not daily | PASS | `ma_30w` first calls `_weekly_bars` before taking the average. Verified via `test_ma_30w_returns_mean` (300 daily bars → ~60 weekly bars → ma_30w resolves). `test_ma_30w_none_when_too_short` confirms 30 daily bars (~6 weekly) returns `None`. |
| D3 (domain) | ATR-14 semantics match Wilder TR formula | PASS (with note) | `_true_range ~prev_close bar = max(high-low, |high-prev_close|, |low-prev_close|)` — correct Wilder TR. First bar skipped (no prior close) via `_true_range_series`. Bars are chronological (CSV storage enforces ascending order), so the "last 14 TRs" slice is the most recent 14 days. **Note:** the implementation uses a **simple arithmetic mean** over 14 TRs, not Wilder's 14-period **smoothed** ATR (`ATR_t = (ATR_{t-1}*13 + TR_t)/14`). The .mli accurately describes the implementation as "Average True Range over the most recent 14 bars" and does not claim Wilder smoothing. The Weinstein book does not mandate Wilder's smoothing — ATR is auxiliary to stop-sizing (3c+). Acceptable as a pragmatic choice. |
| D4 (domain) | RS line implementation matches Weinstein Mansfield (§4.4) | FAIL | Weinstein §4.4: "RS = price_of_stock / price_of_market_average (computed weekly, same day each week, preferably Friday). Mansfield zero line: RS divided by its own **long-term** average." The existing `Relative_strength.analyze` primitive is documented (relative_strength.mli:20) to take **weekly** bars with `rs_ma_period = 52` meaning "52 weekly bars ≈ one year." The 3b code passes **daily** bars to `analyze` (summary_compute.ml:91-92), so with `rs_ma_period = 52` the Mansfield zero line is a **52-day SMA (~2.5 months)** rather than the **~52-week (~1-year)** window Weinstein specifies. This produces an RS normalization that reflects recent ~10-week performance, not the long-term baseline the book prescribes. See notes below. |
| D5 (domain) | Stage heuristic delegates to `Stage.classify` on weekly bars | PASS | `stage_heuristic` first aggregates to weekly via `_weekly_bars`, then calls `Stage.classify ~bars:weekly` — matches `Stage.classify`'s contract (bars must be weekly, chronological). The only override is `ma_period` threaded through from `summary_config`. `ma_type` inherits `Stage.default_config.ma_type = Wma`; this pre-existing choice is documented in `stage.mli:8-9` ("Weinstein's book specifies a plain 30-week SMA, but Wma is a common practical substitute") and is not a 3b regression. `prior_stage:None` is passed, invoking the classifier's cold-start heuristic — appropriate for a "summary" one-shot snapshot. |
| D6 (infra) | Benchmark bars are loaded once per run (not per symbol) | PASS | `t.benchmark_bars : Types.Daily_price.t list option` is a single mutable field on the loader (bar_loader.ml:58). `_benchmark_bars_for` loads lazily on first call; subsequent Summary promotions reuse the cached list. Reload only triggers when `as_of` advances past the cached tail's last bar (bar_loader.ml:170-176) — correct for a forward-replay backtest. No per-symbol benchmark load. |
| D7 (infra) | Insufficient-history handling is silent, not an error | PASS | `_promote_one_to_summary` returns `Ok ()` when `compute_values` returns `None`, leaving the symbol at Metadata tier (auto-promoted earlier in the same call). Documented in both bar_loader.mli:131-133 and the code comment at line 195. `test_promote_summary_insufficient_history_stays_at_metadata` asserts this exact behavior. Matches the plan's framing: "insufficient history is a pre-condition for Summary, not a load failure." No silent drop of symbols that *should* have promoted — the symbol remains accessible at Metadata and a future retry with more history will succeed. |
| D8 (infra) | `demote ~to_:Summary_tier` no-op in 3b is documented | PASS | Comment at bar_loader.ml:260-262: "In 3b the only higher tier is Summary itself; Full tier lands in 3c and will drop the raw bars here. Keep summary as-is." mli:141-143 documents "drops only Full bars (no-op for Summary-only symbols)." Test `test_demote_summary_to_summary_is_noop` asserts the no-op behavior. A future reader reading both .mli and code sees this is intentional. |
| D9 (infra) | Memory: no `Daily_price.t list` retained per promoted Summary symbol | PASS | `entry` record (bar_loader.ml:36-40) has no bar-list field — only `metadata: Metadata.t option` and `summary: Summary.t option`. Raw stock_bars in `_promote_one_to_summary` are let-bound locals that go out of scope after `compute_values` returns. The benchmark tail is retained (shared across all symbols, acknowledged design). **However:** `_load_metadata` uses `Price_cache.get_prices`, which retains every Metadata-tier symbol's full CSV in the shared `Price_cache` (not per-tier state). This compromises the plan's memory goals at the Metadata tier, but it is acknowledged scope in the plan's §Resolutions ("Price_cache kept as the raw-CSV layer"). Not a 3b regression; flagged as ongoing concern to be revisited in 3f when real memory numbers are measured. |

## Notes on D4 (RS line — daily vs weekly)

The `rs_line` helper in `summary_compute.ml`:

```ocaml
let rs_line ~(config : config) ~stock_bars ~benchmark_bars : float option =
  let rs_config : Relative_strength.config =
    { rs_ma_period = config.rs_ma_period }
  in
  Relative_strength.analyze ~config:rs_config ~stock_bars ~benchmark_bars
```

passes the **daily** `stock_bars` / `benchmark_bars` straight through. `Relative_strength.analyze`'s `rs_ma_period` is in units of input-bar cadence — its own test suite (`test_relative_strength.ml`) uses `weekly_bars`, and `relative_strength.mli:20` documents the default `52` as "52 weekly bars ≈ one year."

The summary_compute .mli comment at lines 21-22 acknowledges the ambiguity: "Default: 52 (~one year weekly, or ~52 trading days if daily)." But **the caller unconditionally feeds daily bars**, so the actual behavior is the 52-day (not 52-week) interpretation. The rs_line test (`test_rs_line_flat_ratio`) uses `rs_ma_period = 10` with 30 daily bars and only verifies the flat-ratio edge case (normalized = 1.0 when stock ≡ benchmark), which doesn't exercise the period-length semantics.

Downstream implication: when the Summary tier feeds a "shadow screener" in 3f, symbols will be ranked / gated on an RS that reflects ~2.5-month outperformance, not the book's ~1-year outperformance baseline. This can produce different screener verdicts than the legacy path (which uses `Stock_analysis.analyze` on weekly bars). This matters for the 3g parity test.

**Required fix:** one of:
1. Aggregate `stock_bars` and `benchmark_bars` to weekly inside `rs_line` before passing to `Relative_strength.analyze` — keeps `rs_ma_period = 52` meaning 52 weeks. (Simplest; aligns with book.)
2. Keep daily cadence but set `rs_ma_period = 250` (≈ 52 weeks of trading days) — requires bumping `tail_days` to cover it, and `default_config.tail_days = 250` is already barely enough for the 30-week MA.

Option 1 is the cleaner behavioral fix and matches how `Relative_strength`'s own tests exercise it.

**harness_gap:** LINTER_CANDIDATE — a golden-scenario test with known weekly RS inputs (stock outperforming benchmark by a constant spread over 60 weeks) and an asserted Mansfield-normalized value matching a hand computation on weekly cadence would catch this deterministically.

## Quality Score

3 — Acceptable. Tier bookkeeping, weekly-MA pipeline, stage-heuristic delegation, benchmark caching, insufficient-history handling, and demotion semantics are all faithful to the plan and the Weinstein authority. Tests exercise the math with hand-computable fixtures (flat bars, constant-range bars, identical stock/benchmark) and hit the happy + edge paths. The one domain fidelity gap is D4: the RS line consumes daily bars through a primitive designed for weekly cadence, so the Mansfield zero-line window is 52 days (~2.5 months) rather than the book's ~1 year. This is a meaningful correctness issue for the 3f shadow-screener parity test because RS is the Weinstein gate that separates "strong RS + positive territory = buy" from "negative RS = never buy" (§4.4). ATR not matching Wilder smoothing is noted but acceptable since the .mli describes it honestly and the book doesn't mandate Wilder's form.

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### D4: RS line uses daily cadence where Weinstein (and the underlying primitive) expects weekly
- Finding: `rs_line` passes daily `stock_bars` / `benchmark_bars` directly to `Relative_strength.analyze` with `rs_ma_period = 52`. The primitive's documented contract is weekly bars (see `analysis/technical/indicators/relative_strength/lib/relative_strength.mli:20` and its test suite `test_relative_strength.ml` which uses `weekly_bars`). As a result the Mansfield zero line is computed over 52 calendar-adjacent trading days (~2.5 months), not the ~52 weeks / ~1 year Weinstein specifies in §4.4 ("Mansfield zero line: RS divided by its own long-term average").
- Location: `trading/trading/backtest/bar_loader/summary_compute.ml:87-98` (`rs_line`). Called from `_promote_one_to_summary` in `bar_loader.ml:183-218` with daily `stock_bars` (`_load_bars_tail`) and daily `benchmark_bars` (`_benchmark_bars_for`).
- Authority: `docs/design/weinstein-book-reference.md` §4.4 Relative Strength — "Formula: RS = price_of_stock / price_of_market_average (computed weekly, same day each week, preferably Friday)" and "Mansfield zero line: RS divided by its own long-term average. Above 1.0 = positive territory, below = negative."
- Required fix: Aggregate `stock_bars` and `benchmark_bars` to weekly via `Time_period.Conversion.daily_to_weekly ~include_partial_week:true` inside `rs_line` (or a shared helper) before invoking `Relative_strength.analyze`. Keep `rs_ma_period = 52` — now correctly interpreted as 52 weeks. Add a test that asserts the Mansfield normalization window spans ~1 year of real calendar time, not ~2.5 months.
- harness_gap: LINTER_CANDIDATE — golden scenario with 60+ weeks of stock outperforming benchmark by a constant spread, asserting the normalized RS at t=-0 vs the hand-computed 52-week MA. Deterministic.

## Return

NEEDS_REWORK — RS line's Mansfield zero line is ~2.5 months of daily bars instead of the ~1 year of weekly bars Weinstein §4.4 prescribes; other Summary-tier behaviors (30-week MA, ATR-14, stage heuristic, benchmark caching, insufficient-history handling) are faithful to the authority doc.
