# Fresh-eyes, dated picks: the reading (24 dates, plus 2 repeats on 4 of them)

**Rework 1** (qc-results on #3328 at `cc10c95ec`: NEEDS_REWORK, items R2 and R9).
- **R2.** `ours.sh` read the record's `trades.csv` `entry_price` as a raw fill.
  - For a hold that spans a split, the record restates it onto the exit's split basis (`round_trip_pairing.mli`). FLO 2013 (3:2 split, 2013-06-20) was therefore split twice and read +102.6 % instead of +35.1 % (salt 0).
  - `ours.sh` now multiplies the entry back by the `splits.csv` factors in (entry, exit]. FLO is the only window entry whose hold spans a split, in any salt.
  - `2012-12-14/ours/entries.csv` and `compare/` were regenerated, and every figure below that rests on them was re-run.
- **What moved.**
  - Our mean excess: +3.9 → +2.6 % (salt 0).
  - Our per year of capital: +1.5 → −1.3 %.
  - Reader minus ours: +0.7 pp (was −0.6); per year +1.6 pp (was −1.1).
  - Read 3's p25: −20.0 (was −25.7). The 2012-12-14 row.
  - Our tail figures.
  - Our 104-week hold (median −0.9 %, geometric +0.4 %) and managed level (−0.4 %).
- **What did not move.** Medians, sign rates, per-trade percentiles, the management value-add (a ratio of managed to held on the same entry, so the entry error cancels), and every figure in §1.1–1.2 and §3.1–3.2. The verdict is unchanged.
- **Also.**
  - BHC (+84 pp) joins the §1.4 two-year list; it was missing before.
  - The 2020 coverage gap is stated next to 2008.
  - "Per year" now names the 7-day minimum hold.
  - §3.1's "within 13 %" is replaced by the cap arithmetic.
  - §3.3 gives an interval for the hold comparison.
  - The analysis scripts now read the committed `results/run`.
- **R9.** The memory files are named in the PR body.

**Pre-registration:** `dev/plans/fresh-eyes-dated-picks-2026-10-18.md`, merged at `8fd63c8ec` (#3326) and unchanged
since.
- §6 lists reads 1–5.
- §1 calls this a screen that "can point at a gap worth a real test" and "cannot promote or reject a mechanism".

The reads are applied as written. Where one cannot be applied, the section says so and why. Reading by
`results-analyst`; numbers spot-checked by the dispatcher (2016-11-11 audit `(entered 0)`; reader r0 longs n 34, mean
+3.3 %; read 1, 13 of 40 orders on 14 dates).

**Run:** scripts at `5c8a2a584`, the pilot fix at `9765766f2`, results at `4133a5ddd` (branch
`experiment/fresh-eyes-dated`, PR #3328).
- The fix added a short-side pool filter and a "no warrants" filter, and fixed the empty-list file index and the
  empty-pool exit.
- Two pilot dates ran before the fix:
  - 2002-02-22: step A said "neither", so there was no pool.
  - 2017-07-14: the fix commit states its pool is byte-identical after the fix.
- 2009-01-16 was re-run after the fix; the first output is not committed.
- Every short-date pool on disk post-dates the fix, and its filter names sit within 25 % of the 52-week low (40 of 40
  sampled per date) *(re-derived)*.
- 32 date-runs, 928 model calls, $65.74 at list price (`results/run/*/calls.csv`). The plan's unit cost implies
  $64–102 for 32 runs. The weekly plan quota went from 8 % to 10 % over the full run.

**Dates:** `results/dates.txt`, plan §2's stratified draw (`dates.sh` reproduces it).
- No decision date falls in calendar 2008 or calendar 2020.
- 2008: the 2007–09 bear market is covered by 2007-12-14 and 2009-01-16.
- 2020: the crash is not covered. Blocks 20 and 21 drew 2019-11-01 and 2021-01-01.
- So plan §2's "covers 2000-02, 2008 and 2020 by construction" holds for 2000–02 and for the 2008 bear market, but not
  for 2020.
- The 2020 crash shows up only inside the holds and 104-week paths of 2019-11-01 trades. Ours: KLIC and DKS were stopped
  on 2020-02-28. The reader placed no orders that day.

**Artifacts:** `results/run/<date>[-rK]/`, `results/run/compare/`, and `results/analysis/` (the analyst's
re-derivations).
- Our side is the record N: rb1 plus the full NYSE A-D fixture, 26 years, salts 0–2.
  - `ours.sh` reads it from `.sweep-output/breadth-pair-N/rb1-26-s{0,1,2}-v12-{trade_audit.sexp,trades.csv,splits.csv}`.
  - Those files are not committed. They are the same runs as the committed `breadth-fix-rb1-2026-10-11/results/N-*`.
- The analyst's re-derivations read those audits and the host bar store `data/`. Numbers from them are marked
  *(re-derived)*.

**Universe:** broad on both sides; no sp500 cell.
- The reader's pool comes from the PIT top-3000 v12 members alive on each date.
- The record runs on the same PIT top-3000 v12 schedule.

**Review pack:** none, because this is not a portfolio backtest. Four of the reader's images were read instead
(§Images).

**Validator gate** (`mechanism-validation-rigor.md` check 8): there are no paired backtest arms, so
`validator_diff -check V6` does not apply. The record's own reports read `V6 INVARIANT PASS`, 0 violations, in all
three salts (`rb1-26-s{0,1,2}-v12-validator.sexp.md`).

Verifies: none

## In brief

- **Read 5, reported first as the plan asks, bounds everything else.**
  - On long dates the reader repeats about half its picks (Jaccard 0.29–0.67, mean 0.47).
  - On the one short date it repeats none (0.00 in all three pairs); step A also changed its groups there, and with
    them the pool.
  - The long/short side never changed. Initial stops on names picked twice agree within 2.1 % of the trigger.
  - One date's result swings from +59 % to no trade to −24 % across repeats (2023-01-20).
  - So reads 1–4 can support "no large gap", not a direction.
- **Read 1.** On the 14 long dates with orders, 13 of the reader's 40 orders were on our top-20 list.
  - That is 2.0× the pool's base rate (6.45 expected, P ≈ 0.008).
  - The agreement is made at the close look, not at the contact sheet.
  - No reader order was ever one of our entries (0 of 40 long orders).
- **Read 2.** Reader longs (n 34) and our trades (n 51) cannot be told apart.
  - Mean excess vs SPY: +3.3 % vs +2.6 %. Median: −6.1 % vs −3.1 %.
  - Difference in means +0.7 pp (date-clustered 95 % CI −11.4 to +14.8).
  - Per year of capital in the trades: +0.3 % vs −1.3 %.
  - Both means rest on one or two trades (VTR for the reader, AVGO for ours).
  - Reader shorts: 1 of 9 beat an SPY short.
- **Read 3.** The reader is ahead on 7 of 14 paired dates (95 % CI 23–77 %), median +0.4 pp. Every perturbation that
  survives a change of aggregation stays a coin flip.
- **Read 4 cannot be applied: there are 0 shared trades.**
- **Why there is no overlap (the main finding): it comes from our entry gate, not from taste.**
  - Our investor preset places a ticket only after the stock has pulled back at least 8 % from its newest 90-day high.
    The reader buys stocks at that high.
  - All 13 overlapping names were `Skipped No_structural_stop`. 12 of them sat at, or within 11 bars of, a fresh
    90-day high, with less than 8 % pullback since.
  - Across 26 years, two thirds of all `No_structural_stop` skips are this case, not a floor that is too far away.
- **Selection and management.** No side's picks beat the other's, or a neutral near-high pool, in a form that survives
  a change of horizon or of arithmetic vs log returns. Neither manager beats holding its own picks for two years; both
  are about a point worse, geometrically. The cells that could separate the two (plan §5 off-diagonals) were not built.
- **Verdict: no-build; nothing escalates.**
  - The transferable result is the entry-shape mechanism.
  - It is a property of our system, measured from our own audit, and does not depend on the reader's noise.

## 1. The pre-registered reads, as written

Plan §6 reports read 5 first, because "it sets how much weight reads 1–4 can bear". This section follows that order.

### 1.1 Read 5: self-consistency (`compare/consistency.csv`)

| date | step A side (3 runs) | groups | pools shared | shortlists shared (of 10) | order Jaccard (3 pairs) | initial-stop gap, common names |
|---|---|---|---|---|---|---|
| 2003-05-23 | long ×3 | same | 120 / 120 | 7, 6, 8 | 0.50, 0.29, 0.67 | 0.2–0.5 % |
| 2009-01-16 | short ×3 | three different sets (IT and Materials in all) | 38, 57, 49 / 120 | 1, 1, 1 | 0.00, 0.00, 0.00 | – |
| 2016-11-11 | long ×3 | same | 120 / 120 | 5, 3, 6 | 0.50, 0.43, 0.29 | 0.0–2.1 % |
| 2023-01-20 | long ×3 | same set | 120 / 120 | 5, 5, 7 | 0.50, 0.40, 0.67 | 0.0–0.2 % |

The pool and shortlist columns are *(re-derived)* from each run's `pool.csv` and `shortlist.txt`. The stop gaps are
`median_stop_gap` in `consistency.csv`.

- **Averages.** The mean over all 12 pairs is 0.35 (`report.txt`); over the 9 long-date pairs it is 0.47.
- **Scale** *(re-derived, by formula)*: two random 4-name draws from a 120-name pool give a Jaccard of about 0.02. Two
  random 4-of-10 draws from one shared shortlist give about 0.25.
- **The short date's zero is two disagreements stacked.** Step A chose different groups, so the pools differ; then the
  shortlists share 1 name in 10.
- **What the noise does to one date's result** *(re-derived, `compare/trades.csv` by run)*:

| date | r0 | r1 | r2 | ours-s0 |
|---|---|---|---|---|
| 2003-05-23 | 4 filled, +34.1 % | 5, +40.8 % | 5, +25.9 % | 1, −0.4 % |
| 2016-11-11 | 5, −14.3 % | 4, −7.8 % | 5, −7.1 % | 5, −6.6 % |
| 2009-01-16 (short) | 1, −8.5 % | 1, −10.5 % | 4, +4.8 % | none |
| 2023-01-20 | 1, +59.4 % (TDG) | 0 filled | 1, −23.6 % (AXAHY) | none |

- On the two paired repeat dates, read 3's sign holds in all three runs: +26 to +41 pp on 2003-05-23, and −7.7 to
  −0.5 pp on 2016-11-11.
- On 2023-01-20 one fill decides the date. GLNCY and IEX were ordered in all three runs and never filled.
- **Weight reads 1–4 can bear.**
  - Step A's market call is stable, and so are the stops. The picks are half stable.
  - A date's result is one draw, with a spread of 7–83 pp across repeats.
  - So reads 2–3 support "no gap larger than the noise", and nothing finer.

### 1.2 Read 1: pick overlap (`compare/overlap.csv`, `report.txt`)

- **On the 4 short dates our list is empty by construction** (2000-10-20, 2001-08-31, 2009-01-16, 2016-02-05).
  - The record's macro gate was Bearish on each (`ours/week.csv`).
  - The record runs with `enable_short_side false` (`rb1-26-s0-v12-params.sexp`).
  - So overlap there says nothing about choice.
- **The 14 long dates with orders (r0).**
  - 13 of 40 orders were on our top-20 list (32.5 %).
  - Our names were 16.1 % of those pools, so 6.45 were expected by chance.
  - P(≥ 13) ≈ 0.008 for random picks inside each date's pool *(re-derived, 200,000 draws)*.
  - Dropping any one date leaves 1.6–2.2×. Dropping 2016-11-11, which holds 4 of the 13, leaves 9 vs 5.62.
  - Per date: median share 25 %; 6 of 14 dates at zero.
- **The agreement is made at the close look** *(re-derived)*.
  - Contact sheets (5-year thumbnails): 23 of 180 shortlisted names on the 18 long dates were ours, against 27.75
    expected. P(≤ 23) = 0.18, so no preference.
  - Close looks (the 2×2 weekly composite with MA, volume and RS): 13 of 19 shortlisted names of ours became orders,
    against 27 of 121 others. Pooled hypergeometric P = 0.0001. Without 2016-11-11: 9 of 14 vs 26 of 116.
  - So when a book reader looks closely at our screener's names, it wants to buy them at three times the rate of the
    other names it shortlisted.
- **Overlap with our actual entries: 0 on every date** (0 of 40 long orders).
- **The `report.txt` summary line** ("dates with orders: 26 … 23 % … zero overlap 16") counts the 8 repeat rows and the
  4 short dates as dates (§6, defect 1). The r0 figures above replace it.

### 1.3 Read 2: per-trade excess vs SPY over the holding period (`compare/trades.csv`)

`report.txt` pools the reader's longs and shorts, but they are measured against different legs.
- `path.awk` signs both legs for a short. A short's excess is its short P&L minus an SPY-short P&L, which equals SPY
  return minus stock return over the hold.
- That is the right benchmark for a short's selection, and the one #3286 used. It should not be pooled with longs.

Split *(re-derived)*:

| who | n | mean | median | p10 | p25 | p75 | p90 | beat SPY | median hold (p25–p75) | per year of capital |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|
| reader long | 34 | +3.3 % | −6.1 % | −19.8 | −12.2 | +10.7 | +42.8 | 11 | 279 d (127–538) | +0.3 % |
| reader short | 9 | −6.4 % | −8.5 % | −16.5 | −11.2 | −5.8 | +4.5 | 1 | 24 d (21–75) | −28.3 % |
| reader, pooled (`report.txt`) | 43 | +1.3 % | −8.0 % | −20.2 | −12.2 | +7.4 | +34.9 | 12 | 202 d | −1.7 % |
| ours s0 | 51 | +2.6 % | −3.1 % | −12.9 | −9.8 | +2.3 | +17.7 | 18 | 69 d (28–145) | −1.3 % |
| ours s1 | 49 | +2.6 % | −3.0 % | −13.7 | −9.9 | +2.2 | +18.3 | 19 | 69 d | −1.4 % |
| ours s2 | 50 | +2.9 % | −2.7 % | −13.7 | −9.7 | +2.9 | +18.0 | 20 | 69 d | −0.4 % |

- **Scale.** "Per year of capital" is the sum of log((1 + ret)/(1 + spy)) over the sum of years held, exponentiated. Each hold counts as at least 7 days, the same floor `compare_dates.sh` uses for its annualised column (`stats.awk`, `boot.awk`).
  It is the excess per year earned by money inside these trades.
  - `report.txt`'s annualised column cannot be used: it annualises each trade separately, and its mean is −20.9 %
    (reader) and −25.6 % (ours).
  - A 2-day −10 % trade annualises to −99.7 % (DIN, 2001-09-17), so the mean is set by the shortest holds.
- **The difference, reader longs minus ours-s0** *(re-derived)*: bootstrapped over the 19 dates with a long trade on
  either side, 10,000 draws, seed 20261018.
  - Mean +0.7 pp (95 % CI −11.4 to +14.8).
  - Median −3.0 pp (−7.8 to +5.8).
  - Per year +1.6 pp (−15.5 to +25.6).
  - Salts 1 and 2 move our mean and median by at most 0.4 pp, and our per-year figure by up to 1 pp. They are the same trades with path noise, not
    independent samples.
- **The tail.** Both means come down to one or two trades.
  - Without VTR (+88.1 %, 2003) the reader's long mean is +0.7 %; without its top two (VTR, SSNC1), −1.2 %.
  - Without AVGO (+183.8 %, 2013) ours is −1.1 %; without its top two (AVGO, BHC), −2.1 %.
  - The top three trades are 57 % (reader) and 70 % (ours) of each side's positive excess.
- **Power.** The design cannot see a per-trade gap smaller than about ±13 pp in the mean, or ±7 pp in the median. An
  edge of a few points per trade is well inside that.

### 1.4 Read 3: paired per date (`compare/paired.csv`)

- 14 dates have trades on both sides. The reader is ahead on 7 (50 %; Clopper-Pearson 23–77 %).
- Median difference +0.4 pp, p25 −20.0, p75 +13.3, range −37.8 to +34.5.
- Perturbations *(re-derived)*:

| variant | dates | reader ahead | median diff |
|---|---:|---:|---:|
| as registered (ours = s0, per-date means) | 14 | 7 | +0.4 pp |
| ours = s1 | 14 | 7 | −0.2 pp |
| ours = s2 | 13 | 6 | −2.2 pp |
| per-date medians instead of means | 14 | 5 | −4.9 pp |
| a side with no trade counts as SPY (excess 0); not registered | 22 | 11 | +0.4 pp |
| each pick held 104 weeks from entry, arithmetic; not registered | 14 | 4 | −12.0 pp |
| the same, geometric per-date means | 14 | 7 | −1.8 pp |

- **The arithmetic 104-week row is not an effect.** It is carried by our side's two-year monsters (EW, MOV, WING, AVGO, BHC,
  XERS: +81 to +217 pp in their 104-week paths), and it disappears under the geometric mean
  (`feedback_perturb_before_believing_a_cohort_split`).
- **By period.**
  - The reader is ahead on 4 of 5 dates in 2001–07, 2 of 8 in 2010–18, and 1 of 1 in 2024. Fisher one-sided
    P = 0.086.
  - The 2010–18 deficit stays negative on all four big dates after removing our best trade on each (MOV, BHC, AVGO,
    WING).
  - With 8 dates this cannot be called a period effect.

### 1.5 Read 4: management on shared names, which cannot be applied

- `compare/shared.csv` is empty. No name was traded by both the reader and ours-s0 from the same date.
- That includes 2016-11-11, where 4 of the reader's 5 orders were on our list.
- The pre-registered read has no events. §3.1–3.2 give the mechanism; §3.4 gives the management evidence that the
  cells we have can carry.

### 1.6 The 24 dates

| date | step A | our macro | our list: n / Placed (s0) | reader orders (on our list) | filled | reader mean excess | ours n, mean excess (s0) | reader − ours |
|---|---|---|---|---|---|---:|---:|---:|
| 2000-10-20 | short | Bearish | 0 / 0 | 1 (0) | 1 | −22.8 % | 0, – | – |
| 2001-08-31 | short | Bearish | 0 / 0 | 3 (0) | 3 | +2.0 % | 1, −10.7 % | +12.7 pp |
| 2002-02-22 | neither | Bearish | 0 / 0 | 0 (0) | 0 | – | 0, – | – |
| 2003-05-23 | long | Bullish | 17 / 0 | 4 (1) | 4 | +34.1 % | 1, −0.4 % | +34.5 pp |
| 2005-01-07 | long | Bullish | 19 / 1 | 2 (2) | 2 | +12.8 % | 1, −4.6 % | +17.3 pp |
| 2006-01-13 | long | Bullish | 20 / 1 | 2 (0) | 2 | −7.0 % | 2, +11.1 % | −18.1 pp |
| 2007-02-23 | long | Bullish | 20 / 1 | 3 (1) | 3 | +9.7 % | 3, +2.8 % | +6.9 pp |
| 2007-12-14 | long | Neutral | 20 / 0 | 0 (0) | 0 | – | 2, +10.7 % | – |
| 2009-01-16 | short | Bearish | 0 / 0 | 2 (0) | 1 | −8.5 % | 0, – | – |
| 2009-04-03 | neither | Neutral | 19 / 0 | 0 (0) | 0 | – | 0, – | – |
| 2010-09-10 | long | Neutral | 18 / 1 | 4 (0) | 4 | +0.7 % | 3, −12.8 % | +13.5 pp |
| 2011-12-09 | long | Neutral | 20 / 0 | 1 (0) | 1 | −21.0 % | 2, +7.3 % | −28.3 pp |
| 2012-12-14 | long | Bullish | 20 / 0 | 3 (0) | 3 | −0.3 % | 4, +20.4 % | −20.6 pp |
| 2013-08-30 | long | Bullish | 20 / 3 | 2 (2) | 2 | −9.8 % | 6, +28.0 % | −37.8 pp |
| 2014-05-23 | long | Bullish | 19 / 0 | 3 (0) | 3 | −1.4 % | 3, −4.5 % | +3.1 pp |
| 2016-02-05 | short | Bearish | 0 / 0 | 5 (0) | 4 | −8.1 % | 0, – | – |
| 2016-11-11 | long | Bullish | 20 / 0 | 5 (4) | 5 | −14.3 % | 5, −6.6 % | −7.7 pp |
| 2017-07-14 | long | Bullish | 19 / 0 | 3 (1) | 1 | −14.0 % | 2, +22.6 % | −36.5 pp |
| 2018-09-07 | long | Bullish | 20 / 0 | 3 (1) | 2 | −8.3 % | 2, −6.0 % | −2.3 pp |
| 2019-11-01 | long | Bullish | 20 / 0 | 0 (0) | 0 | – | 4, −9.6 % | – |
| 2021-01-01 | long | no screen (holiday week) | 0 / 0 | 0 (0) | 0 | – | 2, −13.8 % | – |
| 2021-12-03 | long | Bullish | 20 / 3 | 0 (0) | 0 | – | 5, −3.7 % | – |
| 2023-01-20 | long | Bullish | 20 / 0 | 4 (1) | 1 | +59.4 % | 0, – | – |
| 2024-01-26 | long | Bullish | 20 / 0 | 1 (0) | 1 | +19.8 % | 3, −11.3 % | +31.1 pp |

Sources: `side.txt`, `ours/week.csv`, `ours/top.csv` (salt 0), `compare/overlap.csv` (on-list counts use the union
over salts), `compare/paired.csv`.

## 2. The verdict, calibrated

- **No-build decision; nothing escalates.**
  - Read 2's difference is +0.7 pp (95 % CI −11.4 to +14.8). Read 3 is 7 of 14. Read 4 has no events.
  - Under `mechanism-validation-rigor.md`, a proxy screen at this power may say "no obvious gap, not worth prioritising
    a build". It may not say that the reader and our system pick or manage equally well.
- **What the design can claim:**
  - (a) A book reader's close look prefers our screener's top-20 names (read 1).
  - (b) Our entry gate rejects exactly those names, for a structural reason found in our own audit (§3.1).
  - (c) There is no selection or management gap large enough to see with 34 and 51 trades on 14 paired dates.
- **What it cannot claim:**
  - A direction on selection. The reader's picks change half the time on a repeat, and the plan's date-axis
    recognition test was not built (§6, defect 5).
  - Anything about management on the same names: there are no shared trades, and the off-diagonal cells were not built.
  - Anything about shorts beyond consistency with the existing no-build (9 trades, one draw).
  - Anything about the 2020 crash: no decision date falls in 2020 (§6, defect 12).
- **The §3.1 mechanism does not depend on the reader's noise.** It is a property of the floor scan, reproduced on 96 %
  of the record's placed tickets.

## 3. Why

### 3.1 Zero shared trades: the two systems buy different phases of the same move

**The gate.** The record runs `require_structural_stop true` (`params.sexp`).
- A candidate whose initial stop is not a `Support_floor` is skipped as `No_structural_stop`
  (`entry_audit_capture.ml`, `_lacks_required_structural_stop`).
- A floor more than 15 % below entry is first re-anchored to the fallback and then skipped the same way
  (`entry_audit_helpers.ml`, `_maybe_reanchor_to_entry_base`).
- The floor comes from `Support_floor` with the defaults in `stop_types.ml`: 90 daily bars, `Window_extreme`, `Wick`,
  `min_correction_pct 0.08`.
- `support_floor.ml` anchors on the highest high in the window (the newest one on ties) and accepts a low only *after*
  that high: "When [anchor_off = 0] the range is empty and no counter-move can exist."

**What that does.**
- A stock at, or just past, a fresh 90-day high has no qualifying low after its high, so it gets no floor and is
  skipped.
- A ticket is placed only once the stock has pulled back at least 8 % from that high.

Measured with the floor scan re-implemented on the adjusted basis of the host store *(re-derived)*:

- **The 18 decision-week lists (salt 0): 351 names.**
  - 338 `No_structural_stop` (96.3 %), 10 `Placed`, 2 `Insufficient_cash`, 1 `Sized_to_zero`.
  - Of the 338: 84 had their 90-bar high on the decision day; 157 had pulled back less than 8 % since a recent high; 97
    had a floor in the reproduction, so their skip is the more-than-15 % case.
  - The reproduction finds a floor for 12 of the 13 names that passed the stop test. NABZY 2006 is the miss.
- **26 years (salt 0): a seeded random 1,514 of the 20,177 skips.**
  - 29.6 % had their high on the decision day.
  - 38.5 % had pulled back less than 8 %; their high came a median 3 bars earlier, 91 % within 10 bars.
  - 31.9 % had a floor too far below entry.
  - In the no-floor two thirds, 93 % of closes sit within 5 % of the 90-bar high.
  - The no-floor share is about 50 % in 2000–02 and 2009, and 64–73 % in the other eras.
- **The record's 672 placed tickets (salt 0, 26 years).** The floor is reproduced for 644 (96 %).
  - The 90-bar high came a median 8 trading days before placement (p25 4, p75 13).
  - The correction after it was a median 9.9 % (p25 8.8, p75 12.1).
  - The close sat a median 6.7 % below that high, and the trigger E a median 3.5 % below it (p90 +1.1 %).

So the investor preset enters on the first pullback after a new high, with a buy-stop near the old high. The reader
buys the breakout week itself.

**The 13 overlap names.**
- All 13 were `Skipped No_structural_stop` on our side that week (`ours/top.csv`). The raw audit for 2016-11-11 reads
  `(entered 0)`, with all 20 names `(Skipped No_structural_stop)`.
- 12 of the 13 fail the scan because they sit at or near a fresh high:
  - the 90-bar high on the decision day: GIS, KALU, MTB, EXPO, DCI;
  - the high 1–11 bars earlier with a pullback under 8 %: ASL, WKC, CMI, AKRX, BK, SLF, WPC.
- AMGN, the 13th, had a floor more than 15 % away.
- Their closes were 0.0–6.2 % below the 90-bar high (median 1.8 %).
- They came back to our lists 0–3 times in the next 12 months, always `No_structural_stop`. The record traded none of
  them that year.

**The reader's stops on those names were not the investor's floor.**
- They sat 8.7–14.2 % below the trigger (median 11.4 %).
- The card's investor rule names "the prior correction low or the bottom of the base before the breakout". That
  pre-breakout low was 14.5–34.8 % below the trigger (median 21.1 %; `Nearest` scan at 8 %), beyond 15 % for 12 of 13.
- The reader used a shallower recent low, the old ceiling or the MA instead. That is closer to the card's trader rule
  ("the closest prior reaction low").
- On these names our gate declined the trade the way the book's "prefer other candidates" would.

**The other direction.**
- Our 10 `Placed` names on the decision-week lists, plus the 2 cash and 1 sizing skips, were all in the reader's pool.
- The reader shortlisted none of them (0 of 13).

**Would the `Nearest` scope change this?** Mostly not *(re-derived)*.
- It finds a floor for 220 of the 241 at-the-high skips on these lists, a median 17.8 % below the close (p25 14.6 %).
- **The cap is measured from E to the installed stop, not to the floor.**
  - The installed stop sits 4 % under the floor: `floor_stop.ml` places it at floor × (1 − 0.08 / 2), then nudges it
    under a round number.
  - With E at the close, a floor passes the 15 % cap only if it is within about 11.5 % of the close. That is 23 of the
    220 (10 %).
  - Against the bare 15 %, ignoring the 4 % offset, it is 64 (29 %).
  - The audit does not record E for skipped names, so the true count lies somewhere in that range.
- **A ticket also fills only within 2 % above E** (`entry_extension_max_pct 2.0`). A name already well past its
  breakout would rest until it pulled back.
- Most would still fail. The scope is not the binding constraint; the cap against the pre-breakout low is.

### 3.2 Our 4-week entries are mostly not decisions made on the date

Plan §5 reads "our picks" through the entries made in the 4 weeks after each date. In this system those are mostly
other weeks' decisions *(re-derived: `ours/entries.csv` `position_id` joined to the audit's `placement_date`)*.
- Of 51 window entries (salt 0):
  - 25 came from tickets placed before the decision week. Ticket age at fill runs up to 47 weeks (AAON: placed
    2023-03-17, filled 2024-02-15).
  - 8 came from the decision week.
  - 18 came from later weeks.
- 40 of the 51 were never in the reader's pool.

So even apart from §3.1, the reader could not have picked most of what we traded. Read 4 needed the decision week's
`Placed` names; there are 10 of those across the 24 dates.

### 3.3 Selection, with management removed (not pre-registered)

- **Filled picks held 104 weeks from entry** (`trades.csv` `r104`, `spy104`; ratio form (1 + r104)/(1 + spy104) − 1).
  - Reader longs: median +0.6 % over SPY, geometric mean +1.4 % (n 34).
  - Ours: median −0.9 %, geometric +0.4 % (n 51).
  - The difference is noise *(re-derived, date-clustered bootstrap, 10,000 draws, seed 20261018)*: +1.5 pp in the
    median (95 % CI −9.7 to +16.7), +1.0 pp in the geometric mean (−13.4 to +17.5).
- **Everything each side liked, measured from the decision date.** Each set is compared with the neutral filter names
  of the same pool: within 25 % of the 52-week high, $1M dollar volume, and in the favoured groups or with no sector
  row. A cell counts the dates where the set beat the filter names *(re-derived)*.

| comparison | form | 13 w | 26 w | 39 w | 52 w | 78 w | 104 w |
|---|---|---|---|---|---|---|---|
| reader orders vs filter | arith | 8/14 | 5/14 | 7/14 | 7/14 | 8/14 | 7/14 |
| | log | 8/14 | 6/14 | 10/14 | 12/14 | 11/14 | 9/14 |
| our list vs filter | arith | 9/17 | 9/17 | 11/17 | 8/17 | 10/17 | 7/17 |
| | log | 8/17 | 10/17 | 11/17 | 10/17 | 10/17 | 11/17 |
| reader orders vs our list | arith | 7/14 | 6/14 | 7/14 | 7/14 | 11/14 | 8/14 |
| | log | 8/14 | 7/14 | 8/14 | 8/14 | 11/14 | 10/14 |

- Nothing clears both forms at more than one horizon.
- The reader's 12 of 14 (log, 52 weeks) is a tilt away from the pool's deep losers; the pool's 52-week p10 is −44 % vs
  SPY. The tilt is gone in arithmetic form and at 26 weeks.
- Our list has no edge over the neutral pool at any horizon. That is the same "ranker pool = universe" result as the
  2025 selection screen.
- Our actual entries look better than the pool (12–14 of 17 at 104 weeks), but they are conditioned on a fill within 4
  weeks, which is look-ahead from the decision date. That row is not a selection read and is left out of the table.

### 3.4 Management, within each side (not pre-registered)

There is no shared name to compare exits on. Instead, each manager is compared with holding its own picks for 104
weeks, with the money parked in SPY after an exit *(re-derived)*.

- **Holds and exits.**
  - The reader holds a median 279 days; ours, 69.
  - Reader exits: 27 stops, 5 at the 104-week cap, 1 sell, 1 data end. Ours: 26 `stop_loss`, 25 `laggard_rotation`.
- **Value-add (log, managed minus held).**
  - Reader: median 0.000 (IQR −0.103 to +0.032), positive in 13 of 34.
  - Ours: median −0.057 (IQR −0.238 to +0.181), positive in 22 of 51.
  - Geometric over each side's picks: the reader +1.4 % held vs +0.3 % managed; ours +0.4 % held vs −0.4 % managed.
  - Both lose about a point to holding (1.1 and 0.8 points). Ours is far more active in both directions.
- **What the stock did after the exit** (vs SPY, to 104 weeks from entry):
  - After a `laggard_rotation` exit (median trade +8.0 %), the stock beat SPY in 14 of 25 (median +2.2 %; mean
    value-add −0.063).
  - After a `stop_loss` (median trade −9.8 %): 15 of 26 (median +8.0 %; mean value-add +0.046).
  - After the reader's stops: 14 of 27 (median +5.6 %).
- **Caveat.** SPY parking is a neutral counterfactual, not the record's; the record rotates into the next Stage 2 name.
  These rows describe each manager; they do not compare them. Only the plan's top-right cell (the reader's entries
  under our stops) could.

