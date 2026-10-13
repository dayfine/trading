# Short setup map: blind second read (results-analyst, 2026-10-13)

This read had no access to `README.md` or to the rest of `results/analysis/`. Inputs:
- the plan, including amendment 1;
- `results/events/*.csv` (45,599 events);
- `summary-floor*.txt`;
- the scripts, the raw bars and the stage CSVs;
- the prior-programme records.

The read's own scratch scripts were not committed. The figures below are as the read reported them.

## Q1. The decision rule as written: no edge in P1 or P2 (confidence: high)

Both cells were recomputed independently and match `summary-floor5.txt` to the digit.

| cell | n | mean | median | beat | halves (mean) | O1 +60 mean | result |
|---|---:|---:|---:|---:|---|---:|---|
| P1 (E1) | 4,235 | −2.44 % | −3.76 % | 29.7 % | −2.69 / −2.29 % | −2.69 % | fails criteria 2, 3, 4 |
| P2 (E2) | 3,530 | −0.85 % | −1.91 % | 31.4 % | −1.42 / −0.48 % | −0.95 % | fails criteria 2, 3, 4 |

- **95 % CI on the beat rate:** ±1.4 pp (P1) and ±1.5 pp (P2).
- **Clustering:** P1's events fall in 264 breakdown weeks, and 29.9 % of those weeks have a positive mean.
- **Economic scale:**
  - P1 loses 11.3 %/yr of the capital at work against the SPY short (mean hold 55 bars, 72.9 % stopped).
  - P2 loses 5.4 %/yr (40 bars, 81.8 % stopped).
- **$17 floor:**
  - P1: n 3,506, median −3.63 %, beat 29.2 %.
  - P2: n 2,960, median −1.86 %, beat 31.4 %.
- **Rule coding.** `analyze.awk` codes criteria 1–6 as written.
  - The halves and O1 sign checks are vacuous "ok"s here, because every value is negative.
  - "RS not rising" excludes RS = na. Including it gives a beat of 29.8 % for P1 and 31.6 % for P2.
- **No descriptive cell qualifies.** The only cells at a beat of 58 % or more are top_width > 20, with n = 43 and 39.

## Q2. Measurement

- **Five seeded random P1 events re-derived from the raw bars:** every field matches to 5 decimals.
  - JKHY 2018-12-07
  - AMH 2022-02-11
  - SCHW 2015-01-30
  - CSGP 2023-10-27
  - IQV 2022-01-28
- **E1 O2 excess:** reproduces for all 45,599 events (0 mismatches above 1e-4).
- **Estimand gaps.** These do not flip the verdict.
  - (a) **The Stage-3 sliver.** The Stage-3 range is 1–2 weeks in 64.7 % of events. The median stop room is 10.2 %
    (p10 2.7 %). The 26-week high sits a median 13.3 % above the stop's basis.
  - (b) **No support-break condition.** 48.1 % of events close the breakdown week above the 10-week support. Among
    true breaks, the E2 share is 66.7 %.
  - (c) **E2 phantoms.** 452 of P2's entries (12.8 %) sit at or above their own stop. Without them, P2's beat is
    28.8 % and its median −2.62 %.
  - (d) **Survivorship.** About 89 % of the group = na events are delisted names. Admitting them gives P1 n 8,732,
    beat 32.3 % and median −3.70 %.

| P1 variant (not pre-registered) | median | beat |
|---|---:|---:|
| as registered | −3.76 % | 29.7 % |
| stop at 1.01 × the 26-week high | −4.21 % | 42.1 % |
| no stop, +60 / +120 bars | −1.29 / −1.35 % | 46.2 / 47.2 % |
| true support breaks only, O1 +60 (n = 2,351) | −2.11 % | 44.6 % |

## Q3. No-build: warranted

Confidence is high for the setup as measured, and medium as "the book's setup".

**Selection.** On O1 +60, the population is a coin flip (beat 51.4 %). Every checklist item is flat or inverted:

