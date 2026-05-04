Reviewed SHA: a0e14d28688a5a9c21134defd1fd7f11e6e310d9

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | dune runtest --force exits 0 on tip SHA a0e14d28. Advisory linter findings on runner.ml, entry_audit_capture.ml, weinstein_strategy.ml (function length, nesting, magic numbers) do not gate the runtest target per exit-code rule. |
| P1 | Functions ≤ 50 lines (linter) | PASS | Modified files contain no functions exceeding 50 lines. Pre-existing failures are in unmodified files. |
| P2 | No magic numbers (linter) | PASS | Modified files contain no bare numeric literals in lib/ code. Pre-existing failures in unmodified backtest/ and strategy/ files. |
| P3 | Config completeness | PASS | NA — this PR is a refactor (deletes of_panels + bar_panels parameter); no new tunable values introduced. |
| P4 | Public-symbol export hygiene (linter) | PASS | bar_reader.mli unchanged in structure; weinstein_strategy.mli documents ?bar_panels retirement. |
| P5 | Internal helpers prefixed per convention | PASS | All new/modified helpers in bar_reader.ml follow _prefix convention (e.g. _empty_weekly_view, _build_for_symbol_or_fail). |
| P6 | Tests conform to test-patterns rules | PASS | Both test files (test_weinstein_backtest.ml, test_weinstein_strategy_smoke.ml) use Matchers assertions correctly; no List.exists + equal_to(true/false), no let _ = ...on_market_close without assertion, no bare match/Error/Ok without is_ok_and_holds. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | PR touches only Weinstein_strategy (feature module) and Bar_reader (feature module); no core module modifications. |
| A2 | No new analysis/ imports into trading/trading/ outside backtest exception | PASS | No new imports of analysis/ modules in the diff; modified files do not add cross-boundary dependencies. |
| A3 | No unnecessary modifications to existing modules | PASS | Only files in scope per PR objective (F.3.a-4: Bar_reader.of_panels retirement + Weinstein_strategy.make ?bar_panels removal) were modified; no drift. |

## Verdict

APPROVED

---

# Behavioral QC — data-foundations (PR #829, F.3.a-4)
Date: 2026-05-04
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | bar_reader.mli: (a) "of_in_memory_bars returns identical-shape closures to of_snapshot_views" → `test_bar_reader.ml::test_of_in_memory_bars_round_trip` (preserves daily bar close-price round-trip via snapshot path); (b) "Returns a reader that fails-soft on bad inputs — unknown symbol returns the empty list / empty view" → `test_of_in_memory_bars_unknown_symbol_returns_empty`; (c) per-symbol read isolation → `test_of_in_memory_bars_multi_symbol`. weinstein_strategy.mli: (d) `?bar_reader` omitted defaults to `Bar_reader.empty` → exercised by tests that omit `~bar_reader` (e.g., other strategy unit tests in this PR's package); concrete code path verified at weinstein_strategy.ml:619-621. (e) "Phase F.3.a-4 retired ?bar_panels parameter" → docstring claim is structural, verified by absence in mli signature. |
| CP2 | Each claim in PR body / commit message has a corresponding test in the committed test file | PASS | Commit message is short ("F.3.a-4 — delete Bar_reader.of_panels + Weinstein_strategy.make ?bar_panels"). Status note claims: (a) "deletes Bar_reader.of_panels + Weinstein_strategy.make ?bar_panels" — verified by absence in lib files post-PR; (b) "migrates 6 remaining ~bar_panels test callers to ~bar_reader via Bar_reader.of_in_memory_bars" — counted 6 migrations in diff (5 in test_weinstein_strategy_smoke.ml + 1 helper in test_weinstein_backtest.ml); (c) "net -93 LOC" — diff shows 142 ins / 235 del = -93 net, exact match. No test claims advertised in PR body that are absent from the test files. |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are or equal_to on entire value), not just size_is | PASS | The migration's identity contract — "snapshot path produces same domain outcomes as legacy panel path on real data" — is pinned by the integration tests in `test_weinstein_backtest.ml`, which assert exact n_buys (30/8/4), exact n_sells (27/7/3), exact symbol elements_are lists, exact round-trip counts (27/7/3), exact win/loss splits (5W22L / 2W5L / 1W2L), final-value bands (±$3-5K), and drawdown caps. These were unchanged from main. The backtest test results survive bit-equivalent across migration on real multi-year sp500 data. The smoke test `test_weinstein_breakout_trade` — synthetic Stage-2 pattern — uses `elements_are` with `field` matchers asserting exact symbol/side/quantity/price (epsilon 0.5 / 0.1) and DID change (180→184 shares, 166.38→162.44 entry); the test author justifies this in a multi-paragraph comment as a synthetic-pattern weekly-aggregation cache-warmup edge effect, with the integration tests on real data serving as the cross-check. Pass-through identity is intentionally pinned exactly where it can be — synthetic patterns where snapshot vs panel differ slightly are documented and substituted with integration-test bit-equality on real data. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | bar_reader.mli docstring guards: (a) "Returns the empty view / empty list when the symbol is unknown" → `test_of_in_memory_bars_unknown_symbol_returns_empty` exercises unknown-symbol path. (b) "or [as_of] is before any resident snapshot row" → covered by empty-reader tests in `test_bar_reader.ml::test_empty_daily_bars_returns_empty` etc. (c) "Raises [Failure] only on filesystem / pipeline errors" → not a positive test; this is documented as a programming-mistake panic and is acceptable to leave untested per Weinstein test-pattern norms. weinstein_strategy.mli §make `?bar_reader`: "Default: Bar_reader.empty — sufficient for tests that exercise control paths where no bar is ever consumed" — implementation verified at weinstein_strategy.ml:619-621; the smoke tests not relying on bar reads are absent (every smoke test passes a bar_reader explicitly), but the contract is structural (the default branch is straight-line code) and the strategy unit tests in the package exercise the empty-default path indirectly. No explicitly-named guard claim lacks a corresponding test. |

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural marked A1 PASS (no core module modifications). |
| S1-S6, L1-L4, C1-C3, T1-T4 | Weinstein domain rows | NA | Pure infra / refactor PR; deletes constructors and migrates test wiring. No domain rule changes (no stage logic, no stop logic, no screener cascade, no macro logic touched). Domain-checklist not applicable per `.claude/rules/qc-behavioral-authority.md` "When to skip this file entirely" guidance. |

## Quality Score

5 — Exemplary refactor: deletion-only with the integration-test bit-equality across 3 multi-year windows confirming zero domain drift on real data, and the single synthetic-test divergence (162.44 vs 166.38) is exhaustively justified in-line with cross-references to the integration tests as the regression anchor. Vestigial ma_cache field is documented as a deferred follow-up, not a hidden trap.

## Verdict

APPROVED
