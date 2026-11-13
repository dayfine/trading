# Post-run validation report

Invariant checks failing: 2
audit join: 552/552 rows matched

QUALITY-FLAG: 1 fallback exits (V16)

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /w/trading/test_data/share_classes.sexp)
V7 INVARIANT 32 violations
    XERS 2024-02-14 Virgin_territory but only 295 weekly bars (< 520) before entry
    WRB 2018-04-20 Virgin_territory but only 485 weekly bars (< 520) before entry
    WING 2017-08-08 Virgin_territory but only 113 weekly bars (< 520) before entry
    VRSK 2017-02-22 Virgin_territory but only 385 weekly bars (< 520) before entry
    UHAL 2015-02-03 Virgin_territory but only 318 weekly bars (< 520) before entry
    TRW1 2000-03-27 Virgin_territory but only 117 weekly bars (< 520) before entry
    TRNO 2017-04-11 Virgin_territory but only 374 weekly bars (< 520) before entry
    TDY 2017-07-25 Virgin_territory but only 447 weekly bars (< 520) before entry
    SO 2010-07-20 Virgin_territory but only 81 weekly bars (< 520) before entry
    PBF 2015-03-25 Virgin_territory but only 119 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 113 violations (172 skipped)
    XLRN 2018-07-23 prior_top=51.43 within +25% of entry=47.46
    XLRN 2020-04-20 prior_top=97.78 within +25% of entry=97.02
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.75
    WOLF_old2 2021-11-22 prior_top=139.55 within +25% of entry=133.00
    WIX 2021-03-03 prior_top=353.09 within +25% of entry=327.36
    WITS 2005-10-20 prior_top=20.89 within +25% of entry=20.10
    WIFI 2018-11-02 prior_top=34.90 within +25% of entry=29.05
    VRTX 2012-06-07 prior_top=64.85 within +25% of entry=56.30
    VRTX 2014-07-30 prior_top=99.07 within +25% of entry=92.22
    VOLC 2011-06-13 prior_top=30.65 within +25% of entry=29.26
V10 EXPECTATION 5 violations (172 skipped)
    SATL 2026-04-01 entry_wk_close=6.77 > prior=3.09 (spike>60%)
    PUMP 2025-11-12 entry_wk_close=9.92 > prior=5.54 (spike>60%)
    ISEE 2022-09-30 entry_wk_close=17.94 > prior=9.44 (spike>60%)
    INOD 2025-09-29 entry_wk_close=84.14 > prior=43.48 (spike>60%)
    APPS 2020-06-15 entry_wk_close=10.38 > prior=5.82 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT PASS
V13 INVARIANT 39 violations (4 skipped)
    ZION 2004-10-21 no bar on entry_date 2004-10-21 (nearest earlier bar: none)
    WRB 2000-08-28 no bar on entry_date 2000-08-28 (nearest earlier bar: none)
    WDC 2003-10-06 no bar on entry_date 2003-10-06 (nearest earlier bar: none)
    WAB 2003-08-18 no bar on entry_date 2003-08-18 (nearest earlier bar: none)
    TYL 2007-09-11 no bar on entry_date 2007-09-11 (nearest earlier bar: none)
    TRMB 2003-11-24 no bar on entry_date 2003-11-24 (nearest earlier bar: none)
    STT 2000-04-10 no bar on entry_date 2000-04-10 (nearest earlier bar: none)
    SNA 2004-03-08 no bar on entry_date 2004-03-08 (nearest earlier bar: none)
    RYAAY 2003-10-27 no bar on entry_date 2003-10-27 (nearest earlier bar: none)
    QCOM 2026-05-18 no bar on entry_date 2026-05-18 (nearest earlier bar: 2026-04-10)
