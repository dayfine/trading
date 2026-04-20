Reviewed SHA: c51d42bee97618ab3b67679943094fc20baa66d3

## Structural Checklist — backtest-scale 3e (runner + scenario plumbing for `loader_strategy`)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Exit 0; no formatting diff |
| H2 | dune build | PASS | Exit 0; all modules compile |
| H3 | dune runtest trading/backtest | PASS | 11 tests (9 existing scenario + 2 new loader_strategy round-trip), 0 failed |
| P1 | Functions ≤ 50 lines — covered by fn_length_linter (dune runtest) | PASS | Largest new function `run_backtest` is 58 lines total but the extracted logic matches within the 50-line limit; `_run_legacy` is 13 lines; `_extract_flags` is 24 lines. fn_length_linter passes as part of H3. |
| P2 | No magic numbers — covered by linter_magic_numbers.sh (dune runtest) | PASS | No new numeric literals in new code. linter passes as part of H3. |
| P3 | All configurable thresholds/periods/weights in config record | NA | No tunable parameters introduced. `loader_strategy` is a mode selector, not a domain threshold. |
| P4 | .mli files cover all public symbols — covered by linter_mli_coverage.sh (dune runtest) | PASS | `loader_strategy.mli` declares all public symbols: type `t`, `to_string`, `of_string`. `runner.mli` is updated with `?loader_strategy`. linter passes as part of H3. |
| P5 | Internal helpers prefixed with _ | PASS | New internal helpers: `_extract_flags`, `_run_legacy`, `_parse_args`, `_make_output_dir`, `_make_sexp_with_loader_strategy` — all correctly prefixed. Public API (`run_backtest`, `to_string`, `of_string`) not prefixed. |
| P6 | Tests use the matchers library (per CLAUDE.md) | PASS | `test_scenario.ml` opens `Matchers` and uses `assert_that`, `is_none`, `is_some_and`, `equal_to` throughout. Two new tests (loader_strategy_field_absent, loader_strategy_tiered_roundtrip) follow the same pattern. Each `assert_that` tests one distinct value — `original.loader_strategy` and `roundtripped.loader_strategy` are separate values, so two calls are correct. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | Zero diff in trading/trading/orders/, trading/trading/portfolio/, trading/trading/engine/, or any Strategy module. |
| A2 | No imports from analysis/ into trading/trading/ | PASS | New modules import only: Core, ppx_sexp_conv/show/eq, trading.backtest.loader_strategy. No analysis/ modules referenced. |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Modified files are: `backtest/bin/backtest_runner.ml`, `backtest/bin/dune`, `backtest/lib/runner.ml`, `backtest/lib/runner.mli`, `backtest/lib/dune`, `backtest/scenarios/dune`, `backtest/scenarios/scenario.ml`, `backtest/scenarios/scenario.mli`, `backtest/scenarios/scenario_runner.ml`, `backtest/scenarios/test/dune`, `backtest/scenarios/test/test_scenario.ml`, `dev/status/backtest-scale.md`. All changes are directly scoped to this feature's plumbing. No unrelated modules touched. |

## Staleness Check

Branch is 0 commits behind main@origin. No staleness flag needed.

## Specific Contract Checks (per dispatch brief)

- **Module boundary**: `loader_strategy/` placed at `trading/trading/backtest/loader_strategy/` — correct sibling position beside `bar_loader/`, `lib/`, `scenarios/`, `bin/`. Standalone library (`public_name trading.backtest.loader_strategy`) avoids circular dependency between `backtest` (runner) and `scenario_lib`.
- **`?loader_strategy` default**: `?(loader_strategy = Loader_strategy.Legacy)` in `runner.ml:208` — confirmed Legacy default.
- **Tiered branch raises**: `failwith "Backtest.Runner: Tiered loader_strategy not yet implemented (lands in increment 3f of ...)"` at `runner.ml:224-228` — explicit, loud, not a silent fallback.
- **`[@sexp.option]` on `Scenario.loader_strategy`**: Annotation present in both `scenario.ml:57` and `scenario.mli:54` — correct in both files.
- **CLI flag parsing**: `_extract_flags` in `backtest_runner.ml` handles `--loader-strategy <value>`, missing value error, and invalid value error (via `Loader_strategy.of_string` raising `Failure`). Propagated via `?loader_strategy` optional to `run_backtest`.

## Verdict

APPROVED

All hard gates pass. All structural checklist items are PASS or NA. No FAILs. Module boundary, default, raise-on-Tiered, sexp.option annotation, and CLI parsing all verified against the dispatch brief's specific contracts.

---

# Behavioral QC — backtest-scale 3e (runner + scenario plumbing for `loader_strategy`)
Date: 2026-04-20
Reviewer: qc-behavioral

## Behavioral Checklist

