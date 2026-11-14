# Post-run validation report

Invariant checks failing: 2
audit join: 340/340 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /w/trading/test_data/share_classes.sexp)
V7 INVARIANT 15 violations
    XERS 2024-02-14 Virgin_territory but only 295 weekly bars (< 520) before entry
    WING 2017-08-08 Virgin_territory but only 113 weekly bars (< 520) before entry
    VRSK 2017-02-22 Virgin_territory but only 385 weekly bars (< 520) before entry
    VOYA 2017-11-29 Virgin_territory but only 239 weekly bars (< 520) before entry
    UHAL 2015-02-03 Virgin_territory but only 318 weekly bars (< 520) before entry
    TRNO 2017-04-11 Virgin_territory but only 374 weekly bars (< 520) before entry
    NGVT 2017-10-05 Virgin_territory but only 74 weekly bars (< 520) before entry
    MCHP 2015-02-13 Virgin_territory but only 319 weekly bars (< 520) before entry
    HURN 2013-03-27 Virgin_territory but only 441 weekly bars (< 520) before entry
    FN 2019-12-12 Virgin_territory but only 494 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 84 violations (59 skipped)
    XLRN 2018-07-23 prior_top=51.43 within +25% of entry=47.46
    XLRN 2020-04-20 prior_top=97.78 within +25% of entry=97.02
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.75
    WOLF_old2 2021-11-22 prior_top=139.55 within +25% of entry=133.00
    WIX 2021-03-03 prior_top=353.09 within +25% of entry=327.36
    WIFI 2018-11-02 prior_top=34.90 within +25% of entry=29.05
    VSAT 2013-04-12 prior_top=49.67 within +25% of entry=49.17
    VRTX 2014-07-30 prior_top=99.07 within +25% of entry=92.22
    VICR 2021-07-27 prior_top=107.97 within +25% of entry=107.30
    THO 2021-02-16 prior_top=130.65 within +25% of entry=123.20
V10 EXPECTATION 5 violations (59 skipped)
    SATL 2026-04-01 entry_wk_close=6.77 > prior=3.09 (spike>60%)
    PUMP 2025-11-12 entry_wk_close=9.92 > prior=5.54 (spike>60%)
    ISEE 2022-09-30 entry_wk_close=17.94 > prior=9.44 (spike>60%)
    INOD 2025-09-29 entry_wk_close=84.14 > prior=43.48 (spike>60%)
    APPS 2020-06-15 entry_wk_close=10.38 > prior=5.82 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT PASS
V13 INVARIANT 4 violations (3 skipped)
    QCOM 2026-05-18 no bar on entry_date 2026-05-18 (nearest earlier bar: 2026-04-10)
    OKE 2013-09-18 entry_price=46.1500 outside 2013-09-18 bar [51.8900, 54.5300]
    NEOG 2017-09-05 entry_price=52.4700 outside 2017-09-05 bar [68.8760, 70.4406]
    MAR 2025-12-15 no bar on exit_date 2026-05-18 (nearest earlier bar: 2026-04-10)
V14 EXPECTATION 13 violations (1 skipped)
    UPWK 2025-09-30 entry bar 2025-09-30 open=18.9800 low=18.2150 close=18.5700 vs stop=17.8706, exit=17.8300
    TDS 2023-09-11 entry bar 2023-09-11 open=17.8500 low=17.3700 close=17.6500 vs stop=17.1658, exit=17.0600
    SDA 2023-07-12 entry bar 2023-07-12 open=14.1500 low=11.5500 close=11.7000 vs stop=10.4919, exit=10.4400
    PUMP 2025-11-12 entry bar 2025-11-12 open=11.0100 low=10.1850 close=10.4300 vs stop=9.8372, exit=9.7100
    MLNX 2018-11-19 entry bar 2018-11-19 open=92.8500 low=91.1200 close=91.2800 vs stop=85.8773, exit=85.8500
    GATX 2014-10-09 entry bar 2014-10-09 open=56.7000 low=55.2723 close=55.4300 vs stop=52.8780, exit=54.6500
    FLNA 2020-10-12 entry bar 2020-10-12 open=11.8900 low=11.0700 close=11.4300 vs stop=10.8755, exit=10.8100
    EXTR 2022-01-21 entry bar 2022-01-21 open=12.8100 low=12.4900 close=12.4900 vs stop=12.1943, exit=12.0900
    CVNA 2025-12-31 entry bar 2025-12-31 open=429.5500 low=421.8550 close=422.0200 vs stop=406.8887, exit=406.7000
    CRON 2018-09-24 entry bar 2018-09-24 open=11.8000 low=11.6500 close=11.8600 vs stop=11.7871, exit=11.7100
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION 1 violations
    QCOM 2026-05-18 entry filled 2026-05-18 but last bar is 2026-04-10 (38 days stale)
