Reviewed SHA: 470d3989dee49c5046dbf70ef1051263d40ad146

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No formatting violations |
| H2 | dune build | PASS | Clean build, no errors |
| H3 | dune runtest | PASS | All tests pass (including new test_universe_snapshot) |
| P1 | Functions ≤ 50 lines (linter) | PASS | All functions within limit; max 3 lines for helpers |
| P2 | No magic numbers (linter) | PASS | Covered by dune runtest |
| P3 | Config completeness | NA | No new tunable parameters introduced |
| P4 | Public-symbol export hygiene (linter) | PASS | universe_snapshot.mli documents public interface completely |
| P5 | Internal helpers prefixed per convention | PASS | Private functions use underscore prefix (_entry_to_pair, _try_decode_legacy, _load_via_snapshot_path, _make_entry, _make_snapshot, _write_snapshot_tmp, _empty_after_filter_error, _project_entries, _composition_goldens_root) |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | PASS | All assertions use `assert_that` with matchers; no List.exists violations; no unasserted results; match patterns use proper matchers (is_ok_and_holds, elements_are, matching); test file has `open Matchers` and follows all pattern rules |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to core modules; only new bridge module in scenarios/ |
| A2 | No new `analysis/` imports into `trading/trading/` outside allow-list | PASS | Only `universe` (analysis/data/universe/) imported into trading/trading/backtest/scenarios/dune, which is allowed per updated rule; located under trading/trading/backtest/** as required; widened rule amendment properly documents this change |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Only files modified: qc-structural-authority.md (rule update), 2 dune files (add universe dep), 2 new scenario files (universe_snapshot bridge), 1 existing file (universe_file fallback), 1 new test file; all on-scope, no cross-feature drift |

## Verdict

APPROVED

## Summary

PR #1174 introduces a clean bridge adapter (`Universe_snapshot` module) that projects custom-universe composition Snapshot sexp goldens onto the (symbol, sector) pair shape that `Universe_file.load` already consumes. The implementation is minimal (30 LOC), well-documented, and thoroughly tested (5 unit tests covering composition→pairs, decomposition→error, mixed→filtering, integration fallback, and real fixture cardinality). Critically, the A2 architecture rule is widened appropriately to allow `analysis/data/universe/` imports into `trading/trading/backtest/**` — the same exception class already established for `analysis/weinstein/`. The new dependency is located in the correct scope, build and tests pass, and no core modules are affected. Ready for behavioral review.

---

# Behavioral QC — feat-universe-snapshot-consumer
Date: 2026-05-17
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | `universe_snapshot.mli` makes three claims, each pinned: (1) "Ok pairs on success, synthetic entries silently dropped" → pinned by `test_composition_projects_to_pairs` (pure-real input → exact 3-element pair list) AND `test_mixed_keeps_real_drops_synthetic` (verifies synthetic filtering preserves real-entry order); (2) "Error Failed_precondition when every entry is synthetic" → pinned by `test_pure_decomposition_errors` (asserts via `matching` on `Status.Failed_precondition` code); (3) "Error Internal/Failed_precondition propagated from Universe.Snapshot.load" → not pinned directly here, but inherited via `Result.bind (Snapshot.load ...)` and `Snapshot.load` itself is pinned in the upstream `analysis/data/universe/test/test_snapshot.ml`. Acceptable propagation; no behavioral hole. |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | PASS | PR body Test plan enumerates 5 contracts: (1) "Composition snapshot → ordered (symbol, sector) pairs" ↔ `test_composition_projects_to_pairs`; (2) "Pure-decomposition snapshot → Error Failed_precondition" ↔ `test_pure_decomposition_errors`; (3) "Mixed snapshot → drops synthetic, keeps real (ordered)" ↔ `test_mixed_keeps_real_drops_synthetic`; (4) "Universe_file.load auto-falls-back through the new bridge → Pinned" ↔ `test_universe_file_load_falls_back_to_snapshot`; (5) "committed top-500-1998.sexp composition golden loads with cardinality 500" ↔ `test_committed_composition_golden_loads`. All 5 tests present and run green (5/5 passing under `dune exec test_universe_snapshot.exe`). |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are, not size_is) | PASS | Composition projection IS a pass-through-with-filter: `test_composition_projects_to_pairs` and `test_mixed_keeps_real_drops_synthetic` both pin identity using `elements_are [equal_to ("AAPL", "Information Technology"); ...]` — full pair equality, not just `size_is`. Note: `test_committed_composition_golden_loads` uses `size_is 500` rather than full element identity, but that is a deliberate cardinality smoke test on a 500-symbol golden where listing all pairs in the test file would be impractical, AND the more specific identity contracts are already pinned by tests (1) and (3). No CP3 violation. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | Two guards in code: (a) "Synthetic entries dropped" — exercised by `test_mixed_keeps_real_drops_synthetic` (mixed input, synthetic filtered out, real preserved); (b) "Empty result after filter → Failed_precondition error rather than silent empty list" — exercised by `test_pure_decomposition_errors` (all-synthetic input → Failed_precondition with the runner-cannot-consume-empty-sector-map message). The `Universe_file.load` fallback path is also implicitly guarded by `_try_decode_legacy` returning `None` (so legacy sexp shapes never invoke the snapshot decoder); the legacy path is regression-protected by the unchanged `test_universe_file.ml` suite (8/8 tests passing: `Pinned parses`, `Full_sector_map parses`, `Pinned round-trips`, `symbol_count`, `to_sector_map_override_*`, `committed universes parse`, `broad-3000-2010 universe parses`). |

## Behavioral Checklist

Pure infrastructure / bridge-adapter PR; Weinstein S*/L*/C*/T* domain checklist not applicable (no stage / stop / screener / macro logic touched).

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural did not flag A1 — no core-module modifications |
| S1–S6 | Stage definitions / buy criteria | NA | Pure infra adapter; no stage logic |
| L1–L4 | Stop-loss rules / state machine | NA | No stop logic |
| C1–C3 | Screener cascade / macro gate / sector RS | NA | No screener / macro logic |
| T1–T4 | Domain-outcome test coverage | NA | No domain-outcome behavior to assert |