### 3.5 The market read and the shorts

- **Step A never contradicts our macro gate** (`a/a.json`, `ours/week.csv`).
  - Bearish weeks: short 4 of 5, neither once (2002-02-22).
  - Bullish weeks: long 14 of 14.
  - On the 4 Neutral dates the reader went long 3 times and neither once (2009-04-03). The 3 long calls were 2007-12-14
    (where it then placed nothing), 2010-09-10 and 2011-12-09.
  - On 2007-12-14 its close looks read "only A+ setups qualify" under a "Stage 3 top". SPY then fell 38.2 % in 52
    weeks.
- **Four long dates with no orders** (2007-12-14, 2019-11-01, 2021-01-01, 2021-12-03).
  - The close-look reasons cite extension above the MA (22–48 % above it on 2021-01-01), a stop more than 15 % away,
    weak breakout volume, or an RS divergence. The first two are the same 15 % limit our gate applies.
  - The record traded on all four dates: mean excess +10.7 %, −9.6 %, −13.8 % and −3.7 %.
- **Shorts.**
  - 9 filled, all stopped out. 1 beat its SPY-short benchmark: VPI 2001, +23.1 %. Median −8.5 %, median hold 24 days.
  - Two of the four short calls came at turns: 2009-01-16 (SPY +36.7 % over the next 52 weeks) and 2016-02-05
    (+24.6 %).
  - Consistent with the short-track no-builds. 9 trades from one draw add direction, not weight.

