# index-hedge-screen-2026-10-12: index-short overlay screen on the record (N)

**Pre-registration:** `dev/plans/index-hedge-screen-2026-10-11.md`, CONFIRMED by the user and merged as `776e8d355`
(#3251). This directory applies it without changes, except for the operational choices listed below.

## Inputs

- **Base:** the record N, rb1 on the full NYSE A-D fixture (#3261). It has three salts:
  `dev/experiments/breadth-fix-rb1-2026-10-11/results/N-rb1-26-s{0,1,2}-v12-equity_curve.csv`. The run is total
  return with interest and dividends on, over 2000-01-03 → 2026-06-25.
- **SPY:** the host `data/S/Y/SPY/data.csv`, `adjusted_close` (total return, so the short pays dividends).
- **G1, SPY's weekly stage:** `results/spy-weekly-stage.csv`.
  - It is the `stage_chart.exe` replay of SPY over 1999-01-01 → 2026-06-26, using the default classifier on
    adjusted closes. This is the same replay the review pack uses for trade stages.
  - G1 is on in weeks whose stage is `Stage4`: price below a falling 30-week MA.
- **G2, G3, the macro gate:** `results/macro-N.csv`, the `trend` column of N's `macro_trend.sexp`. It is identical
  across salts, with 233 Bearish weeks.
- **Cash rate for the credit sensitivity:** `data/macro/tbill_3m_dtb3.csv`, minus 10 bp (the record's
  `cash_yield_fee_bp`).

## Overlay (as pre-registered)

`ln V*_T = ln V_T + Σ_t ln(1 − h · g_{t−1} · r_SPY,t) − borrow`

- h ∈ {0.25, 0.5, 1.0}.
- Borrow is 0.25 %/yr on the notional, charged daily.
- Primary: short proceeds earn no interest. Sensitivity: they earn DTB3 − 10 bp.

**Operational choices** (the plan leaves these open):

1. **Gate timing.** "Weekly and lagged one week" is implemented as follows: the gate on day t is the reading of the
   last week-end strictly before t. A reading at Friday's close applies from the next trading day. The `-lag1`
   sensitivity adds one more week.
2. **Drawdown.** Max drawdown is measured on the daily combined NAV, and so is the base's.
3. **Regimes.** The UP / MIXED / DOWN columns in `summary-*.txt` use the classifier's 30-week WMA at the gate's own reading week (near-tautological for G1: 0 UP sessions). The pack-rule split (weekly close vs the 30-week SMA and that SMA four weeks earlier, prior ISO week) is in `results/analysis/phase.txt` and §4c below.
4. **Holiday rows.** The base equity curve has 236 rows on US market holidays (no SPY bar). The overlay carries the last SPY close across them, as `dev/lib/review_pack/periods.awk` does; borrow and credit accrue per SPY session, and the credit rate is floored at 0.
5. **Host inputs** (gitignored) are pinned by md5: `data/S/Y/SPY/data.csv` `447bca148f4385bcd3b5c19a144f21bf`, `data/macro/tbill_3m_dtb3.csv` `4ccbfe555711299c535d039452e71da2`.

## Files

- `scripts/overlay.awk`, `scripts/run.sh`: run `run.sh` from the repo root to regenerate every `results/*.txt`.
- `results/summary-s{0,1,2}.txt` (primary), `-credit.txt`, `-lag1.txt`. Each row is one (gate, h) cell and gives:
  - days the gate is on, overlay log, combined log, and the delta vs base;
  - combined max drawdown and its delta vs base;
  - bear-period deltas and how many of the 3 bears it beats;
  - criteria flags c1–c3;
  - overlay log by regime.
- `results/years-s{0,1,2}.txt`: combined − base log by year at h = 0.5.
- `results/episodes.txt`: every gate episode with SPY's move and the h = 1 short log.
- `scripts/analysis/*.awk`, `scripts/analysis/run.sh` → `results/analysis/*`: the reading's tables (episodes, distributions, phase split, lateness, cost decomposition, sensitivities, ledger metrics). Run after `scripts/run.sh`.


## Results (2026-10-12)

Reading by `results-analyst` of pre-registration `776e8d355`. Paths are relative to this directory.

**Verdict: no-build decision.** No (gate, h) cell escalates. c1 and c2 fail in every cell and every salt. Criterion 2
cannot be reached by any hedge that is on only in bear markets, because the record's binding drawdown (2024-11-26 →
2026-06-24) happened while SPY rose +24.6 %. Per the plan, single-name and index shorts both stay off.

### 0. Script audit

- **One defect, fixed before the reading.** The first `scripts/overlay.awk` (`ea62a74d3`) computed SPY's return only
  when both `d[t-1]` and `d[t]` had an SPY bar. The base curve carries 236 US-holiday rows, so the session after each
  holiday lost its SPY return. Specimens with G1 on: 2001-09-17 −5.22 %, 2009-01-20 −5.28 %, 2009-02-17 −4.28 %.
- **Effect:** at most +0.038 log over 26 years (G1 h=1) and +0.091 on one episode (G1 #8). No criterion flag changes in
  any cell, salt or sensitivity.
- **Independent check.** A separate implementation reproduces the first outputs to 4 dp with the defect on, and the
  corrected `overlay.awk` digit for digit with it off.
- **Checked and fine:**
  - Gate timing: the reading of the last week-end strictly before the day, so there is no look-ahead; entering at the
    signal close rather than the next open is bounded by `-lag1`.
  - Returns are total return, so the short pays dividends.
  - Macro: G2 and G3 carry the prior reading through the 59 holiday-Friday weeks with no reading (#3139), as the
    strategy did.
  - Drawdown is daily peak-to-trough; the base reproduces `actual.sexp` (22.52 / 22.19 / 22.19 %).
  - Bear windows are inclusive and applied identically; c1–c3 are coded as written; c4 is computed in §1.

### 1. The pre-registered rule, as written

The base, per salt (`results/summary-s{0,1,2}.txt`):

| salt | base log | base max DD | bear-period base log (2000–02 / 2007–09 / 2022) |
|---|---:|---:|---|
| s0 | 2.2501 | 22.52 % | +0.0847 / −0.1011 / −0.0817 |
| s1 | 2.2360 | 22.19 % | +0.0820 / −0.1002 / −0.0786 |
| s2 | 2.2802 | 22.19 % | +0.0796 / −0.1090 / −0.0759 |

The overlay depends only on SPY in the pre-registered form, so d_log and the bear deltas are identical across salts;
only max DD moves with the salt. In c2, change = base − combined (positive = smaller drawdown; the rule needs ≥ +3).

| cell | c1: d_log (needs ≥ −0.05) | c2: combined max DD s0 / s1 / s2 → change, pp | c3: bears beaten (deltas) | c4 | escalates |
|---|---|---|---|---|---|
| G1 h=0.25 | −0.2114 fail | 26.24 / 25.93 / 25.92 → −3.72 / −3.73 / −3.73 fail | 2/3 (+0.0789 / +0.1155 / −0.0133) | holds | no |
| G1 h=0.5 | −0.4527 fail | 29.89 / 29.60 / 29.59 → −7.37 / −7.40 / −7.40 fail | 2/3 (+0.1515 / +0.2189 / −0.0283) | holds | no |
| G1 h=1.0 | −1.0260 fail | 42.21 / 42.52 / 42.42 → −19.69 / −20.33 / −20.23 fail | 2/3 (+0.2777 / +0.3895 / −0.0637) | holds | no |
| G2 h=0.25 | −0.0793 fail | 23.70 / 23.38 / 23.38 → −1.18 / −1.19 / −1.19 fail | 3/3 (+0.0839 / +0.0825 / +0.0035) | holds | no |
| G2 h=0.5 | −0.1826 fail | 25.08 / 24.80 / 24.87 → −2.56 / −2.60 / −2.68 fail | 3/3 (+0.1616 / +0.1533 / +0.0056) | holds | no |
| G2 h=1.0 | −0.4618 fail | 30.04 / 30.15 / 30.19 → −7.52 / −7.96 / −8.00 fail | 3/3 (+0.2981 / +0.2595 / +0.0058) | holds | no |
| G3 h=0.25 | −0.1541 fail | 23.70 / 23.38 / 23.38 → −1.18 / −1.19 / −1.19 fail | 3/3 (+0.0693 / +0.0841 / +0.0013) | holds | no |
| G3 h=0.5 | −0.3351 fail | 25.42 / 25.13 / 25.20 → −2.90 / −2.94 / −3.02 fail | 3/3 (+0.1314 / +0.1564 / +0.0011) | holds | no |
| G3 h=1.0 | −0.7785 fail | 33.01 / 33.00 / 33.12 → −10.49 / −10.81 / −10.94 fail | 2/3 (+0.2343 / +0.2649 / −0.0035) | holds | no |

- **c4** holds vacuously: every c1 and c2 margin is negative at every h.
- **Where the combined max DD falls** (`results/analysis/ledger-metrics-s{0,1,2}.txt`, the same windows in every salt):
  at h=0.25 (and G1 h=0.5) the base's own 2024-11-26 → 2026-06-24 window; G2/G3 h=0.5 2021-06-01 → 2023-10-27; h=1.0
  G1 2018-09-14 → 2023-10-27, G2 2008-11-20 → 2010-02-04, G3 2011-05-10 → 2012-01-24.
- **Sharpe and Calmar** (the simulator's convention) fall in every cell. Best: G2 h=0.25, Sharpe 0.5018 vs 0.5262,
  Calmar 0.3605 vs 0.3939 (s0).
- **Scaled:** as CAGR, G1 h=0.25 takes the record from 8.87 % to 8.01 %, below SPY TR 8.20 %; G2 h=0.25 to 8.54 %.

### 2. Verdict, calibrated

- **No-build decision.** No cell escalates; criterion 2 fails in every cell, salt, convention and estimand tested, and
  structurally rather than marginally (§5.1).
- **What it can claim:** no lagged weekly index-short overlay — SPY Stage 4, Stage 4 with Bearish macro, or Bearish
  macro alone, at 25–100 % of NAV — cuts this record's drawdown or earns its keep over 26 years.
- **What it cannot claim:** that "index shorts do not work". The overlay is an offline, daily-rebalanced proxy whose
  P&L never feeds back into the book; only three lagged gates were tested and no faster cover rule; it is one SPY path,
  so "2 of 3 salts" is one overlay read three times; and c1 is convention-sensitive for G2 h=0.25 (§3). c2 is not.

### 3. Sensitivities (not the rule; do they move the verdict?)

s0 shown; s1/s2 have the same pattern. Each entry is d_log / change in DD in pp.

| read | file | G1 h=0.25 | G2 h=0.25 | G3 h=0.25 | any cell escalates |
|---|---|---|---|---|---|
| primary, corrected | `results/summary-s0.txt` | −0.2114 / −3.72 | −0.0793 / −1.18 | −0.1541 / −1.18 | no |
| as first committed | `results/summary-s0.txt` @ `ea62a74d3` | −0.2226 / −4.07 | −0.0775 / −1.64 | −0.1487 / −1.64 | no |
| proceeds credited at DTB3 − 10 bp | `results/summary-s0-credit.txt` | −0.1904 / −3.58 | −0.0611 / −1.14 | −0.1291 / −1.14 | no |
| one more week of lag | `results/summary-s0-lag1.txt` | −0.1470 / −4.40 | −0.0515 / −1.46 | −0.0920 / −1.37 | no |
| lag + credit | `results/analysis/summary-s0-lag1-credit.txt` | −0.1262 / −4.26 | **−0.0336 (c1 passes)** / −1.32 | −0.0673 / −1.32 | no |
| sum form (h × combined NAV at t−1) | `results/analysis/forms-sum-s0.txt` | −0.1979 / −3.69 | −0.0731 / −1.19 | −0.1460 / −1.19 | no |
| held short, static per episode | `results/analysis/forms-static-s{0,1,2}.txt` | −0.1768 / −3.57 | **−0.0413 (c1 passes, all salts)** / −1.19 | −0.1157 / −1.19 | no |
| old frozen-A-D macro (O s0) | `results/analysis/omacro-summary-s0.txt` | −0.2114 / −3.72 | −0.0737 / −1.18 | −0.1765 / −1.18 | no |

c3 holds in every row; c2 fails in every row. A daily-rebalanced short costs G2 about 0.038 log at h=0.25 against a
held short: that sizes the return cost, not the verdict.

### 4. Reported regardless of verdict

**4a. Every G1 episode** (`results/analysis/episodes-G1.csv`; G2 and G3 in `episodes-G2.csv`, `episodes-G3.csv`).
SPY move runs from the close before the first on-day to the last; "below its high" is SPY's drawdown from its running
total-return high at entry.

| # | first | last | sessions | SPY move | SPY below its high at entry | h=1 short log | h=0.25 overlay log |
|---|---|---|---:|---:|---:|---:|---:|
| 1 | 2000-10-16 | 2001-05-18 | 149 | −5.14 % | 10.0 % | +0.0146 | +0.0069 |
| 2 | 2001-07-09 | 2001-12-07 | 104 | −1.72 % | 21.4 % | −0.0014 | +0.0011 |
| 3 | 2002-05-06 | 2002-12-06 | 151 | −13.77 % | 28.3 % | +0.0914 | +0.0278 |
| 4 | 2003-02-17 | 2003-04-04 | 34 | +5.26 % | 43.2 % | −0.0592 | −0.0141 |
| 5 | 2004-08-09 | 2004-09-03 | 20 | +4.93 % | 26.1 % | −0.0491 | −0.0122 |
| 6 | 2007-12-03 | 2007-12-07 | 5 | +1.51 % | 5.0 % | −0.0156 | −0.0039 |
| 7 | 2008-01-14 | 2008-05-02 | 77 | +1.47 % | 10.0 % | −0.0291 | −0.0061 |
| 8 | 2008-06-30 | 2009-04-24 | 207 | −30.61 % | 17.3 % | +0.1670 | +0.0600 |
| 9 | 2010-06-14 | 2010-08-06 | 39 | +2.96 % | 25.9 % | −0.0352 | −0.0083 |
| 10 | 2010-08-30 | 2010-09-10 | 9 | +4.32 % | 27.4 % | −0.0439 | −0.0108 |
| 11 | 2011-08-22 | 2011-11-04 | 54 | +11.98 % | 22.0 % | −0.1312 | −0.0312 |
| 12 | 2015-08-31 | 2015-10-23 | 39 | +4.67 % | 6.3 % | −0.0512 | −0.0124 |
| 13 | 2016-01-18 | 2016-03-11 | 38 | +7.96 % | 10.7 % | −0.0820 | −0.0201 |
| 14 | 2018-12-10 | 2019-02-08 | 42 | +3.22 % | 9.8 % | −0.0398 | −0.0093 |
| 15 | 2020-03-23 | 2020-06-05 | 53 | +39.57 % | 32.0 % | −0.3667 | −0.0886 |
| 16 | 2022-02-28 | 2022-04-01 | 25 | +3.79 % | 8.4 % | −0.0420 | −0.0101 |
| 17 | 2022-05-02 | 2022-08-19 | 77 | +2.90 % | 13.5 % | −0.0482 | −0.0104 |
| 18 | 2022-09-26 | 2022-11-18 | 40 | +7.63 % | 22.1 % | −0.0861 | −0.0204 |
| 19 | 2025-03-31 | 2025-05-16 | 34 | +6.94 % | 9.1 % | −0.0909 | −0.0205 |
| 20 | 2026-03-30 | 2026-04-17 | 14 | +11.99 % | 8.6 % | −0.1153 | −0.0287 |

**4b. Distribution of episode P&L** (`results/analysis/episode-dist.txt`; linear-interpolated percentiles):

| series | n | positive | mean | median | p10 | p25 | p75 | p90 | min / max |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| G1, h=0.25 overlay | 20 | 4 | −0.0106 | −0.0106 | −0.0290 | −0.0202 | −0.0056 | +0.0090 | −0.0886 / +0.0600 |
| G1, h=1 short | 20 | 3 | −0.0507 | −0.0461 | −0.1169 | −0.0830 | −0.0257 | +0.0223 | −0.3667 / +0.1670 |
| G1, SPY move | 20 | 16 up | +3.49 % | +4.06 % | −6.00 % | +1.50 % | +7.11 % | +11.98 % | −30.61 / +39.57 % |
| G2, h=0.25 overlay | 23 | 7 | −0.0035 | −0.0085 | −0.0196 | −0.0126 | +0.0018 | +0.0144 | −0.0268 / +0.0516 |
| G3, h=0.25 overlay | 31 | 7 | −0.0050 | −0.0102 | −0.0181 | −0.0154 | −0.0024 | +0.0163 | −0.0268 / +0.0593 |

An insurance premium that pays out too rarely: the median episode is a small loss, and only two G1 episodes pay
materially (2008–09, 2002). Leave-out (`results/analysis/loo-G{1,2,3}.txt`): c1 clears −0.05 only after dropping G1's 4
worst episodes (2020, 2011, 2026, 2025) or G2's 2 worst; G3 still fails after 5 drops.

**4c. Bleed from bear rallies and V-rebounds, split by phase and regime** (`results/analysis/phase.txt`; regime = the
pack's rule). Bear leg = peak to trough inside a bear (the three Phase B windows plus COVID 2020-02-19 → 03-23, labelled
as outside the rule); post-trough = the 6 months after each trough; other = everything else. h=0.25 overlay log, SPY
sessions in brackets:

| gate | bear leg | post-trough (the V-rebound) | other (false alarms) | total |
|---|---|---|---|---|
| G1 | +0.1875 (735), of which DOWN +0.1793 | −0.2453 (187), of which DOWN −0.2487 | −0.1536 (289), of which DOWN −0.1764 | −0.2114 |
| G2 | +0.1699 (661) | −0.1521 (111) | −0.0971 (158) | −0.0793 |
| G3 | +0.1547 (767) | −0.1426 (147) | −0.1662 (237) | −0.1541 |

The split is stable to a 3 / 6 / 12-month post-trough window (G1 −0.2311 / −0.2453 / −0.2453). Bear-leg figures are net
of in-bear rallies: in 2022, G1's on-days saw SPY +0.0343 log while the whole decline (−0.3153) came on its off-days
(`results/analysis/lateness.txt`).

**Exposure by period and regime (RV2)**, G1 at h=0.25 (overlay log, sessions on):

| period | total | UP | MIXED | DOWN |
|---|---|---|---|---|
| 2000–02 | +0.0358 (404) | 0 | +0.0008 (29) | +0.0350 (375) |
| 2003–07 | −0.0302 (59) | 0 | +0.0082 (5) | −0.0384 (54) |
| 2008–09 | +0.0539 (284) | 0 | +0.0008 (5) | +0.0531 (279) |
| 2010–19 | −0.0922 (221) | 0 | +0.0287 (39) | −0.1209 (182) |
| 2020–21 | −0.0886 (53) | 0 | −0.0122 (5) | −0.0764 (48) |
| 2022–23 | −0.0409 (142) | 0 | +0.0141 (25) | −0.0550 (117) |
| 2024–26 | −0.0492 (48) | −0.0111 (5) | +0.0052 (14) | −0.0433 (29) |

G2 by the same periods: +0.0408 (394), −0.0347 (44), +0.0288 (246), −0.0732 (134), 0 (0), −0.0257 (98), −0.0154 (14). The
overlay is on almost only in DOWN regimes; it earns in the two secular bears and loses in DOWN-labelled weeks of every
period after 2009.

**4d. Year table and running ratio** (`results/analysis/years.txt`; h=0.25; base = s0; per-salt h=0.5 in
`results/years-s*.txt`). Each gate cell: overlay log for the year → combined/base ratio at year-end.

| year | SPY TR | base | G1 | G2 | G3 |
|---|---:|---:|---|---|---|
| 2000 | −0.0927 | +0.1367 | +0.0088 → 1.009 | +0.0088 → 1.009 | −0.0216 → 0.979 |
| 2001 | −0.1251 | −0.0604 | −0.0008 → 1.008 | +0.0042 → 1.013 | +0.0073 → 0.986 |
| 2002 | −0.2431 | −0.0049 | +0.0278 → 1.036 | +0.0278 → 1.042 | +0.0209 → 1.007 |
| 2003 | +0.2483 | +0.1970 | −0.0141 → 1.022 | −0.0223 → 1.019 | −0.0310 → 0.976 |
| 2004 | +0.1016 | +0.1791 | −0.0122 → 1.010 | −0.0085 → 1.010 | −0.0085 → 0.968 |
| 2007 | +0.0502 | +0.0819 | −0.0039 → 1.006 | −0.0039 → 1.006 | −0.0119 → 0.956 |
| 2008 | −0.4588 | −0.0285 | +0.0531 → 1.060 | +0.0468 → 1.054 | +0.0565 → 1.012 |
| 2009 | +0.2339 | +0.0304 | +0.0008 → 1.061 | −0.0180 → 1.036 | −0.0180 → 0.994 |
| 2010 | +0.1403 | +0.2599 | −0.0192 → 1.041 | 0 | 0 |
| 2011 | +0.0188 | −0.0174 | −0.0312 → 1.009 | −0.0413 → 0.994 | −0.0594 → 0.936 |
| 2015 | +0.0123 | +0.0769 | −0.0124 → 0.997 | −0.0124 → 0.982 | −0.0237 → 0.914 |
| 2016 | +0.1133 | +0.0547 | −0.0201 → 0.977 | −0.0103 → 0.971 | −0.0051 → 0.910 |
| 2018 | −0.0468 | −0.0827 | +0.0110 → 0.988 | +0.0110 → 0.982 | +0.0103 → 0.919 |
| 2019 | +0.2717 | +0.1241 | −0.0203 → 0.968 | −0.0203 → 0.963 | −0.0267 → 0.895 |
| 2020 | +0.1683 | +0.1328 | −0.0886 → 0.886 | 0 | 0 |
| 2022 | −0.2006 | −0.0631 | −0.0409 → 0.850 | −0.0257 → 0.938 | −0.0279 → 0.870 |
| 2025 | +0.1631 | −0.1441 | −0.0205 → 0.833 | −0.0154 → 0.924 | −0.0154 → 0.857 |
| 2026 (to 06-25) | +0.0793 | −0.0317 | −0.0287 → 0.809 | 0 | 0 |

Years not listed (2005–06, 2012–14, 2017, 2021, 2023–24) have the overlay off in every gate. The overlay builds only in
2000–02 and 2008 (peak G1 1.061, G2 1.054 at end-2009), gives it all back by 2011, and erodes in every era after.

### 5. Why

**5.1 Criterion 2 is out of reach by construction: the record's binding drawdowns are not bears**
(`results/analysis/windows-s{0,1,2}.txt`, `base-dd-s*.txt`).
- The base has four ~20 % drawdowns: 2007-07 → 2010-02 (18.94 %), 2018-09 → 2020-03 (20.71 %), 2021-06 → 2023-10
  (20.99 %), 2024-11 → 2026-06 (22.52 %, open at the end). Passing c2 needs combined max DD ≤ 19.52 % (s0), so all four
  would have to be cut.
- **The binding window is a rising market:** in 2024-11-26 → 2026-06-24 SPY made +0.2198 log (+24.6 %) while the base
  lost −0.2551 — the 2025–26 picks drawdown. The gate fired only at the spring 2025 and spring 2026 dips, each followed
  by a rebound (G1 h=0.25 −0.0492 in the window, 26.24 % DD; G2/G3 −0.0154, 23.70 %). Any hedge flat or short through a
  +24.6 % SPY window leaves that drawdown at least as deep; shrinking h drives the DD change toward 0, never to +3.
- 2021-06 → 2023-10: SPY flat (+0.0155); the overlay was whipsawed in the 2022 bear (G1 −0.0409, DD 24.16 %).
  2018-09 → 2020-03 ends in the COVID crash, which fell before any lagged gate fired (G1 −0.0029, DD 20.94 %). Only
  2007-07 → 2010-02 improves (G1 +0.0500, DD 18.94 → 15.88 %).
- **In the deep bears the record is already defended:** 2000-03 → 2002-10 SPY −0.6446 vs base +0.0860; 2007-10 →
  2009-03 SPY −0.8027 vs base −0.1015, because the macro gate holds cash there. The overlay's bear gains land where the
  record needed them least.

**5.2 Gate lateness** (`results/analysis/lateness.txt`, `tails.txt`, `covers.txt`):

| bear | share of the decline done before G1 first on | share captured on on-days | post-trough exposure |
|---|---:|---:|---|
| 2000–02 | 16 % | 59 % | 41 sessions, SPY +0.1641 |
| 2007–09 | 6 % | 73 % | 33 sessions, SPY +0.2480 |
| 2020 (COVID) | 94 % (first on 2020-03-23, the trough day) | — | 52 sessions, SPY +0.3593 |
| 2022 | 31 % | none (SPY rose on on-days) | 27 sessions, SPY +0.1050 |

- 2020: SPY was still Stage 2 on 2020-03-13 (245.48 vs WMA 286.14) because the MA had not turned; Stage 4 first read on
  2020-03-20 (209.78) and lasted to 2020-05-29.
- The gate is on in volatility clusters, where both tails sit: on 18.2 % of sessions, it holds 37 of the 50 largest up
  days and 31 of the 50 largest down days (9 of the top 10 up days).
- The exit is whipsawed too: over the 5 sessions after each cover SPY fell −0.1972 (G1) and −0.3050 (G2), though one
  cover can carry the sum.

**5.3 Rebound bleed and false alarms** (§4c): for G1, post-trough exposure costs −0.2453 against +0.1875 earned in the
bear legs, and false alarms (2004, 2010, 2011, 2015–16, 2018–19, 2025, 2026) cost a further −0.1536. 2020 alone is
−0.0886, 42 % of G1's cost at h=0.25. G2 and G3 skip 2020 (the macro composite was never Bearish) but still lose
post-trough (−0.1521, −0.1426).

**5.4 Costs** (`results/analysis/decomp.txt`, h=0.25; closes to within 0.0002 of the exact overlay):

| gate | SPY arithmetic return while on | SPY price move while on (× −h) | daily-rebalance variance | dividends paid | borrow |
|---|---:|---:|---:|---:|---:|
| G1 | +16.1 %/yr (all sessions 9.8 %) | +0.4611 → −0.1153 | −0.0744 | −0.0189 | −0.0030 |
| G2 | +7.0 %/yr | +0.0067 → −0.0017 | −0.0598 | −0.0156 | −0.0023 |
| G3 | +12.1 %/yr | +0.2655 → −0.0664 | −0.0669 | −0.0181 | −0.0029 |

G2's on-weeks are weaker than average but SPY's price was flat across them, so its cost is mostly variance decay and
dividends; a held short saves 0.035–0.038 (§3). Crediting proceeds interest would add +0.0210 (G1), +0.0182 (G2),
+0.0250 (G3); the record pays no short rebate, so the primary read is the record-consistent one.

**5.5 The lagged regime label does not forecast** (`results/analysis/regime-check.txt`): read one week late, DOWN weeks
returned 13.2 / 9.6 / 9.4 %/yr and UP weeks 10.5 / 9.8 / 8.5 %/yr across three MA definitions; read the same week the
label separates sharply (DOWN −21.1 vs UP +24.5 %/yr). A lagged DOWN label describes the past week.

**5.6 Three events traced end to end** (`results/analysis/traces-s0.txt`):
1. **2020 V-rebound (G1 #15):** short from the 2020-03-20 close (209.78) to 2020-06-05 (292.79), SPY +39.6 %: −0.3667 at
   h=1, −0.0886 at h=0.25, while the base made +0.0797 by re-entering. G2/G3 were off.
2. **2008–09 (G1 #8), split at the trough:** 2008-06-30 → 2009-03-09 SPY −45.8 %, the short +0.1254 at h=0.25 while the
   base lost only −0.0101 (in cash); 2009-03-10 → 04-24 SPY +28.1 %, the short gave back −0.0654 (52 %) in 33 sessions
   while the base was flat (the 2009 sit-out).
3. **Spring 2025, inside the binding drawdown (G1 #19, G2 #23):** Stage 4 read 2025-03-28 (547.94); G1 made +0.0271 to
   the 2025-04-08 low (489.58), then lost −0.0476 in the +19.7 % rebound to 05-16 (including +10.5 % on 04-09). G2 was
   short 2025-04-14 → 05-02 into SPY +6.1 %, −0.0154.

**5.7 Phase B comparison** (`results/analysis/omacro-summary-s0.txt`): the same G3 overlay at h=0.25 costs −0.1765 on
O's frozen-A-D macro (398 Bearish weeks) and −0.1541 on N (233); the breadth fix explains only +0.022 of Phase B's
−0.30. The rest is Phase B's own exposure path (inferred, not measured here: open shorts stayed on after the macro left
Bearish, since v0 had no cover on non-Bearish weeks). Per bear, Phase B's +0.094 / +0.229 / −0.025 compares with G3 on N
at +0.0693 / +0.0841 / +0.0013.

### 6. How it fits what we know

- **Shorts Phase B (`project_shorts_liveness_dead`): confirms and closes.** Phase B's exposure-timing reason (Bearish
  weeks hold the V-rebounds) reproduces with the index's own gate at constant size. The index-shaped protection is real
  in the two secular bears (+0.08 / +0.12 at h=0.25) but never reaches the record's binding drawdowns. Bear protection
  through shorts is closed in both forms.
- **Barbell (`project_barbell_on_stocks`): confirms from the short side** — in deep bears the record is already in cash,
  so the hedge pays where the record does not need it.
- **Regime barbell direction:** the record wins when SPY is down; its weak cells are turns, fast bears and melt-ups,
  exactly where the index short loses (2020, 2022, 2025, 2026).
- **Index-stage veto:** read every protection lever against the 2020 recovery cohort; G1's worst episode is that window.
- **Record (`project_investor_preset_broad`):** its max DD is a 2024–26 picks drawdown with SPY +24.6 %.
- **Recovery re-entry gap:** re-derived — the GFC drawdown troughs on 2010-02-04, after the bear, in the post-trough
  phase where a short bleeds.
- **Breadth fix (`project_breadth_fix_ad_frozen`): refines** — the frozen input moves the macro-gated short by only
  +0.022.
- **Fat-tail edge: consistent.** The overlay does not touch winners; it fails on timing and beta.
- **Contradictions:** none found.

### 7. What it implies next (options; the choice is the user's)

1. **Stop here (recommended).** Bear protection through shorts is closed: single names by Phase B round 1, the index by
   this screen. The record's remaining drawdown risk is the long book lagging in rising and recovering markets (2009–10,
   2021–23, 2024–26), which a bear-only short cannot hedge; the levers for that are selection and exits in UP regimes.
2. **Only if the user wants another index-hedge question:** a new pre-registration with a different objective (c2 as
   written is unreachable for any bear-only hedge on this record; a per-bear drawdown or Ulcer measure instead), a held
   short, and a faster cover with a book basis (the Ch. 7 buy-stop above a rally high). Expected value is low: G2 h=0.25
   already clears c1 and c3 as a held short, but no cover rule turns the 2024–26 window into a gain.
3. **Out of scope:** `Spy_only_weinstein` `enable_stage4_short` is a standalone SPY strategy, not an overlay.

### 8. Rule 4 classification of the short-side flags (recommendation; the user decides)

Recommended class: **REJECT-do-not-revive** for the single-name short book, as a return lever and as bear protection
(Phase B −0.93 / −0.80 log ex interest, every book-rule cohort negative; this screen removes the hedge rationale).

| flag | eligible for retirement? | reason |
|---|---|---|
| `short_min_price_on_order_price` (#3131) | after 3 unused sessions | short-only, default off, sim-only |
| `share_class_gate_covers_shorts` (#3146) | after 3 unused sessions | short-only, default off, sim-only |
| `margin_config.short_maintenance_finra` (#3148) | after 3 unused sessions | short-only, default off, sim-only |
| `short_tightened_ratchet_follows_decline` (#3145 study arm) | after 3 unused sessions | short-only, default off, sim-only |
| `enable_short_side` | **not eligible** | defaults to `true`, so deletion is a behaviour change (R5); drives the live weekly report's "Short candidates" section; 202 of 319 scenario files inherit it |
| `tightened_can_ratchet` | **not eligible** | shared with the long-side topping-zone stop |

Retiring `enable_short_side` would first need a separate config-default PR with paired goldens. The #3221 flags
(`short_cancel_on_non_bearish`, `short_entry_order_max_rest_weeks`), classified keep-as-axis by the Phase B ledger,
could join the retirement set — the user's call. The alternative class (keep-as-axis, on the data-blocked squeeze
filter) is not recommended: removing every squeeze leaves the Phase B book deeply negative. Record it in the ledger
notes, `project_shorts_liveness_dead`, and the next `dev/notes/mechanism-flag-inventory-*.md`.

### 9. Defects found

1. **This experiment's `overlay.awk`** dropped the session after each holiday row (§0; fixed). Also fixed: the credit
   rate was not floored at 0, and borrow/credit accrued on holiday rows (≤ 0.0005 log).
2. **Shared library: year-straddling weeks split into two weekly bars.**
   `trading/analysis/technical/indicators/time_period/lib/week_bucketing.ml` keys weeks on `Date.week_number` plus the
   calendar `Date.year`, not the ISO week-year, so a week across 1 January becomes two bars (e.g. SPY rows 2001-12-28 /
   2001-12-31 / 2002-01-04 in `results/spy-weekly-stage.csv`; 11 year-ends 2000–2026). It feeds the strategy's weekly
   views and the A-D weekly aggregation. Immaterial to this verdict; filed as an issue.
3. **Simulator metric, minor:** the equity curve's 236 US-holiday rows are trading steps, so the Sharpe uses 6,894 marks
   (N s0 0.5262 vs 0.5355 on SPY sessions only). Root cause not traced (candidate: non-US listings with bars on US
   holidays).
4. **Known (#3139):** 59 holiday-Friday weeks have no macro reading.

### 10. Rigor checks (`mechanism-validation-rigor.md`)

1. **Estimand:** an offline daily-rebalanced multiplicative overlay vs a held SPY short whose P&L feeds back into the
   book; bounded by the sum form, a held short, extra lag and credit (§3). c2 is unaffected; c1 for G2 moves ≤ 0.046.
2. **Distribution:** §4a–b. 3. **Scale:** G1 h=0.25 costs 0.87 pp/yr of CAGR (8.87 → 8.01 %), G2 h=0.25 0.33 pp/yr.
4. **Selection:** gates use only information at the lagged decision week; bear windows pre-registered.
5. **Surface:** 3 gates × 3 h × 2 lags × 2 credit settings, plus 2 estimands and 2 macro inputs; every cell worsens with
   h on c1 and c2, no interior optimum.
6. **Paired, event-level:** exact per-day pairing on the same base path; episode table; three traces.
7. **Power:** one SPY path, 20 / 23 / 31 episodes; G2's c1 failure rests on 2 episodes; c2's failure is a bound, not a
   sampling statement; the salts are not independent draws of the overlay.
8. **V6:** no pair to diff (the combined arm is the base plus an analytic SPY leg); SPY never appears in the long book
   (0 rows in `trades.csv` and `open_positions.csv`); the base's V6 passes every salt; universe PIT top-3000 v12.

### 11. Review-pack look

Not applicable: an offline overlay, not a run, and the pre-registration asks for no pack. The base N pack
(https://claude.ai/artifact/HbW7eoNG9A4tuMNsEH6b6c) was rendered and read in #3261; its era bullets are the profile this
reading explains.

### Reproduce

```sh
sh dev/experiments/index-hedge-screen-2026-10-12/scripts/run.sh            # results/*.txt (rule reads)
sh dev/experiments/index-hedge-screen-2026-10-12/scripts/analysis/run.sh   # results/analysis/* (this reading)
```
