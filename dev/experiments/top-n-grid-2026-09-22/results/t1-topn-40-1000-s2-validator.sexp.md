# Post-run validation report

Invariant checks failing: 3
audit join: 767/767 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 91 violations
    ZS 2021-07-12 Virgin_territory but only 176 weekly bars (< 520) before entry
    WWAV 2016-10-07 Virgin_territory but only 209 weekly bars (< 520) before entry
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    WLK 2012-08-06 Virgin_territory but only 419 weekly bars (< 520) before entry
    WAVX 2000-02-22 Virgin_territory but only 59 weekly bars (< 520) before entry
    ULTA 2013-08-02 Virgin_territory but only 304 weekly bars (< 520) before entry
    ULTA 2017-03-06 Virgin_territory but only 494 weekly bars (< 520) before entry
    UCM 2000-05-22 Virgin_territory but only 126 weekly bars (< 520) before entry
    UAA 2010-09-15 Virgin_territory but only 254 weekly bars (< 520) before entry
    TTWO 2003-11-18 Virgin_territory but only 345 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 73 violations (294 skipped)
    ZD 2021-06-05 prior_top=111.23 within +25% of entry=111.00
    YUM 2025-04-07 prior_top=158.67 within +25% of entry=144.64
    YETI 2021-07-03 prior_top=94.97 within +25% of entry=92.81
    WWAV 2016-10-07 prior_top=56.64 within +25% of entry=53.85
    WAB 2018-05-14 prior_top=95.29 within +25% of entry=95.13
    VRTX 2014-06-28 prior_top=93.77 within +25% of entry=92.22
    URBN 2025-03-13 prior_top=58.19 within +25% of entry=50.12
    ULTA 2016-04-02 prior_top=194.18 within +25% of entry=192.62
    UHS 2018-08-22 prior_top=138.68 within +25% of entry=128.79
    UAA 2021-11-20 prior_top=30.47 within +25% of entry=26.66
V10 EXPECTATION 7 violations (294 skipped)
    RMBS 2000-06-22 entry_wk_close=114.69 > prior=40.75 (spike>60%)
    OCHTQ 2000-02-17 entry_wk_close=6300.00 > prior=3075.00 (spike>60%)
    MARA 2023-12-19 entry_wk_close=26.71 > prior=11.41 (spike>60%)
    JKS 2020-09-29 entry_wk_close=33.65 > prior=15.33 (spike>60%)
    CBMC 2000-03-06 entry_wk_close=191.25 > prior=71.25 (spike>60%)
    ATISZ 2000-02-09 entry_wk_close=7.13 > prior=3.56 (spike>60%)
    ABRX 2000-03-09 entry_wk_close=15.00 > prior=8.44 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 29 violations
    YMM 2024-11-20 installed_stop=8.2848 vs fill=9.7600 -> dist=0.1511 > gate=0.1500
    WFM 2013-05-18 installed_stop=98.2752 vs fill=51.3400 -> dist=0.9142 > gate=0.1500
    PNR 2003-12-01 installed_stop=42.1632 vs fill=22.0000 -> dist=0.9165 > gate=0.1500
    PENN 2001-06-02 installed_stop=15.7028 vs fill=18.8300 -> dist=0.1661 > gate=0.1500
    ODFL 2005-11-11 installed_stop=37.1520 vs fill=25.8600 -> dist=0.4367 > gate=0.1500
    ODFL 2005-11-11 installed_stop=37.1520 vs fill=25.8600 -> dist=0.4367 > gate=0.1500
    O 2019-09-03 installed_stop=63.3750 vs fill=74.5600 -> dist=0.1500 > gate=0.1500
    NKE 2006-10-25 installed_stop=88.3200 vs fill=46.0400 -> dist=0.9183 > gate=0.1500
    NKE 2015-07-30 installed_stop=110.7648 vs fill=57.7000 -> dist=0.9197 > gate=0.1500
    MTN 2020-11-09 installed_stop=218.2464 vs fill=261.7800 -> dist=0.1663 > gate=0.1500
V13 INVARIANT 170 violations (12 skipped)
    ZD 2021-06-05 no bar on entry_date 2021-06-05 (nearest earlier bar: 2021-06-04)
    YUMC 2019-12-21 no bar on entry_date 2019-12-21 (nearest earlier bar: 2019-12-20)
    YUM 2022-01-01 no bar on entry_date 2022-01-01 (nearest earlier bar: 2021-12-31)
    YETI 2021-07-03 no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)
    WPM 2024-04-20 no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WLK 2012-08-06 entry_price=64.6000 outside 2012-08-06 bar [65.8500, 68.4000]
    WFM 2013-05-18 no bar on entry_date 2013-05-18 (nearest earlier bar: 2013-05-17)
    WDC 2012-08-18 no bar on entry_date 2012-08-18 (nearest earlier bar: 2012-08-17)
    VZ 2025-03-08 no bar on entry_date 2025-03-08 (nearest earlier bar: 2025-03-07)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 12 violations
    BRK-A 2018-09-19 median close 83025.10 over 11230 bars (1980-03-17..2026-06-15), above the 10000.00 ceiling
    CBE 2005-02-03 median close 74.58 over 11518 bars (1972-06-01..2018-01-30); bar 1997-05-19 close 60.00 (+92.00% vs prior close 31.25) on volume 0
    CLE 2006-12-11 median close 19.00 over 4813 bars (1997-12-31..2018-06-28); bar 2014-06-09 close 0.07 (-94.53% vs prior close 1.28) on volume 0
    IOVA 2020-12-01 median close 7.46 over 3939 bars (2010-10-15..2026-06-15); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0
    ISA 2010-09-18 median close 7360.00 over 5664 bars (1997-12-31..2020-07-07); bar 2001-08-22 close 0.05 (-100.00% vs prior close 1070.00) on volume 0
    LNG 2026-03-14 median close 27.70 over 8104 bars (1994-04-04..2026-06-15); bar 1994-07-19 close 6.00 (+500.00% vs prior close 1.00) on volume 0
    RAL_old 2017-04-24 median close 45000.00 over 4022 bars (1997-12-31..2022-03-02), above the 10000.00 ceiling; bar 2010-04-23 close 49.84 (-99.84% vs prior close 31800.00) on volume 0
    RGLD 2009-11-06 median close 17.48 over 11346 bars (1981-06-09..2026-06-15); bar 1992-06-01 close 0.38 (+200.00% vs prior close 0.12) on volume 0
    RRC 2006-11-30 median close 16.75 over 9584 bars (1984-11-05..2026-06-15); bar 1992-11-23 close 4.22 (+1399.47% vs prior close 0.28) on volume 0
    SFI 2020-12-02 median close 24200.00 over 2823 bars (2010-12-14..2022-03-02), above the 10000.00 ceiling