- SPY Stage 1/2 beats 52.5 %, against 49.4 % for early Stage 4.
- RS rising beats 52.9 %, against 51.5 % for negative-and-falling.
- Prior advance under 30 % beats 52.9 %, against 50.6 % for 30–100 %.

Leaving one item out of P1 raises its beat by 3.6 pp (market), 3.0 (group), 1.2 (RS) and 0.4 (advance).

**Market timing.** Over P1's O2 holds, SPY rose 6.3 % on average. The stock short returned −8.77 % and the SPY short
−6.32 %. Only 18.6 % of P1's shorts won in absolute terms. P1's O1 +60 beat was:

| bear year | O1 +60 beat |
|---|---:|
| 2000 | 38.1 % |
| 2008 | 45.0 % |
| 2022 | 49.0 % |

**The stop is a drag, not the cause.** P1 drifts negative at every horizon without a stop: −0.82 / −2.69 / −3.43 % at
+20 / +60 / +120 bars.

## Q4. Programme: close single-name shorts (confidence: medium-high)

The user named four ways the setup might have been mis-built:

- stop room;
- pullback entry;
- market phase;
- selection.

This screen answers each one.

- **Recommendation (a):** stop here. Classify the single-name short book as do-not-revive.
- **Option (b):** run one cheap, separately pre-registered **top screen**:
  - **Top:** late Stage 2 plus Stage 3, using the `late` flag.
  - **Stop:** above the right-shoulder peak.
  - **Order:** read O1 +60 first.
  - **Close rule:** close if the beat rate is under 55 % or the median is 0 or below.
  - **Expected outcome:** failure. There is no O1 gradient by top width (51.9 / 50.4 / 51.3 / 51.2 %), and the
    market-phase headwind remains.
- **Short interest** remains data-blocked.

## Q5. Dividends: do not exclude payers (confidence: medium-high)

**O2 by yield (none / under 2 % / 2–5 % / over 5 %):**

| yield | O2 beat | O2 median |
|---|---:|---:|
| none | 34.2 % | −3.53 % |
| under 2 % | 33.1 % | −2.87 % |
| 2–5 % | 34.1 % | −2.56 % |
| over 5 % | 36.7 % | −2.52 % |

- **O1 +60:** non-payers beat 53.1 %, against 49.2–50.4 % for payers. The gap is mostly in 2000–12, and it vanishes
  inside P1.
- **Cost:** dividends are already charged through the adjusted closes, at about yield × holding period.
- **Correction (qc-results):** the 962-event figure below is mis-defined. The committed decision-time split is 1,093
  events at a beat of 29.5 % (README §10, `divsplit.txt`).
- **The `bigdiv` split is look-ahead biased (defect 4 below).** At decision time, the 962 events with a dividend of
  3 % or more do slightly worse: beat 31.9 % and mean −1.92 %, against 34.1 % and −1.33 %.

## Defects

1. **Stage-3 sliver.** Specimens: IQV 2022-01-28 and JKHY 2018-12-07.
2. **No support-break condition.** Specimen: AMH 2022-02-11.
3. **E2 phantoms at or above their stop.** Specimen: SCHW 2015-01-30.
4. **`bigdiv` look-ahead.** The 3 % test divides by the in-hold close. 174 of the 1,136 flagged events qualify only
   because the price fell, and those read beat 72.4 % and mean +14.0 %. Specimen: TGH 2008-09-26.
5. **Sector coverage is survivor-tilted.** About 89 % of the group = na events are delisted names.
6. **The prior-advance low can come after the high.** 3.8 % of events (5.8 % of P1), including the 2020-03-20 cohort.
   Without them, P1's beat is 28.9 %.
7. **Vendor splices.** BELM, SRX, CGRN, CCBL and PUB; room outliers NATI and UFS. Clipped at ±100 %, P1/P2 is
   −2.33 / −0.82 %.
8. **WTR all-zero bars from 2013-05-29.** These produce the single advance = na event.
9. **Year-end stub weekly bars.** About 350 events, from the shared `week_bucketing` defect (PR #3283 in flight).
   Immaterial.
