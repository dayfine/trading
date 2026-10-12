# breadth-fix-rb1-2026-10-11: the record with and without the NYSE A-D breadth gap (#3238)

**Pre-registration.** Nothing has run. Everything below is fixed before the first cell launches.

## Why

Until #3252, `trading/test_data/breadth/nyse_{advn,decln}.csv` held one 1965 row, then 2017-01-02 onward.
`Ad_bars.load` filled only the tail from Synthetic, so every 26-year run had no A-D breadth from 2000 to 2016.
The A-D inputs to the macro composite sat at a constant over those 17 years. The macro composite gates every long
entry (spine rule 6).

#3252 commits the full Unicorn archive and fills interior holes from Synthetic. On CI goldens it moved
`bull-crash-2015-2020` from −9.9 % to +36.4 % and `sp500-2010-2026-longshort` from 406 % to 675 %. Those are
small-universe cells, though, not the record. This experiment is the [after-merge] item of #3238: does the record
move?

## Design

- **Spec:** `specs/rb1-26.sexp`, the record spec from `rebaseline-v12-2026-10-08`, unchanged byte for byte below
  its header line.
  - Investor preset, 2000-01-01 → 2026-06-26.
  - Top-3000 PIT v12 schedule, total return (interest + dividends).
  - Warehouse `/tmp/snap_top3000_pit_v12pit`. Salts 0, 1, 2.
- **Arms** differ only by run tree. Both trees are pinned worktrees.
  - **O:** main just before the #3252 squash, with the old fixture.
  - **N:** the #3252 squash, with the full fixture and the interior-gap fill.
  - `launch.sh` aborts unless O's `nyse_advn.csv` has < 1,000 rows and N's has > 13,000.
  - It also aborts unless the schedule lists hash the same in both trees.
- **Same build:** lane O re-runs s0 first, and the driver compares it with `rebaseline-v12`'s `rb1-26-s0`
  (`trades.csv`, `actual.sexp`, `equity_curve.csv`).
  - If they are identical, the old rb1 s1/s2 cells stand as O's partners.
  - If not, lane O runs s1 and s2 too, and only lane O's cells pair with N.
- **Order:** one 26-year cell at a time, so 4 to 6 cells at about 3 h each (rb1 cells took 10,091–11,881 s).
  `CELL_TIMEOUT` is 36,000 s.

## What is read (per salt, then across salts)

1. **V6 gate.** Each N cell runs `validator_diff -check V6` against its same-salt O partner, and must exit 0. A
   V6 mismatch means that salt yields no delta.
2. **Macro change.** From `macro_trend.sexp`, the number of weekly readings whose `trend` or `breadth_state`
   differs between O and N, by year. They should concentrate in 2000–2020.
   - 2017–2020 can move too: the A-D momentum average spans about 200 weeks.
   - Any change after 2021 is a flag to trace.
3. **Record delta.** N − O on:
   - total return (log and %), CAGR, max drawdown, Sharpe, Calmar, trades;
   - the bear periods 2000-03-24 → 2002-10-09, 2007-10-09 → 2009-03-09 and 2022-01-03 → 2022-10-12;
   - the year table vs SPY total return.
4. **Where it comes from.**
   - Entries gained and lost (joined on `symbol|entry_date`), and the P&L of each set.
   - The weeks whose macro reading flipped and what was bought in them.
   - The largest contributors, traced end to end.

## Decision (fixed now)

This is a data correction, not a mechanism, so there is no accept/reject.

- **The N arm replaces rb1 as the record** whatever the direction of the delta: `project_investor_preset_broad` and
  the ledger are updated, and every later 26-year comparison pairs against N.
- **If any salt fails V6,** that salt is excluded. If two salts fail, the record is not replaced, and an issue is
  filed with the specimen.
