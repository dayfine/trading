# Post-run validation report

Invariant checks failing: 3
audit join: 564/564 rows matched

QUALITY-FLAG: 1 fallback exits (V16)

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-rk/trading/test_data/share_classes.sexp)
V7 INVARIANT 22 violations
    XERS 2024-02-14 Virgin_territory but only 295 weekly bars (< 520) before entry
    WING 2017-08-08 Virgin_territory but only 113 weekly bars (< 520) before entry
    VRSK 2017-02-22 Virgin_territory but only 385 weekly bars (< 520) before entry
    TRW1 2000-03-27 Virgin_territory but only 117 weekly bars (< 520) before entry
    TRNO 2017-04-11 Virgin_territory but only 374 weekly bars (< 520) before entry
    SBS 2010-09-30 Virgin_territory but only 438 weekly bars (< 520) before entry
    POM_old 2006-07-26 Virgin_territory but only 447 weekly bars (< 520) before entry
    PBF 2015-03-25 Virgin_territory but only 119 weekly bars (< 520) before entry
    NVS 2005-10-03 Virgin_territory but only 465 weekly bars (< 520) before entry
    NGVT 2017-10-05 Virgin_territory but only 74 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 110 violations (177 skipped)
    XLRN 2018-07-23 prior_top=51.43 within +25% of entry=47.46
    XLRN 2020-04-20 prior_top=97.78 within +25% of entry=97.02
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.75
    WOLF_old2 2021-11-22 prior_top=139.55 within +25% of entry=133.00
    WIX 2021-03-03 prior_top=353.09 within +25% of entry=327.36
    WFG 2024-08-26 prior_top=92.49 within +25% of entry=90.10
    VICR 2021-07-27 prior_top=107.97 within +25% of entry=107.30
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TKO 2017-03-23 prior_top=25.14 within +25% of entry=21.67
    THO 2021-02-16 prior_top=130.65 within +25% of entry=123.20
V10 EXPECTATION 5 violations (177 skipped)
    SATL 2026-04-01 entry_wk_close=6.77 > prior=3.09 (spike>60%)
    PUMP 2025-11-12 entry_wk_close=9.92 > prior=5.54 (spike>60%)
    ISEE 2022-09-30 entry_wk_close=17.94 > prior=9.44 (spike>60%)
    INOD 2025-09-29 entry_wk_close=84.14 > prior=43.48 (spike>60%)
    APPS 2020-06-15 entry_wk_close=10.38 > prior=5.82 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 28 violations
    VIRT 2021-03-18 installed_stop=24.8750 vs fill=29.3000 -> dist=0.1510 > gate=0.1500
    TRMB 2003-11-24 installed_stop=25.8750 vs fill=19.6700 -> dist=0.3155 > gate=0.1500
    TLK 2012-07-17 installed_stop=31.7760 vs fill=37.7000 -> dist=0.1571 > gate=0.1500
    TGI 2011-06-24 installed_stop=86.3232 vs fill=48.9200 -> dist=0.7646 > gate=0.1500
    QLYS 2021-01-20 installed_stop=106.9728 vs fill=125.8900 -> dist=0.1503 > gate=0.1500
    POM_old 2006-07-26 installed_stop=20.9184 vs fill=24.6400 -> dist=0.1510 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.8000 -> dist=0.1529 > gate=0.1500
    MNT 2005-04-15 installed_stop=31.3920 vs fill=37.4500 -> dist=0.1618 > gate=0.1500
    MNSO 2025-01-06 installed_stop=21.8750 vs fill=26.0100 -> dist=0.1590 > gate=0.1500
    MMS 2014-08-07 installed_stop=33.2640 vs fill=39.3800 -> dist=0.1553 > gate=0.1500
V13 INVARIANT 19 violations (7 skipped)
    SHOO 2016-11-28 exit_price=34.7500 outside 2017-01-03 bar [34.7501, 36.2000]
    PPDI 2011-10-03 no bar on exit_date 2011-12-06 (nearest earlier bar: 2011-12-05)
    PLMD 2007-08-27 no bar on exit_date 2007-11-01 (nearest earlier bar: 2007-10-31)
    OKE 2013-09-18 entry_price=46.1500 outside 2013-09-18 bar [51.8900, 54.5300]
    NUAN 2010-12-10 exit_price=17.9300 outside 2011-03-07 bar [17.1166, 17.9259]
    NTTYY 2017-11-07 entry_price=50.4200 outside 2017-11-07 bar [50.4190, 50.4190]
    NMK1 2000-11-15 entry_price=16.3800 outside 2000-11-15 bar [16.1880, 16.3750]
    NLC 2011-08-11 no bar on exit_date 2011-12-06 (nearest earlier bar: 2011-12-01)
    NEOG 2017-09-05 entry_price=52.8000 outside 2017-09-05 bar [68.8760, 70.4406]
    MRUS 2025-07-18 no bar on exit_date 2025-12-30 (nearest earlier bar: 2025-12-29)
