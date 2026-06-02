---
name: 2026-05-17 autonomous session — 13 PRs (full custom-universe + bonuses)
description: Q1 + Q2-A (pivoted) + Q2-B + cross-val all complete. BRK-B BAH + weekly-sweep tool. CSV-storage 4th-recurrence flake root-fixed. BAH-runner zero-trade bug surfaced.
type: project
originSessionId: f34c5bfb-9c21-4b11-b19d-c8b8e1b5f1f1
---
# 2026-05-17 autonomous session — 13 PRs

User dispatched the 8-PR custom-universe plan + walked away. Session landed 13 PRs total: 8 plan items + 2 fix-forwards + 2 user-requested bonus features + 1 deeper-fix-forward.

## PRs merged

| PR | Track | Summary |
|---|---|---|
| #1156 | Q1 PR1 | Asset_type parser |
| #1157 | Q1 PR2 | bulk Asset_type enrichment → `data/symbol_types.sexp` 41,575 entries |
| #1158 | fix-fwd | is_directory guard on test_reconcile_log_path_layout |
| #1159 | Q1 PR3 | filter_equity_like_symbols + plan doc committed |
| #1160 | Q2-A PR1 | shares_outstanding lib (no data — EODHD `/api/fundamentals/` 403) |
| #1161 | Q2-B PR1 | Snapshot.t + build_from_index (Shiller + French) |
| #1162 | fix-fwd | _reset_reconcile_dir uses rm -rf |
| #1164 | Q2-B PR2 | synthesizer runner + 213 decomposition goldens 1927-1997 |
| #1166 | bonus | BRK-B BAH benchmark (5y +77.71%, 15y +491.27%) |
| #1167 | bonus | weekly-start sweep tool + GHA Monday cron |
| #1168 | fix-fwd | CSV test per-test temp_dir isolation (4th-recurrence root fix) |
| #1169 | Q2-A PR2 | dollar-volume composition PIVOT + 75 goldens 1998-2025 |
| #1170 | Cross-val | composition vs Shiller drift (median +5.5pp; max 22.5pp at 2000) |

## Key design decisions locked

### Q2-A composition methodology pivot
- **Original plan**: rank by `current_shares × historical_price` (market cap)
- **Blocker**: EODHD `/api/fundamentals/` returns 403 on our paid tier (Fundamentals tier upgrade required)
- **Pivot**: rank by trailing 60-day avg daily dollar volume (`close × volume` from cached bars)
- **Justification**: arguably better for Weinstein universe (weights liquidity not theoretical cap)
- **Output**: equal-weight basket of top-N most-liquid symbols, reconstituted annually

### Q2-B decomposition methodology (unchanged from plan)
- 5 French industries × N_per_industry synthetic symbols (default 600 per for size=3000)
- Per-industry French daily returns as market factor
- Idiosyncratic GARCH(1,1) noise via existing `factor_model`
- Cap-weight rescale anchored to Shiller composite total return (price + dividend)
- Closed-form: machine-epsilon precise

### Snapshot.t unified type
- Single record produced by both directions
- `method_` tag flags composition vs decomposition
- `entries` carry `symbol`, `weight`, `sector`, `synthetic` (true for decomposition)
- Backtest scenarios consume both uniformly

### CSV-storage test isolation
- 4-level fix progression: PR #1153 (helper guard) → PR #1158 (test guard) → PR #1162 (rm -rf) → PR #1168 (per-test temp_dir)
- Root cause: all tests shared `test_data/_reconcile_log/`. `test_reconcile_failure_is_non_fatal` plants a file there; dune sandbox parallelism leaks the plant into sibling tests.
- Real fix: each test allocates `Filename.temp_dir` via `Fun.protect`

## Carry-forward blockers + findings

### BAH-runner zero-trade bug (NEW)
- Weekly-start sweep PR #1167 surfaced: 70/157 cells produce 0 trades, $100k unchanged
- Pre-existing in `backtest_runner.ml`, not caused by sweep tool
- Reproducible: `start=2023-07-10 end=2024-05-01` returns 0 trades; `start=2023-05-01` returns 1 trade
- Not Monday-vs-holiday related
- Worth investigating before relying on BAH benchmarks at arbitrary start dates

### EODHD fundamentals tier upgrade decision
- Still parked. Q2-A pivot bypassed need.
- If you later want shares-outstanding for factor work, $60/mo Fundamentals tier or $100/mo All-In-One.

### Q2-A 2026 data gap
- `top-{500,1000,3000}-2026.sexp` empty because bars cache doesn't extend to 2026-05-31
- Re-run cleanly when bars cache updates

### Q2-A runner memory bottleneck
- `_score_all` retains full bar history for all 14k symbols → OOM on multi-year × multi-size
- Worked around via single-year invocations
- Real fix: drop bars from non-top-N records mid-pipeline

## Agent dispatch lessons

1. **Agents claim "linters pass" without running `dune runtest devtools/checks/`.** Multiple PRs in this session hit CI lint failures post-push despite "all linters pass" claims. Dispatch prompts MUST include explicit `grep -c "^FAIL" /tmp/log` check + zero threshold.
2. **gh pr view --json files paginates at 100.** Use `git diff origin/main origin/<branch> --name-only` for true file lists on large PRs.
3. **ocamlformat skew is real** even between identical-looking docker images. The `dune build @fmt --auto-promote` step isn't always sufficient.
4. **jj workspaces under `.claude/worktrees/`** (NOT `/tmp/`) because docker bind-mount can't see /tmp. Boilerplate in `worktree-isolation.md` is correct.
5. **Multi-hour bulk runs need monitoring.** Q2-A runner ran 5h+; agent's session ran out before runner finished. Solution: dispatch a follow-up agent to drain the partial output.
6. **OOM bulk runs need single-iteration invocations.** Q2-A runner can't handle 12 years × 3 sizes at once. Single (year, size) per invocation works.

## Files to consult in next session

- `dev/notes/next-session-priorities-2026-05-19.md` — full P0/P1 ledger
- `dev/sweep/weekly-start-sweep-bah-spy.md` — sweep results (and the zero-trade bug evidence)
- `dev/sweep/cross-validation-composition-vs-shiller.md` — drift report
- `trading/test_data/goldens-custom-universe/composition/` — 75 dollar-vol goldens 1998-2025
- `trading/test_data/goldens-custom-universe/decomposition/` — 213 synthesis goldens 1927-1997

## What worked

- Sequential PR dispatch with rebase-on-base-update is reliable
- QC structural + behavioral agents catch most issues; rare CI escapes
- Methodology pivots are fine when documented and verified by cross-validation
- 12+ PR sessions are feasible when blockers are small and parallel agents avoid contention
