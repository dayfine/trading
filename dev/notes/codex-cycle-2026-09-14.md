# Codex issue-cycle retrospective — 2026-09-14

The user authorized merge checks every 30 minutes for #2785 and #2798, followed
by hourly idle issue work for 12 hours and a final retrospective. The cycle
produced four issue PRs, all merged externally. Codex did not merge them or
post its own QC gate approvals. Two other issues were explicitly blocked.

## Window and scheduling evidence

- Prerequisite merges: #2785 at 2026-09-14 04:49:43 UTC; #2798 at 07:30:56 UTC.
- First processed activation: 2026-09-14 17:00:29 UTC (10:00:29 PDT).
- Deadline: 2026-09-15 05:00:29 UTC (September 14, 22:00:29 PDT).
- Closeout resumed after the deadline, observed at 06:22:49 UTC. No new issue
  was selected then; only the authorized retrospective was started.

An OS cron entry invoked a session-local controller every 30 minutes. It queued
the same conversation when due, using pending-message suppression and a lock.
Six mock test groups covered scheduling, duplicate suppression, activation,
hourly timing, end-of-window handling, finished no-ops, and queue failure retry.
A real connection-only wake-up succeeded. The scheduler relied on the host and
Codex being available; it was not a continuously executing worker.

Logs show work messages at 17:00, 18:00, 19:00, 20:00, 22:30, 23:30, 00:30,
01:30, and 02:30 UTC. The 22:30 wake-up arrived during active #2639 work and
did not start another issue. The 02:30 message remained pending when closeout
resumed. Processing was not reliably hourly. No active-work duration was
measured, and the gaps must not be counted as continuous implementation time.

## Outcomes

| Issue | Result | Verification and review |
| --- | --- | --- |
| [#2753](https://github.com/dayfine/trading/issues/2753) | [#2806](https://github.com/dayfine/trading/pull/2806), merged 17:57:54 UTC September 14 | Publisher regression suite 87/87 before, 90/90 after; targeted guard mutation 89/90. CI green, both Claude QC gates approved; no rework. |
| [#2394](https://github.com/dayfine/trading/issues/2394) | `needs-info` | Required real configuration arming `min_rs_normalized` was absent. Posted evidence; no implementation. |
| [#2539](https://github.com/dayfine/trading/issues/2539) | `ready-for-human` | Required live orchestrator validation conflicted with an existing run; no isolated smoke mode. Requested a coordinated validation window instead of launching another dispatcher. |
| [#2639](https://github.com/dayfine/trading/issues/2639) | [#2819](https://github.com/dayfine/trading/pull/2819), merged by next 01:30 check | Draft-hold detector 5/16 before, 16/16 after. Timestamp mutant 13/16; fail-open mutant 7/16. One CI formatting failure fixed in a second commit. Both Claude QC gates approved. |
| [#2788](https://github.com/dayfine/trading/issues/2788) | [#2820](https://github.com/dayfine/trading/pull/2820), merged 01:36:17 UTC September 15 | Docs-only behavioral-review tool contract, green CI; QC skipped by repository policy. Waited until the old claim expired, checked for an existing PR, used a fresh worktree. |
| [#2742](https://github.com/dayfine/trading/issues/2742) | [#2821](https://github.com/dayfine/trading/pull/2821), merged 02:29:35 UTC September 15 | Per-file follow-up threshold: 18 new checks passed, old implementation failed 18 assertions, boundary mutation failed 9. Green CI and both Claude QC approvals. |

PR #2797 was completed before activation and is not one of the four cycle PRs.
No advisory reviews were posted during the cycle; assigned work took priority.
Issue #2793 was not started before the deadline.

## What worked

Fresh repo-local worktrees kept edits and tests away from the primary jj
workspace. Checks of shared container activity prevented concurrent Dune builds;
focused shell suites and CI supplied validation. Reading merged instructions
established the `author/codex` label and Claude-owned gates before new PRs.

Behavioral evidence was reproducible: Claude reviews independently reproduced
the targeted mutations. The blocked-issue protocol avoided expanding scope or
dispatching unrelated work. The per-file change also updated its configuration,
consumer metrics, and agent prose, rather than changing only the warning.

## What failed or remained incomplete

Permission friction remained substantial despite a project command-policy PR.
Recorded boundaries included protected Git index/ref writes, GitHub network
operations, the queue database, host crontab installation, and worktree removal.
At closeout, four cleanup commands reported inability to remove protected
`.git/worktrees` metadata. A grouped escalated retry reported that those paths
were no longer worktrees; a subsequent Git listing confirmed their registrations
were absent. This does not establish which intervening operation removed them.

The user twice challenged the cleanup approval batch. Running the same known
protected operation separately for four worktrees was poor unattended behavior.
The log records explicit escalation requests but cannot reconstruct every UI
approval prompt, so an exact prompt total is not claimed. Future runs need a
capability inventory before activation and a per-request audit, not a promise
that a repository allowlist eliminates sandbox restrictions.

The first new Dune rule failed CI over one blank line. Avoiding an occupied
build slot was correct, but formatting still needed verification. The follow-up
second commit passed; no behavior changed.

Remaining limitations are explicit: #2819 did not add timeline pagination;
#2821 did not exclude archived residuals, and its report-aggregation plumbing
is inspected but not directly tested by the focused suite. Those are not
claimed as completed work. Cleanup of the #2742 and retrospective worktrees,
and eventual removal of the scheduler worktree, must be tracked separately.

## Reusable process

[Codex scheduled issue cycles](../../docs/howtos/codex_scheduled_issue_cycle.md)
formalizes activation, ownership checks, one-PR lifecycle, capacity checks,
permission accounting, deadline handling, and shutdown. Its key corrections are
to distinguish queued from processed work, recheck time after any interruption,
test formatting as well as behavior, and treat protected cleanup as a known
capability boundary rather than repeatedly surprising the user.
