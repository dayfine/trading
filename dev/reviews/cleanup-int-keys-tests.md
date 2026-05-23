Reviewed SHA: 2db7fcade3145cd84bf6351e4761138f60933e3f

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | 50 tests total (5 new), all passed |
| P1 | Functions ≤ 50 lines (linter) | PASS | fn_length linter passed as part of H3 |
| P2 | No magic numbers (linter) | PASS | magic_numbers linter passed as part of H3 |
| P3 | Config completeness | NA | Test file only; no config records introduced |
| P4 | Public-symbol export hygiene (linter) | PASS | mli_coverage linter passed as part of H3 |
| P5 | Internal helpers prefixed per convention | PASS | Helpers `_with_temp_dir`, `_spec_text`, `_write_spec_file`, etc. all properly prefixed |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | PASS | All 5 new tests use proper `assert_that` + matchers (`is_ok_and_holds`, `is_some_and`, `matching`, `elements_are`, `equal_to`, `float_equal`). No bare match with `assert_failure`; no `let _ = ...run` patterns; no `List.exists ... equal_to bool` |
| A1 | Core module modifications | NA | No modifications to Portfolio/Orders/Position/Strategy/Engine |
| A2 | Dependency-direction rules respected | NA | Test file only; no cross-boundary imports added |
| A3 | No unnecessary existing module modifications | PASS | PR touches exactly 2 files per `gh pr view 1268 --json files` |

## Verdict

APPROVED

## Notes

The docstring fix at bayesian_runner_spec.mli clarifies the merge semantics: explicit `int_keys` field entries come first, then per-binding `(int)` markers in bounds order. The `.mli` example (lines 190–201) correctly uses verbatim block `{v...v}` instead of code block `{[...]}` to prevent ocamlformat from normalizing the `(int)` marker back to bare `int`. The 5 new tests pin the observed parse behavior (concat not dedup), three error cases, and round-trip invariants. No structural violations found.
