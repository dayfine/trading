# Invoking Codex for PR reviews from another CLI

> **Status (2026-09-13, `.claude/rules/cross-agent-review.md`, PR #2798):** the
> default integration is **advisory**. `sh dev/scripts/codex_review.sh <PR>` runs
> Codex read-only against the PR head, validates the report, and posts it under
> `## Codex review — <title>`, which the `CODEX` column of
> `pr_gate_status.sh` reads. The merge gates stay CI + Claude qc-structural +
> Claude qc-behavioral for every PR. §§4–6 below describe the **promotion
> path** — Codex playing the gate roles under the gate headings — which is NOT
> enabled and would need its own rule change once the advisory column has
> agreed with the Claude gates across enough PRs. §§0–3 apply to both.

An orchestrator (Claude CLI, a GHA step, a shell controller) can run Codex as a
subprocess to play the project's two review roles:

1. Structural QC — `.claude/agents/qc-structural.md`
2. Behavioral QC — `.claude/agents/qc-behavioral.md`

Run them in that order. Behavioral QC runs only after structural QC has
returned `APPROVED` for the **same head SHA** (`.claude/rules/pr-gate-loop.md`).
The controller — not Codex — owns authentication, the worktree, the
structural→behavioral gate, verdict parsing, posting, and cleanup. Codex gets
review authority only.

Measured against `codex-cli 0.154.0`: `codex exec review --base <branch>` **refuses a
custom `[PROMPT]`** ("the argument '--base <BRANCH>' cannot be used with
'[PROMPT]'" — the first live run of `codex_review.sh` on #2798 hit exactly this). The
working shape is plain `codex -C <worktree> exec --ephemeral -o <file> "<prompt>"`, with
the prompt naming the PR and telling Codex to read the change via `gh pr diff <N>` in
the detached checkout; `--ephemeral`, `--json` and `-o/--output-last-message` are real
`exec` flags.

## 0. Two rules that apply before anything else

- **Docs-only PRs skip both QC gates.** If every file in `gh pr view <N> --json
  files` is under `dev/notes/`, `dev/plans/`, `dev/reviews/`, `dev/status/` or
  is a `*.md`, do not invoke Codex at all — CI is the only gate
  (`.claude/rules/pr-merge-gates.md` §Docs-only). Running the build gates on a
  docs PR burns container memory next to live backtests for nothing.
- **Codex never works in the primary checkout.** Everything below happens in a
  worktree the controller creates for the task (§2). The primary checkout is a
  jj workspace that snapshots continuously: a file another process writes there
  becomes part of whatever change is `@`, and jj run from any worktree
  addresses that same workspace. See `AGENTS.md` §"Working in this repository
  as a coding agent".

## 1. The PR is the canonical input

Pass the PR number, the repository path and the review role to every
invocation. Scope comes from `gh pr view <N> --json
files,title,body,headRefName,headRefOid`, never from commit ancestry —
concurrent agents leave unrelated commits in the graph, and the A3 rule in
`.claude/rules/qc-structural-authority.md` is measured against the PR's file
list for exactly that reason. The `--base` diff Codex computes is *context*
for the reviewer, not the scope.

## 2. Worktree — repo-local, so the container can see it

Every dune gate the roles run (`dune build @fmt`, `dune build`, `dune
runtest`) must execute **inside `trading-1-dev`, against the reviewer's own
checkout** (`.claude/rules/qc-structural-authority.md` §"Operational
requirements", `.claude/rules/worktree-isolation.md`). The container
bind-mounts the repo at `/workspaces/trading-1`, so the worktree has to live
under the repo — a `/tmp` path is invisible to `docker exec`, and a native
host `dune` run reports ENVFAIL from the ocamlformat / opam skew, not from
the PR.

```bash
PR_NUMBER=2784
REPO=/Users/difan/Projects/trading-1            # host path
NAME="codex-qc-pr-${PR_NUMBER}-$$"
WORKTREE="$REPO/.claude/worktrees/$NAME"        # host path
CWT="/workspaces/trading-1/.claude/worktrees/$NAME"   # the same dir inside the container

cd "$REPO"
HEAD_SHA="$(gh pr view "$PR_NUMBER" --json headRefOid --jq .headRefOid)"
git fetch origin "pull/${PR_NUMBER}/head"
git worktree add --detach "$WORKTREE" "$HEAD_SHA"
```

Plain `git` only — never `jj` inside a dispatched worktree (it addresses the
parent workspace). Remove the worktree after both reports are collected:

```bash
git -C "$REPO" worktree remove --force "$WORKTREE" && git -C "$REPO" worktree prune
```

The dune gate incantation the reviewer must use (put it in the prompt
verbatim; `cd /workspaces/trading-1/trading` would build the parent tree):

```bash
docker exec trading-1-dev bash -c \
  "cd $CWT/trading && eval \$(opam env) && export TRADING_DATA_DIR=\$PWD/test_data && dune build @fmt && dune build && dune runtest"
```

**One `dune` at a time across all agents.** Dune's shared cache is one
directory for every worktree; two full builds of the same sources in flight
corrupt each other (observed 2026-09-13: a Codex build alongside a dispatcher
build produced a spurious "module alias is missing" failure that a clean
rebuild cured). Capacity: at most 3 concurrent reviewers, **one** dune
build/runtest in flight, and never while a multi-hour backtest holds the
container (`.claude/rules/container-capacity-scheduling.md`).

### Sandbox decision — pick A or B, and use that section's invocation

Codex's default sandbox will not reach the Docker socket.

- **A — Codex runs the build gate.** Grant only what `docker exec` needs
  (e.g. `-c 'sandbox_permissions=["disk-full-read-access"]'` plus the socket
  access the local Codex version requires) and keep every other restriction.
  No blanket bypass. Use the §4-A / §5 invocations.
- **B — CI is the build gate.** Codex reviews the pattern / architecture /
  contract rows only; the report records H1–H3 as `PASS (CI run <id>)` with
  the `gh pr checks` evidence the controller passes in. Cheaper, and it
  matches how the dune-wired linters are already trusted
  (`.claude/rules/pr-merge-gates.md` §"Why each gate matters"). Use §4-B.

## 3. The report format is machine-parsed

`dev/scripts/pr_gate_status.sh` decides each PR's next action by reading PR
**reviews** (not issue comments). The canonical template is the one in the
agent files; every prompt must require it and the controller must verify it
before posting:

1. **First body line exactly** `Reviewed SHA: <full 40-char sha>` — the
   idempotency sentinel (`.claude/agents/qc-structural.md` Step 5; the parser
   falls back to the review's `commit_id` only when this line is missing).
2. **First heading** `## Structural QC — <PR title or feature>` or
   `## Behavioral QC — <…>`. Gate attribution uses the review's FIRST heading
   only and anchors on its start, so it must name **its own gate and nothing
   else**; interior headings are prose.
3. Then the role's checklist table, `## Quality Score` (1–5, 5 = best), a
   `## Verdict` section whose next non-blank line is exactly `APPROVED` or
   `NEEDS_REWORK`, then `## NEEDS_REWORK Items` when applicable (Finding /
   Location / Authority / Required fix / harness_gap per item).
4. **The other gate is never mentioned anywhere in the body.** The behavioral
   prompt tells Codex which structural SHA it is building on — that sentence
   must not be echoed into the report (the #2620 false-green mode). Reject a
   behavioral report containing the word "structural", and vice versa.

Posting is **mandatory for both verdicts** — a NEEDS_REWORK report is the
rework brief. Post as a PR review pinned to the reviewed SHA:

```bash
gh api -X POST "repos/dayfine/trading/pulls/${PR_NUMBER}/reviews" \
  -f event=COMMENT -f commit_id="$HEAD_SHA" -F body=@"$REPORT"
gh api "repos/dayfine/trading/pulls/${PR_NUMBER}/reviews" \
  --jq '.[] | "\(.id) \(.commit_id[0:9]) \(.submitted_at)"'   # your row must show the head SHA
sh dev/scripts/pr_gate_status.sh "$PR_NUMBER"                    # STRUCT/BEHAV column reads ok / rework
```

`gh pr comment` creates an issue comment, which the gate reader never sees.
`-F body=@file` reads the file; `-f body=@file` sends the literal path.
(`gh pr review --comment --body` also creates a review and is equivalent.)

## 4. Structural review (promotion path — not enabled; see the status note at the top)

Common prompt body (both variants):

```
Review PR #${PR_NUMBER} (head ${HEAD_SHA}) as qc-structural.
Protocol: .claude/agents/qc-structural.md plus the project rows in
.claude/rules/qc-structural-authority.md (P6, A1, A2, A3); also apply
.claude/rules/experiment-flag-discipline.md R1-R3,
.claude/rules/config-default-blast-radius.md B1-B3 and
.claude/rules/test-patterns.md where the diff touches strategy config or tests.
Scope = 'gh pr view ${PR_NUMBER} --json files,title,body,headRefName,headRefOid';
the --base diff is context only.
Report: first line exactly 'Reviewed SHA: ${HEAD_SHA}'; first heading
'## Structural QC — <PR title>'; then the checklist, '## Quality Score',
'## Verdict' (next line exactly APPROVED or NEEDS_REWORK), '## NEEDS_REWORK Items'.
Do not mention any other review gate. Do not modify files, commit, push, or post to GitHub.
```

**4-A (Codex runs the gates)** — append:

```
Build gate: run every dune command inside the container against THIS checkout:
docker exec trading-1-dev bash -c 'cd ${CWT}/trading && eval $(opam env) && export TRADING_DATA_DIR=$PWD/test_data && dune build @fmt && dune build && dune runtest'
(never cd /workspaces/trading-1/trading). Read exit codes, not greps. Record H1/H2/H3 from those exits.
```

**4-B (CI is the gate)** — append instead, after the controller has confirmed
`gh pr checks ${PR_NUMBER}` is all `pass` at `${HEAD_SHA}`:

```
Do NOT run dune. H1/H2/H3 are supplied by CI: record each as
'PASS (CI: build-and-test run ${RUN_ID} at ${HEAD_SHA})' using the evidence below, and review only
P1-P6 / A1-A3 / R1-R3 / B1-B3 from the source.
<paste `gh pr checks ${PR_NUMBER}` output>
```

Invocation (either variant):

```bash
REPORT="/tmp/qc-structural-pr-${PR_NUMBER}.md"     # report files may live in /tmp; only the worktree may not
codex -C "$WORKTREE" exec --ephemeral --json \
  --output-last-message "$REPORT" "$(cat prompt-structural.txt)"   # not `exec review --base`: it refuses a prompt
```

The controller parses `$REPORT`, checks its first line names `$HEAD_SHA`,
posts it (§3), and continues only on `APPROVED`.

## 5. Behavioral review (promotion path — not enabled)

Same worktree and PR input. The behavioral role's shell use is deliberately
narrow, and this is the operating contract the repo's own behavioral reviews
follow (issue #2788 reconciles the role file's older "no Bash" line with it):
scoped `dune runtest <dir>` inside the container against this checkout, and
**temporary mutation probes that are reverted** (`git status` clean at the
end) — nothing that persists, no pushes, no parent tree.

```bash
REPORT="/tmp/qc-behavioral-pr-${PR_NUMBER}.md"
codex -C "$WORKTREE" exec --ephemeral \
  --output-last-message "$REPORT" \
  "Review PR #${PR_NUMBER} (head ${HEAD_SHA}) as qc-behavioral. This head has
already cleared the first gate; do NOT restate that fact or name that gate in
your report. Protocol: .claude/agents/qc-behavioral.md (CP1-CP4: every
non-trivial claim in .mli docstrings, the PR body's test plan and the linked
issue must be pinned by a named test that exists in the diff) plus the domain
rows and authority list in .claude/rules/qc-behavioral-authority.md (S/L/C/T
rows for Weinstein-domain PRs; all NA with one note for infra/harness PRs).
For a faithfulness question the reference leaves open, the book is a local
file — follow .claude/rules/book-as-authority.md. Shell scope: scoped
'dune runtest <dir>' only, inside the container against this checkout:
docker exec trading-1-dev bash -c 'cd ${CWT}/trading && eval \$(opam env) && export TRADING_DATA_DIR=\$PWD/test_data && dune runtest <dir>'
plus at least two mutation probes that sever the mechanism, each reverted
before the next; an uncaught severing mutation is a NEEDS_REWORK item.
'git status --porcelain' must be empty when you finish.
Scope = 'gh pr view ${PR_NUMBER} --json files,title,body,headRefName,headRefOid'.
Report: first line exactly 'Reviewed SHA: ${HEAD_SHA}'; first heading
'## Behavioral QC — <PR title>'; then the Contract Pinning table, the domain
table, '## Quality Score', '## Verdict' (next line exactly APPROVED or
NEEDS_REWORK), '## NEEDS_REWORK Items'. Do not mention any other review gate.
Do not modify files persistently, commit, push, or post to GitHub."
```

## 6. Rework loop

On `NEEDS_REWORK` the controller dispatches a rework carrying the **full
review body**, the iteration number (cap 2, then stop and flag for a human),
"address every item, no new scope", and "commit as a second commit, never
amend" (`.claude/rules/pr-gate-loop.md`). A new tip invalidates both verdicts:
re-run structural at the new SHA, then behavioral.

## 7. Notes

- `--base origin/main` on a branch that is behind `main` still diffs the PR's
  own changes (Codex uses the merge-base), but the file list must come from
  `gh pr view`; do not let the reviewer infer scope from the diff.
- The `/tmp` fixture race that produced spurious H3 failures under concurrent
  `dune runtest` (#2760) is fixed by #2767; older branches that predate it can
  still trip it when two reviewers run full suites at once — one more reason
  for the single-dune rule above.
- For a persistent integration Codex also exposes an experimental
  `app-server` transport; a local MCP bridge can forward review requests to it.
  The subprocess form above is preferred: one PR per process, one report file,
  easy to audit.
