Reviewed SHA: 57571d631fbc5ab7ca311c02f5732e8b5f4c663d

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | Orchestrator live evidence (run on tip SHA 57571d63): `dune runtest --force` → exit=0. Per exit-code-only rule, gate verdict is PASS. Prior review's finding of linter text was advisory output during normal test execution, not gating output. |
| P1 | Functions ≤ 50 lines (linter) | PASS | All functions in weekly_ma_cache.ml are under 50 lines (longest: _snapshot_weekly_history at ~16 lines). |
| P2 | No magic numbers (linter) | PASS | No hardcoded numeric literals in the PR's code. Comments in snapshot_bar_views.ml mention 250-day/10-year windows but are explanatory text, not tunable parameters. |
| P3 | Config completeness | PASS | No new tunable thresholds introduced; cache uses caller-provided max_as_of and reads from existing config-backed data sources. |
| P4 | Public-symbol export hygiene (linter) | PASS | .mli file fully documents all public symbols; internal helpers prefixed with underscore. |
| P5 | Internal helpers prefixed per convention | PASS | All internal functions (_tag_of_stage_ma_type, _panels_weekly_history, _snapshot_weekly_history, _compute_ma_array, _build_entry) use underscore prefix. |
| P6 | Tests conform to `.claude/rules/test-patterns.md` (presence + conformance) | PASS | Test file opens Matchers and uses assert_that + matcher composition throughout (elements_are, all_of, field, is_some_and, is_none, equal_to, float_equal). No violations of the three sub-rules: no List.exists with equal_to true/false; no let _ = with on_market_close/.run; match statements in test helpers use failwith (standard practice per test-patterns.md). Helper functions (panels_of_symbols, _build_snapshot_callbacks) follow test data builder conventions; all actual test assertions use proper matchers. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) — FLAG if any found | PASS | No modifications to core modules. Only weekly_ma_cache.ml/mli (new backings) and test file changes. |
| A2 | No new `analysis/` imports into `trading/trading/` outside the established backtest exception surface | PASS | Test dune file declares weinstein.* dependencies (allowed exception for backtest tests). Strategy lib dune file declares weinstein.* (allowed). No non-weinstein analysis imports. |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | PR file list (per gh pr view) contains only 4 files: weekly_ma_cache.ml, weekly_ma_cache.mli, strategy test dune, test_weekly_ma_cache.ml. All changes are localized to this feature. |

## Verdict

APPROVED

---

# Behavioral QC — data-foundations (Phase F.3.b-1)
Date: 2026-05-04
Reviewer: qc-behavioral
PR: #833 — feat/weekly-ma-cache-snapshot-port
Tip SHA: 57571d631fbc5ab7ca311c02f5732e8b5f4c663d

This is a pure infrastructure / refactor PR (parallel constructor + internal closure restructure for `Weekly_ma_cache`). It touches no Weinstein domain logic (no stage rules, buy/sell, stops, screener). Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely", the S*/L*/C*/T* domain rows are NA; the review is the generic CP1–CP4 contract pinning checklist.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | Claims and pinning tests: (a) "Both produce bit-equal MA / dates arrays for the same key when the underlying bar history is identical" → `test_snapshot_parity_sma_30`, `test_snapshot_parity_wma_30`, `test_snapshot_parity_sma_10` (assert element-wise equality of `(values, dates)` pairs from panel-backed vs snapshot-backed caches via `elements_are` + `all_of [field float_equal; field equal_to]`). (b) `of_snapshot_views` "semantically equivalent to create … same MA values, same dates, same memoisation behaviour" → same parity tests for value/date equivalence. (c) Empty-history / unknown-symbol behaviour → `test_snapshot_short_history_returns_empty`, `test_snapshot_unknown_symbol_returns_empty`. (d) `max_as_of` upper-bound semantics with `n = Int.max_value` → exercised on every snapshot parity test (the helper passes the last bar's date as `max_as_of`). |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | PASS | PR body advertises "parity test pinning bit-equal MA values + dates between snapshot-backed and panel-backed paths on a known fixture." Three such tests are committed (`test_snapshot_parity_sma_30`, `test_snapshot_parity_wma_30`, `test_snapshot_parity_sma_10`) using deterministic Friday-aligned synthetic bars. The `_run_snapshot_parity` helper builds both caches over the same `(symbol, bars)` fixture and asserts pair-wise equality on `(values, dates)`. No advertised test missing from the file. |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are [equal_to ...] or equal_to on entire value), not just size_is | PASS | Parity tests use `elements_are (List.map panel_pairs ~f:(fun (v, d) -> all_of [field … (float_equal ~epsilon:1e-9 v); field … (equal_to d)]))` — full element-wise equality on both the float values and the date arrays, not just length. The `panel_pairs` zip ensures positional alignment is asserted. Only the empty-history edge tests use `Array.length … |> equal_to 0`, which is the correct identity for the empty-output contract. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | The .ml comment in `_snapshot_weekly_history` calls out the `Int.max_value` overflow guard: "weekly_view_for would compute the calendar span from n via (n*8)+7, which overflows for n = Int.max_value; the weekly_bars_for entrypoint sidesteps that overflow." Every snapshot-backed test passes through `_snapshot_weekly_history` which always invokes `weekly_bars_for cb ~symbol ~n:Int.max_value`, so the overflow-avoidance branch is exercised on every snapshot parity test. The .mli's EMA caveat ("The default Stage config uses WMA, not EMA, so this concern is dormant") is documented as a known asymptotic property, not a guard, and notes the production path is WMA — no snapshot-EMA parity test is required to pin the live-config contract. |

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1–T4 | All Weinstein domain rows | NA | Pure infra refactor; domain checklist not applicable per `.claude/rules/qc-behavioral-authority.md`. PR adds a parallel constructor and refactors `Weekly_ma_cache` internals to a backing-agnostic closure; touches no stage rules, buy/sell criteria, stops, screener cascade, or sector/macro logic. |

## Quality Score

5 — Exemplary contract-pinning: every .mli claim has an identified test, the parity tests assert full element identity (values + dates) via composed matchers, edge cases (empty history, unknown symbol) are covered for both backings, and the overflow-guard rationale in the .ml is exercised by construction on every snapshot test path. Closure-based factoring keeps the converging seam observable from tests.

## Verdict

APPROVED
