# Short-supply screen — FINDINGS (2026-06-21)

**Verdict: NO-BUILD decision — the short sleeve is supply-gated, not price-floor-
gated; loosening the floor does not grow the book, and name-level Stage-4 shorts
are net-neutral-to-negative and an unreliable bear hedge. The bear-defense lever
is the regime/index overlay (barbell floor), not name-level shorts. Short line
CLOSED.** (Calibrated per `mechanism-validation-rigor.md`: a read-only screen, so
a no-build *decision*, not a mechanism "rejection".)

## What was tested

The 06-20 short re-decomposition found only 37 shorts over 28y and hypothesized
the book was **supply-gated** (Stage-4 signal count + `short_min_price 17`). The
cheap test: loosen `short_min_price 17 → 5` (admit cheaper Stage-4 shorts), same
top-3000 PIT-1998 long-short deep run (1998-2026, margin on), and ask: does the
book (a) grow, (b) stay per-trade-favorable, (c) finally fire reliably in 2008?

Spec: `cell-e-top3000-1998-longshort-sm5.sexp` (warehouse
`/tmp/snap_top3000_1998_ls`). Run summary: total return 1185%, 1298 trades,
Sharpe 0.55, MaxDD 39.9%.

## Result — loosening the floor changed almost nothing

**Short count: 36 (loosened sm5) vs 37 (baseline sm17).** Dropping the price
floor from \$17 to \$5 admitted **~zero** net new shorts → the binding constraint
is the **Stage-4 signal supply**, not the price filter. Hypothesis (a) FALSIFIED.

### The 36 shorts, decomposed

Overall: total P&L **−\$50,594** over 28y · win-rate **36.1%** (13/36) · avg win
**+\$56,360** · avg loss **−\$34,055** (favorable per-trade asymmetry, but the low
hit-rate makes the sleeve net-negative).

By exit-year (n · total P&L · wins):

| year | n | P&L | wins |
|---|---|---|---|
| 1998 | 7 | −\$11.7k | 2/7 |
| 1999 | 3 | +\$62.8k | 3/3 |
| 2000 | 4 | −\$37.7k | 2/4 |
| 2004 | 2 | −\$11.1k | 1/2 |
| 2007 | 1 | −\$40.9k | 0/1 |
| **2008** | **7** | **+\$26.7k** | **2/7** |
| 2009 | 3 | +\$206.1k | 1/3 |
| 2011 | 2 | −\$78.5k | 0/2 |
| 2012 | 1 | +\$45.2k | 1/1 |
| 2015 | 1 | −\$59.7k | 0/1 |
| 2016 | 3 | −\$57.5k | 1/3 |
| 2019 | 2 | −\$94.3k | 0/2 |

## Interpretation (the transferable why)

1. **Supply is the constraint, not price.** 36 ≈ 37 — the price floor was never
   binding. A bigger short book is not reachable by loosening admission; it would
   need *more Stage-4 signals*, which the universe simply doesn't produce at this
   cadence (~1.3 shorts/yr). Corrects nothing in the standing belief; confirms
   `project_short_funnel` (supply-gated).
2. **The sleeve is net-negative and lottery-shaped.** −\$50k over 28y on a 36%
   hit-rate; the few green years (1999, 2009 +\$206k, 2012) are carried by single
   tail winners, exactly mirroring the long book's fat-tail structure
   (`edge_is_the_fat_tail`) — but on the short side the tail is too thin and rare
   to overcome the steady losing majority.
3. **2008 is NOT a reliable hedge.** Shorts *did* fire in 2008 (7 of them, net
   +\$27k) — but only 2/7 won; the net came from 1-2 names, not breadth. A hedge
   you can only count on 2-out-of-7 times, carried by a lottery winner, is not a
   dependable bear defense. The yellow flag going in (name-level Stage-4 short
   *timing* is the real failure) is confirmed: loosening supply does not fix
   timing.

## Consequence

Name-level shorts are closed as a bear-hedge lever. The session's parallel result
makes the alternative concrete: the **barbell floor (SPY-timing index overlay)**
*is* the dependable bear defense — it sat in cash through 2000-02 and 2008 and
halved drawdown reliably, with none of the short sleeve's lottery dependence. Route
all bear-defense effort to the regime/index overlay, not name-level shorts.

Updates standing belief `project_short_funnel_crowded_out` (supply-gated, price
floor non-binding) and bookends the bear-defense question in favor of the barbell.
