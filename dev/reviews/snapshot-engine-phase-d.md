Reviewed SHA: 1026659c

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | FAIL | Indentation drift in trading/trading/backtest/lib/runner.mli lines 135-139 — docstring example block needs +4 spaces per ocamlformat indent rules |
| H2 | dune build | PASS | Builds clean |
| H3 | dune runtest | PASS | 200+ tests passed (output truncated; includes 3 new parity tests + 4 new flag tests) |
| P1 | Functions ≤ 50 lines (linter) | PASS | New functions in bar_data_source.ml (27 LOC), snapshot_bar_source.ml (85 LOC distributed across 5 functions), test fixtures under 80 LOC each. All under limit. |
| P2 | No magic numbers (linter) | PASS | H3 linter passed. Single constant _previous_bar_lookback_days=60 is named in snapshot_bar_source.ml. |
| P3 | Config completeness | PASS | No hardcoded thresholds; 60-day lookback is named constant with doc comment. |
| P4 | Public-symbol export hygiene (linter) | PASS | H3 mli-coverage passed. bar_data_source.mli + snapshot_bar_source.mli fully document public API. |
| P5 | Internal helpers prefixed per convention | PASS | All helpers prefixed with underscore: _make_bar, _build_snapshot_adapter, _snapshot_to_daily_price, etc. |
| P6 | Tests conform to test-patterns.md | PASS | 3 parity tests + 4 flag tests. All use `assert_that` with matchers (equal_to, is_ok_and_holds, is_none, elements_are). No nested asserts inside List.iter. No bare List.exists on bool. |
| A1 | Core module modifications (FLAG if any) | FLAG | Market_data_adapter.mli + simulator.mli modified. Changes are strategy-agnostic (feature flag adds optional params; simulator gains optional benchmark_symbol + market_data_adapter). No Weinstein-specific logic. Routed to behavioral for generalizability judgment. |
| A2 | No new analysis/ imports outside backtest exception | PASS | All weinstein.snapshot_pipeline + weinstein.snapshot_runtime imports are in trading/trading/backtest/lib/dune (bar_data_source, snapshot_bar_source modules). Backtest exception surface established + confirmed. |
| A3 | No unnecessary modifications to existing modules | PASS | File scope = 21 per gh pr view 790 --json files. No cross-feature drift. Modifications to simulator/market_data_adapter are minimal (optional params + split detection helpers). |

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### H1: Format drift in runner.mli docstring
- Finding: Indentation in docstring example (lines 135-139) does not conform to ocamlformat rules. The bracket list inside the docstring block {[ ... ]} should have 4 additional spaces of indentation per line.
- Location: /Users/difan/Projects/trading-1/trading/trading/backtest/lib/runner.mli lines 135-139
- Required fix: Run `dune build @fmt` locally to auto-correct, then stage + commit. The issue is minor but H1 is a strict gate.
- harness_gap: LINTER_CANDIDATE — dune fmt --check is already wired into CI; this should have been caught pre-push. Consider a pre-commit hook if not already active.