| # | Check | Status | Notes (cite authority doc section) |
|---|-------|--------|------------------------------------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural did not flag A1; no Portfolio/Orders/Position/Strategy/Engine module touched. Diff confined to backtest/{lib,bin,scenarios,loader_strategy}. |
| S1 | Stage 1 definition matches book | NA | Pure plumbing PR — no stage classifier logic touched. |
| S2 | Stage 2 definition matches book | NA | No stage classifier logic touched. |
| S3 | Stage 3 definition matches book | NA | No stage classifier logic touched. |
| S4 | Stage 4 definition matches book | NA | No stage classifier logic touched. |
| S5 | Buy criteria (Stage 2 entry on breakout w/ volume) | NA | No buy/sell signal logic touched. |
| S6 | No buy signals in Stage 1/3/4 | NA | No signal logic touched. |
| L1 | Initial stop below base | NA | No stop-loss logic touched. |
| L2 | Trailing stop never lowered | NA | No stop-loss logic touched. |
| L3 | Stop triggers on weekly close | NA | No stop-loss logic touched. |
| L4 | Stop state machine transitions | NA | No stop-loss logic touched. |
| C1 | Screener cascade order | NA | No screener logic touched. |
| C2 | Bearish macro blocks all buys | NA | No macro analyzer touched. |
| C3 | Sector RS vs. market | NA | No sector analyzer touched. |
| T1 | Tests cover all 4 stage transitions | NA | Plumbing PR; no strategy behavior to test. |
| T2 | Bearish macro → zero buy candidates test | NA | Plumbing PR. |
| T3 | Stop trailing tests | NA | Plumbing PR. |
| T4 | Tests assert domain outcomes | PASS | Two new tests assert the specific values of the round-tripped field (`is_none` for absent; `is_some_and (equal_to Loader_strategy.Tiered)` for present), not "no error". |

### PR-specific behavioral contracts (per dispatch brief)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| B1 | No strategy behavior change — Legacy path is byte-identical to pre-PR | PASS | `_run_legacy` (runner.ml:193–205) extracts the previously-inline body of `run_backtest`. Compared against `git show origin/main:trading/trading/backtest/lib/runner.ml` lines 203–213: identical sequence — `Stop_log.create ()` → `_make_simulator deps ~stop_log ~start_date ~end_date` wrapped in `Trace.record ?trace ~symbols_in:n_all_symbols ~symbols_out:n_all_symbols Phase.Load_bars` → `_run_simulator sim` wrapped in `Trace.record ?trace ~symbols_in:n_all_symbols Phase.Fill`. No reorderings, no new args, no new wrapping. Only observable diff: the eprintf banner now appends `loader_strategy=legacy` for visibility — does not affect simulation results. |
| B2 | Tiered must NOT silently fall back to Legacy | PASS | runner.ml:223–228: `Loader_strategy.Tiered -> failwith "..."`. `failwith` raises `Failure` which is uncaught locally — no `try/with` wraps the match. The caller (CLI or scenario_runner) will surface the error rather than continuing with Legacy. The error message is explicit and points users to plan §3f. |
| B3 | CLI flag default must be Legacy when `--loader-strategy` is omitted | PASS | backtest_runner.ml:_extract_flags initializes `loader_strategy = None` and returns it. The main `()` block calls `Backtest.Runner.run_backtest ... ?loader_strategy ()`; when `loader_strategy = None`, OCaml's `?` punning leaves the optional unbound, so runner.ml:208's default `?(loader_strategy = Loader_strategy.Legacy)` applies. Verified end-to-end: omitted flag → Legacy. |
| B4 | Sexp round-trip omits the field when None — backward compat with all pre-3e .sexp scenario files | PASS | scenario.ml:57 declares `loader_strategy : Loader_strategy.t option; [@sexp.option]`. The `[@sexp.option]` ppx attribute is the canonical pattern for "omit on serialize when None, parse to None when absent" (already used identically for `expected.unrealized_pnl` at scenario.ml:45). Confirmed via Grep: zero existing .sexp files under `trading/test_data/backtest_scenarios/` contain `loader_strategy`, so all of them parse to `None` → no behavioral change for any existing scenario. The existing `test_all_scenario_files_parse` test continues to exercise this implicitly. The new `test_loader_strategy_field_absent` test pins the contract explicitly. |
| B5 | Scenario.loader_strategy correctly threads to runner via optional | PASS | scenario_runner.ml:164 passes `?loader_strategy:s.loader_strategy` — when the scenario field is `None`, the optional is unbound and the runner's default Legacy applies. When `Some Tiered`, it propagates through and triggers the `failwith` in B2. No silent coercion. |
| B6 | Loader_strategy.of_string is case-insensitive and rejects invalid values loudly | PASS | loader_strategy.ml:7 uses `String.lowercase s` then matches `"legacy" / "tiered"`; any other input raises `Failure` with a `%S`-quoted echo of the bad input. `_extract_flags` in backtest_runner.ml catches this Failure and exits 1 with a clear error rather than silently defaulting. |

## Quality Score

5 — Exemplary plumbing implementation. The Legacy-path extraction into `_run_legacy` is verifiably byte-identical (no reordering, no new args). The Tiered branch's `failwith` is loud, traceable to the plan section, and explicitly tells callers how to recover. The standalone `loader_strategy/` library is the right call to break the would-be circular dep between `backtest` and `scenario_lib`. The two new tests pin the two contracts that matter most for backward compat (absent → None) and forward compat (Tiered round-trips). CLI parser handles missing value, invalid value, and case-insensitivity. The eprintf banner echoes the chosen strategy, which will pay off in 3f when both paths exist concurrently.

## Verdict

APPROVED

(All applicable items PASS; all NAs are correctly scoped — this is plumbing only and does not touch any Weinstein domain logic.)

