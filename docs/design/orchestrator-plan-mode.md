# Orchestrator plan mode

Reference for `.claude/agents/lead-orchestrator.md` § Plan Mode.

When the dispatch prompt contains the token `--plan` (e.g. `dev/run.sh
--plan`), the orchestrator runs in plan mode:

## Contract

- **Do NOT dispatch any subagents.** Skip Steps 2 through 6 entirely — no
  feat-agent, qc-structural, qc-behavioral, harness-maintainer,
  health-scanner, or ops-data spawns. Plan mode is read-only.
- **Do all of Step 1** (read current state — `dev/decisions.md`, every
  `dev/status/*.md`, `dev/notes/data-gaps.md`, existing `dev/reviews/*.md`).
  This is cheap and the plan depends on it.
- **Emit the dispatch plan** — what would have been dispatched, why, and on
  which branch. Organise as the same sections the daily summary uses, filled
  with plan-mode content:
  - Which blocking refactors (2a) would run
  - Whether the followup accumulation threshold (2b) is met
  - Which harness backlog item (2c) is highest-priority open
  - Whether ops-data (2d) would run, against which gap
  - Which feat-agents (2e) are eligible, in what order
- **Write** `dev/daily/<YYYY-MM-DD>-plan.md` (note the `-plan` suffix — do
  NOT overwrite the real daily summary). Header line:
  `# Status — YYYY-MM-DD (plan mode)`.
- **Exit 0**. Plan mode never mutates branches, never pushes bookmarks,
  never writes to `dev/status/*.md` or `dev/reviews/*.md`.

## Use cases

- Operator dry-runs before a real scheduled run
- Smoke-testing changes to `.claude/agents/lead-orchestrator.md` without
  committing Claude-API tokens
- Verifying status-file changes land cleanly in Step 1 reads

## Relationship to real runs

Plan mode and real runs share Step 1 and Step 1b (drift cross-reference).
They diverge at Step 1.5 (guard still evaluates eligibility but no
dispatches fire). Step 1c (verify carried-forward `[critical]`) runs in
both modes — a plan that carries forward a stale critical is as wrong as
a real run that does.
