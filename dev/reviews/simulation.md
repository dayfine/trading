# QC Structural Review: simulation

Date: 2026-04-07
Reviewer: qc-structural
Branch reviewed: feat/simulation

## Scope

New files:
- `analysis/weinstein/data_source/lib/synthetic_source.ml/.mli` — deterministic DATA_SOURCE (4 bar patterns)
- `analysis/weinstein/data_source/test/test_synthetic_source.ml` — 8 unit tests
- `trading/weinstein/strategy/test/test_weinstein_strategy_smoke.ml` — 3 smoke tests (Daily x2, Weekly x1)
- `trading/weinstein/strategy/test/dune` — updated to include smoke tests
- `devtools/checks/linter_exceptions.conf` — added `nesting analysis/scripts` exception

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune fmt --check | PASS | No format violations |
| H2 | dune build | PASS | Clean build |
| H3 | dune runtest | PASS | All linters pass (fn_length, magic_numbers, mli_coverage, nesting, arch_layer, fmt_check); all test suites pass |
| P1 | Functions ≤ 50 lines | PASS | Verified by fn_length linter |
| P2 | No magic numbers | PASS | Verified by magic_numbers linter; named constants are implementation constants |
| P3 | Config completeness | PASS | User-facing parameters in `config` record |
| P4 | .mli coverage | PASS | `synthetic_source.mli` added; verified by mli_coverage linter |
| P5 | Internal helpers prefixed with `_` | PASS | Only public symbol is `make` |
| P6 | Tests use matchers library | PASS | Both test files use `assert_that` with matchers throughout |
| A1 | Core module modifications | PASS | No modifications to Portfolio/Orders/Position/Strategy/Engine |
| A2 | No analysis/ → trading/ imports | PASS | arch_layer linter passes |
| A3 | No unnecessary existing module modifications | PASS | `linter_exceptions.conf` and strategy test dune changes both appropriate |

**FLAG**: Branch is 7 commits behind main@origin — rebase recommended before merge. Below 10-commit block threshold; non-blocking.

## Verdict

APPROVED

---

# QC Behavioral Review: simulation

Date: 2026-04-07
Reviewer: qc-behavioral
Branch reviewed: feat/simulation

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|------------------------------------|
| A1 | Core module modification is strategy-agnostic | PASS | `strategy_cadence` is strategy-neutral; no Weinstein-specific logic in shared simulator |
| S1–S6 | Stage definitions and buy criteria | NA | Stage classifier not in this feature |
| L1–L4 | Stop-loss rules | NA | Not in this feature |
| C1–C3 | Screener cascade | NA | Not in this feature |
| T1–T3 | Stage/macro/stop tests | NA | Not in this feature |
| T4 | Tests assert domain outcomes, not just "no error" | PASS | `test_weinstein_weekly_cadence` uses `Weekly` cadence over Jan 2–19 2024 (two Fridays); confirms Friday gate wired end-to-end per eng-design-4 §4.3 |

## Verdict

APPROVED

---

## Combined Result

overall_qc: APPROVED
Both structural and behavioral QC passed on 2026-04-07.
Feature is in Integration Queue — ready to merge to main pending human decision.
