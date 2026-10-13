# Issue hygiene: every open issue has an owner, a state and a next check

On 2026-10-12, 51 issues were open. Triage closed 22 as done or stale, folded 8 into umbrellas, and left 22. Most of
the drift came from three gaps:

- **After-merge checks nobody connected.** Several `verify/pending` items had already been satisfied by later runs,
  for example the total-return reruns #3219 and #3261, but no one linked the run to the issue.
- **Results PRs that never said which issue they satisfied.**
- **Research ideas no plan would run.** They sat untouched for weeks.

User direction, 2026-10-12: *"develop a good practice so issue status is up-to-date / maybe a verification process"*,
with a target of 10–20 open issues.

## A. Owner and state on every open issue

- **One owner label:**
  - `owner/local`: needs local data, the warehouse or long runs;
  - `env/cloud`: a Claude cloud session can do it;
  - `agent/codex`: small, mechanical, well specified;
  - `owner/user`: waiting on a decision only the user can make. The question must be in the latest comment.
- **One state:**
  - `ready-for-agent`;
  - `verify/pending`: the [merge] items have shipped and [after-merge] items remain;
  - `blocked`: name the blocker in a comment.

  No label means "being worked locally".
- **An issue with no owner label is untriaged.** Triage it the same week, or close it.

## B. Verify at merge, not later

- **When merging a PR with `Refs #N -- verify: <items>`:**
  - add `verify/pending` to #N;
  - comment the [after-merge] items, each naming the run or experiment that will satisfy it.

  An item with no planned run is a smell: either schedule the run or rewrite the item.
- **Every results PR body carries one line:** `Verifies #N: <item> — <evidence path>` for each [after-merge] item it
  satisfies, or `Verifies: none`.
  - qc-results checks that the evidence meets the item, as a row in its checklist.
  - If it does, the dispatcher closes #N right after the merge, quoting the evidence.
- **`Closes #N` stays as written in `pr-merge-gates.md`:** every [merge] item is met, and no [after-merge] item
  remains.

## C. The weekly pass (same slot as `perf-review-weekly.md`)

Run `sh dev/scripts/issue_fix_audit.sh`. Every issue it lists leaves the week closed, re-owned or commented.

- open issues mentioned by a merged PR (existing);
- `verify/pending` issues and their [after-merge] items (existing);
- **untriaged:** no owner label;
- **stale verify:** `verify/pending` for more than 14 days;
- **idle:** no update for more than 30 days;
- **a waiting `owner/user` question:** raise it with the user once, batched, outside quiet hours
  (`decision-quiet-hours.md`).

Record the open count and what closed in `dev/status/backtest-perf.md` §Weekly review.

## D. The cap: 20 open issues

- **Above 20,** filing a new issue comes with closing, merging or folding one. Umbrella issues with a checklist count
  as one.
- **Research ideas no current plan will run** are closed as not-planned, with a reopen trigger in the close comment
  and a pointer in memory. Closing loses nothing: the issue stays searchable and can be reopened.
- **Every session handoff** (`dev/notes/next-session-priorities-*.md`) records the open-issue count.

## E. What QC can check

- **qc-results:** a results PR has a `Verifies` line, and each claimed item is met by a committed artifact.
- **qc-structural row I1** (unchanged): the issue-link grammar.

## Related

- `pr-merge-gates.md` §Issue links (#3019)
- `findings-registry.md`: closing a finding issue updates its registry row.
- `perf-review-weekly.md`: the weekly slot.
