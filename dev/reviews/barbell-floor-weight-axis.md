Reviewed SHA: 295eaba7bbb4609879ae91030f63f3735f9807bd

## Structural QC — barbell-floor-weight-axis (R2 completion)

### Summary
PR #1697 completes the barbell overlay's R2 gate by making `floor_weight` a searchable axis. Implements a self-contained barbell-local surface expander (`Barbell_floor_sweep`) + CLI runner, adheres to experiment-flag-discipline (default-off), and introduces zero core-module modifications. All hard gates pass; tests conform to project patterns.

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | 8 files changed, 708 insertions(+), 6 deletions(-). All linters pass: fn_length, nesting, file_length, mli_coverage, magic_numbers, fmt. Full test suite green. |
| P1 | Functions ≤ 50 lines (linter) | PASS | fn_length_linter passed as part of H3. Longest function in new code is `metrics_table` (9 lines in `.ml`). |
| P2 | No magic numbers (linter) | PASS | linter_magic_numbers.sh passed as part of H3. |
| P3 | Config completeness | PASS | No hardcoded thresholds; all tunable values (`floor_weights`, `rebalance_weeks`) are config parameters expressed in `Barbell_floor_sweep.axis` record. |
| P4 | Public-symbol export hygiene (linter) | PASS | mli_coverage linter passed as part of H3. New `.mli` file documents public interface fully. |
| P5 | Internal helpers prefixed per convention | PASS | All helpers prefixed with `_` (e.g., `_validate_axis`, `_cell_of_weight`, `_label_of_weight`, `_run_legs_once`, `_write_csv`, `_parse_weights`, `_parse_flags`). |
| P6 | Tests conform to test-patterns.md | PASS | `test_barbell_floor_sweep.ml`: (1) One `assert_that` per value, composed via `all_of`/`field`/`elements_are`. (2) No `List.exists ... equal_to true/false`. (3) No un-asserted `let _ = ...`; all test results asserted. (4) Stub blend metrics used for pure testing. 7 tests, all passing. |
| A1 | Core module modifications | PASS | No flags. Zero edits to `trading/trading/{portfolio,orders,position,strategy,engine}/`. Feature is confined to barbell subsystem. |
| A2 | No new analysis/ imports outside backtest exception | PASS | barbell dune files declare only barbell-local + pre-existing scenario_lib dependencies. No new `analysis/` imports outside `trading/trading/backtest/`. |
| A3 | No unnecessary existing module modifications | PASS | `git diff --name-only` shows only barbell-scoped files (lib, test, scenario/bin) + plan/status docs. No cross-feature drift. File list: `dev/plans/barbell-floor-weight-axis-2026-06-22.md`, `dev/status/barbell-overlay.md`, 4 barbell lib/test files, 2 dune + runner. No `_index.md` edit. |

## Experiment-Flag-Discipline Verification

- **R1 — default-off.** `Barbell_floor_sweep.axis` expands weights into cells; no default is flipped. `floor_weight = 0.0` (pure-engine no-op) is a valid cell. `0.0` appears in test `test_zero_weight_cell_is_valid` and passes validation. ✅
- **R2 — searchable / config-expressed.** Axis is a record field in `Barbell_floor_sweep.axis`, validated via `cells` expanding to `Barbell_config.t` cells per weight. Not hardcoded; only searchable when a session runs the sweep CLI. ✅
- **R3 — promotion requires ledger ACCEPT.** Status file explicitly notes "flipping any default on" is out-of-scope and requires `promotion-confirmation.md`'s confirmation grid. ✅

## Quality Score

5 — Clean, minimal, self-contained R2 completion. Pure module + thin CLI. No core edits. Tests are comprehensive, well-structured, and pin the two core invariants (ascending order + default-weight no-op). Docstrings are thorough and cite the design docs.

## Verdict

**APPROVED**

---

## Notes

