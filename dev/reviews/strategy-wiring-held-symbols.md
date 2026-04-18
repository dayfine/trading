Reviewed SHA: f67565b5870b50beabcda9846c1a656e6c6c149c

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | fmt_check.sh: OK — all .ml/.mli files correctly formatted |
| H2 | dune build | PASS | Clean build, no errors |
| H3 | dune runtest | FAIL | Nesting linter (49 functions, 6 files) and magic-number linter both FAIL. However: nesting failures are entirely pre-existing on main (all in analysis/scripts/universe_filter/ and analysis/scripts/fetch_finviz_sectors/). The magic-number failure IS introduced by this PR — see P2. Strategy tests (test_weinstein_strategy.exe): 13 tests, 13 passed, 0 failed (includes both new tests). |
| P1 | Functions ≤ 50 lines (fn_length_linter) | PASS | fn_length_linter passed: OK — no functions exceed 50 lines |
| P2 | No magic numbers (linter_magic_numbers.sh) | FAIL | Magic-number linter FAILS on this PR. The comment block added to _held_symbols contains the date string "2026-04-17" on a continuation line that does not contain `(*` or `*)`. The linter's comment-skip heuristic (line 65 of linter_magic_numbers.sh) only skips lines containing `(*`, `*)`, or `e.g.` — interior lines of multi-line OCaml comments that are bare text fall through. The regex `[0-9]{2,}` matches `2026`, `04`, and `17` from the date. Fix: remove the "Bug fix (2026-04-17):" inline date from the comment body, or rewrite the sentence to not embed the bare date, or escape via `linter_exceptions.conf`. |
| P3 | All configurable thresholds/periods/weights in config record | NA | No new numeric thresholds introduced. This is a pure logic fix (filter by position state). |
| P4 | .mli files cover all public symbols (linter_mli_coverage.sh) | PASS | linter_mli_coverage.sh: OK — all lib/*.ml files have a corresponding .mli |
| P5 | Internal helpers prefixed with _ | PASS | `_held_symbols` retains its underscore prefix; the new `make_pos_at_state` and `_portfolio_of_positions` helpers in the test file follow the convention. `_held_symbols` is exposed in the .mli for unit-testing purposes with a clear doc note — the underscore signals its internal nature. |
| P6 | Tests use the matchers library | PASS | Both new tests use `assert_that` with `equal_to` and `is_empty` from the `Matchers` module (opened at line 3 of the test file). |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to Portfolio, Orders, Engine, or Position modules. Changes are confined to weinstein_strategy.ml/.mli and the strategy test file, plus a dev/status/ update. |
| A2 | No imports from analysis/ into trading/trading/ | PASS | No new analysis/ imports added to trading/trading/ files. arch_layer_test.sh passed. |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Only four files changed: weinstein_strategy.ml (bug fix), weinstein_strategy.mli (expose _held_symbols for testing), test_weinstein_strategy.ml (two new tests), dev/status/backtest-infra.md (status note). All changes are scoped to the fix. |

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### P2: Magic-number linter failure introduced by date string in comment

- Finding: The newly added docstring for `_held_symbols` contains the text "Bug fix (2026-04-17): previously returned every position in the portfolio" and "[dev/notes/strategy-dispatch-trace-2026-04-17.md] / PR #408." These lines appear as bare text in the middle of a multi-line OCaml comment. The linter's comment-skip heuristic (linter_magic_numbers.sh line 65) only skips lines that contain `(*`, `*)`, or `e.g.` — interior comment continuation lines are not skipped. The regex `[0-9]{2,}` then matches `2026`, `04`, and `17` from the date. The linter was clean on main; this PR introduces the regression.
- Location: `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml` — the new docstring block above `_held_symbols` (lines approximately 118-128 on the feature branch)
- Required fix: One of: (a) remove or reword the inline date from the comment body (e.g., change "Bug fix (2026-04-17):" to "Bug fix (April 2026):" or simply "Previously,"); (b) wrap the offending lines so they appear on the same line as `(*` or `*)`, triggering the existing skip; (c) add a `magic_numbers` path exception to `devtools/checks/linter_exceptions.conf` for this file — but this is inadvisable as the file legitimately should not contain magic numbers.
- harness_gap: LINTER_CANDIDATE — the magic-number linter's comment-skip heuristic is known-weak (grep-based, not AST-based). A more robust fix would be to use a proper OCaml comment stripper before scanning for numeric literals. This is a latent false-positive risk that will recur whenever any comment mentions a year or two-digit number. That said, the simplest resolution for this PR is (a) — rewording the comment.
