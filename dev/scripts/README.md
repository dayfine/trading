# dev/scripts/

Operational shell scripts for data management, backtesting, and analysis.

All scripts use `#!/usr/bin/env bash` with `set -euo pipefail`. No Python — per `.claude/rules/no-python.md`.

## velocity_report.sh

Generates a reproducible PR velocity report for any time window.

```
bash dev/scripts/velocity_report.sh --since YYYY-MM-DD [--until YYYY-MM-DD] [--out FILE]
```

**Example — regenerate the existing velocity note:**

```bash
bash dev/scripts/velocity_report.sh --since 2026-03-24 --out dev/notes/velocity-since-2026-03-24.md
```

**What it produces:**

- Headline PRs/LOC for the window
- By-category breakdown (Conventional Commits prefixes)
- By-language breakdown with OCaml test/source split:
  - `OCaml source (total)` — all `*.ml`/`*.mli` files
  - `— OCaml source (lib)` — OCaml files outside `/test/` directories
  - `— OCaml source (test)` — OCaml files under `/test/` directories
- Per-month rollup
- Methodology section

**100-file truncation guard:** when a PR has exactly 100 files in the GitHub GraphQL response (the API truncation limit), the script falls back to `gh api repos/dayfine/trading/pulls/<N>/files --paginate` to get the full file list. Required for PR #873 (997 files of generated SP500 test fixtures).

**Verification:** the script asserts OCaml source (total) == lib + test before emitting the report. If the PR-level headline LOC differs from the language-table sum (can happen if some PRs have no per-file data), a WARNING is emitted.

**Idempotent:** re-running with the same `--since`/`--until` produces byte-identical output (modulo the run-timestamp in the Methodology section).

**Requirements:** `gh` (GitHub CLI, authenticated), `jq`, `bc`.

## Other scripts

| Script | Purpose |
|---|---|
| `sweep_stale_worktrees.sh` | Remove stale `agent-*` jj workspaces to reclaim disk space. See `.claude/rules/worktree-isolation.md §Cleanup`. |
| `cleanup_merged_worktrees.sh` | Remove worktrees whose branches are gone from origin (post-merge cleanup). |
| `build_sp500_universe.sh` | Build the S&P 500 ticker universe for backtesting. |
| `build_broad_snapshot_incremental.sh` | Incrementally build a broad-universe snapshot. |
| `check_sp500_baseline.sh` | Regression-check S&P 500 backtest metrics against pinned baselines. |
| `perf_tier1_smoke.sh` — `perf_tier4_release_gate.sh` | Performance tier gates (tier 1: fast CI, tier 4: local-only full run). |
| `golden_sp500_postsubmit.sh` | Post-submit golden-run pipeline for S&P 500 scenarios. |
| `prepare_ci_data.sh` | Prepare fixture data for CI runs. |

## review_pack.sh

Builds a human review pack for one or more backtest runs (typically the salts
of one config): a static site with the equity curve against SPY and the macro
gate, year/quarter tables, every trade with its chart, A–F grade and
execution/book flags, highlights, diagnostics (flat stretches, pick vs exit
quality, hard-stop replay, stop-fill timing, entry-time D/F predictors) and a
cross-salt comparison. Helpers and the page live in `dev/lib/review_pack/`;
the test is `trading/devtools/checks/review_pack_test.sh`.

```sh
P=.sweep-output/pit-null/a0-pit-null
sh dev/scripts/review_pack.sh --out .sweep-output/review-26y \
  --title "26-Year Record Review" \
  s0=$P-s0-v11- s1=$P-s1-v11- s2=$P-s2-v11-
```

About 2 minutes for three 26-year salts when the stage replays already exist,
plus ~1.3 s per trade the first time (`stage_chart` in `trading-1-dev`).
`--no-container` skips the audit report and the stage replay. Publish
`<out>/site/index.html` with `<out>/site/data/*` as supporting files.
