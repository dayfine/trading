# Next-session priorities — 2026-11-02 (supersedes 2026-10-13)

Overnight session, 2026-11-01 21:30 → 11-02 07:00 PT. Open issues: **20** (the cap). Main CI is green.

## 0. Ground rules (changes since 10-13)

- **Agent worktrees are no longer reaped.** `cleanup_merged_worktrees.sh`, run from the settings hook, removed live agent
  worktrees whenever they ran past 1 h, because their `worktree-agent-<id>` branch is never pushed. Three agents lost
  all their work on 11-02. Fixed in #3501, which keeps locked worktrees. The parent checkout's copy of the script was
  synced by hand. Re-sync it when the parent next moves to main.
- **Cloud sessions are the default for feature and rework work.** The local container is kept for QC and runs that need
  local data. Launch with `RemoteTrigger` (`docs/howtos/claude_cloud_sessions.md`). Briefs carry the docker build line
  and "new commit, never amend; never merge". Tonight 5 feature PRs and 4 reworks ran this way, with no local slots
  used.
- **haiku qc-structural often returns without posting** and asks the dispatcher to post
  (`memory/feedback_haiku_qc_structural_fails_to_post`). Never post it yourself. Put the exact
  `jq --rawfile … COMMENT` command in the brief, and SendMessage-resume the agent if it didn't post.
- **Docker Desktop wedged** at about 04:15 under four concurrent builds plus low disk (367 MiB free at the worst point).
  It recovered after `kill -9` of the stuck `com.docker.backend`, then a relaunch. Keep the local wave at 3 agents or
  fewer, and remove QC worktrees as soon as their review lands.

## 1. What this session settled

| item | result |
|---|---|
| #3501 | cleanup hook honours `git worktree lock` (merged; regression test `cleanup_merged_lock_test.sh`) |
| #3504 | #3477 PR 5: recorder capture/restore and the step journal (merged after 1 rework). PR 6 and PR 7 remain |
| #3502 | #3426 laggard split basis and streak clear, both default-off flags (merged; #3426 closed) |
| #3476 data identity | the R2 pull works from cloud (32 s, sha OK). The hash manifest root `e0348f01…` is **equal** on cloud and local (11,888 symbols) |
| #3476 parity cell | **FAILED**: goldens-broad bull-crash-2015-2020 at 2210132b2 gave cloud 51.3 % / 203 trades and local 99.5 % / 179. Cause: **#3506** |
| #3506 (new, P1) | shard path uses the symbol's raw last character. `*_old` symbols live under uppercase shards (`C/D/COMP_old`) and resolve only on case-insensitive macOS. Linux (cloud **and GHA**) silently drops about 30 of the top-1000-2015. This may explain the goldens-broad tier-4 "FAIL on GHA" |
| #3505 (new) | SGNT stop fires a day late on float epsilon (split out of #3424) |

## 2. In flight (check first)

| what | where | next |
|---|---|---|
| **#3503** (#3424 force-liq + fill-from-above) | main merged in (registry conflict resolved, tip `dcfe5a74b`) | CI, then re-run **both** QC (merge-only delta), then merge. That closes #3424 |
| **#3500** (#3420 validator V12/V13) | cloud session `rework-3500-iter2`, **iteration 2 of 2** | it now also **conflicts with main** (registry): resolve, then structural → behavioral. If behavioral is NEEDS_REWORK again: STOP, leave it as a draft, and flag it to the user |
| **#3506 fix** | cloud session `issue-3506-shard-case` | it opens a PR and reruns the parity cell in the cloud. Compare with the local hashes (§4). Then the usual gates |
| parity worktree | `.claude/worktrees/parity-3476` (pinned 2210132b2) and `parity-3476-run.sh` | rerun locally at the #3506 fix commit, so both sides use the same code |

## 3. Queue

1. **#3506 → parity → cloud default.** After #3506 merges: rerun the parity cell local and cloud at the same SHA; the
   output must be byte-identical. Then the 26y kill+resume cloud run, which needs #3477 PR 6 and PR 7. Only then make
   cloud the default and shrink the VM (`memory/project_cloud_backtest_default_path`).
2. **#3477 PR 6** (`Backtest_checkpoint` dir and hook), then **PR 7** (CLI plus the byte-identity acceptance test).
   Both are good cloud-session tasks.
3. **#3505** SGNT stop epsilon: small and well specified, a cloud task.
4. **Weekly perf/usage review** is overdue (`perf-review-weekly.md`), along with the `issue_fix_audit.sh` pass.
5. **Decision walkthrough** (`memory/project_decision_walkthrough_next`): parked until backtests move to the cloud.

## 4. Reference numbers

Local parity output at 2210132b2 (`dev/backtest/scenarios-2026-11-02-125307/bull-crash-2015-2020`, parent tree):
actual.sexp `234f4794…12d6`, trades.csv `76eec7b2…c0c0`, equity_curve.csv `63a50df1…6541`, trade_audit.sexp
`1d0413f0…abba`. Warehouse 988 touched / 27 absent. Local wall 60 min, but run beside two QC builds. Cloud: 5 min,
0.5 GB RSS; warehouse build 3 min.

## 5. Decisions waiting (deferred to 11:00 PT)

None needing the user. #3500 goes to the user only if rework iteration 2 fails.
