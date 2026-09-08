# Post-run validation report

Invariant checks failing: 4
audit join: 705/705 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT 2 violations
    CSC 2014-02-26 twin positions: CSC/DXC
    AMSWA 2020-04-29 twin positions: AMSWA/LGTY
V7 INVARIANT 48 violations
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    UTHR 2002-11-21 Virgin_territory but only 180 weekly bars (< 520) before entry
    UGP 2006-10-20 Virgin_territory but only 370 weekly bars (< 520) before entry
    TLB 2004-06-07 Virgin_territory but only 340 weekly bars (< 520) before entry
    TBI1 2000-04-28 Virgin_territory but only 68 weekly bars (< 520) before entry
    SVM1 2005-10-10 Virgin_territory but only 410 weekly bars (< 520) before entry
    SRCL 2005-06-13 Virgin_territory but only 465 weekly bars (< 520) before entry
    RDA1 2005-02-02 Virgin_territory but only 374 weekly bars (< 520) before entry
    PLFE 2005-10-20 Virgin_territory but only 411 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 83 violations (219 skipped)
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.74
    VSAT 2019-03-15 prior_top=81.15 within +25% of entry=76.86
    VRTX 2014-07-31 prior_top=99.07 within +25% of entry=89.97
    VICR 2021-07-03 prior_top=107.97 within +25% of entry=107.30
    UHS 2018-11-19 prior_top=138.68 within +25% of entry=133.37
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TTWO 2020-05-19 prior_top=137.99 within +25% of entry=136.47
    TLB 2004-06-07 prior_top=42.90 within +25% of entry=38.90
    THO 2021-02-13 prior_top=130.65 within +25% of entry=123.01
    TGT 2020-03-12 prior_top=107.27 within +25% of entry=92.66
V10 EXPECTATION 6 violations (219 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    RDN 2009-08-06 entry_wk_close=5.51 > prior=1.50 (spike>60%)
    GERN 2012-09-01 entry_wk_close=2.74 > prior=1.61 (spike>60%)
    ENCO 2009-09-30 entry_wk_close=3.76 > prior=1.52 (spike>60%)
    CLFD 2026-05-26 entry_wk_close=47.22 > prior=29.43 (spike>60%)
    APWR 2000-01-24 entry_wk_close=15.33 > prior=9.33 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 19 violations
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.1800 -> dist=0.9189 > gate=0.1500
    TRMB 2003-11-24 installed_stop=25.8750 vs fill=19.6900 -> dist=0.3141 > gate=0.1500
    SMTC 2018-04-10 installed_stop=35.8750 vs fill=42.2800 -> dist=0.1515 > gate=0.1500
    R 2024-03-28 installed_stop=102.3552 vs fill=120.9300 -> dist=0.1536 > gate=0.1500
    PH 2007-04-04 installed_stop=77.1361 vs fill=58.9800 -> dist=0.3078 > gate=0.1500
    ORLY 2025-01-27 installed_stop=1127.3750 vs fill=84.4200 -> dist=12.3544 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.4800 -> dist=0.1600 > gate=0.1500
    MNT 2005-04-15 installed_stop=31.3920 vs fill=37.4500 -> dist=0.1618 > gate=0.1500
    MMM 2003-07-26 installed_stop=131.9328 vs fill=69.6800 -> dist=0.8934 > gate=0.1500
    LRCX 2014-05-03 installed_stop=48.3750 vs fill=57.2000 -> dist=0.1543 > gate=0.1500
V13 INVARIANT 149 violations (8 skipped)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WDC 2018-03-10 no bar on entry_date 2018-03-10 (nearest earlier bar: 2018-03-09)
    WAFD 2013-06-29 no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)
    VICR 2021-07-03 no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)
    VFC 2006-05-06 no bar on entry_date 2006-05-06 (nearest earlier bar: 2006-05-05)
    URBN 2025-12-20 no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)
    UN 2017-03-11 no bar on entry_date 2017-03-11 (nearest earlier bar: 2017-03-10)
    UFPI 2013-06-22 no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)
    TXNM 2020-02-01 no bar on entry_date 2020-02-01 (nearest earlier bar: 2020-01-31)
    TWX1 2000-01-28 exit_price=76.5600 outside 2000-02-23 bar [76.5630, 82.0000]
V14 EXPECTATION PASS (1 skipped)
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