### 3.6 Traces

1. **MTB, 2016-11-11: the reader's trade, our skip.**
   - The close look (`d/SRSP.json`) saw a breakout to all-time highs in election week. Buy-stop 136.25 (limit 139),
     stop 117.88, "under the recent base lows and the MA (about 13.5 % risk)".
   - Filled 2016-11-14 at the 136.75 open (`follow/SRSP/log.csv`).
   - The looks held the stop until a 10 % pullback (about 170 → 147) in April 2017, raised it to 146.88 on 2017-05-05,
     then to 149.88 on a Stage 3 call on 2017-08-25.
   - Stopped 2017-08-29: +11.2 % vs SPY +14.5 %, 288 days.
   - Our side: rank 6 on the 2016-11-11 list, `No_structural_stop`.
     - The decision bar's 136.16 high is the top of its 90-bar window, so the scan has no bars after its anchor.
     - The nearest 8 % pullback low in the window (111.82 on 2016-08-02) is 17.9 % below the reader's trigger.
     - MTB appeared once more (2016-11-18) and was skipped the same way.
2. **VTR, 2003-05-23: the reader's best trade, never on our list.**
   - A REIT from the neutral part of the pool. Buy-stop 11.12, stop 9.88, "under the old 10 ceiling (about 11 % risk)
     … already about 10 % past the breakout".
   - Filled 2003-05-27; stop raised five times, to 18.88; held to the 104-week cap.
   - +120.7 % vs SPY +32.6 % (excess +88.1 %).
   - It never reached our top 20 in the following year. Our trade from that date was COLM.
