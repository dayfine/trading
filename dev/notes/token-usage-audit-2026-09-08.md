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
