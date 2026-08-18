# Ticket-funding rejection cohort — the measurement, 2026-08-18

Step 2 of `dev/plans/ticket-funding-2026-08-16.md` ("then measure the cohort,
from the artifact rather than from stderr greps"), run before any of the three
axes (G2a retry / G2b size-to-available / G3 reserve-at-placement) is built.

`screen-rigor` applies: this is a **read-only measurement of the rejected
population**, not a measurement of what the rejections cost. Every "what we gave
up" statement is a counterfactual and is labelled as one.

## What was measured, and from what

| source | what it gives | n |
|---|---|---|
| `scenario_runner` stderr (`WARN: portfolio rejected fill …`) | per-rejection **required vs available cash** → the shortfall distribution, and the burst structure | 3,530 over 20 ladder-v4 arms (`.sweep-output/ladder-v4.log`, 2026-08-11) |
| `trade_audit.sexp` (post-#2348) | per-ticket **cancel_reason + rest-time + cascade grade + date** | the TTL re-test cell 00 run (see below) |

Scripts: `cohort_from_log.sh` (stderr side), `cohort_from_audit.sh` (artifact
side). Both are pure text extraction — no container, no build, so they are safe
to run while a sweep holds the container.

## Finding 1 — the cohort is NOT a near-miss population

The plan's motivating case is `PRGS`, destroyed **\$397 (0.3%)** short. That case
is real and it is the **1st percentile**, not the shape:

```
shortfall as % of the ticket's required cost   (n = 3,530)
  p1  =  0.8%    p10 = 10.1%    p25 = 26.3%    p50 = 52.3%
  p75 = 76.9%    p90 = 92.0%    p99 = 99.0%     mean = 51.6%

  <=1%: 49 (1.4%)   1-5%: 132 (3.7%)   5-25%: 649   25-75%: 1,758   >75%: 942
```

**The median rejected ticket is short slightly more than half of what it needed.**
Only **5.1%** of the cohort is within 5% of being fundable.

The shape is **config-invariant** — across the 16 ladder-v4 arms with n ≥ 90
(different stop widths, TTLs, anchors, nearfloor / volconf settings), mean
shortfall is **44.5–58.4%** and the ≤5% near-miss share is **2.0–7.7%**. It is a
property of the sizing-vs-cash regime, not of any one knob.

Supporting scale (same pool): the ticket's designed cost has p50 ≈ **\$245k**,
while available cash at the moment of rejection has p50 ≈ **\$101k**. Only **87
of 3,530** rejections (2.5%) happened with a genuinely empty book (< \$5k).
So the typical failure is *"the book has 40% of this ticket"*, not *"the book has
nothing"* and not *"the book is a rounding error away"*.

## Finding 2 — 63% of rejections are bursts against one cash balance

Grouping rejections by the exact `Available:` figure they were refused against:

```
distinct available-cash values : 2,094 over 3,530 rejections
bursts of > 1 rejection        :   771, covering 2,207 rejections (63%)
largest bursts                 : 18, 14, 12, 11, 11 tickets on one balance
```

Two thirds of the cohort died in **groups on a single tick**: several tickets
triggered the same week, the first ones consumed the cash, and the rest were
refused in arrival order. This is the mechanism behind
`project_ticket_dies_on_cash_shortfall`'s "selection at trigger = arrival order,
not rank" — measured here rather than inferred from one symbol.

## What this does to the three axes

The measurement changes the expected shape of all three, and it argues they are
**not** equally promising:

- **G2a `entry_fill_reject_retries`** — the plan already predicted this one fails
  because retrying enters later and worse, into `entry_extension_max_pct`. The
  cohort adds a second, independent reason: with a median shortfall of 52% and
  63% of the population arriving in bursts, a retry on the next tick is asking
  for **half a position's worth of new cash** to appear, not for a rounding
  error to clear. The near-miss population a retry would rescue cheaply is ~5%
  of the cohort.
- **G2b `entry_fill_size_to_available`** — this axis is the one the measurement
  *reshapes* rather than weakens. It would fill at the median **≈ 48% of the
  designed size** (p25 ≈ 74%, p75 ≈ 23%, p90 ≈ 8%). So the "minimum viable size"
  guard is not a detail — it *is* the mechanism: set it high and the axis is
  nearly a no-op, set it low and the book systematically takes fractional
  positions into exactly the breakouts it wanted full size in. That is a direct
  `project_edge_is_the_fat_tail` exposure, and it is why the min-size fraction
  must be the swept dial, not a constant.
- **G3 `reserve_cash_for_resting_tickets`** — the burst structure is a direct
  argument *for* this axis. The failure is **aggregate over-commitment** (more
  tickets written than the book can fund, resolved by arrival order), not
  per-ticket bad luck; reserving at placement is the only one of the three that
  removes the over-commitment rather than arbitrating it. It also cuts ticket
  count, which is the direction `project_record_gap_is_concentration` says the
  record arm runs (4.9 concurrent positions vs our 10.6 at the same exposure).

**Recommended build order (revision to the plan's "one grid over all three"):**
G3 first, G2b second with its min-size fraction as the axis, G2a last or not at
all. The grid still ranks all three, but G2a no longer deserves an equal share of
the build budget.

## Limits of this measurement — what it cannot say

1. **It measures the rejected population, not the loss.** Nothing here says the
   destroyed tickets would have been profitable. AXTI's 5.8× is one path, and
   `project_edge_is_the_fat_tail` cuts both ways: a fatter entry population
   contains more monsters *and* more of everything else.
2. **The 3,530 pool is 20 arms of one universe/window** (top-3000, 2000-2026),
   not 20 independent samples — arms share the base and most of the calendar.
   The per-arm table shows the shape is stable across *configs*; it does not
   establish stability across *periods* or *universes*.
3. **The stderr side cannot see rank or date.** The artifact side (below) is what
   carries grade, rest-time and calendar; before #2348 those columns did not
   exist, which is why this measurement could not have been made two weeks ago.
4. **No top-line claim is made or possible.** The 08-14 seeded null on this base
   is **132.5pp** (three salts: 265.44 / 281.71 / 397.95). Any of these axes will
   have to clear that, and this note deliberately produces no return number.

## Artifact side (cancel_reason join)

Pending the TTL re-test cell 00 run (in flight at time of writing; the artifact
lands with the chain's first RESULT line).

The ladder-v4 artifacts cannot stand in for it, for two independent reasons:

1. They **predate #2348**, so `cancel_reason` is absent on every record — cell 00
   shows 1,425 placed tickets with **zero** cancels of any kind.
2. They **predate #2317**, so the fill side is join-limited too:
   `ticket_age_weeks_at_fill` only ever reads 0 or 1, and the 60–68% of placed
   tickets that "resolve to nothing" across arms is mostly the 7-day reach-back
   failing to match, not tickets that never resolved
   (`dev/notes/exit-trigger-recompute-2026-08-18.md` §"The defect").

Cell 00 of the TTL re-test runs at `59b26c3bf`, after both fixes, and is the
first artifact in which the placed-ticket population can be decomposed at all.

## Side effect — the rest-time table the TTL axis rests on is not reproducible

`rest_time_pnl.sh` (added here) computes realized P&L by ticket rest time the
only way that is sound: `position_id` → `ticket_age_weeks_at_fill` from the
audit, `position_id` → `pnl_dollars` from `trades.csv`. It **refuses to report**
when the artifact's maximum fill age is ≤ 1 week, because that is the pre-#2317
signature rather than a distribution.

Run against ladder-v4 cell 00 it refuses, as it should: 572 fill ages, max 1
week. That matters beyond hygiene, because the `{13, 26, 52}` axis of the TTL
re-test was chosen from a rest-time table over **cell 13's "942 joined trades"**
— and cell 13's `trades.csv` carries a `position_id` on only **404** of its 953
round trips. A 942-row join over that artifact cannot have been keyed on
`position_id`; it was keyed on dates, which is the join class #2317 replaced.

That does not make the table wrong, but it does mean **no run currently on disk
can reproduce it**, and the one internal cross-check available already
disagrees: the `>3yr` bucket is −154,006 on cell 13 and +304,101 on cell 00
(the 08-18 priorities note). A 20–25 trade bucket flipping sign between two arms
of the same ladder is what an unverified join and a thin tail look like from the
outside — indistinguishable without the keyed join.

Arm 00 of the chain is the first artifact `rest_time_pnl.sh` will accept. The
axis should be re-derived from it before any clock arm is run.
