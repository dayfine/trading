# Post-run validation report

Invariant checks failing: 3
audit join: 724/724 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 112 violations
    ZS 2020-05-29 Virgin_territory but only 117 weekly bars (< 520) before entry
    XPOF 2023-01-27 Virgin_territory but only 79 weekly bars (< 520) before entry
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    WLK 2012-08-06 Virgin_territory but only 419 weekly bars (< 520) before entry
    WING 2017-08-08 Virgin_territory but only 113 weekly bars (< 520) before entry
    WDR 2007-07-13 Virgin_territory but only 491 weekly bars (< 520) before entry
    VRSK 2017-02-22 Virgin_territory but only 388 weekly bars (< 520) before entry
    VOYA 2017-11-29 Virgin_territory but only 241 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    VICI 2019-10-16 Virgin_territory but only 105 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 79 violations (249 skipped)
    ZGN 2023-09-08 prior_top=15.43 within +25% of entry=14.25
    XLRN 2018-07-23 prior_top=51.43 within +25% of entry=47.46
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.75
    VRTX 2014-07-31 prior_top=99.07 within +25% of entry=89.97
    VRNS 2021-07-21 prior_top=71.50 within +25% of entry=60.93
    UNVR 2022-03-15 prior_top=32.43 within +25% of entry=32.15
    UMAC 2026-01-15 prior_top=18.73 within +25% of entry=17.69
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TTWO 2020-05-19 prior_top=137.99 within +25% of entry=136.42
    TGTX 2018-03-05 prior_top=18.68 within +25% of entry=15.48
