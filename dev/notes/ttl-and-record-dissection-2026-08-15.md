# Trade dissection — what TTL actually cancels, and what the record arm actually is

Two questions, one procedure (`trade-dissection` skill), same 26y window
(2000-01-01..2026-06-26, top-3000 PIT-2000):

1. **Cell 13 (rt-nearfloor, ttl0) vs cell 15 (rt-ttl4-nearfloor)** — identical
   configs except `entry_order_ttl_weeks` 0 vs 4.
2. **Both vs the record-nextopen arm** (+7,321%).

All three arms have `position_id` populated at 100%, so decision-date → fill-date
joins are exact rather than date-proximity guesses (this is what #2317/#2323
bought; the same dissection was impossible a week ago).

## Part 1 — TTL cancels the long-resting tickets, and they were the profitable ones

Realized P&L: cell 13 = 4,486,566; cell 15 = 3,233,396. Gap **1,253,178**.

Decomposed by symbol membership:

| | symbols | realized pnl |
|---|---|---|
| traded only by 13 (ttl0) | 138 | **+913,534** |
| traded only by 15 (ttl4) | 117 | +51,745 |
| shared | 458 | 13: 3,573,036 vs 15: 3,181,652 (Δ +391,384) |

**73% of the gap is symbols cell 15 never touched at all.** The substitution was
poor: 15 gave up 914k of trades and its exclusive alternatives returned only 52k.

### The causal link, measured

Joining each trade's `position_id` to its audit decision date gives exact ticket
rest:

