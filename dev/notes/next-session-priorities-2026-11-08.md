# Next-session priorities — 2026-11-08 (supersedes 2026-11-05)

Session 2026-11-08, ended ~17:00 PT. Open issues: **15**. Main CI green.

## 0. Ground rules (unchanged)

- Cloud sessions are the default for feature and rework work; local container for QC and runs needing local data.
- Local agent wave ≤ 3; remove QC worktrees as soon as their review lands.
- Run `r2_bars.sh` on the **host**: from inside `trading-1-dev` R2 answers 403 (cause not traced).

## 1. What settled since 11-05

| item | result |
|---|---|
| #3545, #3551 split corpus (#2973) | merged |
| #3546 decision walkthrough on record k0 | merged (`memory/project_decision_walkthrough_next`) |
| #3547 relocatable warehouse reads | merged; #3535 now `verify/pending` |
| R2 warehouse `v12wk-9236` | verified identical to the local 9,236-symbol warehouse |
| rk-k0 cloud parity, attempt 1 | **MISMATCH** (1251.35 vs 1312.79 %): no dividends/splits staged. First diff 2000-06-28 = FR's $1,767.00 dividend |
| dividends + splits in R2 | `corpact-2026-10-27` (one tarball, 23,760 files, verified) |

## 2. In flight (check first)

| what | where | next |
|---|---|---|
| rk-k0 cloud parity attempt 2 (with corpact) | routine `trig_01LBm7DN4Fr43VZQTpVAeXF7`, fired 00:40Z 11-09; posts on #3535 | MATCH → #3535 item 1 done; MISMATCH → read the comment's first differing date/trade |
| #3554 howto: dividends/splits staging, pre-#3547 `/tmp` mount, host-only R2 | docs-only | CI → merge |

## 3. Queue

1. On MATCH: cloud-default runbook line in `docs/howtos/claude_cloud_sessions.md`, then Docker VM shrink.
2. #3535 item 2: twin-dedupe decision (below).
3. #2973 split corpus continues.
4. Weekly perf/usage review + `issue_fix_audit.sh` due ~11-09.
5. Unfinished `tables.sh` extension from the old `walk-rk-rw` worktree: patch saved in session scratchpad only
   (`walk-rk-rw-tables.patch`), likely lost; redo if the walkthrough tables need it.

## 4. Decisions waiting (raise at/after 11:00 PT)

- **#3535 twin dedupe:** is `build_pit_warehouse_v12.sh`'s twin dedupe the intended construction or a chunking
  artefact (`memory/project_pit_chunked_twin_miss`)? Recommendation: treat the 9,236 `v12wk` as canonical (the record
  runs on it) and document the dedupe as intended; revisit only if a rebuild is needed.
- **Docker VM shrink** 7.75 → 5 → 4 GB after parity matches: user's Docker Desktop setting.
