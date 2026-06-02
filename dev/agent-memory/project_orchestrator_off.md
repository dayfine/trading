---
name: GHA orchestrator on reduced cron (2 nightly slots)
description: Daily orchestrator cron reduced from 4 slots to 2 overnight slots (00:17 PT + 05:17 PT); substantive work still happens in dedicated sessions
type: project
originSessionId: 35c8f646-d23b-46d6-98b4-2e330e930c33
---
GHA `Daily orchestrator` workflow runs **2× per day** (00:17 PT + 05:17 PT) as of 2026-04-26 (PR #581). Previously 4 slots, then briefly turned off 2026-04-25 for cost, then reinstated at reduced cadence 2026-04-26 to cover routine agent work overnight while keeping substantive work in local sessions.

**Why:** cost vs coverage tradeoff. The 4×/day cron was ~$5/run even when Step 0.5 NO-OP fast-exit applied — overhead not worth it given the queue is mostly empty between human-driven bursts. But fully-off lost coverage of routine night work the human would have to manually trigger. Two overnight slots = ~$10/day cap with hands-off cleanup running while the human sleeps; daytime work remains local.

**How to apply:**

- Expect a daily summary on 2 cadences (post-00:17 PT and post-05:17 PT). Each writes `dev/daily/<date>[-runN].md` and `dev/budget/<date>-<run_id>.json`.
- After PR #583 (budget bundling) merges, the budget JSON is bundled into the daily summary PR — no separate `ops/budget-*` PR per run.
- Sub-agent dispatch + isolation worktrees are the same pattern in both GHA orchestrator runs and dedicated sessions.
- `health-deep-weekly.yml`, `image.yml`, `ci.yml` unaffected. `tiered-loader-ab.yml` was deleted in PR #581 (Tiered + Legacy both gone).
- To reduce/expand cadence: edit `.github/workflows/orchestrator.yml`'s `on.schedule` block. Comments in that file explain the `:17` minute choice.
