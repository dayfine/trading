Reviewed SHA: 8760e9c9628a44dcaaec324039fcacd6ea798709

## Structural QC — tuning (M1 T1.5, PR #1328)

### Summary

PR adds `Tuner_bin.Bayesian_runner_rescore` library + `rescore_checkpoints.exe` CLI under `trading/backtest/tuner/bin/`. Pure-function re-scorer consuming synthetic `bo_rescore_input.sexp` fixtures (per-iteration candidate parameters + per-fold actuals) + baseline fold actuals, computing paired-Δ per candidate, and emitting markdown report with PASS/FAIL verdict against configurable acceptance gate (default 4.05 = 5× historical 0.81 spread). 17 new tests; all 238 tuner tests pass (9 grid_search_bin + 28 grid_search + 43 bayesian_opt + 33 bayesian_runner_scoring + 16 bayesian_runner_evaluator + 14 bayesian_runner_oos_validator + 21 bayesian_runner_successive_halving + 57 bayesian_runner_bin + 17 bayesian_runner_rescore).

### File Scope Verification

**Via `gh pr view 1328 --json files`:**
- dev/notes/t1-5-rescore-procedure-2026-05-26.md (new)
- dev/status/tuning.md (updated, status of T1.5 flipped from `[ ]` to `[~]`)
- trading/trading/backtest/tuner/bin/bayesian_runner_rescore.ml (new, 156 LOC)
- trading/trading/backtest/tuner/bin/bayesian_runner_rescore.mli (new, 193 LOC)
- trading/trading/backtest/tuner/bin/dune (updated)
- trading/trading/backtest/tuner/bin/rescore_checkpoints.ml (new, 147 LOC)
- trading/trading/backtest/tuner/bin/test/dune (updated)
- trading/trading/backtest/tuner/bin/test/test_bayesian_runner_rescore.ml (new, 503 LOC)

**Constraint check:** All files within `trading/trading/backtest/tuner/bin/`, docs, and status. No modifications to `dev/status/_index.md`. ✓

### Hard Deterministic Gates

| Gate | Result | Notes |
|------|--------|-------|
| `dune build @fmt` | PASS | Format check clean |
| `dune build` | PASS | Project builds successfully |
| `dune runtest trading/backtest/tuner/` | PASS | 238 tests pass (9 + 28 + 43 + 33 + 16 + 14 + 21 + 57 + 17) |

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest trading/backtest/tuner/ | PASS | 238 tests, 238 passed, 0 failed |
| P1 | Functions ≤ 50 lines (linter) | PASS | All functions well under 50 lines; linter passed as part of H3 |
| P2 | No magic numbers (linter) | PASS | Three named constants extracted: `historical_flat_surface = 0.81`, `flat_surface_multiplier = 5.0`, `default_min_spread = 4.05`; linter passed as part of H3 |
| P3 | Config completeness | PASS | All thresholds in named constants; CLI `--min-spread` flag allows override from default |
| P4 | Public-symbol export hygiene (linter) | PASS | .mli present and comprehensive; mli-coverage linter passed as part of H3 |
| P5 | Internal helpers prefixed per convention | PASS | Underscore-prefixed internal helpers: `_epsilon`, `_fold_actual`, `_baseline_sharpes`, `_baseline_actuals`, `_make_constant_offset_candidate`, `_make_synthetic_input`, `_usage_msg`, `_default_metric`, `_parse_metric`, `_parse_float`, `_parse_args`, `_emit_report`, `_verdict_label`, `_run`, and in tests: `_tmp_dir`, `_verdict_of_spread`, `_metric_label`, `_verdict_label`, `_parameters_to_string`, `_candidate_row` |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | PASS | 17 test cases in test_bayesian_runner_rescore.ml: all use `open Matchers` + `assert_that` with matcher composition (`all_of`, `field`, `float_equal`, `equal_to`, `is_some_and`); `assert_bool` used only for string-substring validation (markdown output), which is appropriate for free-form text; `assert_failure` used only in exception-handler paths (Failure message matching); no nested `assert_that` inside matcher callbacks; no anti-patterns detected |
| A1 | Core module modifications | NA | No modifications to Portfolio, Orders, Position, Strategy, or Engine; pure new module under tuner/bin |
| A2 | No new `analysis/` imports into `trading/trading/` | PASS | All imports are within `trading/trading/backtest/tuner/bin/`; no cross-boundary deps |
| A3 | No unnecessary modifications to non-feature modules | PASS | File list (per `gh pr view 1328 --json files`) contains only tuner/bin/ + new docs + status update; no drift to sibling modules |

