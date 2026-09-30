# Post-run validation report

Invariant checks failing: 3
audit join: 720/720 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 109 violations
    XPOF 2023-01-27 Virgin_territory but only 79 weekly bars (< 520) before entry
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    WLK 2012-08-06 Virgin_territory but only 419 weekly bars (< 520) before entry
    VRSK 2017-02-22 Virgin_territory but only 388 weekly bars (< 520) before entry
    VOYA 2017-11-29 Virgin_territory but only 241 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    VICI 2019-10-16 Virgin_territory but only 105 weekly bars (< 520) before entry
    VC 2015-05-22 Virgin_territory but only 245 weekly bars (< 520) before entry
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
    UNVR 2022-03-15 Virgin_territory but only 354 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 79 violations (239 skipped)
    ZGN 2023-09-08 prior_top=15.43 within +25% of entry=14.25
    XLRN 2018-07-23 prior_top=51.43 within +25% of entry=47.49
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.85
    WTFC 2010-04-06 prior_top=46.07 within +25% of entry=39.46
    WRLD 2010-03-12 prior_top=49.25 within +25% of entry=43.73
    WIX 2021-04-28 prior_top=353.09 within +25% of entry=320.97
    VRNS 2021-07-21 prior_top=71.50 within +25% of entry=60.99
    UNVR 2022-03-15 prior_top=32.43 within +25% of entry=32.23
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TTWO 2020-05-19 prior_top=137.99 within +25% of entry=136.41
V10 EXPECTATION 13 violations (239 skipped)
    VUZI 2026-05-29 entry_wk_close=4.60 > prior=2.84 (spike>60%)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    PYX 2018-10-08 entry_wk_close=43.05 > prior=18.60 (spike>60%)
    MVL 2002-03-08 entry_wk_close=5.33 > prior=3.00 (spike>60%)
    ISEE 2022-09-30 entry_wk_close=17.94 > prior=9.44 (spike>60%)
    HIMX 2026-05-08 entry_wk_close=17.48 > prior=9.05 (spike>60%)
    GRPN 2025-03-26 entry_wk_close=18.82 > prior=11.12 (spike>60%)
    EXK 2020-07-20 entry_wk_close=4.20 > prior=2.14 (spike>60%)
    EOSE 2023-06-27 entry_wk_close=4.34 > prior=2.43 (spike>60%)
    CLPA 2000-01-31 entry_wk_close=25.25 > prior=12.12 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 17 violations
    YMM 2024-11-20 installed_stop=8.2848 vs fill=9.7600 -> dist=0.1511 > gate=0.1500
    WKC 2004-12-20 installed_stop=44.3750 vs fill=23.6000 -> dist=0.8803 > gate=0.1500
    VOYA 2017-11-29 installed_stop=36.7008 vs fill=43.5100 -> dist=0.1565 > gate=0.1500
    NJDCY 2015-06-08 installed_stop=15.2160 vs fill=17.9500 -> dist=0.1523 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.5300 -> dist=0.1589 > gate=0.1500
    MGM 2001-09-18 installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500
    MCK 2020-05-28 installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500
    LZB 2024-07-15 installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500
    LPG 2023-09-15 installed_stop=23.2022 vs fill=27.3000 -> dist=0.1501 > gate=0.1500
    GRA 2016-01-22 installed_stop=73.1724 vs fill=86.3000 -> dist=0.1521 > gate=0.1500
V13 INVARIANT 30 violations (4 skipped)
    WRLD 2010-03-12 exit_price=41.9300 outside 2010-03-15 bar [41.9301, 44.1000]
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WLK 2012-08-06 entry_price=64.6000 outside 2012-08-06 bar [65.8500, 68.4000]
    VRTX 2001-03-12 exit_price=31.6400 outside 2001-03-15 bar [31.6406, 35.6250]
    VICI 2019-10-16 entry_price=23.4200 outside 2019-10-16 bar [23.0400, 23.4190]
    SAFM 2022-05-31 no bar on exit_date 2022-07-25 (nearest earlier bar: 2022-07-22)
    PAYC 2021-08-09 exit_price=454.0800 outside 2021-08-10 bar [454.0850, 472.4900]
    NPSNY 2009-08-28 entry_price=32.1200 outside 2009-08-28 bar [31.1960, 32.1180]
    NEOG 2017-09-05 entry_price=52.5300 outside 2017-09-05 bar [68.8760, 70.4406]
    MMSI 2011-03-14 entry_price=14.3300 outside 2011-03-14 bar [17.5400, 17.9500]
V14 EXPECTATION 58 violations
    XRAY 2000-04-25 entry bar 2000-04-25 open=27.8750 low=27.8750 close=29.1876 vs stop=28.2853, exit=28.2500
    WRLD 2010-03-12 entry bar 2010-03-12 open=43.0000 low=42.5200 close=43.6500 vs stop=41.9721, exit=41.9300
    VUZI 2026-05-29 entry bar 2026-05-29 open=4.5200 low=4.2200 close=4.6000 vs stop=4.1413, exit=4.0400
    UTL 2022-07-01 entry bar 2022-07-01 open=58.7100 low=58.0800 close=61.0000 vs stop=57.2355, exit=57.2300
    UBS 2014-11-26 entry bar 2014-11-26 open=17.5500 low=17.5200 close=23.2000 vs stop=21.8068, exit=18.0900
    TRMD 2024-01-24 entry bar 2024-01-24 open=36.5500 low=35.8800 close=35.9700 vs stop=35.3118, exit=35.2700
    TRC 2026-03-17 entry bar 2026-03-17 open=18.8600 low=18.7200 close=18.9700 vs stop=18.7070, exit=18.6600
    TIE 2010-05-13 entry bar 2010-05-13 open=17.1200 low=16.9400 close=17.4100 vs stop=16.9831, exit=16.8400
    TGTX 2018-03-05 entry bar 2018-03-05 open=14.8500 low=14.8500 close=15.2000 vs stop=14.8161, exit=14.7800
    TCBI 2006-04-19 entry bar 2006-04-19 open=24.4700 low=24.0700 close=24.9100 vs stop=23.8081, exit=23.2500
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 16 violations
    ATLKY 2026-01-15 median close 24.88 over 7441 bars (1996-11-18..2026-06-16); bar 2003-09-01 close 1000000.00 (+3311246.00% vs prior close 30.20) on volume 0
    BLFS 2021-07-08 median close 1.73 over 9207 bars (1989-11-22..2026-06-16); bar 2014-01-29 close 8.12 (+1300.00% vs prior close 0.58) on volume 0
    BLNK 2020-07-29 median close 1.61 over 4084 bars (2008-07-15..2026-06-16); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0
    BOKF 2003-06-04 median close 49.75 over 8757 bars (1991-09-05..2026-06-16); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    CECO 2023-10-13 median close 4.61 over 11477 bars (1980-12-02..2026-06-16); bar 1992-09-29 close 2.66 (+399.96% vs prior close 0.53) on volume 0
    CIR 2013-04-24 median close 32.28 over 6046 bars (1999-10-18..2023-11-16); bar 2023-11-06 close 0.00 (-100.00% vs prior close 56.00) on volume 0
    DUOT 2026-06-15 median close 2.72 over 3139 bars (2008-08-13..2026-06-16); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0
    FIT 2020-12-03 median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0
    FLO 2020-03-09 median close 18.18 over 11657 bars (1980-03-17..2026-06-16); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    IOVA 2020-03-24 median close 7.46 over 3940 bars (2010-10-15..2026-06-16); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0
