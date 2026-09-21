# Post-run validation report

Invariant checks failing: 3
audit join: 705/705 rows matched

QUALITY-FLAG: 1 fallback exits (V16)

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 103 violations
    ZG 2020-02-20 Virgin_territory but only 453 weekly bars (< 520) before entry
    YETI 2020-06-08 Virgin_territory but only 87 weekly bars (< 520) before entry
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    WING 2017-08-08 Virgin_territory but only 113 weekly bars (< 520) before entry
    VRSK 2017-02-22 Virgin_territory but only 388 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    VICI 2019-10-16 Virgin_territory but only 105 weekly bars (< 520) before entry
    VC 2015-05-22 Virgin_territory but only 245 weekly bars (< 520) before entry
    UNVR 2022-03-15 Virgin_territory but only 354 weekly bars (< 520) before entry
    ULTA 2013-08-02 Virgin_territory but only 304 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 69 violations (250 skipped)
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.74
    WRLD 2010-03-12 prior_top=49.25 within +25% of entry=43.75
    VRTX 2014-06-28 prior_top=93.77 within +25% of entry=92.22
    URBN 2025-03-13 prior_top=58.19 within +25% of entry=50.12
    UNVR 2022-03-15 prior_top=32.43 within +25% of entry=32.37
    UHS 2018-08-22 prior_top=138.68 within +25% of entry=128.84
    TYL 2021-07-24 prior_top=497.85 within +25% of entry=491.82
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    THI 2014-08-09 prior_top=62.34 within +25% of entry=61.84
    TGTX 2018-03-05 prior_top=18.68 within +25% of entry=15.45
V10 EXPECTATION 11 violations (250 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    PYX 2018-10-08 entry_wk_close=43.05 > prior=18.60 (spike>60%)
    MVL 2002-03-08 entry_wk_close=5.33 > prior=3.00 (spike>60%)
    IPSU 2011-06-02 entry_wk_close=21.47 > prior=12.99 (spike>60%)
    EOSE 2023-06-27 entry_wk_close=4.34 > prior=2.43 (spike>60%)
    ECHO 2025-08-26 entry_wk_close=61.79 > prior=26.93 (spike>60%)
    CLPA 2000-01-31 entry_wk_close=25.25 > prior=12.12 (spike>60%)
    CBMC 2000-03-06 entry_wk_close=191.25 > prior=71.25 (spike>60%)
    BTDR 2024-11-29 entry_wk_close=14.27 > prior=7.83 (spike>60%)
    BLNK 2020-07-29 entry_wk_close=11.05 > prior=5.28 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 15 violations
    YMM 2024-11-20 installed_stop=8.2848 vs fill=9.7700 -> dist=0.1520 > gate=0.1500
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.1800 -> dist=0.9189 > gate=0.1500
    SMTC 2018-04-10 installed_stop=35.8750 vs fill=42.2800 -> dist=0.1515 > gate=0.1500
    NJDCY 2015-06-08 installed_stop=15.2160 vs fill=17.9500 -> dist=0.1523 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.7700 -> dist=0.1536 > gate=0.1500
    MGM 2001-09-18 installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500
    LPG 2023-09-15 installed_stop=23.2022 vs fill=27.3000 -> dist=0.1501 > gate=0.1500
    GRA 2016-01-22 installed_stop=73.1724 vs fill=86.3000 -> dist=0.1521 > gate=0.1500
    FULT 2002-03-07 installed_stop=23.3952 vs fill=19.5000 -> dist=0.1998 > gate=0.1500
    EOG 2000-05-01 installed_stop=21.9602 vs fill=25.8500 -> dist=0.1505 > gate=0.1500
V13 INVARIANT 123 violations (4 skipped)
    ZWS 2018-10-06 no bar on entry_date 2018-10-06 (nearest earlier bar: 2018-10-05)
    WSO 2010-03-06 no bar on entry_date 2010-03-06 (nearest earlier bar: 2010-03-05)
    WPM 2024-04-20 no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)
    WPC 2012-10-06 no bar on entry_date 2012-10-06 (nearest earlier bar: 2012-10-05)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WING 2017-08-08 entry_price=31.6000 outside 2017-08-08 bar [32.7300, 34.1600]
    WBTN 2025-08-23 no bar on entry_date 2025-08-23 (nearest earlier bar: 2025-08-22)
    WAFD 2013-06-29 no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)
    VVC 2018-04-28 no bar on entry_date 2018-04-28 (nearest earlier bar: 2018-04-27)
    VRTX 2014-06-28 no bar on entry_date 2014-06-28 (nearest earlier bar: 2014-06-27)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION 1 violations
    CLE 2014-11-18 force_liquidation exit 2014-11-19 (entry 2014-11-18 @ 37.65, exit @ 0.71)
V17 EXPECTATION PASS
V18 EXPECTATION 15 violations
    BLNK 2020-07-29 median close 1.61 over 4078 bars (2008-07-15..2026-06-08); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0
    BOKF 2003-06-04 median close 49.73 over 8751 bars (1991-09-05..2026-06-08); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    BRK-A 2006-05-18 median close 83000.00 over 11225 bars (1980-03-17..2026-06-08), above the 10000.00 ceiling
    CECO 2023-10-13 median close 4.59 over 11471 bars (1980-12-02..2026-06-08); bar 1992-09-29 close 2.66 (+399.96% vs prior close 0.53) on volume 0
    CEQP 2018-01-22 median close 25.49 over 5608 bars (2001-07-26..2023-11-16); bar 2023-11-14 close 0.00 (-100.00% vs prior close 28.26) on volume 0
    CIR 2013-04-24 median close 32.28 over 6046 bars (1999-10-18..2023-11-16); bar 2023-11-06 close 0.00 (-100.00% vs prior close 56.00) on volume 0
    CLE 2014-11-18 median close 19.00 over 4813 bars (1997-12-31..2018-06-28); bar 2014-06-09 close 0.07 (-94.53% vs prior close 1.28) on volume 0
    CSKI 2009-12-19 median close 0.20 over 5186 bars (1995-02-01..2015-10-05); bar 2002-12-13 close 0.45 (+542.86% vs prior close 0.07) on volume 0
    FLO 2020-03-09 median close 18.19 over 11651 bars (1980-03-17..2026-06-08); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    IHG 2024-10-15 median close 37.37 over 5828 bars (2003-04-08..2026-06-08); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0
