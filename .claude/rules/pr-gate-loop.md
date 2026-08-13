# The PR gate loop — run QC on every PR, immediately, as a loop

`pr-merge-gates.md` says *what* the three gates are. This file says *when* they
run and *who* drives them, because that part used to live in `lead-orchestrator`
and the orchestrator is off (2 cron slots/day,
`memory/project_orchestrator_off`). Without it, PRs sit open for days
accumulating nothing: tonight's session opened with **eight** open PRs, all
CI-green, of which three had never been reviewed at all and two carried verdicts
pinned to superseded SHAs.

The loop is not optional work that happens when there is time. **A PR that is
open and unreviewed is the default work item**, ahead of new features.

## The state machine (one PR)

```
opened / reworked
      |
      v
   CI green? ---no--> fix CI (never dispatch QC against red CI)
      |yes
      v
 qc-structural at tip --NEEDS_REWORK--> rework (iter <= 2) --+
      |APPROVED                                              |
      v                                                      |
 qc-behavioral at tip --NEEDS_REWORK--> rework (iter <= 2) --+
      |APPROVED                                              |
      v                                                      v
    MERGE                                          after iter 2: STOP,
                                                   leave draft, flag for human
```

Two rules that are easy to get wrong and cost a re-run each time:

- **Both verdicts must be at the CURRENT tip.** A rework commit invalidates every
  prior verdict. This is the single most common stale-green error — see the
  `stale(<sha>)` column in the status script.
- **Behavioral does not run until structural APPROVES.** Dispatching both at once
  wastes the behavioral agent when structural finds a blocker.

## Read the state, don't remember it

```sh
sh dev/scripts/pr_gate_status.sh            # every open PR + its ONE next action
sh dev/scripts/pr_gate_status.sh 2265 2280  # specific PRs
```

Prints `PR | CI | STRUCT | BEHAV | NEXT-ACTION`, where a gate is `ok` / `rework` /
`stale(<sha>)` / `none` / `skip` (docs-only). Run it **at session start, and
after every agent wave.** It encodes two things a by-hand `gh` read gets wrong:

1. QC verdicts land as **COMMENTED** reviews, never `APPROVED` — GitHub blocks
   self-approval when the reviewer and PR author are the same account, which is
   always the case here. Reading `.state` finds zero approvals forever; the
   verdict is in the body text.
2. A review body mentioning the *other* gate ("qc-structural already returned
   APPROVED") must not be counted as that gate's verdict. Match on the review's
   own heading and read the `## Verdict` section, not the first APPROVED token.

## Batching (see `container-capacity-scheduling.md`)

Dispatch QC in waves of **at most 3**, batched by phase — all the structural
reviews, collect, then all the behavioral ones. Never while a multi-hour backtest
is running. Fill the wait with merges, rework briefs, and docs — never with a
fourth agent.

## The rework brief

When a verdict is NEEDS_REWORK, the rework dispatch must carry:

- The **full review body** (`gh pr view <N> --json reviews --jq '.reviews[-1].body'`),
  not a summary — the findings contain the required fix and the authority.
- The **iteration number** ("rework iteration 1 of 2") so the agent knows headroom.
- "Address every checked-fail item. Do not introduce new scope."
- Commit as a **second commit** (`fix(review): address QC rework iteration N (#PR)`),
  never an amend, so the reviewer can diff what changed.
- `timeout: 600000` on every dune Bash call, split into scoped foreground calls
  (`feedback_agents_background_wait_stall` — the 120s default auto-backgrounds
  the call and the agent then waits forever for an event a subagent never gets).

## Dispatcher-side recovery (do not re-dispatch reflexively)

Agents stall — on the Bash timeout, on token limits, on a dune lock held by a
sibling. Before re-dispatching, check whether the work already exists:

```sh
jj log -r 'all()' --no-graph -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"' -n 20
jj diff -r <change-id> --stat        # 0 files = never snapshotted; real files = recoverable
```

A stalled agent's commit usually sits complete in its workspace. **Finishing it
from the dispatcher side (verify → `jj bookmark set` → `jj git push`) is faster
than a re-dispatch and cannot lose the work.** Kicking the agent is the right
move only when the work is genuinely incomplete.
