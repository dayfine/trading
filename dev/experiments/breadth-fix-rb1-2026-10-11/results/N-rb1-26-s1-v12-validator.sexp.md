# Post-run validation report

Invariant checks failing: 3
audit join: 575/575 rows matched

QUALITY-FLAG: 1 fallback exits (V16)

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-bp-N/trading/test_data/share_classes.sexp)
V7 INVARIANT 24 violations
    XERS 2024-02-14 Virgin_territory but only 297 weekly bars (< 520) before entry
    WING 2017-08-08 Virgin_territory but only 113 weekly bars (< 520) before entry
    VRSK 2017-02-22 Virgin_territory but only 388 weekly bars (< 520) before entry
    VOYA 2017-11-29 Virgin_territory but only 241 weekly bars (< 520) before entry
    TRW1 2000-03-27 Virgin_territory but only 118 weekly bars (< 520) before entry
    SBS 2010-09-30 Virgin_territory but only 442 weekly bars (< 520) before entry
    PBF 2015-03-25 Virgin_territory but only 122 weekly bars (< 520) before entry
    NGVT 2017-10-05 Virgin_territory but only 74 weekly bars (< 520) before entry
    NABZY 2006-01-31 Virgin_territory but only 426 weekly bars (< 520) before entry
    MSTR 2004-11-03 Virgin_territory but only 337 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 112 violations (192 skipped)
    XLRN 2018-07-23 prior_top=51.43 within +25% of entry=47.35
    XLRN 2020-04-20 prior_top=97.78 within +25% of entry=97.02
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.74
    WOLF_old2 2021-11-22 prior_top=139.55 within +25% of entry=133.00
    WIX 2021-03-03 prior_top=353.09 within +25% of entry=327.36
    VRTX 2014-07-30 prior_top=99.07 within +25% of entry=92.22
    UA 2021-11-22 prior_top=27.04 within +25% of entry=22.69
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TTWO 2020-05-19 prior_top=137.99 within +25% of entry=136.47
    THO 2021-02-16 prior_top=130.65 within +25% of entry=123.20
V10 EXPECTATION 4 violations (192 skipped)
    SATL 2026-04-01 entry_wk_close=6.77 > prior=3.09 (spike>60%)
    PUMP 2025-11-12 entry_wk_close=9.92 > prior=5.54 (spike>60%)
    ISEE 2022-09-30 entry_wk_close=17.94 > prior=9.44 (spike>60%)
    INOD 2025-09-29 entry_wk_close=84.14 > prior=43.48 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 39 violations
    XERS 2024-02-14 installed_stop=2.6496 vs fill=3.1500 -> dist=0.1589 > gate=0.1500
    VOYA 2017-11-29 installed_stop=36.7008 vs fill=43.5100 -> dist=0.1565 > gate=0.1500
    UGI 2010-07-14 installed_stop=23.3280 vs fill=27.4700 -> dist=0.1508 > gate=0.1500
    TRMB 2003-11-24 installed_stop=25.8750 vs fill=19.6900 -> dist=0.3141 > gate=0.1500
    TLK 2012-07-17 installed_stop=31.7760 vs fill=37.7000 -> dist=0.1571 > gate=0.1500
    SMTC 2018-04-10 installed_stop=35.8750 vs fill=42.2800 -> dist=0.1515 > gate=0.1500
    QLYS 2021-01-20 installed_stop=106.9728 vs fill=125.8900 -> dist=0.1503 > gate=0.1500
    PPDI 2011-10-03 installed_stop=27.6864 vs fill=32.5800 -> dist=0.1502 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.7700 -> dist=0.1536 > gate=0.1500
    MNT 2005-04-15 installed_stop=31.3920 vs fill=37.4500 -> dist=0.1618 > gate=0.1500
V13 INVARIANT 18 violations (7 skipped)
    SPIL 2003-07-15 exit_price=2.4300 outside 2003-07-21 bar [2.4313, 2.5722]
    SHOO 2016-11-28 exit_price=34.7500 outside 2017-01-03 bar [34.7501, 36.2000]
    PPDI 2011-10-03 no bar on exit_date 2011-12-06 (nearest earlier bar: 2011-12-05)
    PLMD 2007-08-27 no bar on exit_date 2007-11-01 (nearest earlier bar: 2007-10-31)
    NUAN 2010-12-10 exit_price=17.9300 outside 2011-03-07 bar [17.1166, 17.9259]
    NTTYY 2017-11-07 entry_price=50.4200 outside 2017-11-07 bar [50.4190, 50.4190]
    NLC 2011-08-11 no bar on exit_date 2011-12-06 (nearest earlier bar: 2011-12-01)
    NEOG 2017-09-05 entry_price=52.7700 outside 2017-09-05 bar [68.8760, 70.4406]
    MMSI 2011-03-14 entry_price=14.2800 outside 2011-03-14 bar [17.5400, 17.9500]
    MIME 2021-06-25 no bar on exit_date 2022-05-20 (nearest earlier bar: 2022-05-19)
