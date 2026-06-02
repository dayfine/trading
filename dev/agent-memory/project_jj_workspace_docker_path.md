---
name: jj workspace must live under repo bind-mount, not /tmp
description: The `jj workspace add /tmp/...` boilerplate from worktree-isolation.md does NOT work for docker-based commands. Container bind-mounts /Users/difan/Projects/trading-1 only; /tmp/agent-ws-* is invisible inside the container, so dev/lib/run-in-env.sh fails silently.
type: project
originSessionId: 62a91729-bd17-40ce-ab8e-226d718d658a
---
## Problem

`.claude/rules/worktree-isolation.md` boilerplate says:

```bash
AGENT_ID="${HOSTNAME}-$$-$(date +%s)"
AGENT_WS="/tmp/agent-ws-${AGENT_ID}"
jj workspace add "$AGENT_WS" --name "$AGENT_ID" -r main@origin
cd "$AGENT_WS"
```

But the docker container `trading-1-dev` only bind-mounts `/Users/difan/Projects/trading-1`. Anything under `/tmp/` on the host is invisible inside the container. Running `dev/lib/run-in-env.sh dune build` from `/tmp/agent-ws-...` ends up running dune in the wrong path inside the container — it falls back to `/workspaces/trading-1/trading` (the parent worktree) and either silently fails or builds the wrong tree.

## Fix

Use a path UNDER the bind-mount:

```bash
AGENT_ID="${HOSTNAME}-$$-$(date +%s)"
AGENT_WS="/Users/difan/Projects/trading-1/.claude/worktrees/agent-${AGENT_ID}"
jj workspace add "$AGENT_WS" --name "$AGENT_ID" -r main@origin
cd "$AGENT_WS"
```

`.claude/worktrees/` is under the repo root, so it IS bind-mounted. The wrapper's path resolution logic handles the worktree case (see `_REL_PATH` block in `dev/lib/run-in-env.sh`).

## Reference

- First documented: 2026-05-06 on PR #877 ocamlformat rework dispatch (agent `ac2ab3a0c0251ecfd`)
- The current `worktree-isolation.md` boilerplate is wrong for any agent that uses `dev/lib/run-in-env.sh` — should be updated to use `.claude/worktrees/` instead of `/tmp/`.

## How to apply

When dispatching a feat-* / fix-* agent that needs docker-based commands:
- Override the worktree-isolation boilerplate's `/tmp/` path
- Use `.claude/worktrees/agent-<id>/` instead
- Also check that the worktree was actually created under the right path before running dune
