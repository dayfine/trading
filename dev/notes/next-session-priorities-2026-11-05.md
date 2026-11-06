# Next-session priorities — 2026-11-05 (supersedes 2026-11-02)

Short evening session, 2026-11-05 22:08 PT. Open issues: **15**. Main CI is green.

## 0. Ground rules (unchanged since 11-02)

- Cloud sessions are the default for feature and rework work (`docs/howtos/claude_cloud_sessions.md`); the local
  container is for QC and runs that need local data.
- Local agent wave ≤ 3; remove QC worktrees as soon as their review lands.
- haiku qc-structural often fails to post: put the exact post command in the brief, never post for it.

## 1. What settled since 11-02

| item | result |
|---|---|
| #3506 shard case | fixed by #3510; goldens-broad cell byte-identical cloud vs local |
| #3477 pause/resume | PR 6 (#3517) + PR 7 (#3521) + follow-ups #3524/#3529 merged; issue closed |
| #3505 SGNT stop epsilon | fixed by #3512 |
| #3503, #3500 | merged |
| #3476 cloud backtests | **closed tonight**: all Done-when met; 26y kill+resume on cloud matched all four artifacts (11-05) |
| weekly perf/issue review | done 11-02 (#3520) |
| #3533 daily summary | merged tonight |

## 2. In flight (check first)

| what | where | next |
|---|---|---|
| **#3536** halt exit 75 (closes #3534) | review commit `091c63c9` on top: `_exit_code` moved to `Checkpoint_cli.exit_code` + unit test, fold-health wrapper inlined; `scenario_runner.ml` 321 → 296 lines | CI, then qc-structural → qc-behavioral, then merge |

## 3. Queue

1. **Decision-tree walkthrough** (`memory/project_decision_walkthrough_next`) — unblocked now that backtests run in
   the cloud. First pass (09-26, f2 s0) found: weekly stop raises are not recorded in `trade_audit.sexp`; fallback-stop
   shakeouts dominate losses; tickets rest for years. Start by re-running the walkthrough inputs on the current record
   config, in a cloud session.
2. **Make cloud the default for backtests** (`memory/project_cloud_backtest_default_path`): runbook line in
   `docs/howtos/claude_cloud_sessions.md`, then shrink the Docker VM 7.75 → 5 → 4 GB (Docker Desktop setting, user).
   Blocker to check first: **#3535** — cloud cells rebuild the v12 warehouse (5.5 h) and get a different construction
   (9,181 vs 9,364 symbols). Ship the built warehouse through R2 instead of rebuilding.
3. **#2973** split corpus (ready-for-agent, env/cloud): continuing.
4. Weekly perf/usage review + `issue_fix_audit.sh` due again ~11-09.

## 4. Decisions waiting (deferred to 11:00 PT)

- **Docker VM shrink** after #3535 lands: user changes the Docker Desktop memory setting.
