Reviewed SHA: 6b3ce79fea1b51129906a32eb4744a8bd5a7e0f9

## Structural QC — trades-export-join-fix (PR #1942)

Backtest-infra / tooling PR: keys `trades.csv` `exit_trigger` + `stop_trigger_kind`
by `position_id` (via the audit-recovered join) instead of a symbol-keyed FIFO
pop, and appends a trailing `position_id` column. No domain (strategy) logic;
domain-leak rows are PASS/NA.

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | exit 0 |
| H2 | dune build | PASS | exit 0 |
| H3 | dune runtest | PASS | exit 0 (full suite incl. wired linters: fn_length, magic_numbers, mli_coverage, nesting) |
| P1 | Functions ≤ 50 lines (linter) | PASS | Covered by H3. New fns are short: `stop_info_for_trade` (~5 lines), `_position_id_for_trade` (~4 lines); `_write_trade_row` shrank (FIFO-pop removed). |
| P2 | No magic numbers (linter) | PASS | Covered by H3. No new literals in lib code; test-file price literals are in test files (not linted). |
| P3 | Config completeness | NA | CSV export keying fix; introduces no tunable threshold/period/weight. |
| P4 | Public-symbol export hygiene (mli) | PASS | New public `stop_info_for_trade` is declared + documented in `trade_context.mli`; new `position_id` record field added to the `.mli` type and `csv_header_fields`/`csv_row_fields` docstrings updated. |
| P5 | Internal helpers prefixed per convention | PASS | `_position_id_for_trade` underscore-prefixed; `stop_info_for_trade` is intentionally public (exposed in `.mli`). |
| P6 | Tests conform to test-patterns.md | PASS | New tests use `assert_that` + `elements_are`/`all_of`/`field`/`is_some_and`. Sub-rule 1 (`List.exists ... equal_to true/false`): none. Sub-rule 2 (`let _ = ...on_market_close`/`.run`): none. Sub-rule 3 (`match ... Error -> assert_failure` / bare `Ok ->`): none. The two `assert_that` calls in `test_stop_info_for_trade_keys_by_position_id` target two distinct values (trade1 vs trade2 results) — compliant with one-assert-per-value. |
| A1 | Core module modifications | PASS | No touches to portfolio/orders/position/strategy/engine; all source under `trading/trading/backtest/`. |
| A2 | No new analysis/ imports into trading/trading/ | NA | No dune-file changes in the diff. |
| A3 | No unnecessary modifications to existing modules | PASS | 8 files (per git diff vs main; matches the stated PR file list): 3 lib/test-support files, 4 tests, 1 status doc — all coherent with the fix. No cross-feature drift. |

Notes:
- Experiment-flag-discipline (R1–R3): N/A. This is a bugfix to CSV export keying,
  not a new strategy mechanism, so no default-off config flag is required.
- Backward-compat: `position_id` is appended LAST so fixed positional reader
  indices (`exit_trigger`=12, `stop_trigger_kind`=16) stay valid; the canonical
  header golden in `test_trade_audit_report.ml` is updated accordingly.
- Branch is 1 commit behind origin/main — no staleness flag.

## Verdict

APPROVED

## Behavioral QC — trades-export-join-fix (PR #1942)

Pure backtest-infra / CSV-export correctness fix. No Weinstein strategy logic touched.

| # | Check | Status |
|---|-------|--------|
| CP1 | Each non-trivial .mli claim pinned by a test | PASS |
| CP2 | PR "Test plan" claims each have a committed test | PASS |
| CP3 | Pass-through/identity tests pin identity (elements_are), not size | PASS |
| CP4 | Each docstring guard has a test exercising the guarded scenario | PASS |

Domain block (S*/L*/C*/T*): NA — pure infra PR per qc-behavioral-authority §"When to skip".
Key claim verified: multi-position-per-symbol join pinned by TWO tests supplying
stop_infos reversed vs trade order (trips residual FIFO join) + a validator V5 regression
fixture mirroring the real WSM specimen. dune build/runtest exit 0 on backtest test dirs.

## Quality Score

5 — Exemplary: single-source-of-truth position-keyed join, clear .mli contracts, tests
deliberately constructed to trip the exact bug while asserting per-position outcomes.

## Verdict

APPROVED
