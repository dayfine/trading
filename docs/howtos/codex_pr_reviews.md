# Invoking Codex for PR reviews from another CLI

An orchestrator (Claude CLI, a GHA step, a shell controller) can run Codex as a
subprocess to play the project's two review roles:

1. Structural QC — `.claude/agents/qc-structural.md`
2. Behavioral QC — `.claude/agents/qc-behavioral.md`

Run them in that order. Behavioral QC runs only after structural QC has
returned `APPROVED` for the **same head SHA**
(`.claude/rules/pr-gate-loop.md`). The controller — not Codex — owns
authentication, the worktree, the structural→behavioral gate, verdict parsing,
posting, and cleanup. Codex gets review authority only.

Verified against `codex-cli 0.154.0`: `codex -C <dir> exec review --base
<branch> --ephemeral --json --output-last-message <file> [PROMPT]` are all
real flags.

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

### Sandbox decision (pick one and say which)

Codex's default sandbox will not reach the Docker socket. Two coherent
choices:

- **A — Codex runs the build gate.** Grant only what `docker exec` needs
  (e.g. `-c 'sandbox_permissions=["disk-full-read-access"]'` plus whatever
  socket access the local Codex version requires) and keep every other
  restriction. Do not use a blanket bypass.
- **B — CI is the build gate.** Codex reviews the pattern / architecture /
  contract rows only; the controller substitutes the PR's CI status for H1–H3
  and says so in the posted report. Cheaper, and it matches how the dune-wired
  linters are already trusted (`.claude/rules/pr-merge-gates.md` §"Why each
  gate matters").

Capacity: at most 3 concurrent reviewers, and on a GHA runner at most **one**
`dune build`/`runtest` in flight at a time
(`.claude/rules/container-capacity-scheduling.md`). Never dispatch reviewers
while a multi-hour backtest holds the container.

## 3. The report format is machine-parsed

`dev/scripts/pr_gate_status.sh` decides each PR's next action by reading PR
**reviews** (not issue comments). A report that breaks the contract reads as
`unclear` and the PR stalls. Every prompt must require, and the controller
must verify before posting:

- Top heading exactly `# qc-structural review — PR #<N> @ <short sha>` (or
  `qc-behavioral`), naming **only its own gate**.
- A `## Verdict` section whose next non-blank line is exactly `APPROVED` or
  `NEEDS_REWORK`, followed by `## NEEDS_REWORK Items` when applicable
  (Finding / Location / Authority / Required fix / harness_gap per item).
- **No mention of the other gate anywhere in the body.** In particular the
  behavioral prompt tells Codex which structural SHA/report it is building on
  — that sentence must not be echoed into the report, or the parser attributes
  a second structural verdict to it (the #2620 false-green mode). Reject a
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

## 4. Structural review

```bash
REPORT="/tmp/qc-structural-pr-${PR_NUMBER}.md"     # the report file may live in /tmp; only the worktree may not

codex -C "$WORKTREE" exec review \
  --base origin/main --ephemeral --json \
  --output-last-message "$REPORT" \
  "Review PR #${PR_NUMBER} (head ${HEAD_SHA}) as qc-structural.
Protocol: .claude/agents/qc-structural.md plus the project rows in
.claude/rules/qc-structural-authority.md (P6, A1, A2, A3); also apply
.claude/rules/experiment-flag-discipline.md R1-R3,
.claude/rules/config-default-blast-radius.md B1-B3 and
.claude/rules/test-patterns.md where the diff touches strategy config or tests.
Scope = 'gh pr view ${PR_NUMBER} --json files,title,body,headRefName,headRefOid';
the --base diff is context only.
Build gate: run every dune command inside the container against THIS checkout:
docker exec trading-1-dev bash -c 'cd ${CWT}/trading && eval \$(opam env) && export TRADING_DATA_DIR=\$PWD/test_data && dune build @fmt && dune build && dune runtest'
(never cd /workspaces/trading-1/trading). Read exit codes, not greps.
Report format (machine-parsed): top heading exactly
'# qc-structural review — PR #${PR_NUMBER} @ ${HEAD_SHA:0:9}', a '## Verdict'
section whose next line is exactly APPROVED or NEEDS_REWORK, then
'## NEEDS_REWORK Items' if any. Do not mention any other review gate.
Do not modify files, commit, push, or post to GitHub."
```

The controller parses `$REPORT`, checks the heading SHA equals `$HEAD_SHA`,
posts it (§3), and continues only on `APPROVED`.

## 5. Behavioral review

Same worktree and PR input. The structural approval is passed to Codex as an
instruction, with the explicit order not to repeat it in the report.

```bash
REPORT="/tmp/qc-behavioral-pr-${PR_NUMBER}.md"

codex -C "$WORKTREE" exec review \
  --base origin/main --ephemeral \
  --output-last-message "$REPORT" \
  "Review PR #${PR_NUMBER} (head ${HEAD_SHA}) as qc-behavioral. This head has
already cleared the first gate; do NOT restate that fact or name that gate in
your report. Protocol: .claude/agents/qc-behavioral.md (CP1-CP4: every
non-trivial claim in .mli docstrings, the PR body's test plan and the linked
issue must be pinned by a named test that exists in the diff) plus the domain
rows and authority list in .claude/rules/qc-behavioral-authority.md (S/L/C/T
rows for Weinstein-domain PRs; all NA with one note for infra/harness PRs).
For a faithfulness question the reference leaves open, the book is a local
file — follow .claude/rules/book-as-authority.md. Run at least two mutation
probes that sever the mechanism (revert each); an uncaught severing mutation is
a NEEDS_REWORK item (memory: coverage counts per shape). Scoped dune runtests
only, inside the container against this checkout:
docker exec trading-1-dev bash -c 'cd ${CWT}/trading && eval \$(opam env) && export TRADING_DATA_DIR=\$PWD/test_data && dune runtest <dir>'.
Scope = 'gh pr view ${PR_NUMBER} --json files,title,body,headRefName,headRefOid'.
Report format (machine-parsed): top heading exactly
'# qc-behavioral review — PR #${PR_NUMBER} @ ${HEAD_SHA:0:9}', a
'## Quality Score' section, a '## Verdict' section whose next line is exactly
APPROVED or NEEDS_REWORK, then '## NEEDS_REWORK Items' if any. Do not mention
any other review gate. Do not modify files, commit, push, or post to GitHub."
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
  still trip it when two reviewers run full suites at once — rerun
  `dune runtest devtools/sexp_default_drift_linter/test` alone before
  classifying such an H3.
- For a persistent integration Codex also exposes an experimental
  `app-server` transport; a local MCP bridge can forward review requests to it.
  The subprocess form above is preferred: one PR per process, one report file,
  easy to audit.
