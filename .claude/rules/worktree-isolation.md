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

AGENT_ID="${HOSTNAME}-$$-$(date +%s)"
AGENT_WS="/tmp/agent-ws-${AGENT_ID}"
jj workspace add "$AGENT_WS" --name "$AGENT_ID" -r main@origin
cd "$AGENT_WS"

# Verify isolation: the new workspace's @ should be off main@origin
jj log -n 1 -r @
```

**After work is complete, clean up:**

```bash
# From the repo root (not inside AGENT_WS):
jj workspace forget "$AGENT_ID"
rm -rf "$AGENT_WS"
```

**Notes:**
- `$AGENT_WS` is under `/tmp/` — outside the repo — so it cannot contaminate
  the parent worktree's git index.
- The `-r main@origin` flag ensures the new `@` starts from main, not from
  whatever `@` the parent had at dispatch time.
- This fix applies to local jj runs only. GHA runs use `$TRADING_IN_CONTAINER`
  mode (plain git, no jj) and are unaffected.
- Reference: `memory/project_jj_worktree_root_cause.md` (root cause writeup).

## Cleanup

Stale `agent-*` worktrees accumulate in `.claude/worktrees/` after each session
and consume disk space (typically 50–150 MB each). A `SessionStart` hook in
`.claude/settings.json` automatically invokes the sweep script at the start of
every Claude Code session.

**Script:** `dev/scripts/sweep_stale_worktrees.sh`

**Auto-detection trigger:** runs at every `SessionStart`; only sweeps when disk
usage on the repo filesystem is ≥ 85% **and** the worktree mtime is older than
24 hours. Both thresholds are configurable via CLI flags.

**Manual invocation:**

```bash
# Dry-run: see what would be removed (no deletions)
bash dev/scripts/sweep_stale_worktrees.sh --dry-run --force

# Force sweep regardless of disk level, 24h+ stale
bash dev/scripts/sweep_stale_worktrees.sh --force

# Custom thresholds
bash dev/scripts/sweep_stale_worktrees.sh --threshold-percent 70 --stale-hours 48
```

Logs append to `dev/logs/worktree-sweep-YYYY-MM-DD.log`.
