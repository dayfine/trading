# Post-run validation report

Invariant checks failing: 3
audit join: 723/723 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 116 violations
    ZS 2020-05-29 Virgin_territory but only 117 weekly bars (< 520) before entry
    XPOF 2023-01-27 Virgin_territory but only 79 weekly bars (< 520) before entry
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    WLK 2012-08-06 Virgin_territory but only 419 weekly bars (< 520) before entry
    VRSK 2017-02-22 Virgin_territory but only 388 weekly bars (< 520) before entry
    VNA 2015-02-05 Virgin_territory but only 258 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    VICI 2019-10-16 Virgin_territory but only 105 weekly bars (< 520) before entry
    VC 2015-05-22 Virgin_territory but only 245 weekly bars (< 520) before entry
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 80 violations (236 skipped)
    ZGN 2023-09-08 prior_top=15.43 within +25% of entry=14.25
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.74
    WRLD 2010-03-12 prior_top=49.25 within +25% of entry=43.75
    WIX 2021-04-28 prior_top=353.09 within +25% of entry=320.94
    VRTX 2014-07-31 prior_top=99.07 within +25% of entry=89.97
    URBN 2025-03-13 prior_top=58.19 within +25% of entry=50.12
    UNVR 2022-03-15 prior_top=32.43 within +25% of entry=32.37
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TTWO 2020-05-19 prior_top=137.99 within +25% of entry=136.47
    TGTX 2018-03-05 prior_top=18.68 within +25% of entry=15.45
V10 EXPECTATION 13 violations (236 skipped)
    VUZI 2026-05-29 entry_wk_close=4.60 > prior=2.84 (spike>60%)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    QBTS 2024-11-25 entry_wk_close=3.02 > prior=1.04 (spike>60%)
    OKLO 2024-11-04 entry_wk_close=24.47 > prior=9.15 (spike>60%)
    MVL 2002-03-08 entry_wk_close=5.33 > prior=3.00 (spike>60%)
    ISEE 2022-09-30 entry_wk_close=17.94 > prior=9.44 (spike>60%)
    GSIT 2025-10-20 entry_wk_close=9.23 > prior=3.84 (spike>60%)
    EOSE 2023-06-27 entry_wk_close=4.34 > prior=2.43 (spike>60%)
    CUTRQ 2022-03-28 entry_wk_close=72.31 > prior=40.49 (spike>60%)
    CLPA 2000-01-31 entry_wk_close=25.25 > prior=12.12 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 17 violations
    WKC 2004-12-20 installed_stop=44.3750 vs fill=23.6000 -> dist=0.8803 > gate=0.1500
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.1800 -> dist=0.9189 > gate=0.1500
    SMTC 2018-04-10 installed_stop=35.8750 vs fill=42.2800 -> dist=0.1515 > gate=0.1500
    MGM 2001-09-18 installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500
    LZB 2024-07-15 installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500
    LPG 2023-09-15 installed_stop=23.2022 vs fill=27.3000 -> dist=0.1501 > gate=0.1500
    GC 2020-04-06 installed_stop=1392.8640 vs fill=1647.7000 -> dist=0.1547 > gate=0.1500
    GBCI 2006-09-21 installed_stop=32.3232 vs fill=22.4600 -> dist=0.4391 > gate=0.1500
    FULT 2002-03-07 installed_stop=23.3952 vs fill=19.5000 -> dist=0.1998 > gate=0.1500
    EOG 2000-05-01 installed_stop=21.9602 vs fill=25.8500 -> dist=0.1505 > gate=0.1500
