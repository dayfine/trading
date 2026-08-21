# G3 first arming — reservation removes the failure mode; the cost is breadth (2026-08-21)

`reserve_cash_for_resting_tickets` (G3) had been built and tested since
2026-08-16 but **armed in zero specs** — the only arc mechanism never
exercised. This is its first arming anywhere: `inspect-6mo-g3` =
the four-override arc bundle + `initial_stop_buffer 1.0` + G3, on the 6-month
inspection window (2019H1, top-3000, non-binding metrics per the inspection
harness convention).

| | arc (no G3) | g3 |
|---|---:|---:|
| `Insufficient cash` rejections | 6 | **0** |
| trades | 59 | **11** |
| return | −4.17% | +2.66% |
| mean hold | 4.4d | 3.5d |
| exits | 24 stop / 35 eject | 3 stop / 8 eject |

## The two liveness answers

1. **The mechanism works as designed:** zero portfolio rejections — the plan's
   claim that G3 "removes the failure rather than handling it" is confirmed
   live. Placement-time reservation means a triggered ticket always has its
   cash.
2. **The idle-cash cost is not a rounding error — it is the dominant effect.**
   Trade count collapses 59 → 11: every resting ticket locks its designed cost
   (~14% of NAV each), so ~5 concurrent reservations exhaust the 70%
   deployable pool and the screener's subsequent tickets never place. The plan
   predicted "reserved cash is idle cash"; the observed form is **fewer
   concurrent tickets**, not idle drag on the same tickets.

No performance claim from either number (single 6-month window, inspection
purpose). The return sign difference is dominated by which 11-of-59 tickets
survived — a selection effect of the reservation queue, exactly what the
three-way grid (A1-4) exists to measure properly against G2a (retry) and G2b
(resize), which handle the same failure without locking the pool.

Artifacts: `dev/experiments/inspect-6mo-2026-08-21/results/g3-{actual.sexp,trades.csv}`.
Spec: `trading/test_data/backtest_scenarios/staging-arc-2026-08/inspect/inspect-6mo-g3.sexp`.

A1-4 note: the grid needs a build containing G2a (#2463) + G2b (#2468) — i.e.
a fresh pinned worktree at current main; the `sweep-arc26` worktree predates
both.