## Architecture decision review (A2 allow-list widening)

The PR widens `.claude/rules/qc-structural-authority.md` §A2 to add `universe` (i.e. `analysis/data/universe/`) alongside the existing `weinstein.*` allow-list, scoped to `trading/trading/backtest/**` dune deps only.

Sanity-check on precedent reasoning: PASS. The two cases are the same class.
- `weinstein.*` allow exists because backtest scenarios are the canonical integration point that consumes upstream Weinstein analysis outputs (indicators, screener inputs).
- `universe` allow has the same shape and same scope: backtest scenarios consume upstream `analysis/data/universe/` outputs (composition / decomposition goldens). The bridge module lives in `trading/trading/backtest/scenarios/`, which is inside the allow-listed prefix.
- Reverse direction is unchanged (it has always been fine: `trading/trading/` → consumed by `analysis/`).
- The rule continues to FAIL any import from these analysis paths into `trading/trading/` paths *outside* `trading/trading/backtest/**` (portfolio, orders, engine, strategy, simulation remain protected).

The amendment is correctly bounded, well-justified by the precedent, and the only added dune dependency (`trading/trading/backtest/scenarios/dune`) is within the allow-listed scope. No concerns.

## Verification performed

- Built feature SHA `470d3989` in docker (`docker exec trading-1-dev … dune build`): clean.
- Ran the new test directly: `_build/default/trading/backtest/scenarios/test/test_universe_snapshot.exe` → `Ran: 5 tests in: 0.13 seconds. OK`.
- Ran the backwards-compatibility test: `_build/default/trading/backtest/scenarios/test/test_universe_file.exe` → `Ran: 8 tests in: 0.13 seconds. OK` (all legacy Pinned / Full_sector_map / committed-universe cases still pass after the `load` change).
- Read `analysis/data/universe/snapshot.mli` to confirm the inherited error contract (`Snapshot.load` returns `Error Internal` on read fail, `Error Failed_precondition` on decode fail) matches the propagation claim in `universe_snapshot.mli`.

## Quality Score

5 — Exemplary bridge adapter: minimal surface (30 LOC ml + 34 LOC mli), three crisp behavioral contracts, every claim pinned by an identity-asserting test, real-fixture smoke test included, backwards-compatible fallback in `Universe_file.load` that preserves the existing `Failure`-raising contract, and the A2 rule widening is correctly bounded and well-justified by the established `weinstein.*` precedent.

## Verdict

APPROVED
