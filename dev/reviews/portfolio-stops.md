# QC Structural Review: portfolio-stops

Date: 2026-04-05
Reviewer: qc-structural
Branch reviewed: portfolio-stops/trading-state-sexp
Merge base: 4fcfc160f29e6c3990399d653d9337b5f7ab52e3 (Add sexp derivation to weinstein types and stops)

## Scope

This review covers the two commits unique to `portfolio-stops/trading-state-sexp`
relative to its fork point:

1. `8305e76` Add sexp derivation to weinstein types and stops
2. `dbf038b` Rewrite weinstein_trading_state to use sexp serialisation

New files added:
- `analysis/weinstein/resistance/` (resistance mapper, 3 source files + test)
- `trading/trading/weinstein/trading_state/` (sexp-based persistence, 3 source files + test)
- `analysis/weinstein/order_gen/lib/dune` (empty placeholder stub)

---

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune fmt --check | FAIL | resistance.mli, resistance.ml, test_resistance.ml have formatting diffs (double-space after sentence ends in comments; record destructuring layout in resistance.ml:65-68) |
| H2 | dune build | PASS | |
| H3 | dune runtest | FAIL | 499 tests across 44 suites, 1 failure: test_resistance.ml "high exactly at breakout_price counts" (line 226) |
| P1 | Functions <= 50 lines | PASS | H3 linter passed for all suites except resistance — resistance failure is a behavioral test failure, not a length violation |
| P2 | No magic numbers | PASS | All numeric literals in resistance.ml are inside default_config (520, 130, 0.10, 4, 10); trading_state has no numeric literals |
| P3 | All configurable thresholds/periods/weights in config record | PASS | resistance: all five thresholds (virgin_territory_weeks, clean_lookback_weeks, zone_proximity_pct, moderate_weeks_threshold, heavy_weeks_threshold) routed through config; trading_state has no tunable parameters |
| P4 | .mli files cover all public symbols | PASS | Both new modules have .mli files; resistance.mli exports config, default_config, result, analyze; trading_state.mli exports t, trade_action, trade_log_entry, empty, add_log_entry, set_stop_state, get_stop_state, remove_stop_state, set_prior_stage, get_prior_stage, save, load |
| P5 | Internal helpers prefixed with _ | PASS | resistance.ml: _take_last, _weeks_since_high; trading_state.ml: no internal helpers |
| P6 | Tests use the matchers library | PASS | Both test files open Matchers and use assert_that throughout |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to any of these modules; all new code is in weinstein/ namespace |
| A2 | No imports from analysis/ into trading/trading/ | PASS | New resistance/ and order_gen/ files do not import from trading/trading/; new trading_state uses Trading_portfolio and Weinstein_stops (weinstein/ namespace, not analysis/) |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | All 11 changed files are newly created files; no existing module files were modified |

---

## Verdict

NEEDS_REWORK

---

## NEEDS_REWORK Items

### H1: Format violations in resistance module

- Finding: `dune build @fmt` produces diffs in three files. The formatter changes double-space after sentence-ending periods in doc comments to single-space, and reformats the record destructuring in `analyze` (lines 65-68 of resistance.ml). These are deterministic formatting violations that `dune fmt` would fix automatically.
- Location:
  - `trading/analysis/weinstein/resistance/lib/resistance.mli`
  - `trading/analysis/weinstein/resistance/lib/resistance.ml`
  - `trading/analysis/weinstein/resistance/test/test_resistance.ml`
- Required fix: Run `dune fmt` in the trading directory and commit the result.
- harness_gap: LINTER_CANDIDATE — this is exactly what H1 (dune build @fmt) catches deterministically; no inferential judgment needed.

### H3: Failing test in resistance module

- Finding: `test_high_exactly_at_breakout_price_counts` fails at test_resistance.ml line 226. The test sets up 5 bars all with high = 100.0 and breakout_price = 100.0, then asserts `quality = Clean` and `overhead_weeks = 5`. The assertion on `overhead_weeks` fails — the test reports "Values should be equal / not equal", meaning the proximate-overhead count is not 5. The proximate zone check in resistance.ml is `h >= breakout_price && h <= ceiling` where ceiling = 100.0 * 1.10 = 110.0. With h = 100.0 >= 100.0 and h <= 110.0, this condition is true, so all 5 bars should be counted — meaning the test should pass. The most likely cause is a discrepancy in the `has_overhead` step or `_take_last` with a config that has `virgin_territory_weeks = 10` but only 5 bars: `_take_last 10 [5 bars]` returns all 5, and `has_overhead` should be true. This requires investigation of the actual failure message (the OUnit output says "not equal" without showing the actual value — the test needs a better error message to diagnose, but the code logic appears correct on inspection). The test is definitively failing.
- Location: `trading/analysis/weinstein/resistance/test/test_resistance.ml` line 212-227
- Required fix: Investigate and fix either the test assertion or the resistance.ml implementation to make this test pass. Run `dune runtest` to confirm.
- harness_gap: ONGOING_REVIEW — test failures require understanding the behavioral intent; cannot be mechanically detected beyond "test failed".
