Reviewed SHA: 70ab3af9f62092c9de74f41ce02e1294fbd00a4f

# Behavioral QC (re-review v2) — pr-1019-simulator-nav-fallback
Date: 2026-05-10
Reviewer: qc-behavioral

PR: https://github.com/dayfine/trading/pull/1019
Title: fix(simulation): cache + avg-cost fallback in _resolve_price
Branch: fix/simulator-nav-fallback
Commits reviewed: 75cdda6b (original NAV fix) + 70ab3af9 ("Apply review: fix linter regressions in simulator.ml")
Files changed (vs merge-base 9b3d17f6):
  - trading/trading/simulation/lib/dune (+1)
  - trading/trading/simulation/lib/portfolio_state_computer.ml (+11/-8 docstring update)
  - trading/trading/simulation/lib/portfolio_valuation.ml (NEW, 87 lines)
  - trading/trading/simulation/lib/portfolio_valuation.mli (NEW, 45 lines)
  - trading/trading/simulation/lib/simulator.ml (+47/-71 → 436 lines, was 516)

Classification: **Infrastructure / library** (pure simulator-correctness change). Per
`.claude/rules/qc-behavioral-authority.md`, the S*/L*/C*/T* domain block does not
apply — only CP1–CP4 contract pinning.

Prior review: `pr-1019-simulator-nav-fallback-behavioral.md` (NEEDS_REWORK at
75cdda6b due to three dune-wired linter regressions surfaced by CI: function
length on `_process_step_day` 51>50, file length on simulator.ml 516>500,
nesting on `_resolve_price` avg=3.17/max=7). The follow-up commit 70ab3af9
addresses these by extracting valuation logic into a dedicated
`Portfolio_valuation` module and extracting `_build_step_result` from
`_process_step_day`.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PARTIAL | A new `.mli` was added (`portfolio_valuation.mli`). Its primary contract is the four-tier resolution chain: (1) today's bars, (2) `Market_data_adapter.get_previous_bar`, (3) `last_known_prices` cache, (4) avg-cost. The chain claims `compute` "always returns a finite value" and "the legacy cash-only fallback should not fire". Tier (1) and tier (2) are pinned by `test_forward_fill_uses_last_known_close_when_held_symbol_has_no_bar` (test_simulator.ml:817–866) — same test that pinned the pre-extraction implementation; logic moved verbatim into `Portfolio_valuation.compute`, so the existing pin still covers tier (2). Tiers (3) cache and (4) avg-cost remain unpinned by dedicated unit tests. The cache update via `_update_cache_with_today_bars` (newly factored as a separate helper) is also unpinned. The .mli's "increments [valuation_failure_count] exactly once per (symbol, step) pair that fell through to the avg-cost last-resort" claim is unpinned. Recorded as a non-blocking FLAG below — same judgment call as v1, per the user's brief. |
| CP2 | Each claim in PR body "Test plan" / "Test coverage" sections has a corresponding green test in CI | PASS | PR body's Test plan: "[x] `dune build` clean (no errors)" — verified locally inside docker. "[x] `dune runtest trading/simulation/` — all green" — verified locally inside docker (no diff output, all simulation tests pass including the dune-wired `fn_length_linter`, `linter_magic_numbers.sh`, `linter_mli_coverage.sh`, and `nesting_linter`). "[x] dune runtest trading/orders/ trading/engine/ trading/portfolio/ trading/strategy/ trading/backtest/ — all green" — covered by CI. CI status at 70ab3af9: `build-and-test` COMPLETED SUCCESS (workflow run 25628987441), `perf-tier1-smoke` COMPLETED SUCCESS. The remaining unchecked item ("Re-run Cell E 15y backtest — expect equity_curve.csv to match reconstructed_equity_curve.csv") is explicitly marked "tracked separately" by the author. Three previously-failing linter rows (function length / file length / nesting) are now PASS — directly verifiable: simulator.ml=436 lines (was 516), `_process_step_day`=37 lines (was 51), `_resolve_price` extracted into `portfolio_valuation.ml` and now uses `Option.first_some` to flatten the previously-nested fallback chain. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size | NA | This PR introduces a value-resolution chain, not pass-through semantics. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PARTIAL | Same posture as v1 with one improvement: the docstring claim "the legacy `Error _ -> portfolio.current_cash` survives only as defense-in-depth" remains by-construction unreachable (acceptable). The named-and-described scenarios for the cache tier ("held symbols whose bar dataset has gaps the adapter cannot reach — M&A delisting, dataset edges, survivor-bias purges") and the avg-cost tier ("zero-unrealized assumption — last resort when no market price has ever been seen") are still not pinned by dedicated unit tests. The new `valuation_failure_count` invariant ("incremented exactly once per (symbol, step) pair that fell through to avg-cost") is also not pinned. Treated as FLAG, not FAIL — per the user's brief: empirical Cell E 15y reconstruction is doing the end-to-end validation, deferred to a follow-up unit-test PR. harness_gap: LINTER_CANDIDATE. |

