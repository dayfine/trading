# G3 first arming — reservation removes the failure mode; the isolated cost is breadth (2026-08-21)

`reserve_cash_for_resting_tickets` (G3) had been built and tested since
2026-08-16 but **armed in zero specs** — the only arc mechanism never
exercised. This is its first arming anywhere: `inspect-6mo-g3` =
the four-override arc bundle + `initial_stop_buffer 1.0` + G3, on the 6-month
inspection window (2019H1, top-3000, non-binding metrics per the inspection
harness convention).

> **Comparator note (QC rework):** the g3 spec differs from the `arc` arm by
> **two** overrides — the stop-buffer fix moved alongside G3 — so `arc` is not
> the isolating control. The control is `inspect-6mo-bookstop` (arc +
> `initial_stop_buffer 1.0` alone), already committed in the same results
> directory. An earlier revision of this note credited the whole arc→g3 delta
> to G3; that framing was wrong.

By `symbol|entry_date` join (no duplicate keys in any file): g3's 11 trades
are an exact subset of bookstop's 39; bookstop is **not** a subset of arc —
arc ∩ bookstop = 37, arc-only 22, bookstop-only 2 (AKAM 2019-06-07,
WWW 2019-04-24, both with wide structural stops ≈ 0.11 — the stop-buffer
override *substitutes* trades as well as filtering them). An earlier revision
claimed 11 ⊂ 39 ⊂ 59; the outer inclusion is false:

| arm | delta vs previous row | trades | return | stop / eject exits |
|---|---|---:|---:|---|
| arc | — | 59 | −4.17% | 24 / 35 |
| bookstop | + `initial_stop_buffer 1.0` | 39 | +4.83% | 4 / 35 |
| **g3** | **+ G3 reservation** | **11** | **+2.66%** | 3 / 8 |

## The two liveness answers (G3 isolated = g3 vs bookstop)

1. **The mechanism works as designed:** zero `Insufficient cash` rejections
   with G3 armed. *Provenance:* the rejection counts (g3: 0, bookstop/arc
   window: 6) are **log-sourced** (`grep -c 'Insufficient cash'` on the run
   logs), not present in any committed artifact — unlike every other number in
   this note, which reproduces from the committed `results/` files.
2. **The isolated cost is breadth, and it is large:** trades 39 → **11** and
   return +4.83% → **+2.66%** (−2.17pp) from arming G3 alone. Reservation
   locks each resting ticket's designed cost at placement, so concurrent
   tickets collapse. *Config arithmetic, not a measurement:* at the configured
   `max_position_pct_long 0.14` against the 70% pool, 0.70 / 0.14 = 5 tickets
   would exhaust it. *The measured analogue* (isolated, against the right
   control): max concurrent positions is arc 8 / **bookstop 5** / g3 **2**.
   The control already sits at the nominal 0.70/0.14 = 5 ceiling, and arming
   G3 more than halves it — the reservation's own footprint, not the
   stop-buffer's.

No performance claim from any of these numbers (single 6-month window,
inspection purpose). Which tickets survive the reservation queue is a
selection effect — exactly what the three-way grid (A1-4) exists to measure
against G2a (retry, #2463) and G2b (resize, #2468), which handle the same
failure without locking the pool.

Artifacts: `dev/experiments/inspect-6mo-2026-08-21/results/g3-{actual.sexp,trades.csv}`
(controls: `bookstop-*`, `arc-*` in the same directory).
Spec: `trading/test_data/backtest_scenarios/staging-arc-2026-08/inspect/inspect-6mo-g3.sexp`.

A1-4 note: the grid needs a build containing G2a (#2463) + G2b (#2468) — i.e.
a fresh pinned worktree at current main; the `sweep-arc26` worktree predates
both.