V14 EXPECTATION 19 violations
    UPWK 2025-09-30 entry bar 2025-09-30 open=18.9800 low=18.2150 close=18.5700 vs stop=17.8706, exit=17.8000
    TDS 2023-09-11 entry bar 2023-09-11 open=17.8500 low=17.3700 close=17.6500 vs stop=17.1658, exit=17.1400
    SDA 2023-07-12 entry bar 2023-07-12 open=14.1500 low=11.5500 close=11.7000 vs stop=10.4919, exit=10.4900
    QCOM 2026-05-18 entry bar 2026-05-18 open=206.7700 low=193.5800 close=203.6400 vs stop=191.2014, exit=191.1000
    PUMP 2025-11-12 entry bar 2025-11-12 open=11.0100 low=10.1850 close=10.4300 vs stop=9.8426, exit=9.8200
    MLNX 2018-11-19 entry bar 2018-11-19 open=92.8500 low=91.1200 close=91.2800 vs stop=85.8773, exit=85.6600
    FSH 2005-11-15 entry bar 2005-11-15 open=65.0000 low=64.8200 close=65.5000 vs stop=58.4609, exit=64.1600
    FLNA 2020-10-12 entry bar 2020-10-12 open=11.8900 low=11.0700 close=11.4300 vs stop=10.8755, exit=10.8600
    EXTR 2022-01-21 entry bar 2022-01-21 open=12.8100 low=12.4900 close=12.4900 vs stop=12.1943, exit=12.1700
    CVNA 2025-12-31 entry bar 2025-12-31 open=429.5500 low=421.8550 close=422.0200 vs stop=406.8887, exit=406.8700
V15 EXPECTATION PASS
V16 EXPECTATION 1 violations
    NLC 2011-08-11 stale_force_exit exit 2011-12-06 (entry 2011-08-11 @ 32.80, exit @ 38.80)
V17 EXPECTATION PASS
V18 EXPECTATION 10 violations
    ANIP 2024-03-11 median close 26.24 over 6160 bars (2001-07-24..2026-06-24); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    ARJ 2005-12-29 median close 0.16 over 4552 bars (1999-02-09..2017-03-13); bar 2010-01-29 close 0.13 (-99.55% vs prior close 28.25) on volume 0
    AUY 2011-08-08 median close 5.11 over 5183 bars (2001-06-22..2023-03-31); bar 2001-10-04 close 1.67 (+1571.60% vs prior close 0.10) on volume 0
    BRK-A 2017-08-03 median close 83100.00 over 11236 bars (1980-03-17..2026-06-24), above the 10000.00 ceiling
    DRX 2007-06-14 median close 8.92 over 4248 bars (2000-01-04..2018-02-22); bar 2014-10-27 close 0.01 (-99.92% vs prior close 12.71) on volume 0
    EHC 2014-09-04 median close 23.25 over 10013 bars (1986-09-24..2026-06-24); bar 2006-10-26 close 23.75 (+400.00% vs prior close 4.75) on volume 0
    FIT 2019-11-26 median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0
    FLO 2013-01-03 median close 18.16 over 11662 bars (1980-03-17..2026-06-24); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    NLC 2011-08-11 median close 18.62 over 2816 bars (2004-11-11..2018-01-30); bar 2015-04-15 close 15.54 (+8533.33% vs prior close 0.18) on volume 0
    TNXP 2025-06-10 median close 0.16 over 3561 bars (2012-02-03..2026-06-24); bar 2012-05-10 close 0.00 (-99.99% vs prior close 1.50) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 66 violations
    VMC 2016-11-28 LONG installed_stop 121.2960 vs screener_proxy_stop 117.6128: 3.13% tighter > 3%
    VGR 2021-12-06 LONG installed_stop 10.3471 vs screener_proxy_stop 10.0280: 3.18% tighter > 3%
    UPWK 2025-09-30 LONG installed_stop 17.8750 vs screener_proxy_stop 16.7716: 6.58% tighter > 3%
    TDS 2023-09-11 LONG installed_stop 17.1648 vs screener_proxy_stop 16.0264: 7.10% tighter > 3%
    SYY 2013-12-16 LONG installed_stop 34.4928 vs screener_proxy_stop 33.3316: 3.48% tighter > 3%
    STK1 2004-01-21 LONG installed_stop 27.4848 vs screener_proxy_stop 25.8796: 6.20% tighter > 3%
    SSTK 2020-09-04 LONG installed_stop 44.4864 vs screener_proxy_stop 42.5132: 4.64% tighter > 3%
    SNBR 2011-11-10 LONG installed_stop 18.8160 vs screener_proxy_stop 17.7836: 5.81% tighter > 3%
    RYAAY 2003-10-27 LONG installed_stop 46.3750 vs screener_proxy_stop 44.5832: 4.02% tighter > 3%
    QCOM 2022-01-20 LONG installed_stop 164.3616 vs screener_proxy_stop 155.2776: 5.85% tighter > 3%
