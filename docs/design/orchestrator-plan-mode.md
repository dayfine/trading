# Orchestrator plan mode

Reference for `.claude/agents/lead-orchestrator.md` § Plan Mode.

When the dispatch prompt contains the token `--plan` (e.g. `dev/run.sh
--plan`), the orchestrator runs in plan mode:

## Contract

"Read-only" means **no state-changing effects** (no subagent spawn, no
branch push, no writes to `dev/status/*.md` / `dev/reviews/*.md` /
source files). It does NOT mean "no subprocesses." Verification
subprocesses that only read state — `dune build @runtest --force`, curl
REST GETs against GitHub, `jj log`, `ls` — are pure observations and
**MUST** run. Skipping them produces a plan built on yesterday's
assumptions (see 2026-04-18 → 2026-04-17-plan for a case where skipping
verification cascaded stale `[critical]`s through the whole plan).

- **Do NOT dispatch any subagents.** Skip Steps 2 through 6 entirely — no
  feat-agent, qc-structural, qc-behavioral, harness-maintainer,
  health-scanner, or ops-data spawns.
- **Do all of Step 1** (read current state — `dev/decisions.md`, every
  `dev/status/*.md`, `dev/notes/data-gaps.md`, existing `dev/reviews/*.md`).
- **Do all of Step 1b + 1c** (drift cross-reference + carry-forward
  verification). The verification commands listed in Step 1c are read-only
  and must actually run — `dune build @runtest --force` exit code,
  `curl .../pulls/<N>/commits/<sha>/check-runs`, etc. A plan that writes
  "Plan mode: NOT executed. Assumption: <stale>" for a `[critical]` is a
  broken plan.
- **Do the Step 1.5 PR-open guard** including the live REST query for
  each eligible track. Don't substitute `_index.md`-based speculation —
  `_index.md` lags reality until Step 5.5 reconciles it, and a real run
  would query PR state anyway.
- **Emit the dispatch plan** — what would have been dispatched, why, and on
  which branch. Organise as the same sections the daily summary uses,
  filled with plan-mode content:
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
