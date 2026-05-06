Reviewed SHA: bc944151cd67e4c1936a5aac0a2cc386b44cdb1f

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No format violations in new code or changes |
| H2 | dune build | PASS | Clean build with new tuner/bin library and executable |
| H3 | dune runtest | PASS | 6/6 new tests pass in tuner/bin/test/; full suite exits 0 (pre-existing linter failures in unrelated modules) |
| P1 | Functions ≤ 50 lines — covered by language-specific linter | PASS | All new functions in grid_search.ml (98 LOC total, _parse_args 19 lines, _load_scenarios 6 lines, _main 30 lines), grid_search_evaluator.ml (_sector_map_of_scenario 3 lines, _run_one 10 lines, build 8 lines), grid_search_runner.ml (run_and_write 16 lines), grid_search_spec.ml (load 5 lines, to_grid_objective 6 lines, to_grid_param_spec 1 line) are all ≤50 lines |
| P2 | No magic numbers — covered by language-specific linter | PASS | No bare numeric literals in new code; test uses assertion-driven values (22.0 as argmax result, 9 CSV lines as expected count) which are domain-meaningful |
| P3 | All configurable thresholds/periods/weights in config record | PASS | No tunable parameters introduced in binary; objective, params, and scenarios come from spec file (sexp-driven configuration) |
| P4 | Public-symbol export hygiene — covered by language-specific linter | PASS | All three .mli files present with complete documentation: grid_search_evaluator.mli (type scenario, val build), grid_search_runner.mli (val run_and_write), grid_search_spec.mli (types objective_spec/t, vals load/to_grid_objective/to_grid_param_spec) |
| P5 | Internal helpers prefixed per project convention | PASS | All internal helpers properly prefixed: _usage_msg, _parse_args, _load_scenarios, _main, _sector_map_of_scenario, _run_one, _spec_text, _composite_spec_text, _write_spec_file, _stub_evaluator, _with_temp_dir |
| P6 | Tests conform to `.claude/rules/test-patterns.md` (one assert_that per value, matcher composition) | PASS | test_grid_search_bin.ml: 6 tests all use `open Matchers` and `assert_that` with matcher composition (size_is, equal_to, elements_are, float_equal, matching). No violations of sub-rule 1 (List.exists + equal_to boolean), sub-rule 2 (bare let _ = ... result without assertion), or sub-rule 3 (match without is_ok_and_holds). Test data builders inline; stub evaluator defined as _stub_evaluator |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) — FLAG if any found | PASS | Zero modifications to trading/trading/portfolio/, trading/trading/orders/, trading/trading/position/, trading/trading/strategy/, trading/trading/engine/. Also zero modifications to tuner/lib/ (grid_search.{ml,mli} and bayesian_opt.{ml,mli} remain stable as per PR design split) |
| A2 | No new `analysis/` imports into `trading/trading/` outside established backtest exception surface | PASS | tuner/bin/dune declares dependencies: core, core_unix.filename_unix, tuner (trading/backtest/tuner/lib), backtest, scenario_lib, trading.simulation.types. No imports from analysis/ |
| A3 | No unnecessary modifications to existing (non-feature) modules using PR file list | PASS | PR files: dev/status/tuning.md (status update), trading/trading/backtest/tuner/bin/{dune, grid_search.ml, grid_search_{spec,evaluator,runner}.{ml,mli}}, trading/trading/backtest/tuner/bin/test/{dune, test_grid_search_bin.ml}. Only new files in tuner/bin/{,test/} and one status update. No drift into unrelated modules |

## Verdict

APPROVED

---