V14 EXPECTATION 18 violations (11 skipped)
    VCYT 2020-07-27 entry bar 2020-07-27 open=30.3700 low=29.3700 close=30.2400 vs stop=28.6744, exit=28.6200
    UPWK 2025-09-30 entry bar 2025-09-30 open=18.9800 low=18.2150 close=18.5700 vs stop=17.8706, exit=17.8300
    TDS 2023-09-11 entry bar 2023-09-11 open=17.8500 low=17.3700 close=17.6500 vs stop=17.1658, exit=17.0600
    SDA 2023-07-12 entry bar 2023-07-12 open=14.1500 low=11.5500 close=11.7000 vs stop=10.4919, exit=10.4400
    RH 2025-02-11 entry bar 2025-02-11 open=399.7100 low=377.0400 close=384.4200 vs stop=366.8941, exit=366.5700
    PUMP 2025-11-12 entry bar 2025-11-12 open=11.0100 low=10.1850 close=10.4300 vs stop=9.8372, exit=9.7100
    MLNX 2018-11-19 entry bar 2018-11-19 open=92.8500 low=91.1200 close=91.2800 vs stop=85.8773, exit=85.8500
    GATX 2014-10-09 entry bar 2014-10-09 open=56.7000 low=55.2723 close=55.4300 vs stop=52.8780, exit=54.6500
    FSH 2005-11-15 entry bar 2005-11-15 open=65.0000 low=64.8200 close=65.5000 vs stop=58.4590, exit=64.1500
    FLNA 2020-10-12 entry bar 2020-10-12 open=11.8900 low=11.0700 close=11.4300 vs stop=10.8755, exit=10.8100
V15 EXPECTATION PASS
V16 EXPECTATION 1 violations
    NLC 2011-08-11 stale_force_exit exit 2011-12-06 (entry 2011-08-11 @ 32.79, exit @ 38.80)
V17 EXPECTATION 1 violations (30 skipped)
    QCOM 2026-05-18 entry filled 2026-05-18 but last bar is 2026-04-10 (38 days stale)
V18 EXPECTATION 10 violations
    ANIP 2024-03-11 median close 26.24 over 6160 bars (2001-07-24..2026-06-24); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    AUY 2011-08-08 median close 5.11 over 5183 bars (2001-06-22..2023-03-31); bar 2001-10-04 close 1.67 (+1571.60% vs prior close 0.10) on volume 0
    DRX 2007-06-14 median close 8.92 over 4248 bars (2000-01-04..2018-02-22); bar 2014-10-27 close 0.01 (-99.92% vs prior close 12.71) on volume 0
    EHC 2014-09-04 median close 23.25 over 10013 bars (1986-09-24..2026-06-24); bar 2006-10-26 close 23.75 (+400.00% vs prior close 4.75) on volume 0
    FIT 2019-11-26 median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0
    FLO 2021-06-03 median close 18.16 over 11662 bars (1980-03-17..2026-06-24); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    IHG 2012-06-19 median close 37.44 over 5839 bars (2003-04-08..2026-06-24); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0
    NLC 2011-08-11 median close 18.62 over 2816 bars (2004-11-11..2018-01-30); bar 2015-04-15 close 15.54 (+8533.33% vs prior close 0.18) on volume 0
    PPP 2005-06-13 median close 5.31 over 2978 bars (2003-09-10..2017-08-14); bar 2009-12-14 close 4.40 (-92.67% vs prior close 60.00) on volume 0
    TNXP 2025-06-10 median close 0.16 over 3561 bars (2012-02-03..2026-06-24); bar 2012-05-10 close 0.00 (-99.99% vs prior close 1.50) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 68 violations
    WIFI 2018-11-02 LONG installed_stop 27.8750 vs screener_proxy_stop 26.2016: 6.39% tighter > 3%
    VMC 2016-11-28 LONG installed_stop 121.2960 vs screener_proxy_stop 117.6128: 3.13% tighter > 3%
    VGR 2021-12-06 LONG installed_stop 10.3471 vs screener_proxy_stop 10.0280: 3.18% tighter > 3%
    UPWK 2025-09-30 LONG installed_stop 17.8750 vs screener_proxy_stop 16.7716: 6.58% tighter > 3%
    TROX 2014-09-19 LONG installed_stop 25.8048 vs screener_proxy_stop 24.9872: 3.27% tighter > 3%
    TGB 2010-10-19 LONG installed_stop 6.1632 vs screener_proxy_stop 5.7408: 7.36% tighter > 3%
    TDS 2023-09-11 LONG installed_stop 17.1648 vs screener_proxy_stop 16.0264: 7.10% tighter > 3%
    TCPC 2021-12-20 LONG installed_stop 12.3072 vs screener_proxy_stop 11.7852: 4.43% tighter > 3%
    TCOM 2024-10-15 LONG installed_stop 57.4704 vs screener_proxy_stop 53.6268: 7.17% tighter > 3%
    SSTK 2020-09-04 LONG installed_stop 44.4864 vs screener_proxy_stop 42.5132: 4.64% tighter > 3%
