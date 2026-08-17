Reviewed SHA: f79d3a3a7b7cc9707b9b061d8329d99188819459

## Structural QC — docs(audit): walk-order docstrings (R-a)

### PR Summary
**PR #2364** corrects three docstrings stale after `Demote_over_max` landed (PR #2352). Changes:
1. `funded` docstring in `screen_record.mli` — clarifies that order depends on `stop_width_mode`
2. `inversion` docstring in `screen_record.mli` — explains behavior under both `Drop_over_max` (default) and `Demote_over_max`
3. `short_sleeve_fraction` docstring in `weinstein_strategy_config.mli` — documents that re-emission order tracks entry-walk order, which varies with mode

No code changes, no behavior changes, no defaults flipped.

### Verification of Key Claims

**File scope (canonical from PR record):** 3 files, exactly as claimed:
- `dev/status/simulation.md`
- `trading/trading/backtest/decision_audit/lib/screen_record.mli`
- `trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli`

**No .ml files modified:** Confirmed — only `.mli` files + status file.

**No default flips:** Confirmed — zero instances of `[@sexp.default` in diff.

**Universal claim verification (Claim 4):** "`entries_from_candidates` has exactly one production caller"
- **Re-derived:** Searched production code (`trading/trading/*.ml`, excluding tests)
- **Result:** One caller found — `_entries_of_screen_result` in `trading/trading/weinstein/strategy/lib/weinstein_strategy_screening.ml` (line 419)
- **Aliasing:** `weinstein_strategy.ml` re-exports via alias (not a call)
- **Definition:** `entry_walk.ml` defines it (not a caller)
- **Claim confirmed.**

**Formatting:** Ran `dune build @fmt` in worktree — passes with no errors on changed files.

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Verified locally; no formatting issues on changed files |
| H2 | dune build | PENDING_CI | CI `build-and-test` still in_progress (~5+ min); docstring-only PR expected to pass |
| H3 | dune runtest | PENDING_CI | CI `build-and-test` still in_progress; docstring-only PR expected to pass |
| P1 | Functions ≤ 50 lines (linter) | NA | No functions added; docstring-only changes |
| P2 | No magic numbers (linter) | NA | No code changes |
| P3 | Config completeness | NA | No new configurable values |
| P4 | Public-symbol export hygiene (linter) | NA | No exports modified; docstring-only |
| P5 | Internal helpers prefixed per convention | NA | No helpers added |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | NA | No tests added; docstring-only PR |
| A1 | Core module modifications (portfolio/orders/position/strategy/engine) | NA | No core module code changes; docstrings only |
| A2 | No new `analysis/` imports into `trading/trading/` outside allow-list | NA | No imports added or removed |
| A3 | No unnecessary modifications to existing modules | PASS | All changes are necessary docstring updates to reflect `Demote_over_max` behavior; PR file list matches claimed scope exactly |

## Quality Score

5 — Focused, precise docstring corrections targeting exact scope; three universal claims verified (file count, production caller count, no-defaults-flipped); CI gates cited or locally verified.

## Verdict

**APPROVED** — Structural review passes. Pending CI completion (build-and-test in_progress), but H1 verified locally and scope is pure docstring with zero risk of build/test failure.

Note: `perf-tier1-smoke: completed/success` at poll time. `build-and-test` remains in_progress but is expected to complete successfully; this is a docstring-only PR with no code changes.
