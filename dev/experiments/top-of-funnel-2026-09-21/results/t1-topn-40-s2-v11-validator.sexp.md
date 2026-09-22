# Post-run validation report

Invariant checks failing: 3
audit join: 766/766 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 107 violations
    ZS 2020-05-29 Virgin_territory but only 117 weekly bars (< 520) before entry
    XERS 2024-02-14 Virgin_territory but only 297 weekly bars (< 520) before entry
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    WLK 2012-08-06 Virgin_territory but only 419 weekly bars (< 520) before entry
    W 2018-06-05 Virgin_territory but only 193 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
    UTHR 2002-11-21 Virgin_territory but only 180 weekly bars (< 520) before entry
    USNA 2005-02-01 Virgin_territory but only 502 weekly bars (< 520) before entry
    UNVR 2022-03-15 Virgin_territory but only 354 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 83 violations (242 skipped)
    WRLD 2010-03-12 prior_top=49.25 within +25% of entry=43.73
    WLY 2021-02-05 prior_top=52.55 within +25% of entry=50.09
    UNVR 2022-03-15 prior_top=32.43 within +25% of entry=32.23
    UHS 2018-08-22 prior_top=138.68 within +25% of entry=128.79
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    SCI 2011-08-03 prior_top=10.17 within +25% of entry=9.99
    ROST 2023-11-14 prior_top=125.52 within +25% of entry=124.00
    RCRC 2006-12-01 prior_top=44.66 within +25% of entry=41.35
    QTWO 2018-02-17 prior_top=45.70 within +25% of entry=44.70
    QRVO 2018-02-27 prior_top=85.25 within +25% of entry=81.66
V10 EXPECTATION 10 violations (242 skipped)
    VUZI 2026-05-29 entry_wk_close=4.60 > prior=2.84 (spike>60%)
    VLN 2026-05-16 entry_wk_close=3.22 > prior=1.79 (spike>60%)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    IPSU 2011-06-02 entry_wk_close=21.47 > prior=12.99 (spike>60%)
    GSIT 2025-10-20 entry_wk_close=9.23 > prior=3.84 (spike>60%)
    CUTRQ 2022-03-28 entry_wk_close=72.31 > prior=40.49 (spike>60%)
    CLPA 2000-01-31 entry_wk_close=25.25 > prior=12.12 (spike>60%)
    CBMC 2000-03-06 entry_wk_close=191.25 > prior=71.25 (spike>60%)
    BLNK 2020-07-29 entry_wk_close=11.05 > prior=5.28 (spike>60%)
    ARXX 2000-02-07 entry_wk_close=11.95 > prior=4.95 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 23 violations
    XERS 2024-02-14 installed_stop=2.6496 vs fill=3.1300 -> dist=0.1535 > gate=0.1500
    VLN 2026-05-16 installed_stop=2.9136 vs fill=3.4300 -> dist=0.1506 > gate=0.1500
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.1800 -> dist=0.9189 > gate=0.1500
    SOUN 2024-04-02 installed_stop=4.3750 vs fill=5.2400 -> dist=0.1651 > gate=0.1500
    PATK 2015-02-17 installed_stop=61.8750 vs fill=48.3400 -> dist=0.2800 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.5300 -> dist=0.1589 > gate=0.1500
    MNSO 2025-01-06 installed_stop=21.8400 vs fill=26.0100 -> dist=0.1603 > gate=0.1500
    MMS 2014-08-07 installed_stop=33.2640 vs fill=39.3800 -> dist=0.1553 > gate=0.1500
    MGM 2001-09-18 installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500
    MCK 2020-05-28 installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500
V13 INVARIANT 132 violations (5 skipped)
    ZWS 2018-10-06 no bar on entry_date 2018-10-06 (nearest earlier bar: 2018-10-05)
    WSO 2010-03-06 no bar on entry_date 2010-03-06 (nearest earlier bar: 2010-03-05)
    WPM 2024-04-20 no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WLK 2012-08-06 entry_price=64.6000 outside 2012-08-06 bar [65.8500, 68.4000]
    WAFD 2013-06-29 no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)
    VLN 2026-05-16 no bar on entry_date 2026-05-16 (nearest earlier bar: 2026-05-15)
    URBN 2025-12-20 no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)
    UPS 2021-04-17 no bar on entry_date 2021-04-17 (nearest earlier bar: 2021-04-16)
    UN 2017-03-11 no bar on entry_date 2017-03-11 (nearest earlier bar: 2017-03-10)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 13 violations
    APLS 2023-04-03 median close 32.83 over 2156 bars (2017-11-09..2026-06-10); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0
    BLNK 2020-07-29 median close 1.61 over 4080 bars (2008-07-15..2026-06-10); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0
    BOKF 2003-06-04 median close 49.75 over 8753 bars (1991-09-05..2026-06-10); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    BRK-A 2006-05-18 median close 83000.00 over 11227 bars (1980-03-17..2026-06-10), above the 10000.00 ceiling
    CIR 2013-04-24 median close 32.28 over 6046 bars (1999-10-18..2023-11-16); bar 2023-11-06 close 0.00 (-100.00% vs prior close 56.00) on volume 0
    CSKI 2009-12-19 median close 0.20 over 5186 bars (1995-02-01..2015-10-05); bar 2002-12-13 close 0.45 (+542.86% vs prior close 0.07) on volume 0
    DUOT 2026-06-06 median close 2.71 over 3135 bars (2008-08-13..2026-06-10); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0
    FLO 2020-03-09 median close 18.19 over 11653 bars (1980-03-17..2026-06-10); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    IOVA 2020-03-24 median close 7.47 over 3936 bars (2010-10-15..2026-06-10); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0
    ISA 2019-03-14 median close 7360.00 over 5664 bars (1997-12-31..2020-07-07); bar 2001-08-22 close 0.05 (-100.00% vs prior close 1070.00) on volume 0
