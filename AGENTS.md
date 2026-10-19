# AGENTS.md

## Working in this repository as a coding agent (Codex, Cursor, others)

Two agents share this directory in practice (a Claude Code session drives the
repo with `jj`; Codex is run alongside it). These rules exist because the
primary checkout is a **jj workspace that snapshots the working copy
continuously**: any file you create here becomes part of whatever change is
currently `@`, and `jj` run from any subdirectory or worktree addresses this
same workspace. On 2026-09-13 a Codex-written file rode into an unrelated PR
this way, and a concurrent Codex `dune build` corrupted the shared dune cache.

1. **Never work in the primary checkout.** First step of every task: create
   your own detached git worktree **under the repo** (so the container's
   bind-mount can see it — a `/tmp` path is invisible to `docker exec`):
   ```bash
   git fetch origin main
   git worktree add --detach .claude/worktrees/codex-<task>-$$ origin/main
   cd .claude/worktrees/codex-<task>-$$
   ```
   Do all edits, builds, commits and pushes there with **plain `git`**. Never
   run `jj` (any subcommand) — it is the dispatcher's tool and it mutates the
   parent workspace. Remove the worktree when the PR is open
   (`git -C <repo> worktree remove --force <path>`).
2. **Every dune command runs inside the container against YOUR worktree:**
   ```bash
   docker exec trading-1-dev bash -c \
     'cd /workspaces/trading-1/.claude/worktrees/<your-worktree>/trading && eval $(opam env) && export TRADING_DATA_DIR=$PWD/test_data && dune build'
   ```
   `cd /workspaces/trading-1/trading` builds the parent tree, not your edits.
   Native host `dune` reports ENVFAIL from opam/ocamlformat skew, not from your
   change.
3. **One `dune build`/`runtest` in flight at a time, repo-wide.** The dune
   cache is shared across worktrees; check `docker exec trading-1-dev sh -c
   'ps -eo args | grep [d]une'` first. Never build while a multi-hour backtest
   holds the container (`docker exec trading-1-dev sh -c 'ps -eo args | grep
   [s]cenario_runner'`) — see `.claude/rules/container-capacity-scheduling.md`.
4. **Docs-only PRs need no build.** If your diff is only `*.md` /
   `dev/notes|plans|reviews|status`, skip dune entirely; CI is the gate.
5. **Branch, commit, PR conventions** are in `CLAUDE.md` (branch names,
   commit trailers, incremental commits) and `.claude/rules/pr-merge-gates.md`
   (three gates; never merge yourself; never `--admin`). Never write
   `dev/status/_index.md` from a feature PR. Never `gh pr merge` or
   `gh pr review --approve`.
6. **Reviews you post are machine-parsed.** Follow
   `docs/howtos/codex_pr_reviews.md` §3 exactly (first line `Reviewed SHA:`,
   own-gate first heading, `## Verdict`), and post as a PR review, not an
   issue comment.
7. **Don't touch what you didn't create:** other agents' worktrees under
   `.claude/worktrees/`, `.sweep-output/`, container `/tmp/snap_*` warehouses,
   running processes, or `~/.codex` / `.claude` settings.

