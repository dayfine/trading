# Post-run validation report

Invariant checks failing: 4
audit join: 793/793 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT 6 violations
    AABA 2005-11-16 twin positions: AABA/YHOO
    BFX 2020-04-22 twin positions: BFX/NLS
    AORT 2016-08-11 twin positions: AORT/CRY_old
    CSC 2014-02-26 twin positions: CSC/DXC
    BB 2006-09-29 twin positions: BB/BBRY
    RCII 2020-12-21 twin positions: RCII/UPBD
V7 INVARIANT 64 violations
    YHOO 2005-11-16 Virgin_territory but only 415 weekly bars (< 520) before entry
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    UTHR 2002-11-21 Virgin_territory but only 180 weekly bars (< 520) before entry
    URBN 2003-06-05 Virgin_territory but only 503 weekly bars (< 520) before entry
    UHAL 2003-09-12 Virgin_territory but only 466 weekly bars (< 520) before entry
    TLB 2004-06-07 Virgin_territory but only 340 weekly bars (< 520) before entry
    TFSM 2003-06-02 Virgin_territory but only 232 weekly bars (< 520) before entry
    TBI1 2000-04-28 Virgin_territory but only 68 weekly bars (< 520) before entry
    STLD 2003-12-01 Virgin_territory but only 371 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 106 violations (242 skipped)
    ZQKSQ 2004-05-12 prior_top=11.62 within +25% of entry=10.02
    VSH 2023-09-07 prior_top=27.66 within +25% of entry=25.09
    VSAT 2017-12-29 prior_top=81.15 within +25% of entry=75.15
    VSAT 2019-03-15 prior_top=81.15 within +25% of entry=76.93
    VRX1 2009-06-24 prior_top=26.54 within +25% of entry=24.78
    VRTX 2014-07-30 prior_top=99.07 within +25% of entry=91.61
    VICR 2021-07-03 prior_top=107.97 within +25% of entry=107.30
    URBN 2025-03-13 prior_top=58.19 within +25% of entry=50.12
    TXT 2023-08-05 prior_top=78.40 within +25% of entry=78.00
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
V10 EXPECTATION 7 violations (242 skipped)
    RDN 2009-08-06 entry_wk_close=5.51 > prior=1.50 (spike>60%)
    NLS 2020-04-22 entry_wk_close=6.49 > prior=2.80 (spike>60%)
    CYBX 2005-02-04 entry_wk_close=39.78 > prior=20.88 (spike>60%)
    CLPA 2000-01-31 entry_wk_close=25.25 > prior=12.12 (spike>60%)
    CLFD 2026-05-26 entry_wk_close=47.22 > prior=29.43 (spike>60%)
    BFX 2020-04-22 entry_wk_close=6.49 > prior=2.80 (spike>60%)
    APWR 2000-01-24 entry_wk_close=15.33 > prior=9.33 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 20 violations
    WFM 2013-05-18 installed_stop=89.8750 vs fill=51.3400 -> dist=0.7506 > gate=0.1500
    URBN 2003-06-05 installed_stop=32.9308 vs fill=18.7300 -> dist=0.7582 > gate=0.1500
    TRN 2013-10-31 installed_stop=31.6477 vs fill=17.1800 -> dist=0.8421 > gate=0.1500
    TIN 2005-02-04 installed_stop=27.9938 vs fill=16.0900 -> dist=0.7398 > gate=0.1500
    PDLI 2003-05-19 installed_stop=12.3750 vs fill=14.6000 -> dist=0.1524 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.8100 -> dist=0.1527 > gate=0.1500
    KLIC 2014-05-09 installed_stop=11.8750 vs fill=14.0500 -> dist=0.1548 > gate=0.1500
    IMMR 2024-08-27 installed_stop=7.3750 vs fill=8.8300 -> dist=0.1648 > gate=0.1500
    HGSI 2011-11-17 installed_stop=6.8750 vs fill=8.2000 -> dist=0.1616 > gate=0.1500
    GE 2024-04-13 installed_stop=128.6304 vs fill=154.1300 -> dist=0.1654 > gate=0.1500
V13 INVARIANT 154 violations (7 skipped)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WFM 2013-05-18 no bar on entry_date 2013-05-18 (nearest earlier bar: 2013-05-17)
    WAFD 2013-06-29 no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)
    VICR 2021-07-03 no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)
    URBN 2025-12-20 no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)
    UN 2019-09-07 no bar on entry_date 2019-09-07 (nearest earlier bar: 2019-09-06)
    UFPI 2013-06-22 no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)
    TXT 2023-08-05 no bar on entry_date 2023-08-05 (nearest earlier bar: 2023-08-04)
    TXNM 2020-02-01 no bar on entry_date 2020-02-01 (nearest earlier bar: 2020-01-31)
    TWX1 2000-01-28 exit_price=76.5600 outside 2000-02-23 bar [76.5630, 82.0000]
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
