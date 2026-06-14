# Structural QC Review — sweep-perf Win #4 production wiring

Reviewed SHA: 45a04508f1fc577f95d125c987f87fb9c4de4b8e

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | 42 existing tests passing; 3 new tests in test_panel_runner_active_through.ml all passing |
| P1 | Functions ≤ 50 lines (linter) | PASS | All new/modified functions are single-purpose helpers; no violations |
| P2 | No magic numbers (linter) | PASS | Linter clean as part of H3 |
| P3 | Config completeness | PASS | The new `?prune_universe_by_active_through:bool` parameter is already configurable via the panel runner's public interface; no hardcoded thresholds introduced |
| P4 | Public-symbol export hygiene (linter) | PASS | Both new public symbols (`Panel_runner.fold_start_date_of_opt_in`, `?prune_universe_by_active_through` parameter) are properly documented in .mli with full contract descriptions |
| P5 | Internal helpers prefixed per convention | PASS | New internal helpers follow the `_` prefix convention: `_active_through_for_of_panels`, `_build_sim` |
| P6 | Tests conform to test-patterns rules | PASS | New test file `test_panel_runner_active_through.ml` opens `Matchers`, uses `assert_that` + matchers composition (`is_none`, `is_some_and`, `equal_to`); no bare `List.exists`, no `let _ =`, no nested `assert_that` or `match...assert_failure` patterns |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | NA | No core modules touched; work is confined to backtest/panel layer |
| A2 | No new `analysis/` imports into `trading/trading/` outside allow-list | PASS | One dune change (backtest/test): adds `test_panel_runner_active_through` test target only; no new library imports. All changes under `trading/trading/backtest/` remain within bounds |
| A3 | No unnecessary modifications to existing modules | PASS | File list via git diff: 7 files changed (dev/status/sweep-perf.md, panel_runner.ml, panel_runner.mli, panel_strategy_builder.ml, panel_strategy_builder.mli, test/dune, new test file). All changes are load-bearing: panel_runner.ml/mli add the flag + helpers, panel_strategy_builder.ml/mli thread the fold_start_date parameter to the screener, test/dune registers the new test. No drift observed |

## Experiment-flag discipline checklist (R1–R3)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| R1 | Default-off invariant | PASS | `?prune_universe_by_active_through:bool` defaults to `false` (line 296, panel_runner.ml); `false` resolves to `fold_start_date = None` which disables pruning on both surfaces. Behaviour is bit-identical to pre-PR: same universe classification, same bar-fetch loop, no golden changes needed. Authority: experiment-flag-discipline.md R1 |
| R2 | Mechanism is a config axis | PASS | The flag is a real `Panel_runner.run` parameter, exposed + documented in the .mli. Callers can set it `true` or `false`. Pure helper `fold_start_date_of_opt_in` pins the flag→cutoff mapping and is exposed for tests. Authority: experiment-flag-discipline.md R2 |
| R3 | Promotion requires ledger ACCEPT | NA | The mechanism adds the production opt-in surface; no default-flipping occurs in this PR. The flag lands default-off. If a future PR flips the default, that PR must cite a ledger ACCEPT. Authority: experiment-flag-discipline.md R3 |

## Code-health judgment (P6 marker on panel_runner.ml)

**Finding:** File grew from ~300 lines (pre-PR) to 341 lines. Author marked it `@large-module`.

**Judgment:** **JUSTIFIED**. The module is the canonical single backtest execution pipeline with fixed sequential reading order: snapshot source resolution → 3-surface hybrid fan-out (strategy bar reader + simulator adapter + final-close lookup over one Daily_panels.t) → cost overlay → simulator construction → step loop → teardown. Fragmenting it would harm per-cycle reading order. Sibling `runner.ml` (493 lines) carries the same marker for the same reason. The new 41 lines are integral to this flow (fold_start_date resolution, active_through_for threading through the hybrid setup). No extraction candidate identified that doesn't violate the sequential-order principle.

**Per code-health-discipline.md:** the marker is correct; no limit bump required; no extraction needed.

## Verdict

**APPROVED**

No structural or mechanical blockers. All build gates pass. The default-off invariant is pinned. The flag routes through public parameters and can be surfaced as an experiment axis. Test patterns conform. No core module modifications; no boundary violations.

Quality score: **5** — clean, well-documented, experiment-flag-compliant, test coverage of the opt-in contract is explicit.

---

# Behavioral QC Review — sweep-perf Win #4 production wiring

Reviewed SHA: 45a04508f1fc577f95d125c987f87fb9c4de4b8e

