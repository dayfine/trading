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

### The rest distribution — and where the P&L actually is

1,070d is **not** the maximum; it was only the longest among the four 2025
symbols. Across all 942 joined trades in cell 13:

| | days |
|---|---|
| median | **12** |
| p75 | 48 |
| p90 | 160 |
| p95 | 427 |
| p99 | **1,648** (4.5 yr) |
| max | **7,941** (21.7 yr) |

The extreme verified end-to-end: `FUL-wein-64` decided **2000-02-04**, filled
**2021-11-01**, realized −1,138. A resting order that survived 21.7 years is the
literal-GTC defect in its purest form.

Most tickets fill promptly (median 12d); 31.6% pass 4 weeks, 15.5% pass 13 weeks,
5.8% pass a year. So TTL only ever touches the tail — but *which part* of the
tail decides everything:

| rest bucket | n | share | realized pnl | pnl/trade |
|---|---:|---:|---:|---:|
| ≤7d | 396 | 42.0% | 2,225,496 | 5,620 |
| 8-28d | 248 | 26.3% | 423,842 | 1,709 |
| **29-91d** | 152 | 16.1% | **1,273,096** | **8,376** |
| 92-182d | 59 | 6.3% | 404,455 | 6,855 |
| 183-365d | 32 | 3.4% | −10,173 | −318 |
| 1-3yr | 35 | 3.7% | 379,985 | 10,857 |
| **>3yr** | 20 | 2.1% | **−154,006** | **−7,700** |

**ttl4's 28-day cut lands exactly on the lower edge of the most profitable
bucket.** The 29-91d band is 16% of trades and 28% of all realized P&L at the
best per-trade rate of any bulk bucket — and ttl4 cancels all of it. That is the
mechanical reason ttl4 loses money, and it means the tested axis
({0, 4, 8} weeks) never reached the useful range.

Meanwhile the >3yr bucket is actively destructive (−7,700/trade), so the answer
is not "no TTL" either. A cut around **26 weeks** retains ~95% of realized P&L
with 91% of trades while removing the 183d+ tail including the >3yr losses.

⚠ Static decomposition: it assumes cancelling a bucket leaves the others
unchanged, whereas freed capital would redeploy. Indicative of where to set the
knob, not a prediction of the resulting return.

### Per-symbol: the fast fills lost, the slow fill won

Every ticket for the three 2025 drivers, in cell 13 (TTL absent):

| symbol | rest | realized |
|---|---|---|
| AMG | 181d | +229,597 |
| CHRW | 11d / 3d / **1,070d** | −9,363 / −44,224 / **+166,717** |
| JNJ | 5d / **728d** | −21,903 / **+209,844** |

For CHRW and JNJ the promptly-filled tickets lost money and the long-resting one
carried the name.

### Three-arm YoY (realized pnl)

| year | 13 (ttl0) | 15 (ttl4) | record |
|---|---:|---:|---:|
| 2003 | 551,148 | 570,301 | 1,472,537 |
| 2008 | −118,454 | −56,234 | −289,878 |
| 2014 | 627,899 | 459,285 | 1,343,850 |
| 2015 | 1,382 | 69,801 | **−845,480** |
| 2016 | 1,384,858 | 981,503 | 515,016 |
| 2017 | 108,535 | 170,954 | 1,874,003 |
| 2018 | −600,152 | −477,696 | −645,877 |
| 2020 | 1,054,523 | 1,227,051 | 5,365,533 |
| 2022 | −98,199 | **−602,727** | 317,601 |
| 2023 | 1,133,577 | 1,333,523 | 3,442,470 |
| **2025** | −172,214 | **−827,925** | **+57,080,155** |
| 2026 | −401,293 | −304,441 | −4,732,975 |
| **total** | **4,486,567** | **3,233,396** | **66,820,669** |

Record's 2025 is AXTI in a single line. But note it also leads in the other big
years (2020 5.37M vs 1.05M, 2017 1.87M vs 0.11M, 2023 3.44M vs 1.13M) — that is
**position sizing / concentration**, not entry timing, and it is the ex-AXTI 2.4×.
Cells 13 and 15 track each other closely in every year **except 2022 and 2025**,
where the entire TTL gap lives.

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

## Three follow-up questions, answered with data

### Q1 — is an arbitrary upper bound (e.g. 183d) justified?

**A bound is justified, but at ~3 years, not 26 weeks — and for absurdity, not
return.** The >3yr bucket is not one outlier: 20 trades, **7 winners (+87,354)
vs 13 losers (−241,360)**, largest win only +21,987. It is a systematically
poor, **upside-free** population — no fat tail at all, which is exactly what
distinguishes it.

