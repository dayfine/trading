# Token / quota usage audit — 2026-09-08

Source: the local Claude Code transcripts for this project
(`~/.claude/projects/-Users-difan-Projects-trading-1/**/*.jsonl`, `message.usage`
per assistant turn; main sessions = depth-1 files, subagents = depth-2). Window:
2026-09-01 .. 09-08. Weights used to rank levers: fresh input 1×, cache read
0.1×, cache write (1-hour ephemeral, which is what every turn here uses) 2×,
output 5×.

## Where the tokens go

| day | main turns | main cache-read | main avg ctx/turn | sub turns | sub cache-read | sub cache-write |
|---|---:|---:|---:|---:|---:|---:|
| 09-05 | 768 | 370M | 481k | 1,303 | 158M | 9.2M |
| 09-06 | 1,030 | 514M | 499k | 4,335 | 724M | 42.2M |
| 09-07 | 485 | 407M | **839k** | 1,523 | 208M | 10.0M |
| 09-08 | 1,400 | 639M | 456k | 5,824 | 817M | 48.6M |

7-day totals: cache reads 6.5B (main 3.5B, sub 3.0B), cache writes 225M
(main 53M, sub 171M), output 10.4M, fresh input 0.6M. Weighted, cache reads
≈ 55%, cache writes ≈ 40%, output ≈ 5% of spend. Tool results are NOT the
bloat (6,618 subagent tool results in 3 days: p50 368 bytes, p90 4.6 KB,
max 27 KB).

## The four levers, ranked

1. **Main-session context length.** Sessions run to 800k–995k tokens of
   context (09-08 earlier session: 2,578 turns, peak 995k; 09-06: 887k;
   09-04: 860k) and every turn re-reads all of it. The 09-08 earlier session
   alone is ~1.3B cache-read tokens ≈ half the day's weighted spend. A
   session capped at ~300k context costs 2–3× less per turn for the same
   work, and the late-session turns are the low-value ones (polls, merges).
   **Action:** `/handoff` + `/clear` at ~300k (the handoff doc already exists
   as the durable carry), batch independent tool calls into one turn, keep
   polls to one bounded loop per turn (today: 16 of 184 turns were polls,
   fine).