3. **COLM, 2003-05-23: our trade, from a ticket placed the week before.**
   - Placed 2003-05-16 at rank 3, filled 2003-05-28, closed by `laggard_rotation` on 2003-12-22: +15.4 % vs SPY
     +15.8 %.
   - Over its 104 weeks it ended −7.2 % against SPY +29.0 %, so the rotation exit was right.
   - It was not on the 2003-05-23 list the reader saw.
4. **AVGO, 2013-08-30: our best trade, not shortlisted.**
   - Rank 9 on the list, `Placed`: Stage 2 for 14 weeks, RS crossover, volume ratio 2.25, grade A+ (audit entry
     `AVGO-wein-642`).
   - E 39.38 against a 38.51 close. Stop 34.32, under a 10.0 % pullback from a 2013-07-17 high.
   - Filled 2013-09-10, stopped 2015-08-20 after 709 days: +209.5 % total return (+183.8 % excess).
   - AVGO was in the reader's pool but did not make its shortlist. The reader's orders that day, KALU and AKRX, were
     names our gate skipped.

## 4. How it fits what we know

- **Refines `project_recovery_reentry_gap`** (item 2 and its funnel fact).
  - `No_structural_stop` dominance is confirmed again: 338 of 351 list names here.
  - Its cause is mostly not "the floor is the crash low, more than 15 % away". Two thirds of skips have no floor at
    all, because the stock is at or within days of a fresh 90-day high.
  - The far-floor case is a third overall, and about half in 2000–02 and 2009.
  - This also explains the anchor-position screen's unexplained half "within 10 % of the top"
    (`entry-anchor-recovery-2026-10-02/anchor-position-screen.md`).
