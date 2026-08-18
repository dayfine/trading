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
| `scenario_runner` stderr (`WARN: portfolio rejected fill …`) | per-rejection **required vs available cash** → the shortfall distribution, and the burst structure | 3,530 over the 20 ladder-v4 arm-blocks in `.sweep-output/ladder-v4.log` (2026-08-11) — see limit 5 on how this differs from the 19-arm `trades.csv` set |
| `trade_audit.sexp` of the TTL re-test cell 00 (tree `59b26c3bf` — post-#2317, **pre**-#2348) | per-ticket **rest-time**, joined to `pnl_dollars` on `position_id` | 1,147 joined round trips (§"The re-derived rest-time table") |
| `trade_audit.sexp` **post-#2348** — the source that would give per-ticket `cancel_reason` + cascade grade + date | **nothing yet — no such artifact exists on disk** | 0; needs a run on current `main` (§"Artifact side") |

Scripts: `cohort_from_log.sh` (stderr side), `cohort_from_audit.sh` (artifact
side, and the one that will decompose the cancel cohort once a post-#2348 run
exists), `rest_time_pnl.sh` (the rest-time join). All three are pure text
extraction — no container, no build, so they are safe to run while a sweep holds
the container.

## Finding 1 — the cohort is NOT a near-miss population

The plan's motivating case is `PRGS`, destroyed **\$397 (0.3%)** short. That case
is real and it sits **below the 1st percentile** (p1 = 0.8%), not on the shape:

```
shortfall as % of the ticket's required cost   (n = 3,530)
  p1  =  0.8%    p10 = 10.1%    p25 = 26.3%    p50 = 52.3%
  p75 = 76.9%    p90 = 92.0%    p99 = 99.0%     mean = 51.6%

  <=1%: 49 (1.4%)   1-5%: 132 (3.7%)   5-25%: 649   25-75%: 1,758   >75%: 942
```

**The median rejected ticket is short slightly more than half of what it needed.**
Only **5.1%** of the cohort is within 5% of being fundable.

The shape holds on **every arm with enough n to read it** — across the 16
ladder-v4 arms with n ≥ 90 (different stop widths, TTLs, anchors, nearfloor /
volconf settings), mean shortfall is **44.5–58.4%** and the ≤5% near-miss share
is **2.0–7.7%**. Over those 16 arms it reads as a property of the
sizing-vs-cash regime rather than of any one knob; the arms below n = 90 were
not tested, and limit 2 bounds how far this generalises.

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

63% of the cohort died in **groups on a single tick**: several tickets
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
2. **The 3,530 pool is 20 arm-blocks of one universe/window** (top-3000,
   2000-2026), not 20 independent samples — arms share the base and most of the
   calendar. The per-arm table shows the shape is stable across *configs*; it
   does not establish stability across *periods* or *universes*.
3. **The stderr side cannot see rank or date.** Only the audit side carries
   grade, rest-time and calendar. Rest-time became readable with #2317, which is
   why the join below could not have been made two weeks ago; grade and
   `cancel_reason` need #2348 and are **still not available** on any artifact
   here (§"Artifact side").
4. **No top-line claim is made or possible.** The 08-14 seeded null on this base
   is **132.5pp** (three salts: 265.44 / 281.71 / 397.95). Any of these axes will
   have to clear that, and this note deliberately produces no return number.
5. **The 20-arm stderr pool and the 19-arm `trades.csv` recompute were never
   reconciled.** `dev/notes/exit-trigger-recompute-2026-08-18.md` enumerates 19
   arms (`v4-00` … `v4-18`) — every ladder-v4 directory carrying a `trades.csv`
   — while this cohort counts 20 arm-blocks in the shared `ladder-v4.log`. With
   the artifacts off disk it is not determined whether one arm produced no
   `trades.csv` or whether the log carries a re-run block. No arm was dropped
   from either side for disagreeing with a result. Every figure here quantifies
   over the log's 20; every figure there over the CSVs' 19.

## Artifact side (cancel_reason join)

**Still pending, and not obtainable from this chain.** The TTL re-test runs from
a worktree pinned at `59b26c3bf` (#2349, the TTL split), which **predates #2348**
— `git merge-base --is-ancestor 1ebc37317 59b26c3bf` is false. So no arm of the
chain emits `cancel_reason`: arm 00 records **1,466 placed tickets and zero
cancels of any kind**, while its own log carries **262** `WARN: portfolio
rejected fill` lines. The decomposition needs a run from a tree containing
#2348; the next scenario run on current main is the first opportunity.

What the chain's tree *does* contain is #2317, which is why the rest-time join
below is valid.

The ladder-v4 artifacts cannot stand in for it, for two independent reasons:

1. They **predate #2348**, so `cancel_reason` is absent on every record — cell 00
   shows 1,425 placed tickets with **zero** cancels of any kind.
2. They **predate #2317**, so the fill side is join-limited too:
   `ticket_age_weeks_at_fill` only ever reads 0 or 1, and the 60–68% of placed
   tickets that "resolve to nothing" across arms is mostly the 7-day reach-back
   failing to match, not tickets that never resolved
   (`dev/notes/exit-trigger-recompute-2026-08-18.md` §"The defect").

Cell 00 of the TTL re-test runs at `59b26c3bf`, which contains #2317 but **not**
#2348 — re-verified here: `git merge-base --is-ancestor 1ebc37317 59b26c3bf`
exits 1 (false), and `1ebc3731` (#2348, Aug 16 01:13) landed **14 minutes after**
`59b26c3b` (#2349, Aug 16 00:59). So cell 00 is the first artifact that can
measure **rest time** — the join §"The re-derived rest-time table" rests on — and
it is **not** an artifact in which the placed-ticket population can be
decomposed: like ladder-v4 it emits zero `cancel_reason` of any kind.

**No artifact now on disk can decompose the placed-ticket population.** The
first that could is a scenario run from a tree containing #2348 — i.e. at or
after `1ebc3731`, which means a run on current `main`. That is the pending work
item; do not re-analyse cell 00 for it.

## Side effect — the cell-13 rest-time table the TTL axis was chosen from is not reproducible

`rest_time_pnl.sh` (added here) computes realized P&L by ticket rest time the
only way that is sound: `position_id` → `ticket_age_weeks_at_fill` from the
audit, `position_id` → `pnl_dollars` from `trades.csv`. It **refuses to report**
when the artifact's maximum fill age is ≤ 1 week, because that is the pre-#2317
signature rather than a distribution.

Both `trades.csv` columns it reads are resolved **by name from the file's own
header**, and it refuses if either is absent rather than falling back to an
index — the contract
`trading/trading/backtest/lib/trades_csv_schema.mli` states ("silently reading
the wrong cell is worse than reading nothing"). `position_id` sits *inside* the
trailing per-trade context block, so a writer that inserts at or ahead of it
shifts the index and a positional read returns a neighbouring cell that still
looks like data.

Run against ladder-v4 cell 00 it refuses, as it should: 572 fill ages, max 1
week. That matters beyond hygiene, because the `{13, 26, 52}` axis of the TTL
re-test was chosen from a rest-time table over **cell 13's "942 joined trades"**
— and cell 13's `trades.csv` carries a `position_id` on only **404** of its 953
round trips. A 942-row join over that artifact cannot have been keyed on
`position_id`; it was keyed on dates, which is the join class #2317 replaced.

That does not make the cell-13 table wrong, but it does mean **no run currently
on disk can reproduce the cell-13 table**, and the one internal cross-check
available already disagrees: the `>3yr` bucket is −154,006 on cell 13 and
+304,101 on cell 00 (the 08-18 priorities note). A 20–25 trade bucket flipping
sign between two arms of the same ladder is what an unverified join and a thin
tail look like from the outside — indistinguishable without the keyed join.

**This paragraph is about cell 13 only.** The `position_id`-coverage disproof
above (404 of 953) is a statement about *cell 13's* `trades.csv`; it is not
evidence about any other cell's, and nothing below extends it to one.

Arm 00 of the chain is the first artifact `rest_time_pnl.sh` will accept. The
axis re-derived from it is below — and it **disagrees** with the recorded cell-00
table the earlier premise came from.

## The re-derived rest-time table (arm 00, keyed join, max fill age 865 weeks)

1,147 of 1,147 round trips joined on `position_id`; total realized +2,314,952
(the bucket rows below sum to +2,314,953 — a \$1 artifact of per-bucket
rounding, not a missing trade).

| bucket | n | share | P&L \$ | per trade | win% |
|---|---:|---:|---:|---:|---:|
| ≤1wk | 698 | 60.9% | +1,710,291 | +2,450 | 32% |
| 2–4wk | 166 | 14.5% | −149,906 | −903 | 33% |
| **5–13wk** | 136 | 11.9% | **+1,021,434** | **+7,511** | 39% |
| 14–26wk | 58 | 5.1% | +82,266 | +1,418 | 40% |
| 27–52wk | 29 | 2.5% | −148,226 | −5,111 | 24% |
| 1–3yr | 35 | 3.1% | +16,612 | +475 | 37% |
| **>3yr** | 25 | 2.2% | **−217,518** | **−8,701** | 28% |

**F1 — the 5–13 week profit band confirms as to sign and rank, not magnitude.**
11.9% of fills carry 44% of realized P&L at +7,511/trade, the best per-trade
bucket outside the two-trade `extension_stop` tail. `ttl4`'s 28-day cut still
lands on its lower edge, so the `{13, 26, 52}` axis remains the right one. What
"confirms" means here is narrow: the recorded table (F2 below) puts the same
bucket at +1,596,587 / +11,740 per trade, so the **magnitude moved −575,153**
even as the rank held. Only the ordering is being confirmed.

**F2 — this table and the recorded cell-00 table disagree in every bucket, and
the cause is not established.** `dev/notes/next-session-priorities-2026-08-18.md`
and `dev/agent-memory/project_rest_time_pnl_is_cell_specific.md` record a cell-00
rest-time table whose `>3yr` bucket is **+304,101 on 25 trades (+12,164/trade,
"second-highest per-trade in the run")**, and conclude that defect E's absurdity
bound "would cut a *profitable* population on this base". The keyed-join
measurement above puts that bucket at **−217,518 (−8,701/trade) on 25 trades**.

The divergence is not confined to that bucket. Against the recorded table, at
near-identical per-bucket n:

| bucket | recorded (n) | this run (n) | recorded P&L | this run P&L | Δ |
|---|---:|---:|---:|---:|---:|
| ≤1wk | 696 | 698 | +679,738 | +1,710,291 | **+1,030,553** |
| 2–4wk | 167 | 166 | −201,330 | −149,906 | +51,424 |
| 5–13wk | 136 | 136 | +1,596,587 | +1,021,434 | **−575,153** |
| 14–26wk | 58 | 58 | +3,254 | +82,266 | +79,012 |
| 27–52wk | 29 | 29 | +11,622 | −148,226 | −159,848 |
| 1–3yr | 35 | 35 | −220,314 | +16,612 | +236,926 |
| >3yr | 25 | 25 | +304,101 | −217,518 | **−521,619** |
| **total** | **1,146** | **1,147** | **+2,173,658** | **+2,314,953** | **+141,295** |

**What this establishes, and what it does not.** Every bucket moved and the run
total moved; the two row counts differ (1,146 vs 1,147, and two tickets sit on
opposite sides of the 1-week boundary), so these are **not the same set of
trades** and "the same 25 trades" is not a claim this measurement supports for
the `>3yr` row either. The honest statement is: **the recorded cell-00 table is
not reproducible from any artifact now on disk, and a `position_id`-keyed
measurement on the post-#2317 arm 00 disagrees with it across the whole table.**

The *cause* is unestablished, and three candidates remain open, none of which
this PR can distinguish without the artifacts:

1. **Two different runs both labelled "cell 00."** The recorded table states
   1,145 filled tickets (its own rows sum to 1,146); this one joins 1,147.
2. **A reader difference on the `trades.csv` side.** Until the fix in this PR,
   `rest_time_pnl.sh` addressed `position_id` by fixed index. On the current
   21-column layout that index is in fact correct (verified against
   `Result_writer._trades_csv_header` + `Trade_context.csv_header_fields`), so
   the table above is not affected — but nothing pins which reader produced the
   *recorded* figure, and a fixed-index read of a different vintage returns a
   neighbouring cell silently. The hazard is removed going forward; it cannot be
   retro-applied to a figure whose reader is unrecorded.
3. **A genuine data difference** between the two trees.

Explicitly **not** established: that the earlier figure is a mis-join artifact.
Its own record (`project_rest_time_pnl_is_cell_specific`) states it was joined
`position_id` → `ticket_age_weeks_at_fill` → `pnl_dollars` — the *same* key this
script uses — so the recorded provenance contradicts that diagnosis rather than
supporting it. The `404 of 953` coverage disproof above is about **cell 13** and
is not evidence about either cell-00 measurement. Per
`.claude/rules/mechanism-validation-rigor.md` §"Verdict calibration", a
disagreement between two measurements licenses *"not reproducible"*; it does not
license a causal account of why.

Read individually, this run's `>3yr` cohort is what defect E described: the
worst is BLDP resting **380 weeks** for −39,827, the longest rest is **865 weeks
(16.6 years)**, and only a handful are positive. That description is of *this*
run's 25 trades and is not offered as a correction of the recorded 25.

**F3 — every candidate clock cuts a net-losing cohort.** Gross effect of
cancelling tickets that rested longer than each bound:

| clock | fills cut | realized P&L of the cut cohort | as % of total realized |
|---|---:|---:|---:|
| 13w | 147 | −266,866 | +11.5% if removed |
| **26w** | 89 | **−349,132** | **+15.1% if removed** |
| 52w | 60 | −200,906 | +8.7% if removed |
| 156w | 25 | −217,518 | +9.4% if removed |

**This changes the narrowing decision in #2368.** That PR deferred the clock arms
because their *top-line* effect (8–30pp) sits 4–13× below the 132.5pp null — which
is true and remains true. But the metric it named as the one that could resolve
them ("per-bucket realized P&L on the arm's own trades") is exactly the table
above, and it is **within-run accounting, not a between-run difference**, so the
null does not apply to it. On this base the clock is not a coin flip: every bound
tested removes money-losing fills, with 26 weeks the largest at 15% of realized
P&L.

**Calibration.** Gross ≠ net: cancelling a resting ticket frees its capital,
which the walk redeploys into some other candidate, and that replacement's P&L is
unmeasured. These figures bound the effect, they do not predict it. It is also
one salt on one base. The honest conclusion is *"the clock axis is worth running
and #2368's deferral rested on a number this run does not reproduce"* — not
*"#2368's number was wrong"*, which F2 does not establish, and not *"a 26-week clock
is worth +15%"*.
