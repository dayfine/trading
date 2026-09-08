---
name: token-usage-audit-2026-09-08
description: Quota audit 09-08 — cache READS of 450–995k-token main-session contexts ≈ 55% of spend, subagent cache WRITES (1h TTL) ≈ 40%; 72 qc-structural agents in 3 days vs ~20 reviews posted (same PR dispatched twice ~30 min apart); levers = cap main context ~300k via /handoff + /clear, never re-dispatch QC without checking the review count, 5m TTL for subagents if settable, trim .claude/rules (138 KB) per agent.
metadata:
  type: project
---

Full write-up: `dev/notes/token-usage-audit-2026-09-08.md` (method: `message.usage` over the local transcripts, main = depth-1 jsonl, subagents = depth-2).

**Why:** the user asked 09-08 why quota is burning fast. Measured 7d: cache reads 6.5B (main 3.5B / sub 3.0B), cache writes 225M (sub 171M, all `ephemeral_1h`), output 10M. Tool-result size is NOT the problem (p50 368 B). Main sessions ran to 800k–995k context and every turn re-reads it; the 09-08 earlier session (2,578 turns, peak 995k) ≈ half that day's spend.

**How to apply:** (1) `/handoff` + `/clear` around 300k context; batch independent calls per turn. (2) Before ANY QC re-dispatch: `sh dev/scripts/pr_gate_status.sh <N>` + `gh pr view <N> --json reviews --jq '.reviews|length'` — a dozen duplicate structural agents/day ≈ 10% of spend. (3) Check whether subagents can use the 5-minute cache TTL. (4) Keep rules to their checkable core; narratives go to dev/notes. Related: [[qc-review-format-must-parse]], [[container-capacity-scheduling]].
