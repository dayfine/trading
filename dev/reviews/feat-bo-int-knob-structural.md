Reviewed SHA: 705bd0de6421d0c849f66b520b540c589394ffad

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No violations |
| H2 | dune build | PASS | Full build succeeds |
| H3 | dune runtest | PASS | 28 tests, 28 passed, 0 failed |
| P1 | Functions ≤ 50 lines (linter) | PASS | No functions exceed 50-line hard limit; linter passed via H3 |
| P2 | No magic numbers (linter) | PASS | Linter passed via H3 |
| P3 | Config completeness | PASS | All new parameters (`int_keys`) route through function arguments, no hardcoded tunable values introduced |
| P4 | Public-symbol export hygiene (mli-coverage) | PASS | 12 public exports documented in .mli; 13 internal helpers prefixed with `_`; linter passed via H3 |
| P5 | Internal helpers prefixed per convention | PASS | All internal helpers in grid_search.ml use `_` prefix convention: `_format_binding_value`, `_binding_to_sexp`, etc. |
| P6 | Tests conform to test-patterns.md | PASS | All 5 new test functions use single `assert_that` with `all_of`/`field` composition; no nested assertions; no `List.exists equal_to true`; no bare match/Error patterns. Test helpers `_contains` and `_excludes` properly wrapped in `field`. |
| A1 | Core module modifications | PASS | No modifications to Portfolio/Orders/Position/Strategy/Engine; changes confined to trading/backtest/tuner/ subsystem |
| A2 | No new analysis/ imports into trading/trading/ outside backtest exception | PASS | No analysis/ dependencies added; tuner lib uses only core + backtest + simulation.types |
| A3 | No unnecessary cross-feature drift | PASS | Exactly 3 files touched (grid_search.ml/.mli + test), all within tuner subsystem; no stray modifications |

## Verdict

APPROVED

The change adds integer-key rounding support to the grid-search tuner to fix the BO int-knob crash (issue #1249). Implementation is clean: new optional `int_keys` parameter threads through the call chain, comprehensive test coverage with 4 new tests pinning rounding semantics and backward-compatibility, and structural gates all pass.
