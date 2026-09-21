# Post-run validation report

Invariant checks failing: 3
audit join: 716/716 rows matched

QUALITY-FLAG: 2 fallback exits (V16)

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 115 violations
    YETI 2020-06-08 Virgin_territory but only 87 weekly bars (< 520) before entry
    XPOF 2023-01-27 Virgin_territory but only 79 weekly bars (< 520) before entry
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    WING 2017-08-08 Virgin_territory but only 113 weekly bars (< 520) before entry
    VNA 2015-02-05 Virgin_territory but only 258 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    VICI 2019-10-16 Virgin_territory but only 105 weekly bars (< 520) before entry
    UCM 2000-05-22 Virgin_territory but only 126 weekly bars (< 520) before entry
    UAA 2010-09-15 Virgin_territory but only 254 weekly bars (< 520) before entry
    TWST 2020-05-06 Virgin_territory but only 81 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 73 violations (247 skipped)
    ZGN 2023-09-08 prior_top=15.43 within +25% of entry=14.25
    WRLD 2010-03-12 prior_top=49.25 within +25% of entry=43.73
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TGTX 2018-03-05 prior_top=18.68 within +25% of entry=15.72
    STVN 2023-03-02 prior_top=28.27 within +25% of entry=23.47
    SKYW 2013-11-23 prior_top=16.83 within +25% of entry=16.41
    SCSC 2007-11-03 prior_top=37.19 within +25% of entry=35.00
    SAND 2025-06-02 prior_top=9.56 within +25% of entry=9.20
    RDWR 2020-12-22 prior_top=28.14 within +25% of entry=27.14
    RCRC 2006-12-01 prior_top=44.66 within +25% of entry=41.35
V10 EXPECTATION 10 violations (247 skipped)
    VUZI 2026-05-29 entry_wk_close=4.60 > prior=2.84 (spike>60%)
    VLN 2026-05-16 entry_wk_close=3.22 > prior=1.79 (spike>60%)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    MVL 2002-03-08 entry_wk_close=5.33 > prior=3.00 (spike>60%)
    IPSU 2011-06-02 entry_wk_close=21.47 > prior=12.99 (spike>60%)
    EOSE 2023-06-28 entry_wk_close=4.34 > prior=2.43 (spike>60%)
    CLPA 2000-01-31 entry_wk_close=25.25 > prior=12.12 (spike>60%)
    CBMC 2000-03-06 entry_wk_close=191.25 > prior=71.25 (spike>60%)
    BLNK 2020-07-29 entry_wk_close=11.05 > prior=5.28 (spike>60%)
    ARXX 2000-02-07 entry_wk_close=11.95 > prior=4.95 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 14 violations
    YMM 2024-11-20 installed_stop=8.2848 vs fill=9.7600 -> dist=0.1511 > gate=0.1500
    VLN 2026-05-16 installed_stop=2.9136 vs fill=3.4300 -> dist=0.1506 > gate=0.1500
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.1800 -> dist=0.9189 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.8100 -> dist=0.1527 > gate=0.1500
    MMS 2014-08-07 installed_stop=33.2640 vs fill=39.3800 -> dist=0.1553 > gate=0.1500
    MGM 2001-09-18 installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500
    MCK 2020-05-28 installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500
    FULT 2002-03-07 installed_stop=23.3952 vs fill=19.5000 -> dist=0.1998 > gate=0.1500
    EVCM 2026-01-07 installed_stop=10.4448 vs fill=12.2900 -> dist=0.1501 > gate=0.1500
    ENB 2004-10-29 installed_stop=36.2112 vs fill=21.2700 -> dist=0.7025 > gate=0.1500
V13 INVARIANT 125 violations (5 skipped)
    ZWS 2018-10-06 no bar on entry_date 2018-10-06 (nearest earlier bar: 2018-10-05)
    WSO 2010-03-06 no bar on entry_date 2010-03-06 (nearest earlier bar: 2010-03-05)
    WPM 2024-04-20 no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WIRE 2023-12-14 no bar on exit_date 2024-07-03 (nearest earlier bar: 2024-07-02)
    WING 2017-08-08 entry_price=31.3600 outside 2017-08-08 bar [32.7300, 34.1600]
    WAFD 2013-06-29 no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)
    VRSK 2012-12-22 no bar on entry_date 2012-12-22 (nearest earlier bar: 2012-12-21)
    VLN 2026-05-16 no bar on entry_date 2026-05-16 (nearest earlier bar: 2026-05-15)
    VICI 2019-10-16 entry_price=23.4200 outside 2019-10-16 bar [23.0400, 23.4190]
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION 2 violations
    CLE 2014-11-18 force_liquidation exit 2014-11-19 (entry 2014-11-18 @ 37.65, exit @ 0.71)
    ASPS 2017-04-20 force_liquidation exit 2017-04-21 (entry 2017-04-20 @ 35.53, exit @ 26.75)
V17 EXPECTATION PASS
V18 EXPECTATION 20 violations
    ANIP 2024-03-02 median close 25.62 over 6145 bars (2001-07-24..2026-06-02); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    APLS 2023-04-03 median close 32.95 over 2150 bars (2017-11-09..2026-06-02); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0
    BLNK 2020-07-29 median close 1.61 over 4074 bars (2008-07-15..2026-06-02); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0
    BOKF 2003-06-04 median close 49.72 over 8747 bars (1991-09-05..2026-06-02); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    BRK-A 2006-05-18 median close 83000.00 over 11221 bars (1980-03-17..2026-06-02), above the 10000.00 ceiling
    CLE 2014-11-18 median close 19.00 over 4813 bars (1997-12-31..2018-06-28); bar 2014-06-09 close 0.07 (-94.53% vs prior close 1.28) on volume 0
    CSKI 2009-12-19 median close 0.20 over 5186 bars (1995-02-01..2015-10-05); bar 2002-12-13 close 0.45 (+542.86% vs prior close 0.07) on volume 0
    CYRX 2020-05-18 median close 2.90 over 5227 bars (2005-08-22..2026-06-02); bar 2010-02-05 close 9.30 (+900.00% vs prior close 0.93) on volume 0
    FERG 2025-07-23 median close 69.50 over 4393 bars (2001-07-20..2026-06-02); bar 2001-10-22 close 60.37 (-97.71% vs prior close 2641.96) on volume 0
    FLO 2020-03-09 median close 18.20 over 11647 bars (1980-03-17..2026-06-02); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