## Behavioral Checklist

Pure infra / simulator-correctness PR; domain checklist (S*/L*/C*/T*) not applicable.

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | No core-module modification: only `trading/trading/simulation/lib/` files touched (+ a one-line dune entry). The Portfolio/Orders/Position/Strategy/Engine modules are untouched. |
| S1–S6 | Stage definitions / buy criteria | NA | Pure infra / simulator-correctness PR; domain checklist not applicable. |
| L1–L4 | Stop-loss rules | NA | Pure infra / simulator-correctness PR; domain checklist not applicable. |
| C1–C3 | Screener cascade | NA | Pure infra / simulator-correctness PR; domain checklist not applicable. |
| T1–T4 | Domain test coverage | NA | Pure infra / simulator-correctness PR; domain checklist not applicable. |

## Verification notes (what I checked and how)

1. Re-fetched `origin/fix/simulator-nav-fallback` and pinned the review at tip
   SHA `70ab3af9f62092c9de74f41ce02e1294fbd00a4f`.
2. Read both new files (`portfolio_valuation.ml`, `portfolio_valuation.mli`)
   end-to-end. The four-tier chain in the .mli docstring matches the
   implementation:
   - `_update_cache_with_today_bars` (tier 1 prefilling)
   - `_from_adapter` (tier 2)
   - `_from_cache` (tier 3)
   - `_from_avg_cost` (tier 4 — increments `valuation_failure_count`,
     uses `Trading_portfolio.Calculations.avg_cost_of_position`)
   `_resolve_price` composes tiers 2+3 via `Option.first_some` and falls
   through to tier 4 only when both return `None`. The
   `Trading_portfolio.Calculations.avg_cost_of_position` symbol exists
   (`trading/trading/portfolio/lib/calculations.ml:10`).
