Reviewed SHA: 6e3bdbc8c706c634c9419004a49fffa35bee85b0
PR: #920 (feat/cost-overlay-slippage-bps; maintainer-authored)
Reviewed: 2026-05-08 (lead-orchestrator dispatch)

## Orchestrator post-verification (2026-05-08)

The qc-structural agent recorded `Reviewed SHA: 359607f9...` (the PR's first commit) instead of the actual tip `6e3bdbc8...` (the maintainer's fmt fix). Orchestrator re-ran the hard gates directly on tip 6e3bdbc8 — the picture differs:

- **H1 `dune build @fmt` exits 0** on tip 6e3bdbc8 — the maintainer's fmt fix at 6e3bdbc8 was the slippage_bps docstring rewrap. Agent's H1 finding referenced the older commit's docstring shape; **FALSE on tip**.
- **H3 file-length / fn-length fails are present on the raw PR branch** (5 file-length violations + run_backtest 83 lines) BUT every one is a stale-branch artifact: the listed files were already trimmed on `main` via PRs #963/#972/#973/#974/#978/#980 etc. that landed AFTER PR #920's last merge of main (commit c931af5f at 2026-05-07T20:42Z). GitHub PR CI tests the merge-result, which is why both `build-and-test` and `perf-tier1-smoke` are GREEN on tip 6e3bdbc8. **Resolution: merge main into the PR (or rebase) and these failures disappear.**
- **P6 test-pattern violation IS a genuine, PR-introduced issue.** `test_slippage_bps_sell_receives_less` in `test_engine.ml` uses bare `match | Ok` with assertions inside instead of `assert_that result (is_ok_and_holds (...))`. Per `.claude/rules/test-patterns.md` sub-rule 3 / Authority §P6 sub-rule 3, this is a FAIL. The fix is mechanical (~10 LOC).
- **A1 FLAG is correct**: PR touches `trading/trading/engine/`, a core module. The change is a strategy-agnostic cost-overlay knob (default 0 preserves baseline). Generalizability judgment passes — the knob applies uniformly to any strategy that emits orders.

**Net verdict: NEEDS_REWORK.** Narrowed to:
1. P6 test-pattern fix (~10 LOC) on `test_engine.ml::test_slippage_bps_sell_receives_less`.
2. Recommended: merge `main` into the branch so the linter context matches what gets merged.

The agent's full structural checklist below is preserved verbatim for the audit trail; H1/H3/P1 rows are SUPERSEDED by the post-verification above.

---

## Structural Checklist (agent's first pass — preserved for audit)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | FAIL | backtest_runner_args.ml docstring indentation does not conform to ocamlformat |
| H2 | dune build | PASS | Build succeeds (non-fatal warnings about dune-project are expected) |
| H3 | dune runtest | FAIL | Linter failures in dune runtest: (1) file-length linter (pre-existing: screener.ml 708 lines), (2) fn-length linter (this PR: runner.ml line 446 run_backtest is 83 lines, exceeds 50-line limit), (3) nesting linter (pre-existing: 106 functions exceed limits) |
| P1 | Functions ≤ 50 lines — covered by language-specific linter | FAIL | fn-length linter reports run_backtest function at 83 lines (limit 50) in trading/trading/backtest/lib/runner.ml:446 |
| P2 | No magic numbers — covered by language-specific linter | PASS | Magic number linter failures are pre-existing (not introduced by this PR) |
| P3 | All configurable thresholds/periods/weights in config record | PASS | slippage_bps is properly added to engine_config record; default 0 bps preserves baseline |
| P4 | Public-symbol export hygiene — covered by language-specific linter | PASS | .mli coverage linter passed (no new .mli files without proper export) |
| P5 | Internal helpers prefixed per project convention | PASS | New helper _apply_slippage and _apply_slippage_to_fill follow underscore prefix convention |
| P6 | Tests conform to `.claude/rules/test-patterns.md` (presence + conformance) | FAIL | test_engine.ml: test_slippage_bps_sell_receives_less violates P6 sub-rule 3 — uses bare match with `\| Ok [ report ]` followed by assertions inside, instead of wrapping result in `is_ok_and_holds` matcher. Should use `assert_that result (is_ok_and_holds (...))` pattern. CLI tests in test_backtest_runner_args.ml are properly formatted with Matchers library. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) — FLAG if any found | FLAG | PR modifies trading/trading/engine/ (core module per A1 watch-list). Change is strategy-agnostic cost-overlay knob applied uniformly to all fills. Flagged for qc-behavioral generalizability review. |
| A2 | No new `analysis/` imports into `trading/trading/` outside the established backtest exception surface | PASS | No analysis/ imports in dune files; no dependency-direction violations |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Modifications are confined to feature scope: engine/, simulation/, backtest/. No cross-feature drift detected. |

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### H1: Docstring indentation in backtest_runner_args.ml
- Finding: ocamlformat reports incorrect indentation of docstring lines in backtest_runner_args.ml (lines 19-21). The continuation lines should align with the opening of the doc comment, not be over-indented.
- Location: trading/trading/backtest/runner_args/backtest_runner_args.ml, lines 19-21 (slippage_bps field docstring)
- Required fix: Reformat docstring to align continuation lines correctly:
  ```ocaml
  slippage_bps : int option;
      (** [--slippage-bps N], when supplied, applies an explicit basis-points
          slippage at every trade fill — the cost-overlay knob from P4. [None]
          preserves the no-friction baseline (engine default = 0 bps). *)
  ```
  should become:
  ```ocaml
  slippage_bps : int option;
      (** [--slippage-bps N], when supplied, applies an explicit
          basis-points slippage at every trade fill — the cost-overlay knob
          from P4. [None] preserves the no-friction baseline (engine
          default = 0 bps). *)
  ```
