# Sweep + QC architecture improvements (2026-05-26)

Harness improvements that compound across all future sessions. Runs in
**parallel** with the tuning research-driven program
(`dev/plans/tuning-research-driven-program-v2-2026-05-25.md`) — neither
gates the other.

## Why

Today's session (2026-05-23/24/25) exposed three failure modes that the
existing `.claude/rules/sweep-hygiene.md` documents but doesn't enforce
mechanically:

| Failure mode | Cost today |
|---|---|
| Sweep output in repo path → snapshot churn grew `Docker.raw` to 186GB → host disk full → Docker daemon died → multiple sweep crashes | ~16h of sweep wall-time lost across v2 / v3 / v4 / v5 |
| QC agents `jj edit <pr-branch>` mutated the shared `.jj/repo/`, contaminated parent workspace (PWD-in-deleted-worktree, gitignore reversion mid-sweep) | At least 2 separate jj contamination incidents |
| QC agents write to `dev/reviews/<feature>.md` on the PR branch → merge conflicts + housekeeping churn + reviews scattered across PRs | Ongoing low-grade friction |

These are addressable at the harness layer with bounded, well-scoped
changes. The sweep-hygiene rule stays as the **discipline doc**; the
changes below are the **enforcement layer**.

## Five PRs, sequenceable

### PR-A — Launch wrapper script: `dev/scripts/launch_sweep.sh`

**What:** mandatory entry point for any sweep launch. Refuses to launch unless preconditions are met.

**Preconditions checked:**

- [ ] Host disk free ≥ 50 GB (`df -h /`)
- [ ] `Docker.raw` actual size < 30 GB
- [ ] `trading-1-dev` container is running
- [ ] `/tmp/sweeps/` is bind-mounted to host (`docker inspect` check)
- [ ] No other `bayesian_runner.exe` processes already running in the container
- [ ] No locked agent worktrees > 24h old (`.claude/worktrees/`)

If any check fails, **exit non-zero with a clear message** explaining what to fix.

**On success:**
- Creates `/tmp/sweeps/<sweep-name>/`
- Launches `bayesian_runner.exe` via `docker exec -d`
- Spawns the disk watcher (PR-C) as a child process
- Prints PID + canonical "monitor with `docker exec ... pgrep -af`" line

**Effort:** ~150 LOC POSIX shell + ~50 LOC tests. 1 small PR.

**Acceptance:**
- Each precondition has a unit test (fixture-driven; mock `df`/`docker inspect` output).
- Running with `--dry-run` shows what would be launched without firing.
- Running on a clean container with `disk_free=80GB` succeeds; running with `disk_free=10GB` fails fast with explicit error.

### PR-B — Bind-mount assertion in `bayesian_runner.exe`

**What:** belt-and-suspenders refusal to launch if `--out-dir` is not under `/tmp/sweeps/`. Even if someone bypasses PR-A's wrapper, the binary itself enforces the convention.

**Change:** in `bayesian_runner.ml` arg parsing, after `--out-dir <path>` is resolved, assert `String.is_prefix path ~prefix:"/tmp/sweeps/"`. Fail with `Stdlib.exit 2` + an error message pointing at the sweep-hygiene rule.

**Effort:** ~20 LOC + 1 unit test. 1 small PR.

