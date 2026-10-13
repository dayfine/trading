# Dispatcher cadence: wait in the background, keep a heartbeat, hand off at a queue boundary

The dispatcher's context is its own operational log, not the codebase. The 2026-09-08 token audit
(`dev/notes/token-usage-audit-2026-09-08.md`, issue #2738) found a 995k-token session whose growth was Bash
inputs and results, plus 118 near-identical agent briefs, with zero `Read` calls. In one evening, 53 of 144
API calls were 30-second foreground poll loops, and every poll re-reads the whole context: a poll at 350k
costs 2.3× one at 150k.

## The rules

1. **A wait longer than ~5 minutes runs in the background.** Use `dev/scripts/wait_for.sh` under the
   harness's background mode (Bash `run_in_background`), so the session gets one turn back when the condition
   fires:

   | waiting on | command |
   |---|---|
   | a chain cell / lane | `sh dev/scripts/wait_for.sh --max-minutes 240 log <chain.log> '^RESULT <tag>'` |
   | CI on a PR | `sh dev/scripts/wait_for.sh --max-minutes 60 checks <PR>` |
   | a QC review to post | `sh dev/scripts/wait_for.sh --max-minutes 60 reviews <PR> <count>` |
   | dune in the container | `WAIT_FOR_PS='docker exec trading-1-dev ps -eo stat=,args=' sh dev/scripts/wait_for.sh proc 'dune (build\|runtest)'` |

   It exits 0 when the condition holds and 2 on timeout. Every exit prints the UTC time and the elapsed
   seconds. A `checks` exit says only that every check run registered on the PR head has completed: read
   `fail=` in its line before acting. The PR conditions use `gh api` (REST), so they also work in Claude
   cloud sessions, where `gh pr checks` and `gh pr view` (GraphQL) are refused.
   A dispatched subagent is its own event: its completion notification is the wake, so do not poll for it.

2. **Every background wait has a fallback heartbeat.** An event can fail to fire back. Two stall classes are
   on record (`feedback_two_stall_classes_check_clock`, `feedback_agents_background_wait_stall`). Alongside
   the wait, arm one scheduled wake 20–30 minutes out: `send_later` in a cloud session, `ScheduleWakeup` in a
   `/loop`. When it fires, re-check the same condition and the clock, and re-arm it if the wait is still
   pending. Never wait on a bare event, and never run a 30-second foreground loop.

3. **Never `sleep`-poll in the foreground.** A foreground `until …; do sleep 30; done` holds the turn, and
   each iteration that ends a turn re-reads the context. The only foreground waits are bounded commands that
   finish within one tool call, such as a scoped `dune runtest` with `timeout: 600000`.

4. **Hand off at a queue boundary, not at a token count.** End or compact a session when the remaining work is
   only waits, such as a chain running or PRs waiting on reviewers, and not partway through a merge wave.
   Compaction thresholds stay as `session-rampup.md` Step 3 sets them; there is no flat context cap.

## Known hazards the helper accounts for

- **Zombie dune.** A `docker exec` killed at its time limit leaves defunct `dune` entries, and
  `pgrep -x dune` keeps matching after dune has exited. `wait_for.sh proc` ignores `Z` state.
- **Dune lock.** A backgrounded build that outlives its tool call still holds the dune lock, and the next
  foreground `dune` aborts with "Another Dune instance is currently running". Wait on
  `proc 'dune (build|runtest)'` before starting the next build.

## Related

- `container-capacity-scheduling.md`: what may run while you wait.
- `session-rampup.md` Step 3: when to compact.
- `pr-gate-loop.md`: the gate loop this cadence drives.
