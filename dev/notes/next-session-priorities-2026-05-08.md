# Next-session priorities — 2026-05-08

## Yesterday→today's progress (session ending early AM 2026-05-08)

**17 PRs admin-merged** (cleanup + harness):
- #935-942, #944-951 — nesting cleanup batch (15 PRs)
- #943 — **harness: dune dep tracking fix** — every linter rule now globs `.ml`/`.mli`/`.sh` so `dune runtest` correctly invalidates on source change. Was root cause of #919.
- #946 — **harness: sweep_stale_worktrees lock-honoring** — refuses removal of git-locked worktrees; rejects `--stale-hours 0`; smoke-test wired to `dune runtest`.

**Linter delta (vs session start):**
- nesting fn-violations: 97 → 69 (28% reduction)
- nesting file-avg violations: 9 → **0** ✓
- file_length: now visible (was cache-hidden)
- fn_length: now visible
- magic_numbers: now visible (mostly false positives in comment bodies)

## Current main state (red CI, but make all 4 green)

```
$ dune runtest

FAIL: file length linter:
  trading/weinstein/strategy/lib/entry_audit_capture.ml: 305 (limit 300)
  trading/weinstein/strategy/lib/weinstein_strategy.ml: 872 (declared-large hard limit 500)
  trading/backtest/optimal/lib/optimal_strategy_runner.ml: 413 (limit 300)
  trading/backtest/optimal/lib/optimal_strategy_report.ml: 488 (limit 300)
  trading/backtest/lib/result_writer.ml: 372 (limit 300)
  trading/engine/lib/price_path.ml: 511 (declared-large hard limit 500)

FAIL: function length linter:
  trading/simulation/lib/simulator.ml:354: 'step' = 63
  trading/weinstein/strategy/lib/weinstein_strategy.ml:585: '_on_market_close' = 216 ⚠
  trading/weinstein/strategy/lib/weinstein_strategy.ml:802: 'make' = 61

FAIL: nesting linter — 69 fns, 0 file-avg

FAIL: magic number linter — bare numerics in comment bodies (multi-line comment tracking absent)
```

## Priorities

**P0 — fix magic-numbers linter false positives.** Vast majority of magic-number violations are bare numerics in **comment body lines** (multi-line comments where the opening `(*` is on a previous line). Linter only skips lines containing `(*` or `*)`. Fix: track multi-line comment depth across `while read line` loop. Patch was in flight earlier in session but uncommitted; re-apply.

**P1 — split weinstein_strategy.ml.** 872 LOC + `_on_market_close` 216 lines. Per memory `feedback_no_deferred_codehealth.md` and `feedback_no_pr_merging.md`, NO `@large-module` markers, NO bumping limits. Extract `_on_market_close` phases into a separate `weinstein_strategy_phases.ml` module. Likely splits cleanly: candidate generation phase, transition phase, audit phase.

**P2 — split optimal_strategy_report.ml (488).** Likely several report-section helpers can lift into a `optimal_strategy_report_sections_<name>.ml`.

**P3 — split optimal_strategy_runner.ml (413).** Friday/scan helpers candidate for extract.

**P4 — split result_writer.ml (372).** Per-CSV writers candidate for extract.

**P5 — split price_path.ml (511 / declared-large 500).** 11 LOC over hard limit; trim or extract one helper module.

**P6 — entry_audit_capture.ml (305 / limit 300).** 5 over; trivial extract or condense.

**P7 — fn_length: simulator.ml step (63), weinstein_strategy make (61).** Both modest extracts.

**P8 — nesting: 69 remaining fns.** Top files (by # violations or impact):
- snapshot_bar_views.ml — 5 fns + nested-else
- snapshot_format.ml — 4 fns
- round_trip_verifier.ml — 3 `_check_*` fns
- all_eligible_runner.ml — 3 fns
- screener.ml — `_evaluate_longs/_evaluate_shorts` (twin)
- laggard_rotation_runner.ml — 2 fns
- antifragility_computer.ml, distributional_computer.ml, return_basics_computer.ml
- order_generator.ml `transitions_to_orders`
- runner.ml, result_writer.ml — multiple
- many smaller files (single-fn)

**P9 — unblocks #920 + #921** automatically once main goes green.

## Workflow notes

- Subagent watchdog stalls (600s no-progress) hit 6 cleanup agents in parallel and 1 serial in the closing hours of the session — container itself looks healthy (load 2.7, 12% disk, 20% mem). Probably subagent infra hiccup. **Fall back to direct main-thread work** if stalls recur, OR rate-limit to 1-2 agents at a time.
- Container sync drops untracked files in working tree; commit notes-files via jj before stash/checkout.
- Memory entries that govern this work: `feedback_cleanup_local_lint_then_merge.md` (admin-merge cleanup PRs, batch CI), `feedback_no_deferred_codehealth.md` (no @large-module workarounds), `feedback_pr_merge_gates.md` (cleanups exempt from full 3-gate; features still need them).

## Blocked features (queued behind green CI)

- #920 — feat(engine): cost-overlay slippage_bps + --slippage-bps CLI
- #921 — docs(design): corporate-actions track (M&A long-term)

## State of branch protection

`enforce_admins` ENABLED (re-enabled at session-end). Disable temporarily for batch admin-merges:
```
gh api -X DELETE /repos/dayfine/trading/branches/main/protection/enforce_admins
# ... merge batch ...
gh api -X POST /repos/dayfine/trading/branches/main/protection/enforce_admins
```
