# Read-only screens after the anchor experiment (2026-10-02, 26y investor s0)

Two questions the anchor result raised, answered from committed artifacts only
(`.sweep-output/investor-preset/inv26sc-investor-s0-v11-*`, build 6d84ff1c3, PR #3068) and the raw bar
store `data/<first>/<last>/<SYM>/data.csv`. Scripts: `results/tickets_extract.awk`,
`results/alts_extract.awk`, `results/graded_top.sh`, `results/episodes.awk`, `results/skips.awk`.
No backtest was run. These are proxy screens (`mechanism-validation-rigor.md`): they rule levers in or
out of *prioritisation*, they do not reject a mechanism.

## 1. Is a far-away graded top a post-crash phenomenon? No.

**Question.** After a crash the entry ticket (the 8–60-week max high, `breakout_price`) sits far above
the market, and on the investor preset the candidate is skipped (`No_structural_stop`: no correction low
within 15 % below that ticket). If this only happened after crashes, a "base-bounded" anchor (the top of
the range since the stock's last Stage 4 week) would be a targeted fix. If it happens in every regime,
it is another global lever like the local-range window that just diluted 6/6.

**Method.** The audit holds 599 entered tickets and 10,615 skipped alternatives (10,263
`No_structural_stop`, 231 `Insufficient_cash`, 118 `Sized_to_zero`, 3 `Share_class_held`); 7,231 unique
(symbol, decision date) pairs among the structural-stop skips. Skipped alternatives carry no price, so
the graded top is approximated as the max raw daily high 56–420 calendar days before the decision date,
divided by the raw close on that date (`graded_top.sh`). Calibration on the 599 entered tickets: that
proxy / `suggested_entry` averages 1.026, never below 0.95. Skips are recorded only in weeks that had an
entry, so months with no entry under-count (2009-05 → 08 has 19 skips against T1's 116 tickets).

**Entered tickets** sit at the market in every year: median ticket / close 1.02–1.06, **0 %** of entered
tickets ≥ 20 % above the close in any year (the structural-stop rule removes the far ones before entry).

**Skipped candidates**, graded-top proxy / close, by year:

| year | n | median | ≥ 1.10 | ≥ 1.20 | ≥ 1.50 |
|---|---:|---:|---:|---:|---:|
| 2000 | 288 | 1.19 | 68 % | 47 % | 21 % |
| 2002 | 16 | 1.47 | 88 % | 81 % | 44 % |
| 2003 | 257 | 1.08 | 46 % | 30 % | 11 % |
| 2004 | 230 | 1.05 | 33 % | 16 % | 6 % |
| 2007 | 188 | 1.07 | 41 % | 22 % | 9 % |
| 2009 | 192 | 1.15 | 55 % | 44 % | 24 % |
| 2011 | 189 | 1.02 | 23 % | 12 % | 3 % |
| 2013 | 371 | 1.02 | 23 % | 14 % | 5 % |
| 2017 | 427 | 1.02 | 22 % | 9 % | 3 % |
| 2019 | 310 | 1.09 | 44 % | 21 % | 8 % |
| 2020 | 355 | 1.09 | 48 % | 26 % | 8 % |
| 2022 | 130 | 1.17 | 68 % | 42 % | 12 % |
| 2023 | 400 | 1.11 | 54 % | 30 % | 14 % |
| 2025 | 505 | 1.11 | 53 % | 31 % | 13 % |

(All 26 years are in the script output; the omitted ones lie between 2004 and 2007 in shape.) In the
first 13 weeks after a gate reopen: 2009-05 89 % ≥ 1.20 (n = 19), 2002-03 81 %, 2000-07 71 %, 2022-08
68 %, 2003-05 46 %, but also 2000-03 37 %, 2016-04 36 %, 2025-05 36 %, 2020-06 33 %, 2010-10 32 %.

**Read.** Post-bear windows do have the farthest tops, but **9–30 % of skipped candidates in every calm
year** also sit ≥ 20 % under their graded top, and about half of all structural-stop skips are within
10 % of it (skipped because no correction low lies within 15 % below the ticket, not because the ticket
is far). A base-bounded anchor would therefore move a large share of candidates in every regime. Taken
with the local-range result (dilutes 6/6), moving the anchor is a global lever and is **not** the way to
target the recovery. **Do not build the base-bounded anchor.**

**Funnel fact worth keeping.** The investor preset enters 599 of about 10,900 top-20 candidates
(5.5 %); `require_structural_stop` is the dominant filter, the cash cap a distant second (231). After a
crash the floor under a candidate is the crash low, more than 15 % away, and the book's own rule
("prefer other candidates") is what keeps the preset out until bases have formed. The 2009 gap is the
cost of that rule, not a defect of the ticket.

## 2. The 2025 reopen: picks, not cash (and not path)

The gate reopened 2025-05-23 after 9 non-Bullish weeks. In the next 26 weeks SPY made +14.5 %; the
preset made −8.0 % with 19 entries in the window (21 by year end, −$267k; 10 stop exits, −$523k).

| symbol | entry | result | initial stop | raises | exit | 26-wk forward return of the stock |
|---|---|---:|---:|---:|---|---:|
| TNXP | 06-10 | −25.1 % | 5.6 % | 0 | stop | −48.1 % |
| AD | 08-04 | −29.4 % | 5.2 % | 0 | stop (gap) | +15.1 % |
| APPF | 08-11 | −4.0 % | 1.1 % | 0 | stop | −34.6 % |
| WBTN | 08-19 | −8.1 % | 6.0 % | 0 | stop | −23.0 % |
| FLG | 08-26 | −10.8 % | 10.6 % | 0 | stop | +4.7 % |
| UPWK | 09-30 | −4.1 % | 1.9 % | 0 | stop | −41.0 % |
| AIP | 11-10 | −12.3 % | 11.3 % | 0 | stop | +121.8 % |
| BALY | 11-10 | −12.6 % | 11.5 % | 0 | stop | −38.5 % |
| CVLT | 08-12 | −6.6 % | 10.9 % | 0 | laggard | −54.6 % |
| GILT | 07-18 | +66.1 % | 13.6 % | 8 | stop (trailed) | +126.4 % |
| MAR, KN, UTHR, ATAT, ATMU, PTGX | | +5.7 to +15.1 % | 11–14 % | 1–6 | mostly laggard | +20 to +71 % |

- **Same names in every salt.** 21 of the 22 entries appear in s1 and s2 as well (FLG is the one
  exception). The 2025 loss is a selection outcome, not a path lottery.
- **The picks themselves were a coin flip against the tape:** 26-week forward return of the 22 stocks
  from their entry dates: median +4.7 %, mean +8.7 %, 10 of 22 negative, against SPY +14.5 %. Dispersion
  is huge (−55 % to +126 %).
- **Stops cut two names that then rallied** (AIP −12 % then +122 %; AD −29 % gap then +15 %), but most
  stop-outs were on names that kept falling (TNXP, APPF, WBTN, UPWK, BALY). The stops were right more
  often than wrong.
- **Narrow structural stops (1.1 %, 1.9 %, 5 %) are not the lever**: over 26 years, < 6 % initial stops
  net +$598k (s0) / +$562k (s1) on 67–69 trades.

**Read.** 2025 is a stock-selection shortfall in a rising tape, consistent across salts. It is the same
shape as 2018–23 ("holdings lagged while the market rose") and the melt-up-lag law
(`project_melt_up_lag_anatomy`), not a re-entry gap and not a cash drag. No lever proposed from this
screen; it narrows the search away from entry timing and toward what the ranker picks in a narrow
rally (sector concentration of the tape vs the RS ranking), which is a different experiment.
