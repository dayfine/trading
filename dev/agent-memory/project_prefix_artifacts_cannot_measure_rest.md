---
name: project-prefix-artifacts-cannot-measure-rest
description: "Any artifact from before #2317 (2026-08-14) has fill ages capped at 0 or 1 week, so its rest-time and ticket-resolution numbers measure the join window — including the table the TTL {13,26,52} axis was chosen from."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7b9bffd9-4afb-483a-9e22-50b6142eb14c
  modified: 2026-08-18T19:31:09.285Z
---

Checked 2026-08-18 while measuring the ticket-funding cohort (PR #2371).

**The signature.** In every ladder-v4 artifact (run 2026-08-11, before #2317
landed on 08-14) `ticket_age_weeks_at_fill` takes **only the values 0 and 1** —
the 7-day reach-back of the date-proximity join
([[project-audit-join-date-proximity]]). Consequences for anything read off such
an artifact:

- **Rest-time distributions are the join window**, not resting time.
- **Ticket resolution is not measurable.** The 60–68% of placed tickets that
  "resolve to nothing" across arms (853/1,425 on cell 00; 2,245/3,482 on cell
  16) is mostly tickets that *did* fill and were not matched. Pre-#2348
  artifacts additionally record **zero** cancels of any kind, so nothing
  decomposes.
- **`trades.csv` is unaffected** where it is read directly: `exit_trigger` is a
  simulator-written column with no join, so groupings off the CSV are valid even
  on pre-fix artifacts (`dev/notes/exit-trigger-recompute-2026-08-18.md`).

**The consequence that matters.** The `{13, 26, 52}`-week TTL axis was chosen
from a rest-time table that **no artifact now on disk reproduces**. A
`position_id`-keyed measurement of the same nominal cell (arm 00 of the TTL
re-test) disagrees with it across every bucket — e.g. `>3yr` is +304,101 in the
record and −217,518 keyed.

⚠ **Do not call this a mis-join.** An earlier version of this memory did, and
that diagnosis was refuted in QC on #2368: a re-pairing permutes P&L across
buckets but **preserves the total**, and these totals move (+2,173,658 →
+2,314,953, a +141,295 gap) while the n also differ (1,146 vs 1,147). That is a
**different trade set**, not a mis-paired one — a reproducibility problem, not a
pairing bug. The `404 of 953` `position_id` coverage that motivated the
mis-join story is real but is **cell-13 scoped**, so it is not evidence about
either cell-00 measurement. Per `mechanism-validation-rigor.md` §"Verdict
calibration", the disagreement licenses *"not reproducible"* — it does not
license a causal account of why.

**How to apply.** Before quoting any rest-time / resolution / ticket-age figure,
check the artifact's max fill age; ≤ 1 week means the number is a join artifact.
`dev/experiments/ticket-funding-cohort-2026-08-18/rest_time_pnl.sh` enforces
this — it joins on `position_id` and refuses to report on a pre-#2317 artifact.
Re-derive the TTL axis from a post-#2317 run before running any clock arm.

Instance of [[feedback-always-dissect-before-reporting]]: the quantity was a
function of the join, not of the thing being varied.
