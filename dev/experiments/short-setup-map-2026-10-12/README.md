# short-setup-map-2026-10-12: the book's short setup, mapped over every Stage 3 → 4 breakdown

**Pre-registration:** `dev/plans/short-setup-map-2026-10-12.md`, confirmed by the user on 2026-10-12 and merged at
`b666ad751` (#3274). Amendment 1 (the dividend splits) is `d65968e28` (#3278), committed at 20:54 PT. That is before
the event extraction: the per-symbol event files are dated 22:07–22:13 PT, and the 19:48 stage replay computes stages,
not outcomes. The plan on disk is byte-identical to `d65968e28`. The rule is applied as written. The choices the text
leaves open are listed under Method.

**Artifacts** (`results/`, commit `5aa014545`):
- `summary-floor5.txt` is the primary result and `summary-floor17.txt` the $17 sensitivity;
- `events/<year>.csv` holds the 45,599 events (one header per file; the columns are `scripts/header.txt` plus `sector`
  and `group_rel`);
- `sector-median.csv`, `membership.txt` and `event_dates.txt` are the inputs;
- `scripts/run.sh` regenerates all of these from the repo root.

**Reading:** results-analyst. The analyst's re-derivations are in `results/analysis/`: `run_all.sh` writes
`analysis.txt` (tables) and `traces.txt` (the traced events). They are read-only and host-only.
- `ev2.awk` copies `events.awk`'s event selection verbatim, so it gets the same 45,599 events, and adds diagnostics.
- The tracer, `trace.awk`, is written independently of `scripts/`.

**Universe:** the PIT top-3000 v12 schedule, which is broad (`universe-discipline.md` U1). **Review pack:** none. This
is not a backtest: there is no capital and no equity curve, and the pre-registration asks for no pack.

Verifies: none

## In brief

- **Verdict: no-build decision for the book's short setup as measured here.** Neither primary cell shows an edge.
  - P1 (breakdown entry) and P2 (pullback entry) each fail criteria 2, 3 and 4 by wide margins, at both price floors.
  - P1: n = 4,235, mean −2.44 %, median −3.76 %, beat 29.7 %.
  - P2: n = 3,530, mean −0.85 %, median −1.91 %, beat 31.4 %.
  - Against the 55 % bar, P1's week-clustered 95 % CI on the beat rate is [27.5, 31.6] %.
  - No descriptive cell meets the six-criteria bar either.
- **Why.** Stage 3 → 4 breakdowns in this universe do not fall faster than the index.
  - Over 1 to 6 months, without a stop, the population is a coin flip against an SPY short (+60 bars: median +0.49 %,
    beat 51.4 %).
  - Nothing on the book's checklist sorts the ones that do. The full checklist is slightly worse than the population
    (beat 46.2 %).
  - The book's market timing (index in Stage 3 or early Stage 4) adds nothing. Inside the checklist, early Stage 4 is
    the worst slice, because broken names rebound with the index (2020 is the extreme). The bull tape is the best phase.
  - The stop then turns a coin flip into a loser. The classifier's Stage-3 top is usually 1–2 weeks, so the stop sits a
    median 10 % above the entry, and 69 % of shorts are stopped.
  - For the checklist cell, no stop width (5 % to 100 %, or above the 26- or 52-week high), entry or market phase
    changes the sign.
- **The four gaps the pre-registration named are each measured, and none of them is the cause.** They were stop room,
  the pullback entry, market phase, and selection.
- **Dividends (the user's question):** there is no evidence that dividend payers make worse shorts once the short is
  charged the dividends.
  - On the rule's outcome, payers and non-payers have the same beat rate (34.2 %), and payers have the better median
    (−2.68 % vs −3.53 %).
  - The "≥ 3 % dividend inside the hold" split cannot answer the question as built. It is conditioned on the
    outcome (defect 8). Measured at decision time instead, the 962 events with a ≥ 3 % dividend do slightly worse:
    beat 31.9 %, against 34.1 % for the rest. The cost is small and is already charged.
  - Do not exclude payers on this evidence. AD-type specials are better caught by a narrower check for an announced
    special before entry, and even that is moot until a short setup shows an edge.
- **Next (the user's call; options in §9).** On this evidence, close single-name shorts as a strategy track. The one
  book-based lever left with a non-trivial prior is short interest. It needs data we do not have, so its first step is
  a data check, not a run.

## 1. Method (brief)

- **Events:**
  - A week whose stage (the `stage_chart.exe` default classifier on adjusted closes) is `Stage4` after a `Stage3` week.
  - Breakdowns from 2000-01-07 to 2025-12-26; the symbol must be in that year's top-3000 list (list Y applies from
    Y-05-31).
  - Breakdown-week raw close ≥ $5 ($17 sensitivity); one event per symbol per 26 weeks.
- **Entries:**
  - E1 is the close of the first bar after the breakdown week.
  - E2 is the first weekly close in weeks +1..+8 at or above the broken support, which is the lowest weekly close of
    the 10 weeks before the break.
- **Outcomes:**
  - O1 is the side-signed short return at +20 / +60 / +120 bars minus an SPY short over the same dates, both on
    adjusted closes, so the short pays dividends.
  - O2 holds a buy-stop 1 % above the highest weekly high of the Stage-3 run, not trailed, to the stop or +120 bars.
    Gaps fill at the open.
  - "Beat" means O2 excess > 0.
- **Primary cells:** SPY in Stage 3 or in Stage 4 for ≤ 8 weeks; prior advance ≥ 30 %; RS not rising; group weak.
  P1 uses E1 and P2 uses E2.
- **Choices the text leaves open:**
  1. E2 enters at the first qualifying **weekly** close (the week's last daily close).
  2. An entry whose close is already at or above its own stop is covered at the next open. That is 1,639 E1 entries
     (3.6 %) and 4,621 E2 entries (12.8 %), counted as `room ≤ 0` in the event table (`analysis.txt` §support).
  3. The checklist drops events with RS class `na` (515) or no sector (17,174), since "RS not rising" and "group weak"
     need both. §5.8 shows the verdict does not depend on it.
  4. Intraday highs and opens are put on the adjusted basis by each bar's adjusted/raw close ratio.
  5. The $17 cells filter the $5 event set, so the de-duplication was done at $5.
  6. The "advance" is the Stage-3 high over the lowest weekly close of the 104 weeks through the breakdown week.

## 2. The decision rule, as written (O2 excess vs the SPY short)

From `results/summary-floor5.txt` and `summary-floor17.txt` (§Decision rule). I reproduced them from
`results/events/*.csv` with independent code.

| criterion | P1, $5 | P2, $5 | P1, $17 | P2, $17 |
|---|---|---|---|---|
| 1. n ≥ 100 | 4,235 ✓ | 3,530 ✓ | 3,506 ✓ | 2,960 ✓ |
| 2. mean ≥ +2 % | −2.44 % ✗ | −0.85 % ✗ | −2.23 % ✗ | −0.84 % ✗ |
| 3. median > 0 | −3.76 % ✗ | −1.91 % ✗ | −3.63 % ✗ | −1.86 % ✗ |
| 4. beat ≥ 55 % | 29.7 % ✗ | 31.4 % ✗ | 29.2 % ✗ | 31.4 % ✗ |
| 5. halves agree in sign (2000–12 / 2013–25 means) | −2.69 / −2.29 ✓ | −1.42 / −0.48 ✓ | −2.81 / −1.87 ✓ | −1.54 / −0.40 ✓ |
| 6. O1 +60 agrees in sign (mean) | −2.69 % ✓ | −0.95 % ✓ | −2.14 % ✓ | −0.77 % ✓ |
| **result** | **no edge** | **no edge** | **no edge** | **no edge** |

Criteria 5 and 6 "pass" only because every reading agrees that the cell is negative.

**Descriptive cells:** none meets all six criteria at the ≥ 58 % bar, at either floor (`analysis.txt` §criteria; 0 of
64 cells at each floor: every split level × E1 / E2, plus the three bear periods). The closest is top width > 20 weeks:
- 5 of 6 criteria (e1: n = 43, mean +4.20 %, median +3.15 %, beat 60.5 %; e2: n = 39, beat 61.5 %). It fails n ≥ 100.
- Its e1 mean rests on two events, YRCW 2010-10-22 (+67.2 %) and EIG 2020-03-20 (+60.1 %). Without them it is +1.30 %,
  which fails criterion 2 as well.
- 22 of its 43 events have no sector, and it includes a warrant (VLY-WS) and a probable foreign listing (ROSG).
- It cannot propose a pre-registration under the rule.

## 3. Distributions (O2 excess vs the SPY short, $5 floor)

From `summary-floor5.txt`.

| cell | n | mean | median | p10 | p25 | p75 | p90 | beat |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| P1 | 4,235 | −2.44 % | −3.76 % | −16.8 | −9.7 | +1.0 | +18.4 | 29.7 % |
| P1, clipped ±100 % | 4,235 | −2.33 % | −3.76 % | −16.8 | −9.7 | +1.0 | +18.4 | 29.7 % |
| P1, 2000–12 / 2013–25 | 1,641 / 2,594 | −2.69 / −2.29 % | −4.06 / −3.55 % | | | | | 27.4 / 31.1 % |
| P1, bear 2000–02 | 169 | −1.97 % | −5.80 % | −20.7 | −12.9 | +3.6 | +28.3 | 31.4 % |
| P1, bear 2007–09 | 330 | −2.75 % | −5.12 % | −19.0 | −11.1 | +1.4 | +22.8 | 27.9 % |
| P1, bear 2022 | 461 | −3.07 % | −4.19 % | −19.2 | −10.9 | +1.8 | +16.2 | 31.2 % |
| P2 | 3,530 | −0.85 % | −1.91 % | −11.1 | −5.7 | +0.6 | +12.4 | 31.4 % |
| P2, clipped ±100 % | 3,530 | −0.82 % | −1.91 % | −11.1 | −5.7 | +0.6 | +12.4 | 31.4 % |
| P2, 2000–12 / 2013–25 | 1,388 / 2,142 | −1.42 / −0.48 % | −2.31 / −1.59 % | | | | | 27.5 / 33.9 % |
| P2, bear 2000–02 | 127 | −2.21 % | −2.70 % | −16.3 | −8.1 | +0.5 | +12.8 | 29.9 % |
| P2, bear 2007–09 | 288 | −0.98 % | −2.45 % | −16.0 | −8.4 | +0.8 | +20.5 | 29.9 % |
| P2, bear 2022 | 386 | −0.53 % | −1.57 % | −13.6 | −7.0 | +2.9 | +16.4 | 37.3 % |
| all events, E1 | 45,599 | −1.28 % | −3.02 % | −15.3 | −8.5 | +4.1 | +23.8 | 34.2 % |
| all events, E2 | 36,085 | −1.23 % | −1.71 % | −10.5 | −5.5 | +0.9 | +16.1 | 32.8 % |

**O1, no stop.** These are the same events at fixed horizons (`summary-floor5.txt`).

| | +20 bars | +60 bars | +120 bars |
|---|---|---|---|
| P1: mean / median / beat | −0.82 / −0.69 / 46.0 % | −2.69 / −1.29 / 46.2 % | −3.43 / −1.35 / 47.2 % |
| P2 | −0.14 / +0.07 / 50.4 % | −0.95 / −0.45 / 48.4 % | −2.05 / +0.17 / 50.4 % |
| all events, E1 | −0.07 / +0.19 / 51.0 % | −1.64 / +0.49 / 51.4 % | −2.74 / +1.47 / 53.0 % |
| all events, E2 | +0.27 / +0.38 / 52.1 % | −1.36 / +0.51 / 51.5 % | −3.07 / +1.45 / 53.0 % |

**In absolute terms** (the stock short's own O2 return, not excess): P1 has a median of −8.48 %, and only 18.6 % of
its shorts make money. P2 has a median of −4.70 %, and 20.9 % make money.

**Reported regardless of verdict** (`summary-floor5.txt` unless noted):
- **Events by breakdown year:**

  | 2000 | 2001 | 2002 | 2003 | 2004 | 2005 | 2006 | 2007 | 2008 | 2009 | 2010 | 2011 | 2012 |
  |---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
  | 1,508 | 1,544 | 1,954 | 1,114 | 1,813 | 2,030 | 1,785 | 2,038 | 1,956 | 732 | 1,738 | 2,122 | 1,814 |

  | 2013 | 2014 | 2015 | 2016 | 2017 | 2018 | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 |
  |---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
  | 1,313 | 2,056 | 1,995 | 1,583 | 1,572 | 2,559 | 1,433 | 1,605 | 1,809 | 1,808 | 2,022 | 1,732 | 1,964 |

  P1 has no events in 2009, 2013, 2017, 2021 or 2024, when SPY was in neither Stage 3 nor early Stage 4. It has few in
  2001 (9) and 2002 (26), because SPY's long Stage-4 runs there are "late" (> 8 weeks) (`analysis.txt` §years).
- **The old 15 % stop-room slice:** 32,202 of 45,599 E1 entries (70.6 %) have room ≤ 15 %, as do 61.5 % of P1
  (`analysis.txt` §support). At $17 the share is 74.3 %.
- **E2:** 79.1 % of events pull back within 8 weeks (36,085 of 45,599; 80.0 % at $17). The book says about half. Time
  to the pullback: week 1, 64.4 %; week 2, 12.5 %; week 3, 7.4 %; week 4, 5.1 %; week 5, 3.7 %; week 6, 2.7 %; week 7,
  2.2 %; week 8, 1.9 %. §5.4 explains the 79 %.
- **Stopped under O2:** 31,399 E1 shorts (68.9 %) and 28,801 E2 shorts (79.8 %). In P1, 72.9 % (`analysis.txt`
  §support); in P2, 81.8 % (§paired).

**By year** (`analysis.txt` §years): P1's median O2 excess is negative in 21 of the 22 years that have P1 events. The
exception is 2002 (n = 26, median +3.43 %, beat 57.7 %). Its beat rate is below 38 % in every other year. The worst
no-stop year is 2020 (n = 270, O1 +60 median −9.86 %), the COVID V-rebound.

## 4. Verdict, calibrated

**What this design can claim:**
- The book's short setup shows no edge over an index short at any tested stop width, entry, horizon or price floor.
  That holds as the book's checklist defines it, on our classifier's Stage 3 → 4 events in the broad PIT top-3000, over
  26 years and three bear markets.
- The sample can see an edge of the pre-registered size. P1's beat-rate CI is [27.5, 31.6] % with weeks as clusters
  (264 weeks) and [27.3, 32.3] % with quarters (48). The bar is 55 %.
- The four candidate causes the pre-registration named are each measured: stop room, entry, market phase and
  selection. None of them flips the sign (§5).
- Under the pre-registration, this is a **no-build decision**. The short stop room, the pullback entry and the
  market-phase gate are not built. The existing short flags stay default-off axes.

**What it cannot claim:**
- That no short strategy can work. This is a proxy screen (`mechanism-validation-rigor.md`, verdict calibration). It
  rules out building **this** setup; it does not prove that shorting fails.
- Anything about short interest, which is the pre-registration's named untested item.
- Anything about a top defined the way a chartist would draw it. Our classifier's Stage 3 is usually 1–2 weeks long
  (§5.3).
- Anything about trailed stops (the pre-registration: "a later question"). Round 1 ran the book's trail on its own
  entries and found the exits bounded.
- Anything net of costs. Borrow, commissions, slippage and the uptick rule are all absent, and each would make the
  shorts worse.

## 5. Why

The deliverable is the decomposition. It asks which mechanism produced "no edge": selection, market phase, stop room,
entry timing, the event definition, or the fat-tail tax.

### 5.1 Selection: breakdowns do not beat the index, and the checklist does not sort them

O1 is the cleanest selection read: no stop, fixed horizons, against an SPY short over the same dates.

- **The population is a coin flip** (`summary-floor5.txt`): O1 +60 has a median of +0.49 % and a beat of 51.4 %; O1
  +120 has a median of +1.47 % and a beat of 53.0 %. Both means are negative (−1.64 % and −2.74 %): see §5.6.
- **Each checklist item alone is a coin flip at +60 bars** (`analysis.txt` §checklist): SPY in Stage 3 or early Stage 4,
  49.9 %; advance ≥ 30 %, 51.0 %; RS not rising, 51.2 %; group weak, 50.5 %.
- **Together they are slightly worse than any one of them.** P1 at +60 bars has a median of −1.29 % and a beat of
  46.2 %; the week-clustered CI is [43.8, 48.6] % and the quarter-clustered CI [42.8, 50.0] %. At +120 bars it is
  −1.35 % and 47.2 %.
- **RS does not sort breakdowns the way the book says.**
  - The class the book forbids, RS rising, is the least bad on the rule's outcome: O2 beat 39.2 %, median −1.52 %.
  - Without a stop it is as good as either falling class: O1 +120 beat 54.9 %, median +2.11 %, and it holds in both
    halves (52.5 % and 57.8 %).
  - The book's ideal, "negative and falling", is 34.4 % on O2 and 53.8 % on O1 +120. "Topped" (positive but falling)
    is the worst: 31.4 % and 49.0 % (`summary-floor5.txt`; `analysis.txt` §checklist).
  - It is not stop room: RS-rising entries have the tightest median room (8.0 %, against 10.8 % for "negative and
    falling").
- **Group and advance do not sort them either.** Weak and strong groups are the same (O2 beat 33.4 % vs 33.0 %). A
  bigger prior advance is worse at the median: ≥ 100 % is −4.22 %, < 30 % is −2.29 % (`summary-floor5.txt`).

### 5.2 Market phase: the book's timing adds nothing, and its early-Stage-4 slice is the worst

- **The O2 median is about −3 % in every SPY phase.** It is −3.02 % in early Stage 4, −3.13 % in late Stage 4, −3.00 %
  in Stage 3 and −3.02 % in Stage 1/2 (`summary-floor5.txt`).
- **Without a stop at +120 bars, the book's preferred phases are coin flips and the bull tape is the best**
  (`analysis.txt` §checklist):

  | SPY phase | Stage 1/2 | Stage 3 | early Stage 4 | late Stage 4 |
  |---|---|---|---|---|
  | beat | 55.1 % | 51.6 % | 50.6 % | 45.7 % |
  | median | +2.48 % | +0.76 % | +0.37 % | −2.34 % |

- **Inside P1, early Stage 4 (the book's "index in Stage 4") is the worst slice** (`analysis.txt` §phase).
  - n = 1,742; O1 +120 median −2.24 %, beat 45.4 %.
  - Absolute O2 short return median −11.31 %, with 16.1 % of shorts making money.
  - P1 in SPY Stage 3: O1 +120 median −0.80 %, beat 48.4 %.
- **The likely mechanism.** A breakdown in a falling market is a high-beta loser. When the index turns, it rebounds
  harder than the index: the short loses, and loses more than an SPY short would.
  - In 2020, P1's O1 +60 median was −9.86 % (n = 270).
  - Six of P1's eight events beyond −100 % are 2020-03-20 breakdowns that went on to double or triple: GTLS, JACK,
    CRMT, PMT, AMWD, MHO.
  - This is the same shape as the index-hedge screen's "rebound bleed" and Phase B's "Bearish weeks hold the
    V-rebounds", now at the single-name level. It matches the momentum-crash pattern in the literature: losers rebound
    hardest just after market declines.

### 5.3 Stop room: the stop is tight because the classifier's top is short, and no width rescues the cell

- **The Stage-3 run before the break is brief** (`analysis.txt` §topwidth): 1 week in 30.5 % of events, 2 weeks in
  34.2 %, 3 weeks in 15.3 %, and ≤ 8 weeks in 96.1 %.
- **The classifier also fragments tops.** CSCO 2000 went Stage 3 → 2 → 3 through its top, and `top_width` counts only
  the last contiguous run. So the "Stage-3 high" is the high of the last few weeks.
- **So the head-and-shoulders proxy is uninformative.** It fires on 18 E1 events and 13 E2 events (`summary-floor5.txt`),
  because a 1–2-week Stage-3 run cannot hold three swing highs. "The bigger the top, the bigger the drop" is not tested
  here. It needs a top definition that spans the whole distribution area (§9, item 2).
- **So the stop is close.** The room has a median of 10.2 % (P1 12.1 %), with p25 5.9 % and p75 16.5 %
  (`analysis.txt` §surface). 68.9 % of E1 shorts are stopped (`summary-floor5.txt`), and 72.9 % of P1 (`analysis.txt`
  §support).
- **Paired on the same P1 events, the stop costs most of the hit rate.** Going from no stop (O1 +120) to the
  pre-registered stop, the beat drops from 47.2 % to 29.7 % and the median from −1.35 % to −3.76 %. The mean improves
  (−3.43 % → −2.44 %), because the stop cuts the squeezes.
- **The surface shows that no width works** (E1, excess vs the SPY short, hold to the stop or +120 bars; `analysis.txt`
  §surface):

  | buy-stop | P1 median | P1 beat | P1 mean | P1 stopped | all events: median / beat |
  |---|---:|---:|---:|---:|---|
  | pre-registered (1 % above the Stage-3 high) | −3.76 % | 29.7 % | −2.44 % | 72.9 % | −3.02 % / 34.2 % |
  | entry + 5 % | −2.53 % | 23.8 % | −0.90 % | 92.2 % | −3.01 % / 24.5 % |
  | entry + 10 % | −4.80 % | 23.8 % | −1.47 % | 80.9 % | −5.26 % / 29.9 % |
  | entry + 15 % | −6.49 % | 29.3 % | −1.75 % | 68.6 % | −6.30 % / 36.8 % |
  | entry + 20 % | −7.86 % | 34.4 % | −2.18 % | 57.0 % | −5.00 % / 42.5 % |
  | entry + 30 % | −5.17 % | 41.2 % | −2.51 % | 37.4 % | −0.75 % / 48.6 % |
  | entry + 50 % | −2.77 % | 44.8 % | −2.98 % | 16.6 % | +0.91 % / 51.8 % |
  | entry + 100 % | −1.42 % | 47.0 % | −3.27 % | 3.6 % | +1.41 % / 52.8 % |
  | 1 % above the 26-week high (median room 28 %) | −4.21 % | 42.1 % | −2.83 % | 37.7 % | −1.15 % / 48.0 % |
  | 1 % above the 52-week high (median room 29 %) | −3.69 % | 42.7 % | −2.88 % | 34.7 % | −0.43 % / 49.2 % |
  | no stop (O1 +120) | −1.35 % | 47.2 % | −3.43 % | 0 | +1.47 % / 53.0 % |

  Widening the stop moves the result toward the no-stop coin flip, and never past it. The mean gets worse as the stop
  widens, because the squeezes come back.

  **The verdict survives the tight stop.** With no stop at all, P1 still fails criteria 2, 3 and 4: at +120 bars the
  mean is −3.43 %, the median −1.35 % and the beat 47.2 %; at +60 bars −2.69 %, −1.29 % and 46.2 %. **Stop room
  explains why O2 is worse than O1. It does not explain why neither has an edge.** A "wider-top" stop is in the table
  (the 26- and 52-week highs), and it does not help. A different *event* definition, keyed to the whole top area,
  would be its own pre-registration (§9), not a rescue.

### 5.4 Entry timing: the pullback entry helps a little, and is mostly a one-week delay

- **Most E2 pullbacks are not pullbacks** (`analysis.txt` §support).
  - Only 51.9 % of Stage 3 → 4 events close below the broken support (the E2 level) in the breakdown week. The
    classifier's transition and a break of the 10-week low are different events.
  - When the breakdown close is at or above the support (48.1 % of events), E2 fires 92.5 % of the time, and in week 1
    77.0 % of the time. Then "a close at or above the level" only means the stock did not fall further.
  - 72.6 % of week-1 E2 entries come from such non-breaks. This, not the book's pullback, is where the 79 % E2 share
    comes from. On real breaks, E2 fires 66.7 % of the time and in week 1 only 26.9 %.
- **Paired on the same events, E2 beats E1** (`analysis.txt` §paired).
  - Over the 3,530 P2 events, the median gain is +1.88 pp; E2 is better in 70.4 % of events, and the mean gain is
    +3.37 pp. E2 shorts a median 3.9 % higher.
  - On O1 +60 the paired gain is +1.86 pp (64.9 %).
- **But the events that pull back are the failed breakdowns.** Their own E1 outcome is a median of −4.35 % and a beat
  of 24.0 %. E2 recovers part of that, to a median of −1.91 % and a beat of 31.4 %. Timing moves the level, not the
  sign.
- **12.8 % of P2 entries are at or above their own stop**, and so cover at the next open for about zero. Dropping them
  makes P2 worse: median −2.62 %, beat 28.8 % (`analysis.txt` §robust).

### 5.5 The event itself: late, and often not a break. Neither is the cause.

- **The classifier calls Stage 4 late** (`analysis.txt` §surface). At the event, the median stock's close is 19.4 %
  below its highest weekly close of the prior 52 weeks (P1: 20.0 %; p10 −39 %). OSPN 2007 fell 42 % in three weeks
  while still classified Stage 2 (§6).
- **Earlier or cleaner events are not better** (`analysis.txt` §lateness).
  - P1 events less than 10 % off the high (n = 260) have an O2 beat of 33.1 % and an O1 +60 beat of 53.8 %.
  - P1 events that really closed below support (n = 2,351) have an O2 beat of 29.6 %, against 29.7 % for the rest.
- **The direction of this split flips between the population and P1.** In the whole population, deeper-decline events
  are slightly better without a stop (< −30 %: O1 +120 beat 55.9 %). Inside P1 they are worse (< −30 %: O1 +60 beat
  43.2 %). That is the market-phase effect of §5.2: deep losers continue in calm tapes and rebound after market falls.
  So it is not a stable lever.

### 5.6 The fat-tail tax: the short book carries the long book's tail on the wrong side

- **The left tail outweighs the right** (no stop, +120 bars; `analysis.txt` §tail).
  - 3.7 % of events lose more than 50 % against the SPY short, summing to −278,707 pp.
  - 3.0 % gain more than 50 %, summing to +87,329 pp.
  - Clipped at ±100 %, the population's mean is +0.62 %, against −2.74 % raw. The negative mean is the squeezes (and
    the splices, §12).
- **The short's payoff is capped at +100 % and unbounded below.** That is `project_edge_is_the_fat_tail` from the other
  side: the long book's edge is its uncapped right tail, and a short book holds the uncapped tail against itself.
- **P1 is negative even clipped** (−2.92 %). Its problem is the centre of the distribution, not only the tail.

### 5.7 Economic scale

From `analysis.txt` §scale: the sum of excess over the sum of bars held, × 252.

- **P1:** held a mean of 54.7 bars (median 38). The excess is **−11.3 %/yr** per unit of capital deployed (−10.7 %/yr
  clipped), and the absolute short return is −40.4 %/yr.
- **P2:** −5.4 %/yr (−5.2 % clipped), and −23.9 %/yr absolute.
- **All E1 events, clipped:** +0.7 %/yr, which is nothing.
- **The best-looking region, the bull tape** (SPY Stage 1/2, O1 +120): a median of +2.48 % and a mean of +1.08 % per
  roughly 24 weeks, about +2–5 %/yr. That is before borrow. Round 1 paid 25 %/yr on names under $17.

### 5.8 What does not move the verdict

From `analysis.txt` §robust, §survivor and §checklist.

- **Outliers:**
  - Clipping at ±100 % leaves P1's median and beat unchanged (−3.76 %, 29.7 %).
  - Dropping |excess| > 50 % gives a median of −3.76 % and a beat of 29.3 %.
  - Dropping room > 100 % gives a median of −3.73 % and a beat of 29.6 %.
  - P1's eight events beyond ±100 % are genuine: the six March-2020 rebounds, plus LIVN 2004-08-27 and EYPT
    2023-10-27.
- **Degenerate stops:** dropping entries at or above their own stop, or with room ≤ 2 %, makes P1 and P2 worse (P1
  median −4.08 % and −4.44 %).
- **The 38 % of events without a sector.** Dropping the group filter and keeping them (n = 11,483) gives a median of
  −3.53 % and a beat of 32.5 %. The `group=na` events alone (n = 4,497) give −3.59 % and 34.8 %.
- **Survivorship in the sector file.** `data/sectors.csv` covers essentially only symbols still listed in 2026: 0.9 % of
  sector-covered events are on delisted symbols, against 91.2 % of `group=na` events. So P1 and P2 are, in effect,
  survivor-only cells.
  - The bias runs slightly against the short: on the checklist without the group filter, delisted names have an O2
    beat of 34.4 % against 31.5 % for live ones.
  - It is about 3 pp, against a 25 pp shortfall.
- **The $17 floor:** P1 29.2 %, P2 31.4 % (§2).

### 5.9 The points raised before this reading, item by item

| point | finding | where |
|---|---|---|
| The Stage-3 top is short, so the O2 stop is tight | True: the top is ≤ 8 weeks in 96.1 % of events and the median room is 10.2 %. The verdict survives it: with no stop, P1 still fails criteria 2–4, and no stop width rescues it. A wider-top *event* definition would be its own pre-registration | §5.3, §9 |
| E2 is mostly a one-week shift of E1 | True: 64.4 % of pullbacks are in week 1, and 72.6 % of those follow a "breakdown" that never closed below support. Paired, E2 helps by a median +1.9 pp but stays negative | §5.4 |
| Vendor splices produce outlier tails | True (BELM −47,833 % and others), but none is in P1 or P2. Medians and beat rates do not move under clipping or trimming | §5.8, §12 |
| 38 % of events have no sector | True. Those events are 91 % delisted names, so P1 and P2 are survivor-only cells. The bias runs slightly against the short (about 3 pp of beat rate), far short of the 25 pp gap | §5.8 |
| The H&S proxy almost never fires | True (18 / 13 events). The split is uninformative | §5.3 |
| Dividend payers | No evidence that payers are worse shorts. Non-payers have the worst mean, from the squeeze tail | §10 |
| No secondary cell may trigger a build | None qualifies: 0 of 64 cells at each floor. The closest (top width > 20 weeks, n = 43) fails n ≥ 100 and rests on two events | §2 |

## 6. Traced events

Ten winners and ten losers. They are taken from P1 (E1 entry) and P2 (E2 entry) at fixed quantiles of O2 excess:
losers at 5 / 20 / 35 / 50 / 65 %, winners at 75 / 82 / 89 / 95 / 99 %. They were not hand-picked.

Each was re-derived from the raw bars (`data/<A>/<B>/<SYM>/data.csv`), the stage replay and `data/S/Y/SPY/data.csv` by
`results/analysis/trace.awk`. That is an independently written tracer that shares no code with `events.awk`.
**All 20 reproduce every price-path field compared.** The fields are the Stage-3 run and `top_width`, the stop, the
entry date and price, the room, O1 at +20 / +60 / +120, the O2 exit bar, stopped flag, return and excess, and the E2
week and entry. With CSCO, that is 450 fields over 21 events and 39 legs, checked mechanically by `check_traces.awk`
against the committed rows, with 0 mismatches (`analysis.txt` §trace check). The classification fields were
spot-checked separately against independent recomputations:
- the SPY phase for all ten P1 events, against `spy-weekly-stage.csv`;
- the Mansfield RS and its class for CSCO, OSPN and LFST;
- `group_rel` for CSCO, against `sector-median.csv`.

All agree. The full printouts are in `results/analysis/traces.txt`, which also traces CSCO 2000-09-22 as a 21st
example. **No script defect was found.** Prices are adjusted.

**P1 (E1 entry, the next close after the breakdown week)**

| q | event | top | entry | stop (room) | exit | short | SPY | excess | O1 +120 | what it shows |
|---|---|---|---|---|---|---:|---:|---:|---:|---|
| 5 | BCE 2000-06-02 | 3 wk | 06-05 @ 6.044 | 30.171 (+399 %) | +120 bars, 11-22 @ 6.838 | −13.1 % | −9.7 % | −22.9 % | −22.9 % | **Data artifact.** The raw close goes 103.10 → 23.41 on 2000-05-09 (the Nortel distribution) and the adjusted series falls with it. The "top" is pre-distribution (§12) |
| 20 | AIR 2007-09-14 | 5 wk | 09-17 @ 27.749 | 31.782 (+14.5 %) | stop, bar +59, 12-10 | −14.5 % | +3.2 % | −11.4 % | +9.6 % | Whipsaw: stopped on the December rally, then fell 22 % |
| 35 | AVA 2004-05-21 | 3 wk | 05-24 @ 6.742 | 7.508 (+11.4 %) | stop, bar +20, 06-23 | −11.4 % | +4.4 % | −6.9 % | −4.1 % | Failed breakdown: never broke support, kept rising |
| 50 | OSPN 2007-11-16 | 1 wk | 11-19 @ 20.794 | 22.614 (+8.8 %) | stop, bar +12, 12-06 | −8.8 % | +5.0 % | −3.8 % | +45.1 % | Late classifier plus a 1-week top: the close fell 39.47 → 23.04 in three weeks while still Stage 2. Stopped, then fell 46 % |
| 65 | PLUS 2016-02-26 | 2 wk | 02-29 @ 18.536 | 19.619 (+5.8 %) | stop, bar +9, 03-11 | −5.8 % | +4.8 % | −1.1 % | +1.4 % | Broke down into the Feb-2016 market low and was squeezed in the rebound |
| 75 | KRNT 2018-12-28 | 1 wk | 12-31 @ 18.720 | 18.453 (−1.4 %) | next open, 2019-01-02 @ 18.55 | +0.9 % | +0.1 % | +1.0 % | −31.3 % | Degenerate "win": the entry close is above its own stop. The stock then rose 50 % |
| 82 | WM 2020-03-27 | 2 wk | 03-30 @ 85.478 | 105.215 (+23.1 %) | stop, bar +116, 09-14 | −23.1 % | +29.9 % | +6.8 % | +4.4 % | A "winner" that lost 23 %: SPY rose more |
| 89 | ING 2011-07-29 | 7 wk | 08-01 @ 5.565 | 6.717 (+20.7 %) | +120 bars, 2012-01-23 @ 4.830 | +13.2 % | +3.4 % | +16.6 % | +16.6 % | Real winner: a euro-crisis bank with a wide stop |
| 95 | CSL 2020-03-20 | 2 wk | 03-23 @ 93.219 | 144.700 (+55.2 %) | +120 bars, 09-11 @ 113.524 | −21.8 % | +50.5 % | +28.7 % | +28.7 % | A "winner" that lost 22 %, shorted at the COVID low |
| 99 | LFST 2025-04-04 | 2 wk | 04-07 @ 6.510 | 7.151 (+9.8 %) | +120 bars, 09-29 @ 5.420 | +16.7 % | +32.3 % | +49.1 % | +49.1 % | Real winner: fell while the market rallied off the tariff low |

**P2 (E2 entry, the first weekly close back at the broken support)**

| q | event | top; pullback | entry | stop (room) | exit | short | SPY | excess | O1 +120 | what it shows |
|---|---|---|---|---|---|---:|---:|---:|---:|---|
| 5 | PLXS 2022-02-11 | 3 wk; wk 1 | 02-18 @ 81.830 | 88.779 (+8.5 %) | stop, bar +108, 07-27 | −8.5 % | −7.0 % | −15.4 % | −16.4 % | Rose 15 % through the 2022 bear. The "breakdown" never closed below support |
| 20 | DOO 2022-09-23 | 3 wk; wk 5 | 10-28 @ 62.147 | 69.314 (+11.5 %) | stop, bar +23, 12-01 | −11.5 % | +4.7 % | −6.8 % | −5.0 % | A real break and a real pullback, squeezed in the Q4-2022 rally |
| 35 | LGND 2016-02-12 | 2 wk; wk 2 | 02-26 @ 60.686 | 66.775 (+10.0 %) | stop, bar +22, 03-30 | −10.0 % | +6.2 % | −3.9 % | +1.5 % | A real break; the rebound took it through the stop |
| 50 | ETR 2007-08-10 | 1 wk; wk 1 | 08-17 @ 23.136 | 24.817 (+7.3 %) | stop, bar +21, 09-18 | −7.3 % | +5.4 % | −1.9 % | −13.0 % | No break of support; a utility that kept rising |
| 65 | TRGP 2025-04-17 | 1 wk; wk 1 | 04-25 @ 171.872 | 172.388 (+0.3 %) | gap over the stop, 04-28 open @ 172.462 | −0.3 % | +0.0 % | −0.3 % | +37.3 % | A 0.3 % stop, gone the next morning. Then fell 17 % |
| 75 | GEN 2025-04-04 | 12 wk; wk 5 | 05-09 @ 28.109 | 28.282 (+0.6 %) | gap, 05-12 open @ 28.868 | −2.7 % | +3.3 % | +0.6 % | +30.2 % | A 0.6 % stop; "won" because SPY gapped more on the tariff-truce day. Then fell |
| 82 | KR 2018-12-31 | 2 wk; wk 1 | 2019-01-04 @ 19.585 | 21.190 (+8.2 %) | stop, bar +36, 02-27 | −8.2 % | +10.6 % | +2.4 % | +38.4 % | A "winner" that lost 8 %. Then fell 22 % |
| 89 | SEIC 2008-01-25 | 1 wk; wk 1 | 02-01 @ 22.368 | 22.655 (+1.3 %) | +120 bars, 07-24 @ 17.969 | +19.7 % | −9.2 % | +10.5 % | +10.5 % | Real winner; the 1.3 % stop was never touched |
| 95 | EQIX 2025-03-14 | 1 wk; wk 7 | 05-02 @ 851.788 | 910.626 (+6.9 %) | +120 bars, 10-23 @ 818.392 | +3.9 % | +19.2 % | +23.1 % | +23.1 % | Mostly relative: a flat stock in a rising market |
| 99 | FHN 2023-03-24 | 3 wk; wk 1 | 03-31 @ 15.802 | 22.102 (+39.9 %) | +120 bars, 09-22 @ 10.138 | +35.9 % | +5.9 % | +41.7 % | +41.7 % | Real winner: the 2023 regional-bank break, with room from the pre-SVB top |

**What the twenty say:**
- **The losers come in three shapes.**
  - Six are failed breakdowns that kept rising: AVA, PLUS, PLXS, DOO, LGND and ETR. That is selection (§5.1).
  - Two are whipsaws, stopped and then fallen: AIR and OSPN. A third, TRGP, had a 0.3 % stop. That is stop room
    (§5.3).
  - One is a data artifact, BCE.
- **Of the ten winners, only five are real declines:** ING, LFST, SEIC, FHN, and EQIX in part.
  - Three lost money in absolute terms and "won" only because SPY rose more: WM −23 %, CSL −22 % and KR −8 %.
  - Two are degenerate: KRNT entered above its own stop, and GEN had a 0.6 % stop and won only on the gap.
- **The stop turned five eventual winners into losses or near-zero results:** AIR, OSPN, TRGP, GEN and KR (O1 +120
  between +9.6 % and +45.1 %). Against that, it saved only small amounts on the six failed breakdowns (O1 +120
  between −16.4 % and +1.5 %). That is §5.3 in miniature.
- **13 of the 20 "breakdowns" never closed below their broken support,** in line with §5.4.

## 7. Rigor checks (`mechanism-validation-rigor.md`)

1. **Estimand.** A build would change the realised P&L of a short book that enters these setups with the book's
   buy-stop.
   - O2 is that trade's excess over an SPY short, with no capital, sizing, borrow, commissions, slippage or uptick rule,
     and no trail. Dividends are charged through adjusted closes.
   - So the proxy is optimistic on costs. Round 1 put costs at −0.14 log over 26 years.
   - O1 measures the selection edge at fixed horizons, with no exits at all.
   - The benchmark is relative. A short can "win" while losing money (WM, CSL, KR), so the absolute short return is
     reported beside it (§3).
2. **Distributions.** Every headline cell is given with n, mean, median, p10–p90 and beat (§3). The ±100 % clipped
   lines and the trims are in §5.8.
3. **Economic scale.** It is in §5.7: P1 is −11.3 %/yr per unit of capital-time, and the population is about zero.
4. **Selection and survivorship.**
   - The PIT lists include names that later delisted. The sector file does not, which makes P1 and P2 survivor-only;
     that biases slightly against the short (§5.8).
   - 443 events (0.97 %) have fewer than 120 bars after the E1 entry, and carry their last bar. Their O1 +120 has a
     mean of −16.7 % and a beat of 32.1 %, which reads as mostly acquisitions: the short covers at the deal price.
     That is realistic, and it biases against the short.
   - Only 113 O2 rows (0.25 %) end on a truncated bar without a stop.
   - A bankrupt name whose data stops above zero would understate a winner. This is too small to matter.
   - Every attribute is measured at the breakdown week. The dividend-in-hold flag is ex post by design.
5. **Surface.** The knobs swept are:
   - stop width (5–100 %, 26- and 52-week highs; §5.3);
   - entry (E1 / E2, paired; §5.4);
   - horizon (+20 / +60 / +120);
   - price floor ($5 / $17);
   - top width (8 buckets; O1 +120 beat is flat at 51–54 % for 1–20 weeks);
   - prior decline (§5.5).

   None has a region that clears the bar.
6. **Paired and event-level.** E2 vs E1 and O2 vs O1 are on the same events. 21 events are traced end to end (§6).
7. **Uncertainty and power.** Events cluster in crash weeks, so the confidence intervals use a cluster bootstrap
   (`analysis.txt` §bootstrap, B = 1,000).

   | cell, outcome | week clusters | quarter clusters |
   |---|---|---|
   | P1 O2 beat | [27.5, 31.6] % (264) | [27.3, 32.3] % (48) |
   | P1 O2 median | [−4.34, −3.34] % | [−4.27, −3.35] % |
   | P1 O1 +60 beat | [43.8, 48.6] % | [42.8, 50.0] % |
   | P2 O2 beat | [29.2, 33.5] % (260) | [28.6, 34.3] % (48) |
   | P2 O1 +60 beat | [45.9, 50.9] % | [45.3, 52.0] % |

   The sample can distinguish 30 % from 55 % many times over. This is not a power failure.
8. **Validator V6.** Not applicable. There are no simulator arms and no validator reports. The paired reads are within
   event, on the same bars.

## 8. How it fits what we know

- **It confirms and extends Phase B round 1** (ledger `2026-10-10-shorts-phase-b-round1`,
  `project_shorts_liveness_dead`).
  - Round 1 found that the shorted Stage-4 breakdowns rose after the fill, and that its skipped top-N pool was a coin
    flip against SPY.
  - This map measures every breakdown (45,599, not the screener's ranked pool) with the book's own stop, both of the
    book's entries and the book's checklist. It gets the same answer.
  - So fixing the four gaps the user named on 2026-10-12, which the pre-registration was built on, would not have
    rescued round 1. They were the long-designed stop room, the breakdown-only entry, the macro-composite timing, and
    the mirrored score; the map puts the book's own checklist in the score's place, and it does not rank either.
- **It confirms the index-hedge screen** (ledger `2026-10-12-index-hedge-screen`, `project_index_hedge_screen_no_build`)
  at the single-name level. Lagged Stage-4 gates come in late and bleed in the rebound. The book's early-Stage-4 phase
  is the worst P1 slice (§5.2).
- **It refines the score-threshold addendum** (#3273). There, "weakest stock in the weakest sector" was the worst filled
  cohort. Here, group strength is flat and the RS ordering runs against the book (§5.1). The book's selection cues do
  not rank Stage-4 breakdowns in this universe.
- **It mirrors `project_edge_is_the_fat_tail`.** The edge that carries the long book is the uncapped right tail. The
  short book holds that tail against itself: the clipped mean is +0.6 % and the raw mean −2.7 % (§5.6).
- **It agrees with P0a** (`project_p0_levers_no_build_2026_06_20`): on the deep broad run, a reserved short sleeve lost
  at every fraction. P1a (`project_p1a_deep_short_screens`) was an sp500 cell, so it is not evidence here
  (`universe-discipline.md`).
- **It contradicts the pre-registration's own premise 1, and that is worth recording.**
  - The premise: our stop is tighter than the book's "plenty of room".
  - With the book's stop (above the Stage-3 high), 70.6 % of events have room ≤ 15 %. The room is tight because our
    classifier's Stage 3 is short. Round 1's 2,024 of 2,184 `No_structural_stop` skips were a different construct, the
    support-floor anchor.
  - Either way, a wide stop does not help (§5.3). The premise names a real gap that is not the cause.

## 9. What it implies next (options; the choice is the user's)

**What the why rules out:**
- More dials on this setup: a wider or narrower stop, the pullback entry, the index-phase gate, RS / group / advance
  filters, or a stricter score. Each was measured here or in round 1, and none changes the sign.
- A build of P1 or P2 behind flags. The rule says no-build. The short flags stay default-off axes (pre-registration).
- Excluding dividend payers (§10).

**What it leaves open, in order of prior:**
1. **Short interest** (the book's squeeze filter, "sucker shorts"). It is book-based, and it is the pre-registration's
   named remaining item.
   - The rule (Ch. 7, the "sucker short"): avoid "a very large short interest relative to the average daily trading
     volume … these too-obvious shorts often have a short position five times or more the average daily volume".
   - It targets the left tail that makes the mean negative (§5.6).
   - It would have to do more than trim that tail: P1's no-stop median is −1.3 % with a 46 % hit rate.
   - It needs a point-in-time short-interest history the warehouse lacks. The first step is to check coverage
     (FINRA or exchange history, and how far back before 2007 it goes), not a run.
   - Prior: low to moderate.
2. **A wider-top event definition.** This is the book's "big top": the whole distribution area across the
   classifier's Stage 2/3 flips (as at CSCO 2000), with head-and-shoulders detected on it and the stop above that top's
   last rally peak.
   - It is book-based, but this map gives it a weak prior. Without a stop, the beat is flat (51–54 %) across top
     widths of 1–20 weeks. The only positive cell (> 20 weeks, n = 43) rests on two events.
   - It needs its own pre-registration with a new event definition, not a rescue of this one. Prior: low.
3. **The book's trailing buy-stop on these entries.** Round 1 ran it, and the exits were bounded: a perfect-hindsight
   exit on every winner left the 26-year book at +1.3 % (v0) and +4.5 % (v1), ex interest. Prior: low.
4. **Index-shaped bear protection** is closed (the index-hedge screen).
5. **Not recommended:** a relative-value pair, shorting Stage-4 names against a long index in bull tapes.
   - It is the only region above 55 % (SPY Stage 1/2, O1 +120: beat 55.1 %, median +2.5 %).
   - But it is not the book's short (the book shorts bear markets), it is about +2–5 %/yr before borrow, and it is
     below the 58 % descriptive bar.

**Recommendation (honest, and the user decides):**
- Close single-name shorts as a strategy track. The user's working hypothesis was "we're just not doing it very well".
  This map tested the four specific ways we might be doing it badly, and the setup itself shows no edge here.
- If the user still wants to pursue shorts, the one lever with a book basis and a non-trivial prior is short interest.
  It is gated on the data existing.
- Because the first option closes a programme, `model-routing.md` calls for a second, blind analyst read before the
  decision is recorded.
- Record the why in the ledger and in `project_shorts_liveness_dead` either way. Breakdowns do not out-fall the index,
  the book's market timing selects the rebound, and the stop converts a coin flip into a loss.

## 10. Dividends (amendment 1): should we avoid shorting dividend payers?

**No, on this evidence.** The splits are descriptive and cannot trigger anything.

| | n | O2 median | O2 beat | O2 mean | O1 +120 median | O1 +120 beat | O1 +120 mean |
|---|---:|---:|---:|---:|---:|---:|---:|
| payers (trailing yield > 0) | 24,541 | −2.68 % | 34.2 % | −0.12 % | +0.69 % | 51.6 % | −0.06 % |
| non-payers | 21,058 | −3.53 % | 34.2 % | −2.63 % | +2.95 % | 54.5 % | −5.86 % |
| yield < 2 % | 10,289 | −2.87 % | 33.1 % | −0.12 % | +0.81 % | 51.7 % | −0.15 % |
| yield 2–5 % | 9,496 | −2.56 % | 34.1 % | −0.23 % | +0.50 % | 51.3 % | +0.05 % |
| yield > 5 % | 4,756 | −2.52 % | 36.7 % | +0.12 % | +0.91 % | 52.1 % | −0.09 % |
| a ≥ 3 % dividend inside the +120-bar window | 1,136 | −2.59 % | 38.1 % | +0.53 % | +3.06 % | 56.7 % | +1.33 % |
| no such dividend | 44,463 | −3.03 % | 34.1 % | −1.33 % | +1.43 % | 52.9 % | −2.85 % |

The yield and dividend rows on O2 are from `summary-floor5.txt`. The combined payer row and every O1 +120 column are
from `analysis.txt` §dividends. E1 entry, all events.

- **On the rule's outcome (O2)** the beat rate is identical, and payers have the better median and mean.
- **Without a stop (O1 +120),** which pays every dividend in the window, non-payers have the better median and beat.
  - The gap is mostly 2000–12: payers 45.9 % against non-payers 51.9 %. In 2013–25 it is 56.0 % against 57.7 %.
  - Non-payers' mean is much worse (−5.86 % vs −0.06 %), which is the squeeze tail.
- **Corrected after the second read: the large-dividend row is look-ahead biased (defect 8).** `events.awk` compares
  each ex-date amount with the raw close the day before the ex-date, which falls inside the hold. A stock that falls
  turns an ordinary quarterly into a "≥ 3 %" dividend. 174 of the 1,136 flagged events qualify only because the price
  fell, and they read beat 72.4 % and mean +14.0 %. Specimen: TGH 2008-09-26. A $0.23 quarterly was 1.33 % of the
  $17.25 decision-time close; it was flagged after the stock fell to $5.45, for an excess of +23.3 %.
  - Measured at decision time instead (dividend ≥ 3 % of the breakdown-week close), the 962 such events do slightly
    worse: beat 31.9 % and mean −1.92 %, against 34.1 % and −1.33 %.
  - The favourable rows above (beat 38.1 %, and the per-half O1 figures) are therefore not evidence that big dividends
    help a short. This blind-read figure is not in a committed script; it is recorded in
    `results/analysis/blind-read.md`.
- **In P1,** payers and non-payers are the same: O2 beat 30.1 % vs 29.0 %, O1 +120 beat 47.2 % vs 47.0 %.

The AD 2025-08-20 special that prompted the question is a real cost when it lands, and the adjusted closes charge it.
In aggregate, it does not make payers worse shorts. (AD's 2025-05-23 event was stopped after 24 bars, before that
ex-date.)

**The book.** Chapter 7 (Selling Short) does not discuss dividends. I checked the local text on 2026-10-12, including
spaced OCR variants. Chapter 6 treats a high-yield Stage-4 stock as "any other Stage 4 loser": "if you get a 10
percent yield but lose 20 percent because of price depreciation, that's not winning mathematics." It also notes that
the falling company "may not even have the ability to pay future dividends at all". That fits the data: a yield does
not protect a broken stock, and payers are no worse to short.

## 11. Caveats

- **The classifier defines the event.** Our Stage 3 is short and fragmented (§5.3), so "the top" here is the last few
  weeks before the transition. The map measures the book's setup as our classifier sees it, faithfully to the
  pre-registration. A chartist's top would be wider (§9, item 2).
- **A relative benchmark.** The excess is against an SPY short over the same dates. In V-rebounds a losing short can
  beat it, and in bull tapes a flat stock can. Absolute returns are reported beside it.
- **No costs and no trail** (§4).
- **Data.**
  - Vendor splices, one uncredited distribution (BCE), a raw-price sentinel (AKR) and foreign-currency listings affect
    the means (§12). They do not affect the medians or beat rates.
  - Neither P1 nor P2 holds a vendor splice. P1 holds one uncredited distribution (BCE 2000-06-02) and one sentinel
    event (AKR 2004-05-14). Both are losers, so dropping them moves P1's beat rate by about 0.01 pp.
- **Multiple comparisons.** 64 descriptive cells at each floor were looked at, plus the analyst's own splits in §5, and
  none clears the bar. Any cell that looks good by eye here is a multiple-comparison survivor until a pre-registration
  says otherwise. One example: breakdowns too young for a 52-week RS (`rs=na`, n = 515) read 60.4 % without a stop at
  +120 bars, but 38.3 % on the rule's outcome (`analysis.txt` §checklist; `summary-floor5.txt`).

## 12. Defects found

1. **AKR raw prices** (`data/A/R/AKR/data.csv`).
   - The open, high, low and close columns are the sentinel `999999.9999` on every row through 2007 (e.g.
     2005-01-03), and on some rows in 2008–10. Elsewhere in 2008–13 they run at about 5,000× the adjusted close (e.g.
     2011-10-14: raw close 55,264.404, adjusted 10.9468). The adjusted close is fine.
   - Here it gives 3 events (2004-05-14, 2007-07-27, 2008-01-25; the first in P1) a breakdown close that passes any
     price floor, a dividend yield of about 0, and a close-only intraday high.
   - 43 other event symbols carry sentinel rows, some inside the window: LJPC has 3,239 rows in 1994–2008, MGDDY 312
     in 2008–10, and PEGX 10 in 2024–25. None falls inside one of that symbol's own event windows, so only AKR's
     three events are affected.
   - Any reader of the raw close is exposed: price floors, dollar volume and yields. The simulator's raw-close paths
     are worth a check.
2. **BCE 2000-05-09: an uncredited distribution** (`data/B/E/BCE/data.csv`).
   - The raw close goes 103.10 → 23.41, and the adjusted close 28.78 → 6.53 (the Nortel distribution). The adjusted
     series does not credit it.
   - The classifier reads it as a top and a breakdown, and the event lands in P1 (it is P1's 5th-percentile loser) with
     a 399 % stop room and a 443 % "advance".
   - This is the #3215 class (spin-offs uncredited).
3. **Vendor splices in the population tail** (the #3239 class). Examples: BELM 2005-10-28 (O2 excess −47,833 %), SRX
   2007-01-05 (−4,659 %), CGRN 2001-06-29 (−3,621 %), CCBL 2007-08-24 (−1,869 %), PUB 2014-04-25 (−1,597 %) and
   KARO_old 2020-12-18 (−1,103 %). None is in P1 or P2.
4. **Foreign-currency listings** (Phase B defect 4, already known). CELSIA, HSBA, SBER, PLZL, NVTK, BOUBYAN and ROSG,
   among others, produce events measured against SPY. Most have no sector, so they fall outside P1 and P2.
5. **The sector file is survivor-only.** `data/sectors.csv` covers 3,682 of the 9,279 list members. 0.9 % of
   sector-covered events are delisted symbols, against 91.2 % of the rest. Any "group" read built on it is a survivor
   read (§5.8).
6. **Definitional, not code.**
   - (a) 48.1 % of Stage 3 → 4 events never close below the broken support, which inflates E2's pullback share (§5.4).
   - (b) Entries already at or above their own stop are booked as next-open covers. The pre-registration is silent,
     and the book would not enter.
   - (c) `advance` takes its 2-year low through the breakdown week, which is what produces BCE's spurious 443 %.
   - (d) `top_width` is the classifier's last contiguous Stage-3 run, not the top (CSCO 2000).
7. **`scripts/analyze.awk` has a fragile sort.** Its quicksort uses a 2-way partition. It is correct on these
   continuous outcomes, but it overflows macOS awk's stack on large tied arrays: it crashed when the analyst reused it
   on 45,599 integer hold lengths. No committed number is affected. `results/analysis/lib.awk` uses a 3-way partition.

8. **`bigdiv` look-ahead (`scripts/events.awk`, the large-dividend block).** Found by the second read; the first
   read missed it. The 3 % test divides by the raw close the day before each ex-date inside the hold, not by the
   decision-time close. Specimen: TGH 2008-09-26 (§10). It affects only the descriptive `bigdiv_in_hold` split, which
   cannot trigger anything. It is not fixed in this PR; the split is reported as biased.
9. **The prior-advance low can come after the Stage-3 high** (3.8 % of events, 5.8 % of P1). This includes the
   2020-03-20 cohort (MHO room 213 %, GTLS 245 %), which supplies 5 of P1's 6 worst events. Without them, P1's beat
   rate is 28.9 %. This is the same root as 6(c).

**Script verification:**
- The 21 traced events reproduce all 450 committed fields compared, with 0 mismatches (§6).
- The second read re-derived 5 seeded random P1 events independently and matched every field to 5 decimals. It also
  matched the E1 O2 excess for all 45,599 events (0 mismatches above 1e-4).
- RS, the SPY phase and `group_rel` agree on the spot checks.
- The headline numbers reproduce from `results/events/*.csv` with independent code.

Apart from defect 8, nothing in `scripts/` was found wrong.

## 13. Second, independent read (blind)

`model-routing.md` asks for a second read when a verdict closes a programme. A second results-analyst read the
pre-registration and the raw artifacts without access to this README or to `results/analysis/`. Its memo is
`results/analysis/blind-read.md`.

- **Agrees:**
  - no edge in P1 or P2; it recomputed both cells to the digit;
  - a no-build decision: high confidence as measured, medium as "the book's setup";
  - close single-name shorts as a strategy track (medium-high confidence);
  - do not exclude dividend payers (medium-high confidence).
- **Adds:**
  - **Every checklist item, given the others, selects worse shorts.** On O1 +60, leaving one item out raises P1's beat
    rate by 3.6 pp (market), 3.0 (group), 1.2 (RS) and 0.4 (advance).
  - **Over P1's holds, SPY rose 6.3 % on average.** Only 18.6 % of P1 shorts made money in absolute terms.
  - **E2 phantom entries:** 12.8 % of P2 sit at or above their own stop. Without them, P2's beat rate is 28.8 %.
  - **True support breaks only** (n = 2,351): O1 +60 beat 44.6 %, which is no better.
  - Defects 8 and 9 above.
- **Differs:**
  - on the large-dividend split (defect 8); §10 and the brief are corrected to follow the second read;
  - **on what remains to test.** The first read names short interest, which is data-blocked. The second read also names
    one cheap, separately pre-registered **top screen**. It would define the top as the late-Stage-2 plus Stage-3 span,
    using the `late` flag, put the stop above the right-shoulder peak, and read O1 +60 first. Its stop rule: close if the
    beat rate is below 55 % or the median is 0 or below. It expects that screen to fail: there is no O1 gradient by top
    width (51.9 / 50.4 / 51.3 / 51.2 %), and the market-phase headwind remains.

## Reproduce

From the repo root; host only:

```sh
sh dev/experiments/short-setup-map-2026-10-12/scripts/run.sh            # the committed result (stage replay already in .sweep-output)
sh dev/experiments/short-setup-map-2026-10-12/results/analysis/run_all.sh   # this reading's tables and traces (~10-40 min, host load)
```

`run_all.sh` needs the stage replays in `.sweep-output/short-setup-map/stages/`, the host bars in `data/`, and SPY's
weekly stage from `dev/experiments/index-hedge-screen-2026-10-12/results/spy-weekly-stage.csv`. It writes scratch files
to `.sweep-output/short-setup-map/analysis/`.

Verifies: none
