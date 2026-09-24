# Post-run validation report

Invariant checks failing: 4
audit join: 733/733 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT 1 violations
    IAC 2012-03-15 twin positions: IAC/MTCH
V7 INVARIANT 98 violations
    ZS 2021-07-12 Virgin_territory but only 176 weekly bars (< 520) before entry
    Z 2020-02-20 Virgin_territory but only 239 weekly bars (< 520) before entry
    WWAV 2016-10-07 Virgin_territory but only 209 weekly bars (< 520) before entry
    WLP1 2000-10-02 Virgin_territory but only 145 weekly bars (< 520) before entry
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    WLK 2012-08-06 Virgin_territory but only 419 weekly bars (< 520) before entry
    WAVX 2000-02-22 Virgin_territory but only 59 weekly bars (< 520) before entry
    VOYA 2017-11-29 Virgin_territory but only 241 weekly bars (< 520) before entry
    VC 2015-05-22 Virgin_territory but only 245 weekly bars (< 520) before entry
    UCM 2000-05-22 Virgin_territory but only 126 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 70 violations (282 skipped)
    ZBH 2012-12-12 prior_top=67.87 within +25% of entry=67.54
    YUM 2025-04-07 prior_top=158.67 within +25% of entry=144.64
    X 2023-08-21 prior_top=37.63 within +25% of entry=31.79
    WWAV 2016-10-07 prior_top=56.64 within +25% of entry=53.85
    VRTX 2014-06-28 prior_top=93.77 within +25% of entry=92.22
    VRTX 2019-11-09 prior_top=201.31 within +25% of entry=197.08
    URBN 2025-03-13 prior_top=58.19 within +25% of entry=50.12
    URBN 2026-01-06 prior_top=81.84 within +25% of entry=81.27
    ULTA 2016-04-02 prior_top=194.18 within +25% of entry=192.62
    UHS 2018-08-22 prior_top=138.68 within +25% of entry=128.80
V10 EXPECTATION 7 violations (282 skipped)
    RMBS 2000-06-22 entry_wk_close=114.69 > prior=40.75 (spike>60%)
    RBAK 2006-12-23 entry_wk_close=24.94 > prior=14.52 (spike>60%)
    OCHTQ 2000-02-17 entry_wk_close=6300.00 > prior=3075.00 (spike>60%)
    DDD 2021-01-19 entry_wk_close=34.48 > prior=11.55 (spike>60%)
    CBMC 2000-03-06 entry_wk_close=191.25 > prior=71.25 (spike>60%)
    ATISZ 2000-02-09 entry_wk_close=7.13 > prior=3.56 (spike>60%)
    ABRX 2000-03-09 entry_wk_close=15.00 > prior=8.44 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 26 violations
    WFM 2013-05-18 installed_stop=98.2752 vs fill=51.3400 -> dist=0.9142 > gate=0.1500
    VOYA 2017-11-29 installed_stop=36.7008 vs fill=43.5100 -> dist=0.1565 > gate=0.1500
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.3100 -> dist=0.9045 > gate=0.1500
    PENN 2001-06-02 installed_stop=15.7028 vs fill=18.8300 -> dist=0.1661 > gate=0.1500
    ODFL 2005-11-11 installed_stop=37.1520 vs fill=25.9300 -> dist=0.4328 > gate=0.1500
    ODFL 2005-11-11 installed_stop=37.1520 vs fill=25.9300 -> dist=0.4328 > gate=0.1500
    NRG 2006-11-18 installed_stop=50.7552 vs fill=26.9500 -> dist=0.8833 > gate=0.1500
    NKE 2006-10-25 installed_stop=88.3200 vs fill=46.0300 -> dist=0.9187 > gate=0.1500
    MMM 2003-07-26 installed_stop=131.9328 vs fill=69.6800 -> dist=0.8934 > gate=0.1500
    MGM 2001-09-18 installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500
V13 INVARIANT 151 violations (12 skipped)
    YUM 2022-01-01 no bar on entry_date 2022-01-01 (nearest earlier bar: 2021-12-31)
    WPM 2024-04-20 no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WLK 2012-08-06 entry_price=64.5300 outside 2012-08-06 bar [65.8500, 68.4000]
    WFM 2013-05-18 no bar on entry_date 2013-05-18 (nearest earlier bar: 2013-05-17)
    VRTX 2014-06-28 no bar on entry_date 2014-06-28 (nearest earlier bar: 2014-06-27)
    VRTX 2019-11-09 no bar on entry_date 2019-11-09 (nearest earlier bar: 2019-11-08)
    VRSK 2017-11-04 no bar on entry_date 2017-11-04 (nearest earlier bar: 2017-11-03)
    URBN 2025-12-20 no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)
    ULTA 2016-04-02 no bar on entry_date 2016-04-02 (nearest earlier bar: 2016-04-01)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 9 violations
    BRK-A 2006-05-18 median close 83087.55 over 11234 bars (1980-03-17..2026-06-22), above the 10000.00 ceiling
    CBE 2005-02-03 median close 74.58 over 11518 bars (1972-06-01..2018-01-30); bar 1997-05-19 close 60.00 (+92.00% vs prior close 31.25) on volume 0
    CLE 2006-12-11 median close 19.00 over 4813 bars (1997-12-31..2018-06-28); bar 2014-06-09 close 0.07 (-94.53% vs prior close 1.28) on volume 0
    IOVA 2020-12-01 median close 7.45 over 3943 bars (2010-10-15..2026-06-22); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0
    LAR 2021-10-29 median close 1.48 over 4466 bars (2008-09-18..2026-06-22); bar 2017-11-08 close 7.65 (+400.03% vs prior close 1.53) on volume 0
    RGLD 2009-11-06 median close 17.49 over 11350 bars (1981-06-09..2026-06-22); bar 1992-06-01 close 0.38 (+200.00% vs prior close 0.12) on volume 0
    RRC 2006-11-30 median close 16.75 over 9588 bars (1984-11-05..2026-06-22); bar 1992-11-23 close 4.22 (+1399.47% vs prior close 0.28) on volume 0
    UCM 2000-05-22 median close 0.10 over 3743 bars (1997-12-31..2019-12-09); bar 2010-01-04 close 0.28 (-97.37% vs prior close 10.65) on volume 0
    WWY 2007-04-30 median close 45.02 over 4141 bars (1997-12-31..2016-06-22); bar 2010-10-13 close 4.77 (-94.04% vs prior close 79.97) on volume 0
