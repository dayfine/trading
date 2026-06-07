---
harness: reusable
---

# Worktree Isolation Integrity

## The problem

When a subagent is dispatched with `isolation: "worktree"`, its worktree is
**not** a clean checkout of `main@origin`. The isolated worktree inherits a
snapshot of the parent worktree's working copy at dispatch time — including any
uncommitted edits and any in-flight commits from concurrent agents on other
branches.

Consequences observed in practice:

1. **File leaks.** `jj new main@origin` can leave stray modifications in the
   working copy that originated in a sibling agent's branch, which then get
   auto-snapshotted into your commit.
2. **Ancestry leaks.** If your `@` is a descendant of another agent's
   in-flight commits at the time you create your branch, the PR diff against
   `main` will include those commits too — even if your single commit only
   touches the files you intended.

Both happened on 2026-04-16 while concurrent feat-weinstein and
harness-maintainer agents were running.

## The rule

Before committing, verify your working copy contains only the files your task
requires. Before pushing, verify the branch ancestry lands on `main@origin` and
not on a sibling agent's stack.

**Pre-commit checks:**

```bash
jj diff --stat   # expect only files listed in your task's "Files to touch"
```

If stray files appear, scrub them before staging your real changes:

```bash
jj restore <stray-path> --from main@origin
```

**Pre-push checks:**

```bash
# What commits are in your branch but not in main@origin?
jj log -r '::<your-bookmark> & ~::main@origin' --no-graph -T 'description.first_line() ++ "\n"'
```

You should see **only your own commits**. If you see commits from other agents
(e.g., `feat(stops):`, `feat(strategy):`), your branch is stacked on top of
their work. Rebase onto `main@origin`:

```bash
jj rebase -r <your-change-id> -d main@origin --ignore-immutable
jj git push -b <your-bookmark>   # force-update if remote diverges
```

**Post-push verification (when task allows network access):**

```bash
gh pr view <PR#> --json files --jq '.files[].path'
```

The file list must match your "Files to touch". If it doesn't, rebase and
force-push — do not hand off a contaminated PR for review.

## When to apply

- Every subagent dispatched with `isolation: "worktree"` while another agent is
  known to be running in the same repo.
- Any session where the dispatcher's pre-flight prompt calls out workspace
  contamination risk explicitly.
- Any time `jj diff --stat` surprises you at dispatch time.

## What this rule does NOT cover

- Shared-worktree dispatch (non-isolated) — that's a different hazard class
  (`@` collisions between parent and child). Use `isolation: "worktree"` plus
  this rule for most concurrent work.
- Git-mode dispatch inside `$TRADING_IN_CONTAINER` (GHA) — CI runners start
  from a fresh checkout, so contamination doesn't occur there.

## jj workspace isolation

