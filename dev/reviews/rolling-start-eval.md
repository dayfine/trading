Reviewed SHA: 4a49095fea60b66ca1ff1e25756b8eb1d4cedff1

## Structural QC — rolling-start-eval exe (PR #1476)

### Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | Zero format violations |
| H2 | dune build | PASS | Full build succeeds |
| H3 | dune runtest trading/backtest/rolling_start/ | PASS | 34 tests pass (19 dispersion-stats + 8 types + 7 runner) |
| P1 | Functions ≤ 50 lines (linter) | PASS | Longest functions: runner.ml `per_start_of_summary` 27 lines; bin `_parse_flag` 39 lines; all under hard limit |
| P2 | No magic numbers (linter) | PASS | linter passed as part of H3 |
| P3 | Config completeness | PASS | No numeric literals; all scenario/execution params come from command-line flags or scenario fields |
| P4 | Public-symbol export hygiene (.mli coverage) | PASS | `rolling_start_runner.mli` fully documents all three public functions + config type with comprehensive docstrings |
| P5 | Internal helpers prefixed per convention | PASS | All internal functions properly prefixed with underscore |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | PASS | single `assert_that` per value; composed matchers; no nested `assert_that`; no bare `let _` on Results |
| A1 | Core module modifications | NA | No changes to Portfolio/Orders/Position/Strategy/Engine |
| A2 | No improper analysis/ → trading/trading/ imports | PASS | All imports within backtest-allow-list |
| A3 | No cross-feature drift | PASS | PR touches exactly 8 files; matches `gh pr view 1476 --json files` |

### Structural Verdict

APPROVED

---

## Behavioral QC — rolling-start-eval exe (PR #1476)

**Nature of PR:** additive / analysis-only tooling. The `rolling_start_eval` exe +
`rolling_start_runner` lib enumerate backtest start dates, run
`Backtest.Runner.run_backtest` per start, project each result's terminal metrics
into a `Rolling_start_types.per_start`, and assemble a dispersion `report`. It
contains **no Weinstein domain logic** (no stage classification, buy/sell
criteria, stop machine, or screener cascade). Per
`.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely",
the entire S*/L*/C*/T* domain block is **NA**. The review surface is the generic
Contract Pinning Checklist (CP1–CP4).

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial .mli docstring claim has an identified test that pins it | PASS | `enumerate_starts`: "first element = scenario_start when start<end" → `test_enumerate_first_and_last` (`field List.hd_exn (equal_to scenario_start)`); "steps by stride_days, emits every start strictly before end_date" → `test_enumerate_quarterly` (Jan/Apr/Jul/Oct, last is Oct 1 < Dec 31 end); "start==end_date excluded; last is greatest start <end_date" → `test_enumerate_first_and_last` (`field List.last_exn (lt end_date)`) + `test_enumerate_empty_when_start_eq_end`; "empty when start>=end" → `..._start_eq_end` + `..._start_after_end`; "@raise Invalid_argument if stride_days<=0" → `test_enumerate_rejects_nonpositive_stride`. `per_start_of_summary`: "cagr_pct annualised via Walk_forward_runner.cagr_pct" → `test_per_start_extracts_metrics` (1y doubling → CAGR `is_between 99..101`); "max_underwater_vs_initial_pct from MaxUnderwaterVsInitialPct, NaN if absent" → extracts `-12.5` + NaN test; "max_drawdown_pct from MaxDrawdown, NaN if absent" → extracts `-42.0` + NaN test. The `run` orchestrator's claim is data-gated and not unit-pinned — disclosed honestly (see CP2 / harness_gap); every pure unit it composes IS pinned. |
| CP2 | Each PR-body "Test coverage" claim has a corresponding committed test | PASS | PR body claims: quarterly cadence (Jan/Apr/Jul/Oct) → `test_enumerate_quarterly`; first/last clipping → `test_enumerate_first_and_last`; empty cases (start==end, start>end) → two dedicated tests; non-positive-stride rejection → `test_enumerate_rejects_nonpositive_stride`; metric extraction (CAGR ~100%, MaxUnderwaterVsInitialPct, MaxDrawdown) → `test_per_start_extracts_metrics`; NaN surfacing → `test_per_start_missing_metrics_are_nan`. "34 tests (19+8+7), all pass" verified by re-running `dune runtest trading/backtest/rolling_start/test/` (EXIT 0; `test_rolling_start_runner.exe` Ran 7 OK). No advertised test is absent from the committed file. The "smoke-verified locally on smoke/bull-2019h2.sexp" claim is explicitly placed under "What is NOT covered" as a local-only check, not presented as a committed test — honest. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size_is | PASS | `test_enumerate_quarterly` pins each enumerated start by whole-value identity via `elements_are [equal_to <Date>; ...]` (not `size_is`). `size_is 0` is used only in the two empty-case tests, where emptiness IS the contract (correct usage). No output-equals-input pass-through semantics in this feature otherwise. |
| CP4 | Each explicitly-claimed guard has a test exercising the guarded-against scenario | PASS | Guard "stride_days<=0 → Invalid_argument" → `test_enumerate_rejects_nonpositive_stride` asserts the exact message string. Guard "start==end / start>end → empty (zero-length window)" → `test_enumerate_empty_when_start_eq_end` + `test_enumerate_empty_when_start_after_end`. Guard "missing metric → NaN, no crash" → `test_per_start_missing_metrics_are_nan` (asserts `Float.is_nan` on both DD fields and well-defined 0.0 CAGR on zero return). All three named guards exercised. |

### Behavioral Checklist (Weinstein domain)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1–T4 (all S*/L*/C*/T* rows) | Weinstein domain logic | NA | Pure analysis/tooling PR (start-date enumeration + metric projection + dispersion report). No stage classification, buy/sell criteria, stop machine, or screener cascade. Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely", the domain block is not applicable. qc-structural A1 was not flagged (no core-module change). |

### Honest harness_gap (not a FAIL)

The true multi-start **end-to-end** `run` path (real `Backtest.Runner.run_backtest`
over many starts) is data-gated — it requires deep PIT OHLCV / `EODHD_API_KEY`,
unavailable in GHA. The PR body discloses this clearly under "What is NOT covered
(harness_gap honesty)" and does not claim E2E coverage. What IS claimed to be
tested (the pure enumeration, the per-start metric projection, NaN surfacing,
report assembly via the PR-1 `Rolling_start_types`/`Dispersion_stats` units) is
actually pinned by the committed suite. Classification: **ONGOING_REVIEW** — the
`run` orchestration is genuinely data-gated; a golden-scenario E2E test would
require a deterministic PIT fixture this repo does not maintain in CI. The pure
slices are already deterministic and pinned, which is the right decomposition.

## Quality Score

4 — All Contract Pinning items pass; every .mli and PR-body claim is pinned by a
deterministic, data-free unit test, and the one genuinely data-gated path (`run`)
is disclosed honestly rather than papered over with a hollow "no error" test.
Clean separation of pure (testable) enumeration/projection from orchestration.

## Verdict

APPROVED