- **Confirms the forward-pass reading** (§3.7 of `fresh-eyes-2026-10-13/results/forward/README.md`, #3317) and
  supplies the mechanism it lacked.
  - There, 13 of 24 sample names reached our top 20 and all were `No_structural_stop`. Here, 13 of 13 overlapping
    orders were. Second sample, same result.
  - Its VIAV specimen (a reader stop about 17 % away caught +265 %) is the other side of the same coin. Here, the
    reader's comparable picks showed no edge on average.
- **Consistent with the closed selection programme:** `project_entry_selection_closed_powered`,
  `project_cascade_selection_inversion`, and the 2025 screen's "ranker pool = universe" (`project_recovery_reentry_gap`
  item 6). Our top-20 list has no forward edge over a neutral near-high pool on these dates.
- **Confirms `project_edge_is_the_fat_tail`** for both systems: each side's mean is one or two trades. Without AVGO, ours turns negative.
- **Consistent with `project_nearfloor_is_risk_not_return`** (the `Nearest` scope: REJECT-as-default, keep-as-axis).
  - On the investor preset the scope would admit few of the at-the-high names, because their pre-breakout lows are
    mostly more than 15 % away.
  - Nothing here reopens that grid.
- **Consistent with the short-track no-builds:** `2026-10-13-short-setup-map`, `2026-10-13-short-wide-top`,
  `2026-10-12-index-hedge-screen`, `project_shorts_liveness_dead`.
