# Post-run validation report

Invariant checks failing: 2
audit join: 644/644 rows matched

QUALITY-FLAG: 1 fallback exits (V16)

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /w/trading/test_data/share_classes.sexp)
V7 INVARIANT 65 violations
    ZION 2005-11-18 Virgin_territory but only 0 weekly bars (< 520) before entry
    WEC 2014-10-30 Virgin_territory but only 304 weekly bars (< 520) before entry
    VVV 2024-02-08 Virgin_territory but only 385 weekly bars (< 520) before entry
    VRSK 2017-02-22 Virgin_territory but only 385 weekly bars (< 520) before entry
    VOYA 2017-11-29 Virgin_territory but only 239 weekly bars (< 520) before entry
    ULTA 2017-03-06 Virgin_territory but only 427 weekly bars (< 520) before entry
    UDR 2012-07-30 Virgin_territory but only 187 weekly bars (< 520) before entry
    TRW1 2000-03-27 Virgin_territory but only 117 weekly bars (< 520) before entry
    TRV 2016-06-30 Virgin_territory but only 391 weekly bars (< 520) before entry
    TMO 2015-07-22 Virgin_territory but only 342 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 88 violations (236 skipped)
    ZS 2020-10-29 prior_top=154.85 within +25% of entry=142.28
    ZD 2021-06-07 prior_top=111.23 within +25% of entry=110.55
    YETI 2021-07-06 prior_top=94.97 within +25% of entry=92.81
    X 2023-08-21 prior_top=37.63 within +25% of entry=31.79
    WOLF_old2 2021-11-22 prior_top=139.55 within +25% of entry=133.00
    VRTX 2012-06-07 prior_top=64.85 within +25% of entry=56.30
    VRTX 2014-07-30 prior_top=99.07 within +25% of entry=92.22
    VLO 2022-02-01 prior_top=90.84 within +25% of entry=85.41
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    THO 2021-02-16 prior_top=130.65 within +25% of entry=123.20
V10 EXPECTATION 3 violations (236 skipped)
    IREN 2025-07-15 entry_wk_close=17.94 > prior=10.47 (spike>60%)
    HOFF 2000-05-17 entry_wk_close=262.50 > prior=157.81 (spike>60%)
    GMGC 2000-01-24 entry_wk_close=103.69 > prior=54.25 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT PASS
V13 INVARIANT 100 violations (11 skipped)
    ZION 2005-11-18 no bar on entry_date 2005-11-18 (nearest earlier bar: none)
    WDC 2003-10-06 no bar on entry_date 2003-10-06 (nearest earlier bar: none)
    WDC 2007-11-20 no bar on entry_date 2007-11-20 (nearest earlier bar: none)
    TJX 2003-12-01 no bar on entry_date 2003-12-01 (nearest earlier bar: none)
    TFC 2006-09-25 no bar on entry_date 2006-09-25 (nearest earlier bar: none)
    STT 2000-04-10 no bar on entry_date 2000-04-10 (nearest earlier bar: none)
    SAP 2007-09-11 no bar on entry_date 2007-09-11 (nearest earlier bar: none)
    RF 2004-01-27 no bar on entry_date 2004-01-27 (nearest earlier bar: none)
    PPL 2007-09-12 no bar on entry_date 2007-09-12 (nearest earlier bar: none)
    PCAR 2006-05-30 no bar on entry_date 2006-05-30 (nearest earlier bar: none)
V14 EXPECTATION 15 violations (42 skipped)
    TER 2020-03-12 entry bar 2020-03-12 open=50.8000 low=49.6000 close=49.8300 vs stop=47.8942, exit=48.6800
    TECK 2022-04-25 entry bar 2022-04-25 open=36.0000 low=34.1400 close=35.8800 vs stop=35.1252, exit=35.0700
    STX 2018-02-05 entry bar 2018-02-05 open=51.2600 low=49.5100 close=49.6500 vs stop=49.3224, exit=48.0800
    RH 2025-02-11 entry bar 2025-02-11 open=399.7100 low=377.0400 close=384.4200 vs stop=366.8941, exit=366.5700
    OKLO 2025-06-18 entry bar 2025-06-18 open=63.2650 low=59.6200 close=62.0200 vs stop=58.1745, exit=58.1500
    MTCH 2019-09-10 entry bar 2019-09-10 open=267.0275 low=263.0702 close=264.5411 vs stop=261.7962, exit=261.7400
    GFI 2024-04-29 entry bar 2024-04-29 open=17.7600 low=17.6000 close=17.8900 vs stop=16.3743, exit=16.1600
    FSH 2005-11-15 entry bar 2005-11-15 open=65.0000 low=64.8200 close=65.5000 vs stop=58.4590, exit=64.1500
    DG 2012-12-11 entry bar 2012-12-11 open=45.6500 low=42.7700 close=42.9400 vs stop=41.4573, exit=42.2600
    DECK 2018-11-19 entry bar 2018-11-19 open=129.9402 low=123.0300 close=123.3798 vs stop=119.4512, exit=119.3900
V15 EXPECTATION PASS
V16 EXPECTATION 1 violations
    MAY 2005-03-02 stale_force_exit exit 2005-09-05 (entry 2005-03-02 @ 36.72, exit @ 39.75)
V17 EXPECTATION 2 violations (91 skipped)
    PBR 2026-02-09 entry filled 2026-02-09 but last bar is 2025-05-16 (269 days stale)
    NVS 2025-12-03 entry filled 2025-12-03 but last bar is 2025-05-16 (201 days stale)
