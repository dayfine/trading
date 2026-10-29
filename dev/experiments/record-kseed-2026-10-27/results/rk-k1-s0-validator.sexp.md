# Post-run validation report

Invariant checks failing: 3
audit join: 555/555 rows matched

QUALITY-FLAG: 2 fallback exits (V16)

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-rk/trading/test_data/share_classes.sexp)
V7 INVARIANT 20 violations
    XERS 2024-02-14 Virgin_territory but only 295 weekly bars (< 520) before entry
    WING 2017-08-08 Virgin_territory but only 113 weekly bars (< 520) before entry
    WDR 2007-07-13 Virgin_territory but only 488 weekly bars (< 520) before entry
    VRSK 2017-02-22 Virgin_territory but only 385 weekly bars (< 520) before entry
    TRW1 2000-03-27 Virgin_territory but only 117 weekly bars (< 520) before entry
    POM_old 2006-07-26 Virgin_territory but only 447 weekly bars (< 520) before entry
    PBF 2015-03-25 Virgin_territory but only 119 weekly bars (< 520) before entry
    NVS 2005-10-03 Virgin_territory but only 465 weekly bars (< 520) before entry
    NABZY 2006-01-31 Virgin_territory but only 422 weekly bars (< 520) before entry
    MSTR 2004-11-03 Virgin_territory but only 334 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 112 violations (183 skipped)
    XLRN 2018-07-23 prior_top=51.43 within +25% of entry=47.46
    XLRN 2020-04-20 prior_top=97.78 within +25% of entry=97.02
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.75
    WOLF_old2 2021-11-22 prior_top=139.55 within +25% of entry=133.00
    WIX 2021-03-03 prior_top=353.09 within +25% of entry=327.36
    WITS 2005-10-20 prior_top=20.89 within +25% of entry=20.10
    VICR 2021-07-27 prior_top=107.97 within +25% of entry=107.30
    VAS 2004-02-02 prior_top=24.49 within +25% of entry=23.76
    USB 2024-08-28 prior_top=51.66 within +25% of entry=46.10
    URBN 2026-01-06 prior_top=81.84 within +25% of entry=81.27
V10 EXPECTATION 5 violations (183 skipped)
    SATL 2026-04-01 entry_wk_close=6.77 > prior=3.09 (spike>60%)
    PUMP 2025-11-12 entry_wk_close=9.92 > prior=5.54 (spike>60%)
    ISEE 2022-09-30 entry_wk_close=17.94 > prior=9.44 (spike>60%)
    INOD 2025-09-29 entry_wk_close=84.14 > prior=43.48 (spike>60%)
    APPS 2020-06-15 entry_wk_close=10.38 > prior=5.82 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 24 violations
    VIRT 2021-03-18 installed_stop=24.8750 vs fill=29.3000 -> dist=0.1510 > gate=0.1500
    TRMB 2003-11-24 installed_stop=25.8750 vs fill=19.6700 -> dist=0.3155 > gate=0.1500
    TLK 2012-07-17 installed_stop=31.7760 vs fill=37.7000 -> dist=0.1571 > gate=0.1500
    SNX 2020-11-09 installed_stop=136.8750 vs fill=77.6400 -> dist=0.7629 > gate=0.1500
    SNEX 2025-01-14 installed_stop=87.2355 vs fill=68.1400 -> dist=0.2802 > gate=0.1500
    POM_old 2006-07-26 installed_stop=20.9184 vs fill=24.6400 -> dist=0.1510 > gate=0.1500
    PH 2007-04-04 installed_stop=77.1361 vs fill=58.9800 -> dist=0.3078 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.4700 -> dist=0.1602 > gate=0.1500
    MNT 2005-04-15 installed_stop=31.3920 vs fill=37.4500 -> dist=0.1618 > gate=0.1500
    MCHP 2015-02-13 installed_stop=42.9888 vs fill=51.3000 -> dist=0.1620 > gate=0.1500