- **Leaves `project_laggard_broad_recheck` (keep ON) as it is.** Rotated names beat SPY afterwards in 14 of 25, but the
  record's counterfactual is the next Stage 2 name, not SPY.
- **No contradiction found.**

## 5. What it implies next (options; the choice is the user's)

1. **Stop here (Recommended).**
   - No selection or management lever is ruled in.
   - The user's 10-18 decision to stop the forward pass at its reading applies here with the same force.
2. **Documentation only, no behaviour change.**
   - `support_floor.mli` says "for a normally-shaped base the two readings coincide (the window extremum *is* the
     recent base)". That holds only before a breakout. On, or just after, the breakout bar, `Window_extreme` returns
     `None`.
   - Say in the investor preset's docs, or as an implementation note in `weinstein-book-reference.md` §5.1, that
     `require_structural_stop` with the default scan admits only pullbacks after a high: the high a median 8 trading
     days earlier, about 10 % deep.
3. **Free and mechanical, but low value: the plan's top-right cell** (our stop machine on the reader's 34 filled
   longs).
   - It is the only cell that isolates management on the same picks.
   - But read 2 leaves little to explain, and these are names our entry gate rejects.
4. **Not suggested by this screen, but available if the faithfulness question should be settled.**
   - A pre-registered surface on the investor base that lets a fresh breakout use its pre-breakout floor
     (`support_floor_anchor_scope Nearest` exists as an axis), run through the confirmation grid.
   - The expected effect is small:
     - between a tenth and three in ten of the at-the-high skips would come within the cap (§3.1);
     - they would fill only on a pullback to within 2 % of E;
     - the reader's breakout picks carried no edge here.
   - The trader-style alternative is a nearer reaction-low stop, as the reader used. That is a trader dial, and the
     hybrid's percentage-stop entries already lost 29–39 pp a salt (`project_investor_preset_broad`, 09-28).
