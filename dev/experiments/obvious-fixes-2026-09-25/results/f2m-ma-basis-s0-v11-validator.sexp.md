# Post-run validation report

Invariant checks failing: 3
audit join: 740/740 rows matched

QUALITY-FLAG: 1 fallback exits (V16)

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 110 violations
    ZS 2020-05-29 Virgin_territory but only 117 weekly bars (< 520) before entry
    Z 2020-02-20 Virgin_territory but only 239 weekly bars (< 520) before entry
    XPOF 2023-01-27 Virgin_territory but only 79 weekly bars (< 520) before entry
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    WLK 2012-08-06 Virgin_territory but only 419 weekly bars (< 520) before entry
    WING 2017-08-08 Virgin_territory but only 113 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    VICI 2019-10-16 Virgin_territory but only 105 weekly bars (< 520) before entry
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
    UNVR 2022-03-15 Virgin_territory but only 354 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 81 violations (241 skipped)
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.75
    WTFC 2010-04-06 prior_top=46.07 within +25% of entry=39.54
    WRLD 2010-03-12 prior_top=49.25 within +25% of entry=43.75
    WIX 2021-04-28 prior_top=353.09 within +25% of entry=321.01
    WFG 2024-08-26 prior_top=92.49 within +25% of entry=90.10
    VRTX 2014-07-30 prior_top=99.07 within +25% of entry=92.22
    URBN 2025-12-22 prior_top=81.84 within +25% of entry=81.11
    UNVR 2022-03-15 prior_top=32.43 within +25% of entry=32.15
    UHS 2018-08-22 prior_top=138.68 within +25% of entry=128.80
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
V10 EXPECTATION 15 violations (241 skipped)
    VUZI 2026-05-29 entry_wk_close=4.60 > prior=2.84 (spike>60%)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    QBTS 2024-11-25 entry_wk_close=3.02 > prior=1.04 (spike>60%)
    PYX 2018-10-08 entry_wk_close=43.05 > prior=18.60 (spike>60%)
    MVL 2002-03-08 entry_wk_close=5.33 > prior=3.00 (spike>60%)
    ISEE 2022-09-30 entry_wk_close=17.94 > prior=9.44 (spike>60%)
    HIMX 2026-05-08 entry_wk_close=17.48 > prior=9.05 (spike>60%)
    GSIT 2025-10-20 entry_wk_close=9.23 > prior=3.84 (spike>60%)
    EXK 2020-07-20 entry_wk_close=4.20 > prior=2.14 (spike>60%)
    EOSE 2023-06-28 entry_wk_close=4.34 > prior=2.43 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 20 violations
    YMM 2024-11-20 installed_stop=8.2848 vs fill=9.7700 -> dist=0.1520 > gate=0.1500
    WKC 2004-12-20 installed_stop=44.3750 vs fill=23.6000 -> dist=0.8803 > gate=0.1500
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.3100 -> dist=0.9045 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.4700 -> dist=0.1602 > gate=0.1500
    MMS 2014-08-07 installed_stop=33.2640 vs fill=39.3800 -> dist=0.1553 > gate=0.1500
    MGM 2001-09-18 installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500
    MCK 2020-05-28 installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500
    LZB 2024-07-15 installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500
    LPG 2023-09-15 installed_stop=23.2022 vs fill=27.3000 -> dist=0.1501 > gate=0.1500
    GRA 2016-01-22 installed_stop=73.1724 vs fill=86.3000 -> dist=0.1521 > gate=0.1500