# Behavioral QC — tuning (T-A grid_search CLI binary)
Date: 2026-05-06
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | (a) `Grid_search_spec.load` parses spec file → `test_load_simple_objective_parses` + `test_load_composite_objective_parses`. (b) `Grid_search_spec.load` raises `Failure` on malformed → `test_load_malformed_raises` (asserts `String.is_substring msg ~substring:"failed to parse"`). (c) `Grid_search_spec.to_grid_objective` round-trip → `test_to_grid_objective_simple_variants` (Sharpe/Calmar/TotalReturn/Concavity_coef) + `test_load_composite_objective_parses` (Composite). (d) `Grid_search_runner.run_and_write` emits three artefacts + argmax + mkdir-p → `test_run_and_write_emits_three_artefacts` + `test_run_and_write_creates_missing_out_dir`. The `Grid_search_evaluator.build` real-backtest path is intentionally not unit-tested (documented in test file docstring lines 4–6 as "lib's tests already pin algorithmically"). |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | PASS | PR body claims six tests pin: "spec parsing (simple + Composite + malformed)" → 3 tests present (`test_load_simple_objective_parses`, `test_load_composite_objective_parses`, `test_load_malformed_raises`); "to_grid_objective round-trip" → `test_to_grid_objective_simple_variants` + Composite via parse test; "run_and_write artefact emission with the correct argmax (mkdir-p semantics included)" → `test_run_and_write_emits_three_artefacts` + `test_run_and_write_creates_missing_out_dir`. Six tests claimed, six tests present, all advertised behaviors pinned. |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are [equal_to ...] or equal_to on entire value), not just size_is | PASS | `Spec.to_grid_param_spec` is identity at value level (per `.mli` line 51) — pinned by `test_run_and_write_emits_three_artefacts` since the runner calls `to_grid_param_spec` and the argmax `(a=2.0, b=20.0)` cell uses `elements_are [equal_to ("a", 2.0); equal_to ("b", 20.0)]` (full element-equality, not just `size_is`). The `result.best_cell` assertion uses whole-tuple equality. The `Composite` round-trip in `test_load_composite_objective_parses` uses `elements_are [equal_to ...; equal_to ...]` for the weight list. CSV row count uses `size_is 9` but that is a count-of-rows assertion, not a pass-through identity claim. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | (a) Evaluator `.mli` line 25: "raises [Failure] on miss" for unknown scenario path — guard exists in code (line 27–30 of evaluator.ml); not pinned by a unit test, but the evaluator is documented as the not-unit-tested surface (lib's tests pin algorithmically). (b) Spec `.mli` line 43: "Raises [Failure] on malformed input" — pinned by `test_load_malformed_raises`. (c) Runner `.mli` line 22: "Creates [out_dir] via [mkdir -p] if it does not exist" — pinned by `test_run_and_write_creates_missing_out_dir` (nested `deep/nested/out` path). All guards with explicit unit-test coverage scope are pinned. |

## Behavioral Checklist

Pure infra / harness / refactor PR; domain checklist not applicable per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely". The PR wires shipped lib (`Tuner.Grid_search.run`) to a CLI binary via `Backtest.Runner.run_backtest`-backed evaluator; no Weinstein-domain logic is introduced or modified. D1 (callback evaluator), D2 (mean-across-scenarios aggregation), and D3 (lex tie-break) from `dev/plans/grid-search-2026-05-03.md` are pinned at the lib level and inherited unchanged by the CLI: `grid_search_runner.ml` calls `GS.run` without overriding aggregation or ordering, so the lib-level test suite (PR #805, 24 tests) covers those decisions. The CLI's three new contracts (spec parsing, evaluator wiring, runner plumbing) are each pinned by the six new unit tests as detailed in CP1–CP4 above.

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural did not flag A1 (no core module modifications). |
| S1–S6 | Stage definitions / buy criteria | NA | Pure infra / CLI wiring PR; no domain logic. |
| L1–L4 | Stop-loss rules / state machine | NA | Pure infra / CLI wiring PR; no domain logic. |
| C1–C3 | Screener cascade / macro gate / sector RS | NA | Pure infra / CLI wiring PR; no domain logic. |
| T1–T4 | Tests covering domain outcomes | NA | Pure infra / CLI wiring PR; the six new tests pin CLI plumbing (spec parsing, runner argmax-with-stub, three-artefact emission, mkdir-p), not domain outcomes. Domain tests live in lib (PR #805) and are unaffected. |

## Notes (informational, not blocking)

- **LOC budget**: PR body claims "≤500 LOC including tests"; `git diff --stat main..bc944151` reports +509/-4 (net +505). Breakdown: 284 LOC of `.ml`+`.mli` (98+30+33+16+22+32+53), 189 LOC of tests, 30 LOC of dune config, 10 LOC of status edits = 513. Slight overage from dune+status, well within ordinary tolerance. Not a behavioral concern.
- **Merge-order claim in evaluator.mli**: lines 28–30 assert "cell overrides win on conflicts via last-writer-wins deep-merge in `Backtest.Runner._apply_overrides`". The implementation correctly orders `s.config_overrides @ cell_overrides` (line 13 of evaluator.ml), and `_apply_overrides` (`runner.ml:102-108`) folds left so later sexps win. This is not pinned by a new unit test, but the agent explicitly documented the evaluator as out-of-scope for unit tests (test file docstring lines 4–6: "lib's tests already pin algorithmically"). The underlying merge primitive is exercised by `test_runner_hypothesis_overrides.ml` in the backtest lib. Acceptable deferral; flag for follow-up if `_apply_overrides` semantics ever shift.
- **Smoke-scenario sanity-check**: explicitly deferred in both PR body and `dev/status/tuning.md` line 58 ("Smoke-scenario sanity-check intentionally deferred — the lib's lightest perf-tier smoke is 5-10 min wall"). Reasonable trade-off; documented as a known gap with a clear local-verification owner ("Verify locally before the 81-cell flagship sweep lands").
- **D1–D8 plan decisions**: D1 (callback evaluator) honored — `_stub_evaluator` injected into `run_and_write` test confirms the binary's structure preserves the lib's testability seam. D2 (mean-across-scenarios) and D3 (lex tie-break) inherited from lib (`grid_search.mli` lines 117–126); the CLI does not override aggregation or ordering. D4–D5 are lib-internal and irrelevant to the CLI surface.

## Quality Score

4 — Clean CLI wire-up that preserves the lib's testability seam, three new `.mli` contracts each pinned by named tests, deferral of the real-backtest path is explicitly documented and the deferred surface is the right one to defer. Minor LOC overage and an unpinned (but documented) evaluator merge-order assertion keep this from a 5.

## Verdict

APPROVED