V22 EXPECTATION 107 violations (100 skipped: position has no stop-decision rows)
    ABEV 2012-11-02 no stop move for 15 weeks (2012-11-29..2013-03-15), 1 completed cycle(s) stalled; last: stop 32.19, candidate 4.39, ma 4.44, correction extreme 40.74 (extreme/ma 9.18)
    ACN 2006-10-13 no stop move for 27 weeks (2006-10-30..2007-05-11), 3 completed cycle(s) stalled; last: stop 28.66, candidate 25.44, ma 25.69, correction extreme 34.28 (extreme/ma 1.33)
    ADNT 2020-02-21 no stop move for 31 weeks (2020-11-09..2021-06-18), 1 completed cycle(s) stalled; last: stop 25.38, candidate 20.66, ma 20.86, correction extreme 26.23 (extreme/ma 1.26)
    AIN 2005-02-04 no stop move for 23 weeks (2005-07-12..2005-12-23), 2 completed cycle(s) stalled; last: stop 29.71, candidate 23.88, ma 24.31, correction extreme 34.60 (extreme/ma 1.42)
    AIT 2022-08-26 no stop move for 16 weeks (2022-10-05..2023-01-26), 1 completed cycle(s) stalled; last: stop 104.22, candidate 102.48, ma 103.52, correction extreme 114.59 (extreme/ma 1.11)
    ALSK 2006-03-10 no stop move for 49 weeks (2006-03-21..2007-03-02), 6 completed cycle(s) stalled; last: stop 10.37, candidate 8.72, ma 8.81, correction extreme 15.15 (extreme/ma 1.72)
    ALXN 2004-02-06 no stop move for 14 weeks (2004-02-10..2004-05-21), 1 completed cycle(s) stalled; last: stop 18.69, candidate 4.77, ma 4.82, correction extreme 20.99 (extreme/ma 4.36)
    AMZN 2013-09-13 no stop move for 21 weeks (2013-09-18..2014-02-14), 2 completed cycle(s) stalled; last: stop 268.16, candidate 15.17, ma 15.33, correction extreme 324.06 (extreme/ma 21.15)
    AN 2020-07-31 no stop move for 16 weeks (2020-08-04..2020-11-24), 2 completed cycle(s) stalled; last: stop 48.84, candidate 48.78, ma 49.27, correction extreme 50.52 (extreme/ma 1.03)
    AOS 2009-11-27 no stop move for 27 weeks (2009-11-30..2010-06-07), 2 completed cycle(s) stalled; last: stop 37.16, candidate 5.81, ma 5.87, correction extreme 48.43 (extreme/ma 8.25)
V23 EXPECTATION 16 violations
    WDFC 2011-10-14 filled 2011-10-14 after the 2011-10-07 screen read Bearish
    SYK 2019-01-30 filled 2019-01-30 after the 2019-01-25 screen read Bearish
    STN 2025-05-01 filled 2025-05-01 after the 2025-04-25 screen read Bearish
    PPDI 2011-10-03 filled 2011-10-03 after the 2011-09-30 screen read Bearish
    PAET 2011-10-04 filled 2011-10-04 after the 2011-09-30 screen read Bearish
    OFIX 2019-02-12 filled 2019-02-12 after the 2019-02-08 screen read Bearish
    MZTI 2015-09-03 filled 2015-09-03 after the 2015-08-28 screen read Bearish
    MEI 2004-08-20 filled 2004-08-20 after the 2004-08-13 screen read Bearish
    LIN 2019-02-15 filled 2019-02-15 after the 2019-02-08 screen read Bearish
    ISEE 2022-09-30 filled 2022-09-30 after the 2022-09-23 screen read Bearish
