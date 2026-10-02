# Post-run validation report

Invariant checks failing: 3
audit join: 510/510 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-investor26/trading/test_data/share_classes.sexp)
V7 INVARIANT 30 violations
    XERS 2024-02-14 Virgin_territory but only 297 weekly bars (< 520) before entry
    WING 2017-08-08 Virgin_territory but only 113 weekly bars (< 520) before entry
    WDR 2007-07-13 Virgin_territory but only 491 weekly bars (< 520) before entry
    VRSK 2017-02-22 Virgin_territory but only 388 weekly bars (< 520) before entry
    VOYA 2017-11-29 Virgin_territory but only 241 weekly bars (< 520) before entry
    TRW1 2000-03-27 Virgin_territory but only 118 weekly bars (< 520) before entry
    TRNO 2017-04-11 Virgin_territory but only 377 weekly bars (< 520) before entry
    SMCI 2013-10-01 Virgin_territory but only 343 weekly bars (< 520) before entry
    PERY 2004-04-26 Virgin_territory but only 334 weekly bars (< 520) before entry
    PDM 2015-01-28 Virgin_territory but only 472 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 90 violations (175 skipped)
    XLRN 2018-07-23 prior_top=51.43 within +25% of entry=47.49
    XLRN 2020-04-20 prior_top=97.78 within +25% of entry=97.02
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.85
    WOLF_old2 2021-11-22 prior_top=139.55 within +25% of entry=133.00
    WIX 2021-03-03 prior_top=353.09 within +25% of entry=327.36
    URBN 2026-01-06 prior_top=81.84 within +25% of entry=81.11
    UA 2021-11-22 prior_top=27.04 within +25% of entry=22.69
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TTWO 2020-05-19 prior_top=137.99 within +25% of entry=136.41
    THO 2021-02-16 prior_top=130.65 within +25% of entry=123.20
V10 EXPECTATION 3 violations (175 skipped)
    ISEE 2022-09-30 entry_wk_close=17.94 > prior=9.44 (spike>60%)
    FMI 2015-01-20 entry_wk_close=47.97 > prior=22.22 (spike>60%)
    CLPA 2000-01-31 entry_wk_close=25.25 > prior=12.12 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 26 violations
    XERS 2024-02-14 installed_stop=2.6496 vs fill=3.1300 -> dist=0.1535 > gate=0.1500
    VOYA 2017-11-29 installed_stop=36.7008 vs fill=43.5100 -> dist=0.1565 > gate=0.1500
    TRMB 2003-11-24 installed_stop=25.8750 vs fill=19.7100 -> dist=0.3128 > gate=0.1500
    QLYS 2021-01-20 installed_stop=106.9728 vs fill=125.9600 -> dist=0.1507 > gate=0.1500
    PSB 2017-04-24 installed_stop=104.3750 vs fill=122.9800 -> dist=0.1513 > gate=0.1500
    NJDCY 2015-06-08 installed_stop=15.2160 vs fill=17.9500 -> dist=0.1523 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.8100 -> dist=0.1527 > gate=0.1500
    MNT 2005-04-15 installed_stop=31.3920 vs fill=37.4500 -> dist=0.1618 > gate=0.1500
    MNSO 2025-01-06 installed_stop=21.8400 vs fill=26.0100 -> dist=0.1603 > gate=0.1500
    MMS 2014-08-07 installed_stop=33.2640 vs fill=39.3800 -> dist=0.1553 > gate=0.1500
V13 INVARIANT 23 violations (6 skipped)
    WING 2017-08-08 entry_price=31.3600 outside 2017-08-08 bar [32.7300, 34.1600]
    TDG 2013-07-08 entry_price=136.7000 outside 2013-07-08 bar [158.2500, 160.6800]
    SPIL 2003-07-15 exit_price=2.4300 outside 2003-07-21 bar [2.4313, 2.5722]
    SHOO 2016-11-28 exit_price=34.7500 outside 2017-01-03 bar [34.7501, 36.2000]
    SCCO 2003-07-21 entry_price=15.4300 outside 2003-07-21 bar [15.4322, 16.1914]
    PETC 2000-05-30 entry_price=18.5600 outside 2000-05-30 bar [18.5630, 18.8750]
    OSIS 2024-03-26 entry_price=140.9700 outside 2024-03-26 bar [137.3000, 140.9650]
    NUAN 2010-12-10 exit_price=17.9300 outside 2011-03-07 bar [17.1166, 17.9259]
    NTTYY 2017-11-07 entry_price=50.4200 outside 2017-11-07 bar [50.4190, 50.4190]
    NFLX 2020-03-03 exit_price=341.7200 outside 2020-03-09 bar [341.7209, 357.4701]
