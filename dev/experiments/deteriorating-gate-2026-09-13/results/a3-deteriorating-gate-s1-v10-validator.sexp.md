# Post-run validation report

Invariant checks failing: 3
audit join: 675/675 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 45 violations
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    WDR 2007-07-13 Virgin_territory but only 491 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    UTHR 2002-11-21 Virgin_territory but only 180 weekly bars (< 520) before entry
    TLRD 2000-08-23 Virgin_territory but only 139 weekly bars (< 520) before entry
    TLB 2004-06-07 Virgin_territory but only 340 weekly bars (< 520) before entry
    TBI1 2000-04-28 Virgin_territory but only 68 weekly bars (< 520) before entry
    STLD 2003-12-01 Virgin_territory but only 371 weekly bars (< 520) before entry
    SRCL 2005-06-13 Virgin_territory but only 465 weekly bars (< 520) before entry
    ROVI 2007-06-06 Virgin_territory but only 496 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 76 violations (231 skipped)
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.74
    VSAT 2019-03-15 prior_top=81.15 within +25% of entry=76.86
    VRTX 2014-06-28 prior_top=93.77 within +25% of entry=92.22
    VICR 2021-07-03 prior_top=107.97 within +25% of entry=107.30
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TTWO 2020-05-19 prior_top=137.99 within +25% of entry=136.47
    TLB 2004-06-07 prior_top=42.90 within +25% of entry=38.90
    TKO 2022-07-25 prior_top=88.08 within +25% of entry=71.21
    TGT 2020-03-12 prior_top=107.27 within +25% of entry=92.66
    TBI 2018-08-21 prior_top=31.21 within +25% of entry=29.69
V10 EXPECTATION 10 violations (231 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    RDN 2009-08-06 entry_wk_close=5.51 > prior=1.50 (spike>60%)
    RBAK 2006-12-23 entry_wk_close=24.94 > prior=14.52 (spike>60%)
    MVL 2002-03-08 entry_wk_close=5.33 > prior=3.00 (spike>60%)
    GERN 2012-09-01 entry_wk_close=2.74 > prior=1.61 (spike>60%)
    FOSL 2018-05-29 entry_wk_close=23.70 > prior=14.51 (spike>60%)
    CLFD 2026-05-26 entry_wk_close=47.22 > prior=29.43 (spike>60%)
    BLDP 2026-05-16 entry_wk_close=5.54 > prior=3.28 (spike>60%)
    BFX 2020-04-22 entry_wk_close=6.49 > prior=2.80 (spike>60%)
    APWR 2000-01-24 entry_wk_close=15.33 > prior=9.33 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 23 violations
    WDR 2007-07-13 installed_stop=23.8272 vs fill=28.0500 -> dist=0.1505 > gate=0.1500
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.1800 -> dist=0.9189 > gate=0.1500
    TRMB 2003-11-24 installed_stop=25.8750 vs fill=19.6900 -> dist=0.3141 > gate=0.1500
    SMTC 2018-04-10 installed_stop=35.8750 vs fill=42.2800 -> dist=0.1515 > gate=0.1500
    R 2024-03-28 installed_stop=102.3552 vs fill=120.9300 -> dist=0.1536 > gate=0.1500
    PH 2007-04-04 installed_stop=77.1361 vs fill=58.9800 -> dist=0.3078 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.4800 -> dist=0.1600 > gate=0.1500
    MNT 2005-04-15 installed_stop=31.3920 vs fill=37.4500 -> dist=0.1618 > gate=0.1500
    MMM 2003-07-26 installed_stop=131.9328 vs fill=69.6800 -> dist=0.8934 > gate=0.1500
    MGM 2001-09-18 installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500
V13 INVARIANT 133 violations (8 skipped)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WERN 2009-12-12 no bar on entry_date 2009-12-12 (nearest earlier bar: 2009-12-11)
    WDC 2012-08-18 no bar on entry_date 2012-08-18 (nearest earlier bar: 2012-08-17)
    WAFD 2013-06-29 no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)
    VRTX 2014-06-28 no bar on entry_date 2014-06-28 (nearest earlier bar: 2014-06-27)
    VICR 2021-07-03 no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)
    URBN 2025-12-20 no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)
    UFPI 2013-06-22 no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)
    TXNM 2020-02-01 no bar on entry_date 2020-02-01 (nearest earlier bar: 2020-01-31)
    TWX1 2000-01-28 exit_price=76.5600 outside 2000-02-23 bar [76.5630, 82.0000]
V14 EXPECTATION PASS (1 skipped)
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 7 violations
    AKR 2016-06-30 median close 1000000.00 over 8326 bars (1993-05-27..2026-06-25), above the 10000.00 ceiling
    BRK-A 2006-05-18 median close 83100.00 over 11237 bars (1980-03-17..2026-06-25), above the 10000.00 ceiling
    CLE 2014-11-18 median close 19.00 over 4813 bars (1997-12-31..2018-06-28); bar 2014-06-09 close 0.07 (-94.53% vs prior close 1.28) on volume 0
    EHC 2011-01-10 median close 23.25 over 10014 bars (1986-09-24..2026-06-25); bar 2006-10-26 close 23.75 (+400.00% vs prior close 4.75) on volume 0
    KBL 2021-07-26 median close 199.09 over 3819 bars (1998-01-29..2022-03-02); bar 2012-01-09 close 165.81 (+481.17% vs prior close 28.53) on volume 0
    MVL 2002-03-08 median close 9.00 over 4795 bars (1999-01-04..2018-01-24); bar 2010-01-26 close 60.00 (+96.88% vs prior close 30.48) on volume 0
    RRC 2006-11-30 median close 16.75 over 9591 bars (1984-11-05..2026-06-25); bar 1992-11-23 close 4.22 (+1399.47% vs prior close 0.28) on volume 0
