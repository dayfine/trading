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

## Combined Result (Slice 1)

overall_qc: APPROVED
Both structural and behavioral QC passed on 2026-04-07.

---

# QC Structural Review: simulation (Slice 3)

Date: 2026-04-10
Reviewer: lead-orchestrator (inline QC)
Branch reviewed: feat/simulation (commits adfc5902, 3c71f99e)

## Scope

Modified files:
- `trading/weinstein/strategy/lib/weinstein_strategy.ml` — prior_stage accumulation
- `trading/weinstein/strategy/test/test_weinstein_strategy_smoke.ml` — breakout pattern test + doc update
- `dev/status/simulation.md` — status update

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune fmt | PASS | No format violations |
| H2 | dune build | PASS | Clean build |
| H3 | dune runtest | PASS | All tests pass (13 strategy tests: 9 unit + 4 smoke) |
| P1 | Functions ≤ 50 lines | PASS | No new functions; existing functions unchanged in length |
| P2 | No magic numbers | PASS | `base_weeks=40`, `breakout_volume_mult=8.0` are test parameters |
| P3 | Config completeness | PASS | No new user-facing parameters |
| P4 | .mli coverage | PASS | No new public API; .mli unchanged |
| P5 | Internal helpers prefixed | PASS | All existing helpers retain `_` prefix |
| P6 | Tests use matchers | PASS | `assert_that`, `gt`, `not_`, `is_empty` used |
| A1 | Core module modifications | PASS | No modifications to Portfolio/Orders/Position/Strategy/Engine |
| A2 | No analysis/ → trading/ imports | PASS | No cross-layer changes |
| A3 | No unnecessary modifications | PASS | Only strategy impl + test + status file |

## Verdict

APPROVED

---

# QC Behavioral Review: simulation (Slice 3)

Date: 2026-04-10
Reviewer: lead-orchestrator (inline QC)
Branch reviewed: feat/simulation

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| B1 | Prior stage accumulation correct | PASS | Hashtbl stores stage after each `Stage.classify`; next call receives it |
| B2 | Stock_analysis receives prior_stage | PASS | `Hashtbl.find prior_stages ticker` passed to `analyze` |
| B3 | Index prior stage wired to Macro | PASS | `Hashtbl.find prior_stages config.index_symbol` → `Macro.analyze ~prior_stage` |
| B4 | Side effects contained in closure | PASS | `prior_stages` Hashtbl created in `make`, same pattern as `stop_states` and `bar_history` |
| B5 | Test exercises full pipeline | PASS | Breakout pattern → Stage1→Stage2 → screener → orders → trades → assertions |
| B6 | Test assertions meaningful | PASS | Verifies orders submitted, trades executed, positive portfolio value |
| T1 | Domain correctness | PASS | Prior stage accumulation matches Weinstein's weekly stage progression concept |

## Verdict

APPROVED

---

## Combined Result (Slice 3)

overall_qc: APPROVED
Both structural and behavioral QC passed on 2026-04-10.
Feature is in Integration Queue — ready to merge to main pending human decision.