V13 INVARIANT 26 violations (5 skipped)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WLK 2012-08-06 entry_price=64.5300 outside 2012-08-06 bar [65.8500, 68.4000]
    WIRE 2023-12-14 no bar on exit_date 2024-07-03 (nearest earlier bar: 2024-07-02)
    WING 2017-08-08 entry_price=31.6500 outside 2017-08-08 bar [32.7300, 34.1600]
    VRTX 2001-03-12 exit_price=31.6400 outside 2001-03-15 bar [31.6406, 35.6250]
    SEM 2023-02-02 entry_price=30.6300 outside 2023-02-02 bar [29.7099, 30.6299]
    SAFM 2022-05-31 no bar on exit_date 2022-07-25 (nearest earlier bar: 2022-07-22)
    NPSNY 2009-08-28 entry_price=32.1200 outside 2009-08-28 bar [31.1960, 32.1180]
    NEOG 2017-09-05 entry_price=52.4700 outside 2017-09-05 bar [68.8760, 70.4406]
    MMSI 2011-03-14 entry_price=14.2900 outside 2011-03-14 bar [17.5400, 17.9500]
V14 EXPECTATION 67 violations
    Z 2020-02-20 entry bar 2020-02-20 open=62.4700 low=61.9300 close=63.6300 vs stop=63.3905, exit=63.1600
    XRAY 2000-04-25 entry bar 2000-04-25 open=27.8750 low=27.8750 close=29.1876 vs stop=28.2786, exit=28.2500
    WRLD 2010-03-12 entry bar 2010-03-12 open=43.0000 low=42.5200 close=43.6500 vs stop=41.9738, exit=41.9500
    VUZI 2026-05-29 entry bar 2026-05-29 open=4.5200 low=4.2200 close=4.6000 vs stop=4.1413, exit=4.0400
    VRNS 2022-01-27 entry bar 2022-01-27 open=34.2100 low=32.4900 close=32.7600 vs stop=30.9184, exit=32.1400
    UTL 2022-07-01 entry bar 2022-07-01 open=58.7100 low=58.0800 close=61.0000 vs stop=57.2322, exit=57.1400
    URBN 2025-12-22 entry bar 2025-12-22 open=80.4200 low=79.8700 close=80.1200 vs stop=77.8656, exit=77.8600
    UBS 2014-11-26 entry bar 2014-11-26 open=17.5500 low=17.5200 close=23.2000 vs stop=21.8076, exit=18.0900
    TRMD 2024-01-24 entry bar 2024-01-24 open=36.5500 low=35.8800 close=35.9700 vs stop=35.3096, exit=35.2700
    TR 2021-01-27 entry bar 2021-01-27 open=45.1599 low=39.5799 close=42.8501 vs stop=39.3798, exit=39.3700
V15 EXPECTATION PASS
V16 EXPECTATION 1 violations
    ASPS 2017-04-20 force_liquidation exit 2017-04-21 (entry 2017-04-20 @ 35.53, exit @ 26.75)
V17 EXPECTATION PASS
V18 EXPECTATION 14 violations
    BOKF 2003-06-04 median close 49.75 over 8753 bars (1991-09-05..2026-06-10); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    BRK-A 2014-03-28 median close 83000.00 over 11227 bars (1980-03-17..2026-06-10), above the 10000.00 ceiling
    CECO 2023-10-13 median close 4.60 over 11473 bars (1980-12-02..2026-06-10); bar 1992-09-29 close 2.66 (+399.96% vs prior close 0.53) on volume 0
    CEQP 2018-01-22 median close 25.49 over 5608 bars (2001-07-26..2023-11-16); bar 2023-11-14 close 0.00 (-100.00% vs prior close 28.26) on volume 0
    DUOT 2026-06-08 median close 2.71 over 3135 bars (2008-08-13..2026-06-10); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0
    FLO 2020-03-09 median close 18.19 over 11653 bars (1980-03-17..2026-06-10); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    IOVA 2020-03-24 median close 7.47 over 3936 bars (2010-10-15..2026-06-10); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0
    MVL 2002-03-08 median close 9.00 over 4795 bars (1999-01-04..2018-01-24); bar 2010-01-26 close 60.00 (+96.88% vs prior close 30.48) on volume 0
    NOKBF 2025-10-28 median close 5.96 over 4469 bars (2001-07-11..2026-06-10); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0
    RAL_old 2017-04-24 median close 45000.00 over 4022 bars (1997-12-31..2022-03-02), above the 10000.00 ceiling; bar 2010-04-23 close 49.84 (-99.84% vs prior close 31800.00) on volume 0