Classification: **pure backtest-infrastructure PR** (runner parameter plumbing under `trading/trading/backtest/`). Touches no Weinstein domain logic — stage classifier, screener rules, stops, macro/sector gating are all unchanged. The Weinstein domain checklist (S*/L*/C*/T*) is therefore NA; the review is the generic Contract Pinning Checklist CP1–CP4 plus the experiment-flag (R1–R3) and Weinstein-spine (W1) rows.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | (1) `fold_start_date_of_opt_in`: `false → None` → `test_opt_in_off_yields_no_cutoff`; `true → Some start_date` → `test_opt_in_on_yields_fold_start_cutoff`. (2) `run`'s `?prune_universe_by_active_through` "ON ⇒ screener pre-prunes before Phase-1" → `test_opt_in_on_prunes_pre_fold_delisted_from_classification`, asserting via the production `Weinstein_strategy.prune_universe_by_active_through` fed by `active_through_for` read off `Bar_reader.snapshot_callbacks` — the EXACT derivation in `Weinstein_strategy_macro._prune_args_of` (verified ml lines 88–90). (3) `run`'s "simulator-side bar-fetch prune fires" claim → pinned by existing #1318 `test_simulator.ml` (`test_create_with_active_through_for_prunes_pre_fold_delisted`, `test_create_without_active_through_for_preserves_symbols`); this PR's `_active_through_for_of_panels` is a thin `Daily_panels.active_through_for` adapter onto that already-tested `Simulator.create` path. (4) `panel_strategy_builder.build`'s `?fold_start_date` forwards to the pre-existing tested `Weinstein_strategy.make ?fold_start_date`. |
| CP2 | Each claim in PR body "Test plan" has a corresponding committed test | PASS | PR body advertises 3 cases in `test_panel_runner_active_through.ml`: (1) flag false→None, (2) flag true→Some start_date, (3) opt-in ON ⇒ strictly fewer symbols reach Phase-1 on a 3-symbol/1998-fold fixture with one 1996 `active_through`. All three exist and run green (`Ran: 3 tests ... OK`). No advertised-but-absent test. |
| CP3 | Pass-through / identity invariant pinned by identity, not size | PASS | The load-bearing default-off identity is `false → None` (no pruning → bit-equal), pinned by `assert_that cutoff is_none` and `is_some_and (equal_to start_date)` — value identity, not a count. The acceptance test asserts the whole pruned list `(3, ["LIVE_A"; "LIVE_B"])` via `equal_to`, pinning element identity not just size. |
| CP4 | Each guard in code docstrings has a test exercising the guarded scenario | PASS | The survivor-bias guard — keep symbols with `active_through = None` and those with `active_through >= fold_start`, drop only strictly-pre-fold delistings — is exercised: the acceptance fixture has two `None`-marker live symbols (kept) and one `Some 1996-06-28` symbol with a 1998 fold (dropped). The predicate under test (`weinstein_strategy_screening.ml:268`, `Core.Date.(<=) fold_start_date d`) is the production predicate, so the point-in-time/not-survivor-bias guard is non-vacuously pinned. |

## Experiment-flag + Weinstein-spine rows

| # | Check | Status | Notes |
|---|-------|--------|-------|
| R1 | Default-off on merge (bit-equal) | PASS | `?(prune_universe_by_active_through = false)` (panel_runner.ml:296) → `fold_start_date = None` → `_active_through_for_of_panels` returns `None` (no simulator prune) and no `?fold_start_date` reaches the screener. Bit-identical to pre-Win-#4; existing parity/golden tests replay unchanged. experiment-flag-discipline.md R1. |
| R2 | Searchable as a config axis | NA | This is a runner perf opt-in (point-in-time universe pre-prune of uninvestable symbols), NOT a strategy mechanism that alters backtest results. Default-off it is bit-equal, so it is not subject to R2's "must be a `Weinstein_strategy.config` field / Variant_matrix axis" — there is no result to search over. Infra plumbing, correctly a `run` parameter. |
| R3 | Promotion needs a ledger ACCEPT | NA | No default flipped; lands default-off. A future PR that turns this on for production sweeps changes no backtest *result* (only runtime), so it does not require a strategy-ledger ACCEPT — but it must preserve the point-in-time cutoff so it stays survivor-bias-free. |
| W1 | Weinstein spine intact | PASS | No spine item (stage classification, Stage-2-only buys, breakout+volume entry, Stage-3/4 sells, stop placement, macro/sector gate, RS selection) is touched. The change drops only symbols genuinely uninvestable at the fold start (pre-IPO / already-delisted), which the strategy could never have traded — it cannot alter any signal on any tradeable symbol. weinstein-faithful-core.md §spine. |

## Behavioral Checklist (Weinstein domain)

NA — pure backtest-infrastructure / runner-plumbing PR; touches no stage classifier, screener rules, stops, or macro/sector logic. Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely", the entire S*/L*/C*/T* block is not applicable.

## Quality Score

5 — Every documented contract is pinned to a test; the acceptance test reuses the EXACT production derivation (`Bar_reader.snapshot_callbacks` → `prune_universe_by_active_through`, mirroring `_prune_args_of`), so it is non-vacuous and cannot pass under a no-op prune. Default-off bit-equality and the point-in-time/not-survivor-bias guard are both explicitly pinned by value, not size.

## Verdict

APPROVED