V14 EXPECTATION 23 violations
    VCYT 2020-07-27 entry bar 2020-07-27 open=30.3700 low=29.3700 close=30.2400 vs stop=28.6744, exit=28.6200
    TDS 2023-09-11 entry bar 2023-09-11 open=17.8500 low=17.3700 close=17.6500 vs stop=17.1658, exit=17.0600
    SDA 2023-07-12 entry bar 2023-07-12 open=14.1500 low=11.5500 close=11.7000 vs stop=10.4919, exit=10.4400
    QCOM 2026-05-18 entry bar 2026-05-18 open=206.7700 low=193.5800 close=203.6400 vs stop=191.2040, exit=191.1600
    PUMP 2025-11-12 entry bar 2025-11-12 open=11.0100 low=10.1850 close=10.4300 vs stop=9.8372, exit=9.7100
    ORA 2007-08-13 entry bar 2007-08-13 open=44.3000 low=40.3600 close=41.9300 vs stop=40.3780, exit=40.3400
    MLNX 2018-11-19 entry bar 2018-11-19 open=92.8500 low=91.1200 close=91.2800 vs stop=85.8773, exit=85.8500
    MBI 2013-03-18 entry bar 2013-03-18 open=11.8800 low=11.7600 close=11.7900 vs stop=11.4139, exit=11.3800
    GATX 2014-10-09 entry bar 2014-10-09 open=56.7000 low=55.2723 close=55.4300 vs stop=52.8780, exit=54.6500
    FSH 2005-11-15 entry bar 2005-11-15 open=65.0000 low=64.8200 close=65.5000 vs stop=58.4590, exit=64.1500
V15 EXPECTATION PASS
V16 EXPECTATION 1 violations
    NLC 2011-08-11 stale_force_exit exit 2011-12-06 (entry 2011-08-11 @ 32.79, exit @ 38.80)
V17 EXPECTATION PASS
V18 EXPECTATION 9 violations (1 skipped)
    ANIP 2024-03-11 median close 26.24 over 6160 bars (2001-07-24..2026-06-24); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    ARJ 2005-12-29 median close 0.16 over 4552 bars (1999-02-09..2017-03-13); bar 2010-01-29 close 0.13 (-99.55% vs prior close 28.25) on volume 0
    DRX 2007-06-14 median close 8.92 over 4248 bars (2000-01-04..2018-02-22); bar 2014-10-27 close 0.01 (-99.92% vs prior close 12.71) on volume 0
    EHC 2014-09-04 median close 23.25 over 10013 bars (1986-09-24..2026-06-24); bar 2006-10-26 close 23.75 (+400.00% vs prior close 4.75) on volume 0
    FIT 2018-06-18 median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0
    FLO 2013-01-03 median close 18.16 over 11662 bars (1980-03-17..2026-06-24); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    NLC 2011-08-11 median close 18.62 over 2816 bars (2004-11-11..2018-01-30); bar 2015-04-15 close 15.54 (+8533.33% vs prior close 0.18) on volume 0
    PPP 2005-06-13 median close 5.31 over 2978 bars (2003-09-10..2017-08-14); bar 2009-12-14 close 4.40 (-92.67% vs prior close 60.00) on volume 0
    TNXP 2025-06-10 median close 0.16 over 3561 bars (2012-02-03..2026-06-24); bar 2012-05-10 close 0.00 (-99.99% vs prior close 1.50) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 68 violations
    VMC 2016-11-28 LONG installed_stop 121.2960 vs screener_proxy_stop 117.6128: 3.13% tighter > 3%
    TWI 2010-04-19 LONG installed_stop 10.3750 vs screener_proxy_stop 9.6600: 7.40% tighter > 3%
    TDS 2023-09-11 LONG installed_stop 17.1648 vs screener_proxy_stop 16.0264: 7.10% tighter > 3%
    TCOM 2024-10-15 LONG installed_stop 57.4704 vs screener_proxy_stop 53.6268: 7.17% tighter > 3%
    SYY 2013-12-16 LONG installed_stop 34.4928 vs screener_proxy_stop 33.3316: 3.48% tighter > 3%
    SSTK 2020-09-04 LONG installed_stop 44.4864 vs screener_proxy_stop 42.5132: 4.64% tighter > 3%
    SNBR 2011-11-10 LONG installed_stop 18.8160 vs screener_proxy_stop 17.7836: 5.81% tighter > 3%
    SIMO 2022-01-24 LONG installed_stop 79.4880 vs screener_proxy_stop 75.6976: 5.01% tighter > 3%
    QCOM 2022-01-20 LONG installed_stop 164.3616 vs screener_proxy_stop 155.2776: 5.85% tighter > 3%
    PYX 2018-10-22 LONG installed_stop 29.3750 vs screener_proxy_stop 28.3820: 3.50% tighter > 3%
