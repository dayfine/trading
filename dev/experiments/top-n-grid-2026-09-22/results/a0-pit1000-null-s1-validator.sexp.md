# Post-run validation report

Invariant checks failing: 4
audit join: 739/739 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT 1 violations
    IAC 2012-03-15 twin positions: IAC/MTCH
V7 INVARIANT 95 violations
    ZS 2021-07-12 Virgin_territory but only 176 weekly bars (< 520) before entry
    WWAV 2016-10-07 Virgin_territory but only 209 weekly bars (< 520) before entry
    WLP1 2000-10-02 Virgin_territory but only 145 weekly bars (< 520) before entry
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    WLK 2012-08-06 Virgin_territory but only 419 weekly bars (< 520) before entry
    WAVX 2000-02-22 Virgin_territory but only 59 weekly bars (< 520) before entry
    VOYA 2017-11-29 Virgin_territory but only 241 weekly bars (< 520) before entry
    VNA 2015-02-05 Virgin_territory but only 258 weekly bars (< 520) before entry
    VC 2015-05-22 Virgin_territory but only 245 weekly bars (< 520) before entry
    UCM 2000-05-22 Virgin_territory but only 126 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 76 violations (271 skipped)
    ZBH 2012-12-12 prior_top=67.87 within +25% of entry=67.53
    YUM 2025-04-07 prior_top=158.67 within +25% of entry=144.64
    WWAV 2016-10-07 prior_top=56.64 within +25% of entry=53.85
    WIX 2021-04-28 prior_top=353.09 within +25% of entry=320.94
    WAB 2018-05-14 prior_top=95.29 within +25% of entry=95.14
    VRTX 2014-06-28 prior_top=93.77 within +25% of entry=92.22
    VRTX 2019-11-09 prior_top=201.31 within +25% of entry=197.08
    USB 2024-08-28 prior_top=51.66 within +25% of entry=46.10
    URBN 2025-03-13 prior_top=58.19 within +25% of entry=50.12
    ULTA 2016-04-02 prior_top=194.18 within +25% of entry=192.62
V10 EXPECTATION 7 violations (271 skipped)
    VTNRQ 2022-05-16 entry_wk_close=14.40 > prior=8.84 (spike>60%)
    RMBS 2000-06-22 entry_wk_close=114.69 > prior=40.75 (spike>60%)
    RBAK 2006-12-23 entry_wk_close=24.94 > prior=14.52 (spike>60%)
    OCHTQ 2000-02-17 entry_wk_close=6300.00 > prior=3075.00 (spike>60%)
    CBMC 2000-03-06 entry_wk_close=191.25 > prior=71.25 (spike>60%)
    ATISZ 2000-02-09 entry_wk_close=7.13 > prior=3.56 (spike>60%)
    ABRX 2000-03-09 entry_wk_close=15.00 > prior=8.44 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 25 violations
    WFM 2013-05-18 installed_stop=98.2752 vs fill=51.3400 -> dist=0.9142 > gate=0.1500
    VOYA 2017-11-29 installed_stop=36.7008 vs fill=43.5100 -> dist=0.1565 > gate=0.1500
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.1800 -> dist=0.9189 > gate=0.1500
    TAP 2007-09-19 installed_stop=83.6448 vs fill=49.0700 -> dist=0.7046 > gate=0.1500
    PRKS 2019-07-11 installed_stop=27.8750 vs fill=32.8900 -> dist=0.1525 > gate=0.1500
    PENN 2001-06-02 installed_stop=15.7028 vs fill=18.8300 -> dist=0.1661 > gate=0.1500
    ODFL 2005-11-11 installed_stop=37.1520 vs fill=25.9000 -> dist=0.4344 > gate=0.1500
    ODFL 2005-11-11 installed_stop=37.1520 vs fill=25.9000 -> dist=0.4344 > gate=0.1500
    NRG 2006-11-18 installed_stop=50.7552 vs fill=26.9500 -> dist=0.8833 > gate=0.1500
    NKE 2006-10-25 installed_stop=88.3200 vs fill=46.0100 -> dist=0.9196 > gate=0.1500
V13 INVARIANT 162 violations (11 skipped)
    YUM 2022-01-01 no bar on entry_date 2022-01-01 (nearest earlier bar: 2021-12-31)
    WPM 2024-04-20 no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WLK 2012-08-06 entry_price=64.5400 outside 2012-08-06 bar [65.8500, 68.4000]
    WFM 2013-05-18 no bar on entry_date 2013-05-18 (nearest earlier bar: 2013-05-17)
    WDC 2012-08-18 no bar on entry_date 2012-08-18 (nearest earlier bar: 2012-08-17)
    VRTX 2014-06-28 no bar on entry_date 2014-06-28 (nearest earlier bar: 2014-06-27)
    VRTX 2019-11-09 no bar on entry_date 2019-11-09 (nearest earlier bar: 2019-11-08)
    ULTA 2016-04-02 no bar on entry_date 2016-04-02 (nearest earlier bar: 2016-04-01)
    UAA 2021-11-20 no bar on entry_date 2021-11-20 (nearest earlier bar: 2021-11-19)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 12 violations
    BRK-A 2006-05-18 median close 83025.10 over 11230 bars (1980-03-17..2026-06-15), above the 10000.00 ceiling
    CBE 2005-02-03 median close 74.58 over 11518 bars (1972-06-01..2018-01-30); bar 1997-05-19 close 60.00 (+92.00% vs prior close 31.25) on volume 0
    CLE 2006-12-11 median close 19.00 over 4813 bars (1997-12-31..2018-06-28); bar 2014-06-09 close 0.07 (-94.53% vs prior close 1.28) on volume 0
    FERG 2025-07-23 median close 69.77 over 4402 bars (2001-07-20..2026-06-15); bar 2001-10-22 close 60.37 (-97.71% vs prior close 2641.96) on volume 0
    ISA 2010-09-18 median close 7360.00 over 5664 bars (1997-12-31..2020-07-07); bar 2001-08-22 close 0.05 (-100.00% vs prior close 1070.00) on volume 0
    LNG 2026-03-14 median close 27.70 over 8104 bars (1994-04-04..2026-06-15); bar 1994-07-19 close 6.00 (+500.00% vs prior close 1.00) on volume 0
    RGLD 2009-11-06 median close 17.48 over 11346 bars (1981-06-09..2026-06-15); bar 1992-06-01 close 0.38 (+200.00% vs prior close 0.12) on volume 0
    RRC 2006-11-30 median close 16.75 over 9584 bars (1984-11-05..2026-06-15); bar 1992-11-23 close 4.22 (+1399.47% vs prior close 0.28) on volume 0
    UCM 2000-05-22 median close 0.10 over 3743 bars (1997-12-31..2019-12-09); bar 2010-01-04 close 0.28 (-97.37% vs prior close 10.65) on volume 0
    VNA 2015-02-05 median close 3100.00 over 1882 bars (2010-02-22..2018-02-28); bar 2015-12-11 close 29.09 (-98.79% vs prior close 2400.00) on volume 0