V22 EXPECTATION 102 violations (115 skipped: position has no stop-decision rows)
    ACN 2006-10-13 no stop move for 27 weeks (2006-10-30..2007-05-11), 3 completed cycle(s) stalled; last: stop 28.66, candidate 25.44, ma 25.69, correction extreme 34.28 (extreme/ma 1.33)
    ADNT 2020-02-21 no stop move for 31 weeks (2020-11-09..2021-06-18), 1 completed cycle(s) stalled; last: stop 25.38, candidate 20.66, ma 20.86, correction extreme 26.23 (extreme/ma 1.26)
    ADSK 2003-09-12 no stop move for 49 weeks (2003-09-15..2004-08-25), 6 completed cycle(s) stalled; last: stop 16.66, candidate 16.39, ma 16.55, correction extreme 35.50 (extreme/ma 2.14)
    AIN 2005-02-04 no stop move for 23 weeks (2005-07-12..2005-12-23), 2 completed cycle(s) stalled; last: stop 29.71, candidate 23.88, ma 24.31, correction extreme 34.60 (extreme/ma 1.42)
    ALJ 2012-08-10 no stop move for 18 weeks (2012-08-14..2012-12-21), 3 completed cycle(s) stalled; last: stop 10.67, candidate 9.88, ma 10.16, correction extreme 12.06 (extreme/ma 1.19)
    ALSK 2006-03-10 no stop move for 49 weeks (2006-03-21..2007-03-02), 6 completed cycle(s) stalled; last: stop 10.37, candidate 8.72, ma 8.81, correction extreme 15.15 (extreme/ma 1.72)
    ALSN 2013-09-27 no stop move for 32 weeks (2013-09-30..2014-05-16), 2 completed cycle(s) stalled; last: stop 23.34, candidate 20.81, ma 21.02, correction extreme 25.71 (extreme/ma 1.22)
    AN 2020-07-31 no stop move for 16 weeks (2020-08-04..2020-11-24), 2 completed cycle(s) stalled; last: stop 48.84, candidate 48.78, ma 49.27, correction extreme 50.52 (extreme/ma 1.03)
    ARCH 2005-02-11 no stop move for 23 weeks (2005-02-16..2005-07-28), 4 completed cycle(s) stalled; last: stop 16.88, candidate 16.88, ma 17.24, correction extreme 24.60 (extreme/ma 1.43)
    ARLP 2024-05-10 no stop move for 13 weeks (2024-05-31..2024-08-30), 1 completed cycle(s) stalled; last: stop 20.97, candidate 17.73, ma 17.91, correction extreme 23.17 (extreme/ma 1.29)
V23 EXPECTATION 16 violations
    TCR 2000-12-18 filled 2000-12-18 after the 2000-12-15 screen read Bearish
    SYK 2019-01-30 filled 2019-01-30 after the 2019-01-25 screen read Bearish
    SPNT 2025-04-14 filled 2025-04-14 after the 2025-04-11 screen read Bearish
    SGEN 2011-10-27 filled 2011-10-27 after the 2011-10-21 screen read Bearish
    PPDI 2011-10-03 filled 2011-10-03 after the 2011-09-30 screen read Bearish
    PAET 2011-10-04 filled 2011-10-04 after the 2011-09-30 screen read Bearish
    OFIX 2019-02-12 filled 2019-02-12 after the 2019-02-08 screen read Bearish
    NRG 2006-07-28 filled 2006-07-28 after the 2006-07-21 screen read Bearish
    NMK1 2000-11-15 filled 2000-11-15 after the 2000-11-10 screen read Bearish
    NJR 2006-07-24 filled 2006-07-24 after the 2006-07-21 screen read Bearish
