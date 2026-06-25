Reviewed SHA: eb336dcb8327b51e498ec56f3fe2d3fa46a6486d

## Structural QC — optimal-alleligible-snapshot-mode

### Hard Gates

| Gate | Status | Notes |
|------|--------|-------|
| H1: dune build @fmt | PASS | exit 0 |
| H2: dune build | PASS | exit 0 |
| H3: dune runtest | PASS | exit 0; full suite passed, linters clean (fmt, magic-numbers) |

### Pattern & Architecture Checks

| # | Check | Status | Notes |
|---|-------|--------|-------|
| P1 | Functions ≤ 50 lines — covered by language-specific linter (fn_length_linter) | PASS | H2/H3 linter coverage; no fn-length violations reported |
| P2 | No magic numbers — covered by magic-numbers linter | PASS | H2/H3 linter coverage |
| P3 | Config completeness | PASS | No new tunable parameters; PR is diagnostic-runner infrastructure only |
| P4 | Public-symbol export hygiene (.mli coverage) | PASS | H2/H3 linter coverage |
| P5 | Internal helpers prefixed per convention | PASS | All internal helpers use `_` prefix (snapshot_world.ml lines 5–6, 15, 18, 30) |
| P6 | Tests conform to test-patterns rules | PASS | All new test files use `open Matchers` + `assert_that` with matchers; fixture setup helpers use `assert_failure` in non-test contexts (setup phase only); no P6 violations detected |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to core modules; PR touches only `trading/trading/backtest/**` (diagnostic runners + new snapshot_world module) |
| A2 | No new `analysis/` imports into `trading/trading/` outside allow-list | PASS | snapshot_world.ml imports Snapshot_pipeline + Csv_snapshot_builder; both are under `analysis/weinstein/` (allow-listed). Only touched files under `trading/trading/backtest/**` ✓ |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | PR scope verified via `gh pr view 1743 --json files`: 13 files, all under `trading/trading/backtest/**`. Git ancestry diff matches. No cross-feature scope drift detected. |

## Verdict

APPROVED

## Notes

- **snapshot_world**: New shared utility module extracted to avoid code duplication between optimal and all-eligible runners. Interface is clean: `build_callbacks` unifies warehouse-directory and CSV-backed snapshot construction.
- **No core-module changes**: The PR is pure backtest infrastructure; it adds `--snapshot-dir` mode for both runners to consume pre-built warehouse snapshots (e.g., top-3000 universes).
- **Test framework**: test_all_eligible_runner.ml and test_optimal_strategy_runner.ml both use proper test patterns (Matchers + assert_that). Smoke fixtures intentionally flat-priced to avoid drift sensitivity.
- **Architecture**: The `analysis/` imports (Snapshot_pipeline, Csv_snapshot_builder, Daily_panels) are all within the `analysis/weinstein/` allow-list and properly scoped to `trading/trading/backtest/**`.

---

## Behavioral QC — optimal-alleligible-snapshot-mode

Scope: **pure infrastructure / backtest PR**. Touches no Weinstein domain logic
(no stage classifier, stops, screener, buy/sell rules). Per
`.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely",
the entire S*/L*/C*/T* domain block is **NA** (single note below); the review is
the generic Contract-Pinning Checklist (CP1–CP4).

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | New `.mli`s: `snapshot_world.mli` (`build_callbacks` two-mode: warehouse-via-`manifest.sexp` / CSV-build), `default_cache_mb`; `?warehouse_dir` on `optimal_strategy_runner.run`; `warehouse_dir` field on `all_eligible_runner.cli_args`; `~warehouse_dir` on `scenario_post_step.emit`. Claim→test: (a) `cli_args.warehouse_dir` parse=Some → `test_parse_argv_snapshot_dir`; absent=None → `test_parse_argv_snapshot_dir_absent_is_none`; (b) CSV-build path (`warehouse_dir=None`) → every all_eligible + optimal smoke test (`test_run_emits_four_artefacts`, `test_run_emits_optimal_strategy_md`, …); (c) `emit ~warehouse_dir:None` wiring → `test_emit_enabled_writes_four_artefacts`. **Thinness (non-blocking):** the *warehouse-mode* happy path (`warehouse_dir = Some dir` → reads `manifest.sexp` → opens `Daily_panels`) is not exercised by a committed test. Acceptable because (1) the `.mli` is honest about the seam, (2) bar-sourcing is delegated to `Snapshot_manifest.read` + `Daily_panels.create`, already tested upstream (#1626/#1631), and (3) the threading itself is a pure plumb verified by the parse tests + `default_cache_mb` env-knob doc. Recorded as a follow-up. |
| CP2 | Each claim in PR body "Test" section has a corresponding committed test | PASS | PR-body claims: "Default (no flag) = unchanged build-from-CSV path; bit-identical to today" → preserved-behavior covered by the unchanged all_eligible/optimal smoke tests passing under `warehouse_dir=None` (full artefact-shape assertions, not bare counts). "New parser tests pin `--snapshot-dir` → Some / absent → None" → literally satisfied by `test_parse_argv_snapshot_dir` + `test_parse_argv_snapshot_dir_absent_is_none` (all_eligible). **Note:** the symmetric `--snapshot-dir` addition to the *optimal* binary's private `_parse_args` (`optimal_strategy.ml`) has no dedicated parser test (the bin parser isn't exposed). Not an advertised-but-missing test — the body's parser claim maps to the all_eligible tests that exist; flagged as a coverage gap, not a CP2 FAIL. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size_is | PASS | The load-bearing invariant is "default path bit-identical to today." The preserved smoke tests assert artefact *content/shape* — four-artefact existence, `summary.md` header + aggregate rows, `trades.csv` exact header line + `size_is 1`, `summary.sexp`/`config.sexp` field-level round-trips — not bare element counts. The `warehouse_dir=None` threading leaves these green, pinning the no-op. |
| CP4 | Each guard in code docstrings has a test exercising the guarded scenario | PASS | `scenario_post_step.mli` documents failure-isolation (runner failure logged + swallowed, never raised) → `test_emit_swallows_runner_failure` (bogus scenario path → asserts no raise). `emit enabled=false` no-op guard → `test_emit_disabled_creates_no_subdir`. **Thinness (non-blocking):** `snapshot_world._load_warehouse` "Raises Failure if the warehouse manifest can't be read" is not tested (defensive failwith on a corrupt/absent manifest); classified ONGOING_REVIEW. |

### Behavioral Checklist (Weinstein domain)

NA — pure infra / backtest diagnostic-runner data-source seam; domain checklist
(S*/L*/C*/T*) not applicable. No stage/stop/screener/buy-sell logic touched.

## Quality Score

4 — Clean, well-documented data-source seam with honest `.mli` contracts and full no-op-preservation coverage; only minor test thinness (warehouse-mode happy path + optimal-bin parser untested), both delegated to already-tested upstream code.

## Verdict

APPROVED

## Follow-ups (non-blocking)

- Add a warehouse-mode smoke test: stage a tiny snapshot warehouse (`manifest.sexp` + one panel) and assert `Snapshot_world.build_callbacks ~warehouse_dir:(Some dir) …` (or the runner with `--snapshot-dir`) opens it and emits artefacts. Pins the one genuinely-new path. harness_gap: LINTER_CANDIDATE — a golden warehouse fixture makes this deterministic.
- Add a parser test for `optimal_strategy.exe --snapshot-dir` (or expose `_parse_args`) so the optimal-side flag is pinned symmetrically with the all_eligible side. harness_gap: ONGOING_REVIEW.