The per-project Codex command policy lives in `.codex/rules/trading.rules`
(PR #2786); the sandbox is a separate control and should stay on.

## User communication (user directive, 2026-10-19)

Make routine implementation decisions autonomously and document them in the
PR or issue. Do not interrupt the user with clarification questions. If blocked,
post the concrete blocker or question on the relevant GitHub issue, where it
will be answered, and continue unaffected work.

## Issue assignment protocol (how work is handed to an agent)

GitHub assignees cannot distinguish agents here (every agent runs as the same
account), so **ownership is a label**, and the workflow state is the existing
triage role (`.claude/skills/triage-labels.md`).

| label | meaning |
|---|---|
| `ready-for-agent` | fully specified; an agent may start without asking |
| `agent/codex` | owner is Codex |
| `agent/claude` | owner is the local Claude Code session or a feat-agent it dispatches |
| (no owner label) | the GHA orchestrator or whoever triages next; Codex does not take it |

**Codex's loop:**

1. **Pick** the open issue with `ready-for-agent` + `agent/codex` and the highest
   priority (`P0` > `P1` > `P2` > `P3`; lowest number breaks ties). Never take an
   issue carrying `agent/claude`, `needs-info`, `ready-for-human` or `do-not-merge`.
2. **Claim** before touching anything: comment on the issue
   `claimed by codex <UTC timestamp> — worktree .claude/worktrees/codex-<issue>-<slug>`.
   If the latest comment is already a claim younger than 24 h from any agent, skip it.
3. **Work** in that worktree per the rules above. Branch `codex/<issue>-<slug>`;
   push with `sh dev/scripts/codex_push.sh` (no arguments);
   commits follow `CLAUDE.md`; the PR body starts with `Closes #<issue>` and has a
   Test plan written from the diff (`grep '>::'` for OCaml tests; the script's own
   check count for shell). One issue per PR.
4. **Report** on the PR, not the issue: rework commits are second commits
   (`fix(review): address QC rework iteration N (#PR)`), never amends.
5. **Blocked or out of scope?** Comment on the issue starting with `BLOCKED:` and
   what is needed, swap `ready-for-agent` for `needs-info` (or `ready-for-human`),
   and stop. Do not widen the task.
6. **Done** = the PR is open with CI green. Merging is the dispatcher's or a
   human's; the merge's `Closes #<issue>` closes the issue. Remove your worktree.

## Cloud agents (Codex cloud, Jules): rules that differ from the local ones above

Cloud agents run in their own VM with no `trading-1-dev` container. Rules 1–3 above (worktree under the repo, `docker
exec`, one dune at a time) do not apply. Use these instead (lessons from #3333 and #3334, 2026-10-18):

1. **Build and test focused targets only.** Disk is about 32 GB and a full build about 13 GB. Run `dune build @fmt`,
   then `dune build <dirs you touched>`, then `dune runtest <dirs you touched>` from `trading/` (Codex cloud: with the
   workspace in `.codex/README.md`). CI runs the full build, the linters and the full runtest.
2. **`dune build @fmt` must show no diff before every push.** Warnings printed by ocamlformat about doc comments in
   other files are pre-existing on main; leave them alone. A diff fails CI.
3. **Stay inside the brief.** Touch only the files the issue or hand-off comment names, plus their tests. Never "fix"
   unrelated files to quiet a warning.
4. **Put the issue link in the PR body when you open the PR.** Use `Closes #N` (every item done) or
   `Refs #N -- remaining: <items>`, and list each item with the test or check that proves it. A bot may not be able to
   edit the body afterwards.
5. **Rework arrives as an `@codex` / `@jules` comment** linking a Claude QC review, with "iteration N of 2". Address
   every failed item, add no new scope, push it as a new commit (never amend or force-push), and reply on the PR with
   what changed. If you cannot do something (edit the PR body, reach the network), say so plainly; don't report it as
   done.
6. **Network:** package managers only, no GitHub token in the environment. PRs and replies go through your GitHub app.
7. **Whose turn it is** is shown on the pinned lane board (#3330) and as `turn/*` labels. Merging is always Claude's,
   after CI and both Claude QC gates.

### Jules: evidence in every reply (added after #3333)

On #3333 two replies said "done" for things that had not happened: a PR-body edit with an empty commit, and a format fix
whose CI stayed red after touching out-of-scope files. GitHub, not the reply, is what Claude checks. These rules make the
reply match it:

1. **Before every push**, run and keep the output of:
   ```sh
   git fetch origin main
   git diff --stat origin/main...HEAD      # must list only the files in the brief
   cd trading && dune build @fmt           # must print no diff (warnings are fine)
   ```
   plus the focused `dune build` / `dune runtest` for the directories you touched.
2. **Every reply on a PR pastes that output**: the `git diff --stat`, the `@fmt` result and the test summary line. Add
   the commit SHA you pushed. A reply without them is treated as "not done".
3. **If a step is impossible for you** (editing the PR body, reaching the network, a command that fails), write
   `CANNOT: <step> — <why>` and stop. Never describe it as done.
4. **One commit per request**, pushed on top (no amend, no force-push). If main moved and the PR conflicts, merge
   `origin/main` and keep both sides; say which files conflicted.
5. **Do not widen scope.** If a fix seems to need a file outside the brief, ask on the PR first with `QUESTION:`.

## Cross-agent review (`.claude/rules/cross-agent-review.md`)

- Add the label `author/codex` to every PR you open. It goes through the same
  gate loop as any PR: CI + qc-structural + qc-behavioral, both **Claude Code**
  reviews, then the dispatcher merges. Your own review of your own PR is not a
  gate.
- When you are asked to review a PR (or `review/codex-requested` is on it), the
  dispatcher runs `sh dev/scripts/codex_review.sh <PR>`, which invokes you
  read-only and posts the result. Your report opens with `Reviewed SHA: <full
  sha>`, its first heading is `## Codex review — <title>`, and it ends with
  `## Verdict` → `APPROVED` or `NEEDS_REWORK`. **Never** use the headings
  `## Structural QC`, `## Behavioral QC` or `## qc-…` — they name the Claude
  merge gates and the poster refuses such a report.
- Do not run dune during a review; the review is advisory and consumes no
  container slot.

**Dispatcher side (Claude Code / human):** triage new issues (`needs-triage` →
role + `kind/`/`size/`/`impact/`/`P` grades), add `agent/codex` to bounded,
verifiable items (docs, shell with a test harness, single-module OCaml with
TDD; no multi-hour backtests, no domain judgment calls), run the gate loop on
Codex's PRs (`.claude/rules/pr-gate-loop.md`), merge, and move the owner label
if an item is taken over (`agent/codex` → `agent/claude`, with a comment).

## Cursor Cloud specific instructions

### Overview

This is an OCaml 5.3 algorithmic trading simulation and backtesting system. All development happens inside the `trading-1-dev` Docker container. There is no web UI, database, or external service required for building and testing.

### Running commands

All build/test/format commands must run inside the Docker container:

```bash
docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && <command>'
```

See `CLAUDE.md` for the full list of essential commands (`dune build`, `dune runtest`, `dune fmt`, etc.).

### Starting the container

If the container is not running, start it with:

```bash
docker start trading-1-dev
```

If it does not exist (e.g., after a fresh VM snapshot), rebuild and start:

```bash
docker build -t trading-1-dev -f /tmp/Dockerfile.trading /workspace
docker run -d --name trading-1-dev -v /workspace:/workspaces/trading-1 -w /workspaces/trading-1/trading trading-1-dev tail -f /dev/null
```

The update script handles image building and container creation automatically.

### Known issues

- **`segmentation_test` floating-point failure**: The test `test_complex_segmentation` in `analysis/technical/trend/test/` fails due to minor floating-point precision differences across platforms (differences in ~10th decimal place). This is a pre-existing issue, not caused by code changes.

- **opam `async_unix` recompile bug with fuse-overlayfs**: When installing dev tools (ocaml-lsp-server, ocamlformat, utop, odoc) via `opam install` in a Docker image built on fuse-overlayfs, the `async_unix` package fails to recompile with "File exists" errors. The workaround is to skip dev tools in the Docker image build, then install them inside the running container after clearing the stale library directory (`rm -rf ~/.opam/5.3/lib/async_unix/*`). The update script handles this automatically.

### Project structure

Refer to `CLAUDE.md` for architecture details, code patterns, test patterns, and the development workflow (TDD, incremental changes, etc.).