V13 INVARIANT 29 violations (5 skipped)
    WRLD 2010-03-12 exit_price=41.9300 outside 2010-03-15 bar [41.9301, 44.1000]
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WLK 2012-08-06 entry_price=64.5400 outside 2012-08-06 bar [65.8500, 68.4000]
    VRTX 2001-03-12 exit_price=31.6400 outside 2001-03-15 bar [31.6406, 35.6250]
    PAYC 2021-08-09 exit_price=454.0800 outside 2021-08-10 bar [454.0850, 472.4900]
    OR 2021-05-17 exit_price=12.7400 outside 2021-07-19 bar [12.7420, 13.1850]
    NTTYY 2017-11-07 entry_price=50.4200 outside 2017-11-07 bar [50.4190, 50.4190]
    NPSNY 2009-08-28 entry_price=32.1200 outside 2009-08-28 bar [31.1960, 32.1180]
    MMSI 2011-03-14 entry_price=14.2800 outside 2011-03-14 bar [17.5400, 17.9500]
    LACO 2020-05-27 no bar on exit_date 2020-10-09 (nearest earlier bar: 2020-10-08)
V14 EXPECTATION 56 violations
    XRAY 2000-04-25 entry bar 2000-04-25 open=27.8750 low=27.8750 close=29.1876 vs stop=28.2787, exit=28.2500
    WRLD 2010-03-12 entry bar 2010-03-12 open=43.0000 low=42.5200 close=43.6500 vs stop=41.9694, exit=41.9300
    WBS 2011-01-18 entry bar 2011-01-18 open=21.6600 low=21.6600 close=22.6500 vs stop=21.8824, exit=21.8700
    VUZI 2026-05-29 entry bar 2026-05-29 open=4.5200 low=4.2200 close=4.6000 vs stop=4.1413, exit=4.1300
    VRNS 2022-01-27 entry bar 2022-01-27 open=34.2100 low=32.4900 close=32.7600 vs stop=30.9184, exit=32.1100
    VNA 2015-02-05 entry bar 2015-02-05 open=4500.0000 low=4300.0000 close=4300.0000 vs stop=4244.8500, exit=4244.7100
    UTL 2022-07-01 entry bar 2022-07-01 open=58.7100 low=58.0800 close=61.0000 vs stop=57.2358, exit=57.1900
    UBS 2014-11-26 entry bar 2014-11-26 open=17.5500 low=17.5200 close=23.2000 vs stop=21.8103, exit=18.0900
    TRMD 2024-01-24 entry bar 2024-01-24 open=36.5500 low=35.8800 close=35.9700 vs stop=35.3141, exit=35.2700
    TIE 2010-05-13 entry bar 2010-05-13 open=17.1200 low=16.9400 close=17.4100 vs stop=16.9832, exit=16.9800
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 12 violations
    BLNK 2020-07-29 median close 1.61 over 4088 bars (2008-07-15..2026-06-23); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0
    BOKF 2003-06-04 median close 49.76 over 8761 bars (1991-09-05..2026-06-23); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    CECO 2023-10-13 median close 4.62 over 11481 bars (1980-12-02..2026-06-23); bar 1992-09-29 close 2.66 (+399.96% vs prior close 0.53) on volume 0
    CEQP 2018-01-22 median close 25.49 over 5608 bars (2001-07-26..2023-11-16); bar 2023-11-14 close 0.00 (-100.00% vs prior close 28.26) on volume 0
    CIR 2013-04-24 median close 32.28 over 6046 bars (1999-10-18..2023-11-16); bar 2023-11-06 close 0.00 (-100.00% vs prior close 56.00) on volume 0
    FLO 2020-03-09 median close 18.17 over 11661 bars (1980-03-17..2026-06-23); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    IOVA 2020-03-24 median close 7.45 over 3944 bars (2010-10-15..2026-06-23); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0
    MVL 2002-03-08 median close 9.00 over 4795 bars (1999-01-04..2018-01-24); bar 2010-01-26 close 60.00 (+96.88% vs prior close 30.48) on volume 0
    NOKBF 2025-10-28 median close 5.97 over 4477 bars (2001-07-11..2026-06-23); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0
    TGTX 2018-03-05 median close 0.13 over 7416 bars (1995-12-14..2026-06-23); bar 2002-06-04 close 0.13 (+129900.00% vs prior close 0.00) on volume 0
