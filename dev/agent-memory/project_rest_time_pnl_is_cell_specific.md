---
name: project-rest-time-pnl-is-cell-specific
description: "The ticket rest-time P&L table does not transfer between ladder cells — the 5-13wk profit band does, but the >3yr bucket flips sign, which refutes defect E's premise for bounding the TTL clock."
metadata: 
  node_type: memory
  type: project
  originSessionId: f3803253-a181-4a9d-88bc-d6fadb39647f
  modified: 2026-08-18T04:47:10.050Z
---

Ticket **rest time** (`ticket_age_weeks_at_fill`) is downstream of the entry
anchor basis, so a P&L-by-rest-time table measured on one ladder cell **does not
transfer** to another. Established 2026-08-17 by re-deriving the table on the
base a re-test actually runs.

Cell 00 (`Ma_cross` + `Window_extreme`, 1,145 filled tickets), joined
`position_id` → `ticket_age_weeks_at_fill` → `pnl_dollars`:

| bucket | n | realized pnl | pnl/trade |
|---|---:|---:|---:|
| wk 0-1 | 696 | 679,738 | 977 |
| wk 2-4 | 167 | −201,330 | −1,206 |
| **wk 5-13** | 136 | **1,596,587** | **11,740** |
| wk 14-26 | 58 | 3,254 | 56 |
| wk 27-52 | 29 | 11,622 | 401 |
| wk 53-156 | 35 | **−220,314** | −6,295 |
| **wk >156** | 25 | **+304,101** | **+12,164** |

**Transfers:** the **5-13 week band is the profit band** — here 1.60M on 136
trades, and on cell 13 the same band was 16.1% of trades and 28% of P&L. A
4-week clock cuts it entirely on both. `{13, 26, 52}` is the right axis.

**Does NOT transfer:** the **>3yr bucket flips sign**. Cell 13: 20 trades, 13
losers, −154,006, "upside-free". Cell 00: 25 trades, **+304,101**, the
second-highest per-trade bucket in the run. And the loss-maker on cell 00 is the
**1-3yr** bucket, not the >3yr one.

**Consequence — defect E's premise is cell-specific.** "Unbounded is genuinely
wrong at the extreme, the >3yr population is systematically poor and
upside-free" was the whole justification for bounding
`entry_order_max_rest_weeks` at ~156 weeks. On cell 00 **a 156-week bound cuts a
profitable population.** Shipping the field defaulting to `0` (#2349) was right
for a better reason than R1 discipline. See [[project-ttl-is-a-tail-lever]].

**And the clock cannot be tested by top-line return at this scale.** Gross
attribution of what each clock removes: 13w −98,663 (~9.9pp), 26w −101,917
(~10.2pp), 52w −83,787 (~8.4pp), 156w −304,101 (~30.4pp) — against a **132.5pp
null**. Every value is 4-13× below the noise floor, and gross attribution is an
upper bound on the magnitude. The metric that would resolve it is **per-bucket
realized P&L on the arm's own trades**, not `total_return_pct`.

**How to apply.** Before spending a multi-hour run on an axis, convert the
motivating table into a predicted effect size and compare it to the null
([[feedback-run-the-null-control-first]]). If it loses, either change the metric
or don't run. Re-derive any borrowed distribution on the base you are actually
running — the join is minutes of work and it changed a conclusion here.