- **Earlier 26-year verdicts** ran on the frozen A-D input. The writeup lists those that rest on a macro-gate effect,
  any of which could read differently on N:
  - macro-suspend (#3123);
  - the index-stage veto;
  - the shorts Phase B exposure path;
  - the D1/D2 and A-D default flips.
  Re-running them is not part of this experiment.

## Review

- A review pack for N s0–s2, rendered and looked at (`backtest-result-review.md`).
- The reading goes to `results-analyst`. The results PR goes to `qc-results`.

## Files

- `results/launch.sh`: run trees, input checks, staging, starts the driver.
- `results/driver-bp.sh`: lane order and the replay check.
- `results/chain-bp.sh`: a copy of `chain-rb12.sh` with paths moved and a cross-lane `PAIR_ART`.

## Log

- 2026-10-11: pre-registered. Sequencing per the user (2026-10-11): this experiment runs before the index-short
  overlay screen (`dev/plans/index-hedge-screen-2026-10-11.md`), whose base is the N arm.

## Results (2026-10-12)

Pre-registration `b42dfb9d9`; README, spec and chain scripts unchanged at the artifact commit `c45edfb85`. Reading by
`results-analyst`; scripts and outputs in `results/analysis/` (`run.sh` regenerates every figure from the committed
artifacts, the sweep-output `trade_audit.sexp` files, `data/S/Y/SPY/data.csv` and the two packs' daily series).

**Setup.**
- Arms: O = `eda54e591` (main just before #3252), N = `524bc2df0` (the #3252 squash); OLD = NEW^, so the trees differ by
  #3252 only. Each lane built in its own pinned tree; BUILD and HEAD checks pass (`results/chain-{O,N}.log`).
- Inputs (`results/launch-pre.log`): `nyse_advn.csv` 791 rows (O) vs 13,873 (N); schedule-list md5 `deca56c7…` in both
  trees; warehouse 9,236 entries; 11,880 `dividends.csv` staged per tree.
- Window 2000-01-01 → 2026-06-26 (last equity row 2026-06-25); PIT top-3000 v12 schedule (broad, U1 passes); salts 0–2.
- Hygiene (`results/driver.log`): one cell at a time; wall 8,207–10,634 s vs `CELL_TIMEOUT` 36,000 s; peak RSS 5.77–5.81 GB;
  cache misses 20,659, evictions 0, one absent symbol (MEL) per cell; six `exit=0`; metric-glob tripwire clean.
- N's runner carries #3252's gap warning and printed no `AD breadth gap` line in any `results/N-*.log`.
- Review pack (N s0–s2): https://claude.ai/artifact/HbW7eoNG9A4tuMNsEH6b6c (version 2, built from main `776e8d355`).

**A data correction: no accept/reject. No salt fails V6, so N replaces rb1 as the record.**

### In brief

- **The record moves by less than its own salt noise.** N − O = −0.003 / +0.019 / +0.073 log (mean +0.030); each arm's
  salt spread is 0.046 (O) and 0.044 (N). Max drawdown unchanged to 0.001 pp (its 2024-11 → 2026-06 episode has identical
  trades in both arms). Sharpe −0.016 / −0.011 / +0.002; trades +59 / +63 / +58.
- **What the old fixture did.** Over 2000–2016 two of the five macro votes were frozen: Momentum Index read "negative
  (−11.0)" (the net of the lone 1965-03-01 row, 550 − 561) and A-D Line read "Insufficient A-D data". All 296 O s0 entry
  decisions in 2000–2016 carry both readings: a standing Bearish vote. Bearish weeks fall 398 → 233 on N, all in
  2000–2016; no reading changes after 2016.
- **The unlocked weeks bought ordinary trades; capital, not the gate, bound.** Over 2000–16 N placed 70–75 more tickets
  and turned 114–122 more candidates away for cash. The tail swaps three for three in every salt: N gains PEGA 2016-10-31,
  GPN 2014-10-21, JNS 2014-10-14 (+$0.99M in s0), all bought in weeks O's gate was shut; it loses CHDN 2017-03-28,
  GTIV 2014-06-09, INVX 2005-08-22 (+$0.64M in s0), each skipped for `Insufficient_cash` in the week O bought it.
- **The path changes by period, and the periods offset** (N − O, log, s0 / s1 / s2): 2000–02 −0.044 / −0.046 / −0.043;
  2003–07 −0.009 / −0.010 / +0.055; 2008–09 −0.057 / −0.056 / −0.065; 2010–16 +0.090 / +0.114 / +0.109; 2017–18 +0.017;
  2019–26 +0.001 (trade lists identical from 2018-09-25).
- **Exposure, by regime and period.** Average invested 51 → 56 %. The extra exposure earned in SPY-UP days
  (+0.10 / +0.12 / +0.16 log) and gave it back in MIXED days (−0.10 / −0.11 / −0.10). DOWN days net to zero over the
  window but not by period: +0.058 in 2010–16 (V-rebounds at 54 % invested vs O's 21 %), −0.054 in 2008–09.
- **The early bears get worse on N.** 2000-03-24 → 2002-10-09 +9.0 % vs +15.2 % (s0); 2007-10-09 → 2009-03-09 −9.7 % vs
  −4.7 %; 2022 identical. Pre-2017 max drawdown 16.8–16.9 % → 18.9–19.8 %. The frozen vote had been defensive by accident
  at the 2000 and 2007 tops: the real NYSE A-D line read "diverging bullishly (index down, A-D up)" in 2001, mid-2007 and
  the spring-2008 rally.
- **New record (N) vs SPY total return:**

  | metric | N s0 / s1 / s2 | SPY TR |
  |---|---|---|
  | total return | +849 / +836 / +878 % | +706 % |
  | CAGR | 8.87 / 8.81 / 8.99 % | 8.20 % |
  | max drawdown | 22.5 / 22.2 / 22.2 % | 55.2 % |
  | Calmar | 0.39 / 0.40 / 0.41 | 0.15 |

- **The look found pack issues and two data defects** (§Defects found). None changes a number above.

### Same-build replay (driver step 1)

The driver compared O s0 byte for byte with `rebaseline-v12`'s rb1-26-s0, found a difference, and as pre-registered ran
O s1 and s2 too (`results/driver.log`: "REPLAY … differs"). `actual.sexp`, `equity_curve.csv`, `macro_trend.sexp` and
`open_positions.csv` are byte-identical to `.sweep-output/rebaseline-v12/rb1-26-s{0,1,2}-v12-*` for all three salts.
`trades.csv` differs only in reporting merged after 10-08: a new `dividends_received` column and 149 / 151 / 145
`stop_trigger_kind` relabels `gap_down` → `intraday`; every other column matches row for row. So O is the existing record,
simulation-identical. The extra cells cost about 5.1 h (9,633 + 8,708 s) and changed nothing.

### 1. V6 gate: PASS on all three salts

| salt | O V6 | N V6 | `validator_diff -check V6`, N vs O |
|---|---|---|---|
| 0 | 0 | 0 | exit 0 |
| 1 | 0 | 0 | exit 0 |
| 2 | 0 | 0 | exit 0 |

V6 counts: `n_violations 0` in `results/{O,N}-rb1-26-s{0,1,2}-v12-validator.sexp.sexp`. Exits: `v6diff:rb1-26:exit=0` in
`results/chain-N.log` (pair directory = lane O's). The wider audit moves with the trade list, as expected (O → N): V7
24→23 / 23→24 / 23→23; V12 23→28 / 31→39 / 23→29; V13 18→21 / 18→18 / 20→19; V23 40→16 / 39→16 / 36→15. V16 goes from
PASS to 1 in each N salt: NLC 2011-08-11 `stale_force_exit` (Defect 3).

### 2. Macro change

`macro_trend.sexp` is identical across salts within each arm (md5), so this is one table
(`results/{O,N}-rb1-26-s0-v12-macro_trend.sexp`, 1,335 weekly readings).

| year | readings | trend differs | O Bull / Neu / Bear | N Bull / Neu / Bear |
|---|---:|---:|---|---|
| 2000 | 51 | 19 | 10 / 21 / 20 | 4 / 16 / 31 |
| 2001 | 50 | 10 | 0 / 2 / 48 | 0 / 12 / 38 |
| 2002 | 51 | 8 | 1 / 3 / 47 | 1 / 11 / 39 |
| 2003 | 50 | 5 | 34 / 0 / 16 | 34 / 5 / 11 |
| 2004 | 50 | 28 | 20 / 8 / 22 | 44 / 4 / 2 |
| 2005 | 51 | 28 | 23 / 17 / 11 | 51 / 0 / 0 |
| 2006 | 51 | 18 | 33 / 5 / 13 | 44 / 7 / 0 |
| 2007 | 51 | 22 | 26 / 6 / 19 | 38 / 11 / 2 |
| 2008 | 50 | 9 | 0 / 4 / 46 | 4 / 6 / 40 |
| 2009 | 49 | 8 | 30 / 3 / 16 | 33 / 5 / 11 |
| 2010 | 50 | 28 | 22 / 8 / 20 | 37 / 13 / 0 |
| 2011 | 51 | 29 | 16 / 4 / 31 | 33 / 12 / 6 |
| 2012 | 51 | 26 | 25 / 11 / 15 | 46 / 5 / 0 |
| 2013 | 51 | 7 | 44 / 7 / 0 | 51 / 0 / 0 |
| 2014 | 50 | 18 | 32 / 12 / 6 | 49 / 1 / 0 |
| 2015 | 49 | 18 | 15 / 14 / 20 | 29 / 9 / 11 |
| 2016 | 51 | 24 | 20 / 18 / 13 | 42 / 2 / 7 |
| 2017–2026 | 579 | **0** | identical | identical |

- **305 readings change trend, all in 2000–2016:** Neutral→Bullish 111, Bearish→Neutral 91, Bearish→Bullish 85,
  Neutral→Bearish 11, Bullish→Neutral 7. Gate effect (Bearish blocks longs, Neutral admits): 176 weeks open on N that O
  had shut; 11 shut that O had open (all 2000).
- **2017–2020 did not move**, so the post-2021 flag does not fire. O's momentum average held the 1965 row until it covered
  more than 200 weeks, but both arms' momentum stayed positive through the 2017–20 bull, so every label agrees.
- **`breadth_state` differs in 302 weeks, never without a trend change.** Bearish_breadth coincides with trend Bearish in
  every week of both arms (398/398, 233/233), by construction: `Breadth_direction._classify_reading` maps a Bearish trend
  to Bearish_breadth first, and its fallback is `breadth_state_of_market_trend`. So the pack's "Macro at entry: Bearish"
  and "Breadth at entry: Bearish_breadth" cohorts are always the same trades.
- Deteriorating 52 → 85 weeks, Recovering 17 → 30; `deteriorating_blocks_longs` is off, so neither gates.

### 3. Record delta

Sources: `results/*-actual.sexp`; CAGR from `results/*-summary.sexp`; log = ln(1 + TR).

| metric | O s0 / s1 / s2 | N s0 / s1 / s2 | N − O |
|---|---|---|---|
| total return | 851.8 / 818.4 / 809.5 % | 849.3 / 836.0 / 878.3 % | −2.5 / +17.6 / +68.8 pp |
| log return | 2.2532 / 2.2175 / 2.2077 | 2.2505 / 2.2364 / 2.2806 | −0.003 / +0.019 / +0.073 (mean +0.030) |
| CAGR | 8.88 / 8.73 / 8.69 % | 8.87 / 8.81 / 8.99 % | −0.01 / +0.08 / +0.30 pp |
| max drawdown | 22.519 / 22.194 / 22.187 % | 22.519 / 22.193 / 22.188 % | 0.000 |
| Sharpe (excess) | 0.542 / 0.533 / 0.533 | 0.526 / 0.522 / 0.534 | −0.016 / −0.011 / +0.002 |
| Sortino | 1.028 / 1.011 / 1.014 | 0.986 / 0.976 / 1.001 | −0.043 / −0.035 / −0.013 |
| Calmar | 0.394 / 0.393 / 0.392 | 0.394 / 0.397 / 0.405 | −0.001 / +0.004 / +0.014 |
| trades | 511 / 512 / 510 | 570 / 575 / 568 | +59 / +63 / +58 |
| volatility | 13.3 % | 13.8–13.9 % | +0.5 pp |

- SPY TR, same dates: +705.8 %, log 2.0866, CAGR 8.20 %, max DD 55.2 % (2007-10-09 → 2009-03-09); base = the 2000-01-03
  adjusted close (the pack's and the ledger's convention).
- Scale: the mean delta is +0.11 pp/yr of CAGR; each arm's salt spread is wider than it. Only s2's +0.073 falls outside,
  and it comes from 2003–07.
- The max drawdown cannot move: it is the 2024-11-26 → 2026-06-24 episode in all six cells, on identical trades.

**Bear periods** (close to close; NAV and invested % from the packs' daily series):

| bear | SPY | O s0 / s1 / s2 | N s0 / s1 / s2 | invested, O → N | in-period max DD, O → N |
|---|---:|---|---|---|---|
| 2000-03-24 → 2002-10-09 | −47.5 % | +15.2 / +15.1 / +14.5 % | +9.0 / +8.7 / +8.4 % | 20.3 → 16.2 % | 6.9 → 9.1 % |
| 2007-10-09 → 2009-03-09 | −55.2 % | −4.7 / −4.6 / −4.7 % | −9.7 / −9.6 / −10.4 % | 8.6 → 21.9–23.3 % | 8.4 → 11.6–11.9 % |
| 2022-01-03 → 2022-10-12 | −24.5 % | −8.6 / −8.3 / −8.1 % | same | 50.7 % in both | 12.3–12.8 % in both |

**Year table vs SPY TR** (%, from `results/*-equity_curve.csv`; 2026 runs to 06-25):

| year | O s0 / s1 / s2 | N s0 / s1 / s2 | SPY | N − O (pp) |
|---|---|---|---:|---|
| 2000 | +16.9 / +16.9 / +16.2 | +14.7 / +14.6 / +14.0 | −8.8 | −2.2 / −2.3 / −2.2 |
| 2001 | −4.5 / −4.5 / −4.5 | −5.9 / −5.9 / −5.8 | −11.8 | −1.4 / −1.5 / −1.3 |
| 2002 | +0.6 / +0.6 / +0.6 | −0.5 / −0.5 / −0.5 | −21.6 | −1.1 / −1.1 / −1.0 |
| 2003 | +21.8 / +22.1 / +22.9 | +21.8 / +22.1 / +22.9 | +28.2 | 0.0 |
| 2004 | +13.3 / +12.6 / +10.5 | +19.6 / +18.9 / +24.5 | +10.7 | +6.3 / +6.3 / +13.9 |
| 2005 | +5.5 / +5.4 / +5.3 | +3.8 / +3.8 / +3.8 | +4.8 | −1.7 / −1.6 / −1.5 |
| 2006 | +26.5 / +26.4 / +26.6 | +17.2 / +17.1 / +17.1 | +15.8 | −9.3 / −9.3 / −9.5 |
| 2007 | +5.4 / +5.4 / +5.5 | +8.5 / +8.4 / +8.6 | +5.1 | +3.1 / +3.0 / +3.0 |
| 2008 | +2.9 / +2.9 / +2.9 | −2.8 / −2.7 / −3.6 | −36.8 | −5.7 / −5.6 / −6.5 |
| 2009 | +3.1 / +3.1 / +2.9 | +3.1 / +3.1 / +2.9 | +26.4 | 0.0 |
| 2010 | +32.1 / +32.0 / +32.1 | +29.7 / +29.6 / +29.7 | +15.1 | −2.4 |
| 2011 | +1.5 / +1.5 / +1.3 | −1.7 / −1.7 / −2.0 | +1.9 | −3.2 / −3.2 / −3.3 |
| 2012 | +10.0 / +9.8 / +9.9 | +10.5 / +10.3 / +10.3 | +16.0 | +0.5 / +0.6 / +0.4 |
| 2013 | +27.1 / +21.9 / +22.1 | +29.5 / +25.0 / +29.5 | +32.3 | +2.4 / +3.1 / +7.4 |
| 2014 | +9.1 / +11.6 / +11.6 | +8.9 / +13.3 / +9.0 | +13.5 | −0.2 / +1.7 / −2.6 |
| 2015 | −0.5 / −1.1 / −0.9 | +8.0 / +7.6 / +7.7 | +1.2 | +8.5 / +8.6 / +8.6 |
| 2016 | +1.8 / +1.8 / +1.8 | +5.6 / +5.6 / +5.7 | +12.0 | +3.8 / +3.8 / +3.9 |
| 2017 | +16.2 / +15.9 / +16.3 | +19.7 / +19.5 / +19.8 | +21.7 | +3.6 / +3.5 / +3.5 |
| 2018 | −6.7 / −6.5 / −6.5 | −7.9 / −7.8 / −7.7 | −4.6 | −1.2 / −1.3 / −1.3 |
| 2019–2026 | identical in both arms | | | 0.0 (2021 +0.1) |

Over 2000–2016, N − O by year is a coin flip with fat tails: 6 / 7 / 6 years positive and 9 / 8 / 9 negative; median
−0.2 / −0.0 / −1.0 pp; range −9.5 to +13.9 pp.

**Regime split by period (RV2).** Strategy returns and invested % from the packs' daily series (`site/data/s<N>_nav.json`);
regime = SPY weekly close vs its 30-week MA and the MA's 4-week slope, applied the following week, with a pre-window
warm-up as in #3255. Cells: strategy / SPY cumulative return, then average invested.

| period | regime | days | O s0 | N s0 | N − O log, s0 / s1 / s2 |
|---|---|---:|---|---|---|
| 2000–02 | UP | 161 | +1.7 / −24.2 % @ 46 % | −0.0 % @ 32 % | −0.017 / −0.016 / −0.016 |
| | MIXED | 143 | +7.5 / +11.2 % @ 19 % | +6.4 % @ 16 % | −0.010 / −0.011 / −0.010 |
| | DOWN | 447 | +2.7 / −25.2 % @ 9 % | +0.9 % @ 9 % | −0.018 / −0.019 / −0.017 |
| 2003–07 | UP | 952 | +91.3 / +43.7 % @ 64 % | +105.4 % @ 72 % | +0.071 / +0.072 / +0.115 |
| | MIXED | 216 | +3.2 / +6.3 % @ 57 % | −6.0 % @ 69 % | −0.094 / −0.095 / −0.087 |
| | DOWN | 90 | −1.6 / +18.7 % @ 16 % | −0.3 % @ 28 % | +0.014 / +0.014 / +0.027 |
| 2008–09 | UP | 145 | +3.0 / +21.7 % @ 20 % | +3.0 % @ 20 % | 0.000 |
| | MIXED | 49 | +0.3 / −1.7 % @ 3 % | −0.1 % @ 6 % | −0.003 |
| | DOWN | 311 | +2.7 / −33.2 % @ 6 % | −2.7 % @ 10 % | −0.054 / −0.053 / −0.062 |
| 2010–16 | UP | 1,377 | +64.8 / +59.0 % @ 63 % | +70.7 % @ 70 % | +0.035 / +0.058 / +0.053 |
| | MIXED | 197 | +7.1 / −4.2 % @ 37 % | +6.8 % @ 59 % | −0.003 |
| | DOWN | 188 | +17.3 / +52.0 % @ 21 % | +24.3 % @ 54 % | +0.058 / +0.059 / +0.059 |
| 2017–18 | all | 502 | +8.4 / +16.1 % @ 74 % | +10.2 % @ 76 % | +0.017 |
| 2019–26 | all | 1,880 | +83.4 / +228.4 % @ 59 % | +83.5 % @ 59 % | +0.001 |
| whole | UP | 4,459 | +503 / +469 % @ 63 % | +567 % @ 67 % | +0.10 / +0.12 / +0.16 |
| | MIXED | 885 | +12.7 / −15.0 % @ 41 % | +1.7 % @ 49 % | −0.10 / −0.11 / −0.10 |
| | DOWN | 1,314 | +40.0 / +66.7 % @ 16 % | +39.9 % @ 23 % | −0.000 / +0.001 / +0.007 |

Perturbation: without the warm-up the whole-window split reads UP +0.12 / +0.14 / +0.18 and MIXED −0.11 / −0.11 / −0.10;
with a two-state split (above/below the 30-week MA, no slope) MIXED days land on both sides (above +0.03 / +0.05 / +0.10,
below −0.034 / −0.034 / −0.025). Either way, the extra exposure earns in rising tapes and gives most of it back in
transitions and declines.

### 4. Where it comes from

**Entries gained and lost, joined on `symbol|entry_date`** (`results/{O,N}-rb1-26-s*-v12-trades.csv`), each classified
by the other arm's gate in its decision week (`placement_date` from `trade_audit.sexp`, gate from `macro_trend.sexp`):

| | s0 | s1 | s2 |
|---|---|---|---|
| common entries | 467 | 473 | 464 |
| gained (N only) | 103, +$1,012k | 102, +$1,318k | 104, +$1,266k |
| – decided in a week O read Bearish | 80, +$990k | 79, +$1,000k | 83, +$1,060k |
| – decided in a week O was open | 23, +$23k | 23, +$318k | 21, +$205k |
| lost (O only) | 44, +$877k | 39, +$1,073k | 46, +$824k |
| – decided in a week N read Bearish (2000) | 5, +$11k | 5, +$11k | 5, +$11k |
| – decided in a week N was open | 39, +$866k | 34, +$1,062k | 41, +$814k |
| common trades' P&L, O → N | $5,149k → $4,826k | $4,589k → $4,390k | $4,780k → $4,791k |
| realised P&L, N − O | −$187k | +$45k | +$453k |

**Distributions** (per-trade P&L; `results/analysis/read4_cls_s*.txt`):

| set | n | median | win rate | sum | sum without its top 3 |
|---|---|---|---|---|---|
| gained, O's gate shut | 80 / 79 / 83 | −$8.7k / −$7.5k / −$8.0k | 44 / 44 / 43 % | +$0.99 / 1.00 / 1.06M | +$0.5k / +$19k / +$43k |
| lost, N's gate open | 39 / 34 / 41 | +$1.6k / +$5.9k / +$0.7k | 59 / 62 / 56 % | +$0.87 / 1.06 / 0.81M | +$0.23 / 0.44 / 0.20M |

The unlocked cohort has the record's usual shape: a losing median and a sum that is three trades. The displaced set won
more often (mostly O's first buys after its own gate reopened); with n = 34–41 the uncertainty is about ±8 pp, and the
salts are not independent.

**Why each entry is missing from the other arm** (second method: the other arm's `cascade_summaries` outcome for that
symbol in that decision week; agrees with the classification above):
- O-only entries, as N saw them: `Skipped_Insufficient_cash` 32 / 27 / 32; N's gate shut 5 / 5 / 5; placed in N but filled
  on another date 6 / 6 / 7; not in N's decisions 1 / 1 / 2.
- N-only entries, as O saw them: O's gate shut 80 / 79 / 83; `Skipped_Insufficient_cash` 12 / 16 / 11; placed in O but
  filled on another date 7 / 5 / 7; not in O's decisions 4 / 2 / 3.
- Over 2000–16, N placed 371 / 374 / 367 tickets vs O's 296 / 299 / 297, and skipped 262 / 259 / 270 candidates for cash
  vs O's 147 / 145 / 148.

**The weeks that flipped, and what was bought in them** (N's tickets decided in the 176 weeks O had shut):

| period | weeks | placed | filled | closed P&L, s0 / s1 / s2 |
|---|---:|---:|---:|---|
| 2000–02 | 18 | 3 | 2 | −$25k / −$27k / −$25k |
| 2003–07 | 66 | 34–35 | 27–30 | +$160k / +$157k / +$200k |
| 2008–09 | 11 | 1 | 1 | −$23k / −$20k / −$22k |
| 2010–16 | 81 | 57–58 | 50–51 | +$902k / +$914k / +$930k |

In the 11 weeks N shut and O had open (all 2000), O made 5 entries worth +$11k.

**Biggest contributors.** 26 trades above $150k are in all six cells; the rest of the tail swaps three for three:

| arm | trade | P&L, s0 / s1 / s2 | why the other arm lacks it |
|---|---|---|---|
| N only | PEGA 2016-10-31 → 2017-08-21, +78.0 % | +$496k / +$491k / +$509k | O Bearish on 2016-10-28 |
| N only | GPN 2014-10-21 → 2015-11-16, +83.6 % | +$307k / +$305k / +$316k | O Bearish on 2014-10-17 |
| N only | JNS 2014-10-14 → 2015-05-04, +36.5 % | +$187k / +$186k / +$192k | O Bearish on 2014-10-10 |
| O only | CHDN 2017-03-28 → 2018-08-06, +76.6 % | +$250k / +$242k / +$238k | N `Insufficient_cash` on 2017-03-24 |
| O only | GTIV 2014-06-09 → 2015-01-12, +36.0 % | +$196k / +$188k / +$184k | N `Insufficient_cash` on 2014-06-06 |
| O only | INVX 2005-08-22 → 2006-09-11, +93.3 % | +$192k / +$191k / +$188k | N `Insufficient_cash` on 2005-08-19 |

**Dollar bridge, final NAV N − O** (`results/*-summary.sexp`):

| component | s0 | s1 | s2 |
|---|---|---|---|
| realised P&L | −$187k | +$45k | +$453k |
| dividends (N holds more stock) | +$206k | +$153k | +$198k |
| cash interest | −$40k | −$25k | +$15k |
| unrealised at the end | −$1k | +$10k | +$37k |
| commissions and rest | −$4k | −$7k | −$16k |
| **total** | **−$25k** | **+$176k** | **+$688k** |

### Traced end to end

1. **PEGA, a winner the unfrozen gate let in** (week of 2016-10-28, audit `PEGA-wein-785`). N's macro: Index Stage
   Neutral ("Stage 1 base"; weight 3, inactive), A-D Line Bullish ("confirming index advance", 2), Momentum Bullish
   (+518.8, 2), NH-NL Bearish (1.5), Global Bullish (1.5): composite 5.5 / 7.0 = 0.786 > 0.65 → Bullish. O sees the same
   three non-A-D votes but A-D "Insufficient A-D data" and Momentum "negative (−11.0)": 1.5 / 5.0 = 0.30 < 0.35 → Bearish
   (default weights and thresholds, `macro_types.ml`). O admits nothing that week; N admits 1,933 candidates and places one
   ticket, PEGA (score 95, trigger 30.38, stop 28.85, $628,623 planned). Fills 2016-10-31 at 30.70, exits by laggard
   rotation 2017-08-21 at 54.65: +$495,573 (s0).
2. **CHDN, PEGA's displaced partner** (week of 2017-03-24, audit `CHDN-wein-578`; both arms Bullish, all five indicators
   Bullish). O holds 8 positions at 71.7 % invested and places DY and CHDN. N holds 9 at 88.9 %, places DY, skips CHDN for
   cash; its one extra holding is PEGA ($635k marked). In O, CHDN fills 2017-03-28 at 157.95, exits 2018-08-06 at 279.00:
   +$249,959.
3. **INVX, displaced by the spring-2005 buys** (week of 2005-08-19; both arms Bullish, O's composite 6 / 8 = 0.75 even with
   the −11.0 vote). O holds 7 at 64.3 % and places DP, INVX, MSTR; N holds 10 at 85.2 %, places DP, skips INVX and MSTR for
   cash. N's four extra holdings were all decided in weeks O read Bearish: GILD (05-04), EGP (05-19), PEET (05-20), MHX
   (06-27). INVX in O: 2005-08-22 at 38.61 → 2006-09-11 at 74.61, +$192,220 — most of N's 2006 shortfall (−9.3 pp). The
   rebaseline-v12 ledger lists INVX among the four monsters "in all six cells"; it is in no N cell.
4. **WMB, a bear-rally entry** (week of 2008-05-02). N: Index Bearish ("Stage 3 top", 3), A-D Bullish ("diverging bullishly
   (index down, A-D up)", 2), Momentum Bullish (+496.8, 2), NH-NL Neutral, Global Bearish (1.5): 4 / 8.5 = 0.47 → Neutral,
   which admits longs. O: 0 / 6.5 → Bearish. WMB fills 2008-05-05 at 37.93, stopped 2008-07-17 at 33.22: −$23,239. Same
   shape: LMT (decided 2007-08-03; N 0.73 Bullish, O Bearish; −$21,483) and DIN (decided 2001-06-15; N 0.41 Neutral, O 0.23
   Bearish; filled 2001-09-17, −$14,149).

### Verdict (calibrated)

- **Per the pre-registration:** V6 passes on all three salts, so N replaces rb1 as the record.
- **What this design can claim:** on this preset and capacity, the record's whole-window numbers are insensitive to the
  A-D fix. The mean paired delta (+0.030 log) is inside either arm's salt spread; the max-drawdown episode and every trade
  after 2018-09-24 are unchanged. The 2000–2016 path does change: 305 macro readings, ~60 more trades, −0.07 to +0.11 log
  by period, a deeper pre-2017 drawdown.
- **What it cannot claim:** that breadth "does not matter" as a mechanism, or that N is better or worse. This is one
  config with one input changed, not a surface; the three salts are path seeds on one candidate path, not independent
  contexts; and the delta is small at this capacity because capital binds — under a different capacity the same unlocked
  weeks could matter more.

### Why

The fix freed the gate, but the gate was not what limited the book.

1. **Gate state.** The single 1965 row left two votes frozen through 2000–2016: a constant Bearish momentum vote (weight
   2), and no A-D Line vote (one weekly bar is below `ad_min_bars` 4; `macro_indicators.ml`, `ad_series_cache.ml`). So O
   could read Bullish only when the index was in early Stage 2 and NH-NL or Global agreed; any index pause with a negative
   NH-NL proxy turned it Bearish. O's extra Bearish weeks sit in bull-market corrections (Bearish weeks O / N: 2004 22 / 2,
   2006 13 / 0, 2007 19 / 2, 2010 20 / 0, 2011 31 / 6, 2012 15 / 0).
2. **Admission against capital.** N used those weeks: 97 / 95 / 97 tickets placed, 81 / 80 / 84 filled, +$1.01–1.08M. But
   the book runs with a 70 % long cap, a 30 % cash floor and a 14 % position cap, and in 2003–07 and 2010–16 N sat near the
   cap (69–71 % and 67–68 % invested). Each extra placement turned away about 1.5–1.7 more candidates for cash, and 27–32
   of O's later trades were exactly those candidates. Admission changed which names held the capital far more than how
   much was at work (+5 pp invested over 26 years).
3. **Fat tail.** The unlocked cohort has a losing median and its sum is three trades (PEGA, GPN, JNS); the displaced tail is
   three trades too (CHDN, GTIV, INVX). The swap nets +$0.35M in s0; smaller common trades take it back (N entered 2010
   with 5–10 % less NAV after the early bears, −$0.10M to −$0.25M in 2010–16), and so does the displaced set's better
   middle (+$0.20M to +$0.44M without its top 3).
4. **Timing, by period.** Real breadth reopened the gate earlier after bull-market corrections (N 2010-08-06, 2011-11-04,
   2016-03-11 vs O 2010-10-08, 2012-01-20, 2016-04-22), which bought the 2010–16 V-rebounds (DOWN-day exposure 54 % vs 21 %,
   +0.058 log). It also bought into tops and bear rallies: the NYSE A-D line rose while the index fell in 2001, mid-2007 and
   spring 2008, and the 200-week momentum average stayed positive deep into 2008. N read Bearish in 2 weeks of 2007 against
   O's 19 and entered 2008 at 74.4 % invested (7 positions) against O's 17.6 % (2). Net: −0.10 log across the two early
   bears, +0.09 to +0.11 in 2010–16, and in 2003–07 a salt-dependent wash (MIXED −0.09, UP +0.07 to +0.11).
5. **Convergence.** From 2017 the inputs are identical and holdings turn over within a year or two (average hold 92 days,
   laggard rotation). From 2018-09-25 both arms fill the same entries on the same days.
6. **Cost and turnover.** ~60 more trades at lower expectancy ($10.2k vs $11.8k per trade, s0); dividends +$153–206k,
   interest −$25–40k in s0/s1; Sharpe and Sortino dip because volatility rises with exposure (13.3 → 13.9 %) while return
   does not.

### How it fits what we know

- **Confirms** the fat-tail edge, the funding-grid monster lottery, the top-N capacity verdict and the concentration/deploy
  probe: at this capacity an admission change re-draws which monsters get funded — the same law seen from the macro side.
- **Confirms** macro-suspend dilutes (#3123): all 16 / 16 / 15 of N's fills after a Bearish screen (V23) are resting
  tickets placed in Neutral or Bullish weeks, 1–33 weeks old (GRA placed 2015-06-05, filled 2016-01-22, −$70,526; ISEE
  2022-09-16 → 2022-09-30, −$71,974; STN 2025-03-21 → 2025-05-01, +$184,630).
- **Refines** the record's era story: part of "eroded 2009–12 … also cash through rebounds", and of the 2010–16 rebound
  cash, was the frozen vote. On N, 2009–12 DOWN-day exposure is 45 % vs O's 20 %; what remains is selection in UP days
  (+17.1 % vs SPY +30.1 % at 62 % invested).
- **Confirms** the recovery re-entry gap: the 2009 sit-out is not an A-D artifact (N reopened 2009-05-01, O 2009-05-08;
  neither placed anything for 13 weeks; trade lists identical from 2009-10-19).
- **Unchanged:** the PIT 2021–25 macro-veto reading and the 2025–26 picks diagnosis (post-2017, arms identical).
- **Contradiction to dig:** the 06-23 A-D default-flip record (`dev/backtest/ad-grid-2026-06-23/STATUS.md`) says
  `test_data` held the Unicorn 1965 → 2020-02 archive at the flip, but the committed fixture held 791 rows (1965, then 2017
  onward) from its first commit `6d061a18c` (#270, 2026-04-11) until #3252. Unless that session's working copy differed,
  the grid's "A-D live" arm was live only from 2017 in its deep and post-GFC cells.
- **Record change:** the rebaseline-v12 "ADMA / GLNG / MMYT / INVX in all six cells" becomes ADMA / GLNG / MMYT plus PEGA,
  GPN, JNS on N; INVX, CHDN and GTIV leave the record.

### Earlier 26-year verdicts that rest on the macro gate (pre-registered list; no re-runs)

| verdict | how it depends on the gate | on N | plausibly reads differently? |
|---|---|---|---|
| macro-suspend (#3123, 10-04; keep as axis) | suspends resting tickets in Bearish weeks | 5d window (2007-06-01 → 2012-06-29): 139 Bearish weeks on O, 59 on N; 5r (2021-06 → 2026-06) identical | 5d leg yes; 5r no. Low stakes, default off |
| index-stage veto (09-21; REJECT-as-default, keep axis) | blocks longs on a Stage-4 index the composite does not call Bearish | its mechanism (c), "2001–02 and 2008 inert — composite already Bearish", is partly the frozen vote: 18 weeks of 2001–02 and 6 of 2008 are non-Bearish on N where O was Bearish | the 2000–16 leg possibly, only where the index was in Stage 4 (DIN and WMB read Stage 3). The decisive 2020 and 2022 legs are unchanged |
| shorts Phase B exposure path (10-10; stopped) | `neutral_blocks_shorts true`: shorts only in Bearish weeks | 165 fewer Bearish weeks, almost all 2004–16 bull corrections, where an SPY short loses | the −0.30 log exposure-timing term is plausibly smaller; the single-name term cannot be judged here. The index-hedge screen's G3 arm re-measures it on N |
| D1/D2 default flip (09-03) | none (exit-fill correctness flip) | — | no |
| A-D default flip (06-23 grid, ACCEPT) | the flip itself | see the contradiction above; its cells were sp500, which `universe-discipline.md` no longer admits as evidence | yes; dig before relying on it |

Also macro-dependent, outside the list: the deteriorating gate (Deteriorating weeks 52 → 85, all 33 new ones before 2017;
its 2020 and 2022–23 evidence unchanged) and stop-width-by-macro-state (the 2000–16 state mix shifts toward Bullish).

### What it implies next

1. **N is the record** (pre-registered). Every later 26y comparison pairs against N s0–s2 at the same salt, gated on
   `validator_diff -check V6`.
2. **The index-short overlay screen** (`dev/plans/index-hedge-screen-2026-10-11.md`) runs on N as planned:
   - G2 and G3 read N's `macro_trend.sexp` (233 Bearish weeks). The plan's Phase B exposure-path figure was measured on the
     frozen macro; G3 on N re-measures it at no extra cost.
   - Criterion 3 has more room on N: N's base does worse in the first two bears than the old record did.
   - Criterion 2 (combined max DD ≥ 3 pp better) is probably hard: the base's max DD is the 2024-11-26 → 2026-06-24 picks
     drawdown in a rising market, where SPY spent 29 days in the pack's DOWN regime (April–May 2025) and rose +17.6 % across
     them. A short look at G1's 2025 episode before the full screen shows whether any cell can pass it. The rule stands as
     written.
3. **Do not search macro-gate dials for return.** At this capacity the gate is not the binding constraint; loosening it
   reshuffled the fat tail and tightening it would too (A-D weights and thresholds included).
4. **Re-read the macro-dependent records above, cheaply** — first the A-D-flip provenance (a docs read), then the
   index-stage veto's 2000–16 leg. Each needs a 26y re-run on N for a fresh verdict; none is urgent.
5. **The live gaps are unchanged:** the 2009 re-entry (No_structural_stop skips) and the 2025–26 picks.

### Defects found

1. **Pack: macro at entry reads the screen that ran after a Friday fill.** `dev/lib/review_pack/assemble.awk` `macro_at(d)`
   takes the last reading dated `<= d`; the screen runs at Friday's close, so a Friday fill has not seen it. V23 uses the
   latest screen strictly before the fill (`validator_audit_checks.ml` `_last_screen_before`). N s0: card 14, V23 16; O s0:
   38 vs 40. Specimens: counted by the pack, not V23 — TWX1 2000-01-28, KSL 2011-08-19; missed by the pack — WDFC
   2011-10-14, MEI 2004-08-20, LIN 2019-02-15. The "Macro / Breadth at entry" cohorts and "Macro not with the side" use the
   same join. Fix: `md[i] < d`, pinned in `review_pack_test.sh` against V23's rule.
2. **Pack built from a stale tree.** Version 1 of the published pack was built from the parent tree at `eda54e591`, before
   #3255 (regime warm-up) and #3253, and against the v11 snapshot default. Rebuilt from main `776e8d355` with
   `--snapshot-dir /tmp/snap_top3000_pit_v12pit` and republished as version 2 (the 2000–02 era now reads UP −0 / −24 % at
   32 %). Detector: stamp the pack code's SHA in the page header.
3. **Pack: "Fill dated on a non-trading day: 1 (net $70k)" is not a Saturday fill.** It is NLC's `stale_force_exit` on
   2011-12-06 after the Nalco–Ecolab merger closed (last Nalco bar 2011-12-01, close 38.80). The pack's after-last-bar
   exclusion does not fire because `data/N/C/NLC/data.csv` carries a different listing under the reused ticker (1,038 bars,
   2013-12-16 → 2018-01-30, zero-volume at first; V18 flags 2015-04-15). The simulator handled the exit correctly (V16
   quality flag, deal price, +$70,157). NLC is an N-only, gate-unlocked entry (O read Bearish on 2011-08-05).
4. **Pack wording.** "Entered against the macro … the macro gate should block both": with `entry_ticket_macro_suspend Off`
   (default) the gate blocks placements, not fills, and all 16 of N s0's are resting tickets. Say so, or read V23.
   Cosmetic: "1 trades have …", "1 fallback exits".
5. **Data: the new NYSE A-D fixture has 38 rows dated on NYSE holidays in 1999–2019** (27 in 2005–2008; e.g. 2006-07-04,
   2006-12-25, 2007-01-02), one Saturday row (2009-10-24), and lacks 1999-11-26 and 2002-06-20. `daily_to_weekly` sums daily
   counts, so each extra row adds a day's net to its week. Low impact (5–9 rows a year in 2005–08).
6. **Data: the NLC ticker-reuse splice** (Defect 3) belongs with the #2672 delisting-guard family.
7. **Process.** The replay check compared `trades.csv` byte for byte, so a reporting-only change cost a 5.1 h re-run;
   compare `actual.sexp` + `equity_curve.csv` instead. The three `v6diff` logs were not committed.

## Review-pack look

Pack: N s0–s2, https://claude.ai/artifact/HbW7eoNG9A4tuMNsEH6b6c. Version 1 was rendered and all twelve images
(`top.png`, `part-1.png` … `part-11.png`) read by the dispatcher and again by the analyst; version 2 (rebuilt from main)
was rendered and its overview and era pages re-read.

Checked:
- **Window:** equity, drawdown and macro charts span 2000-01-03 → 2026-06-25.
- **KPI strip vs `results/N-rb1-26-s0-v12-actual.sexp`:** +849 %, CAGR +8.9 %, max DD −22.5 %, Sharpe 0.53, 570 trades,
  win rate 40.2 %, 92-day average hold, 4 open — all match. SPY "+706 %" is based at the 2000-01-03 close.
- **Text:** no mojibake, `NaN`, `undefined` or empty panels.
- **Counts the config implies:** 4 % fallback stops 0 (`require_structural_stop` on); stops breached before the exit day
  0, and 0 of 187 unraised stop exits filled on a later open (trigger-bar fills on). "Entered against the macro" 14:
  placements are blocked but resting tickets still fill with macro-suspend off (Defects 1 and 4); the old fixture's count
  is 38 / 37 / 34, so the fix lowers it.
- **Consistency:** salt spread +849 / +836 / +878 % matches `actual.sexp`; year table matches the equity curve; average
  invested 56 % matches the daily series; 13 gate reopens match `macro_trend.sexp`; 41 cash-cancelled entries match
  `entry_fill_rejected_by_portfolio` in the s0 audit.
- **Odd rows:** one "fill on a non-trading day", NLC (Defect 3).

Signal bullets (RV3):

| bullet | reading |
|---|---|
| Eras vs SPY: built 2000–02, held 03–06, built 07–08, eroded 09–12, held 13–17, eroded 18–23, built 2024, eroded 25–26; ends 1.18× | **Confirm, refined.** From 2018 the year-end ratio is the same in both arms (2.11 → 1.18). The fix changes only the earlier legs: N's 2008 build is smaller (1.81 → 2.78 vs O's 1.91 → 3.10), and so is its 2009–16 erosion (2.78 → 2.22 vs 3.10 → 2.27) |
| Eroded 2009–12: holdings lagged in UP (+17.1 vs +30.1 % at 62 %), and cash in rebounds (DOWN +20.5 vs +27.4 % at 45 %) | **Refine.** On O the same era is UP +22.1 % at 54 % and DOWN +19.1 % at 20 %. On corrected breadth the cash share of the erosion shrinks and selection in UP days dominates |
| Eroded 2018–23: cash through rebounds (DOWN +14.6 vs +57.2 % at 40 %) | **Confirm.** Identical in O |
| Eroded 2025–26: holdings lagged in UP (−19.7 vs +22.8 % at 61 %) | **Confirm.** Identical in O |
| 2022 rests on GLNG; 2024 on ADMA | **Confirm.** Identical trades in both arms |
| Gate reopens: 2009-05 sat out; 2025-05 invested and lagged | **Confirm.** O reopened a week later (2009-05-08); both sat out until 2009-10 |
| 41 cash-cancelled entries | **Refine.** O 35 / 36 / 36 → N 41 / 39 / 39: the capital constraint, the same one behind +115 `Insufficient_cash` skips at placement |
| Worst three years 2019–21 (+43.2 % vs +99.9 %) | **Confirm.** Identical in O |

Patterns found by eye that the pack did not flag, each with a proposed detector: the pack-vs-V23 disagreement (Defect 1:
a consistency signal whenever the card and V23 differ); a stale pack tree (Defect 2: stamp the pack SHA); the NLC terminal
exit (Defect 3: treat an exit after the issuer's last bar as a delisting when the symbol's next bar is more than a year
later).