V13 INVARIANT 22 violations (9 skipped)
    WTRG 2003-11-21 entry_price=20.1800 outside 2003-11-21 bar [24.9200, 25.2300]
    SHOO 2016-11-28 exit_price=34.7500 outside 2017-01-03 bar [34.7501, 36.2000]
    SGNT 2014-07-14 exit_price=23.7300 outside 2014-08-05 bar [23.7350, 24.6700]
    PPDI 2011-10-03 no bar on exit_date 2011-12-06 (nearest earlier bar: 2011-12-05)
    PH 2007-04-04 entry_price=58.9800 outside 2007-04-04 bar [87.3701, 88.6500]
    OPSW 2007-06-29 no bar on exit_date 2007-09-21 (nearest earlier bar: 2007-09-20)
    OKE 2013-09-18 entry_price=46.1500 outside 2013-09-18 bar [51.8900, 54.5300]
    NUAN 2010-12-10 exit_price=17.9300 outside 2011-03-07 bar [17.1166, 17.9259]
    NTTYY 2017-11-07 entry_price=50.4200 outside 2017-11-07 bar [50.4190, 50.4190]
    NTO 2007-10-01 no bar on exit_date 2007-10-22 (nearest earlier bar: 2007-10-15)
V14 EXPECTATION 18 violations
    VION 2000-04-14 entry bar 2000-04-14 open=100.0000 low=76.8750 close=82.5000 vs stop=75.3697, exit=75.3200
    TDS 2023-09-11 entry bar 2023-09-11 open=17.8500 low=17.3700 close=17.6500 vs stop=17.1658, exit=17.0600
    SDA 2023-07-12 entry bar 2023-07-12 open=14.1500 low=11.5500 close=11.7000 vs stop=10.4919, exit=10.4400
    QCOM 2026-05-18 entry bar 2026-05-18 open=206.7700 low=193.5800 close=203.6400 vs stop=191.2040, exit=191.1600
    PUMP 2025-11-12 entry bar 2025-11-12 open=11.0100 low=10.1850 close=10.4300 vs stop=9.8372, exit=9.7100
    ORA 2007-08-13 entry bar 2007-08-13 open=44.3000 low=40.3600 close=41.9300 vs stop=40.3780, exit=40.3400
    MLNX 2018-11-19 entry bar 2018-11-19 open=92.8500 low=91.1200 close=91.2800 vs stop=85.8773, exit=85.8500
    FSH 2005-11-15 entry bar 2005-11-15 open=65.0000 low=64.8200 close=65.5000 vs stop=58.4590, exit=64.1500
    FLNA 2020-10-12 entry bar 2020-10-12 open=11.8900 low=11.0700 close=11.4300 vs stop=10.8755, exit=10.8100
    EXTR 2022-01-21 entry bar 2022-01-21 open=12.8100 low=12.4900 close=12.4900 vs stop=12.1943, exit=12.0900
V15 EXPECTATION PASS
V16 EXPECTATION 2 violations
    NTO 2007-10-01 stale_force_exit exit 2007-10-22 (entry 2007-10-01 @ 6.34, exit @ 7.64)
    NLC 2011-08-15 stale_force_exit exit 2011-12-06 (entry 2011-08-15 @ 33.17, exit @ 38.80)
V17 EXPECTATION PASS
V18 EXPECTATION 6 violations (1 skipped)
    ANIP 2024-03-11 median close 26.24 over 6160 bars (2001-07-24..2026-06-24); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    EHC 2014-09-04 median close 23.25 over 10013 bars (1986-09-24..2026-06-24); bar 2006-10-26 close 23.75 (+400.00% vs prior close 4.75) on volume 0
    FIT 2018-06-18 median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0
    NLC 2011-08-15 median close 18.62 over 2816 bars (2004-11-11..2018-01-30); bar 2015-04-15 close 15.54 (+8533.33% vs prior close 0.18) on volume 0
    PPP 2005-06-13 median close 5.31 over 2978 bars (2003-09-10..2017-08-14); bar 2009-12-14 close 4.40 (-92.67% vs prior close 60.00) on volume 0
    TNXP 2025-06-10 median close 0.16 over 3561 bars (2012-02-03..2026-06-24); bar 2012-05-10 close 0.00 (-99.99% vs prior close 1.50) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 66 violations
    VMC 2016-11-28 LONG installed_stop 121.2960 vs screener_proxy_stop 117.6128: 3.13% tighter > 3%
    VION 2000-04-14 LONG installed_stop 75.3750 vs screener_proxy_stop 70.4996: 6.92% tighter > 3%
    TROX 2014-09-19 LONG installed_stop 25.8048 vs screener_proxy_stop 24.9872: 3.27% tighter > 3%
    TREX 2004-08-16 LONG installed_stop 39.3750 vs screener_proxy_stop 37.9224: 3.83% tighter > 3%
    TDS 2023-09-11 LONG installed_stop 17.1648 vs screener_proxy_stop 16.0264: 7.10% tighter > 3%
    SYY 2013-12-16 LONG installed_stop 34.4928 vs screener_proxy_stop 33.3316: 3.48% tighter > 3%
    STK1 2004-01-21 LONG installed_stop 27.4848 vs screener_proxy_stop 25.8796: 6.20% tighter > 3%
    SSTK 2020-09-04 LONG installed_stop 44.4864 vs screener_proxy_stop 42.5132: 4.64% tighter > 3%
    SNBR 2011-11-10 LONG installed_stop 18.8160 vs screener_proxy_stop 17.7836: 5.81% tighter > 3%
    SIMO 2022-01-24 LONG installed_stop 79.4880 vs screener_proxy_stop 75.6976: 5.01% tighter > 3%
