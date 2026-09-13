# Post-run validation report

Invariant checks failing: 3
audit join: 700/700 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 50 violations
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    WDR 2007-07-13 Virgin_territory but only 491 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    UTHR 2002-11-21 Virgin_territory but only 180 weekly bars (< 520) before entry
    UGP 2006-10-20 Virgin_territory but only 370 weekly bars (< 520) before entry
    TLRD 2000-08-23 Virgin_territory but only 139 weekly bars (< 520) before entry
    TLB 2004-06-07 Virgin_territory but only 340 weekly bars (< 520) before entry
    TBI1 2000-04-28 Virgin_territory but only 68 weekly bars (< 520) before entry
    STLD 2003-12-01 Virgin_territory but only 371 weekly bars (< 520) before entry
    SRCL 2005-06-13 Virgin_territory but only 465 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 92 violations (228 skipped)
    X 2023-08-21 prior_top=37.63 within +25% of entry=31.79
    WOLF_old2 2021-11-20 prior_top=139.55 within +25% of entry=130.66
    VRTX 2014-06-28 prior_top=93.77 within +25% of entry=92.22
    VICR 2021-07-03 prior_top=107.97 within +25% of entry=107.30
    USB 2024-08-28 prior_top=51.66 within +25% of entry=46.10
    UHS 2018-08-22 prior_top=138.68 within +25% of entry=128.80
    UHS 2018-11-19 prior_top=138.68 within +25% of entry=133.32
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TLB 2004-06-07 prior_top=42.90 within +25% of entry=38.89
    TGT 2020-03-12 prior_top=107.27 within +25% of entry=92.66
V10 EXPECTATION 9 violations (228 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    RDN 2009-08-06 entry_wk_close=5.51 > prior=1.50 (spike>60%)
    RBAK 2006-12-23 entry_wk_close=24.94 > prior=14.52 (spike>60%)
    MVL 2002-03-08 entry_wk_close=5.33 > prior=3.00 (spike>60%)
    GERN 2012-09-01 entry_wk_close=2.74 > prior=1.61 (spike>60%)
    ENCO 2009-09-30 entry_wk_close=3.76 > prior=1.52 (spike>60%)
    CLFD 2026-05-26 entry_wk_close=47.22 > prior=29.43 (spike>60%)
    BFX 2020-04-22 entry_wk_close=6.49 > prior=2.80 (spike>60%)
    APWR 2000-01-24 entry_wk_close=15.33 > prior=9.33 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 20 violations
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.3100 -> dist=0.9045 > gate=0.1500
    TRMB 2003-11-24 installed_stop=25.8750 vs fill=19.6700 -> dist=0.3155 > gate=0.1500
    SU 2025-11-08 installed_stop=36.2592 vs fill=42.7200 -> dist=0.1512 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.8000 -> dist=0.1529 > gate=0.1500
    MNT 2005-04-15 installed_stop=31.3920 vs fill=37.4500 -> dist=0.1618 > gate=0.1500
    MMM 2003-07-26 installed_stop=131.9328 vs fill=69.6800 -> dist=0.8934 > gate=0.1500
    MGM 2001-09-18 installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500
    INFY 2014-10-10 installed_stop=60.9792 vs fill=31.7800 -> dist=0.9188 > gate=0.1500
    GRA 2016-01-22 installed_stop=73.1724 vs fill=86.3000 -> dist=0.1521 > gate=0.1500
    FLO 2013-01-03 installed_stop=20.8750 vs fill=16.5400 -> dist=0.2621 > gate=0.1500
V13 INVARIANT 140 violations (7 skipped)
    YUM 2022-01-01 no bar on entry_date 2022-01-01 (nearest earlier bar: 2021-12-31)
    WOLF_old2 2021-11-20 no bar on entry_date 2021-11-20 (nearest earlier bar: 2021-11-19)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WDC 2012-08-18 no bar on entry_date 2012-08-18 (nearest earlier bar: 2012-08-17)
    WAFD 2013-06-29 no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)
    VRTX 2014-06-28 no bar on entry_date 2014-06-28 (nearest earlier bar: 2014-06-27)
    VICR 2021-07-03 no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)
    URBN 2025-12-20 no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)
    UN 2017-03-11 no bar on entry_date 2017-03-11 (nearest earlier bar: 2017-03-10)
    UFPI 2013-06-22 no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)
V14 EXPECTATION PASS (1 skipped)
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 8 violations
    AKR 2016-06-30 median close 1000000.00 over 8323 bars (1993-05-27..2026-06-22), above the 10000.00 ceiling
    ARJ 2005-12-29 median close 0.16 over 4552 bars (1999-02-09..2017-03-13); bar 2010-01-29 close 0.13 (-99.55% vs prior close 28.25) on volume 0
    BRK-A 2013-02-01 median close 83087.55 over 11234 bars (1980-03-17..2026-06-22), above the 10000.00 ceiling
    CLE 2014-11-18 median close 19.00 over 4813 bars (1997-12-31..2018-06-28); bar 2014-06-09 close 0.07 (-94.53% vs prior close 1.28) on volume 0
    EHC 2011-01-10 median close 23.25 over 10011 bars (1986-09-24..2026-06-22); bar 2006-10-26 close 23.75 (+400.00% vs prior close 4.75) on volume 0
    FLO 2013-01-03 median close 18.18 over 11660 bars (1980-03-17..2026-06-22); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    KBL 2021-07-26 median close 199.09 over 3819 bars (1998-01-29..2022-03-02); bar 2012-01-09 close 165.81 (+481.17% vs prior close 28.53) on volume 0
    MVL 2002-03-08 median close 9.00 over 4795 bars (1999-01-04..2018-01-24); bar 2010-01-26 close 60.00 (+96.88% vs prior close 30.48) on volume 0
