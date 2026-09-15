# Codex scheduled issue cycles

Use this procedure only for a user-authorized, time-bounded cycle. It does not
authorize a new schedule, broader issue ownership, merges, or settings changes.
Repository [AGENTS.md](../../AGENTS.md) remains the authority for isolation,
assignment, container capacity, and review gates.

## Establish the window

Record prerequisite PR numbers, check cadence, work cadence, activation time,
deadline, conversation identity, and final deliverable before starting. Check
that each prerequisite is actually merged; closed without merge is a blocker.
Read instructions from updated main after the gate opens. Start the work window
at activation, and record both UTC and the user's local time zone.

Keep scheduler state and logs in ignored `dev/_tmp/codex/` inside an owned
worktree. Retain that worktree until the schedule is disabled. Queue the existing
conversation, with one pending wake-up and a lock against duplicate ticks.
Scheduling a message is not proof it was processed: record queued and processed
times separately. Machine sleep, an active task, or an approval wait may delay
processing. After any delay, check the deadline before selecting work.

Verify the actual execution environment before promising unattended operation.
Test one connection-only wake-up, duplicate suppression, queue failure recovery,
deadline handling, and finished-state no-ops. Inspect installed scheduling state;
do not equate a prepared installation script with a running schedule.

## Process one wake-up

1. Read state and acknowledge the pending message. Check the current time.
   Past the deadline, take no new issue or review; close out active work and
   write the retrospective.
2. Resume this conversation's active implementation, CI failure, or requested
   rework before selecting another issue. Check ownership and takeover comments.
   A pending PR does not justify duplicate implementation.
3. Select `ready-for-agent` + `agent/codex` by priority, then issue number, as
   specified in AGENTS.md. Read comments and linked PRs. Skip forbidden labels
   and other agents' claims younger than 24 hours. An expired claim does not
   authorize editing its old worktree: check for existing work and make a new
   claim and isolated worktree if still eligible.
4. Claim with a literal UTC timestamp and worktree path. Create one detached
   git worktree under the repository, then a `codex/<issue>-<slug>` branch.
   Never use `jj`, the primary checkout, or another agent's worktree.
5. Resolve the bounded issue. If an explicit prerequisite is unmet, post
   `BLOCKED:` with evidence, change the workflow label per AGENTS.md, and stop
   that issue. Do not manufacture a live validation run that dispatches other
   agents or performs unrelated merges.

## Finish each PR

For a behavior fix, reproduce the failure, add focused regression checks, then
implement it. Use targeted mutations when needed to show that tests detect the
claimed defect. Record actual check counts and exit outcomes. Keep mutation
copies in owned scratch; restore any temporary probes before committing.

Run tests in the container against the isolated worktree. Inspect shared Dune
and backtest activity first. If capacity is occupied, run safe focused shell
checks and disclose that full Dune validation is delegated to CI. Docs-only
changes need no local build. Check formatting for Dune stanzas too: one missing
blank line caused a full CI rework round in the first cycle.

Self-review the diff and the consumers of changed fields, including report
templates and agent instructions. Open one PR per issue, body starting with
`Closes #N`, an evidence-based Test plan, and `author/codex`. Do not invent an
issue number for a separately user-requested retrospective.

Monitor CI to completion. Correct failures or review requests in additional
commits; never amend published work. Own self-review is not a QC gate. Claude
owns structural and behavioral QC; the dispatcher or human merges. Advisory
reviews of other PRs follow [the review protocol](codex_pr_reviews.md), consume
no Dune slot, and must not duplicate existing current-SHA reviews.

Done means PR open with green CI. Remove only the owned worktree after checking
it is clean and its commits are published. Record any blocked cleanup explicitly.

## Permission discipline

Standing user authorization and the execution sandbox are separate controls.
A repository instruction or command rule does not itself grant filesystem
access to protected Git metadata, network access, or host scheduler state.
Never promise zero prompts merely because a policy PR merged.

Before an unattended cycle, inventory the actual operations required: fetch,
worktree/ref/index writes, commit, branch push, GitHub read/write, container
execution, queueing, scheduler installation/removal, and owned-worktree cleanup.
Use existing authorized rules where applicable. Prefer literal arguments,
structured tools or body files, and the simplest shell command that does the job.
Avoid wrapping already-supported operations in unnecessary nested shells.

For every approval request, log the operation, reason, result, and whether the
approval persists. Distinguish an agent clarification from a runtime approval
prompt and from an automatic review rejection. Do not guess the total number
of UI prompts from the number of tool calls. Explain the specific boundary.
Follow execution-policy escalation requirements after a sandbox failure; do not
try another mechanism to bypass it. Repeated failures of the same cleanup
capability should be treated as one known limitation, not discovered again for
each worktree. Preserve sandboxing and other agents' settings.

## Close the cycle

Keep an append-only activity record with times, issue/PR links, decisions,
validation, rework, skips, blockers, and approval friction. At the deadline,
publish an evidence-based retrospective and update this procedure if warranted.
Distinguish elapsed time from measured active work; silence is not execution.

Once the retrospective is safely recorded or published, mark state finished
before removing only the owned cron entry. Finished state must make subsequent
ticks and delayed wake-ups harmless. Preserve unrelated jobs. If host scheduler
cleanup is blocked, report the remaining inert entry; do not restart the cycle.
List any remaining CI, cleanup, and handoff items in the final report.