The pre-commit / pre-push scrubbing above treats symptoms. The root cause is
that Claude Code's `isolation: "worktree"` creates **git worktrees** (via
`git worktree add`) — not jj workspaces. All git-worktree dirs share the same
`.jj/repo/` backend (one `op_heads`, one shared view) and all default to
`WorkspaceName = "default"`, so concurrent agents race the same `@` slot.
Per the jj docs ([Git compatibility](https://docs.jj-vcs.dev/latest/git-compatibility/)),
running jj inside a `git worktree add` directory with shared `.jj/` is
**explicitly unsupported**.

**Fix: every jj-writing agent should call `jj workspace add` as its first
step, before reading any status file or making any edit.** This gives each
agent a distinct `WorkspaceName` and an independent `@` slot, and op-merging
between workspaces is well-defined per the
[jj concurrency docs](https://docs.jj-vcs.dev/latest/technical/concurrency/).

Standard boilerplate for every feat-* / harness-maintainer / ops-data agent:

```bash
# === Pre-work: create isolated jj workspace ===
# Claude Code's isolation:"worktree" creates a git-worktree, NOT a jj-workspace.
# Without this step, concurrent agents race the shared op_heads / default WorkspaceName.
# See .claude/rules/worktree-isolation.md §"jj workspace isolation".
#
# CRITICAL: the workspace MUST live under the repo (.claude/worktrees/) so it is
# visible inside the Docker container via the bind-mount. A /tmp path is
# INVISIBLE to `docker exec trading-1-dev` — the agent would edit files jj+host
# can see but dune (run in the container) cannot, silently building the parent
# tree instead. This was the 2026-06-07 contamination root cause. See
# memory/project_jj_workspace_docker_path.

AGENT_ID="${HOSTNAME}-$$-$(date +%s)"
AGENT_WS=".claude/worktrees/jjws-${AGENT_ID}"          # repo-local → container-visible
jj workspace add "$AGENT_WS" --name "$AGENT_ID" -r main@origin
cd "$AGENT_WS"

# Verify isolation: the new workspace's @ should be off main@origin
jj log -n 1 -r @

# Run EVERY dune command against THIS workspace's trading dir (NOT the parent):
#   docker exec trading-1-dev bash -c \
#     'cd /workspaces/trading-1/'"$AGENT_WS"'/trading && eval $(opam env) && dune build'
# If you cd the container to /workspaces/trading-1/trading you build the parent,
# not your edits — that is the bug this whole section exists to prevent.
```

**After work is complete, clean up:**

```bash
# From the repo root (not inside AGENT_WS):
jj workspace forget "$AGENT_ID"
rm -rf "$AGENT_WS"
```

**Notes:**
- `$AGENT_WS` is **repo-local** (`.claude/worktrees/jjws-…`) so it is bind-mounted
  into the container; jj runs on the host, dune runs in the container, and both
  see the same files. A `/tmp` path breaks this (host-only) — never use it.
- The `-r main@origin` flag ensures the new `@` starts from main, not from
  whatever `@` the parent had at dispatch time.
- This fix applies to local jj runs only. GHA runs use `$TRADING_IN_CONTAINER`
  mode (plain git, no jj) and are unaffected.
- Reference: `memory/project_jj_worktree_root_cause.md` +
  `memory/project_jj_workspace_docker_path.md` (root cause writeups).

## Finish Protocol (required — prevents lost-work / un-opened PRs)

The 2026-06-07 session lost three feat-agent commits because agents (a)
backgrounded the final `dune runtest` and ended the turn "standing by" before
ever committing, and (b) relied on workspace isolation to protect *uncommitted*
state. The work survived only because it could be recovered from disk by hand.

Every jj-writing agent MUST finish with this exact sequence, **in the foreground,
as its last actions, without ending the turn in between:**

1. **Verify in the foreground.** Run `dune build @fmt && dune build && dune runtest`
   and read the **exit code** (not a `grep FAIL:` — OUnit failures and some
   linters don't print that literal; and `… | tail; echo $?` captures `tail`'s
   exit, not dune's). Blocking ~10 min here is expected and correct. Do NOT
   background it and wait for an event.
2. **Commit → bookmark → push → open PR, atomically:**
   `jj describe -m "…"` → `jj bookmark set feat/<name> -r @` →
   `jj git push -b feat/<name>` → `gh pr create …`.
3. **Verify the push landed:** `jj diff -r @ --stat` must list your files (a
   commit that shows 0 files = the working copy never snapshotted into it — STOP
   and fix) **and** `gh pr view <N> --json files` must show them.
4. **On any push/PR failure:** retry once; if it still fails, report the
   **bookmark name + commit id + "PR NOT opened"** explicitly so the dispatcher
   can open it (the dispatcher's recovery path, `feat-agent-dispatch.md` §2).

Never end a turn with an un-pushed commit. The PR being open on origin is the
only durable proof of done — a green local build that was never pushed is lost
work.

## Cleanup

Stale `agent-*` worktrees accumulate in `.claude/worktrees/` after each session
and consume disk space (typically 50–150 MB each). A `SessionStart` hook in
`.claude/settings.json` automatically invokes the sweep script at the start of
every Claude Code session.

**Script:** `dev/scripts/sweep_stale_worktrees.sh`

**Auto-detection trigger:** runs at every `SessionStart`; only sweeps when disk
usage on the repo filesystem is ≥ 85% **and** the worktree mtime is older than
24 hours. Both thresholds are configurable via CLI flags.

**Lock honoring (2026-05-08):** Claude Code marks active agent worktrees as
`locked` via `git worktree add --lock`. The sweep script parses
`git worktree list --porcelain` once per run and skips any candidate in the
locked set, regardless of age. This prevents the script from removing worktrees
that belong to in-progress agents. When a worktree is skipped, the log records:
`skipping locked worktree: <path> (active subagent)`.

**Flags:**

| Flag | Default | Notes |
|---|---|---|
| `--threshold-percent N` | 85 | Sweep only when disk ≥ N% (unless --force) |
| `--stale-hours H` | 24 | Remove worktrees older than H hours. Must be ≥ 1. |
| `--dry-run` | off | Print candidates without deleting |
| `--force` | off | Skip the disk-threshold check |
| `--include-active` | off | Emergency override: also remove locked worktrees. Must be combined with `--stale-hours >= 1`. |

**`--stale-hours 0` is rejected** (exits 1). A value of 0 would capture every
worktree including ones created moments ago by a live agent. Operators who need
an emergency removal of active worktrees should use `--include-active` with a
real `--stale-hours` value.

**Manual invocation:**

```bash
# Dry-run: see what would be removed (no deletions, locked worktrees flagged)
bash dev/scripts/sweep_stale_worktrees.sh --dry-run --force

# Force sweep regardless of disk level, 24h+ stale (locked worktrees skipped)
bash dev/scripts/sweep_stale_worktrees.sh --force

# Custom thresholds
bash dev/scripts/sweep_stale_worktrees.sh --threshold-percent 70 --stale-hours 48

# Emergency: sweep even active/locked worktrees (use with caution)
bash dev/scripts/sweep_stale_worktrees.sh --force --include-active --stale-hours 1
```

Logs append to `dev/logs/worktree-sweep-YYYY-MM-DD.log`.
