# Fresh-eyes forward pass: the reading (24 of 100 symbols)

**Pre-registration:** `dev/plans/fresh-eyes-weinstein-2026-10-13.md` §5–6, merged at `573087e8d` (#3298). The file has
not changed since. The step-2 amendments (adaptive look, a fresh reader per checkpoint, reader isolation) are in this
experiment's README, committed in `22010c4c1` (#3306) before the run began. The rules are applied as written. Where a
rule cannot be applied, the section says so and why.

**Run:** `scripts/forward.sh`, Opus 5.5 driving, no shadow. `.sweep-output/fresh-eyes/forward.log` records
`HEAD=5f86d1af6` and a start of 2026-10-14 05:16Z; the run scripts are unchanged at the tip. It stopped on the weekly
plan limit.
- 24 of 100 symbols finished: all 20 of the 2000–04 stratum, plus VOLC, ZEP, AED2 and PRXIQ.
- 8 stopped part-way (ELSE, GRC, INO, LRN, NWE, PZG1, SIR, WMGI), 28 started but never got an answer, 40 never started.
- This is the final dataset. No more model calls.

**Artifacts** (`results/forward/`, the 24 finished symbols unless noted):
- `decisions.csv`: 4,621 checkpoints (reader stage, action, levels, one-line reason).
- `trades.csv`: 157 trades. `calls.csv`: 5,337 calls (the 8 partial symbols included). `pauses.csv`.
- `compare-stages.txt` and `compare-trades.txt`, from `scripts/compare.sh`.
- Our weekly stages: `.sweep-output/short-setup-map/stages/<SYM>.csv`. These come from the `stage_chart.exe` default
  classifier (the short-setup-map replay) and are not committed.
- The analyst's re-derivations (§Reproduce) also read the run's weekly series and chart pages under
  `.sweep-output/fresh-eyes/forward/`. Numbers from them are marked *(re-derived)*.

**Universe:** the PIT top-3000 pool, which is broad. **Review pack:** none. This is not a portfolio backtest, so the
traced cases' chart pages were read instead (§Chart pages read). **Validator gate** (`mechanism-validation-rigor.md`
check 8) does not apply, because there are no paired arms.

Verifies: none

## In brief

- **Stages: our classifier and the reader agree on 65.9 % of 4,454 matched checkpoints** (`compare-stages.txt`).
  - Joining holiday weeks by week gives 66.0 % on 4,595 *(re-derived; §8, defect 1)*.
  - The pre-registered self-consistency run (10 symbols twice) did not happen.
  - The nearest proxy is the reader against itself: Opus in pilot 2 vs Opus here, on the 112 checkpoints where both
    looked at IMPM and VOLC on the same Friday. It gave the same stage on 108 (96 %). On those same cuts it agreed
    with our classifier on 81 (72 %). So the gap is systematic, not reader noise.
- **The disagreement is about when a trend stage starts.**
  - Our classifier puts 85.5 % of checkpoints in Stage 2 or 4. The reader puts 63.7 % there.
  - Two cells hold 56 % of all disagreement: reader Stage 1 / ours Stage 2 (457 cuts) and reader Stage 3 / ours
    Stage 4 (398).
  - When the reader moved from Stage 1 to 2, our classifier was already in Stage 2 at the reader's previous look 82 %
    of the time. For Stage 3 to 4 the figure is 62 % *(re-derived)*.
- **Why: two ingredients, both visible in the code and the rule card.**
  - *The MA.* Ours is a 30-week WMA, called rising or declining at ±0.5 % over 4 weeks. The chart shows the book's
    simple 30-week MA, and the card calls anything within ±1 % over 4–6 weeks flat.
  - *The range break.* The card, and our own `weinstein-book-reference.md` §1, start Stage 2 at the breakout above
    the base top and Stage 4 at the break of support. Our classifier uses only the MA slope and price against the MA.
  - In a replica of our classifier, swapping in either ingredient lifts agreement from 66.4 % to 70.8 % (the MA) or
    72.9 % (the range break). Both together give 75.4 % (70–75 % across range proxies) *(re-derived)*.
- **By the rule card, the reader is right in all six traced cases.** Our Stage 2 or 4 starts at the MA turn, weeks
  before the break the card requires.
  - About half the time the reader agrees at a later look.
  - About a third of the time our call reverts. These are false starts and false breakdowns inside one range.
  - The class is a documented dial plus a definition gap, not a code bug.
- **The reader's trades show no edge.**
  - 125 longs. Excess vs SPY: mean +1.30 %, median −6.19 %, p10 / p25 / p75 / p90 = −18.4 / −12.2 / +5.3 / +23.7 %.
    Beat rate 30.4 %, t = 0.49.
  - The mean is one trade: VIAV, bought 2025-10-15 at 13.05 and still open at 47.63 (+254.8 % excess). Without it
    the mean is −0.74 %.