2. **Duplicate QC dispatches.** 3-day counts: **72 qc-structural agents and
   25 qc-behavioral agents**, against ~20 structural and ~24 behavioral
   reviews actually posted on the PRs merged since 09-06. The structural
   transcripts show the same PR dispatched twice ~30 min apart on 09-08
   (#2717 07:00/07:33, #2720 09:07/09:35, #2724 11:07/12:22, #2725
   12:23/12:58, #2728 12:19/12:46); 09-06 ran 28 structural agents. A
   structural run ≈ 77 turns, ~9M cache-read, ~0.6M cache-write. Roughly a
   dozen wasted agents/day ≈ 10% of daily spend. **Action:** before any
   re-dispatch run `sh dev/scripts/pr_gate_status.sh <N>` and
   `gh pr view <N> --json reviews --jq '.reviews|length'`; the "post FIRST,
   then verify the count" rule (`feedback_qc_review_format_must_parse`)
   exists because agents were finishing with a verdict and no post — the
   re-dispatch is the expensive symptom of that. Consider one combined
   structural+behavioral pass for PRs under ~100 lines that touch no domain
   logic.
3. **Subagent cache writes at the 1-hour TTL.** Subagent cache writes are
   171M/7d, all `ephemeral_1h` (2× price vs 1.25× for 5-minute). A QC or feat
   agent runs 5–45 min of back-to-back turns; it never benefits from the
   hour. If the TTL is a per-session or per-agent setting, moving subagents
   to 5-minute would cut ~37% of their write cost (≈ 15–20% of total). Worth
   one check in the Claude Code settings; not verified here.
4. **Injected context per agent.** Every agent's system prompt carries
   CLAUDE.md (14.5 KB) + all of `.claude/rules/*.md` (138 KB) + MEMORY.md
   (25 KB) ≈ 45k tokens, written to cache on every spawn (~45 agents/day →
   ~2M cache-write/day ≈ 2–3% of spend) and read on every turn. The rules
   directory is mostly narrative incident history (sweep-hygiene,
   container-capacity, promotion-confirmation, gha-local-coordination …)
   that a QC agent never needs. **Action:** keep each rule to its checkable
   core and move the incident narratives to `dev/notes/`; MEMORY.md is an
   index and should stay one line per entry (it is 25 KB now).

## What is NOT worth chasing

- Output tokens (10M/7d, ~5%): the verbosity of reviews/PR bodies is fine.
- Tool-result size: small, see above.
- Poll loops in the main session: ~9% of turns, each a cheap cache read at
  the current context; the fix for their cost is lever 1, not fewer polls.

## Correction (21:55 PT, same day) — absolute figures above are ~2× too high

The transcript writes one record per content block, and a message with a
text block plus a tool_use block appears twice with the same `usage`. Deduped
on `message.id`: 7-day cache reads **3.2B** (not 6.5B), cache writes **98M**
(not 225M); this session **144 API calls / 35M cache reads** (not 373 / 91M).
Every ratio, the per-day shape, and the lever ranking are unchanged (both
halves scale together). Read the tables above as "÷2".

Per-turn shape of this session, deduped: context grew 150k → 350k over 144
calls; 53 of the calls were bounded 30-second poll loops, ≈16% of the reads.
The expensive pattern is not the context size itself but **wait-turns issued
at a large context** — a poll at 350k costs 2.3× a poll at 150k for the same
information. That points at cadence rules rather than a context cap (see the
handoff discussion of 2026-09-08 evening).

## What actually fills a 995k context (measured on the 09-07/08 session, 1,171 API calls)

Not the codebase. The transcript's message content is ≈ 2.1 MB: **Bash tool
inputs 0.74 MB** (741 calls — long heredocs, chain launches, analysis
one-liners), **Bash results 0.60 MB** (avg 0.8 KB; the largest single result
27 KB), **Agent briefs 0.45 MB** (118 dispatches × 3.8 KB — the same
NO-WAITING / checkout / docker-wrapper / review-format boilerplate re-typed
each time), assistant text + thinking 0.17 MB. No `Read` calls at all; no
file is loaded twice. The context is the operational log of a very long
dispatcher session, so "progressive disclosure of the codebase" is not the
lever here — the codebase is already loaded on demand and barely appears.

Smarter rules than a context cap, in order of expected saving:

1. **Wait by event, not by poll.** 53 of this session's 144 calls were
   bounded 30-second poll loops; a poll at 350k costs 2.3× one at 150k for
   the same bit of information. A waiting script run with the harness's
   background mode returns ONE turn when the cell / CI / agent finishes.
   Rule: any wait expected to exceed ~5 minutes runs as a background
   command that exits on the condition — never as a foreground sleep loop —
   and the longer the context, the stricter this gets.
2. **Boilerplate lives in the agent definition, not the brief.** Move the
   NO-WAITING rule, the plain-git checkout, the docker-wrapper fallback, the
   review-format block, and the finish protocol into
   `.claude/agents/qc-*.md` / `feat-*.md`; a brief then carries only the PR
   number, tip SHA, scope, and the review file path (~0.5 KB, not 4 KB).
   This is a harness-maintainer item (GHA-dispatchable).
3. **Hand off at a queue boundary, not at a token count.** When the
   remaining queue is waits (cells, CI, agents) rather than work that uses
   what is in context, write the handoff and clear; when the context is
   being used (a dissection referencing earlier numbers), keep it whatever
   its size. The write-back to the record (README / handoff) is the moment
   the context's value drops.
4. **Dispatcher-side dedupe of QC** (unchanged from above; ≈10%).
5. The earlier "cap at ~300k" line is withdrawn (user, 09-08: "that's
   aggressive").

Refinement to rule 1 (user, 09-08): an event can fail to fire back (two
stall classes are already on record), so the background wait is paired with
a long fallback heartbeat — a 20–30 minute scheduled re-check of the same
condition plus the clock — never a bare event wait, never a 30-second
foreground loop. Harness item: issue #2738.
