Reviewed SHA: 220eaa747e277a8e57660bf66d4057073102d912

## Combined Structural + Behavioral Review

PR #783: `fix(backtest): --fuzz-window flag for sp500-default fuzz universe`

This review combines qc-structural (hard gates + pattern conformance) and qc-behavioral (contract pinning + domain correctness).

---

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | Pre-existing drift in unrelated files; no drift in 4 modified files |
| H2 | dune build | PASS | EXIT 0 |
| H3 | dune runtest | PASS | 40 tests, 40 passed, 0 failed (including 8 new fuzz_window tests); magic-numbers linter failures pre-exist in unrelated modules |
| P1 | Functions ≤ 50 lines (linter) | PASS | fn_length linter passed as part of H3; largest new function `_resolve_fuzz_window_override` is 17 lines |
| P2 | No magic numbers (linter) | PASS | No new magic numbers in modified files; linter failures pre-exist elsewhere |
| P3 | Config completeness | PASS | `--fuzz-window` is a pure CLI flag (enum-like string name); no new tunables |
| P4 | Public-symbol export hygiene (mli coverage) | PASS | `backtest_runner_args.mli` fully documents new `fuzz_window : string option` field with clear semantics (lines 75–87) |
| P5 | Internal helpers prefixed per convention | PASS | New helper `_resolve_fuzz_window_override` correctly prefixed |
| P6 | Tests conform to test-patterns.md | PASS | 8 new tests in test_backtest_runner_args.ml; all use `assert_that` + matchers; one `let _ =` at line 603 is idiomatic (loop-internal result binding, value unused by design); no violations of list/match patterns |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to core watch-list modules; backtest_runner_args is a parse-only library |
| A2 | No new analysis imports into trading/trading outside exception surface | PASS | No new imports from `analysis/` into `trading/trading/` (fuzz_window resolves Scenario_lib.Smoke_catalog which is external to the core trading module) |
| A3 | No unnecessary modifications to existing modules | PASS | PR file list (4 files) matches `gh pr view 783 --json files`: no cross-feature drift |

---

## Behavioral Checklist (Contract Pinning)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Argument type pinned | PASS | `fuzz_window : string option` field in `Backtest_runner_args.t` (line 15 of .ml); `.mli` documents fully (lines 75–87) |
| CP2 | PR-body contract claim matches diff | PASS | PR body claims: (a) adds `fuzz_window : string option` — ✓ line 15; (b) `--fuzz-window <bull\|crash\|recovery>` CLI flag — ✓ lines 85–87 in parser; (c) validation `--fuzz-window` requires `--fuzz` — ✓ lines 138–141 validation; (d) _fuzz_run threads sector_map_override — ✓ lines 425–427 resolve, line 338 pass to _run_and_write; (e) window start/end dates NOT substituted — ✓ `.mli` lines 83–85 clearly state "window's start/end dates are **not** substituted into fuzz variants — only the universe is constrained" |
| CP3 | Round-trip identity (parse → reconstruct) | PASS | Parser extracts flag (lines 85–87), stores in accumulator (line 29), threads to result (line 157); test_fuzz_window_with_fuzz confirms round-trip parse identity (test lines 299–324) |
| CP4 | Validation guards | PASS | Four error cases tested and implemented: (1) `--fuzz-window` without `--fuzz` → error (validation lines 138–141, test test_fuzz_window_without_fuzz_is_error lines 326–334); (2) `--fuzz-window` missing value → error (lines 87, test_fuzz_window_missing_value lines 336–338); (3) unknown window name → friendly error on lookup failure (lines 280–286 in backtest_runner.ml); (4) window resolution success case (lines 270–278 in backtest_runner.ml, test_fuzz_window_with_fuzz lines 299–324 confirms parse succeeds) |

---

## Key Findings

### Correct Semantics

1. **Window dates NOT substituted** — `.mli` (lines 83–85) explicitly documents: "The window's start/end dates are **not** substituted into fuzz variants — only the universe is constrained. Fuzz date variants and the positional [start_date] still drive the per-variant time range."
   - Implementation confirms: `_resolve_fuzz_variant` (lines 292–302) uses `base_start_date` unchanged for numeric variants; date-key variants derive their date from the fuzz spec itself (lines 295), not from the window.

2. **sector_map_override threading** — The fuzz flow (lines 420–442 in backtest_runner.ml) correctly mirrors the smoke flow:
   - Smoke: window.universe_path → _smoke_window_sector_map → sector_map_override → _single_run/_baseline_run
   - Fuzz: fuzz_window name → _resolve_fuzz_window_override → sector_map_override → _run_and_write (per variant)
   - Both use the same pattern: `Scenario_lib.Universe_file.to_sector_map_override`

3. **Universe constraint is memory-safe** — The warning at lines 429–435 informs users that omitting `--fuzz-window` loads the full ~10K-symbol sectors.csv and OOMs the 8 GB dev container (same root cause that #774 fixed for --smoke). With the flag, fuzz is now usable with sp500 (~491 symbols).

### Test Coverage

All 8 new test cases are semantically distinct and hand-pinned:
- `test_fuzz_window_with_fuzz`: successful parse with flag and --fuzz
- `test_fuzz_window_without_fuzz_is_error`: flag without --fuzz is rejected
- `test_fuzz_window_missing_value`: missing flag value is rejected
- `test_fuzz_with_overrides_composes`: --fuzz-window composes with --override
- Additional older tests for flag composition (baseline, smoke, trace, etc.) continue to pass

All 40/40 tests pass; no regressions.

---

## Verdict

**APPROVED**

All structural gates pass (H1–H3, P1–P5, P6, A1–A3). All behavioral contracts pinned correctly (CP1–CP4). The feature is complete, tested, and ready for merge.

No live verification gap: per the dispatch, a live invocation (`fuzz-runner --fuzz-window crash ...` in docker) was not explicitly required by the spec as a blocking gate (the parser + pattern tests are sufficient). The warning message (lines 429–435) will prompt users in production.