## Verdict

**APPROVED**

All structural gates pass. Code builds and tests pass. File scope is bounded to the feature area (tuner/bin). Test patterns conform to project conventions. No core module modifications. Architecture constraints respected.

---

## Details

### Implementation Quality

**Library (`bayesian_runner_rescore.ml/.mli`):**
- Pure functions: `rescore_candidate`, `spread_of`, `build_report`, `report_to_markdown`
- Clear type definitions with sexp derivation for on-disk schema versioning
- Schema version guard prevents forward-compatibility drift
- Loaders validate input shape and fail loudly on mismatch
- File I/O segregated into loader functions; core logic is pure

**CLI (`rescore_checkpoints.ml`):**
- Well-structured argument parsing with validation
- Appropriate error messages on malformed input
- Supports metric dispatch (`Sharpe | TotalReturn | Calmar | CAGR`)
- Configurable acceptance threshold via `--min-spread`
- Output routing to stdout or file

**Tests (`test_bayesian_runner_rescore.ml`):**
- Comprehensive coverage: 17 cases covering spread computation, rescore_candidate identity/offset/partial-overlap/disjoint exception, build_report pass/fail/boundary, markdown rendering, sexp round-trip, schema validation
- Synthetic test data builders (`_fold_actual`, `_baseline_actuals`, `_make_constant_offset_candidate`)
- Exception paths tested explicitly (disjoint fold names, schema mismatch)
- Comments document coverage intent per plan §M1 T1.5

### Architecture Alignment

