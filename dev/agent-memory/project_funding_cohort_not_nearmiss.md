---
name: project-funding-cohort-not-nearmiss
description: "The funding-rejection cohort is not a near-miss population — median shortfall is 52% of required and 63% of rejections arrive in bursts against one cash balance, which reorders the three ticket-funding axes."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7b9bffd9-4afb-483a-9e22-50b6142eb14c
  modified: 2026-08-18T06:18:14.417Z
---

Measured 2026-08-18 (PR #2371, `dev/experiments/ticket-funding-cohort-2026-08-18/`)
over **n=3,530** portfolio-rejected fills from 20 ladder-v4 arms.

**Shortfall distribution** (as % of the ticket's required cost):

```
p1 = 0.8%   p10 = 10.1%   p25 = 26.3%   p50 = 52.3%
p75 = 76.9%  p90 = 92.0%   p99 = 99.0%    mean = 51.6%
<=1%: 1.4%   1-5%: 3.7%    (only 5.1% within 5% of fundable)
```

The `$397 / 0.3%` case that motivates
`dev/plans/ticket-funding-2026-08-16.md` is the **1st percentile**, not the
shape. Config-invariant: across the 16 arms with n ≥ 90 (stop width, TTL,
anchor, nearfloor, volconf all varying) mean shortfall stays 44.5–58.4% and the
≤5% near-miss share stays 2.0–7.7%.

**Scale:** required p50 ≈ \$245k against available p50 ≈ \$101k. Only 87 of
3,530 (2.5%) hit a genuinely empty book (< \$5k). The typical failure is *"the
book has 40% of this ticket"*.

**Burst structure:** grouping by the exact `Available:` figure, 771 bursts of
> 1 cover **2,207 of 3,530 rejections (63%)**; largest bursts are 18/14/12
tickets on one balance. So two thirds die in groups on a single tick — the
measured form of "selection at trigger is arrival order, not rank"
([[project-ticket-dies-on-cash-shortfall]]).

**Why:** the failure is **aggregate over-commitment** — the walk writes more
tickets than the book can fund — not per-ticket bad luck.

**How to apply.** Reorder the plan's three axes:

1. **G3 `reserve_cash_for_resting_tickets` first.** Only axis that removes the
   over-commitment instead of arbitrating it; it also cuts ticket count, the
   direction [[project-record-gap-is-concentration]] says the record arm runs.
2. **G2b `entry_fill_size_to_available` second**, with the **minimum-size
   fraction as the swept dial** — it *is* the mechanism, since the median fill
   would be 48% of designed size (p75 → 23%, p90 → 8%), i.e. systematic
   undersizing into breakouts, a direct [[project-edge-is-the-fat-tail]]
   exposure.
3. **G2a `entry_fill_reject_retries` last or not at all.** A retry needs half a
   position of new cash to appear, not a rounding error to clear; the cheap-
   rescue population is ~5% of the cohort.

Measures the rejected population only — not what the rejections cost. That
remains a counterfactual.