V14 EXPECTATION 18 violations
    UPWK 2025-09-30 entry bar 2025-09-30 open=18.9800 low=18.2150 close=18.5700 vs stop=17.8706, exit=17.8400
    TDS 2023-09-11 entry bar 2023-09-11 open=17.8500 low=17.3700 close=17.6500 vs stop=17.1658, exit=17.0600
    SDA 2023-07-12 entry bar 2023-07-12 open=14.1500 low=11.5500 close=11.7000 vs stop=10.4919, exit=10.4400
    QCOM 2026-05-18 entry bar 2026-05-18 open=206.7700 low=193.5800 close=203.6400 vs stop=191.1970, exit=191.0800
    MLNX 2018-11-19 entry bar 2018-11-19 open=92.8500 low=91.1200 close=91.2800 vs stop=85.8773, exit=85.7800
    FSH 2005-11-15 entry bar 2005-11-15 open=65.0000 low=64.8200 close=65.5000 vs stop=58.4676, exit=64.1700
    EXTR 2022-01-21 entry bar 2022-01-21 open=12.8100 low=12.4900 close=12.4900 vs stop=12.1943, exit=12.1800
    EPRS 2011-01-19 entry bar 2011-01-19 open=127.2000 low=120.0000 close=120.6000 vs stop=109.8743, exit=109.7500
    DUOT 2026-06-08 entry bar 2026-06-08 open=12.3100 low=11.7500 close=12.2300 vs stop=10.9781, exit=10.7600
    CVNA 2025-12-31 entry bar 2025-12-31 open=429.5500 low=421.8550 close=422.0200 vs stop=406.8887, exit=406.7700
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 10 violations
    ANIP 2024-03-11 median close 25.95 over 6150 bars (2001-07-24..2026-06-09); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    ARJ 2005-12-29 median close 0.16 over 4552 bars (1999-02-09..2017-03-13); bar 2010-01-29 close 0.13 (-99.55% vs prior close 28.25) on volume 0
    DUOT 2026-06-08 median close 2.71 over 3134 bars (2008-08-13..2026-06-09); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0
    EHC 2014-09-04 median close 23.25 over 10003 bars (1986-09-24..2026-06-09); bar 2006-10-26 close 23.75 (+400.00% vs prior close 4.75) on volume 0
    FIT 2019-11-26 median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0
    FLO 2021-06-03 median close 18.19 over 11652 bars (1980-03-17..2026-06-09); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    IHG 2013-11-27 median close 37.39 over 5829 bars (2003-04-08..2026-06-09); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0
    NPPXF 2014-02-12 median close 41.56 over 4372 bars (2002-12-23..2026-06-09); bar 2009-02-13 close 48.23 (-100.00% vs prior close 1000000.00) on volume 0
    PPP 2005-06-13 median close 5.31 over 2978 bars (2003-09-10..2017-08-14); bar 2009-12-14 close 4.40 (-92.67% vs prior close 60.00) on volume 0
    TNXP 2025-06-10 median close 0.16 over 3551 bars (2012-02-03..2026-06-09); bar 2012-05-10 close 0.00 (-99.99% vs prior close 1.50) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 60 violations
    VMC 2016-11-28 LONG installed_stop 121.2960 vs screener_proxy_stop 117.6128: 3.13% tighter > 3%
    VGR 2021-12-06 LONG installed_stop 10.3471 vs screener_proxy_stop 10.0280: 3.18% tighter > 3%
    UPWK 2025-09-30 LONG installed_stop 17.8750 vs screener_proxy_stop 16.7716: 6.58% tighter > 3%
    TDS 2023-09-11 LONG installed_stop 17.1648 vs screener_proxy_stop 16.0264: 7.10% tighter > 3%
    SYY 2013-12-16 LONG installed_stop 34.4928 vs screener_proxy_stop 33.3316: 3.48% tighter > 3%
    SSTK 2020-09-04 LONG installed_stop 44.4864 vs screener_proxy_stop 42.5132: 4.64% tighter > 3%
    RYAAY 2003-10-27 LONG installed_stop 46.3750 vs screener_proxy_stop 44.5832: 4.02% tighter > 3%
    PYX 2018-10-22 LONG installed_stop 29.3750 vs screener_proxy_stop 28.3820: 3.50% tighter > 3%
    POWI 2012-05-21 LONG installed_stop 39.3504 vs screener_proxy_stop 36.9656: 6.45% tighter > 3%
    PKG 2023-08-21 LONG installed_stop 139.8912 vs screener_proxy_stop 135.2124: 3.46% tighter > 3%
