Reviewed SHA: 39e7a0beb838761d5d638430e9850c515a8b7077

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | All tests passed |
| P1 | Functions ≤ 50 lines — covered by language-specific linter | PASS | linter passed as part of H3 |
| P2 | No magic numbers — covered by language-specific linter | PASS | linter passed as part of H3 |
| P3 | All configurable thresholds/periods/weights in config record | PASS | No new magic numbers or tunable parameters introduced |
| P4 | Public-symbol export hygiene — covered by language-specific linter | PASS | mli-coverage linter passed as part of H3 |
| P5 | Internal helpers prefixed per project convention | PASS | All new internal helpers properly prefixed with underscore |
| P6 | Tests conform to test-patterns (one assert_that per value, proper matcher composition) | PASS | All test cases use single assert_that with field/all_of composition; no nested assert_that; Matchers library properly imported and used |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to core modules; changes only to backtest-specific code (all_eligible, release_report) |
| A2 | No new analysis→trading imports outside allow-listed exception surface | PASS | No new imports between analysis/ and trading/trading/ directories; all changes confined to trading/trading/backtest/ |
| A3 | No unnecessary modifications to existing modules (file list per gh pr view) | PASS | 7 files modified: release_report.ml/mli, all_eligible/lib/grade_sweep.ml, test files in all_eligible and release_report, status file — all cohesive to the release-report wiring feature |

## Verdict

APPROVED

No structural issues found. All hard gates (dune build @fmt, dune build, dune runtest) passed. Test patterns conform to project conventions. No core module modifications. Feature is ready for behavioral review.

---

# Behavioral QC — all-eligible-release-report-wiring
Date: 2026-05-11
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | New `.mli` contract claims and their pinning tests: (a) `all_eligible_summary` fields are exactly the ones surfaced from `All_eligible.aggregate` minus `return_buckets` → `test_load_scenario_run_loads_all_eligible_when_present` (asserts `trade_count`, `win_rate_pct`, `total_pnl_dollars`, `trades_csv_path` from on-disk fixture). (b) Decoded with `@@sexp.allow_extra_fields` to absorb `return_buckets` — same test stages a fixture containing `return_buckets` and confirms decode succeeds. (c) `all_eligible : all_eligible_summary option` field is `None` when artefact missing → `test_load_scenario_run_no_all_eligible_when_files_missing`. (d) `trades_csv_path` is always `<scenario_name>/all_eligible/grade-C/trades.csv` → asserted in presence test (`"with-alleli/all_eligible/grade-C/trades.csv"`). (e) Section "renders only when at least one paired side has Some _" → `test_render_omits_all_eligible_when_both_none` + `test_render_includes_all_eligible_when_present` + `test_render_all_eligible_handles_one_sided`. (f) One-sided pairs show "—" in missing cells → `test_render_all_eligible_handles_one_sided` asserts `| Trades \| 200 \| — \|` and `Prior: —`. |
| CP2 | Each claim in PR body "Test plan" / "What it does" sections has a corresponding test in the committed test file | PASS | PR body claims verified: (1) `summary.sexp round-trips` → `test_summary_sexp_round_trips` in `test_all_eligible_runner.ml` line 236. (2) "updated 2 file-count assertions" → `test_run_emits_four_artefacts` (renamed from three) line 164 + `test_grade_sweep_emits_per_grade_subdirs` line 503 (per-cell 4-file presence check including `summary.sexp`) + `test_emit_enabled_writes_four_artefacts` in `test_scenario_post_step.ml` line 128. (3) Test counts: `test_release_perf_report.ml` has 32 tests (matches "passes 32 tests"); `test_all_eligible_runner.ml` has 17 tests (matches "passes 17 tests"). (4) "loader presence/absence/malformed × 3" → `test_load_scenario_run_loads_all_eligible_when_present`, `test_load_scenario_run_no_all_eligible_when_files_missing`, `test_load_scenario_run_no_all_eligible_when_sexp_malformed`. (5) "renderer omission/presence/one-sided × 3" → `test_render_omits_all_eligible_when_both_none`, `test_render_includes_all_eligible_when_present`, `test_render_all_eligible_handles_one_sided`. (6) "fourth per-cell artefact summary.sexp containing the structured All_eligible.aggregate" → `test_summary_sexp_round_trips` decodes the on-disk file as `All_eligible.aggregate_of_sexp` and asserts field values. |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are [equal_to ...] or equal_to on entire value), not just size_is | PASS | The closest pass-through claim is "Schemas unchanged for trades.csv / summary.md / config.sexp." The summary.sexp round-trip test asserts specific aggregate field values (trade_count=0, winners=0, losers=0, total_pnl_dollars=0.0) — not just "round-trips without error". On-disk loader test asserts specific decoded values including `total_pnl_dollars=-50_000.0` and `trades_csv_path="with-alleli/all_eligible/grade-C/trades.csv"` (the latter pins identity of the computed path, not just non-empty). The renderer presence test pins exact markdown strings including `\| Trades \| 200 \| 180 \|`, `\| Win rate \| +30.00% \| +31.00% \|`, `\| Total P&L ($) \| -80000 \| -60000 \|` — full row identity, not just substring presence. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | Three explicit guards in `release_report.ml`: (1) "Any read / parse failure swallows silently — auxiliary, never a hard requirement" → `test_load_scenario_run_no_all_eligible_when_sexp_malformed` writes "this is not valid sexp\n" to `summary.sexp` and asserts `run.all_eligible is_none` (proves the try/with swallow, not a raise). (2) "the section still renders if the CSV is absent (the link will 404 but the metrics are intact)" → not directly tested, but the loader path doesn't check for `trades.csv` existence (only `summary.sexp`), so the implementation matches the docstring — the rendered presence test only asserts on `summary.sexp` being decoded. (3) `@@sexp.allow_extra_fields` absorbs `return_buckets` → exercised in `test_load_scenario_run_loads_all_eligible_when_present` where the on-disk fixture includes `return_buckets` field. (4) "`[None]` for scenarios that did not run the all-eligible diagnostic" → `test_load_scenario_run_no_all_eligible_when_files_missing` covers absence. Note: CSV-absent renders is asserted only indirectly — see Quality Score below. |

## Behavioral Checklist (Weinstein domain)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| Domain | All S*/L*/C*/T* rows | NA | Pure infra / refactor / harness PR (release-report wiring + additive `summary.sexp` emission); no Weinstein domain logic (stages, stops, screener, macro) touched. Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely": "For pure infrastructure / library / refactor / harness PRs that touch no domain logic — the generic CP1–CP4 in the qc-behavioral agent file alone constitute the full review." |

## Quality Score

5 — Contract docstrings on the `.mli` are precise (mirror contract, allow_extra_fields rationale, em-dash fallback, drill-down link semantics); tests pin both happy-path values, the malformed-sexp swallow, the absence branch, and the one-sided rendering with full markdown identity assertions; the `summary.sexp` round-trip on the producer side closes the loop with `release_report`'s decoder. PR-body claims (test counts, updated file-count assertions, new test list) are factually correct against the code. Strictly additive change with no domain risk.

## Verdict

APPROVED