V22 EXPECTATION 100 violations (110 skipped: position has no stop-decision rows)
    ACN 2006-10-13 no stop move for 27 weeks (2006-10-30..2007-05-11), 3 completed cycle(s) stalled; last: stop 28.66, candidate 25.44, ma 25.69, correction extreme 34.28 (extreme/ma 1.33)
    ADSK 2003-09-12 no stop move for 49 weeks (2003-09-15..2004-08-25), 6 completed cycle(s) stalled; last: stop 16.66, candidate 16.39, ma 16.55, correction extreme 35.50 (extreme/ma 2.14)
    AIN 2005-02-04 no stop move for 23 weeks (2005-07-12..2005-12-23), 2 completed cycle(s) stalled; last: stop 29.71, candidate 23.88, ma 24.31, correction extreme 34.60 (extreme/ma 1.42)
    ALSK 2006-03-10 no stop move for 49 weeks (2006-03-21..2007-03-02), 6 completed cycle(s) stalled; last: stop 10.37, candidate 8.72, ma 8.81, correction extreme 15.15 (extreme/ma 1.72)
    AN 2020-07-31 no stop move for 16 weeks (2020-08-04..2020-11-24), 2 completed cycle(s) stalled; last: stop 48.84, candidate 48.78, ma 49.27, correction extreme 50.52 (extreme/ma 1.03)
    APOG 2007-01-12 no stop move for 33 weeks (2007-01-17..2007-09-10), 3 completed cycle(s) stalled; last: stop 17.33, candidate 14.76, ma 14.91, correction extreme 22.90 (extreme/ma 1.54)
    ARCH 2005-02-11 no stop move for 23 weeks (2005-02-16..2005-07-28), 4 completed cycle(s) stalled; last: stop 16.88, candidate 16.88, ma 17.24, correction extreme 24.60 (extreme/ma 1.43)
    ARLP 2024-05-10 no stop move for 13 weeks (2024-05-31..2024-08-30), 1 completed cycle(s) stalled; last: stop 20.97, candidate 17.73, ma 17.91, correction extreme 23.17 (extreme/ma 1.29)
    AUOTY 2003-07-18 no stop move for 17 weeks (2003-07-24..2003-11-21), 2 completed cycle(s) stalled; last: stop 8.38, candidate 3.88, ma 4.07, correction extreme 12.62 (extreme/ma 3.10)
    AVGO 2013-08-30 no stop move for 99 weeks (2013-09-10..2015-08-10), 11 completed cycle(s) stalled; last: stop 34.32, candidate 9.14, ma 9.23, correction extreme 114.56 (extreme/ma 12.41)
V23 EXPECTATION 20 violations
    WDFC 2011-10-14 filled 2011-10-14 after the 2011-10-07 screen read Bearish
    TCR 2000-12-18 filled 2000-12-18 after the 2000-12-15 screen read Bearish
    SYK 2019-01-30 filled 2019-01-30 after the 2019-01-25 screen read Bearish
    SPNT 2025-04-14 filled 2025-04-14 after the 2025-04-11 screen read Bearish
    PPDI 2011-10-03 filled 2011-10-03 after the 2011-09-30 screen read Bearish
    POM_old 2006-07-26 filled 2006-07-26 after the 2006-07-21 screen read Bearish
    PAET 2011-10-04 filled 2011-10-04 after the 2011-09-30 screen read Bearish
    OFIX 2019-02-12 filled 2019-02-12 after the 2019-02-08 screen read Bearish
    NRG 2006-07-28 filled 2006-07-28 after the 2006-07-21 screen read Bearish
    NMK1 2000-11-15 filled 2000-11-15 after the 2000-11-10 screen read Bearish