V22 EXPECTATION 98 violations (90 skipped: position has no stop-decision rows)
    ABEV 2012-11-02 no stop move for 15 weeks (2012-11-29..2013-03-15), 1 completed cycle(s) stalled; last: stop 32.19, candidate 4.39, ma 4.44, correction extreme 40.74 (extreme/ma 9.18)
    ACN 2006-10-13 no stop move for 27 weeks (2006-10-30..2007-05-11), 3 completed cycle(s) stalled; last: stop 28.66, candidate 25.44, ma 25.69, correction extreme 34.28 (extreme/ma 1.33)
    ADNT 2020-02-21 no stop move for 31 weeks (2020-11-09..2021-06-18), 1 completed cycle(s) stalled; last: stop 25.38, candidate 20.66, ma 20.86, correction extreme 26.23 (extreme/ma 1.26)
    AIN 2005-02-04 no stop move for 23 weeks (2005-07-12..2005-12-23), 2 completed cycle(s) stalled; last: stop 29.71, candidate 23.88, ma 24.31, correction extreme 34.60 (extreme/ma 1.42)
    AIT 2022-08-26 no stop move for 16 weeks (2022-10-05..2023-01-26), 1 completed cycle(s) stalled; last: stop 104.22, candidate 102.48, ma 103.52, correction extreme 114.59 (extreme/ma 1.11)
    AJG 2010-05-07 no stop move for 15 weeks (2010-05-11..2010-08-24), 1 completed cycle(s) stalled; last: stop 21.72, candidate 16.44, ma 16.61, correction extreme 23.66 (extreme/ma 1.42)
    ALJ 2012-08-10 no stop move for 18 weeks (2012-08-14..2012-12-21), 3 completed cycle(s) stalled; last: stop 10.67, candidate 9.88, ma 10.16, correction extreme 12.06 (extreme/ma 1.19)
    ALSK 2006-03-10 no stop move for 49 weeks (2006-03-21..2007-03-02), 6 completed cycle(s) stalled; last: stop 10.37, candidate 8.72, ma 8.81, correction extreme 15.15 (extreme/ma 1.72)
    ALXN 2004-02-06 no stop move for 14 weeks (2004-02-10..2004-05-21), 1 completed cycle(s) stalled; last: stop 18.69, candidate 4.77, ma 4.82, correction extreme 20.99 (extreme/ma 4.36)
    AN 2020-07-31 no stop move for 16 weeks (2020-08-04..2020-11-24), 2 completed cycle(s) stalled; last: stop 48.84, candidate 48.78, ma 49.27, correction extreme 50.52 (extreme/ma 1.03)
V23 EXPECTATION 34 violations
    WTM 2015-07-27 filled 2015-07-27 after the 2015-07-24 screen read Bearish
    WST 2012-05-24 filled 2012-05-24 after the 2012-05-18 screen read Bearish
    VRSK 2013-01-02 filled 2013-01-02 after the 2012-12-28 screen read Bearish
    SYK 2019-01-30 filled 2019-01-30 after the 2019-01-25 screen read Bearish
    STN 2025-05-01 filled 2025-05-01 after the 2025-04-25 screen read Bearish
    POWI 2012-05-21 filled 2012-05-21 after the 2012-05-18 screen read Bearish
    PBSOQ 2004-05-10 filled 2004-05-10 after the 2004-05-07 screen read Bearish
    ONXX 2012-05-24 filled 2012-05-24 after the 2012-05-18 screen read Bearish
    OFIX 2019-02-12 filled 2019-02-12 after the 2019-02-08 screen read Bearish
    NJR 2006-07-24 filled 2006-07-24 after the 2006-07-21 screen read Bearish
