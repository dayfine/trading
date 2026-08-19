---
name: project-rest-time-pnl-is-cell-specific
description: "SUPERSEDED — this table's per-bucket P&L is not reproducible from any artifact on disk; the >3yr bucket is negative on the keyed measurement, so defect E's premise was never refuted. Kept as a record of the withdrawn figures."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7b9bffd9-4afb-483a-9e22-50b6142eb14c
  modified: 2026-08-18T19:58:06.694Z
---

⚠ **SUPERSEDED 2026-08-18.** The table below is retained as the durable record
of what was claimed; **do not cite its numbers.** Current facts live in
[[project-prefix-artifacts-cannot-measure-rest]] and the TTL results writeup
(`dev/experiments/ttl-retest-2026-08-16/results.md`).

## What was recorded (2026-08-17) — WITHDRAWN

Cell 00, stated as 1,145 filled tickets joined `position_id` →
`ticket_age_weeks_at_fill` → `pnl_dollars`:

| bucket | n | realized pnl | pnl/trade |
|---|---:|---:|---:|
| wk 0-1 | 696 | 679,738 | 977 |
| wk 2-4 | 167 | −201,330 | −1,206 |
| **wk 5-13** | 136 | **1,596,587** | **11,740** |
| wk 14-26 | 58 | 3,254 | 56 |
| wk 27-52 | 29 | 11,622 | 401 |
| wk 53-156 | 35 | **−220,314** | −6,295 |
| **wk >156** | 25 | **+304,101** | **+12,164** |

## What replaced it

A `position_id`-keyed measurement on `ttl-retest-00-null` (same nominal cell,
post-#2317 tree, 1,147 of 1,147 round trips joined, max fill age 865 weeks)
disagrees across **every** bucket. Most consequentially the `>3yr` bucket is
**−217,518** (−8,701/trade, 28% winners), not +304,101.

- **What survives:** the **5-13 week band is the profit band** (+1,021,434 on
  136 trades, +7,511 each), so the `{13, 26, 52}` axis is still the right one.
  Only the ordering transferred; the magnitudes did not.
- **What does not:** "defect E's premise is cell-specific" and "a 156-week bound
  cuts a profitable population". On the keyed measurement the long-rest
  population loses money, so **defect E was never refuted**. The worst ticket
  rested 380 weeks to lose 39,827; the longest rested 865 weeks (16.6 years).
- **Also withdrawn:** the gross-attribution figures (13w −98,663, 26w −101,917,
  52w −83,787, 156w −304,101) and the conclusion drawn from them. Keyed, every
  bound cuts a **net-losing** cohort — 26w largest at −349,132 over 89 fills.

**Not a mis-join.** An earlier correction of mine claimed that; it was refuted
in QC on #2368 and the refutation is right. A re-pairing permutes P&L across
buckets but preserves the total, and these totals move (+2,173,658 →
+2,314,953) while the n differ (1,146 vs 1,147). That is a **different trade
set** — a reproducibility problem, not a pairing bug.

## What still applies

The two process lessons are unaffected, and one is strengthened:

- **Re-derive any borrowed distribution on the base you are actually running.**
  This episode is now its own best example: the borrowed table survived into two
  PRs and a memory before anyone re-measured it.
- **Convert a motivating table into a predicted effect size and compare it to
  the null before spending a run** ([[feedback-run-the-null-control-first]]) —
  but note the null must *bound the metric you are reading*. The 132.5pp figure
  is a **between-run** null and does not bound a **within-run** per-bucket
  cohort accounting. Applying it to the wrong metric is what retired four arms
  on a bad argument.

See [[project-ttl-is-a-tail-lever]].
