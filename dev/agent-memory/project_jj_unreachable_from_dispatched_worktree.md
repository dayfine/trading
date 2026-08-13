---
name: project_jj_unreachable_from_dispatched_worktree
description: "CONFIRMED 2x on 2026-08-12: inside a Claude-Code-dispatched git worktree, `jj` resolves to the PARENT repo's default workspace — `jj workspace root` returns the parent path. So the documented `jj workspace add` boilerplate is unreachable there, and any `jj describe`/`jj status` an agent runs silently reads/mutates the parent. Agents must use plain git in dispatched worktrees."
metadata: 
  node_type: memory
  type: project
  originSessionId: fb5eee5b-32ea-4e7b-9429-8f3f1f94d659
  modified: 2026-08-13T08:07:48.506Z
---

**Two independent agents hit this on 2026-08-12**, on unrelated PRs:

1. The scale-in retirement agent (#2299): *"The harness placed me in a git
   worktree on its own branch and refuses any command targeting the parent
   checkout, so `jj workspace add` was not reachable. Worse, running `jj` from
   inside this worktree resolves to the parent's `default@` workspace — a
   `jj describe` here would have snapshotted the parent working copy."*
   It used plain git instead and produced a clean PR.
2. The #2300 structural agent: `jj status` / `jj diff` inside its worktree were
   *"silently operating on the parent repo's shared jj default workspace —
   `jj workspace root` resolved to `/Users/difan/Projects/trading-1`, not my
   worktree."* Its first build/test pass therefore ran **against the wrong tree**
   (a stale base commit lacking the PR's files). It recovered with plain
   `git fetch` + `git checkout --detach <sha>`, then redid every check.

**Why this matters more than the existing rule says.**
`.claude/rules/worktree-isolation.md` §"jj workspace isolation" instructs every
jj-writing agent to run `jj workspace add .claude/worktrees/jjws-<id>` as its
first step. That instruction assumes `jj` in the dispatched worktree addresses
*that* worktree. It does not — it addresses the parent. So the boilerplate is
not merely awkward, it is the thing that causes the contamination it was written
to prevent: an agent following it runs `jj` commands that mutate the parent's
shared `@`.

**What actually works** (both agents converged on it independently):
- In a **dispatched** worktree: use **plain git**. The harness already gave the
  agent an isolated worktree on its own branch; git commands there touch only
  that worktree, commits land in the shared object DB, and jj imports them
  normally afterwards. No `jj workspace forget` cleanup is owed.
- From the **parent** session (the dispatcher): `jj workspace add` is fine and
  is the right tool — that is where the rule's boilerplate belongs.

**Dispatcher-side consequences observed the same night:**
- A commit authored by an agent via git had no author/committer set, and
  `jj git push` rejected it (`Won't push commit … since it has no author`).
  Fix: `jj --config user.name=… --config user.email=… describe --reset-author`.
- When the dispatcher creates its *own* jj workspace at an agent's commit, the
  new `@` can land stacked on a *sibling* agent's in-flight commit rather than
  the intended branch — the ancestry leak in `worktree-isolation.md`. Always
  check `jj log -r '::<change> & ~::main@origin'` before pushing and
  `jj rebase -r <change> -d <branch>` if it is wrong.

Related: [[project_jj_worktree_root_cause]], [[project_jj_workspace_docker_path]],
[[feedback_agents_background_wait_stall]].