V22 EXPECTATION 100 violations (107 skipped: position has no stop-decision rows)
    ABEV 2012-11-02 no stop move for 16 weeks (2012-11-29..2013-03-22), 1 completed cycle(s) stalled; last: stop 32.19, candidate 4.34, ma 4.38, correction extreme 40.74 (extreme/ma 9.30)
    ACN 2006-10-13 no stop move for 27 weeks (2006-10-30..2007-05-11), 3 completed cycle(s) stalled; last: stop 28.66, candidate 25.44, ma 25.69, correction extreme 34.28 (extreme/ma 1.33)
    ADSK 2003-09-12 no stop move for 49 weeks (2003-09-15..2004-08-25), 6 completed cycle(s) stalled; last: stop 16.66, candidate 16.39, ma 16.55, correction extreme 35.50 (extreme/ma 2.14)
    ALXN 2004-02-06 no stop move for 14 weeks (2004-02-10..2004-05-21), 1 completed cycle(s) stalled; last: stop 18.69, candidate 4.77, ma 4.82, correction extreme 20.99 (extreme/ma 4.36)
    AN 2020-07-31 no stop move for 16 weeks (2020-08-04..2020-11-24), 2 completed cycle(s) stalled; last: stop 48.84, candidate 48.78, ma 49.27, correction extreme 50.52 (extreme/ma 1.03)
    APOG 2007-01-12 no stop move for 33 weeks (2007-01-17..2007-09-10), 3 completed cycle(s) stalled; last: stop 17.33, candidate 14.76, ma 14.91, correction extreme 22.90 (extreme/ma 1.54)
    ARLP 2024-05-10 no stop move for 13 weeks (2024-05-31..2024-08-30), 1 completed cycle(s) stalled; last: stop 20.97, candidate 17.73, ma 17.91, correction extreme 23.17 (extreme/ma 1.29)
    AUOTY 2003-07-18 no stop move for 17 weeks (2003-07-24..2003-11-21), 2 completed cycle(s) stalled; last: stop 8.38, candidate 3.88, ma 4.07, correction extreme 12.62 (extreme/ma 3.10)
    AVGO 2013-08-30 no stop move for 99 weeks (2013-09-10..2015-08-10), 11 completed cycle(s) stalled; last: stop 34.32, candidate 9.14, ma 9.23, correction extreme 114.56 (extreme/ma 12.41)
    BBWI 2020-07-31 no stop move for 31 weeks (2020-08-05..2021-03-12), 7 completed cycle(s) stalled; last: stop 22.92, candidate 20.38, ma 20.76, correction extreme 36.10 (extreme/ma 1.74)
V23 EXPECTATION 19 violations
    TCR 2000-12-18 filled 2000-12-18 after the 2000-12-15 screen read Bearish
    SYK 2019-01-30 filled 2019-01-30 after the 2019-01-25 screen read Bearish
    SPNT 2025-04-14 filled 2025-04-14 after the 2025-04-11 screen read Bearish
    PPDI 2011-10-03 filled 2011-10-03 after the 2011-09-30 screen read Bearish
    POM_old 2006-07-26 filled 2006-07-26 after the 2006-07-21 screen read Bearish
    PAET 2011-10-04 filled 2011-10-04 after the 2011-09-30 screen read Bearish
    OFIX 2019-02-12 filled 2019-02-12 after the 2019-02-08 screen read Bearish
    NRG 2006-07-28 filled 2006-07-28 after the 2006-07-21 screen read Bearish
    NMK1 2000-11-15 filled 2000-11-15 after the 2000-11-10 screen read Bearish
    NJR 2006-07-24 filled 2006-07-24 after the 2006-07-21 screen read Bearish
