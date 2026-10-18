---
name: batch-model-run
description: Plan and run a large batch of headless model calls (claude -p readers, judges, image reads) on the plan quota without draining the week. Use before any job that makes more than ~200 model calls, e.g. a fresh-eyes reader pass, a blind-judge cohort, or a bulk chart read.
---

# Batch model run: project the cost, pilot, stage, guard

Origin: the fresh-eyes forward pass (2026-10-14) made 5,337 Opus calls ($429.52 notional) in under a day, used up
what was left of the weekly plan quota, then held four workers in retry loops for three days while every other
session was blocked. The dollar cap ($1,200) never fired, because the binding limit was the quota, not dollars.
Record: `dev/plans/fresh-eyes-staged-2026-10-18.md` §1.

## 1. Before writing the driver: a projection table

Write it in the plan, one row per call type:

| call type | calls | $/call | cost |
|---|---|---|---|

- **$/call** from a measured pilot, not a guess. Opus with one ~2400 px image and a ~25k cached prefix costs about
  $0.08; the new image is ~70 % of that (it is written to cache and never re-read). Sonnet is roughly a third.
- **Calls** = units × looks per unit. Count the looks that will return "nothing to do": in the forward pass 87 %
  did. That share is where the money goes.
- **Convert to quota.** The plan quota is not metered in dollars. State the projection as % of a week using the
  last measured conversion (2026-10: one week ≥ $430 notional, likely $500–700), and mark it as an estimate until
  the pilot measures it.

## 2. Stage it: cheap model decides where the expensive model looks

Don't give every unit an expensive close look on a fixed schedule. Staging that worked on paper for fresh-eyes:
context once per checkpoint (market, groups) → a cheap scorer over many units at once (Sonnet on contact sheets of
20 thumbnails) → the expensive model only on the shortlist and on events (fills, stops). Mechanical work (fills,
stops, schedules) stays in code, never in a model call.

Other levers, in order of effect: fewer looks on idle units (longer default interval); smaller images (1568 px
instead of 2400 px, gated by a same-cut legibility check); a shorter system prompt.

## 3. Pilot, then size against the day

1. Pilot ~1–3 % of the projected calls covering every call type.
2. `sh dev/scripts/quota_status.sh` before and after. The seven-day delta ÷ notional dollars is the conversion.
3. Size the full run in % of the week. Compare with the day's allowance that `quota_status.sh` prints (it holds
   back a 15 % management reserve). Split across days when it exceeds one day.

## 4. Guards in the driver (all mandatory)

- **Quota guard:** `sh dev/scripts/quota_status.sh --guard 0.85 --no-log` (or lower) before each unit or every
  ~25 calls. Exit 3 → stop cleanly, state kept.
- **Stop on a usage-limit reply, never wait it out.** A retry loop with pauses holds the quota hostage and blocks
  every other session. Restart in a later session, after reading the allowance.
- **Restartable per unit** (a `done` marker), so stopping costs nothing.
- **A dollar cap** as a backstop only.
- **At most 2 parallel jobs** unless the pilot shows the day's allowance covers more.

## 5. Report

After the run, record calls, notional $, quota % used and $/call per call type in the results README, so the next
projection starts from measured numbers.