- **Shorts re-derive the setup-map no-build (#3286) from a different entry.**
  - The reader's 32 shorts entered at its own support breaks, a median 10 weeks after our Stage 4 began.
  - Excess: mean −1.46 %, median −5.87 %, beat 21.9 % (7 of 32). The setup map's 29.7 % lies inside this CI.
- **Our record took none of the 24 symbols, in any salt.**
  - 13 of the 24 names did reach the record's weekly top 20. Its own trade audit skipped every one of those
    appearances as `No_structural_stop` (84, 84 and 83 by salt), and none for cash.
  - VIAV was skipped three weeks running in August and September 2025, seven weeks before the reader's +255 % entry.
- **Leads, not verdicts (§5).**
  - Our Stage-2 clock starts at the MA turn, a median of about 8 weeks before the breakout the book buys. That is the
    gap the existing `Range_top_breakout` axis was built for.
  - VIAV 2025 is one specimen of the known `No_structural_stop` gap.
  - Nothing here licenses a promotion, a rejection or a faithfulness verdict.
- **Cost:** 5,337 calls and $429.52 at list price ($0.0805 a call). 87 % answered `none`. Every call was a single
  turn, so the reader never opened the book. That is $0.94 per stock-year, computed on one consistent population.
- **Defects found:**
  - TXI 2005-08-01: an uncredited spin-off stopped the reader out at −22.8 %.
  - SYNC: a ticker splice with a 6-year gap (24 calls on a dead chart).
  - PRXIQ 2019–26: a sub-penny stub (31 calls).
  - AKTX 2013–14: a pre-merger shell stub.
  - `compare.sh` drops 141 holiday-week checkpoints.

## 1. The pre-registered rules, as written

### 1.1 Stages (plan §5, bullet 1)

> The agent's stage segments vs our classifier's weekly stages, as a confusion matrix and agreement by year.

The forward reader gives one stage per checkpoint, so the comparison is per checkpoint (`compare-stages.txt`):

| reader \ ours | 1 | 2 | 3 | 4 | reader total |
|---|---:|---:|---:|---:|---:|
| 1 | 110 | **457** | 79 | 113 | 759 |
| 2 | 19 | 1,647 | 74 | 11 | 1,751 |
| 3 | 131 | 157 | 174 | **398** | 860 |
| 4 | 43 | 22 | 15 | 1,004 | 1,084 |
| ours total | 303 | 2,283 | 342 | 1,526 | 4,454 |

- **Agreement is 65.9 %** (2,935 of 4,454). 167 checkpoints had no stage row (§8, defect 1).
- **By year it runs from 56.6 % to 77.6 %.**
  - The lowest years are 2009 (56.6 %), 2011 (57.9 %), 2018 (59.3 %), 2012 (60.0 %) and 2024 (60.2 %). The highest
    are 2007 (77.6 %) and 2017 (75.9 %).
  - The reader-1 / ours-2 cell peaks in rebound years: 2009 (56 cuts), 2012 (45), 2003 (39) and 2024 (27). The
    reader-3 / ours-4 cell peaks in topping and correction years: 2011 (38), 2005 (33) and 2000–01 (54)
    *(re-derived)*.

### 1.2 Trades (plan §5, bullet 2)

> The agent's forward trades vs our record run's trades on the same 100 symbols, matched by symbol and overlap of
> holding period: both took it / only the agent / only ours, for longs and shorts. P&L per class.

- **The record run** is `dev/experiments/breadth-fix-rb1-2026-10-11` N-rb1-26, salts 0–2 (570, 575 and 568 trades).
  It traded none of the 24 symbols in any salt. It also held none of them at the end (`*-open_positions.csv`).
- **So "both" = 0, "only ours" = 0, and "only the agent" = 157** (125 long, 32 short).
- **"Only the agent" P&L** is the reader's P&L (`compare-trades.txt`):
  - longs: mean return +6.66 %, mean excess +1.30 %, beat 30.4 %;
  - shorts: mean return −0.08 %, mean excess −1.46 %, beat 21.9 %.
- **The class split is degenerate, so no trade-level comparison is made.**
  - `compare.sh` instead reports our stage at each reader entry: 121 of 125 longs entered in our Stage 2, and all 32
    shorts in our Stage 4.
  - §3.7 reads why the record took none, from its own audit.

### 1.3 Every disagreement gets a class (plan §5, bullet 3)

The classes are in the table in §3.5, and the traced samples are in §3.3–3.4.

### 1.4 Self-consistency (plan §4): not run, so the rule cannot be applied as written

The plan asks for 10 symbols run twice, "before any comparison (the blind-judge rule: code-vs-agent is
uninterpretable until agent-vs-agent is known)". `forward.sh` ran no rerun and no shadow. Two proxies exist:

| pair | checkpoints | same stage | source |
|---|---:|---:|---|
| Opus vs Opus: pilot 2 vs this run, IMPM and VOLC, same Friday | 112 | 108 (96.4 %) | `results/pilot2/{IMPM,VOLC}/decisions.csv` vs `decisions.csv` *(re-derived)* |
| reader vs ours on those same 112 cuts | 112 | 81 (72.3 %) | *(re-derived)* |
| Opus vs Sonnet, same message, 5 symbols | 490 | 370 (75.5 %) | `results/pilot2/agreement.txt` |

- The Opus pair shares the prompt text, the chart code and, per the experiment README, the rule card. Between the two
  builds only two things changed: reader isolation (an empty working folder, a book-only `--add-dir` and the book path
  in the prompt) and the stepper's 8-week-cancel order.
- The matched cuts span 2000–2015 (IMPM) and 2007–2014 (VOLC). But they are only the cuts where both runs happened to
  look on the same Friday, and there are two symbols.
- What they support: the reader's stage call is stable for a given chart, so the 34 % code-vs-reader gap is mostly
  systematic. What they cannot replace is the planned measurement of trades and levels. Pilot 2 already showed that
  order placements are where readers diverge.

### 1.5 What it may conclude (plan §6)

1. **"Our classifier and a book reader disagree on X % of weeks, mostly in situation Y."**
   - X = 34.1 % of the reader's checkpoints.
   - Y = the start of a trend stage. Price sits above (or below) a turning 30-week WMA but is still inside the base (or
     top) range. The reader waits for the range to break and reads the book's slower, simple MA.
   - The traced cases are in §3.3–3.4.
2. **"The book reader takes trades of kind Z that our gates exclude (or the reverse), with their P&L as a lead."**
   - Z = breakouts that come late in our classifier's Stage 2 (98 of 122 fills), names below our liquidity floor (20 of
     125), and names our record surfaced and then skipped for `No_structural_stop` (VIAV 2025).
   - P&L shows no edge, and what it has is carried by the tail (§3.7).
3. **Not concluded:** a promote or reject on any flag, or "our system is (un)faithful".

Steps not run: layer (i), the hindsight read; the 76 unfinished symbols; and the self-consistency step above.

## 2. The reading, calibrated

This is a screen that produces leads (plan header). On 24 symbols from the oldest listing stratum it supports:

- **A descriptive, mechanism-level statement about the classifier.** Its Stage 2 and Stage 4 begin at an MA-slope
  turn. The rule card, the reader and our own reference start them at a range break. The two big disagreement cells
  follow from that and from the MA dial. This holds across the zone proxies tested (§3.2) and across symbols: no
  symbol carries more than 12 % of either cell.
- **A no-edge reading of the reader's own trades.** Per trade, at unit capital, long and short, the result is
  indistinguishable from zero. The long mean rests on one position that is still open.

It cannot claim:
- that either stage reading earns more;
- anything about names first listed after 2009 (none finished);
- a trade-level comparison with our system (the record took none of these names);
- that "our classifier is unfaithful". The MA type and slope band are documented dials. The missing range-break
  requirement is an undocumented simplification (§5, option 4). The screener checks the breakout separately.

## 3. Why

### 3.1 The classifier labels trends, the reader labels ranges

| | Stage 1 | Stage 2 | Stage 3 | Stage 4 | in 2 or 4 |
|---|---:|---:|---:|---:|---:|
| reader, share of checkpoints | 17.0 % | 39.3 % | 19.3 % | 24.3 % | 63.7 % |
| ours, share of checkpoints | 6.8 % | 51.3 % | 7.7 % | 34.3 % | 85.5 % |
| reader, mean run (weeks) | 12.3 | 26.9 | 10.5 | 24.8 | |
| ours, mean run, sampled at the reader's cuts | 6.2 | 22.8 | 5.6 | 21.5 | |

- **Sources.** The shares come from `compare-stages.txt`. The runs are *(re-derived)* on the 4,595 week-joined cuts.
  Both rows of runs are measured between checkpoints, so neither can be shorter than the look interval.
- **Transitions.** Between consecutive checkpoints the reader changed stage 1,115 times and ours 1,264. Ours entered
  Stage 2 in 423 separate runs against the reader's 271. That gap is the false starts.
- **Lead.** When the reader moved 1→2 (127 times), our classifier was already in Stage 2 at the reader's last Stage-1
  look in 104 (82 %). Our run had begun a median 8 weeks before the reader's first Stage-2 cut (p25 5, p75 13). That
  figure includes the reader's look interval, usually 4 weeks.
- **Same for 3→4** (154 times): already in Stage 4 in 96 (62 %), a median 5 weeks earlier (p25 2, p75 12)
  *(re-derived)*.
- **This reconciles with the setup map's "the classifier calls Stage 4 late".** At our 274 Stage 3→4 transitions on
  these 24 symbols:
  - the close was a median 20.3 % below its prior 52-week closing high, which is late against the peak;
  - but 75.5 % of them were still above the prior 26-week closing low, which is early against the support;
  - 48.9 % were above the prior 10-week low, matching the setup map's 48.1 % *(re-derived)*.

### 3.2 The two ingredients, measured by perturbation

`reclass.awk` re-implements our `Stage.classify` default config (30-week WMA, ±0.5 % over 4 weeks, 6-week price
count, prior-stage rules) on the chart's weekly closes. It reproduces 98.2 % of our 20,768 weekly stage rows for
2000–2026; the misses are near-threshold flips *(re-derived)*. Each variant changes one ingredient:

| variant | agreement with the reader | reader 1 / ours 2 | reader 3 / ours 4 |
|---|---:|---:|---:|
| v0: replica of ours | 66.4 % | 468 | 408 |
| v1: the chart's SMA, ±0.5 % / 4 wk | 68.1 % | | |
| v2: SMA, ±1 % / 5 wk (the card's reading) | 70.8 % | 258 | 168 |
| v4: ours + range break | 72.9 % | 309 | 253 |
| v3: v2 + range break | 75.4 % | 147 | 84 |

- **The range-break proxy.** Entering Stage 2 needs a close above the prior 26-week closing high. Entering Stage 4
  from Stage 2 or 3 needs a close below the prior 26-week closing low.
- **Perturbed over 8, 13, 26 and 52 weeks, on closes and on highs and lows:**
  - v3 ranges 70.2–75.4 % (reader 1 / ours 2: 88–176; reader 3 / ours 4: 31–113);
  - v4 ranges 69.1–76.7 %.
  - The direction holds across every proxy. The exact gain depends on how the base top is drawn.
- **Each ingredient alone removes 34–59 % of a cell, and both together remove 69–79 %.** The residual 25 %
  disagreement of v3 is about the Opus-vs-Sonnet level from pilot 2.
- **The cell features agree** *(re-derived)*.
  - In reader 1 / ours 2 (469 cuts), the chart's SMA was still declining on 21 % and flat on 35 % by the card's ±1 % /
    5-week reading. Our WMA was rising on 99 %. The close was below its prior 26-week high on 92 %.
  - In reader 3 / ours 4 (410), the SMA was flat on 51 % and rising on 18 %, and the close was above the prior 26-week
    low on 96 %.
  - The reasons say the same thing in words: "no breakout yet above the ~7.5 base top", "a 30-week MA that is still
    declining", "support near 80–84 still intact".

**How the episodes end** *(re-derived)*:
- Reader 1 / ours 2:
  - 223 of 469 cuts are in episodes the reader later joined (rd2/o2), so our call was early;
  - 148 are in episodes where our Stage 2 reverted while the reader still saw a base (51 episodes to Stage 3, 22 to
    Stage 4, 5 to Stage 1).
- Reader 3 / ours 4:
  - 181 of 410 cuts are in episodes the reader later joined;
  - 108 end with ours going to Stage 1 and 38 with ours back in Stage 2, which are false breakdowns.

### 3.3 Traces: reader Stage 1, ours Stage 2

Prices are on the chart's scale unless marked "adj". The stage rows come from `stages/<SYM>.csv`.

**(a) PVN 2002-12 to 2003-05. Our Stage 2 began five months before the breakout the reader bought.**
- **What happened:**
  - After the 2001 collapse, PVN based between 2.5 and 8.5 for 18 months.
  - Our classifier went straight from Stage 4 to Stage 2 on 2002-12-06. A rally from 4.28 to 6.30 in five weeks
    (+47 %) turned the WMA up (+1.4 % over 4 weeks). The chart's SMA was still falling 5.7 % over 5 weeks.
  - From 2002-12-13 to 2003-04-04 the reader read "a Stage 1 base … the base top near 8.4 has not been cleared … the
    S&P is below its declining MA".
  - On 2003-05-02 it placed a buy-stop at 8.62 above the 8.5 base top, stop 6.88 under the 7 support. That is about
    20 % risk, which the reason notes is above the card's guideline.
  - The order filled 2003-05-13. By then our Stage 2 was 25 weeks old.
- **Outcome:** held to PVN's last bar, 2005-09-30, when Washington Mutual acquired it, at 17.68. Return +105 %, excess
  +69.2 %.
- **By the card:** the reader is right. The 1→2 transition is the breakout above the base top while the MA is no
  longer declining. Our label read the WMA turn.
- **Consequence:** the breakout came in week 25 of our Stage 2, far outside the default 4-week MA-cross window. While
  that window was open, in December 2002, the macro gate was closed (the S&P was in Stage 4). PVN never appears in the
  record's audit.

**(b) HQH 2009-06 to 2010-01. The reader catches up at the breakout, and neither side trades.**
- Our Stage 2 began 2009-06-05, with the chart's SMA at −1.4 % over 5 weeks.
- Seven looks from 2009-06-19 to 2009-12-04 read the same way: a Stage 1 base under "the ~11.5 rally highs from
  Dec–Jan", RS negative and falling, heavy resistance at 12–15.
- The close broke above the base top in the week of 2009-12-25. The reader called Stage 2 on 2010-01-01, by which
  time our Stage 2 was 31 weeks old.
- It did not buy, because RS was below zero and the 13–15 resistance sat within 20 %. The stock rose about 11 % by
  April 2010 and faded.
- Page read: `HQH-2009-12-04-5y.png` shows a sideways base above a gently turning MA, under the 2006–08 range. The
  reasons match the page.

**(c) EXPO 2022-11 to 2023-03. A false start inside one 80–110 range.**
- **Context:** after its late-2021 peak near 120, EXPO spent 2022 and most of 2023 in an 80–110 range.
- **Our classifier:**
  - 2022-11-18: Stage 1 → 2, after +13.5 % in four weeks lifted the WMA (+1.5 % over 4 weeks; the SMA was −1.55 %);
  - held Stage 2 for 18 weeks;
  - then Stage 3 on 2023-03-24 and Stage 4 on 2023-04-28.
- **The reader:**
  - Stage 1 throughout: "a year-long Stage 1 base (about 82–108) … 2021 supply at 110–118 within 20 %";
  - on 2023-02-10: "the 105–111 attempt … reversed to a 105 close";
  - the range never broke upward.
- **By the card:** the reader is right, since a Stage 2 needs a breakout above the range top.
- **Repeat:** the same thing happened on 2024-01-12, when a 3-week Stage 2 of ours on a V-rebound ("back above a
  30-week MA that is still falling", the SMA at −1.1 %) ended in the February 2024 gap down.
- **Book ambiguous:** over 2022–23 the reader itself labelled this range Stage 3, 4, 3, 1 and then 3, across fresh
  contexts. Whether a range after a ~33 % fall from a Stage-2 peak is a base or a top is not settled.

### 3.4 Traces: reader Stage 3, ours Stage 4

**(a) EXPO 2023-04 to 2023-11. Early by 26 weeks, and right about the direction.**
- Our Stage 4 began 2023-04-28 at 87.9 adj. The WMA was at −0.53 % over 4 weeks; the chart's SMA was still rising
  1.2 % over 5 weeks.
- From 2023-05-05 to 2023-10-20 the reader read "a Stage 3 top … support near 80–84 still intact".
- Support broke on 2023-10-27, when a week's low hit 62 and the close was 69.9 adj (−15.5 % on 2.2× volume). The
  reader called Stage 4 at its next look, 2023-11-17.
- In the 26 weeks between, the price drifted −6 % (87.9 to 82.6 adj).
- By the card the reader is right: a Stage 3 still above major support is not yet Stage 4 (card §1, quiz 11). Our
  call came early and the direction was correct.

**(b) ZEP 2010-04 to 2010-11. A false breakdown driven by the WMA.**
- **What happened:**
  - On 2010-04-09 a one-week gap took ZEP from 22.65 to 17.55 (−22.5 %, 4.1× volume), after its January breakout to
    23.
  - Our classifier went to Stage 3 on 2010-04-23 and to Stage 4 on 2010-04-30, and stayed in Stage 4 for 27 weeks.
    The WMA ran −1.0 % to −3.2 % over 4 weeks.
  - The chart's SMA ran +0.04 % to +2.5 % over 5 weeks until early August. The WMA weights the post-gap weeks, while
    the SMA still held the pre-gap highs.
  - The reader called Stage 3 throughout: "below a flat 30-week MA … the ~16 support has not broken".
- **Outcome:** the price went from 18.25 on 2010-05-07 to 18.11 on 2010-10-22. The range held, with lows near 16 (one
  intraday low of 15.83) and highs near 20.6. Our classifier then went 1 → 2 (2010-11-12) → 3 → 4 (2011-02-04).
- **By the card:** the reader is right. The cause is the MA dial plus the missing support-break requirement.
- **Page read:** `ZEP-2010-07-02-5y.png` shows a flat SMA at about 19.7 over a 16.5–19 range. It matches the reasons.

**(c) PVN 2001. Our classifier fragments a top, and the reader shorts the real break.**
- **Our classifier:** PVN traded 40–65 from December 2000 to August 2001. Inside that one range our classifier ran
  4 → 1 → 2 (2001-01-19) → 3 → 4 (2001-03-23 to 04-27) → 1 → 2 (2001-05-18 to 07-20) → 3 → 4 (2001-08-10).
  That is two Stage-4 calls; after the first, at 43.9, the stock rallied to 61.
- **The reader:** read one "choppy Stage 3 top above ~40 support" at every look. On 2001-08-17 it placed a short-stop
  at 39.40 under "the much-tested ~40 support", with a buy-stop at 42.12, and the order filled 2001-08-29 at 39.37.
- **Outcome:**
  - PVN collapsed (25.7 on 09-07, 5.15 on 10-19, 2.59 on 11-02).
  - The reader lowered its buy-stop to 8.12 on the 2001-10-26 climax and to 5.12 on 2001-11-23.
  - It was covered at 5.12 on 2002-03-06: return +87.0 %, excess +87.4 % against the SPY short. This is the reader's
    best short.
- **By the card:** the reader is right. Page read: `PVN-2001-08-17-5y.png` shows a rolling-over MA at 52.2, the close
  at 45.1 just above the 40 floor, and RS just below zero.

### 3.5 The disagreement classes (plan §5)

| class | where it shows | evidence | specimens |
|---|---|---|---|
| documented dial | MA type: WMA, where the book defines a simple MA and reads Mansfield's weighted one (card §0). Slope band: ±0.5 % / 4 wk; the book gives no number and the card uses ±1 % / 4–6 wk. Both are `Stage.config` fields with stated rationale | swapping in the chart's SMA ±1 % / 5 wk alone: 468 → 258 and 408 → 168 (§3.2) | ZEP 2010; HQH 2009; EXPO 2024-01 |
| our code reads the stage differently from the book's definition | Stage 2 starts at the MA turn, not at the breakout above the base top. Stage 4 starts at the MA turn, not at the support break (card §1 [E]; reference §1 Stage 2 and Stage 4 detail) | adding a range break alone: 468 → 309 and 408 → 253; both ingredients: 147 and 84 | PVN 2002–03; EXPO 2023; PVN 2001 |
| reader misreads, by its own card | the stage label is coloured by a buy veto. Stage 3 is called while the chart's SMA still rises above 1 % / 5 wk with price above it. Stage 1 is called under a declining SMA with price below, which card ambiguity 15 calls Stage 4 | small: about 34 of 163 reader-3 / ours-2 cuts and 25 of 116 reader-1 / ours-4 cuts *(re-derived)* | TXI 2001-05-25 ("coming out of a Stage 1 base on good volume", labelled 1); HQH 2000-04-28 |
| book ambiguous | Stage 1 vs 3 for a range after a top and a decline; the width of the MA's flat band | the reader relabelled EXPO's 2022–23 range 3/4/3/1/3 | EXPO 2022–23 |
| data defect | shell and post-bankruptcy stubs; an uncredited spin-off; a ticker splice | 37 checkpoints fall in stub periods, and excluding them gives 66.2 %. One trade (TXI) is affected | AKTX 2013–14; PRXIQ 2019–26; TXI 2005-08; SYNC 2006–12 (§8) |

Our classifier's stage feeds the entry admission clock (`early_stage2_max_weeks`, default 4) and the stop state
machine (`Weinstein_stops.update ~stage`). So the definition gap matters through those consumers. It does not cause
pre-breakout buys, because the screener checks the breakout separately.

### 3.6 The reader's trades: the distribution, and what carries the long mean

Excess vs SPY (long) or vs an SPY short (short), at unit capital per trade (`trades.csv`; the distributions are
*(re-derived)* from it):

| side | n | mean | median | p10 | p25 | p75 | p90 | beat | SD | t | mean hold |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| long | 125 | +1.30 % | −6.19 % | −18.37 % | −12.18 % | +5.27 % | +23.69 % | 30.4 % | 30.0 % | 0.49 | 207 d |
| short | 32 | −1.46 % | −5.87 % | −13.03 % | −10.99 % | −0.92 % | +17.77 % | 21.9 % | 19.6 % | −0.42 | 92 d |

**Scale.**
- Longs held 70.9 position-years in total. Their excess is +2.3 % per position-year, or −1.3 % without VIAV 2025.
- Shorts held 8.1 position-years, at −5.8 % per position-year.
- Economically small, and statistically zero.

**What carries the long mean.**
- **The top five trades** (VIAV 2025 +254.8 %, PRXIQ 2006 +84.8 %, EXPO 2006 +72.9 %, PVN 2003 +69.2 %, EZCH 2006
  +54.2 %) add +535.8 pp. The other 120 add −372.9 pp, a mean of −3.11 %.
- **Dropping the top 1, 2 or 5** gives a mean of −0.74 %, −1.44 % or −3.11 %. The p5/p95-winsorized mean is −1.11 %.
  Realized trades only (118, excluding the 7 marked at a last bar) give a mean of −1.72 % and a median of −7.07 %.
- **Exits:** 115 of 125 longs ended at their stop. The p10/p25 tail of −18 % / −12 % is the stop losses at the card's
  10–17 % risk.
- **The halves disagree in sign.** Entries in 2000–09 (n = 55) average +5.78 % (beat 40.0 %). Entries in 2010–26
  (n = 70) average −2.22 % (beat 22.9 %), or −5.94 % without VIAV. SPY's flat decade made the hurdle low; its bull
  market made it high.
- **The position that carries the mean is still open:**
  - VIAV, bought 2025-10-15, was marked at 47.63 on 2026-06-26 with its stop at 41.88.
  - Of the 7 positions "open at end", 4 are marks at the symbol's last bar before it left the data (PVN, AED2, RTU,
    TXI 2014). Only VIAV, DX and HQH are still open at the data end.

**Trades traced end to end** (beyond the PVN long and short above):

- **VIAV, long, 2025-10-15.**
  - From June to August 2025 the reader read a Stage 3, then Stage 1, range of 8–13.
  - On 2025-09-12 it placed a buy-stop at 13.05 above "the early-2025 high near 12.9", stop 10.88 (about 17 % risk,
    graded B). Our Stage 2 had begun on 2025-08-22.
  - The order filled 2025-10-15; the next big week was +29 % on 3.3× volume (2025-10-31).
  - The reader raised its stop four times by the card's investor rule (12.38, 13.45, 14.88, 16.88). It then raised it
    to 29.88 when the S&P broke its MA in April 2026 (the market-gate rule), and to 41.88 on climax volume in May.
  - Marked at +265.0 %, against SPY's +10.2 %.
  - The record had VIAV in its weekly top 20 on 2025-08-22, 08-29 and 09-12, and skipped it each time as
    `No_structural_stop` (§3.7).
- **ZEP, long, 2010-02-16.** It bought a re-breakout at 21.51 after January's breakout above the 2008 highs, stop
  18.88 under the pullback low. The stop filled at 18.88 on 2010-04-08, in the week of the −22.5 % drop: return
  −12.2 %, excess −21.8 % (SPY +9.6 %). The stop worked as the book intends: the stock then went sideways for ten
  months.
- **TXI, long, 2005-07-25 at 71.10.** It was stopped at the 55.00 open on 2005-08-01: return −22.6 %, excess
  −22.8 %. The data show the 2005-07-29 close at 73.63 and the 2005-08-01 open at 55.00, with `adjusted_close = close`
  on both days. This is consistent with the Chaparral Steel spin-off at the end of July 2005, which the adjusted
  series does not credit (the #3215 class). The loss is a data artifact (§8, defect 3).

### 3.7 Trades our gates would not take (a lead, not a measurement)

**The stage clock.**
- At the fill week, 24 of the 122 long fills in our Stage 2 were inside the default MA-cross window (Stage 2, at most
  4 weeks old, not late). 96 were older and 2 were flagged late *(re-derived)*.
- 23 of the 96 filled at an all-time high on the stored series. These are candidates for the virgin-crossing arm,
  which is on in the strategy's `default_config`.
- **Caveat:** the record rests tickets at the suggested entry for up to 52 weeks. A ticket placed inside the window
  could fill later, so "stale at the fill" is not a measured exclusion.
- **P&L:**
  - stale fills (n = 98): mean +1.23 %, median −6.01 %, beat 28.6 %, or a mean of −0.90 % without VIAV;
  - fresh fills (n = 24): mean +1.87 %, median −6.79 %, beat 37.5 %.
  - No difference at this n.
- **The reader's own words:** 76 of 124 entry reasons use continuation words ("continuation", "consolidation", "new
  high"), and 29 mention a base. Continuation buys are a documented dial with a ledger history.

**Liquidity.** 20 of 125 fills had a 20-day average dollar volume below $1M (split-corrected), which is the record's
`min_entry_dollar_adv`. Their mean excess is +9.9 % (9 of 20 beat SPY). It is carried by three trades: PRXIQ 2006,
EXPO 2006 and EZCH 2006. The other 105 average −0.34 % *(re-derived)*.

**Why the record took none: its own audit** (`.sweep-output/breadth-pair-N/rb1-26-s{0,1,2}-v12-trade_audit.sexp`, not
committed; the same runs as the committed N-rb1-26 artifacts, whose `trades.csv` and `actual.sexp` are
byte-identical):
- **13 of the 24 names reached the weekly top 20.** The record's top-N list is 20 names, or 0 in a closed-gate week.
  - In s0, all 84 list entries for these names were skipped as `No_structural_stop`. They cover 53 symbol-weeks over
    52 weeks.
  - All 84 in s1 and all 83 in s2 were skipped the same way. Cash was never the reason for these names.
- **That reason dominates the whole audit.** Across s0, `No_structural_stop` is 20,177 of 20,849 skip outcomes
  (96.8 %), against 486 `Insufficient_cash`.
- **The reader often saw the same opportunity.** In 25 of the 53 symbol-weeks the reader was long the name (14) or
  bought it within 8 weeks (11).
- **So the usual explanation, a capital-bound top-N book, is only half the story.** The other 11 names never reached
  the top 20. For the 13 that did, the binding filter was the structural stop, not capital.

### 3.8 The shorts, read against the setup-map no-build (#3286)

- **The reader shorted mostly in bear tapes,** as its card asks (the S&P in Stage 4): 12 shorts in 2000–02, 8 in
  2008–09, 4 in 2011, 3 in 2022, and one each in 2003, 2004, 2007, 2018 and 2025. 27 of 32 hit their buy-stop. The
  median hold is 48 days.
- **The entries are a different event set from the setup map's.**
  - The setup map entered at our classifier's Stage 3→4 week.
  - The reader entered at its own support breaks, a median 10 weeks after our Stage 4 began (range 2–24; only 5 of 32
    within 4 weeks) *(re-derived)*.
- **They fail the same way.**
  - Beat 7 of 32 (21.9 %, 95 % CI about 8–36 %). Against P1's 29.7 %, P(≤ 7) = 0.22. Against a coin flip,
    P = 0.001.
  - Without PVN 2001 (+87.4 %) the mean is −4.33 %.
- **This matches what the setup map already found.**
  - 48.1 % of its 3→4 events never closed below support.
  - Restricting to true support breaks did not help (O2 beat 29.6 %).
  - Early Stage 4 is the worst market slice, because broken names rebound with the index.
- **The reader's book-timed shorts close the remaining door, "maybe the event definition was wrong", from a second
  direction.** The no-build stands, as does the 10-13 wide-top REJECT.

## 4. How it fits what we know

- **Confirms and refines** `project_rangetop_freshness_is_a_drawdown_lever` and `project_rt_needs_its_anchor_knob`.
  - A book reader's Stage 2 starts a median of about 8 weeks after our MA-cross clock (§3.1).
  - So a window measured from the MA turn ages before the breakout.
- **Refines** the `2026-07-06-early-stage2-window-surface` REJECT (widening the window to 6 or 8 weeks taxed bear
  folds).
  - That surface changed the window's *width*. This study points at its *anchor*: the MA turn against the range break.
  - Those are different levers, and the second already exists as `Range_top_breakout` (keep-as-axis, not
    promotable).
- **Confirms** the short track's closure:
  - `2026-10-13-short-setup-map` REJECT;
  - `2026-10-13-short-wide-top` REJECT;
  - `project_shorts_liveness_dead`.
- **Confirms** `project_edge_is_the_fat_tail`. A book-following trader with stops shows the same shape, many small
  stop losses and a few large winners. The long mean is one trade.
- **Confirms** `project_recovery_reentry_gap` ("No_structural_stop skips; far anchors in every year"), with a new
  specimen. In VIAV 2025 the record surfaced the name three weeks running and skipped it. A reader using a nearer
  reaction-low stop (about 17 % risk) caught a +265 % move. One trade, so a specimen, not evidence.
- **Consistent with** the continuation record: `2026-05-14-continuation-combined-axis` REJECT, and
  `2026-10-02-continuation-buys-trader-rerun`, which is "not promotable" per memory. The reader's mostly
  continuation-style entries show no edge.
- **Reconciles with** the setup map's "the classifier calls Stage 4 late" (§3.1). That is late against the peak and
  early against the support. Both hold.
- **Refines the "capital-bound top-N book" explanation** for the zero overlap. For the 13 names the record screened,
  capital was never the reason; the structural-stop requirement was (§3.7).

## 5. What it implies next (options; the choice is the user's)

1. **Stop here on the trade side.** The reader's trades show no edge, and they cannot be compared with our book. The
   stage question is answered well enough at this sample for a faithfulness note.
2. **Free follow-ups, with no model calls:**
   - **(a)** Add the 8 partial symbols' 716 checkpoints to the stage comparison. They are on disk under
     `.sweep-output/fresh-eyes/forward/runs/` and add 2005–09-stratum names (NWE, LRN, ELSE, GRC).
   - **(b)** Replay our screener (default config) on the 24 symbols, and for each reader fill record whether our system
     had an admissible candidate or a resting ticket. This turns the stage-clock lead into a measurement.
   - **(c)** Fix `compare.sh`'s week join (§8).
3. **A faithfulness pre-registration on the classifier's transitions.** Require a range break for 1→2 and 3→4, and
   test the SMA ±1 % reading.
   - Frame it as a faithfulness question first, not a return lever.
   - The related return levers did not promote: range-top freshness (keep-axis), the early-stage2 window (REJECT),
     and true support breaks for shorts (no better).
4. **A documentation decision.** State in `stage.mli`, or in the reference §1, that the classifier's Stage 2 and 4
   begin at the MA turn, before the book's range break, and that the screener checks the breakout separately. This
   changes the docs, not behaviour.
5. **If a reader run is ever resumed:**
   - The remaining 76 symbols are about 860 stock-years, roughly $800 at list price at $0.94 per stock-year. The
     self-consistency rerun adds about 10–15 %.
   - Add data guards first: skip data gaps longer than 26 weeks and sub-$0.01 closes, and flag uncredited
     distributions.
   - Only worth it if the stage question needs the younger strata.

## 6. Sample limits

- **24 of 100, and not the design's mix.** The run went in `sample.txt` order with 4 at a time, so the finished set is
  the first stratum plus 4 of the second.
  - 20 of 24 symbols were first listed in 2004 or earlier (16 of them already in the 1998–99 lists).
  - None comes from the 2010–14, 2015–19 or 2020–25 strata, so there are no recent IPOs, biotech shells, SPACs or
    post-2010 listings.
- **Longevity-weighted, not survivor-only.**
  - 13 of the 24 left the data before 2026 (AED2, DG1, DO_old, EZCH, FUR, HYSL, PVN, RTU, SDS1, SYNC, TXI, VOLC,
    ZEP), so the set is not survivor-only.
  - But checkpoints scale with history. 9 long-lived names (OMC, RMD, EXPO, HQH, DX, TDW, VIAV, DO_old, IMPM) supply
    2,891 of 4,621 checkpoints (63 %). The 11 names still trading in 2026 supply about 65 %.
  - The counts thin out over time: about 200 checkpoints a year in 2000–08, about 105 in 2023–25.
- **Not all ordinary operating companies.** HQH is a closed-end fund, DX a mortgage REIT, PRXIQ a post-bankruptcy
  stub from 2019, and AKTX a reverse-merger shell before 2014.
- **Not run:** layer (i), the hindsight read; the plan's self-consistency step; the remaining 76 symbols.
- **One reader per checkpoint, with no memory.** This is the README's departure from plan §4. The reader cannot carry
  a base count or a thesis between looks, which may make its stage calls noisier than one reader following a stock.
- **The reader is a rule-card reader.** All 5,337 calls were one model turn, so it never grepped the book. It decided
  from `results/rulecard.md` (the step-0 agent's paraphrase, with chapter cites) and the charts.
- **Trade n is small and heavy-tailed** (125 / 32). Every trade split above is a lead at best.

## 7. Cost

From `calls.csv` and `pauses.csv`:
- **Calls:** 5,337 in all, 4,621 on the 24 finished symbols and 716 on the 8 partial ones. All were first attempts,
  single-turn, with 0 malformed answers and 0 rejected decisions.
- **Notional cost** (plan quota, list price): $429.52, of which $370.58 was on the finished symbols. That is $0.0805
  a call, at 33.4k tokens a call (24.7k cache read, 8.3k cache write, 0.45k output) and 7.6 s of model wall time a
  call (11.2 h in total).
- **Actions:** `none` 4,657 (87.3 %), `set_stop` 341, `buy_stop` 220, `cancel` 56, `short_stop` 55, `exit` 8.
- **Per stock-year:**
  - $370.58 over 395.2 stock-years of checkpoints for the 24 finished symbols is **$0.94**;
  - $429.52 over 454.8 stock-years for all 32 symbols with calls is also $0.94.
  - The ~$1.07 per stock-year in the dispatch notes divides the full $429.52 by the 24 finished symbols' ~400
    stock-years. That counts the 8 partial symbols' spend without their years.
  - That works out to about 11.7 calls per stock-year.
- **Spend on dead charts:** about 56 calls (SYNC's 6-year gap 24, PRXIQ's stub 31, AKTX's shell 1), roughly $4.5.
- **Pauses:** 872 rows across 51 symbols, from 2026-10-14 05:42Z to 2026-10-17 07:05Z.
  - There were session limits on 10-14, with waits of about 3.8–4.3 h.
  - Then the weekly limit hit ("resets Oct 18 at 12am (America/Los_Angeles)").
  - 28 symbols used up the 24-retry limit without one answered call.

## 8. Defects and caveats found

1. **`compare.sh` joins on the exact date.**
   - `stages/<SYM>.csv` keys a holiday week by its last trading day, which is a Thursday, while checkpoints are
     Fridays. So 141 holiday-week checkpoints drop out (AED2 2003-04-18, DX 2003-07-04, DO_old 2004-06-11, …), plus
     26 cuts with no bar (SYNC 24, PRXIQ 2).
   - Keying on the week's Friday recovers the 141. Agreement moves from 65.9 % to 66.0 %. Not material, but the
     committed counts are short.
2. **The stepper keeps asking about dead charts.**
   - **SYNC:** no bars from 2006-02-10 to 2012-02-10. The store splices the 2003–06 company with the later Synacor,
     whose IPO came in February 2012. The reader was asked 24 times, and said so each time ("the last bar is
     2006-02-10").
   - **SYNC, continued:** the weekly series computes Synacor's first 30-week MA and RS over the old company's last
     bars (2012-02-10: MA 4.52).
   - **PRXIQ:** from 2019 to 2026, a $0.0001 stub with mostly zero-volume weeks; 31 calls.
   - **Fix:** a gap or stub guard in `step.sh` or `start.awk`.
3. **An uncredited spin-off, TXI 2005-08-01** (`data/T/I/TXI/data.csv`).
   - The 73.63 close is followed by a 55.00 open, with `adjusted_close = close` (the Chaparral Steel distribution, the
     #3215 class).
   - It stopped the reader's long at −22.6 %, excess −22.8 %.
   - It also bends both MAs after the event.
4. **AKTX's pre-merger shell** (`data/A/X/AKTX/data.csv`).
   - From 2013-05-10 to 2014-01-17 the raw close is $0.0001 with zero volume. On 2014-01-24 it jumps to $10.50
     (84,000 adj after three later reverse splits).
   - Both 30-week MAs are meaningless for 30 weeks; the reader wrote "distorted by near-zero prices".
   - The PIT lists also carry AKTX in 1998, 1999 and 2009, with no data then. That put it in the 2000–04 stratum, so
     the ticker is reused between the lists and the store.
5. **Market-pack caveat, not a defect.**
   - After the 2020-02-14 splice, the A-D line is `synthetic_advn/decln.csv`, a universe of about 530 issues a day
     scaled ×4.53.
   - It barely moved in 2022: 513,851 on 2021-12-03, a new high of 519,165 on 2022-03-25, and 513,475 on 2022-12-30.
     SPY fell about 18 % over that span (`results/market/ad-weekly.csv`, `spy-weekly.csv`).
   - The reader's post-2020 "A-D line confirming" reads rest on that large-cap population.
6. **A readability note on the full frame.** One extreme volume week, such as EXPO 2023-03-24 at 9.7×, flattens the
   26-year volume panel. The 5-year frame does not have the problem.

## Chart pages read

**Pages:**
- `.sweep-output/fresh-eyes/forward/pages/HQH-2009-12-04-5y.png`
- `PVN-2003-05-02-5y.png`
- `PVN-2001-08-17-5y.png`
- `EXPO-2023-01-13-5y.png`
- `EXPO-2023-09-22-full.png`
- `ZEP-2010-07-02-5y.png`
- `.sweep-output/fresh-eyes/pilot/pages/market/MARKET-2023-01-13-5y.png`

**Checked:**
- each page's last-week line against the run's JSON (HQH 2009-12-04: close 11.3, MA 10.9, RS −11.5);
- the fixed 2000–2026 axis and the grey future block on the full frame;
- the 5-year window;
- the MA, volume and RS panels;
- the A-D splice line and label, and the sector small multiples with their n;
- that each reader reason describes what the page shows (the base tops, supports and MA slopes quoted in §3.3–3.4).

**Found:** no mojibake, empty panel or misplaced window. Defect 6 is the only visual note.

## Reproduce

**Committed:** from the worktree root, `STAGES=/Users/difan/Projects/trading-1/.sweep-output/short-setup-map/stages sh
dev/experiments/fresh-eyes-2026-10-13/scripts/compare.sh`. A copy run into scratch reproduced both files; the trades
file matches up to awk's key order.

**Re-derived:** host awk only, no model calls. Each script runs as `awk -F, -f scripts/days.awk -f <script> …`. They
are committed in `results/forward/analysis/` with their intermediate CSVs. They also read uncommitted inputs: the stage
CSVs and weekly series under `.sweep-output/`, and the record's trade audits in `.sweep-output/breadth-pair-N/` (same runs
as the committed N-rb1-26 artifacts: byte-identical `trades.csv` and `actual.sexp`). `repro.awk` checks the replica against `stages/<SYM>.csv`, giving the 98.2 %.

| script | computes |
|---|---|
| `join.awk` | Friday-keyed join of `decisions.csv`, `stages/<SYM>.csv` and `forward/weekly/<SYM>.csv`, with MA slopes, 26/52-week range position and forward paths (§1.1, §3.1, §3.2 cell features) |
| `cell.awk` | per-cell features table (§3.2) |
| `reclass.awk`, `reclass2.awk` | replica of `Stage.classify` and variants v0–v4, plus the zone-proxy sweep (§3.2) |
| `runs.awk`, `lag.awk` | stage run lengths; lead and lag at the reader's transitions (§3.1) |
| `t34.awk` | our 3→4 transitions against the 52-week high and the 26/10-week lows (§3.1) |
| `episode.sh`, `episode.awk` | the traces (§3.3–3.4, §3.6) |
| `entrystage.awk`, `late.awk` | our stage, age and late flag at the reader's fills (§3.7, §3.8) |
| `dist.awk`, `hd.awk`, `span.awk` | distributions, holding periods, cost per stock-year (§3.6, §7) |
| `overlap.awk` | the record audit's top-20 weeks against the reader's positions (§3.7) |