5. **If any reader study runs again:**
   - build the plan's date-axis test first (§6, defect 5);
   - take "our picks" to be the decision week's `Placed` names, not the next 4 weeks' entries;
   - draw at least one date inside 2020.

## 6. Defects and caveats found

1. **`report.txt`, read 1 summary line** (`compare.awk` END block). "dates with orders: 26; mean share 23 %; zero
   overlap 16" counts the 8 repeat rows and the 4 short dates, where our list is empty by construction. Per day-0 long
   date: 14 dates, mean share 31 %, 6 at zero; pooled, 13 of 40.
2. **`report.txt`, read 2.**
   - The "reader" rows pool longs (SPY leg) and shorts (SPY-short leg).
   - The annualised column is set by the shortest holds (DIN, 2001-09-17: 2 days, −99.7 %).
3. **Design: plan §5's entry window is not "our picks on the date"** (§3.2). 25 of 51 window entries came from tickets
   placed before the decision week and 18 from later weeks; 40 were never in the pool.
4. **Design: names with no sector row bypass the group filter** (`POOL_UNKNOWN=1`).
   - They are 24–102 of each 120-name pool, mostly in the early years (2000-10-20: 102).
   - 15 of the 51 day-0 orders came from them.
   - In the early years step A's groups barely constrain the pool.
5. **Design: the plan §3 date-axis test was not built.**
   - Every image shows the calendar axis and real prices (checked in §Images), so a reader could recognise a famous
     chart.
   - This limits any selection claim in the reader's favour. None was found.
