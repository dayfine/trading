Reviewed SHA: 5d316b567ceec1359e96c2a801c81e0610a8a212

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No format issues in metric-related files |
| H2 | dune build | PASS | Build succeeded without errors |
| H3 | dune runtest | PASS | All tests passed; simulation/test/ suite green |
| P1 | Functions ≤ 50 lines — covered by language-specific linter | PASS | fn_length_linter passed as part of H3; no violations in refactored code |
| P2 | No magic numbers — covered by language-specific linter | PASS | magic_numbers linter passed as part of H3; no new hardcoded literals |
| P3 | All configurable thresholds/periods/weights in config record | PASS | Refactored code does not introduce new tunable parameters |
| P4 | Public-symbol export hygiene — covered by language-specific linter | PASS | mli_coverage linter passed as part of H3; all public types properly declared |
| P5 | Internal helpers prefixed per project convention | PASS | All new helpers prefixed with underscore (_metrics_from_moments, _add_pair, etc.) |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | PASS | test_benchmark_relative_computer.ml uses `open Matchers` + `assert_that` with proper matcher composition; no `List.exists`, no bare `let _ =`, no unadjusted match blocks |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to core modules; only simulation/lib changes |
| A2 | No new `analysis/` imports into `trading/trading/` | PASS | No analysis imports found in any modified dune files |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | File list from `gh pr view 1021 --json files` confirms 15 files, all within feature scope (simulation/* + benchmark_relative_computer) |

## Structural Findings

### H2 Build Success

File length verification:
- `metric_info_registry.ml`: 494 lines ✓ (under 500-line limit; previously 537)
- `metric_info_types.ml`: 13 lines ✓ (new, lightweight type extraction)
- `metric_info_registry_extras.ml`: 35 lines ✓ (new, dispatch for 5 benchmark-relative variants)

### Nesting Refactoring in `_build_metrics`

Function `_build_metrics` (~lines 144–154 in benchmark_relative_computer.ml):
- Structure: `let bench_opt = match ... in; match bench_opt with ...`
- Max nesting depth: 3 (function → let binding → match)
- Average nesting: ~2.5 (well-flattened after helper extraction)
- Pattern: Two sequential match expressions (not nested), extraction of computation into `_metrics_from_moments` helper
- **Result: nesting avg ≤ 3.0, max ≤ 5** ✓

Supporting helper `_metrics_from_moments` (lines 125–142): extracted to flatten the main function, clear single purpose, ≤ 25 lines.

### Module Splitting Architecture

- **metric_info_types.ml/.mli**: New sibling module exporting `metric_unit` + `metric_info` types
  - Rationale: Break circular dependency; allows `metric_info_registry_extras` to construct records without importing the registry
  - Re-exports in `metric_info_registry.ml` (lines 18–29): public API preserved
  
- **metric_info_registry_extras.ml/.mli**: New module for 5 benchmark-relative variants
  - Function: `info_for_benchmark_relative : metric_type → metric_info option`
  - Handles: BenchmarkAlphaPctAnnualized, BenchmarkBeta, TrackingErrorPctAnnualized, InformationRatio, CorrelationToBenchmark
  - Delegation point in registry (lines 474–480): match on benchmark-relative cases, delegate to extras, fallwith if None

- **metric_info_registry.ml**: Reduced from 537 to 494 lines; delegates 5 cases to extras

### Test Coverage

- **test_benchmark_relative_computer.ml**: 176 lines, 15 test functions
- Scenarios: no benchmark, <5 samples, perfect linear, identical series, zero-variance benchmark, step-sourced benchmark, override paths
- Assertions: `assert_that metrics (map_includes [...])` using Matchers library
- **Conformance**: All test patterns follow `.claude/rules/test-patterns.md` rules; no P6 violations detected

### CI Green

- GitHub Actions: `build-and-test` PASSED (SUCCESS) as of 2026-05-10T13:32:33Z
- Perf tier-1 smoke: PASSED (SUCCESS)

## Verdict

**APPROVED**

The follow-up commit successfully addresses both linter regressions:
1. **File length**: `metric_info_registry.ml` reduced to 494 lines (target: ≤ 500) ✓
2. **Nesting**: `_build_metrics` flattened via helper extraction; avg ~2.5, max 3 (target: avg ≤ 3.0, max ≤ 5) ✓

Structural refactoring is sound: new modules have clear responsibilities, public API preserved, no unwanted dependencies introduced, tests pass, CI green. Behavioral review (qc-behavioral) already approved earlier; this commit is pure structure, no domain logic changes.

---

## Notes for Lead Orchestrator

No harness_gap items. All checks are deterministic and covered by existing dune-wired linters (fn_length_linter, nesting_linter). No QC escalation needed beyond this re-review.
