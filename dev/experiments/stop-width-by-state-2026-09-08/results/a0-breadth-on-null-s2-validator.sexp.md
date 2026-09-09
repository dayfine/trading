# Post-run validation report

Invariant checks failing: 4
audit join: 755/755 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT 5 violations
    CSC 2014-02-26 twin positions: CSC/DXC
    AMSWA 2020-04-29 twin positions: AMSWA/LGTY
    AORT 2016-08-11 twin positions: AORT/CRY_old
    PNM 2020-02-01 twin positions: PNM/TXNM
    CECO_old 2019-05-09 twin positions: CECO_old/PRDO
V7 INVARIANT 54 violations
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    UTHR 2002-11-21 Virgin_territory but only 180 weekly bars (< 520) before entry
    TLB 2004-06-07 Virgin_territory but only 340 weekly bars (< 520) before entry
    TBI1 2000-04-28 Virgin_territory but only 68 weekly bars (< 520) before entry
    SVM1 2005-10-10 Virgin_territory but only 410 weekly bars (< 520) before entry
    SRCL 2005-06-13 Virgin_territory but only 465 weekly bars (< 520) before entry
    RDA1 2005-02-02 Virgin_territory but only 374 weekly bars (< 520) before entry
    PLFE 2005-10-20 Virgin_territory but only 411 weekly bars (< 520) before entry
    PLCE 2004-11-10 Virgin_territory but only 377 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 90 violations (240 skipped)
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.85
    VSAT 2019-03-15 prior_top=81.15 within +25% of entry=76.93
    VICR 2021-07-03 prior_top=107.97 within +25% of entry=107.30
    URBN 2026-01-06 prior_top=81.84 within +25% of entry=81.11
    UHS 2018-08-22 prior_top=138.68 within +25% of entry=128.79
    UHS 2018-11-19 prior_top=138.68 within +25% of entry=133.31
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TLB 2004-06-07 prior_top=42.90 within +25% of entry=38.84
    TKR 2023-01-26 prior_top=83.40 within +25% of entry=79.90
    TGT 2020-03-12 prior_top=107.27 within +25% of entry=92.66
V10 EXPECTATION 7 violations (240 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    RDN 2009-08-06 entry_wk_close=5.51 > prior=1.50 (spike>60%)
    FOSL 2018-05-29 entry_wk_close=23.70 > prior=14.51 (spike>60%)
    CYBX 2005-02-04 entry_wk_close=39.78 > prior=20.88 (spike>60%)
    CLFD 2026-05-26 entry_wk_close=47.22 > prior=29.43 (spike>60%)
    BPT 2022-01-22 entry_wk_close=5.52 > prior=2.85 (spike>60%)
    APWR 2000-01-24 entry_wk_close=15.33 > prior=9.33 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 21 violations
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.1800 -> dist=0.9189 > gate=0.1500
    TRMB 2003-11-24 installed_stop=25.8750 vs fill=19.7100 -> dist=0.3128 > gate=0.1500
    PH 2007-04-04 installed_stop=77.1361 vs fill=58.9800 -> dist=0.3078 > gate=0.1500
    NVDA 2021-05-24 installed_stop=567.6864 vs fill=154.7800 -> dist=2.6677 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.5300 -> dist=0.1589 > gate=0.1500
    MNT 2005-04-15 installed_stop=31.3920 vs fill=37.4500 -> dist=0.1618 > gate=0.1500
    MMS 2014-08-07 installed_stop=33.2640 vs fill=39.3800 -> dist=0.1553 > gate=0.1500
    MMM 2003-07-26 installed_stop=131.9328 vs fill=69.6800 -> dist=0.8934 > gate=0.1500
    LRCX 2014-05-03 installed_stop=48.3750 vs fill=57.2000 -> dist=0.1543 > gate=0.1500
    LGTY 2020-04-29 installed_stop=14.7984 vs fill=17.5400 -> dist=0.1563 > gate=0.1500
V13 INVARIANT 154 violations (5 skipped)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WAFD 2013-06-29 no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)
    VICR 2021-07-03 no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)
    UFPI 2013-06-22 no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)
    TXNM 2020-02-01 no bar on entry_date 2020-02-01 (nearest earlier bar: 2020-01-31)
    TWX1 2000-01-28 exit_price=76.5600 outside 2000-02-23 bar [76.5630, 82.0000]
    TTE 2021-10-16 no bar on entry_date 2021-10-16 (nearest earlier bar: 2021-10-15)
    TRV 2025-05-10 no bar on entry_date 2025-05-10 (nearest earlier bar: 2025-05-09)
    TK 2023-11-04 no bar on entry_date 2023-11-04 (nearest earlier bar: 2023-11-03)
    TIMB 2003-09-13 no bar on entry_date 2003-09-13 (nearest earlier bar: 2003-09-12)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
