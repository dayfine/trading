# fbt-05 at ecd77c760: results-analyst read (flag HARM)

**Arm.** The record config (rk-kK, K = 5 tie seeds) plus `((screening_config ((failed_breakout_tolerance_pct 0.05))))`,
paired with S on one build, ecd77c760. It is row 3 of `surface.tsv` (`arms_run` 3).

**Rule.** `dev/plans/axis-observatory-2026-11-14.md` §1 and §3, as merged in 9a1b1d620 (#3622). The README's "The flag
rule" restates it, and `read/lib/row.awk` holds the constants.

**Files.**
- Public, branch `observatory/lane-results` at ca5ea8f83: `surface.tsv`, `lane-logs/ecd77c760-fbt-05.log`,
  `runs/ecd77c760/{S,fbt-05}/`.
- Private, `dayfine/trading-results` at ee660f8: the same `runs/`, with `trades.csv`, `equity_curve.csv`,
  `open_positions.csv` and runner logs, plus `reads/fbt-05@ecd77c760/` (this read's price-bearing appendix and tables at 7af6135,
  `analyst.md`).
- Corporate-action factors come from the local bar store (§Derivations).

## Summary

- The flag is **HARM**, as written and in every seed. Median D_end is −1.945 log; every seed is negative in 63–74 % of
  years; no single week carries more than 9 % of D_end.
- **The arm does not measure the failed-breakout rule.** The gate compares the bar store's back-adjusted close with a
  raw breakout high. A historical adjusted close sits below the raw close by every split and dividend the name pays
  later. So the gate drops names by their *future* corporate actions.
  - Of the record's 659 trades in names that later split, the arm kept **none**. Those trades carry 64 % of the
    record's summed trade contribution.
- That look-ahead channel is three quarters of the record contribution the arm loses: 1.98 of 2.62 per seed, on
  average.
- Two smaller channels do not come from the basis, and both are negative in all five seeds:
  - the thinned candidate list lets the walk buy deeper names in the bear and reopen windows the record sits out;
  - the fuller book loses record fills to cash.
- **Do not open a disjoint-window pre-registration on this arm.** The dial as built must not be armed in a backtest.
  Fixing the basis, retiring the dial, and auditing two sibling sites are options for the user (§5).

## 1. The rule, as written

> **HARM** is the mirror: median D_end of −0.20 or less, `seeds_neg60` at least 4, and the same step clause. … A flag
> opens a pre-registration on a disjoint window. It is not a promotion.

| clause (HARM) | bar | value | source |
|---|---|---|---|
| median D_end | ≤ −0.20 | **−1.9451** (seeds −1.9094, −2.4577, −2.3027, −1.5941, −1.9451) | `surface.tsv` row 3 `d_end_med`, `d_end_seeds` |
| seeds with ≥ 60 % negative years | ≥ 4 | **5** (negative years 20, 20, 17, 17, 19 of 27) | `seeds_neg60`; private `seeds.tsv` |
| median largest step share | < 0.5 | **0.082** (0.068, 0.053, 0.082, 0.083, 0.088) | `step_max_med`, `step_max_seeds` |

All three clauses hold, so the flag is **HARM** (`flag`).

**It survives dropping any one year.** Remove each seed's worst year (2004 in k0–k3, 2000 in k4) and D_end is −1.57,
−2.07, −1.92, −1.16, −1.65, a median of −1.65. Seeds k2 and k3 then sit at 16 negative years of 26 (private
`years-kK.tsv`).

**Validity, checked before the read.** Sources are the lane log unless named.
- **Same build.** `code_version` is ecd77c760 in every `params.sexp`. The arm's spec is S's plus the one overlay line
  (`params.sexp` diff; `SPEC CHECKS OK`).
- **Tripwire.** S k0 `trades.csv` md5 `0928cfe4…` matches S@3c367cca7. `DRIFT NONE` holds on every seed, so msd-12 and
  msd-18 (rows 1–2) share this S.
- **V6.** `agree` on k0–k4 (`runs/ecd77c760/fbt-05/*.v6diff-S.log`; `V6 OK`). `LIVE` on 5 of 5 seeds.
- **Universe.** Top-3000 PIT v12 (`snap_top3000_pit_v12wk`, `universe_size` 9185). This read uses no sp500 cell.

**Multiple comparisons.** `arms_run` is 3. Every seed sits 1.59 to 2.46 log below S, which is 7 to 11 times the
record's seed SD of 0.225 (`project_record_kseed_band`). Chance across three arms is not the explanation; the estimand
is (§2).

**The rule applies as written.** What I recommend not spending is the step it triggers, a disjoint-window
pre-registration (§2, §5).

## 2. Verdict, calibrated

**What the flag does establish.**
- Arming `failed_breakout_tolerance_pct 0.05` on the record at ecd77c760 costs about 1.9 log over 26 years in every
  seed.
- The record compounds at 10.2–11.5 %/yr and the arm at 1.4–3.8 %/yr (`ln(1+R)` 2.58–2.88 against 0.36–0.99;
  `*-actual.sexp`).
- The arm's max drawdown is about twice S's: 50–57 % against 25–32 %, once a one-day data artefact is removed (§3.5,
  §6).

**What it does not establish.**
- The `.mli` documents the rule as dropping "a long candidate whose current close has fallen back below
  `breakout_price × (1 − k)`". The flag says nothing about that rule.
- The code compares a back-adjusted close with a raw high (§3.1). On history that is a filter on future splits and
  dividends, which is look-ahead selection (`mechanism-validation-rigor.md` checks 1 and 4).
- The estimand is wrong, so the flag cannot be read as a verdict on the mechanism, in either direction.

**What the design can claim, weakly.** Two channels that a same-basis gate would also have are negative in all five
seeds (§3.4):
- deeper-rank buys in bear and reopen windows: −0.57 to −0.69 per seed;
- record fills lost to cash: −0.06 to −0.74 per seed, lottery-sized.

That leans a clean arm negative, but this run cannot size it.

**A disjoint-window pre-registration is not worth spending here.**
- Any historical window re-measures the defect, because adjusted and raw closes diverge by every later corporate
  action, and pre-2000 history diverges more.
- Only forward weeks are clean, and there are too few of them.
- Nothing here is near promotion, so `promotion-confirmation.md` does not apply.

## 3. Why

### 3.1 The code path (artifact check first)

At ecd77c760:
- **The gate.** `screener_admission.ml:34-39` builds `(close, bp, bp × (1 − k))` from
  `Stock_analysis.t.current_close` and `.breakout_price`. Line `:65-67` applies it. Callers are
  `screener_candidate_eval.ml:108-111` and `screener_watchlist.ml:28`.
- **The close is adjusted.**
  - `current_close` is `stock_analysis.ml:344`, `callbacks.stage.get_close ~week_offset:0`.
  - In the backtest that is `panel_callbacks.ml:129`, `get_close = … weekly.closes`.
  - `weekly.closes` is the adjusted close: `snapshot_bar_views.ml:79`,
    `closes = arr_of (fun b -> b.adjusted_close)`, as `snapshot_bar_views.mli` documents.
  - The bar-list path does the same (`stage.ml:460`).
- **The breakout is raw.** `breakout_price` is `stock_analysis.ml:305`, `scan_max_high` over `get_high`. That is the
  raw weekly high (`snapshot_bar_views.ml:81`, `highs = … b.high_price`) over offsets 8–51, cut at a split.
- **The store back-adjusts to the data's end** for every later split and dividend
  (`project_stop_raise_basis_mix_defect`, #2982).

**The arithmetic.** Let F be the adjusted-to-raw close factor in the screened week. The gate drops a name when
F × raw close < 0.95 × raw breakout.
- A name that later splits 2:1 has F ≤ 0.5 before the split. The gate then drops it at any price below about 1.9
  times its breakout, which in practice is always.
- Twenty-six years of dividends do the same more slowly.
- On the latest bar F is 1, so **in live use the comparison is consistent**. The defect lives in historical runs and
  backfills.

**No test reaches it.** `test_screener.ml:2503-2590` builds `Stock_analysis.t` by hand, setting `breakout_price` and
`current_close` directly, so no test meets a bar whose adjusted and raw closes differ.

### 3.2 The arm keeps S's trades by F, not by price (perturbed)

Trades join on symbol plus entry date within a seed, as `firstdiff` keys them; position ids shift between arms. Pooled
over the five seeds, S has 2,816 trades and the arm keeps 635.

**By F at entry** (S trades):

| F at entry | S trades | kept by the arm | rate |
|---|---:|---:|---:|
| < 0.85 | 1,270 | 0 | 0.000 |
| 0.85–0.90 | 162 | 5 | 0.031 |
| 0.90–0.95 | 182 | 13 | 0.071 |
| 0.95–0.97 | 92 | 13 | 0.141 |
| 0.97–0.99 | 87 | 42 | 0.483 |
| 0.99–1 | 60 | 33 | 0.550 |
| = 1 | 915 | 516 | 0.564 |
| > 1 (later reverse split) | 48 | 13 | 0.271 |

The kept rate climbs from 0 to about 0.55 exactly where F × (raw close / breakout) crosses 0.95. That is what the
arithmetic predicts. Path divergence alone would keep about half of every bin.

**By later corporate action** (any `splits.csv` or `dividends.csv` row after entry):

| S trades in names with… | S trades | kept | S win rate | S contribution per seed |
|---|---:|---:|---:|---:|
| a later forward split | 659 (23 %) | **0** | 53 % | +1.781 |
| later dividends only | 1,227 (44 %) | 131 (11 %) | 41 % | +0.308 |
| a later reverse split only | 57 (2 %) | 16 (28 %) | 44 % | −0.027 |
| no later split or dividend | 873 (31 %) | 488 (56 %) | 32 % | +0.726 |

The arm's book is the mirror image. Of its 4,142 trades:
- 69 % are in names with no later action (S: 31 %);
- 8.5 % are in later reverse-splitters (S: 2 %);
- 2 % are in later forward-splitters (S: 23 %).

**Perturbations.**
- **By era.** S trades with F < 0.90 are kept 0/478 in 2000–09, 5/735 in 2010–19 and 0/219 in 2020–26. With F ≥ 0.95
  the kept rates are 0.56, 0.53 and 0.48.
- **Dividend fingerprint.** 33 % of S's trades collect a dividend; 9 % of the arm's do. Dividends as a share of NAV at
  entry sum to 0.20–0.25 per seed for S and 0.04–0.06 for the arm. A same-basis gate would have no reason to avoid
  dividend payers.
- **The reconstruction holds.** Re-running the coded gate from the bar store, 96.5 % of the arm's 4,142 trades pass it
  on at least one of the 8 weekly closes before entry. Of the 2,181 S trades the arm lacks, 1,465 pass a same-basis
  gate on one of those closes but fail the coded gate on all eight.
- **No timing shift.** Of the 2,181 lost S trades, only 93 have the same symbol entered by the arm within 13 weeks.
  Among the 1,427 with F < 0.90, only 2 do.

**The artifacts rule the defect in.** A simulator-side specimen is still cheap. An as-of 2019-07-19 weekly report with
the gate armed would print DXCM's watchlist drop reason, `Failed breakout: close … below breakout …`, with the adjusted
close about 4× below the raw breakout.

### 3.3 Traces

**1. ADSK@2003-09-15: lost through the basis.**
- It is the record's largest single contribution: 0.42 of NAV at entry, in every seed. The arm loses it in 5 of 5.
- ADSK split 2:1 in 2004-12, so F was 0.50.
- On the three weekly closes before S's fill, the raw close sat 3–4 % *above* the raw breakout, so a same-basis gate
  passes.
- The coded comparison saw a ratio near 0.52 and dropped ADSK every week. The arm never bought it.
- This is the same ADSK 2003 that stale-E C crowded out (#3621), this time through the basis.

**2. DXCM@2019-07-22: lost through the basis.**
- Contribution 0.11 in all five S seeds; lost in all five.
- DXCM split 4:1 in 2022-06, so F was 0.25.
- On the 07-05, 07-12 and 07-19 closes the raw close sat 6, 4.5 and 2 % under the breakout. A same-basis gate passes on
  the last two.
- The coded ratio was about 0.24, so the gate dropped it.
- AVGO@2013-09-10 is the same case (10:1 split in 2024, F 0.07, coded ratio about 0.07; S held it in 3 seeds).

**3. MMYT@2023-10-26: lost to cash, not the basis.**
- Contribution 0.22 in all five S seeds; lost in all five. F is 1 (no later actions), so this one is not the basis.
- MMYT passes the gate on both bases on the 10-13 and 10-20 closes.
- In k2 and k3 the arm's ticket triggered on S's fill day, and the fill was rejected for cash. In k2 it fell short by
  under 1 % of the order (private runner logs).
- On 10-26 the arm held 5–7 names bought in the 2022-11 → 2023-06 reopen (CLS, OII, LKNCY, TDW, TRGP, …).
- This is the funding lottery (`project_funding_grid_monster_lottery`) tilted by a fuller book. APPS@2020-06-15 is lost
  the same way in k2 and k4 (kept in k0, k1, k3). So is BGO@2003-07-15 (F 1, lost 5/5): the arm held 4–6 names from
  the 2003 reopen against S's one.

**4. The 2001 bear: the bear brake released.**
- In 2001 S entered 1.4 names per seed and the arm 20.8. Of the arm's 104 entries, pooled over the five seeds, 90 came
  in Neutral macro weeks.
- 15 % of them won, and 99 % ended on a stop.
- Other bear years repeat it:
  - 2002: S 2.2 per seed against the arm's 15.0; 7 % won.
  - 2008: S 0 against 10.0; 16 % won.
  - 2022: S 15.2 against 36.4; 9 % won.
- This is the gate-before-cap release of the record's bear brake (§3.5).

**5. ADMA@2023-12-19: a seed lottery in both arms.**
- Contribution 0.30. S holds it in k1, k2 and k4, the arm in k0 and k3: the same fill on the same day.
- The gate filters only new candidates. It never cancels a resting ticket: the F2 re-screen is off, since
  `enable_entry_ticket_rescreen` defaults to false.
- So a ticket placed at the August 2023 breakout still fills on the December re-break in the arm.

### 3.4 Decomposition of D

**The weight.** A trade's contribution w is its P&L as a share of its arm's NAV at entry: the reader's own weight, used
here as a first-order log attribution. Summed over S's trades it gives 2.63–2.95 per seed, against `ln(1+R)` of
2.58–2.88.

**Classes of lost S trade**, from the reconstructed gate (§Derivations):
- **basis-only:** passes the same-basis gate on some close before entry, but fails the coded gate on all eight;
- **same-basis drop:** fails both gates. This is an upper bound on what a clean gate removes directly;
- **coded passed:** the arm could have ticketed it, and lost it to cash or path.

| seed | D_end | lost: basis-only (n) | lost: same-basis drop (n) | lost: coded passed (n) | added: bear years¹ (n) | added: other years (n) | shared | residual² |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| k0 | −1.909 | −2.135 (297) | −0.052 (42) | −0.064 (103) | −0.693 (118) | +1.317 (584) | +0.002 | −0.284 |
| k1 | −2.458 | −1.980 (302) | −0.473 (31) | −0.124 (106) | −0.566 (111) | +0.843 (593) | −0.000 | −0.158 |
| k2 | −2.303 | −1.899 (286) | −0.396 (38) | −0.609 (107) | −0.640 (116) | +1.296 (590) | +0.010 | −0.064 |
| k3 | −1.594 | −2.075 (299) | −0.064 (30) | −0.348 (115) | −0.652 (113) | +1.852 (593) | +0.014 | −0.320 |
| k4 | −1.945 | −1.817 (281) | −0.322 (33) | −0.737 (111) | −0.621 (109) | +1.626 (580) | +0.020 | −0.094 |

¹ Entries in 2000, 2001, 2002, 2008 and 2022.
² D_end minus the row's sum: lost dividend income (−0.16 to −0.20 per seed), volatility drag, cash interest and open
positions.
Source: private `trades.csv` and `equity_curve.csv`, plus the bar store.

**Reading the table.**
- **The basis-only term is the loss.** At −1.82 to −2.14 per seed it is about D_end's size on its own, and it is the
  steadiest term. The arm only partly refills the vacated slots (+0.84 to +1.85 in other years).
- **Bear-year additions** are the second steady term: −0.57 to −0.69 per seed, 91 % stopped out.
- **Coded-passed losses and same-basis drops** are lottery-sized and set the spread between seeds. APPS 2020 (k2, k4)
  and MMYT 2023 sit in the first, ADMA 2023 in the second.
- **Shared trades contribute nothing:** same trade, same share of NAV. Timing shifts are negligible (§3.2).

### 3.5 Why trades rise ~47 % and the drawdown doubles, when the gate only removes candidates

**Faster turnover, not more capacity.**
- Position-days are close: 50.7k–52.9k per seed for S and 53.7k–54.4k for the arm, +3 to +7 %.
- The arm's picks fail sooner (private `trades.csv`):
  - stop-loss exits rise from 49–51 % of trades to 68–70 %;
  - the median hold falls from 62–65 days to 38–41;
  - the win rate falls from 39–42 % to 31–32 %.
- So the same ~5–7 slots recycle about 1.5 times as often.
- Within names that have no later corporate action, the win rate is about the same (S 32 %, arm 30 %). The overall drop
  is mostly composition: the arm lost the later-splitter cohort, which wins 53 % (§3.2).

**The bear brake released (gate before cap).**
- The gate removes names before the top-20 cut. On the empty-book Fridays after a macro reopen, the walk therefore
  reaches deeper names that have a structural stop.
- On those Fridays the gate funnel (#3631) found S's top 20 was 96 % A+ and 94 % `No_structural_stop`, with an average
  of 54 buyable names below the cut.
- Entries per seed, S against the arm, in 2000 / 2001 / 2002 / 2008 / 2022: 17.8 / 1.4 / 2.2 / 0 / 15.2 against
  41.8 / 20.8 / 15.0 / 10.0 / 36.4.
- Positions held, S against the arm: 0.3 / 3.5 in 2002, 1.3 / 3.2 in 2009, 2.8 / 4.3 in 2016, 3.4 / 4.6 in 2022,
  3.9 / 6.3 in 2023 (private `years-kK.tsv`).

**Cash walls.** Fills rejected for insufficient cash: 44–57 per seed for S, 81–94 for the arm (private runner logs
`obs-*-s0.log`).

**The drawdown is one episode from the 2000 top.**
- With the ELI phantom day removed (§6), the arm's max drawdown starts at the 2000-03-10 peak in all five seeds. It
  reaches 50.3–56.6 %, with troughs between 2003-08 (k4) and 2010-02 (k0).
- S's worst episode is 2018 → 2020-03, or 2021-04 → 2023-10, at 24.6–32.1 % (private `equity_curve.csv`).
- The arm deploys into 2000–02, where S sat in cash. It then misses the 2003–04 recovery winners that the basis dropped
  (ADSK, HOS). By the end of 2004, D is already −0.88 to −1.15.

### 3.6 Regime, by period

**D by era and the base's macro state**, per seed k0..k4 (private `steps-kK.tsv`; weeks assigned as the reader assigns
them):

| era | Bullish | Neutral | Bearish |
|---|---|---|---|
| 2000–09 | −0.79 −0.89 −0.78 −0.64 −0.52 (257 wk) | −0.47 −0.19 −0.35 −0.33 −0.25 (79) | −0.38 −0.29 −0.15 −0.35 −0.26 (185) |
| 2010–19 | −0.21 −0.29 −0.12 −0.37 −0.38 (436) | −0.03 +0.04 −0.08 −0.06 −0.01 (50) | +0.01 −0.16 −0.09 +0.07 −0.13 (35) |
| 2020–26 | +0.31 −0.38 −0.54 +0.40 −0.15 (270) | −0.26 −0.20 −0.14 −0.21 −0.12 (46) | −0.09 −0.09 −0.07 −0.11 −0.13 (23) |

**Mean positions held** at the weekly macro dates, S / arm, averaged over seeds (private `trades.csv`,
`open_positions.csv`):

| era | Bullish | Neutral | Bearish |
|---|---|---|---|
| 2000–09 | 6.44 / 6.52 | 3.06 / 4.35 | 1.51 / 1.86 |
| 2010–19 | 6.92 / 6.64 | 5.76 / 5.56 | 3.49 / 2.93 |
| 2020–26 | 5.87 / 6.64 | 4.34 / 4.89 | 2.90 / 3.99 |

**Reading the tables.**
- **Bull weeks carry the most D in total** (median −1.04, `d_mac_bull`), and the bull-week loss shrinks era by era,
  following the basis channel.
  - The share of S's trades with F < 0.90 is 0.46–1.00 each year from 2000 to 2012, and 0.43–0.64 from 2013 to 2021.
  - It then falls: 0.37 in 2022, 0.21 in 2023, 0.18 in 2024, 0.07 in 2025 and 0 in 2026.
  - The lost later-splitters made their gains in bull tapes.
- **Per week, Neutral is worst.** It costs −0.0033 a week, against −0.0011 for Bullish and −0.0019 for Bearish (medians
  over 169, 930 and 236 macro weeks).
  - Neutral is negative in 14 of 15 seed-era cells. That is the reopen-window deployment, and it persists in 2020–26,
    where the basis channel is weakest.
  - The arm holds more positions there: +1.29 in 2000–09 Neutral weeks, and +0.55 to +1.09 across all three states in
    2020–26.
- **In 2023–26, where F is near 1 for most names, there is no sign.** D sums to +0.25, −0.32, −0.11, +0.39, +0.08, set
  by which arm holds ADMA and MMYT.
- **By SPY year** (`spy_years.tsv`, close basis): bear years sum to −0.91 (`d_bear_yr`, 8 years) and bull years to
  −1.04 (19 years). Per year, bear years are about twice as bad.

### 3.7 Tail or body

S's basis-dropped trades are the better cohort across the whole distribution, not only in the tail. Per-trade return,
pooled:

| cohort | n | mean | p10 | p25 | p50 | p75 | p90 | ≥ +100 % |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| S lost, basis-only | 1,465 | +6.9 % | −11.3 | −7.3 | −1.5 | +10.1 | +28.1 | 23 |
| S lost, coded passed | 542 | +3.8 % | −14.1 | −11.0 | −5.3 | +5.9 | +24.4 | 12 |
| S lost, same-basis drop | 174 | +8.3 % | −13.6 | −11.4 | −2.8 | +11.4 | +40.4 | 3 |
| arm added | 3,507 | +1.5 % | −12.7 | −9.4 | −4.9 | +2.3 | +18.3 | 50 |
| shared | 635 | +2.2 % | −13.6 | −10.5 | −5.2 | +4.4 | +17.6 | 4 |

- **The arm's added cohort has its own doublers:** CLS 2023, IREN 2025, NIO 2020, ENPH 2019 and ODSY 2009, all with
  F = 1. In contribution its tail is *larger*: +1.37 per seed against +0.93 for the basis-dropped cohort.
- **Its losers cost far more:** −4.13 per seed against −1.10. That is a body loss on a book that stops out 69 % of the
  time, not a fat-tail tax.
- **The dropped cohort is hindsight-selected.** These are names that went on to split or pay dividends, so their better
  body says that and nothing more; it is not a law about breakouts.

## 4. How it fits what we know

- **Confirms a recurring defect class:** an adjusted-basis close or MA mixed with raw prices. Earlier instances are
  `project_stop_raise_basis_mix_defect` (#2982) and the #2973 registry rows ("split basis keeps recurring", the
  MA-fallback entry anchor). This instance bites on dividends as well as splits, and it depends on the data vintage: a
  split announced after the warehouse build changes the arm's history.
- **Re-derives stale-E K=5 (#3621) from a new lever.** The record's bear brake is released, and the same S winners are
  crowded out (ADSK 2003, APPS 2020, MMYT 2023). It refines that read: here ADSK goes through the basis, and MMYT and
  APPS through cash.
- **Confirms the gate funnel P1 (#3631).** X lives in empty-book reopen windows, and C\* rides −3.06 % in bear years.
  The arm's bear-year additions are those names in practice: 91 % stopped out, −0.57 to −0.69 per seed.
- **Refines `project_edge_is_the_fat_tail` for admission gates.** This loss is in the body and in composition, not the
  tail. That follows from the hindsight selection, so it does not transfer as a law.
- **Consistent with the user's "A"** (`project_weekly_picks_backfill`: picks stay on the record config). In live use
  the gate compares consistently, so the 07-14 live config really did drop the 10–19 of 20 longs per Friday that sat
  more than 5 % under their breakout. This arm says nothing for or against that live filter.
- **Same S as msd-12 (−0.27) and msd-18 (−0.58),** both flag none. fbt-05 is 3–7 times larger, and most of the gap is
  the defect.
- **Flag to dig: two sibling sites carry the same expression.**
  - `entry_freshness.ml:25`: `Range_top_breakout` compares the adjusted close with a raw range top. Line `:17` compares
    the raw anchor with the adjusted MA.
  - `continuation.ml:133`: adjusted close > raw consolidation high. Line `:114`: raw range over the adjusted average
    close.
  - Neither is on the record's path. `entry_freshness_basis` defaults to `Ma_cross`, under which
    `range_top_freshness` returns `None` (`entry_freshness.ml:31-35`, `weinstein_strategy_config.ml:262`), and the
    record does not set it. Continuation buys are off in the record.
  - `project_rangetop_freshness_is_a_drawdown_lever` and the continuation rejections may rest on the same exclusion of
    later splitters and dividend payers. This read does not measure them.
- **The flag rule worked as designed, and still could not see this.**
  - A look-ahead filter applied every week produces a slope across years and seeds with no dominant step. That is the
    plan's signature of a real mechanism.
  - The shape clause separates a lottery from a slope. It cannot separate a mechanism from a defect.

## 5. What it implies next (options)

**What the why rules out and in.** It rules out reading fbt-05 as evidence about failed-breakout invalidation, and
spending a disjoint window on it. It rules in, as a prior, that any filter applied before the cap which thins the
top 20 on empty-book Fridays releases the bear brake (#3621, #3631, and this read).

1. **Record and stop.**
   - Record fbt-05 as HARM with an invalid estimand (basis mix); open no disjoint-window pre-registration.
   - File the defect, covering the gate, its watchlist twin and the two sibling suspects, with a findings-registry row
     (guard none until a unit test exists).
   - The gate stays off and decision A is unaffected. This is the cheapest option, and it loses nothing a decision
     needs.
2. **Fix and re-measure.**
   - Put the gate on one basis: for example, the raw close at offset 0 (`weekly_view.raw_closes`) against the raw
     breakout. The gate is default-off, so no golden moves.
   - Pin it with a bar fixture that splits later.
   - Queue a clean arm at the fixed HEAD. A new HEAD re-runs S, about 12 h on one lane.
   - Only a clean UP flag would change a decision; a clean HARM or none confirms A.
   - The basis-free channels here lean negative. §3.2 also implies a clean gate removes few of S's own trades
     (same-basis drops: 30–42 per seed), so its effect would run mostly through the cap, which cap-40 measures.
3. **Retire the dial.** Its one consumer, the live picks, moved to the record config under decision A.
4. **Audit the siblings before trusting their verdicts.** This is host-only and needs no new run: re-read the committed
   trades of the rt-freshness and continuation experiments by later-split status, as in §3.2. If later-splitters show
   the same 0 % kept rate, those verdicts rest on the same filter.
5. **Observatory hygiene.**
   - Give admission arms a basis partition in the private read: S's kept rate split by later forward split.
   - Have `obs_read.sh` guard DD and Ulcer against a one-day NAV round trip, or against any non-V6 invariant failure
     (V20 here).
   - Build a review pack for every flagged arm (RV1).

**For cap-40, running at the same commit.**
- cap-40 compares no prices, so it isolates the deeper-rank channel.
- Read it for: entries and positions held in 2000–02, 2008 and 2022–23; Neutral-week D; cash-rejected fills; and S's
  F = 1 winners lost through cash (MMYT 2023, APPS 2020, BGO 2003).
- This read predicts negative D concentrated in the Neutral and Bearish weeks of those windows, and no broad bleed in
  bull weeks.
- A bull-week bleed in cap-40 would point to another defect, not to the cap.

## 6. Defects found

1. **Basis mix in the failed-breakout gate** (the cause of this result).
   - **Where:** `screener_admission.ml:34-39` and `:65-67` compare an adjusted `current_close`
     (`stock_analysis.ml:344` ← `panel_callbacks.ml:129` ← `snapshot_bar_views.ml:79`) with a raw `breakout_price`
     (`stock_analysis.ml:305` ← `snapshot_bar_views.ml:81`).
   - **Callers:** `screener_candidate_eval.ml:108-111` and `screener_watchlist.ml:28`. Historical reports print the
     adjusted close labelled as "close".
   - **Doc claim false on history:** `screener.mli:357`.
   - **Specimens:** DXCM, week of 2019-07-19 (F 0.25); ADSK, 2003-09-12 (F 0.50; the raw close was above the breakout
     and the gate still dropped it); AVGO, 2013-09-06 (F 0.07).
   - **Untested:** `test_screener.ml:2503-2590` builds the analysis record by hand.
2. **Sibling suspects** (same expression, unmeasured, off the record's path): `entry_freshness.ml:17` and `:25`
   (`Range_top_breakout`); `continuation.ml:114` and `:133`.
3. **ELI data defect.**
   - **What:** in the bar store, `ELI` from 2014-05-19 to 2014-06-16 interleaves three unrelated price series, an order
     of magnitude or more apart.
   - **Trade:** the arm bought ELI@2014-05-27 in k1–k4; it is arm-only.
   - **One-day NAV jump:** NAV marked ×2.35 on 2014-05-28 and returned the next day.
   - **Stop-out:** the position stopped out on 2014-05-30 at −96 %. That is −0.075 of NAV, about −0.078 log of D, in
     each of those seeds.
   - **Validator:** V20 (an invariant check) fires once, in arm k1–k4 only (`*.validator.log`: "V20 INV 1
     violations").
   - **Effect on the surface:**
     - `d_maxdd_pp` reads +39.5. With 2014-05-28 dropped the median is +26.3 (per seed +29.4, +26.3, +18.2, +25.9,
       +26.6).
     - `d_ulcer` reads +32.2. Recomputed on both arms with the day dropped, it is about +18.6.
     - Weekly D is unaffected, because the day falls mid-week.
4. **Observatory read and lane.**
   - `obs_read.sh` takes `d_maxdd_pp` and `d_ulcer` from `summary.sexp` with no guard against item 3.
   - The lane's validity gates (V6, tripwire, liveness, spec checks) all pass a mis-wired dial. The only invariant
     failure outside V6 was V20, which the lane does not read.
   - No review pack exists for observatory arms (RV1).

## Review-pack look

No pack was rendered for this arm: the lane keeps no `trade_audit.sexp`, and no images were provided. RV1 is not met.

What I read instead:
- the equity curves: max-drawdown peaks and troughs, which is how the ELI day surfaced;
- the per-seed yearly tables;
- every validator log. Against S, V9 is about ×3, V14 ×3, V21 ×2.4, and V22 ÷7, plus the V20 failure above;
- the runner logs, for rejected fills.

A pack's "Entry geometry" D1 signal (raw/adjusted close ≥ 1.05 at decision) is the same factor F, and its specimens
(DXCM 4.00, CVNA 5.00) match the factors used here.

## Derivations

- **w:** `pnl_dollars` divided by the arm's `equity_curve.csv` value on the last row on or before `entry_date`, per
  trade (private `trades.csv`).
- **Classes:** symbol + `entry_date` within a seed. A trade is shared when its key appears in both arms.
- **F:** `adjusted_close / close` on the bar store's last row on or before `entry_date`.
- **Later action:** any `splits.csv` row (factor > 1 is a forward split, < 1 reverse) or `dividends.csv` row dated
  after `entry_date`.
- **Gate reconstruction:**
  - Monday-start weekly buckets, each with the last day's close and adjusted close and the week's max raw high.
  - Breakout: the max raw weekly high over offsets 8–51 of the screened week, stopping where the adjusted/raw factor
    jumps by 20 % or more. These are the defaults in `stock_analysis.ml:57-59`, with the split guard in
    `stock_analysis_scans.ml`.
  - Coded ratio: adjusted close / breakout. Same-basis ratio: raw close / breakout. Both are taken over the 8 weekly
    closes before the entry week.
- **Bar store:** the local `data/` store, refreshed to 2026-11-13, not the lane's `data-20261102` + `v12wk-9236`.
  Factors can differ by corporate actions between the two vintages; the D1 specimens above match.
- **Tables and scripts** (awk, no Python): trading-results `reads/fbt-05@ecd77c760/analyst-tables/`.
- **Dispatcher spot checks:** the code path at `snapshot_bar_views.ml:79-81` and `stock_analysis.ml:303-344`; the
  per-trade table gives 659 later-forward-split S trades with 0 shared, 1,270 S trades with F < 0.85 with 0 shared,
  and 2,181 S-only against 635 shared; V20 appears in `obs-fbt-05-k1-s0.validator.log`.