- harness_gap: LINTER_CANDIDATE — ocamlformat is deterministic; the dune @fmt rule should catch this. No special review needed once fixed.

### P1: run_backtest function exceeds 50-line hard limit
- Finding: trading/trading/backtest/lib/runner.ml line 446: function `run_backtest` is 83 lines. Hard limit is 50 lines per .claude/rules/ocaml-patterns.md and fn-length-linter enforcement.
- Location: trading/trading/backtest/lib/runner.ml:446-528
- Required fix: Refactor `run_backtest` to extract helper functions. Current structure: (1) _load_deps, (2) _run_panel_backtest, (3) filter/extract steps, (4) compute metrics, (5) build result record. Each step is already a logical unit. Extract (3), (4), (5) into named helpers: `_extract_round_trips_and_audit`, `_compute_final_prices`, `_build_result_record`, then call them from run_backtest. This reduces run_backtest to ~20 lines of orchestration.
- harness_gap: ONGOING_REVIEW — function complexity is hard to encode as a deterministic linter (context matters: is the function orchestrating sub-tasks, or implementing business logic?). Keep this as a QC check.

### P6: test_slippage_bps_sell_receives_less violates test-patterns rule
- Finding: test_engine.ml: `test_slippage_bps_sell_receives_less` (lines ~550–570) uses bare `match process_orders` with `| Ok [ report ]` and assertions inside the match arm, violating P6 sub-rule 3. Pattern:
  ```ocaml
  match process_orders engine order_mgr with
  | Ok [ report ] ->
      let trade = List.hd_exn report.trades in
      assert_that trade.price (float_equal ~epsilon:1e-3 99.9001)
  | _ -> assert_failure "Expected one filled report"
  ```
  Per test-patterns.md, should wrap in `is_ok_and_holds` matcher.
- Location: trading/trading/engine/test/test_engine.ml, test_slippage_bps_sell_receives_less
- Required fix: Refactor to use matcher composition:
  ```ocaml
  let result = process_orders engine order_mgr in
  assert_that result
    (is_ok_and_holds
       (elements_are [
         field (fun report -> List.hd_exn report.trades |> fun trade ->
           field (fun t -> t.price) (float_equal ~epsilon:1e-3 99.9001))
       ]))
  ```
  Or simpler: extract the trade in the test setup and assert on it separately via `is_ok_and_holds` with an inline extractor.
- harness_gap: LINTER_CANDIDATE — the presence of `match ... | Ok` in test files followed by direct assertions (not wrapped in matchers) is greppable and can become a deterministic check in a future dune linter.
