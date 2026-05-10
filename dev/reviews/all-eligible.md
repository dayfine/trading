Reviewed SHA: f56d1c1c18356681b0fe51fd27e8c5df8c759b1b

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | All tests pass (42 tests in all_eligible module + full suite) |
| P1 | Functions ≤ 50 lines — covered by language-specific linter | PASS | All functions are short (emit: 9 lines, _make_runner_args: 8 lines, helpers: ≤ 10 lines); fn_length_linter passed as part of H3 |
| P2 | No magic numbers — covered by language-specific linter | PASS | Only semantic string "all_eligible" constant; no numeric literals; magic_numbers linter passed as part of H3 |
| P3 | All configurable thresholds/periods/weights in config record | PASS | No new tunable parameters introduced; all-eligible config is pinned via library defaults in scenario_post_step.ml:_make_runner_args |
| P4 | Public-symbol export hygiene — covered by language-specific linter | PASS | Proper .mli files with documented API; internal helpers prefixed with _ (all_eligible_subdir, _make_runner_args); mli_coverage linter passed as part of H3 |
| P5 | Internal helpers prefixed per project convention | PASS | _all_eligible_subdir, _make_runner_args both follow underscore convention; no violations |
| P6 | Tests conform to `.claude/rules/test-patterns.md` (presence + conformance) | PASS | test_scenario_post_step.ml uses Matchers library correctly: three assert_that calls, each single assertion with proper field/all_of composition; no nested assert_that inside callbacks; no List.exists with equal_to boolean; no unasserted .run/.on_market_close Results; test helpers use match/assert_failure only in setup helpers (_write_symbol_csv), not in assertions |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) — FLAG if any found | PASS | No modifications to core modules; only new Scenario_post_step facade under backtest_all_eligible/lib/ and scenario_runner.ml threading in the post-step hook |
| A2 | No new `analysis/` imports into `trading/trading/` outside the established backtest exception surface | PASS | Only new dependency is backtest_all_eligible (under trading/trading/backtest/all_eligible/); existing weinstein.* (analysis/weinstein/) deps in backtest_all_eligible/lib/dune are within allow-listed exception (backtest modules); scenario_runner.ml adds only backtest_all_eligible import |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | PR file list via git-diff: dev/status/all-eligible.md, all_eligible/bin/test/dune, test_scenario_post_step.ml (new), scenario_post_step.{ml,mli} (new), scenarios/dune (+backtest_all_eligible), scenario_runner.ml (+post-step hook); all 7 files are in scope for PR-3 wiring; no cross-feature drift |

## Verdict

APPROVED

## Notes

- **Staleness check**: Feature branch is 3 commits ahead of main@origin (current, no rebase needed).
- **Branch structure**: Three commits with clean, focused changes; no ancestry contamination.
- **Test coverage**: Three integration tests pin the wiring contract (enabled mode writes artefacts, disabled mode creates no subdir, failure isolation swallows errors).
- **Failure handling**: Post-step wraps runner in try/with; exceptions logged to stderr and swallowed so parent scenario backtest is never aborted.
- **Artefact location**: Correctly placed under `<scenario_dir>/all_eligible/grade-C/{trades.csv,summary.md,config.sexp}` as documented in status file.
- **Linter compliance**: All dune-wired linters (fn_length, magic_numbers, mli_coverage, nesting) passed as part of dune build + dune runtest.

---

# Behavioral QC — all-eligible (PR-3 release-report wiring)
Date: 2026-05-10
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | `scenario_post_step.mli` claims (claim → test): (a) "[enabled = false] is a no-op: no directory is created, no runner invoked" → `test_emit_disabled_creates_no_subdir` (asserts `Sys_unix.file_exists_exn all_eligible_dir = false`); (b) "writes [<scenario_dir>/all_eligible/grade-C/{trades.csv,summary.md,config.sexp}]" → `test_emit_enabled_writes_three_artefacts` (asserts all three artefacts exist on disk under the documented layout); (c) "On any [Failure] / exception from the runner, logs the message to [stderr]…and returns normally (does not raise)" → `test_emit_swallows_runner_failure` (forces `Scenario.load` to raise via bogus path; asserts `raised = false`). Side-effect "Creates [scenario_dir/all_eligible/]" is implicitly pinned by the artefact-existence assertions in test (a). |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | PASS | PR body / commit message lists three pinning tests: (1) "enabled=true emits three artefacts under <scenario_dir>/all_eligible/grade-C/" → `test_emit_enabled_writes_three_artefacts`; (2) "enabled=false creates no all_eligible subdir at all" → `test_emit_disabled_creates_no_subdir`; (3) "runner failure is swallowed, never raised" → `test_emit_swallows_runner_failure`. All three live in `test_scenario_post_step.ml` and are wired into the `suite` (lines 179–188). The `--no-emit-all-eligible` flag's gate behavior is pinned via the `enabled = false` test (the flag flips this same boolean — confirmed in `scenario_runner.ml` parser branch `\| "--no-emit-all-eligible" :: rest -> loop rest dir parallel fixtures_root progress_every false`). |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are [equal_to ...] or equal_to on entire value), not just size_is | NA | No pass-through / identity semantics in this PR. The post-step is a side-effecting hook, not a transformer that returns its input. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | The `.mli` "Failure isolation" section explicitly enumerates guard scenarios: "missing CSV bars, snapshot construction error, scanner crash". `test_emit_swallows_runner_failure` exercises one realistic failure mode (bogus scenario path → `Scenario.load` raises inside the runner) and verifies the guard contract (no exception propagates). Note (FLAG only): the test could be strengthened by also asserting the upstream `actual.sexp` / `summary.sexp` invariant ("upstream artefacts intact") that the docstring mentions, but this is only true if the host `scenario_runner` has already written them — the docstring is correct that `Scenario_post_step.emit` itself doesn't touch them, and the test confirms `emit` does not raise. The narrower guard (no-raise) is what `emit` actually owns, so coverage is faithful to the contract scope. |

## Behavioral Checklist

Pure infra / wiring PR; domain checklist not applicable. Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely", all S*/L*/C*/T* rows are NA: this PR adds a thin facade module + threads a CLI flag through `scenario_runner`; no Weinstein-domain logic (stage classification, stops, screener cascade, sector RS) is touched. The post-step delegates to `All_eligible_runner.run_with_args`, which is itself already covered by domain tests in PR-1 / PR-2.

## Quality Score

4 — Clean wiring with comprehensive contract pinning: every documented claim in the `.mli` (gate-off no-op, artefact layout, failure isolation) and every test claim in the PR body maps cleanly to a committed test. Minor nit: `test_emit_swallows_runner_failure` could additionally assert the stderr log line was emitted (currently only the no-raise half of the swallow contract is checked), but this is a nice-to-have, not a gap.

## Verdict

APPROVED
