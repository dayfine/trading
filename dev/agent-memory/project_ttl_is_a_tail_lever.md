---
name: project-ttl-is-a-tail-lever
description: "TTL's clock cancels the long-resting tickets that carry the fat tail; one knob arms both the book-supported re-screen cancel and an arbitrary timer, and 4 weeks cuts the most profitable rest band."
metadata: 
  node_type: memory
  type: project
  originSessionId: f38d1024-5259-467e-95cf-9aa2c8fe4ddb
  modified: 2026-08-16T01:55:00.009Z
---

`entry_order_ttl_weeks` gates **two** mechanisms at once
(`weinstein_strategy_screening.ml:299` returns `[]` at 0 without even consulting
the re-screen predicate):

- **re-screen cancel** — cancel a resting ticket whose base broke down / sector
  or macro flipped. **Book-supported** (§4.7 cancel authority, §7 weekly review).
- **clock backstop** — cancel after N weeks. The book names no number.

You cannot have the faithful half without the arbitrary one. **Split them.**

**Default 0 is literal GTC with no cancel authority anywhere** — only half of
§4.7. `FUL-wein-64` was decided 2000-02-04 and filled **2021-11-01**: a resting
order that survived 21.7 years.

**Rest distribution (cell 13, 942 joined trades):** median 12d, p90 160d, p95
427d, p99 1,648d, max 7,941d. P&L by bucket:

| bucket | n | pnl | pnl/trade |
|---|---:|---:|---:|
| ≤7d | 396 | 2,225,496 | 5,620 |
| 8-28d | 248 | 423,842 | 1,709 |
| **29-91d** | 152 | **1,273,096** | **8,376** |
| 92-182d | 59 | 404,455 | 6,855 |
| 183-365d | 32 | −10,173 | −318 |
| 1-3yr | 35 | 379,985 | 10,857 |
| **>3yr** | 20 | **−154,006** | **−7,700** |

**ttl4's 28-day cut lands on the lower edge of the best bucket.** The tested axis
{0, 4, 8} weeks never reached the useful range — re-test at **{13, 26, 52}**.
>3yr is upside-free (7 winners / 13 losers, best +21,987), so a bound ~3yr is
justified **for absurdity, not return**. Do NOT cut at 26 weeks: 183-365d is
break-even and 1-3yr is the best per-trade bucket of all.

**Re-screening does not compensate for a short clock.** Each fresh ticket is
cancelled four weeks later in turn: CHRW was re-screened 4× after its cancel and
never filled, while ttl0's original 2022 ticket rested **1,070 days** and returned
+166,717. So a slow breakout can never be captured under a short clock, however
often the name re-qualifies.

**A resting ticket is a COMMITMENT holding a capital slot** for one name at one
price across time; cancelling reallocates it to whatever ranks best this week.
ttl4 placed **35% more tickets** (1,663 vs 1,235) and earned **28% less** —
commitment beat reallocation.

⚠ Basis matters: on MTM the 13-vs-15 gap is 60pp against a 132.5pp null (not
distinguishable); on realized it is 125pp against a 52pp null. Do not quote a
single number for "what TTL costs".

Related: [[project_edge_is_the_fat_tail]], [[project_entry_anchor_stale_e]],
[[project_ladder_v4_null_278pp]].
