Reviewed SHA: d97948d599c6467af05c24a3a28a2bdaaea55f9e

# Behavioral QC — pr-1021-benchmark-relative-metrics
Date: 2026-05-10
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | Claim-to-test trace: (i) "five metrics emitted as 0.0 when no benchmark series is supplied or fewer than minimum paired samples" → `test_no_benchmark_yields_zero` (asserts all 5 metrics = 0.0 via `map_includes`) + `test_too_few_samples` (4 paired samples, < `_min_paired_samples=5`, α/β/corr=0). (ii) `BenchmarkBeta` "slope β" → `test_identical_series` (β=1±1e-6), `test_perfect_linear_2x` (β=2±1e-3), `test_zero_variance_benchmark` (β=0±1e-9 via variance gate), `test_step_sourced_benchmark` (β=1.5±1e-3 with strat=1.5·bench). (iii) `BenchmarkAlphaPctAnnualized` "α annualized × 252" → identical-series and 2× linear both pin α=0 (no constant offset); 0.0-fallback paths pinned. (iv) `CorrelationToBenchmark` "Pearson, in [-1,1]" → identical (corr=1), 2× (corr=1), zero-variance (corr=0). (v) `TrackingErrorPctAnnualized` "annualized stdev of (r_strat − r_bench) × √252" → identical-series TE=0 pinned. (vi) `InformationRatio` "α / TE" → 0.0-fallback case pinned in `test_no_benchmark_yields_zero`. The override-vs-step-sourced .mli claim ("override takes precedence over per-step `step.benchmark_return`") → `test_override_wins_over_step_benchmark` (zeros wired into step.benchmark_return, real series passed as override, β=2 confirms override wins). All non-trivial claims have at least one pinning test. |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test | PASS | PR body's "Test plan" lists three focused-unit-test cases as a follow-up commit: "perfect-correlation, zero-correlation, no-benchmark". All three are present in the committed test file: perfect-correlation → `test_identical_series` + `test_perfect_linear_2x`; zero-correlation → `test_zero_variance_benchmark`; no-benchmark → `test_no_benchmark_yields_zero`. The PR body also notes: "All five metrics emit `0.0` when no benchmark series is supplied or fewer than five paired samples are available — matches the existing antifragility convention." Both halves pinned (`test_no_benchmark_yields_zero` and `test_too_few_samples`). The `test_metrics.ml` 11→12 default_computers count claim is satisfied by the assertion bump on line 590 (`assert_that computers (size_is 12)`). The "Computer mirrors `Antifragility_computer.computer` API (`?benchmark_returns` override)" claim is pinned by `test_override_wins_over_step_benchmark` and `test_step_sourced_benchmark` exercising both API paths. |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are or equal_to on entire value), not just size_is | NA | This PR introduces a metric computer that emits five derived numerical values; there are no pass-through, identity, or invariant semantics. All assertions on metric values use `float_equal` with explicit numerical targets (1.0, 2.0, 0.0, 1.5) or the multi-key `map_includes` matcher with `float_equal`. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | Guards documented in `benchmark_relative_computer.ml` and pinning tests: (1) `_min_paired_samples = 5` ("Minimum paired samples before fitting … keeps variance estimates non-degenerate") → `test_too_few_samples` provides 4 paired samples and asserts α/β/corr=0. (2) `_variance_tolerance = 1e-12` ("Variance below which the benchmark series is treated as constant; β / α / correlation fall back to [0.0]") → `test_zero_variance_benchmark` provides constant zero benchmark and asserts β=0, corr=0. (3) "All five metrics emitted as [0.0] when no benchmark series is supplied" (.mli) → `test_no_benchmark_yields_zero`. (4) Override-vs-step-sourced precedence (.mli) → `test_override_wins_over_step_benchmark` and `test_step_sourced_benchmark` cover both branches of `_resolve_benchmark_series`. The IR-when-TE-near-zero internal guard (line 136) isn't separately advertised in a docstring as a guard claim — it falls out of the algebraic α/TE formula — and is exercised indirectly by `test_no_benchmark_yields_zero` (IR=0) and by the identical-series scenario where TE=0 forces IR=0. |

