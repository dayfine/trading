---
name: jj contamination root cause — git worktree + colocated jj is unsupported
description: Claude Code's isolation:worktree creates git-worktree dirs, not jj-workspace dirs. All share one .jj/repo/ backend with one op_heads + one default WorkspaceName, so concurrent agents race the same @ slot. Documented unsupported per jj docs.
type: project
originSessionId: df52077d-2210-44cb-9ffa-9aa47ab572ee
---
**The contamination is fundamental to the current runtime config**, not a workflow tuning issue.

`isolation: "worktree"` in Claude Code creates `git worktree add` directories under `.claude/worktrees/agent-*/`. They share the colocated repo's `.jj/` and `.git/`. Per the jj docs (`Git compatibility` page): "git-worktree: No. However, there's native support for multiple working copies … See the `jj workspace` family of commands". Running jj commands inside a git-worktree-with-shared-jj-backend is **explicitly unsupported**.

**Mechanism of cross-agent file-and-revert contamination:**

- One `.jj/repo/` backend = one `op_heads/`, one `view`, one per-workspace working-copy-commit map
- jj identifies a workspace by `WorkspaceName` (recorded in `.jj/working_copy/`), NOT physical path
- Raw `git worktree add` directories all default to `WorkspaceName = "default"` — they collide on the same `@` slot in the shared view
- jj auto-snapshots the working copy at the start of nearly every command — `jj git fetch`, `jj new`, `jj log`, etc. — using the *current cwd*'s files
- When two workspaces concurrently rewrite operations, jj merges via 3-way view merge — but working-copy reconciliation is non-deterministic (issues #7538, #8737, #8929)
- Reverted-edits-mid-session = jj issue [#8929](https://github.com/jj-vcs/jj/issues/8929) "files differ after import": sibling op rewrites @'s tree, next snapshot reconciles to the other tree, your edit vanishes

**How to apply (until harness is fixed):**

- Rule stays: ≤1 concurrent jj-writing agent in this repo. Read-only QC agents OK to run concurrent with one feat-* agent.
- After observed contamination event, do not jj-edit / jj-restore / jj-abandon while another agent is running — the operations cascade. Wait for the agent to push and exit, then clean up.
- Closed-and-redo is often cheaper than fix-in-place when an agent's PR has stray cross-leak files. Example 2026-05-04: PR #836 (docs-only intent) ended up with 8 stray `val *_of_snapshot_views` declarations from sibling F.3.c work; closing + re-filing was cleaner than untangling the squash conflicts.

**Two viable harness fixes (file under harness track):**

1. **`jj workspace add <path>`** per agent instead of `git worktree add` — distinct `WorkspaceName` per agent, separate `@` slot in the shared view. Op-merging is well-defined per the jj concurrency docs. Cheap; no separate clones.
2. **Full `jj git clone`** per agent — separate `.jj/repo/` backends entirely. No op-log races even in pathological cases. Higher disk cost but bulletproof. This is what Panozzo recommends for AI-agent workflows (https://www.panozzaj.com/blog/2025/11/22/avoid-losing-work-with-jujutsu-jj-for-ai-coding-agents/).

The Claude Code runtime's `isolation: "worktree"` should be configurable to choose mode (1) or (2). Until then, ≤1 concurrent jj-writer is the only safe practice.

**References:**
- jj docs: https://docs.jj-vcs.dev/latest/technical/architecture/
- jj working-copy concept: https://docs.jj-vcs.dev/latest/working-copy/
- jj concurrency: https://docs.jj-vcs.dev/latest/technical/concurrency/
- jj git compatibility: https://docs.jj-vcs.dev/latest/git-compatibility/
- Panozzo on AI-agent workflows with jj: https://www.panozzaj.com/blog/2025/11/22/avoid-losing-work-with-jujutsu-jj-for-ai-coding-agents/
- Slava Kurilyak parallel jj method: https://slavakurilyak.com/posts/parallel-claude-code-with-jujutsu
- jj-navi (workspace-add wrapper): https://github.com/eersnington/jj-navi
- Smoking-gun issue #8929 (file revert via sibling op): https://github.com/jj-vcs/jj/issues/8929
