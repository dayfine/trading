# Post-run validation report

Invariant checks failing: 2
audit join: 664/664 rows matched

QUALITY-FLAG: 1 fallback exits (V16)

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /w/trading/test_data/share_classes.sexp)
V7 INVARIANT 60 violations
    VVV 2024-02-08 Virgin_territory but only 385 weekly bars (< 520) before entry
    VRSK 2017-02-22 Virgin_territory but only 385 weekly bars (< 520) before entry
    VOYA 2017-11-29 Virgin_territory but only 239 weekly bars (< 520) before entry
    ULTA 2017-03-06 Virgin_territory but only 427 weekly bars (< 520) before entry
    TRW1 2000-03-27 Virgin_territory but only 117 weekly bars (< 520) before entry
    TRV 2016-06-30 Virgin_territory but only 391 weekly bars (< 520) before entry
    TFC 2006-09-25 Virgin_territory but only 0 weekly bars (< 520) before entry
    SPGI 2016-05-24 Virgin_territory but only 386 weekly bars (< 520) before entry
    SO 2010-07-20 Virgin_territory but only 81 weekly bars (< 520) before entry
    SJM 2013-07-11 Virgin_territory but only 236 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 83 violations (246 skipped)
    ZD 2021-06-07 prior_top=111.23 within +25% of entry=110.55
    X 2023-08-21 prior_top=37.63 within +25% of entry=31.79
    WPM 2022-03-24 prior_top=50.74 within +25% of entry=49.40
    WOLF_old2 2021-11-22 prior_top=139.55 within +25% of entry=133.00
    WIX 2021-04-28 prior_top=353.09 within +25% of entry=321.01
    WCRX 2013-07-08 prior_top=19.95 within +25% of entry=19.90
    VRTX 2012-06-07 prior_top=64.85 within +25% of entry=56.30
    USB 2024-08-28 prior_top=52.11 within +25% of entry=46.10
    URBN 2026-01-06 prior_top=81.84 within +25% of entry=81.27
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
V10 EXPECTATION 3 violations (246 skipped)
    IREN 2025-07-15 entry_wk_close=17.94 > prior=10.47 (spike>60%)
    HOFF 2000-05-17 entry_wk_close=262.50 > prior=157.81 (spike>60%)
    GMGC 2000-01-24 entry_wk_close=103.69 > prior=54.25 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT PASS
V13 INVARIANT 106 violations (14 skipped)
    WSM 2001-12-17 no bar on entry_date 2001-12-17 (nearest earlier bar: none)
    WDC 2003-10-06 no bar on entry_date 2003-10-06 (nearest earlier bar: none)
    WCN 2004-04-14 entry_price=26.0200 outside 2004-04-14 bar [38.8403, 39.5199]
    VTR 2011-04-28 entry_price=43.6000 outside 2011-04-28 bar [56.3200, 57.0800]
    UHS 2007-04-27 no bar on entry_date 2007-04-27 (nearest earlier bar: none)
    TFC 2006-09-25 no bar on entry_date 2006-09-25 (nearest earlier bar: none)
    SWK 2006-01-10 no bar on entry_date 2006-01-10 (nearest earlier bar: none)
    STT 2000-04-10 no bar on entry_date 2000-04-10 (nearest earlier bar: none)
    RTX 2007-09-04 no bar on entry_date 2007-09-04 (nearest earlier bar: none)
    PPG 2006-09-28 no bar on entry_date 2006-09-28 (nearest earlier bar: none)
V14 EXPECTATION 15 violations (47 skipped)
    TER 2020-03-12 entry bar 2020-03-12 open=50.8000 low=49.6000 close=49.8300 vs stop=47.8942, exit=48.6800
    SSYS 2003-09-10 entry bar 2003-09-10 open=44.4800 low=41.3600 close=42.3400 vs stop=40.8665, exit=40.7700
    OKLO 2025-06-18 entry bar 2025-06-18 open=63.2650 low=59.6200 close=62.0200 vs stop=58.1745, exit=58.1500
    MTN 2021-03-22 entry bar 2021-03-22 open=312.4200 low=307.2500 close=313.4900 vs stop=293.9679, exit=293.8000
    MTCH 2019-09-10 entry bar 2019-09-10 open=267.0275 low=263.0702 close=264.5411 vs stop=261.7962, exit=261.7400
    MLM 2017-02-23 entry bar 2017-02-23 open=219.7000 low=206.3400 close=208.6800 vs stop=206.8227, exit=206.7400
    GFI 2024-04-29 entry bar 2024-04-29 open=17.7600 low=17.6000 close=17.8900 vs stop=16.3743, exit=16.1600
    DGX 2020-03-09 entry bar 2020-03-09 open=109.0400 low=107.3100 close=109.8400 vs stop=104.3764, exit=104.3100
    DG 2012-12-11 entry bar 2012-12-11 open=45.6500 low=42.7700 close=42.9400 vs stop=41.4574, exit=42.2600
    DECK 2018-11-19 entry bar 2018-11-19 open=129.9402 low=123.0300 close=123.3798 vs stop=119.4512, exit=119.3900
V15 EXPECTATION PASS
V16 EXPECTATION 1 violations
    MAY 2005-03-02 stale_force_exit exit 2005-09-05 (entry 2005-03-02 @ 36.72, exit @ 39.75)
V17 EXPECTATION 2 violations (93 skipped)
    PBR 2026-02-09 entry filled 2026-02-09 but last bar is 2025-05-16 (269 days stale)
    NVS 2025-12-03 entry filled 2025-12-03 but last bar is 2025-05-16 (201 days stale)
