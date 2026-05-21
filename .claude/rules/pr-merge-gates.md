---
description: PR merge policy — all 3 gates (CI + qc-structural + qc-behavioral) must be green AND completed before merge. `gh pr merge` does not enforce CI on this repo's main branch protection; verify manually.
harness: project
---

# PR merge gates

A PR is mergeable only when **all three** are green:

1. **GitHub CI** — `build-and-test` + `perf-tier1-smoke` (and any other
   required PR workflows). Status must be `COMPLETED SUCCESS`, never
   `IN_PROGRESS` or `PENDING`.
2. **qc-structural** — APPROVED verdict at the current PR tip, recorded
   in `dev/reviews/<feature>.md`.
3. **qc-behavioral** — APPROVED verdict at the current PR tip, recorded
   in `dev/reviews/<feature>-behavioral.md`. NA only for the cases
   listed in `.claude/rules/qc-behavioral-authority.md` §"When to skip
   this file entirely" (pure infra / refactor / harness PRs that touch
   no domain logic — still requires the generic CP1–CP4 review).

## Why each gate matters

- **CI catches what local + QC cannot.** Local `dune build && dune runtest`
  skips the linter steps that GHA runs as part of the PR build
  (`fn_length_linter`, `nesting_linter`, `linter_magic_numbers.sh`,
  `file_length_linter`, `status_file_integrity_linter`). QC agents
  inherit the same blind spot when their host environment lacks opam
  deps. Per `feedback_pr_merge_gates.md` 2026-05-03: ~28 PRs merged in
  autonomous mode on QC alone caused linter regressions on main because
  their local QC environments couldn't run the full linter suite. CI is
  the only place the full lint surface runs.
- **QC structural catches what CI doesn't.** Architecture constraints
  (A1–A3), test patterns (P6), pattern-match exhaustivity, naming
  hygiene — these are not in any linter; they're in `.claude/agents/
  qc-structural.md` + `.claude/rules/qc-structural-authority.md`.
- **QC behavioral catches contract drift.** The .mli docstring,
  feature plan, and PR body each name claims; qc-behavioral pins each
  claim against a test. Without it, "the test suite is green" is a
  much weaker guarantee than "every documented contract is pinned."

## Verifying CI before merge

`gh pr merge --squash` does **not** automatically block on CI when
branch protection isn't enforcing required checks. This repo's main
branch DOES have `build-and-test` + `perf-tier1-smoke` as required
checks with `strict: true` since 2026-05-09, but the requirement
applies to `--squash` only when the PR is up-to-date; a stale PR will
fail with "GraphQL: 2 of 2 required status checks are expected" and
must be rebased (`gh pr update-branch <N>`) before re-attempting. Per
`feedback_pr_merge_ci_gate.md` 2026-05-06: PR #883 merged with
`build-and-test: FAILURE` because the merge command was invoked while
build-and-test was still `IN_PROGRESS` and finished red seconds later.

### The hard rule

Before `gh pr merge`:

```bash
gh pr checks <N>
```

Read column 3 on every line — `pass` / `fail` / `pending`. **If any
line shows `pending` or `fail`, DO NOT merge.** This is non-negotiable
even with `--admin` privileges. Per `feedback_pr_merge_ci_gate.md`
2026-05-15: PR #1113 admin-merged with `build-and-test: fail` despite
QC double-approval; the linter failures (file_length, nesting) landed
on main and blocked 12 subsequent PRs.

### When `fail` is admissible (rare exception)

A `fail` is treated as an actionable failure unless ALL of:

1. Reproducibly the same silent failure on 2+ reruns — same step, no
   test assertion message, no source-level error.
2. Verifiable infra signal in the log (e.g. sandbox-race `find: …
   No such file or directory`).
3. PR content has QC structural + behavioral APPROVED with no findings
   that would interact with the failing step.
4. Main is blocked on this merge (the PR is itself the unblock).

If any of (1)–(4) is missing, treat as a real fail. Even when an
exception fires, file a follow-up to fix the underlying infra race.

### Hard stop: any `^FAIL:` line means real failure

```bash
gh run view <run_id> --log 2>&1 | grep -E 'FAIL:'
```

`FAIL: nesting linter`, `FAIL: file length linter`, `FAIL: magic
numbers`, `FAIL: status_file_integrity_linter`, `FAIL: fn_length`,
`FAIL: mli_coverage`, OUnit `FAIL:` — none of these are ever infra
flakes. Reject the exception. Fix on a new PR before merging anything
else.

### Hard stop: main must be green BEFORE merging the next PR

```bash
gh run list --branch main --workflow CI --limit 1 \
  --json conclusion,headSha,status
```

If main is red, fix main first via a dedicated `[main-fix]`-prefixed
PR (single commit, scope = revert/fix the violation, no new feature
work). Do not pile new merges on a red main — diagnosis ambiguity
multiplies as each successive PR adds noise, and watchdog issue
comments accumulate without a recovery trigger.

## Polling pattern

```bash
# Poll until all checks are COMPLETED SUCCESS, then merge
until [ "$(gh pr view <N> --json statusCheckRollup \
  -q '[.statusCheckRollup[] | select(.status != "COMPLETED" or .conclusion != "SUCCESS")] | length')" = "0" ]; do
  sleep 30
done
gh pr merge <N> --squash --delete-branch
```

Or simpler: `gh pr checks <N>`, eyeball, only merge if all `pass`.

## Don't trust stale "CI was green" reads

CI status can change between QC approval and merge invocation if a
rework was pushed during QC. Always re-verify `gh pr checks <N>`
immediately before `gh pr merge`, not 5 minutes earlier.
