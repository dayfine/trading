Reviewed SHA: 5474a511

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | 16 tests in snapshot_pipeline suite, all pass |
| P1 | Functions ≤ 50 lines (linter) | PASS | Largest function in pipeline.ml is 33 lines; indicator_arrays and weekly_prefix all under 30 lines |
| P2 | No magic numbers (linter) | PASS | All indicator periods (_ema_period=50, _sma_period=50, _atr_period=14, _rsi_period=14, _stage_weekly_lookback=60, _rs_weekly_lookback=100) are named constants at top of pipeline.ml |
| P3 | Config completeness | PASS | All tunable periods are named module-level constants; no literals embedded in indicator logic |
| P4 | Public-symbol export hygiene (linter) | PASS | indicator_arrays.mli and weekly_prefix.mli fully export all public functions; pipeline.mli unchanged |
| P5 | Internal helpers prefixed per convention | PASS | All private helpers use underscore prefix (_sma, _ema, _atr, _rsi, _true_range, _aggregate_week, etc.) |
| P6 | Tests conform to test-patterns.md | PASS | All 16 tests use `assert_that` + matcher composition (all_of, field, elements_are); no nested assert_that; no List.iter; no bare match arms |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to core modules; all changes confined to snapshot_pipeline submodule within analysis/ |
| A2 | No new analysis→trading imports outside backtest exception | PASS | All 5 files within analysis/weinstein/snapshot_pipeline; dune shows only intra-analysis deps (status, types, weinstein_types, stage, rs, macro, indicators.time_period) |
| A3 | No unnecessary existing module modifications | PASS | File scope verified via gh pr view: exactly 5 files (indicator_arrays.{ml,mli}, weekly_prefix.{ml,mli}, pipeline.ml); no drift into unrelated modules |

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Every public function pinned by tests | PASS | `Indicator_arrays`: sma, ema, atr, rsi each covered by dedicated pinned-value tests; `Weekly_prefix`: build and window_for_day tested via integration in snapshot_pipeline tests |
| CP2 | PR body claims match diff | PASS | Claimed 35× speedup (11K bars 7.47s → 0.21s), bit-identity preserved on 16 hand-pinned tests; all 16 tests still pass; O(N²) → O(N) refactor via precomputation matches diff scope |
| CP3 | Round-trip identity: same input → same output as pre-refactor | PASS | Comment in indicator_arrays.ml states "produced cells are identical to the bit"; comment in weekly_prefix.ml states "bit-identity: aggregation primitives copied verbatim from Time_period.Conversion/_aggregate_week"; all 16 tests verify numerical equivalence (e.g. SMA_50 of [100..149] pinned to 124.5, EMA_50 flat series pinned to 100.0) |
| CP4 | Edge cases preserved | PASS | Warmup NaN cells: indicator_arrays.sma/.ema/.atr/.rsi all populate [0..period-2] or [0..period-1] with Float.nan per spec; empty bar list: pipeline.ml returns Ok [] at line 214; single bar: weekly_prefix.build and _weekly_arrays handle n=1 case (partial week only, no finalized entries) |
| DRY-choice | Design decision: no reuse of existing kernels; justified by API mismatch | PASS | Existing `trading/data_panel/{ema,sma,atr,rsi}_kernel.ml` operate on 2D Bigarray panels (N symbols × T times, per-symbol-per-tick advance); single-symbol scalar-state use case has different API (receives full float array, returns full array). Lifting equations is defensible: avoids panel-allocation scaffolding, achieves identical math (identical alpha formula, identical warmup accumulation order, identical recurrence form). Comment in indicator_arrays.ml acknowledges relationship: "forms mirror the kernels...without the panel scaffolding (one symbol, scalar state)." This is principled DRY violation, not ignorance of existing code. |
| Monotone index | Benchmark scan optimization: pre-Phase-C design | PASS | Code at pipeline.ml lines 64–70 uses monotone pointer `bench_idx` that advances without backtracking; comment at lines 60–62 states "Linear scan from a monotone start pointer so the writer's running cost across all daily calls is O(M) total." This is an emergent design property — not a test pinned goal — but sound: each benchmark bar is visited once across all daily iterations, keeping O(N*M) bounded where M is benchmark bar count. |

## Verdict

APPROVED

## Summary

Phase B O(N²) → O(N) refactor is structurally and behaviorally sound. All hard gates pass. New modules (indicator_arrays, weekly_prefix) are well-documented, follow project conventions, test patterns, and have non-overlapping responsibility (scalar indicators vs. weekly aggregation). The deliberate choice not to reuse existing kernels is justified by API shape mismatch (panel vs. scalar). Bit-identity claim is verified by 16 passing hand-pinned tests. The 35× speedup is consistent with moving from per-call recompute (O(N²) per symbol) to single-pass precompute (O(N)). Ready for merge.