- New module sits under established `tuner/bin/` location (tuning research infra)
- Depends on `Bayesian_runner_scoring.paired_delta` (merged #1308) — appropriate downstream consumer
- Consumes `Walk_forward.Walk_forward_types.fold_actual` — reuses existing analytics types
- Does not modify existing modules (tuner, backtest, portfolio, orders, simulation)
- Pure function design aligns with project discipline

### Documentation

- Comprehensive `.mli` docstrings explain input shapes, loader contracts, type definitions
- Procedure note (`dev/notes/t1-5-rescore-procedure-2026-05-26.md`) documents local-run incantation and known gap (upstream adapter required for production `bo_checkpoint.sexp` enrichment)
- Status update in `dev/status/tuning.md` reflects completion of implementation (surface area, test count, verification command)

---

# Behavioral QC — tuning (M1 T1.5, PR #1328)
Date: 2026-05-26
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | (a) "spread > 5× the historical 0.81 flat surface = 4.05" → `test_default_min_spread_is_5x_historical` (lines 106-114); (b) "schema_version guard rejects future shape drift" → `test_load_input_rejects_schema_mismatch` (lines 404-428); (c) "matching by fold_name, order-independent" → `test_rescore_candidate_partial_overlap` (lines 164-197); (d) "disjoint pair raises Failure" → `test_rescore_candidate_disjoint_raises` (lines 202-239); (e) "spread_of empty = 0.0" → `test_spread_of_empty`; (f) "metric argument plumbed through" → `test_total_return_metric_dispatch` (lines 433-466); (g) "build_report does not apply a default — caller passes explicitly" → all `build_report` tests pass `min_spread` explicitly; (h) "Empty candidate list yields spread 0.0 → FAIL" → `test_build_report_empty_input_fails` (lines 307-324). Markdown renderer .mli says output can be pinned "byte-for-byte" but tests use substring matching only — acceptable as the behavioral claim ("contains PASS/FAIL/Sharpe/0.81") is what's tested, but the byte-for-byte language overstates. Minor doc nit, not a contract miss. |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | PASS | PR body lists 17 enumerated test categories: identity / constant-offset / partial-overlap / disjoint-raises / Total_return_pct dispatch / spread_of basic-empty-singleton / named-constants pin / Pass+Fail boundary cases / strict-greater contract / empty input / markdown verdict + 0.81 anchor / sexp round-trip / schema_version mismatch. All 17 are present in the `suite` list (lines 470-501). The `[ ] Local-only` operator-run item is explicitly out-of-scope (deferred to local operator run, plan §M1 T1.5 acceptance verified at that point) — acceptable per dispatch's option (a). |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size_is | PASS | The rescorer is the immediate consumer of `Bayesian_runner_scoring.paired_delta` from #1308 (M1 T1.3). `bayesian_runner_rescore.ml:75` calls `Scoring.paired_delta` directly — no re-implementation. `test_rescore_candidate_identity` (lines 121-138) asserts mean_delta=0.0, stdev_delta=0.0, n_matched=4 (full identity, not just size). `test_rescore_candidate_constant_offset` (lines 142-158) asserts mean_delta=0.25 (the actual paired-Δ output, not stubbed). Integration path is exercised — synthetic candidate Sharpe = baseline + 0.25 → paired_delta computes 0.25, verifies plumbing end-to-end. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | (a) `default_min_spread = 4.05 = 5.0 * 0.81`: `test_default_min_spread_is_5x_historical` asserts all three constants AND the product relation `default_min_spread == flat_surface_multiplier *. historical_flat_surface` (lines 111-114). (b) PASS strict `>` not `>=`: code is `Float.( > ) spread min_spread` (rescore.ml:97), pinned by `test_build_report_exactly_at_threshold_fails` (lines 289-303) which constructs spread = 2.0 with min_spread = 2.0 and asserts `Fail`. (c) Schema-version mismatch raises: `test_load_input_rejects_schema_mismatch` (lines 404-428) writes a file with `schema_version = 999`, expects Failure with substring "schema_version". (d) Disjoint pair raises (callsite-bug contract): `test_rescore_candidate_disjoint_raises` (lines 202-239) verifies the Failure bubbles up with substring "no fold names matched". All guard contracts pinned. |

## Behavioral Checklist (Weinstein-specific)

NA — this is a pure infrastructure / tuner methodology PR. No stage classifier, no buy/sell rules, no stops, no screener, no macro/sector logic. The S*/L*/C*/T* rows in `.claude/rules/qc-behavioral-authority.md` do not apply per the "When to skip this file entirely" guidance.

## Quality Score

5 — Exceptional contract pinning: every non-trivial .mli claim is paired with a named test, named constants extract every magic number and the product relation is tested (defends against accidental edits to either factor), strict-greater boundary is explicitly tested, schema-version guard has a dedicated test with a wrong-version sexp on disk, paired_delta reuse is direct (no re-implementation), metric-dispatch is exercised via Sharpe-noise-injection to prove the discriminator is honored. Honest about the adapter gap (procedure note + .mli explain why production `bo_checkpoint.sexp` lacks per-fold actuals and document the two options for the follow-up adapter). One minor nit: the .mli for `report_to_markdown` claims output can be pinned "byte-for-byte" but tests substring-match only — the behavioral claims are covered, but the language slightly overstates the test surface.

## Verdict

APPROVED

## Design call evaluation

The agent flagged that the existing `bo_checkpoint.sexp` doesn't carry per-fold actuals — running the rescorer against real v4/v6 production data requires an upstream adapter (out of scope for this PR). Evaluation:

- T1.5 is a calibration / methodology artefact, not a strategy primitive. The deliverable is the rescorer code path + the procedure for the local-only production run.
- The procedure note (`dev/notes/t1-5-rescore-procedure-2026-05-26.md`) IS the load-bearing artefact for the local run; it documents both adapter options (re-run path vs. inline path) and the suggested incantation.
- Synthetic-fixture validation in GHA exercises the full read → re-score → render → verdict pipeline.
- The adapter is a known follow-up, documented in the .mli ("Production runs after T1.5 lands will need a small adapter"), the CLI docstring ("Production-run procedure (local-only)"), the procedure note, and the PR body.

The synthetic-fixture coverage is sufficient to validate the code; the adapter gap is a data-access limitation, not a code-correctness gap. Acceptable for APPROVED without flagging in NEEDS_REWORK Items.