6. **Data: warrant series carry their parent's pre-issue history and reach the pools.**
   - `STI-WS-A`, `STI-WS-B`, `BAC-WS-A`, `BAC-WS-B` and `C-WS-A` have bars from 1997-12-31, long before these
     warrants were issued in 2008–10. For example, `C-WS-A` closes at 23.00 on 151 M shares on 2008-10-01, which is
     Citigroup's own common-stock tape.
   - They appear in 19 pool rows, e.g. 4 of 120 in `results/run/2000-10-20/pool.csv`.
   - The fix's filter in `pool_pick.awk` (`/-(W|WS|WT|U|UN|R|RT)$/`) misses the class-suffixed form `-WS-A`.
     `GM-WS-B` (2016-11-11) slips through the same way.
   - None was shortlisted or ordered.
   - Classes: #3183 (warrants in the lists) and #3239 (vendor splices).
7. **Data: symbol class on our own list.**
   - `FNMAS` ranked 10th on the 2016-11-11 list. By its ticker and history (first bar 2007-12-10, $5.65 in 2016) it is
     the Fannie Mae series-S preferred.
   - OTC ADRs ranked 3rd and 12th the same week (`ALIZY`, `AXAHY`).
   - The reader ordered `GLNCY` in all three 2023-01-20 runs; it never filled.
   - #3183's scope names non-USD listings, warrants and units, but not preferreds.
8. **Script comment in `ours_top.awk`.**
   - It says "a holiday Friday's record is dated the Thursday". In the record, a holiday-Friday week has no cascade
     record at all.
   - That is 45 weeks over 26 years: Good Fridays, July 4, Christmas and New Year Fridays, and 2001-09-14. It is why
     2021-01-01's list is empty.
   - Known: #3139, shipped default-off as `screen_holiday_friday_weeks` (#3254). Its paired 26-year read is still
     unrun.
9. **Long-rested tickets inside the window entries:** AAON (47 weeks; the #3075 specimen) and QDEL (placed 2012-04-13,
   filled 2013-01-02; 37 weeks).
10. **Limits of the reproduction.**
    - The analyst's floor scan reads the host bar store, not the run's v12 warehouse.
    - It reproduces 644 of 672 placed tickets (96 %), and misses NABZY 2006 on the lists (6.7 % depth against the 8 %
      threshold).
11. **`ours.sh` read split-restated entry prices as raw (found by qc-results, fixed in rework 1).**
    - The record's `trades.csv` restates `entry_price` onto the exit's split basis when a split falls inside the hold
      (`round_trip_pairing.mli`). FLO-wein-600 entered 2013-01-03 at 24.81 and reads 16.54 = 24.81 / 1.5, for the split
      of 2013-06-20.
    - `ours.sh` passed that to `path.awk` as a raw price, so the split was applied twice: +102.6 % instead of +35.1 %
      (s0); +106.6 % instead of +37.7 % (s1, s2).
    - `ours.sh` now multiplies the entry by the `splits.csv` factors in (entry, exit]. FLO is the only window entry
      whose hold spans a split: 63, 61 and 62 entries checked per salt, including the repeat directories' copies.
    - Any tool that reads `trades.csv` `entry_price` as the raw fill has the same trap.
12. **Design: no decision date in calendar 2020 (or 2008).**
    - Blocks 20 and 21 drew 2019-11-01 and 2021-01-01, so plan §2's "covers … 2020 by construction" does not hold.
    - 2008 is covered as a bear market (2007-12-14, 2009-01-16), not as a calendar year.
    - The 2020 crash reaches the study only through the holds of our 2019-11-01 trades (KLIC and DKS stopped on
      2020-02-28) and their 104-week paths.

## Images looked at

- Under `.sweep-output/fresh-eyes-dated/run/`:
  - `2016-11-11/sheets/sheet-1.png`: the contact sheet holding EXPO and APOL;
  - `2016-11-11/d/SRSP.png`: MTB's close look;
  - `2016-11-11/follow/SRSP/looks/2017-05-05.png`: the look that raised MTB's stop;
  - `2009-01-16/sheets/sheet-1.png`: a short-side sheet.
- **Checked:**
  - pseudonyms only, no real ticker;
  - the future greyed out from the cut;
  - the cut date and last-bar numbers match the prompt and `log.csv`;
  - prices on one basis per page;
  - no mojibake, NaN or empty panels;
  - the short sheet shows names near their lows, as the mirrored filter intends.
- **Found:** nothing wrong in the renders. The calendar axis is visible on every frame (defect 5).

## Reproduce

The analyst's re-derivations are host-only awk/sh, no container, in `results/analysis/` (some steps were inline shell
loops in the analyst session; the scripts and their CSV outputs are committed as run).

- **Inputs flattened from the record's audits:**
  - `decisions.csv`: the weekly decision lists of all three salts;
  - `tickets.csv`: placement date per position.
- **The floor scan:** `floor.awk` re-implements `Window_extreme`/`Wick` on the adjusted basis; `nearest.awk` and
  `nearest_raw.awk` implement `Nearest`.
- **Applying the scan:**
  - `scan_lists.sh` runs it over the decision-week lists, producing `lists_scan.csv`;
  - `placed_geo.csv` covers the 672 placed tickets;
  - `nss_sample_scan.csv` covers the 1,514-skip sample.
- **Read 1:** `read1.sh` and `r1rep.awk`, with tails from `hyper.awk` and `fisher.awk`.
- **Reads 2 and 3:** `stats.awk` (the read 2 split), `boot.awk` (the clustered bootstrap), `paired.awk` (the read 3
  perturbations).
- **§3.3 and §3.4:** `mgmt.awk` (hold vs managed), `boot_hold2.awk` (the hold bootstrap, added in rework 1), `fwd6.awk` and `hz.awk` (decision-date sets).
- **Traces and checks:**
  - `cmpstop.sh`: the reader's stops vs the pre-breakout floor;
  - `later.sh`: later list appearances;
  - `reps.sh`: pools and shortlists across repeats.
