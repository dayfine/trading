# Post-run validation report

Invariant checks failing: 3
audit join: 690/690 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 42 violations
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    UTHR 2002-11-21 Virgin_territory but only 180 weekly bars (< 520) before entry
    TLRD 2000-08-23 Virgin_territory but only 139 weekly bars (< 520) before entry
    TLB 2004-06-07 Virgin_territory but only 340 weekly bars (< 520) before entry
    TBI1 2000-04-28 Virgin_territory but only 68 weekly bars (< 520) before entry
    STLD 2003-12-01 Virgin_territory but only 371 weekly bars (< 520) before entry
    SRCL 2005-06-13 Virgin_territory but only 465 weekly bars (< 520) before entry
    PLCE 2004-11-10 Virgin_territory but only 377 weekly bars (< 520) before entry
    PHCC 2000-02-29 Virgin_territory but only 114 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 86 violations (227 skipped)
    VSAT 2019-03-15 prior_top=81.15 within +25% of entry=76.93
    VRTX 2014-06-28 prior_top=93.77 within +25% of entry=92.22
    VICR 2021-07-03 prior_top=107.97 within +25% of entry=107.30
    URBN 2025-03-13 prior_top=58.19 within +25% of entry=50.12
    URBN 2026-01-06 prior_top=81.84 within +25% of entry=81.11
    UHS 2018-08-22 prior_top=138.68 within +25% of entry=128.79
    TXT 2023-08-24 prior_top=78.40 within +25% of entry=76.69
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TLB 2004-06-07 prior_top=42.90 within +25% of entry=38.84
    TGT 2020-03-12 prior_top=107.27 within +25% of entry=92.66
V10 EXPECTATION 9 violations (227 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    RDN 2009-08-06 entry_wk_close=5.51 > prior=1.50 (spike>60%)
    RBAK 2006-12-23 entry_wk_close=24.94 > prior=14.52 (spike>60%)
    MVL 2002-03-08 entry_wk_close=5.33 > prior=3.00 (spike>60%)
    GERN 2012-09-01 entry_wk_close=2.74 > prior=1.61 (spike>60%)
    FOSL 2018-05-29 entry_wk_close=23.70 > prior=14.51 (spike>60%)
    CLFD 2026-05-26 entry_wk_close=47.22 > prior=29.43 (spike>60%)
    BFX 2020-04-22 entry_wk_close=6.49 > prior=2.80 (spike>60%)
    APWR 2000-01-24 entry_wk_close=15.33 > prior=9.33 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 15 violations
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.1800 -> dist=0.9189 > gate=0.1500
    TRMB 2003-11-24 installed_stop=25.8750 vs fill=19.7100 -> dist=0.3128 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.8100 -> dist=0.1527 > gate=0.1500
    MNT 2005-04-15 installed_stop=31.3920 vs fill=37.4500 -> dist=0.1618 > gate=0.1500
    MMM 2003-07-26 installed_stop=131.9328 vs fill=69.6800 -> dist=0.8934 > gate=0.1500
    MGM 2001-09-18 installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500
    GSK 2005-10-27 installed_stop=54.3756 vs fill=64.0000 -> dist=0.1504 > gate=0.1500
    GAS1 2007-04-04 installed_stop=42.6816 vs fill=50.2400 -> dist=0.1504 > gate=0.1500
    DY 2017-04-18 installed_stop=84.1728 vs fill=99.0600 -> dist=0.1503 > gate=0.1500
    CHDN 2012-03-24 installed_stop=47.8272 vs fill=57.2500 -> dist=0.1646 > gate=0.1500
V13 INVARIANT 135 violations (7 skipped)
    YUM 2022-01-01 no bar on entry_date 2022-01-01 (nearest earlier bar: 2021-12-31)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WERN 2009-12-12 no bar on entry_date 2009-12-12 (nearest earlier bar: 2009-12-11)
    WDC 2012-08-18 no bar on entry_date 2012-08-18 (nearest earlier bar: 2012-08-17)
    WAVX 2014-05-31 no bar on entry_date 2014-05-31 (nearest earlier bar: 2014-05-30)
    WAFD 2013-06-29 no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)
    VRTX 2014-06-28 no bar on entry_date 2014-06-28 (nearest earlier bar: 2014-06-27)
    VICR 2021-07-03 no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)
    UFPI 2013-06-22 no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)
    TXNM 2020-02-01 no bar on entry_date 2020-02-01 (nearest earlier bar: 2020-01-31)
V14 EXPECTATION PASS (1 skipped)
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 9 violations
    AKR 2016-06-30 median close 1000000.00 over 8323 bars (1993-05-27..2026-06-22), above the 10000.00 ceiling
    BRK-A 2006-05-18 median close 83087.55 over 11234 bars (1980-03-17..2026-06-22), above the 10000.00 ceiling
    CLE 2014-11-18 median close 19.00 over 4813 bars (1997-12-31..2018-06-28); bar 2014-06-09 close 0.07 (-94.53% vs prior close 1.28) on volume 0
    EHC 2011-01-10 median close 23.25 over 10011 bars (1986-09-24..2026-06-22); bar 2006-10-26 close 23.75 (+400.00% vs prior close 4.75) on volume 0
    KBL 2021-07-26 median close 199.09 over 3819 bars (1998-01-29..2022-03-02); bar 2012-01-09 close 165.81 (+481.17% vs prior close 28.53) on volume 0
    MVL 2002-03-08 median close 9.00 over 4795 bars (1999-01-04..2018-01-24); bar 2010-01-26 close 60.00 (+96.88% vs prior close 30.48) on volume 0
    NLCS 2014-06-05 median close 943.55 over 4096 bars (1997-12-31..2020-04-29); bar 2006-01-30 close 1051.53 (+1339.21% vs prior close 73.06) on volume 0
    RAL_old 2017-04-24 median close 45000.00 over 4022 bars (1997-12-31..2022-03-02), above the 10000.00 ceiling; bar 2010-04-23 close 49.84 (-99.84% vs prior close 31800.00) on volume 0
    RRC 2006-11-30 median close 16.75 over 9588 bars (1984-11-05..2026-06-22); bar 1992-11-23 close 4.22 (+1399.47% vs prior close 0.28) on volume 0