V18 EXPECTATION 4 violations
    AUY 2011-08-08 median close 5.11 over 5183 bars (2001-06-22..2023-03-31); bar 2001-10-04 close 1.67 (+1571.60% vs prior close 0.10) on volume 0
    BRK-A 2017-08-03 median close 83025.10 over 11230 bars (1980-03-17..2026-06-15), above the 10000.00 ceiling
    ISA 2019-03-14 median close 7360.00 over 5664 bars (1997-12-31..2020-07-07); bar 2001-08-22 close 0.05 (-100.00% vs prior close 1070.00) on volume 0
    PPP 2005-06-13 median close 5.31 over 2978 bars (2003-09-10..2017-08-14); bar 2009-12-14 close 4.40 (-92.67% vs prior close 60.00) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 78 violations
    WY 2010-01-21 LONG installed_stop 15.8750 vs screener_proxy_stop 15.0696: 5.34% tighter > 3%
    VVUS 2008-06-18 LONG installed_stop 6.3750 vs screener_proxy_stop 6.0536: 5.31% tighter > 3%
    VFC 2011-06-08 LONG installed_stop 88.3750 vs screener_proxy_stop 82.9748: 6.51% tighter > 3%
    TNDM 2020-07-24 LONG installed_stop 88.2528 vs screener_proxy_stop 85.4036: 3.34% tighter > 3%
    TER 2020-03-12 LONG installed_stop 47.8944 vs screener_proxy_stop 46.0736: 3.95% tighter > 3%
    SYY 2013-12-16 LONG installed_stop 34.4928 vs screener_proxy_stop 33.3316: 3.48% tighter > 3%
    SWKS 2014-05-20 LONG installed_stop 38.4768 vs screener_proxy_stop 36.3768: 5.77% tighter > 3%
    SUNE_old 2005-06-27 LONG installed_stop 14.3750 vs screener_proxy_stop 13.8184: 4.03% tighter > 3%
    STX 2012-05-18 LONG installed_stop 26.7360 vs screener_proxy_stop 25.6864: 4.09% tighter > 3%
    STX 2019-09-23 LONG installed_stop 49.3750 vs screener_proxy_stop 47.4168: 4.13% tighter > 3%
V22 EXPECTATION 90 violations (141 skipped: position has no stop-decision rows)
    ABBV 2014-08-22 no stop move for 20 weeks (2014-09-09..2015-01-30), 1 completed cycle(s) stalled; last: stop 49.32, candidate 33.88, ma 34.45, correction extreme 52.06 (extreme/ma 1.51)
    ACN 2006-10-13 no stop move for 27 weeks (2006-10-30..2007-05-11), 3 completed cycle(s) stalled; last: stop 28.66, candidate 25.44, ma 25.69, correction extreme 34.28 (extreme/ma 1.33)
    ADSK 2003-09-12 no stop move for 49 weeks (2003-09-15..2004-08-25), 6 completed cycle(s) stalled; last: stop 16.66, candidate 16.39, ma 16.55, correction extreme 35.50 (extreme/ma 2.14)
    ANET 2023-03-03 no stop move for 14 weeks (2023-03-06..2023-06-16), 1 completed cycle(s) stalled; last: stop 127.22, candidate 35.88, ma 36.48, correction extreme 131.68 (extreme/ma 3.61)
    APH 2023-10-06 no stop move for 29 weeks (2023-11-29..2024-06-21), 3 completed cycle(s) stalled; last: stop 77.93, candidate 54.92, ma 55.47, correction extreme 118.40 (extreme/ma 2.13)
    ARCH 2005-02-11 no stop move for 23 weeks (2005-02-16..2005-07-28), 4 completed cycle(s) stalled; last: stop 16.88, candidate 16.88, ma 17.24, correction extreme 24.60 (extreme/ma 1.43)
    ATI 2007-03-09 no stop move for 14 weeks (2007-03-13..2007-06-22), 1 completed cycle(s) stalled; last: stop 90.38, candidate 78.19, ma 78.98, correction extreme 98.22 (extreme/ma 1.24)
    AUY 2011-08-05 no stop move for 15 weeks (2011-08-08..2011-11-25), 1 completed cycle(s) stalled; last: stop 12.18, candidate 10.89, ma 11.00, correction extreme 14.47 (extreme/ma 1.32)
    AVGO 2013-08-30 no stop move for 99 weeks (2013-09-10..2015-08-10), 11 completed cycle(s) stalled; last: stop 34.32, candidate 9.14, ma 9.23, correction extreme 114.56 (extreme/ma 12.41)
    B 2002-03-01 no stop move for 14 weeks (2002-04-02..2002-07-15), 1 completed cycle(s) stalled; last: stop 33.38, candidate 8.38, ma 8.65, correction extreme 34.36 (extreme/ma 3.97)
V23 EXPECTATION 17 violations
    SYK 2019-01-30 filled 2019-01-30 after the 2019-01-25 screen read Bearish
    RTN 2007-08-20 filled 2007-08-20 after the 2007-08-17 screen read Bearish
    PM 2011-10-27 filled 2011-10-27 after the 2011-10-21 screen read Bearish
    NRG 2006-07-28 filled 2006-07-28 after the 2006-07-21 screen read Bearish
    NOK 2008-01-22 filled 2008-01-22 after the 2008-01-18 screen read Bearish
    MTB 2022-02-24 filled 2022-02-24 after the 2022-02-18 screen read Bearish
    LLY 2018-12-17 filled 2018-12-17 after the 2018-12-14 screen read Bearish
    LIN 2019-02-15 filled 2019-02-15 after the 2019-02-08 screen read Bearish
    HRB 2015-09-09 filled 2015-09-09 after the 2015-09-04 screen read Bearish
    HOFF 2000-05-17 filled 2000-05-17 after the 2000-05-12 screen read Bearish