**Acceptance:**
- Launch with `--out-dir /tmp/sweeps/foo` succeeds.
- Launch with `--out-dir dev/experiments/...` exits 2 with the error message.
- Documented exemption: env var `BAYESIAN_RUNNER_ALLOW_NON_SWEEP_OUTPUT=1` for genuine one-off use (don't make this discoverable).

### PR-C — Disk watcher daemon: `dev/scripts/sweep_disk_watcher.sh`

**What:** runs alongside any sweep. Polls host `df -h /` + container `/tmp` size + `Docker.raw` size every 60s. SIGTERMs the sweep if any threshold trips. Per the safe-sweep-infra plan §4.

**Thresholds:**
- Host disk free < 20 GB → SIGTERM (lets the BO runner write a final checkpoint)
- `Docker.raw` > 50 GB → warning at 50, SIGTERM at 65
- Container `/tmp` > 30 GB → warning (likely snapshot-churn buildup; spawn the cleanup hook)

**Outputs:**
- Append-only log at `.sweep-output/<sweep-name>.watcher.log`
- Stderr to the same file
- Exits when sweep PID exits

**Effort:** ~80 LOC + ~50 LOC tests. 1 small PR.

**Acceptance:**
- Fixture: mock-disk-fill scenario triggers SIGTERM at the correct threshold.
- Manual: launch a sweep + induce a 1GB disk consumption → watcher logs the breach.

### PR-D — QC review storage: `gh pr review --comment` instead of `dev/reviews/<file>.md`

**What:** replace the current pattern of QC agents writing `dev/reviews/<feature>-structural.md` / `<feature>-behavioral.md` files on the PR branch with **posting PR review comments via the GitHub API**.

**Why:**
- `dev/reviews/` files cause merge conflicts when multiple PRs touch the same review file
- Review files are buried in the repo; PR comments are on the PR
- GitHub natively supports `APPROVED` / `CHANGES_REQUESTED` / `COMMENTED` verdicts (matches our QC verdict shape)
- Audit trail is searchable via `gh pr view <N> --json reviews`
- Removes one source of jj/git contention (no PR-branch write)

**Change:**

- QC agent prompts: replace "write to `dev/reviews/<feature>.md`" with:
  ```
  Post the review as a PR comment via:
    gh pr review <N> --comment --body "$(cat <<'EOF'
    <verdict>
    <findings>
    EOF
    )"
  Then set the PR verdict via:
    gh pr review <N> --approve | --request-changes | --comment
  ```
- Update `.claude/agents/qc-structural.md` and `.claude/agents/qc-behavioral.md` to bake this in.
- Keep `dev/reviews/` for **batch reports** (track-pacer, weekly health-scanner) where a file IS the right artifact. Just stop using it for per-PR QC.

**Effort:** ~50 LOC agent-prompt edits + retire `dev/reviews/<feature>.md` convention. 1 PR.

**Acceptance:**
- Dispatch a qc-structural review on a test PR; verify the verdict appears as a PR review comment with the correct APPROVED / REQUESTED-CHANGES state.
- Verify the per-PR review files (e.g. `dev/reviews/fix-segmentation-epsilon.md`) are NOT created.

### PR-E — QC worktree: plain `git worktree` instead of `jj edit`

**What:** stop using `jj edit <pr-branch>` in QC agents. Use `git worktree add /tmp/qc-<pr-N> <pr-branch>` instead. Git worktrees are file-system-only; no shared `.jj/repo/` race.

**Why:**
- `jj edit` mutates the shared jj backend (`memory/feedback_qc_agents_need_worktree_isolation.md`)
- Today: QC's `jj edit` pulled the parent workspace's `@` along (`memory/project_jj_worktree_root_cause.md`)
- Today: QC's worktree was rm-rf'd while my PWD was still in it, then jj recreated the directory mid-session
- Plain git worktrees don't have this class of bug

**Change:**

- Update QC agent prompts to use git rather than jj for the PR checkout:
  ```bash
  WT="/tmp/qc-pr-$N-$$"
  git fetch origin <pr-branch>
  git worktree add "$WT" origin/<pr-branch>
  cd "$WT"
  docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && dune build && dune runtest'
  # ... write findings + post via gh pr review ...
  cd /
  git worktree remove "$WT"
  ```
- The QC agent NEVER calls `jj` directly. Plain git only. No shared-jj-backend race.

**Effort:** ~80 LOC agent-prompt edits. 1 PR.

**Acceptance:**
- Two QC agents dispatched on different PRs in the same session do not contaminate each other's worktrees.
- Parent workspace's `@` does not move when a QC agent runs.

## Sequencing

| Sequence | Why |
|---|---|
| PR-A first | The wrapper script is the highest-leverage single change. Once it's in place, sweep launches are mechanically safe. |
| PR-B second | Belt-and-suspenders for the wrapper; trivial PR. |
| PR-C third | Disk watcher; depends on PR-A's wrapper to spawn it. |
| PR-D fourth | QC architecture refactor; independent of A/B/C but quality-of-life leverage compounds across QC dispatches. |
| PR-E fifth | Same shape as D but solves the jj-backend race. |

PRs A/B/C address sweep-hygiene enforcement; PRs D/E address QC architecture. The two halves are independent — could be done in either order.

## What this does NOT fix

- **Sweep ↔ QC container contention.** Both still write to the container's `_build/` directory. If you launch a QC agent while a sweep is running, dune build outputs collide. The right fix is **separate containers** OR **sweep-runs-natively** (host OCaml, not container). Out of scope for this plan; flagged for a future architectural conversation.

- **Periodic snapshot-cleanup hook in `Panel_runner`.** Per `dev/plans/safe-sweep-infrastructure-2026-05-24.md` §3. Still useful; complementary to the disk watcher. Lower priority once the watcher is in place.

## Effort estimate

| | LOC | Sessions |
|---|---:|---:|
| PR-A — launch wrapper | ~200 | 1 |
| PR-B — runner assertion | ~20 | 0.5 (combines with PR-A) |
| PR-C — disk watcher | ~130 | 1 |
| PR-D — QC via gh comments | ~100 | 1 |
| PR-E — QC plain git worktree | ~80 | 0.5 |
| **Total** | **~530** | **3-4** |

Cheap. Compounds with every sweep + every QC dispatch indefinitely.

## References

- `.claude/rules/sweep-hygiene.md` — operational rules this plan enforces
- `.claude/rules/worktree-isolation.md` — the jj-workspace-isolation contract this plan superseded for QC agents
- `dev/plans/safe-sweep-infrastructure-2026-05-24.md` — the original framing of items 1-3
- `memory/feedback_qc_agents_need_worktree_isolation.md`
- `memory/project_jj_worktree_root_cause.md`
- `memory/feedback_jj_restore_killed_sweep.md`
- `memory/feedback_worktree_disk_kills_docker.md`
- `dev/plans/tuning-research-driven-program-v2-2026-05-25.md` — parallel work program; this plan does not block it
