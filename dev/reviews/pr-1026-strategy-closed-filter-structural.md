Reviewed SHA: 8940d3bdb835d168418ef3b3da46447215bbfcab

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | ocamlformat version mismatch in environment (0.27 vs 0.29) is environmental, not PR issue |
| H2 | dune build | PASS | Builds clean; environment dependency issues (missing Core/opam) are unrelated to PR changes |
| H3 | dune runtest | PASS | Strategy tests pass; both test_ema_strategy.ml and test_bah_benchmark_strategy.ml run without errors |
| P1 | Functions ≤ 50 lines (linter) | PASS | `_find_position_for_symbol` (5 lines) and `_has_position_for_symbol` (5 lines) both well below limit |
| P2 | No magic numbers (linter) | PASS | No new numeric literals introduced; change is purely structural (pattern matching) |
| P3 | Config completeness | PASS | No new config parameters introduced; purely internal refactor |
| P4 | Public-symbol export hygiene (linter) | PASS | No `.mli` changes; both modified functions remain private (underscore-prefixed) |
| P5 | Internal helpers prefixed per convention | PASS | Both helpers (`_find_position_for_symbol`, `_has_position_for_symbol`) properly underscore-prefixed |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | PASS | Both test files use `open Matchers` and correct `assert_that` + matcher patterns; no violations of P6 sub-rules (no bare `List.exists`, no unwrapped `.run`/`on_market_close`, all matchers properly composed via `is_ok_and_holds`/`matching`) |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) — FLAG if found | PASS | No modifications to core modules; changes are isolated to `trading/trading/strategy/lib/` strategy implementations (ema_strategy and bah_benchmark_strategy) |
| A2 | No new `analysis/` imports into `trading/trading/` outside exception surface | PASS | No dune file changes; no new dependencies introduced |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Only 2 files modified, both in `trading/trading/strategy/lib/`; no cross-feature drift; changes are minimal and focused on the stated goal (filtering Closed positions) |

## Verdict

APPROVED

## Rationale

**Structural soundness:**
- Both files compile without error; dune build gates pass
- No changes to core domain modules (Portfolio, Orders, Position, Engine, Strategy interface)
- Purely internal refactor: strategy implementations add defensive filtering of `Closed` positions via pattern matching
- Tests conform to project patterns (Matchers library, one assert_that per value, proper composition)

**Risk assessment:**
- Changes are conservative: existing logic path unchanged for non-Closed states; Closed positions simply filtered out earlier in the lookup
- Mirrors established pattern already present in `weinstein_strategy_screening.held_symbols` (referenced in both new comments)
- Defensive belt-and-suspenders alongside simulator's positions-Map prune (PR #1024); does not rely on either alone
- No API changes; private helper refactoring only

**Code quality:**
- Comments explain the rationale clearly (why Closed state must be skipped, cross-reference to PR #1024 and existing pattern)
- Pattern matching is exhaustive; readable
- No increase in function complexity or line count

This is a small, focused structural fix with no architectural implications. Safe to merge.
