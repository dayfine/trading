# Post-run validation report

Invariant checks failing: 3
audit join: 757/757 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 88 violations
    ZTO 2023-05-18 Virgin_territory but only 344 weekly bars (< 520) before entry
    WWAV 2016-10-07 Virgin_territory but only 209 weekly bars (< 520) before entry
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    WLK 2012-08-06 Virgin_territory but only 419 weekly bars (< 520) before entry
    WAVX 2000-02-22 Virgin_territory but only 59 weekly bars (< 520) before entry
    VC 2015-05-22 Virgin_territory but only 245 weekly bars (< 520) before entry
    UCM 2000-05-22 Virgin_territory but only 126 weekly bars (< 520) before entry
    UAA 2010-09-15 Virgin_territory but only 254 weekly bars (< 520) before entry
    TTWO 2003-11-18 Virgin_territory but only 345 weekly bars (< 520) before entry
    TSLA 2014-02-10 Virgin_territory but only 191 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 69 violations (288 skipped)
    ZTO 2023-05-18 prior_top=33.97 within +25% of entry=30.04
    YETI 2021-07-03 prior_top=94.97 within +25% of entry=92.81
    X 2023-08-21 prior_top=37.63 within +25% of entry=31.72
    WWAV 2016-10-07 prior_top=56.64 within +25% of entry=53.85
    WIX 2021-04-28 prior_top=353.09 within +25% of entry=320.94
    WAB 2018-05-14 prior_top=95.29 within +25% of entry=95.14
    VRTX 2014-06-28 prior_top=93.77 within +25% of entry=92.22
    VLO 2022-02-01 prior_top=90.06 within +25% of entry=85.44
    URBN 2025-03-13 prior_top=58.19 within +25% of entry=50.12
    ULTA 2022-11-18 prior_top=442.90 within +25% of entry=441.66
V10 EXPECTATION 6 violations (288 skipped)
    RMBS 2000-06-22 entry_wk_close=114.69 > prior=40.75 (spike>60%)
    OCHTQ 2000-02-17 entry_wk_close=6300.00 > prior=3075.00 (spike>60%)
    JKS 2020-09-29 entry_wk_close=33.65 > prior=15.33 (spike>60%)
    CBMC 2000-03-06 entry_wk_close=191.25 > prior=71.25 (spike>60%)
    ATISZ 2000-02-09 entry_wk_close=7.13 > prior=3.56 (spike>60%)
    ABRX 2000-03-09 entry_wk_close=15.00 > prior=8.44 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 29 violations
    WFM 2013-05-18 installed_stop=98.2752 vs fill=51.3400 -> dist=0.9142 > gate=0.1500
    QLYS 2021-01-20 installed_stop=106.9728 vs fill=125.8900 -> dist=0.1503 > gate=0.1500
    PNR 2003-12-01 installed_stop=42.1632 vs fill=21.9700 -> dist=0.9191 > gate=0.1500
    PENN 2001-06-02 installed_stop=15.7028 vs fill=18.8300 -> dist=0.1661 > gate=0.1500
    ODFL 2005-11-11 installed_stop=37.1520 vs fill=25.9000 -> dist=0.4344 > gate=0.1500
    ODFL 2005-11-11 installed_stop=37.1520 vs fill=25.9000 -> dist=0.4344 > gate=0.1500
    NKE 2006-10-25 installed_stop=88.3200 vs fill=46.0100 -> dist=0.9196 > gate=0.1500
    NKE 2015-07-30 installed_stop=110.7648 vs fill=57.7000 -> dist=0.9197 > gate=0.1500
    MMM 2003-07-26 installed_stop=131.9328 vs fill=69.6800 -> dist=0.8934 > gate=0.1500
    MGM 2001-09-18 installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500
V13 INVARIANT 173 violations (11 skipped)
    YUM 2022-01-01 no bar on entry_date 2022-01-01 (nearest earlier bar: 2021-12-31)
    YETI 2021-07-03 no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)
    WPM 2024-04-20 no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)
    WMB 2024-03-23 no bar on entry_date 2024-03-23 (nearest earlier bar: 2024-03-22)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WLK 2012-08-06 entry_price=64.5400 outside 2012-08-06 bar [65.8500, 68.4000]
    WFM 2013-05-18 no bar on entry_date 2013-05-18 (nearest earlier bar: 2013-05-17)
    WDC 2012-08-18 no bar on entry_date 2012-08-18 (nearest earlier bar: 2012-08-17)
    VRTX 2014-06-28 no bar on entry_date 2014-06-28 (nearest earlier bar: 2014-06-27)
    TXT 2014-11-15 no bar on entry_date 2014-11-15 (nearest earlier bar: 2014-11-14)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 9 violations
    CBE 2005-02-03 median close 74.58 over 11518 bars (1972-06-01..2018-01-30); bar 1997-05-19 close 60.00 (+92.00% vs prior close 31.25) on volume 0
    CLE 2006-12-11 median close 19.00 over 4813 bars (1997-12-31..2018-06-28); bar 2014-06-09 close 0.07 (-94.53% vs prior close 1.28) on volume 0
    FERG 2025-07-23 median close 69.80 over 4406 bars (2001-07-20..2026-06-22); bar 2001-10-22 close 60.37 (-97.71% vs prior close 2641.96) on volume 0
    ISA 2010-09-18 median close 7360.00 over 5664 bars (1997-12-31..2020-07-07); bar 2001-08-22 close 0.05 (-100.00% vs prior close 1070.00) on volume 0
    NPPXF 2014-02-12 median close 41.56 over 4380 bars (2002-12-23..2026-06-22); bar 2009-02-13 close 48.23 (-100.00% vs prior close 1000000.00) on volume 0
    RAL_old 2018-01-26 median close 45000.00 over 4022 bars (1997-12-31..2022-03-02), above the 10000.00 ceiling; bar 2010-04-23 close 49.84 (-99.84% vs prior close 31800.00) on volume 0
    RGLD 2009-11-06 median close 17.49 over 11350 bars (1981-06-09..2026-06-22); bar 1992-06-01 close 0.38 (+200.00% vs prior close 0.12) on volume 0
    RRC 2006-11-30 median close 16.75 over 9588 bars (1984-11-05..2026-06-22); bar 1992-11-23 close 4.22 (+1399.47% vs prior close 0.28) on volume 0
    UCM 2000-05-22 median close 0.10 over 3743 bars (1997-12-31..2019-12-09); bar 2010-01-04 close 0.28 (-97.37% vs prior close 10.65) on volume 0
