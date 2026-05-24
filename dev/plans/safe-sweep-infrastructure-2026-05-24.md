# Safe-sweep infrastructure plan (2026-05-24)

Prerequisite for any future BO sweep / random-search sweep / multi-hour
backtest run inside the docker dev container. Today's session lost
~16 hours of sweep wall-time across v1/v2/v3/v4/v5 to a combination of
jj-tree-state issues, sparse Docker.raw growth, and snapshot churn
filling the host disk. Each crash mode is now well-understood; this
plan turns those lessons into infra changes that prevent recurrence.

## Crash modes observed (2026-05-23/24)

| Mode | Cause | Memory |
|---|---|---|
| **jj-restore wipes output dir** | QC-agent's `jj edit` transiently dropped the gitignore entry for the sweep's output path → sweep's `bo_checkpoint.sexp` got snapshotted as tracked → my later `jj restore --from main` deleted it from disk | `feedback_jj_restore_killed_sweep.md` |
| **Worktrees fill host disk** | 10+ feat-/QC-agent isolated worktrees accumulate; biggest at 8.6GB; SessionStart sweep only fires at session start | `feedback_worktree_disk_kills_docker.md` |
| **Docker.raw runaway growth** | Snapshot CSV churn (`/tmp/panel_runner_csv_snapshot_*` per fold × ~26 folds × ~2 variants × N iters) writes ~30GB/hour into the container's writable layer; Docker.raw is sparse but never shrinks on file-delete → host disk full within 1-2h of sustained sweep | `feedback_worktree_disk_kills_docker.md` §6 |
| **Docker daemon hung on full disk** | Daemon socket becomes unreachable when host disk drops below ~1GB free; even commands like `df` fail because tool-output files can't be created | observed today |
| **No checkpoint resume** | If a sweep crashes mid-flight, partial iters are lost. Multi-hour sweeps × multiple crash modes = compounding wall-time loss | `project_bayesian_sweep_checkpoint_needed.md` (already filed) |

## Required changes — must land BEFORE next sweep

### 1. Bind-mount `/tmp/sweeps/` to a host path

**Why:** sweep output churn lives in `/tmp/sweeps/` inside the
container. Today this counts against `Docker.raw`'s size — capped at
80GB now, so future runaway is bounded but a single 60-iter sweep can
still hit the cap. Moving the output to a host bind-mount means:
- Output visible to `du -sh` from host (monitorable)
- Doesn't grow `Docker.raw` (immune to today's hog)
- Survives container restarts
- Independently cappable / cleanable

**Implementation:**
- Edit `.devcontainer/setup.sh` to add `-v
  $PROJECT_ROOT/.sweep-output:/tmp/sweeps` to the `docker run` command
  in `do_start()`.
- Add `.sweep-output/` to `.gitignore` (defensive — though host path is
  bind-mounted, jj/git should ignore it).
- ~10 LOC change. ~30 min to land.

### 2. Bind-mount `_build/` to a host path (optional but recommended)

**Why:** dune build cache also lives in container `/tmp/_build`-style
paths (and the in-repo `_build/` which IS already bind-mounted via the
repo). Today's cleanup showed the in-container `_build` was 7.5GB
right before crash. Already bind-mounted as part of the repo mount, so
this is mostly a no-op IF the in-repo `_build/` is the only build
cache. Verify by checking `du -sh` of both inside the running container
after a clean build.

**Implementation:** likely already done; just verify in next session.

### 3. Sweep snapshot cleanup hook

**Why:** `Panel_runner` writes `/tmp/panel_runner_csv_snapshot_*` per
fold backtest. These should be cleaned between iters, but observation
of the v3/v4 logs suggests the cleanup might lag relative to creation
(many concurrent in-flight snapshots).

**Investigation needed:**
- Verify the simulator's cleanup path actually runs between iters.
- If not, add an explicit `rm -rf /tmp/panel_runner_csv_snapshot_*`
  hook in the sweep loop's per-iter epilogue.
- ~50 LOC + investigation. Lower priority than (1).

### 4. Sweep wall-time disk monitor

**Why:** today's 1.5h disk-fill → Docker-collapse pattern wasn't
visible until the crash. A small monitor that runs alongside any
sweep and alerts when host disk drops below X GB OR container
writable layer grows beyond Y GB would catch it.

**Implementation:**
- `dev/scripts/sweep_disk_watcher.sh` — POSIX-shell script.
  Polls `df -h /` (host) + `docker exec ... df -h /` (container) +
  `du -sh /tmp/sweeps/<name>/` every 60s. If any threshold tripped,
  writes a `sweep-disk-alert.log` AND emails / posts a notification.
- ~80 LOC + tests. Add a `--watch` mode to the sweep launch script that
  auto-spawns this watcher.

### 5. Checkpoint-resume implementation (deferred but high-ROI)

**Why:** any of the above crash modes that DO recur (residual risk
even with (1)-(4)) cost less if `bayesian_runner.exe` can resume from
the on-disk `bo_checkpoint.sexp` instead of starting fresh. Today,
v4's 34-iter `bo_checkpoint.sexp` was technically intact post-Docker-
restart — but `bayesian_runner.exe` has no `--resume` flag, so it
would have started over anyway.

**Investigation:** see `project_bayesian_sweep_checkpoint_needed.md`
(2026-05-21). Plan exists; ~200-400 LOC + tests. Don't gate
next sweep on it — but high ROI within ~2 sessions.

## Operational rules (in-flight)

Document these as `.claude/rules/sweep-hygiene.md` so future sessions
follow them by default.

1. **Output ALWAYS to bind-mounted host path** (per change 1). Never
   to repo-relative path.
2. **`df -h /` check every 2h** of any active sweep. Hard threshold:
   if host free <20GB, abort the sweep manually.
3. **After EACH agent dispatched in a sweep-active session**: `rm -rf
   .claude/worktrees/<agent-id>/` immediately. Don't batch (memory
   `feedback_clean_worktrees_during_session.md`).
4. **Don't launch QC dispatches while a sweep is running on the same
   container** — they share writable-layer space. Either run QC in a
   separate session OR pause the sweep first.
5. **Treat any `ENOSPC` error** as a top-priority interrupt. Stop
   everything; recover disk; THEN reassess.

## Cost estimate

Total to land changes 1+4+5: ~1 day of focused work.
- Change 1 (bind-mount sweep output): 30 min
- Change 4 (disk watcher script): 2-3h including tests
- Change 5 (checkpoint resume): 1 full session

Lighter sequence to unblock next sweep ASAP: just change 1 + the
operational rules. ~1h total. Defer 4 and 5 to be the work of next
sweep cycle.

## Acceptance — next sweep is safe to launch when

- [ ] `/tmp/sweeps/` is bind-mounted to host (change 1).
- [ ] `du -sh ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw`
  is < 30GB before launch (clean baseline).
- [ ] Operational rules above are documented in `.claude/rules/sweep-hygiene.md`.
- [ ] Session has no other concurrent agent dispatches.
- [ ] `df -h /` shows > 50GB free on host.

## References

- `memory/feedback_jj_restore_killed_sweep.md`
- `memory/feedback_worktree_disk_kills_docker.md`
- `memory/feedback_clean_worktrees_during_session.md`
- `memory/project_bayesian_sweep_checkpoint_needed.md`
- `dev/notes/11knob-plateau-verdict-2026-05-24.md` (this plan's parent context)
