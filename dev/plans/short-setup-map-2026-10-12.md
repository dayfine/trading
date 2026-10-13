# Short setup map — pre-registration (2026-10-12)

**Status: DRAFT, awaiting the user's confirmation of the design and thresholds.** Direction chosen by the user on
2026-10-12 ("map setups first"), after: *"I think it's still worth pursuing. We are just not doing it very well."*

## Why

Shorts Phase B round 1 (#3237) and the index-hedge screen (#3265) failed. Re-reading them against the book
(`weinstein-book-reference.md` §6) shows that our short book is not the book's short book.

1. **Stop room.** The long-designed structural-stop rule skips a short unless a prior rally high sits within 15 %.
   That removed 2,024 of 2,184 top-ranked candidates (`shorts-phase-b-2026-10-09/results/analysis/score-threshold/`).
   All 219 shorts we took had a `Support_floor` stop. The book's stop is "above the prior rally peak … give it plenty
   of room", which for a big Stage-3 top is often wider than 15 %.
2. **Entry.** We only enter on the breakdown. The book: about half of breakdowns pull back to the breakdown level;
   investors short half on the breakdown and half on the pullback. Our biggest loss bucket was failed breakdowns:
   103 shorts stopped at about −10 %.
3. **Market.** We used the macro composite. The book's rule is the index in Stage 4 with the long-term indicators
   negative, which is early in a decline. Head-and-shoulders tops ("the bigger the top, the bigger the drop") are not
   detected at all.
4. **Selection.** The short score is a mirror of the long score and does not rank: 1,491 candidates were a coin flip
   against SPY at every threshold.

So we have not yet measured the book's short setup. This screen maps it before anything is built.

## Population (one row per breakdown event)

- **Universe:** the PIT top-3000 v12 schedule (`trading/test_data/backtest_scenarios/pit-v12/composition/`). An event
  counts only if the symbol is in that year's list. Broad, never sp500 (`universe-discipline.md`).
- **Window:** breakdowns 2000-01-07 → 2025-12-26, so every event has 120 forward bars before 2026-06-25.
- **Stages:** the weekly stage replay of each symbol by `stage_chart.exe`, with the default classifier on adjusted
  closes. This is the replay the review pack and the index-hedge screen use.
- **Event:** a week whose stage is `Stage4` when the prior week's was `Stage3`. That is the Stage 3→4 transition, a
  breakdown below the MA after a top.
- **Price floor:** breakdown-week close ≥ $5 (primary). Sensitivity: ≥ $17, the old `short_min_price`.
- **De-duplication:** one event per symbol per 26 weeks. A re-break within 26 weeks of an event is dropped.

## Entries (both measured on every event)

- **E1, breakdown:** short at the close of the first bar after the breakdown week. This is what the strategy did.
- **E2, pullback:** short at the first close, within 8 weeks after the breakdown week, at or above the breakdown level.
  The breakdown level is the lowest weekly close of the 10 weeks before the breakdown week, i.e. the broken support.
  No such close means no E2 entry. The share of events that pull back is itself reported; the book says about 50 %.

## Outcomes

- **O1, no stop:** the side-signed short return at +20, +60 and +120 bars from entry, minus an SPY short over the same
  dates. Total return (adjusted closes) for both, so the stock short pays dividends, as SPY's does.
- **O2, book stop:** a buy-stop 1 % above the prior rally peak, the highest weekly high of the Stage-3 range before the
  breakdown. The position is held to the stop or to +120 bars, whichever comes first. Gaps fill at the open. The stop
  is not trailed; that is a later question. O2 is reported on the same two entries.

## Splits (the book's checklist, each measured at the breakdown week)

| item | levels |
|---|---|
| market phase (SPY's own weekly stage, as in the index-hedge screen) | SPY Stage 4 ≤ 8 weeks old (early) / Stage 4 > 8 weeks / Stage 3 / Stage 1 or 2 |
| prior advance (rise from the 2-year low to the Stage-3 high) | < 30 % / 30–100 % / ≥ 100 % |
| top width (weeks in Stage 3 before the break) | ≤ 8 / 9–20 / > 20 |
| head-and-shoulders proxy | in the Stage-3 range, three weekly swing highs (±2 weeks), the middle the highest by ≥ 3 %, shoulders within 5 % of each other / not |
| RS (Mansfield, 52-week, vs SPY) | negative and falling / positive but falling ("topped") / rising (the book: never short) |
| group (sector from `data/sectors.csv`) | the sector's median 26-week return among that year's list members, minus SPY's: < 0 (weak) / ≥ 0 |
| stop room (entry to the O2 stop) | ≤ 15 % / 15–30 % / > 30 % |

## Decision rule (fixed before any number is seen)

**Two primary cells,** each the full book checklist:
- market early Stage 4 (or SPY in Stage 3);
- prior advance ≥ 30 %;
- RS not rising;
- group weak;
- any stop room.

**P1** is the checklist with E1, and **P2** the checklist with E2.

A primary cell **shows an edge** when all six of these hold on outcome O2:

1. n ≥ 100 events;
2. mean excess vs the SPY short ≥ +2 %;
3. median excess > 0;
4. beat rate ≥ 55 %;
5. both halves agree in sign: 2000–2012 and 2013–2025;
6. O1 at +60 bars agrees in sign.

If P1 or P2 shows an edge, the next step is to **build** that setup behind default-off flags and run the real 26-year
paired test. The flags would be the short stop room, the pullback entry, and the market phase and checklist gate.

**The other cells are descriptive.** A non-primary cell can only name a candidate for a separate pre-registration.
It never triggers a build, because there are dozens of splits (`mechanism-validation-rigor.md`, multiple
comparisons). Such a cell has to meet all six criteria with a beat rate ≥ 58 %.

If neither primary cell shows an edge, this is a **no-build decision** for the book's short setup as measured here.
The remaining untested item is short interest, which needs data we do not have. The flags stay default-off axes.

## Reported regardless of verdict

- the event count by year, and how much of the population falls in the old 15 % stop-room slice;
- the E2 pullback share and the time to pull back;
- the distribution of each primary cell (n, mean, median, p10–p90) and the bear-period subtotals for 2000–02, 2007–09
  and 2022;
- why the result came out as it did: selection, entry timing, stop room or market phase;
- twenty traced events, ten winners and ten losers from P1 and P2.

## What it is not

It is not a strategy backtest. There is no capital, no sizing and no portfolio interaction. Those come only if a
primary cell escalates.

## Cost

- **Container:** the `stage_chart` replay of about 9,200 symbols, 4 in parallel, about 1–2 h. No other container use.
- **Host:** the event extraction and outcomes, offline awk.
- **Reading:** results-analyst, then qc-results. This is a results-only PR.