V18 EXPECTATION 4 violations
    ANIP 2024-03-11 median close 26.24 over 6160 bars (2001-07-24..2026-06-24); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    EHC 2014-09-04 median close 23.25 over 10013 bars (1986-09-24..2026-06-24); bar 2006-10-26 close 23.75 (+400.00% vs prior close 4.75) on volume 0
    FIT 2018-06-18 median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0
    TNXP 2025-06-10 median close 0.16 over 3561 bars (2012-02-03..2026-06-24); bar 2012-05-10 close 0.00 (-99.99% vs prior close 1.50) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 43 violations
    WIFI 2018-11-02 LONG installed_stop 27.8750 vs screener_proxy_stop 26.2016: 6.39% tighter > 3%
    WD 2021-03-09 LONG installed_stop 91.2672 vs screener_proxy_stop 87.6852: 4.09% tighter > 3%
    VGR 2021-12-06 LONG installed_stop 10.3471 vs screener_proxy_stop 10.0280: 3.18% tighter > 3%
    UPWK 2025-09-30 LONG installed_stop 17.8750 vs screener_proxy_stop 16.7716: 6.58% tighter > 3%
    TDS 2023-09-11 LONG installed_stop 17.1648 vs screener_proxy_stop 16.0264: 7.10% tighter > 3%
    SSTK 2020-09-04 LONG installed_stop 44.4864 vs screener_proxy_stop 42.5132: 4.64% tighter > 3%
    SPSC 2019-02-28 LONG installed_stop 98.2368 vs screener_proxy_stop 93.0856: 5.53% tighter > 3%
    PYX 2018-10-22 LONG installed_stop 29.3750 vs screener_proxy_stop 28.3820: 3.50% tighter > 3%
    PKG 2023-08-21 LONG installed_stop 139.8912 vs screener_proxy_stop 135.2124: 3.46% tighter > 3%
    PEGA 2016-10-31 LONG installed_stop 28.8480 vs screener_proxy_stop 27.9496: 3.21% tighter > 3%
V22 EXPECTATION 44 violations (68 skipped: position has no stop-decision rows)
    ALSN 2013-09-27 no stop move for 32 weeks (2013-09-30..2014-05-16), 2 completed cycle(s) stalled; last: stop 23.34, candidate 20.81, ma 21.02, correction extreme 25.71 (extreme/ma 1.22)
    AN 2020-07-31 no stop move for 16 weeks (2020-08-04..2020-11-24), 2 completed cycle(s) stalled; last: stop 48.84, candidate 48.78, ma 49.27, correction extreme 50.52 (extreme/ma 1.03)
    ATNI 2013-02-01 no stop move for 24 weeks (2013-02-22..2013-08-09), 2 completed cycle(s) stalled; last: stop 39.93, candidate 32.84, ma 33.17, correction extreme 46.55 (extreme/ma 1.40)
    AVGO 2013-08-30 no stop move for 99 weeks (2013-09-10..2015-08-10), 11 completed cycle(s) stalled; last: stop 34.32, candidate 9.14, ma 9.23, correction extreme 114.56 (extreme/ma 12.41)
    BBWI 2020-07-31 no stop move for 31 weeks (2020-08-05..2021-03-12), 7 completed cycle(s) stalled; last: stop 22.92, candidate 20.38, ma 20.76, correction extreme 36.10 (extreme/ma 1.74)
    BC 2013-08-16 no stop move for 22 weeks (2013-08-22..2014-01-24), 2 completed cycle(s) stalled; last: stop 34.73, candidate 29.88, ma 30.36, correction extreme 39.03 (extreme/ma 1.29)
    CLX 2020-03-13 no stop move for 16 weeks (2020-03-16..2020-07-10), 1 completed cycle(s) stalled; last: stop 150.41, candidate 137.88, ma 139.40, correction extreme 161.11 (extreme/ma 1.16)
    CVNA 2024-07-05 no stop move for 33 weeks (2024-07-08..2025-02-28), 4 completed cycle(s) stalled; last: stop 116.17, candidate 25.38, ma 25.76, correction extreme 124.39 (extreme/ma 4.83)
    DECK 2014-07-18 no stop move for 13 weeks (2014-07-25..2014-10-27), 1 completed cycle(s) stalled; last: stop 77.22, candidate 14.25, ma 14.39, correction extreme 87.35 (extreme/ma 6.07)
    DKS 2019-10-04 no stop move for 14 weeks (2019-11-07..2020-02-14), 1 completed cycle(s) stalled; last: stop 36.34, candidate 31.73, ma 32.06, correction extreme 38.81 (extreme/ma 1.21)
V23 EXPECTATION 5 violations
    SYK 2019-01-30 filled 2019-01-30 after the 2019-01-25 screen read Bearish
    SPNT 2025-04-14 filled 2025-04-14 after the 2025-04-11 screen read Bearish
    OFIX 2019-02-12 filled 2019-02-12 after the 2019-02-08 screen read Bearish
    LIN 2019-02-15 filled 2019-02-15 after the 2019-02-08 screen read Bearish
    ISEE 2022-09-30 filled 2022-09-30 after the 2022-09-23 screen read Bearish
