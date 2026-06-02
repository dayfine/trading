---
name: Reprioritize short-side follow-ups after backtest-scale optimization lands
description: Short-side-strategy track is MERGED so orchestrator treats it closed; reopen + dispatch its 3 follow-ups once the backtest-scale optimization work (3f-part2/3f-part3 and successors) finishes
type: project
originSessionId: 91a091f6-8290-41a6-bf7e-9f9e4729da88
---
Once the backtest-scale optimization work lands (tracked in `dev/plans/backtest-scale-optimization-2026-04-17.md`; currently at 3f-part2 via PR #466, with 3f-part3 pending), reprioritize the short-side-strategy follow-ups.

**Why:** `dev/status/short-side-strategy.md` shows `MERGED` at the top, so orchestrator Step 4 treats the track as closed and never dispatches the §Follow-ups items (bear-window backtest regression, full short cascade, Ch.11 real-data spot-check). They appear only in the backlog tail of daily summaries. Not blocked technically — just deprioritized by the closed-track flag. User flagged 2026-04-20 that these should come back onto the active list after optimization throughput work is done.

**How to apply:** When 3f-part3 (and any stacked successors in the backtest-scale-optimization plan) merge, flip `dev/status/short-side-strategy.md` Status from `MERGED` to something dispatchable (e.g., `PENDING — follow-ups`) and/or add a new `dev/status/short-side-followups.md` track so Step 4 picks it up. Alternative: dispatch manually from a local session if orchestrator queue is still saturated.
