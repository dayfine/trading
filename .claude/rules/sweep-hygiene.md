# Sweep hygiene — operational rules for multi-hour BO / random / tuner runs

Today's session (2026-05-23/24) lost ~16 hours of sweep wall-time
across five attempts (v1/v2/v3/v4/v5) to a combination of jj-tree-state
issues, Docker.raw runaway growth, and host disk exhaustion. Each
crash mode is well-understood; this file is the operational checklist
that prevents recurrence.

Pairs with:
- `dev/plans/safe-sweep-infrastructure-2026-05-24.md` (the structural
  changes — bind-mount, disk-watcher, checkpoint resume).
- `memory/feedback_jj_restore_killed_sweep.md`
- `memory/feedback_worktree_disk_kills_docker.md`
- `memory/feedback_clean_worktrees_during_session.md`

## Pre-launch checklist

Before launching any sweep that will run > 1 hour:

- [ ] **Host disk free > 50 GB** — `df -h /`. If less, clean first.
- [ ] **`Docker.raw` < 30 GB** — `du -sh ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw`. If more, recompact via Docker Desktop Settings → Resources → Apply & restart.
- [ ] **No other agent dispatches active** in this session. QC / feat-agents and sweeps cannot share the container — they fight for writable-layer space. Either pause one or run in separate sessions.
- [ ] **`/tmp/sweeps/` is bind-mounted to host** — verify with `docker inspect trading-1-dev | grep -A1 '/tmp/sweeps'`. If not bind-mounted, recreate the container via `.devcontainer/setup.sh rebuild && .devcontainer/setup.sh start`.
- [ ] **No locked worktrees > 24h old** — `ls -lt .claude/worktrees/` and remove any whose owning agent has long since completed.

## During-sweep rules

- **Sweep output path:** ALWAYS launch with `--out-dir /tmp/sweeps/<sweep-name>` (matches the bind-mount). NEVER use a repo-relative output path — gitignore alone won't protect against jj-tree-state issues per `feedback_jj_restore_killed_sweep.md`.
- **`df -h /` check every 2 hours.** Hard threshold: if host free < 20 GB OR `Docker.raw` actual > 50 GB, abort the sweep manually before it crashes the daemon. `kill -TERM <pid>` is the graceful path (lets the BO runner write a final checkpoint).
- **No concurrent jj ops** on the parent workspace once the sweep is writing. Specifically: no `jj new`, `jj rebase`, `jj restore`, `jj git fetch + abandon`. Each of these can transiently change the working-tree shape, and if the sweep's output path is anywhere near a tree boundary, the file can disappear.
- **No concurrent agent dispatches** in this session. QC agents do `jj edit` on PR branches — that touches the shared `.jj/repo/`. See `memory/feedback_qc_agents_need_worktree_isolation.md`; this is a non-zero risk vector even with `isolation: "worktree"`.

## After each dispatched agent (sweep-active sessions)

- **`rm -rf .claude/worktrees/<agent-id>/` immediately** after task-notification confirms agent completion — DON'T batch. Single agent worktrees with `dune build` artifacts are 5-8 GB each. Three of them = 15-24 GB of writable-layer growth that compounds with sweep snapshot churn.
- Per `memory/feedback_clean_worktrees_during_session.md`.

## ENOSPC recovery sequence

If `ENOSPC: no space left on device` errors appear in tool output:

1. **STOP** — every command writes to a tool-output file; ENOSPC means the harness can't write that file. You're effectively dead in the water.
2. Ask the user to manually free disk: `rm -rf /private/tmp/claude-501/*/*/tasks/*.output` (frees enough to make tools work again).
3. Once tools work, identify the hog: `df -h /; du -sh ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw`.
4. **Don't relaunch the sweep until the hog is mitigated.** Today's pattern was: free disk → relaunch → fill back up → ENOSPC again. Address the source, not the symptom.

## Per-sweep launch incantation

The canonical safe form (post-bind-mount + post-cap):

```bash
SWEEP_NAME="11knob-v6-random"  # always increment
docker exec -d trading-1-dev bash -c \
  "mkdir -p /tmp/sweeps/${SWEEP_NAME} && \
   cd /workspaces/trading-1/trading && eval \$(opam env) && \
   nohup dune exec --no-build trading/backtest/tuner/bin/bayesian_runner.exe -- \
     --spec <path-to-spec> \
     --walk-forward-spec <path-to-wf-spec> \
     --baseline-aggregate <path-to-aggregate> \
     --out-dir /tmp/sweeps/${SWEEP_NAME} \
     --parallel 4 \
     > /tmp/sweeps/${SWEEP_NAME}.log 2>&1 &"
```

Key invariants in this incantation:
- `--out-dir /tmp/sweeps/<name>` (uses the bind-mount → host disk)
- `nohup ... &` (sweep survives container restart? no — but survives Claude Code session exit; see § *Post-launch monitoring*)
- `2>&1` (stderr captured for crash diagnosis)

## Post-launch monitoring

- The sweep PID lives inside the container. `docker exec trading-1-dev ps -o etime= -p <pid>` for wall time.
- BO checkpoint at `/tmp/sweeps/<name>/bo_checkpoint.sexp` (visible on host at `$PROJECT_ROOT/.sweep-output/<name>/bo_checkpoint.sexp` via the bind-mount).
- Per-iter scores: `grep -E 'metric ' /tmp/sweeps/<name>/bo_checkpoint.sexp | awk '{print $2}' | tr -d ')' | sort -g`.
- Container can be restarted (`docker restart trading-1-dev`) without losing the bind-mounted output — but the running sweep process inside dies. Only restart the container if necessary; the sweep does NOT resume from checkpoint today (see `memory/project_bayesian_sweep_checkpoint_needed.md`).

## Acceptance — these rules apply when

- A sweep is expected to take > 1 hour wall-time, OR
- A sweep writes anywhere under `/tmp/` inside the container at any sustained rate, OR
- Any concurrent agent dispatch is active.

For short ad-hoc backtests (< 30 min, single scenario), the bind-mount
is still nice-to-have but the operational discipline above is overkill.
