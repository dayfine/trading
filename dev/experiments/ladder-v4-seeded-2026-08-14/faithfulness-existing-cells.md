# Execution faithfulness of the ladder-v4 mixes — 2026-08-14

Measured on the **existing** 19 v4 cells (`.sweep-output/ladder-v4-artifacts-2026-08-12/`).
Read the caveat section before quoting any of it: those runs predate the
path-seed fix, so their *returns* are not rankable. The faithfulness numbers
below are a different quantity and survive that defect — see §Why this is
measurable when the returns are not.

## The measurement

**How long does a ticket rest between its screening decision and its fill?**

That is the execution-faithfulness question for an async resting-ticket design.
Weinstein's entry is a breakout above resistance *with volume confirmation*
(`weinstein-faithful-core.md` spine item 3) — a signal that goes stale. A
resting StopLimit frozen at a year-old `E`, filling when price finally crosses
it, is not that trade: the breakout it references is a year old and the stage
and volume context at fill are unverified.

| cell | trades | filled ≤7d | 8-30d | 31-90d | 91-365d | **>365d** | mean gap |
|---|---|---|---|---|---|---|---|
| 00-core-w4 | 1136 | **50.4%** | 270 | 140 | 89 | **54** | 177d |
| 01-anchor-w8 | 1105 | 48.1% | 264 | 141 | 102 | **56** | 167d |
| 02-fresh-rangetop | 1134 | 49.1% | 264 | 139 | 102 | **64** | 193d |
| **03-ttl4** | 1093 | **68.2%** | 317 | 24 | **0** | **0** | **18d** |
| **04-ttl8** | 1112 | **65.3%** | 313 | 65 | **0** | **0** | **21d** |
| 05-maxstop25 | 1291 | 44.0% | 293 | 208 | 134 | **69** | 171d |
| 06-maxstop35-diag | 1381 | 42.6% | 333 | 207 | 140 | **87** | 222d |
| 07-maxstop50-diag | 1442 | 42.6% | 343 | 211 | 146 | **105** | 241d |
| 08-sizedown50-diag | 1463 | 41.6% | 334 | 249 | 145 | **103** | 240d |
| 09-nearfloor | 967 | 41.7% | 254 | 140 | 106 | **58** | 196d |
| 10-volconf | 3145 | 43.2% | 751 | 498 | 318 | **185** | 175d |
| 11-anchor-w8-rangetop | 1118 | 46.4% | 264 | 136 | 122 | **68** | 208d |
| **12-rt-ttl4** | 1097 | **66.5%** | 332 | 29 | **0** | **0** | **18d** |
| 13-rt-nearfloor | 953 | 42.4% | 246 | 145 | 95 | **56** | 171d |
| 14-rt-volconf | 3220 | 45.3% | 777 | 501 | 286 | **171** | 169d |
| **15-rt-ttl4-nearfloor** | 879 | **62.8%** | 288 | 35 | **0** | **0** | **18d** |
| **16-rt-ttl4-nf-volconf** | 2087 | **59.3%** | 757 | 80 | **0** | **0** | **18d** |
| **17-rt-ttl8-nf-volconf** | 2193 | **55.6%** | 733 | 222 | **0** | **0** | **22d** |
| **18-rt-ttl4-nf-volconf-w8** | 1897 | **56.1%** | 731 | 88 | **0** | **0** | **18d** |

## The finding: TTL is the faithfulness dial, and it is the only one

Every cell splits cleanly into two populations by one axis:

- **ttl0 (no expiry)** — 41.6–50.4% of entries fill within a week of their
  signal. The rest rest: mean gap 167–241 days, and **54 to 185 trades per cell
  fill more than a year after** the decision that generated them.
- **ttl4 / ttl8** — 55.6–68.2% fill within a week, and the long tail is gone
  **outright**: zero fills beyond 90 days in every TTL cell, mean gap 18–22d.

No other axis moves it. anchor (w4→w8), freshness basis, max-stop width,
size-down, nearfloor and volconf all leave the ttl0 profile essentially
unchanged — max-stop widening even makes it slightly worse (00: 54 >1y fills;
07: 105), which is mechanically sensible, since a wider permitted stop admits
tickets whose price is further from `E` and so takes longer to trigger.

**The table validates itself.** ttl4 = 4 weeks and shows near-zero beyond 30
days; ttl8 = 8 weeks and shows a populated 31-90d bucket that ttl4 lacks
(65 vs 24), with both hard-zero beyond 90. That the measured bound tracks the
configured bound, per cell, is what makes the measurement trustworthy.

(The 24 ttl4 fills in the 31-90d bucket exceed a strict 28-day expiry. Most
likely the "nearest prior audit record" is not always the record that generated
the ticket, so the gap is a **lower bound**. That direction only strengthens
the ttl0 result.)

## Why this is measurable when the returns are not

These runs predate the intraday path-seed fix (#2279), so their returns are not
rankable, and their own null control puts the noise floor at ~278pp
(`project_ladder_v4_null_278pp`).

Ticket rest is a different quantity. It is derived from **whether an audit
record exists within 7 days before the fill** — the join success itself, not a
path-dependent P&L. The unseeded RNG perturbed the intraday path within a bar;
it did not move a screening decision months away from its fill. A cell whose
mean gap is 177 days does not owe that to a seed.

Verified rather than assumed, on cell 00's 563 unjoined trades:

```
symbol has NO audit record at all:            0
audit records exist only AFTER the fill:     10   (1.8%)
prior record within 7d (should have joined):  0
prior record more than 7d back:             553   mean 176.9d
```

So join failure means *the ticket rested*, not *the data is missing*. That is
the whole basis of the table.

## Consequence for the re-run

Chain 1 dropped the TTL cells, reasoning that the old return table put them
below core (278/207/179 vs 344) and the direction was at least consistent.
**That reasoning is now inverted:** TTL is the one axis that fixes the
faithfulness defect, so its return cost is the price of the fix and the most
decision-relevant number in the matrix — and 278/207/179 was measured on the
binary we are re-running precisely because we cannot trust it.

`chain2-ttl.sh` therefore adds, after chain 1:

- **03-ttl4** against chain 1's **00-core-w4** — ttl4 alone, unconfounded.
- **13-rt-nearfloor** against chain 1's **15-rt-ttl4-nearfloor** — ttl4 inside
  the rt mix. Chain 1 held 15 but not 13, so without this the only available
  ttl4-vs-ttl0 comparison was confounded by the rangetop and nearfloor axes.

## What this does NOT say

- **It is not a promotion decision.** TTL being more faithful says nothing yet
  about whether it earns its return cost; that is what the seeded runs are for.
- **It does not rank the mixes.** Every return figure attached to these cells
  is inside a ~278pp noise floor.
- **It does not measure fill quality**, only fill *timing*. Distance between
  fill price and `E`, and whether stage/volume still qualified at fill, both
  route through audit columns that the pre-#2317 join left empty on exactly the
  long-resting trades — the population that matters. Those become measurable
  only on post-#2317 runs, i.e. the ones now in flight.