- **Design compliance.** Feature implements exactly what `dev/plans/barbell-floor-weight-axis-2026-06-22.md` specifies: Option 1 (barbell-local axis, not Variant_matrix integration) to avoid entanglement with `Overlay_validator` scope.
- **Zero-drift PR.** All 8 file changes are barbell-scoped; no status-index edits, no core-module drift, no cross-feature creep.
- **Full surface coverage.** Tests verify axis expansion (sorting, one cell per weight), default-weight validity (0.0 no-op), malformed-axis rejection (empty, duplicates, out-of-range, zero cadence), and metrics-table per-cell blend threading.

---

## Behavioral QC — barbell-floor-weight-axis (R2 completion)

### Summary
PR #1697 makes `Barbell_config.floor_weight` a searchable surface via a pure,
self-contained `Barbell_floor_sweep` expander + a thin CLI runner. This is a
backtest-infra / experiment-platform PR — no Weinstein domain logic (no stage
classifier, stop, screener, or macro path) — so the S*/L*/C*/T* domain block is
NA per `.claude/rules/qc-behavioral-authority.md`. Every non-trivial contract
claimed in the `.mli` docstrings and the PR body is pinned by a test in
`test_barbell_floor_sweep.ml`. `dune runtest trading/backtest/barbell/` green in
container (EXIT=0).

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial `.mli` claim has an identified pinning test | PASS | `cells` ascending one-per-weight + per-cell enable/weight/cadence/label → `test_cells_one_per_weight_ascending`; `floor_weight=0.0` valid no-op cell → `test_zero_weight_cell_is_valid`; `@raise Invalid_argument` on empty/duplicate/out-of-range/cadence<1 → the four `*_rejected` tests; `metrics_table` one ordered row per cell threading config → `test_metrics_table_one_row_per_cell`. |
| CP2 | Each PR-body "Test plan" claim has a committed test | PASS | All 7 advertised tests exist; none advertised-but-missing. cell-count/ascending/per-cell-config → `test_cells_one_per_weight_ascending`; default-weight valid → `test_zero_weight_cell_is_valid`; malformed-axis (empty/dup/out-of-range/zero-cadence) → four `*_rejected` tests; metrics_table ordering via stub → `test_metrics_table_one_row_per_cell`. |
| CP3 | Identity/invariant tests pin identity, not just size | PASS | Ascending-order identity pinned via `elements_are` + per-element `field`/`float_equal`/`equal_to` (not `size_is`); `metrics_table` ordering pinned by encoding weight into the stub metric and asserting exact per-row value. |
| CP4 | Each explicitly-claimed guard exercised | PASS | `cells` docstring names four guarded inputs (empty, duplicate, out-of-range weight, `rebalance_weeks<1`); each has a dedicated raising test. `invalid_arg`=`Invalid_argument`; `Barbell_config.validate` enforces `[0,1]`/`>=1`. |

## Behavioral Checklist (Weinstein domain)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification strategy-agnostic | NA | qc-structural did not flag A1; zero core-module edits, diff confined to `backtest/barbell/` + plan + status row. |
| S1–S6, L1–L4, C1–C3, T1–T4 | Weinstein domain rows | NA | Pure backtest-infra / experiment-platform PR; domain checklist not applicable (`qc-behavioral-authority.md` §"When to skip this file entirely"). |

## Experiment-Flag-Discipline (behavioral)

- **R1 — default-off preserved.** Axis enumerates weights, flips no global default; `floor_weight=0.0` valid no-op cell (`test_zero_weight_cell_is_valid`).
- **R2 — searchable / config-expressed.** `floor_weight` is a real `Barbell_config.t` field expanded into a comparison surface from one invocation; barbell-local axis justified vs `Variant_matrix` (which validates against `Weinstein_strategy.config`).
- **R3 — no promotion.** No default flipped; promotion is ledger-gated per status + docstrings.

## Quality Score

5 — Every documented contract is pinned by a focused test; ascending-order and blend-threading identity claims pinned by exact-value `elements_are` (not size-only); default-off and all four malformed-axis guards exercised. Clean, in-scope R2 completion.

## Verdict

APPROVED