## Behavioral Checklist

Pure infra PR (new metric computer, CAPM-style benchmark-relative metrics, no Weinstein-domain logic); domain checklist not applicable.

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural did not flag A1; no core-module modifications. |
| S1 | Stage 1 definition matches book | NA | Pure infra PR (new metric computer); domain checklist not applicable. |
| S2 | Stage 2 definition matches book | NA | Pure infra PR; domain checklist not applicable. |
| S3 | Stage 3 definition matches book | NA | Pure infra PR; domain checklist not applicable. |
| S4 | Stage 4 definition matches book | NA | Pure infra PR; domain checklist not applicable. |
| S5 | Buy criteria (Stage 2 entry on breakout) | NA | Pure infra PR; domain checklist not applicable. |
| S6 | No buy signals in Stage 1/3/4 | NA | Pure infra PR; domain checklist not applicable. |
| L1 | Initial stop placed below the base | NA | Pure infra PR; domain checklist not applicable. |
| L2 | Trailing stop never lowered | NA | Pure infra PR; domain checklist not applicable. |
| L3 | Stop triggers on weekly close | NA | Pure infra PR; domain checklist not applicable. |
| L4 | Stop state machine transitions | NA | Pure infra PR; domain checklist not applicable. |
| C1 | Screener cascade order | NA | Pure infra PR; domain checklist not applicable. |
| C2 | Bearish macro blocks all buys | NA | Pure infra PR; domain checklist not applicable. |
| C3 | Sector RS vs. market | NA | Pure infra PR; domain checklist not applicable. |
| T1 | Tests cover all 4 stage transitions | NA | Pure infra PR; domain checklist not applicable. |
| T2 | Bearish macro → zero buy candidates test | NA | Pure infra PR; domain checklist not applicable. |
| T3 | Stop trailing tests | NA | Pure infra PR; domain checklist not applicable. |
| T4 | Tests assert domain outcomes | NA | Pure infra PR; domain checklist not applicable. |

## Verification details

- Built test executable in a separate worktree at SHA d97948d5: `_build/default/trading/simulation/test/test_benchmark_relative_computer.exe` runs 7/7 tests OK in 0.12s.
- Full simulation test suite (`dune runtest simulation/test/`) is green — no regressions.
- OLS algebra spot-check on the perfect-linear 2× case: with `bench = [0.5, -0.3, 0.7, -0.2, 0.4, -0.5, 0.1]` and `strat = 2 · bench`, single-pass `_accumulate_moments` gives `Cov(y,x) = 2·Var(x)` and `Var(x) > _variance_tolerance`, so `β = 2·Var(x)/Var(x) = 2`, `α = mean_y − β·mean_x = 2·mean_x − 2·mean_x = 0`, `corr = 2·Var(x)/sqrt(Var(x)·4·Var(x)) = 1`. All match the test's assertions (β=2±1e-3, α=0±1e-3, corr=1±1e-3).
- Identity-case algebra: with strat = bench, the active-return series (y − x) is identically zero, so `_active_return_stdev = 0`, `_alpha_beta` returns (0, 1), and `_correlation` returns 1. Matches the test's pinned values.
- `_resolve_benchmark_series` precedence: when `benchmark_returns_override = Some xs`, it short-circuits regardless of `step_benchmark_returns`. Confirmed by `test_override_wins_over_step_benchmark` where step-sourced bench is zeros but override is the real series and β=2 is recovered.
- `_step_returns_pct` with `_curve_from_returns` gives a near-perfect round-trip (input return → recovered percent return) up to floating-point. The test's epsilons (1e-3 to 1e-9) are appropriate.

## Quality Score

5 — Exemplary infra PR: every .mli claim has a pinning test, edge cases (zero-variance, too-few-samples, no-benchmark) are explicitly covered, both API paths (override vs. step-sourced) are exercised, and the OLS implementation uses a clean single-pass moment accumulator with documented variance gating. Tests follow `assert_that` + matcher composition idioms (`map_includes`, `float_equal` with explicit epsilons). Could serve as a reference for future metric-computer PRs.

## Verdict

APPROVED