V18 EXPECTATION 4 violations
    AUY 2011-08-08 median close 5.11 over 5183 bars (2001-06-22..2023-03-31); bar 2001-10-04 close 1.67 (+1571.60% vs prior close 0.10) on volume 0
    BRK-A 2017-08-03 median close 83025.10 over 11230 bars (1980-03-17..2026-06-15), above the 10000.00 ceiling
    ISA 2019-03-14 median close 7360.00 over 5664 bars (1997-12-31..2020-07-07); bar 2001-08-22 close 0.05 (-100.00% vs prior close 1070.00) on volume 0
    PPP 2005-06-13 median close 5.31 over 2978 bars (2003-09-10..2017-08-14); bar 2009-12-14 close 4.40 (-92.67% vs prior close 60.00) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 83 violations
    WY 2010-01-21 LONG installed_stop 15.8750 vs screener_proxy_stop 15.0696: 5.34% tighter > 3%
    WSM 2018-09-13 LONG installed_stop 64.3750 vs screener_proxy_stop 61.0144: 5.51% tighter > 3%
    WDC 2007-11-20 LONG installed_stop 23.9999 vs screener_proxy_stop 22.6504: 5.96% tighter > 3%
    VVUS 2008-06-18 LONG installed_stop 6.3750 vs screener_proxy_stop 6.0536: 5.31% tighter > 3%
    TSLA 2013-04-09 LONG installed_stop 38.3750 vs screener_proxy_stop 36.9840: 3.76% tighter > 3%
    TRN 2014-07-30 LONG installed_stop 33.7002 vs screener_proxy_stop 31.6572: 6.45% tighter > 3%
    TNDM 2020-07-24 LONG installed_stop 88.2528 vs screener_proxy_stop 85.4036: 3.34% tighter > 3%
    TER 2020-03-12 LONG installed_stop 47.8944 vs screener_proxy_stop 46.0736: 3.95% tighter > 3%
    TECK 2022-04-25 LONG installed_stop 35.1264 vs screener_proxy_stop 32.7060: 7.40% tighter > 3%
    TEAM 2018-10-19 LONG installed_stop 66.3648 vs screener_proxy_stop 63.5628: 4.41% tighter > 3%
V22 EXPECTATION 91 violations (128 skipped: position has no stop-decision rows)
    ABBV 2014-08-22 no stop move for 20 weeks (2014-09-09..2015-01-30), 1 completed cycle(s) stalled; last: stop 49.32, candidate 33.88, ma 34.45, correction extreme 52.06 (extreme/ma 1.51)
    ACN 2006-10-13 no stop move for 27 weeks (2006-10-30..2007-05-11), 3 completed cycle(s) stalled; last: stop 28.66, candidate 25.44, ma 25.69, correction extreme 34.28 (extreme/ma 1.33)
    ADSK 2003-09-12 no stop move for 49 weeks (2003-09-15..2004-08-25), 6 completed cycle(s) stalled; last: stop 16.66, candidate 16.39, ma 16.55, correction extreme 35.50 (extreme/ma 2.14)
    AMAT 2007-06-22 no stop move for 17 weeks (2007-06-25..2007-10-25), 1 completed cycle(s) stalled; last: stop 17.64, candidate 14.45, ma 14.60, correction extreme 19.60 (extreme/ma 1.34)
    ANET 2023-02-24 no stop move for 14 weeks (2023-03-06..2023-06-16), 1 completed cycle(s) stalled; last: stop 127.22, candidate 35.88, ma 36.48, correction extreme 131.68 (extreme/ma 3.61)
    APD 2013-12-27 no stop move for 14 weeks (2014-02-13..2014-05-23), 1 completed cycle(s) stalled; last: stop 98.14, candidate 75.33, ma 76.09, correction extreme 110.61 (extreme/ma 1.45)
    APH 2023-10-06 no stop move for 29 weeks (2023-11-29..2024-06-21), 3 completed cycle(s) stalled; last: stop 77.93, candidate 54.92, ma 55.47, correction extreme 118.40 (extreme/ma 2.13)
    ARCH 2005-02-11 no stop move for 23 weeks (2005-02-16..2005-07-28), 4 completed cycle(s) stalled; last: stop 16.88, candidate 16.88, ma 17.24, correction extreme 24.60 (extreme/ma 1.43)
    AUY 2011-08-05 no stop move for 15 weeks (2011-08-08..2011-11-25), 1 completed cycle(s) stalled; last: stop 12.18, candidate 10.89, ma 11.00, correction extreme 14.47 (extreme/ma 1.32)
    AVGO 2023-07-21 no stop move for 50 weeks (2023-08-11..2024-07-26), 6 completed cycle(s) stalled; last: stop 745.32, candidate 126.73, ma 128.01, correction extreme 1302.53 (extreme/ma 10.18)
V23 EXPECTATION 18 violations
    WTW 2019-02-01 filled 2019-02-01 after the 2019-01-25 screen read Bearish
    SYK 2019-01-30 filled 2019-01-30 after the 2019-01-25 screen read Bearish
    PM 2011-10-27 filled 2011-10-27 after the 2011-10-21 screen read Bearish
    NRG 2006-07-28 filled 2006-07-28 after the 2006-07-21 screen read Bearish
    NOK 2008-01-22 filled 2008-01-22 after the 2008-01-18 screen read Bearish
    MDLZ 2011-10-27 filled 2011-10-27 after the 2011-10-21 screen read Bearish
    LIN 2019-02-15 filled 2019-02-15 after the 2019-02-08 screen read Bearish
    HRB 2015-09-09 filled 2015-09-09 after the 2015-09-04 screen read Bearish
    HOFF 2000-05-17 filled 2000-05-17 after the 2000-05-12 screen read Bearish
    HAL 2022-06-17 filled 2022-06-17 after the 2022-06-10 screen read Bearish