V10 EXPECTATION 10 violations (249 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    MVL 2002-03-08 entry_wk_close=5.33 > prior=3.00 (spike>60%)
    ISEE 2022-09-30 entry_wk_close=17.94 > prior=9.44 (spike>60%)
    IPSU 2011-06-02 entry_wk_close=21.47 > prior=12.99 (spike>60%)
    EOSE 2023-06-27 entry_wk_close=4.34 > prior=2.43 (spike>60%)
    CUTRQ 2022-03-28 entry_wk_close=72.31 > prior=40.49 (spike>60%)
    CLPA 2000-01-31 entry_wk_close=25.25 > prior=12.12 (spike>60%)
    CBMC 2000-03-06 entry_wk_close=191.25 > prior=71.25 (spike>60%)
    BLNK 2020-07-29 entry_wk_close=11.05 > prior=5.28 (spike>60%)
    ARXX 2000-02-07 entry_wk_close=11.95 > prior=4.95 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 18 violations
    YMM 2024-11-20 installed_stop=8.2848 vs fill=9.7700 -> dist=0.1520 > gate=0.1500
    VOYA 2017-11-29 installed_stop=36.7008 vs fill=43.5100 -> dist=0.1565 > gate=0.1500
    VLN 2026-05-26 installed_stop=2.9136 vs fill=3.4300 -> dist=0.1506 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.4700 -> dist=0.1602 > gate=0.1500
    MMS 2014-08-07 installed_stop=33.2640 vs fill=39.3800 -> dist=0.1553 > gate=0.1500
    MGM 2001-09-18 installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500
    LZB 2024-07-15 installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500
    LPG 2023-09-15 installed_stop=23.2022 vs fill=27.3000 -> dist=0.1501 > gate=0.1500
    GC 2020-04-06 installed_stop=1392.8640 vs fill=1647.7000 -> dist=0.1547 > gate=0.1500
    FULT 2002-03-07 installed_stop=23.3952 vs fill=19.5000 -> dist=0.1998 > gate=0.1500
V13 INVARIANT 25 violations (4 skipped)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WLK 2012-08-06 entry_price=64.5300 outside 2012-08-06 bar [65.8500, 68.4000]
    WING 2017-08-08 entry_price=31.6500 outside 2017-08-08 bar [32.7300, 34.1600]
    VRTX 2001-03-12 exit_price=31.6400 outside 2001-03-15 bar [31.6406, 35.6250]
    PCYC 2015-01-21 no bar on exit_date 2015-05-25 (nearest earlier bar: 2015-05-22)
    NTTYY 2017-11-07 entry_price=50.4200 outside 2017-11-07 bar [50.4190, 50.4190]
    NPSNY 2009-08-28 entry_price=32.1200 outside 2009-08-28 bar [31.1960, 32.1180]
    NEOG 2017-09-05 entry_price=52.4700 outside 2017-09-05 bar [68.8760, 70.4406]
    MAR 2004-06-04 exit_price=48.6700 outside 2004-07-08 bar [48.6701, 49.6499]
    LACO 2020-05-27 no bar on exit_date 2020-10-09 (nearest earlier bar: 2020-10-08)
V14 EXPECTATION 56 violations
    XRAY 2000-04-25 entry bar 2000-04-25 open=27.8750 low=27.8750 close=29.1876 vs stop=28.2786, exit=28.2500
    UTL 2022-07-01 entry bar 2022-07-01 open=58.7100 low=58.0800 close=61.0000 vs stop=57.2322, exit=57.1400
    UMBF 2024-07-31 entry bar 2024-07-31 open=103.0000 low=100.7500 close=102.0200 vs stop=100.9806, exit=100.8300
    UEC 2021-10-18 entry bar 2021-10-18 open=3.4600 low=3.4300 close=3.4900 vs stop=3.3780, exit=3.3500
    UBS 2014-11-26 entry bar 2014-11-26 open=17.5500 low=17.5200 close=23.2000 vs stop=21.8076, exit=18.0900
    TIE 2010-05-13 entry bar 2010-05-13 open=17.1200 low=16.9400 close=17.4100 vs stop=16.9849, exit=16.8500
    TGTX 2018-03-05 entry bar 2018-03-05 open=14.8500 low=14.8500 close=15.2000 vs stop=14.8097, exit=14.7800
    TCBI 2006-04-19 entry bar 2006-04-19 open=24.4700 low=24.0700 close=24.9100 vs stop=23.8116, exit=23.2500
    SWK 2001-02-08 entry bar 2001-02-08 open=34.6000 low=34.5100 close=35.3000 vs stop=33.6522, exit=33.5700
    STLD 2003-12-01 entry bar 2003-12-01 open=20.1400 low=19.7500 close=21.2500 vs stop=20.3735, exit=20.0900
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 12 violations
    BLNK 2020-07-29 median close 1.61 over 4088 bars (2008-07-15..2026-06-23); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0
    BOKF 2003-06-04 median close 49.76 over 8761 bars (1991-09-05..2026-06-23); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    BRK-A 2006-05-18 median close 83100.00 over 11235 bars (1980-03-17..2026-06-23), above the 10000.00 ceiling
    CECO 2023-10-13 median close 4.62 over 11481 bars (1980-12-02..2026-06-23); bar 1992-09-29 close 2.66 (+399.96% vs prior close 0.53) on volume 0
    CEQP 2018-01-22 median close 25.49 over 5608 bars (2001-07-26..2023-11-16); bar 2023-11-14 close 0.00 (-100.00% vs prior close 28.26) on volume 0
    DUOT 2026-06-08 median close 2.72 over 3143 bars (2008-08-13..2026-06-23); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0
    FLO 2013-01-03 median close 18.17 over 11661 bars (1980-03-17..2026-06-23); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    IOVA 2020-03-24 median close 7.45 over 3944 bars (2010-10-15..2026-06-23); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0
    MVL 2002-03-08 median close 9.00 over 4795 bars (1999-01-04..2018-01-24); bar 2010-01-26 close 60.00 (+96.88% vs prior close 30.48) on volume 0
    OMNI 2007-06-20 median close 2.34 over 3083 bars (1999-01-04..2018-04-13); bar 2002-07-03 close 1.62 (+200.00% vs prior close 0.54) on volume 0
