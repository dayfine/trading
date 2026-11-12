# GHA ↔ local-session coordination — blocking vs non-blocking dispatch

When I move work to the **GHA orchestrator** (by adding Next-Steps to a
`dev/status/<track>.md` file) instead of running it in the local interactive
session, I must **classify** each item and **track** it accordingly. Without
this, two failures recur: (a) silently relying on a slow cron for something I
actually need this session, then being stuck; (b) losing a handoff obligation
across a session boundary because nothing recorded that I was waiting on a
remote PR.

## The load-bearing constraint: GHA cron cadence

The orchestrator runs on a **reduced cron — 2 slots/day (~00:17 / 05:17 PT)**
(`memory/project_orchestrator_off`). So a GHA-scoped item has an inherent
**up-to-~12h latency before a run even picks it up**, plus its dispatch + QC +
merge time. That cadence is the reason the classification below matters: GHA is
for work whose "soon" means *"within a day"*, never *"this session."*

## Two classes — tag every GHA-scoped Next-Step as one

### `[non-blocking]` — fire-and-forget
Nothing local or near-term depends on it. The orchestrator's normal
dispatch → QC → merge loop owns it end to end. **I do NOT poll it, and I do NOT
hold the local session open for it.** This is the **default** class — use it for
follow-ups, nice-to-haves, and anything already mitigated by a shipped patch.

### `[blocking: by <checkpoint>; reclaim-if-untouched]` — handoff-with-followup
Something I'm counting on lands soon — a downstream local step, a stated user
expectation, or an experiment that gates a decision. For these I MUST:
1. **Record an expected-by checkpoint** — concretely "the next cron slot + ~1h
   run buffer" (the next 00:17 / 05:17 PT, +1h).
2. **Check back at the checkpoint** — does the remote branch/PR exist and has it
   progressed? `gh pr list --repo dayfine/trading --head <track-bookmark>`, or
   the track's Open-PR column in `dev/status/_index.md`, or recent orchestrator
   run logs (`gh run list --workflow <orchestrator> --limit 3`).
3. **Take it over locally** if ALL of: (a) the checkpoint has passed, (b) GHA
   hasn't started it (no branch/PR, status unchanged), and (c) the local session
   has free capacity. Don't wait two cron cycles for something you need sooner —
   reclaim it (see Takeover below).

## When NOT to use GHA at all
If the result is needed **sooner than the next cron slot + run time** (realistically
within the next few hours), do NOT scope it to GHA — run it locally from the
start. A tight-deadline blocking item belongs local. GHA-blocking is only
coherent when "soon" is a day-ish, not hours.

## Where the tracking state lives (must survive a session boundary)
- **In the track file:** the `[non-blocking]` / `[blocking: …]` tag on each
  GHA-scoped Next-Step (so the obligation is visible to the next session and to
  the orchestrator).
- **In the session handoff / priorities doc:** a one-line **"GHA watch"** entry
  per blocking item — `check PR for track <X> by <time>; reclaim locally if
  untouched`. This is the durable carry across sessions; a blocking item with no
  GHA-watch line is an obligation about to be dropped.

## Takeover protocol (reclaiming a GHA item locally)
1. **Confirm it's untouched.** `gh pr list --head <bookmark>` + the orchestrator
   run logs. If a remote agent is **mid-flight, do NOT duplicate** — let it
   finish or coordinate; double-dispatch wastes work and creates merge conflicts.
2. **Claim it in the track file** (a quick docs commit): owner →
   `local-session (<date>)`, status note `claimed from GHA <time>`. The next
   orchestrator run then **skips** it (it dispatches per owner/status).
3. **Run it locally**, land the PR.
4. **Release** if you abandon it: owner → back to the feat-agent, so GHA can
   resume it.

## Collision avoidance (the inverse direction)
Work I'm running **locally** must NOT also be a dispatchable Next-Step the
orchestrator reads — or it must be explicitly fenced. Annotate the track:
`in flight locally (<session>), do not dispatch` (as the warmup-flip note does
in `cash-floor-correctness.md` §"Not in scope here"). The orchestrator's
pre-flight check (CLAUDE.md "verify the named module/PR doesn't already exist")
is a backstop, not a substitute for the fence.

## Worked example (2026-06-13)
- **Warmup-trading default flip** — `local + blocking` (user's correctness
  priority, re-pins goldens, needs oversight). Kept OUT of GHA; fenced with a
  "not in scope here / in flight locally" note on the cash-floor track so the
  orchestrator won't touch it. No GHA-watch line (it's local, not remote).
- **Cash-floor cluster (NS1-NS4, `cash-floor-correctness.md`)** — `[non-blocking]`.
  The motivating zombie (#1553) is already mitigated by #1556's shipped patch,
  so the root fix + experiment can land whenever the cron gets to them. No
  check-back obligation; the orchestrator owns them end to end. (If a downstream
  local step ever started *depending* on NS1 landing, I'd re-tag it
  `[blocking: …]` and add a GHA-watch line.)

## What this prevents
- Treating a 2-slot cron as if it were a synchronous worker.
- Double-dispatching one track from local + GHA simultaneously.
- Dropping a blocking handoff at a session boundary (the GHA-watch line is the
  durable carry).