| group (cell 13) | trades | mean rest | >28d (past ttl4's clock) | >365d | realized pnl |
|---|---|---|---|---|---|
| only-13 symbols | 160 | **163d** | **65.6%** | 8.1% | +913,998 |
| shared symbols | 782 | 96d | 24.7% | 5.4% | +3,628,697 |
| all | 942 | 108d | 31.6% | — | +4,542,695 |

Two-thirds of the exclusive trades rested past the 4-week clock — so TTL cancelled
them, which is exactly why cell 15 never took them. That is the mechanism, not an
association.

And they were **better per trade**: +5,712 (only-13) vs +4,640 (shared).

### YoY first, then the max-delta year (the skill's step 1)

Per-year Δpnl from `faithfulness_report_cli -a <13> -b <15>`:

| year | ttl0(13) | ttl4(15) | Δpnl |
|---|---:|---:|---:|
| **2025** | −172,214 | −827,925 | **+655,711** |
| 2022 | −98,199 | −602,727 | **+504,528** |
| 2016 | +1,384,858 | +981,503 | +403,355 |
| 2012 | +290,652 | +68,643 | +222,009 |
| 2023 | +1,133,577 | +1,333,523 | −199,946 |
| 2010 | +248,827 | +433,862 | −185,035 |

Note the shape of the two biggest: **both arms lost money in 2025 and 2022 — ttl4
lost 4.8× and 6.1× more.** TTL's damage concentrates in bad years, not good ones.

Drilling into **2025**, the max-delta year, four symbols carry it, all traded by
13 with no 2025 entry in 15: AMG +229,597, JNJ +209,844, CHRW +166,717,
FLS +80,362.

### Trade level — the fills are at E, and the rest is measured in years

| ticket | decision | fill date | rest | E at decision | actual fill | outcome |
|---|---|---|---|---|---|---|
| CHRW-wein-3960 | 2022-09-09 | 2025-08-14 | **1,070d** | 121.84 | 121.84 | +166,717 |
| JNJ-wein-4150 | 2023-08-18 | 2025-08-15 | **728d** | 176.24 | 176.28 | +209,844 |
| AMG-wein-4553 | 2024-12-27 | 2025-06-26 | 181d | 191.32 | 191.52 | +229,597 |
| FLS-wein-4682 | 2025-08-01 | 2025-10-29 | 89d | 59.55 | 59.70 | +80,362 |

All Stage2, MA rising at decision. **Every fill is at E to within cents** — the
resting StopLimit doing exactly what it is designed to do: sit at the range-top
breakout level until price finally reaches it.

### Why the re-screen does NOT compensate — the structural result

Cancelling releases the `Entry_freeze` pin so the symbol may re-qualify at a
fresh E. It does re-qualify. It still never fills:

- **AMG** — cell 15 made the *same* 2024-12-27 decision, cancelled it at 4 weeks,
  and AMG never re-qualified. 0 trades.
- **CHRW** — both arms decided 2022-09-09. Cell 15 cancelled, then re-screened
  CHRW on 2023-02-24, 2023-05-19 and 2024-12-20. **None of those fresh tickets
  filled either** — each was cancelled 4 weeks later in turn.
- **JNJ** — cell 15 *did* enter, earlier and lower (166.67), and was stopped out
  in 10 days for −8,688. Cell 13 filled later at 176.28 and rode to 229.06.

> **TTL's clock cancels a ticket every 4 weeks, and each re-screen places a fresh
> ticket cancelled 4 weeks later. For a stock whose range-top breakout takes
> months or years to resolve, no ticket ever survives long enough to fill — no
> matter how many times the symbol re-qualifies.**

The pin-release machinery works as designed and still cannot compensate, because
the clock resets faster than the setup resolves.

### The uncomfortable implication

**The least book-faithful entries are the most profitable ones.** A ticket that
rests 163 days and finally fills is catching a breakout through a long-established
level — a bigger, more decisive move. This is
[[project_edge_is_the_fat_tail]] again, from a new angle: TTL is a
tail-touching lever, and every tail-touching lever this program has tested has
cost return.

⚠ On the **MTM** basis the 13-vs-15 gap is 60pp against a 132.5pp null — *not
distinguishable*. The decomposition above is realized-basis, where the null is
52pp and the gap (125pp) does clear. So the *direction* is well-evidenced by the
mechanism; the *magnitude* depends on which basis you price it at. Do not quote a
single number for "what TTL costs".

## Part 2 — the record arm is one trade

| arm | trades | realized | top-1 trade share |
|---|---|---|---|
| record-nextopen | 1121 | 66,820,700 | **84.2%** |
| 13-rt-nearfloor | 953 | 4,486,570 | 25.3% |

The record's top trade:

```
AXTI  entry 2025-06-30 @ $2.05  ->  exit 2026-05-30 @ $115.45
      qty 495,867   pnl +56,231,318   exit_trigger extension_stop
```

**A 56× move on a $2.05 microcap.** Cells 13 and 15 never traded AXTI at all.

Record **excluding AXTI**: 1,119 trades, realized **10,659,357** — so the
comparison is:

| | with AXTI | ex-AXTI |
|---|---|---|
| record | 66.8M | 10.7M |
| cell 13 | 4.5M | 4.5M |
| ratio | **14.9×** | **2.4×** |

The headline "+7,321% vs +568%" is 84% one position. Ex-AXTI the record arm is
still ahead — 2.4× on realized — but that is a different claim, and a tractable
one, rather than a 15× chasm.

This re-derives [[project_faithful_ticket_structural_exclusion]] by an independent
route: the faithful arms exclude AXTI via the 15% `max_stop_distance_pct` gate,
and **the book itself passes on it** (§4.3). The exclusion is correct behaviour,
not a defect — so "close the gap to record" is largely "take the one microcap
moonshot the process is designed to decline."

## What this rules in and out

- **Do not treat the record arm's headline as the target.** The tractable gap is
  the ex-AXTI 2.4×, not 14.9×. Any future work justified by "record does 7,321%"
  is chasing a single position.
- **TTL is a genuine faithfulness/return trade, not a free win.** Earlier framing
  of TTL as "free" was measured on the core mix (00 vs 03: −25pp, inside the
  null). In the *best-performing* mix the mechanism has a real cost, and this
  dissection shows why: it cancels precisely the long-rest tickets that carry the
  fat tail.
- **The decision is a preference, not an optimisation.** Cell 13 = more return,
  ~half its entries filling on stale signals. Cell 15 = stale-signal population
  eliminated, less return. There is no configuration in this run that gets both.
- **Next lever should be tail-preserving.** Per the standing law, the levers that
  work do not touch the fat tail. A TTL variant that cancels on *re-screen failure
  only* (base broken down / sector / macro flipped) without the clock backstop
  would be the tail-preserving version — and the config cannot currently express
  it, because one knob arms both (`weinstein_strategy_screening.ml:299`).

That last point is the actionable one: **splitting the re-screen cancel from the
clock is a config change worth making**, because it is the only shape that buys
faithfulness without taxing the tail.