Correcting an earlier over-read in this note: 183-365d is **essentially
break-even** (11 winners +318,283 vs 21 losers −328,456), not "bad", and the
**1-3yr bucket is the best per-trade of any** (+10,857). A 26-week bound cuts
that band. So the defensible bound is long — around 3 years — and its
justification is removing 21-year resting orders, not improving return.

### Q2 — wouldn't a later screen achieve the same as the later fill?

**No, empirically.** Neither arm made a **2025 entry decision** for CHRW, JNJ or
AMG:

| symbol | 13 (ttl0) decisions | 15 (ttl4) decisions |
|---|---|---|
| CHRW | 2012-10-26, 2019-10-25, 2022-09-09 | 2012-10-26, 2021-11-05, 2022-09-09, 2023-02-24, 2023-05-19, 2024-12-20 |
| JNJ | 2019-11-29, 2023-08-18 | 2022-12-23, 2024-08-09 |
| AMG | 2024-12-27 | 2024-12-27 |

The screener never re-selected these names at their 2025 breakout. Cell 13's
2025 fills came entirely from 2022/2023/2024 tickets.

And ttl4 was not short of opportunities — it placed **35% more tickets**
(1,663 vs 1,235; 107 vs 71 in 2025), because each cancellation frees a slot. It
spent those slots on *different* names, and the reallocation was worse: symbols
only-15 returned +51,745 against only-13's +913,534.

So a resting ticket is not merely an entry mechanism — it is a **commitment that
holds a capital slot for one name at one price across time**. Cancelling
reallocates that slot to whatever ranks best this week. Here, commitment beat
reallocation: **35% more tickets, 28% less money.**

### Q3 — what is the record arm doing right in 2020?

Not catching the knife. Record's **March 2020** entries lost **−103,962** in
aggregate, most stopped out within days — it caught falling knives and was cut.

Its 2020 comes from four post-crash *recovery* entries:

| | entry | fill | pnl | stop_dist |
|---|---|---|---|---|
| BFX | 2020-04-20 | $5.00 | +1,265,910 | 0.221 |
| LOGI | 2020-05-04 | $48.52 | +1,114,624 | 0.068 |
| COHU | 2020-09-28 | $17.05 | +1,102,958 | **0.440** |
| BANB | 2020-04-06 | $196.20 | +830,586 | 0.050 |

Cell 13 **never screened BFX, COHU or BANB at all** — zero decisions in 26 years.
So this is not an entry-price or timing effect; the names never became
candidates.

The dominant cause is the same one that excludes AXTI, generalized:

> **60.3% of record's trades (676/1121) have `stop_initial_distance_pct` > 15% —
> the faithful arms' `max_stop_distance_pct` gate — and those trades carry
> 60,402,579 of its 66,820,670 realized P&L: 90.4%.**

Record's gate-passing trades earn **6,418,091**, against cell 13's 4,486,567 —
the same order of magnitude. **Record's entire edge is the population the gate
excludes.**

That is not "doing something right" in a book sense: a stop 22-57% below entry
is not a Weinstein stop, which sits just below the base. It is a different risk
rule that occasionally returns 56×.

⚠ Two of the four 2020 monsters (BANB 0.050, LOGI 0.068) **would** pass the 15%
gate and cell 13 still never screened them. So there is a second, smaller
selection effect beyond the stop gate — worth its own dissection.

## The two concrete next moves

1. **Re-test the TTL axis at values that matter.** {0, 4, 8} weeks was the wrong
   range — 4 weeks cuts the best bucket's lower edge and 8 weeks barely clears
   it. The evidence points at **{13, 26, 52} weeks**, where 26 keeps ~95% of
   realized P&L and drops the destructive >3yr tail. This is cheap: the knob
   already exists and is a `Variant_matrix` axis.
2. **Split the knob.** `entry_order_ttl_weeks` currently arms the re-screen
   cancel *and* the clock together (`weinstein_strategy_screening.ml:299`
   returns `[]` at 0 without consulting the re-screen predicate). Separating
   them allows the shape the book actually supports — cancel when the setup
   breaks down (§4.7, §7), no arbitrary timer — which on this evidence is the
   only variant that removes 21-year resting orders without also cancelling the
   29-91d band that pays for the strategy.

Note these compose: a long clock (26wk) as a backstop against the >3yr absurdity,
plus re-screen cancel as the real mechanism, is a coherent and book-faithful
design that no cell in v4 tested.
