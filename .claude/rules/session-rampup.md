---
description: New-session ramp-up sequence for this repo — main CI health check + most-recent priorities doc read, before any agent dispatch or feature work.
harness: project
---

# Session ramp-up

At the start of every new Claude Code session in this repo, run these
two steps **before** dispatching any agent, reading status files, or
starting feature work.

## Step 0 — Check main CI is green

```bash
gh run list --branch main --limit 3 \
  --json conclusion,name,headSha,status
```

If the latest `CI` workflow conclusion is `failure` (or status is
`completed` with `conclusion != success`), main is red. **Stop and
ship a fix PR before doing anything else.** Also scan open watchdog
issues:

```bash
gh issue list --label ci-red --state open --limit 5
```

An open `[ci-watchdog] main CI red on <sha>` issue is the same signal.

### Why

Per `feedback_session_rampup_check_main_ci.md` 2026-05-15: PR #1113
merged with red CI; watchdog issue #1114 fired and was ignored 12 times
across 14 hours while 12 more PRs piled on. The 2026-05-16 morning
session diagnosed red main only after the user flagged it manually.
Without the step-0 check, the rampup defaults to dispatching feature
work on a broken base — the fix lands on top of stale broken state
and obscures the original cause.

### Exception

If the failure is a confirmed CI-infra flake (sandbox race, GHA cache
state), document and proceed. The hard rule from
`.claude/rules/pr-merge-gates.md` applies: any `^FAIL:` line in the CI
log (linter, OUnit test) is never an infra flake.

### Recovery

After closing a red-main incident:

```bash
gh issue close <N> \
  --comment "Fixed by PR #<fix>; main green on <new-sha>."
```

## Step 1 — Read the newest priorities doc

```bash
ls -1t dev/notes/next-session-priorities-*.md | head -1
```

`Read` that file. It carries the current P0/P1/defer framing, the
specific in-flight work items, the rationale, and the sequencing. The
file is the load-bearing handoff artefact between sessions.

The most recent doc supersedes older ones (header pointers usually
call out the supersession explicitly).

### Context-on-demand (do NOT auto-read)

These files are reference material — `Read` only if the priorities-doc
content points at them:

- `dev/status/*.md` — per-track Status + Next-task rows.
- `dev/plans/*.md` — open design plans.
- Memory files cited by the priorities doc.

Do NOT pre-load every memory or every status file at session start —
only the priorities doc + main-CI status. The rest is context-on-demand.

## Step 2 — Confirm + dispatch

After reading the priorities doc, briefly state to the user:

- Main CI status.
- The P0 task per the doc.
- Any in-flight work that's still open (PRs, agents, long-running
  experiments).

Ask whether to dispatch P0 work or focus elsewhere. Two sessions in a
row have flipped strategy based on intra-session findings (see
`memory/project_strategic_pivot_broader_first.md`), so the priorities
doc is the most recent snapshot but not authoritative if the user
starts the session with new information.

## What NOT to do

- Don't dispatch new feature work on top of a red main.
- Don't auto-dispatch P0 without confirming the priorities doc still
  matches the user's current intent.
- Don't read every status file at session start — they're stale-prone
  (see `memory/feedback_status_refresh_must_verify.md`), and only the
  ones the priorities doc cites are load-bearing for this session.