3. Read `simulator.ml` diff (+47/-71): the entire `_compute_portfolio_value`
   /`_prices_for_held_positions`/`_fallback_price_for_position` block is
   removed; the call site in `_process_step_day` now invokes
   `Portfolio_valuation.compute` with the new `~last_known_prices` and
   `~valuation_failure_count` parameters threaded from the simulator state.
   `_build_step_result` is extracted from `_process_step_day` (mirrors the
   PR body's claim "extracts `_build_step_result` from `_process_step_day`").
4. Verified field lifetimes on `t`: `last_known_prices : float String.Table.t`
   (mutable hashtable) and `valuation_failure_count : int ref` are both shared
   by reference across `{ t with ... }` per-step copies — confirmed by reading
   `_advance_step` and the `create` initializer (allocated once at
   `String.Table.create ()` / `ref 0`, never copied). The .mli claim
   "Reference-shared across all per-step copies" is correct.
5. Read the existing pin
   `test_forward_fill_uses_last_known_close_when_held_symbol_has_no_bar`
   (`test_simulator.ml:817–866`). Test setup: AAPL has bars on Jan 2 + Jan 3
   only; on Jan 4 the broker still holds 10 shares with no bar today;
   `portfolio_value` must equal `cash_after_buy + 10*157.0`. This still
   exercises tier (2) of the new chain (adapter `get_previous_bar` returns
   `Some`). Plus an additional bug-path floor pin (`gt cash_after_buy + 100`)
   that would also catch a regression of the cache tier in the same fixture.
6. Read `portfolio_state_computer.ml` diff: only docstring updates on the
   `last_marked_step` field and the `_is_marked_to_market` heuristic, both
   correctly reflecting the new fallback chain. No behavior change.
7. Local rebuild inside docker:
   ```
   docker exec trading-1-dev bash -c \
     'cd /workspaces/trading-1/trading && eval $(opam env) && dune build'
   # → BUILD OK (only the no-dune-project-in-cwd warning)
   docker exec trading-1-dev bash -c \
     'cd /workspaces/trading-1/trading && eval $(opam env) && \
      dune runtest trading/simulation/'
   # → exit 0, no test failures, no linter regressions
   ```
   The previously-failing linter rows from v1 (function length, file length,
   nesting) are all green.
8. CI status at tip 70ab3af9 (`gh pr view 1019 --json statusCheckRollup`):
   - `build-and-test` (workflow run 25628987441): COMPLETED, SUCCESS
   - `perf-tier1-smoke` (workflow run 25628987439): COMPLETED, SUCCESS
9. `dune build @fmt` reports residual diffs only in files NOT touched by this
   PR (e.g. `analysis/weinstein/stage/lib/stage.mli`,
   `trading/data_panel/atr_kernel.mli`, etc.) — pre-existing
   container-vs-CI ocamlformat skew on docstring `{[ ]}` indent (per memory
   `project_ocamlformat_version_skew.md`). Not a regression introduced by
   this PR.

## Quality Score

4 — Logic of the fallback chain is sound and well-documented; the four-tier
resolver is the right shape; the rework cleanly extracts the valuation logic
into a dedicated module with its own .mli, which improves modularity beyond
what would have been achieved by inline annotations. Score is held at 4 (not
5) because the cache + avg-cost tiers — the very tiers added by this PR —
are still not pinned by dedicated unit tests; the existing forward-fill test
covers tier (2) but not tiers (3) or (4). The user's brief explicitly accepts
this gap as a non-blocking FLAG, with the empirical 15y Cell E reconstruction
serving as end-to-end validation.

## Verdict

APPROVED

(Mechanical: CP2 = PASS, CP1/CP4 = PARTIAL but recorded as FLAG per the
reviewer brief, not FAIL. CP3 = NA. All applicable items are PASS or NA-with-FLAG.
The three blocking linter regressions from v1 are resolved.)

## Non-blocking FLAGs (do not block merge)

### FLAG: cache + avg-cost tiers lack dedicated test pins
- Finding: The cache fallback (tier 3) and avg-cost fallback (tier 4) of
  `Portfolio_valuation._resolve_price` are not exercised by any unit test.
  Only tier 2 (`get_previous_bar` returning `Some`) is pinned, by
  `test_forward_fill_uses_last_known_close_when_held_symbol_has_no_bar`.
  The `valuation_failure_count`-incremented-exactly-once invariant from the
  .mli docstring is also unpinned.
- Location: `trading/trading/simulation/lib/portfolio_valuation.ml:19–21`
  (`_from_cache`), `:24–28` (`_from_avg_cost`).
- Authority: `portfolio_valuation.mli` lines 9–13 (the four-tier chain
  contract) and lines 38–40 (the failure-count invariant).
- Recommended follow-up (non-blocking):
  1. Cache-tier test — fixture where a symbol has bars on day 1, no bars
     for day 2 onward, and `get_previous_bar` returns `None` after day N.
     Assert `portfolio_value` uses the cached close from day 1 on day N+1
     and `valuation_failure_count` stays at 0.
  2. Avg-cost-tier test — same setup but with the cache empty for the
     symbol. Assert `valuation_failure_count` increments by exactly 1 and
     `portfolio_value` equals `cash + qty × avg_cost`.
- harness_gap: LINTER_CANDIDATE — both tiers can be deterministically pinned
  with a synthetic fixture (no real-data dependency). Empirical Cell E 15y
  reconstruction at `dev/experiments/cell-e-15y-2026-05-09/` is the
  end-to-end validation in the meantime.

### Note: Cell E 15y reconstruction parity tracked separately
- The PR body's expected `equity_curve.csv` parity with
  `reconstructed_equity_curve.csv` from `dev/experiments/cell-e-15y-2026-05-09/`
  is explicitly tracked as a separate validation step. Not a behavioral
  blocker for this PR — but if that re-run shows a divergence, the
  follow-up unit tests above become higher-priority.
