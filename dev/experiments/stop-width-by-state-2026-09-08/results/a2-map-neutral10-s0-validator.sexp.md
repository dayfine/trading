# Post-run validation report

Invariant checks failing: 4
audit join: 806/806 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT 3 violations
    BFX 2020-04-22 twin positions: BFX/NLS
    LANC 2006-09-15 twin positions: LANC/MZTI
    HPT 2013-05-20 twin positions: HPT/SVC
V7 INVARIANT 61 violations
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    UTHR 2002-11-21 Virgin_territory but only 180 weekly bars (< 520) before entry
    URBN 2003-06-05 Virgin_territory but only 503 weekly bars (< 520) before entry
    TLB 2004-06-07 Virgin_territory but only 340 weekly bars (< 520) before entry
    TFSM 2003-06-02 Virgin_territory but only 232 weekly bars (< 520) before entry
    TBI1 2000-04-28 Virgin_territory but only 68 weekly bars (< 520) before entry
    STLD 2003-12-01 Virgin_territory but only 371 weekly bars (< 520) before entry
    SRCL 2005-06-13 Virgin_territory but only 465 weekly bars (< 520) before entry
    SNDK_old 2003-05-21 Virgin_territory but only 284 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 98 violations (257 skipped)
    ZQKSQ 2004-05-12 prior_top=11.62 within +25% of entry=10.02
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.75
    VSH 2023-09-07 prior_top=27.66 within +25% of entry=25.09
    VRX1 2009-06-24 prior_top=26.54 within +25% of entry=24.83
    VRTX 2014-07-31 prior_top=99.07 within +25% of entry=89.97
    VRTX 2019-11-09 prior_top=201.31 within +25% of entry=197.08
    VICR 2021-07-03 prior_top=107.97 within +25% of entry=107.30
    USB 2024-08-28 prior_top=51.66 within +25% of entry=46.10
    URBN 2025-03-13 prior_top=58.19 within +25% of entry=50.12
    UNT 2003-12-20 prior_top=24.18 within +25% of entry=23.84
V10 EXPECTATION 8 violations (257 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    RDN 2009-08-06 entry_wk_close=5.51 > prior=1.50 (spike>60%)
    NLS 2020-04-22 entry_wk_close=6.49 > prior=2.80 (spike>60%)
    FOSL 2018-05-29 entry_wk_close=23.70 > prior=14.51 (spike>60%)
    CYBX 2005-02-04 entry_wk_close=39.78 > prior=20.88 (spike>60%)
    BPT 2022-01-22 entry_wk_close=5.52 > prior=2.85 (spike>60%)
    BFX 2020-04-22 entry_wk_close=6.49 > prior=2.80 (spike>60%)
    APWR 2000-01-24 entry_wk_close=15.33 > prior=9.33 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 23 violations
    WFM 2013-05-18 installed_stop=89.8750 vs fill=51.3400 -> dist=0.7506 > gate=0.1500
    URBN 2003-06-05 installed_stop=32.9308 vs fill=18.7500 -> dist=0.7563 > gate=0.1500
    TRN 2013-10-31 installed_stop=30.9884 vs fill=17.3100 -> dist=0.7902 > gate=0.1500
    TIN 2005-02-04 installed_stop=27.9938 vs fill=16.0900 -> dist=0.7398 > gate=0.1500
    SID 2021-01-04 installed_stop=5.3750 vs fill=6.4500 -> dist=0.1667 > gate=0.1500
    SGP_old1 2010-05-10 installed_stop=8.8750 vs fill=10.5500 -> dist=0.1588 > gate=0.1500
    PDLI 2003-05-19 installed_stop=12.3750 vs fill=14.6000 -> dist=0.1524 > gate=0.1500
    PDLI 2005-02-28 installed_stop=12.8750 vs fill=15.1700 -> dist=0.1513 > gate=0.1500
    OSPN 2022-09-15 installed_stop=7.8750 vs fill=9.2800 -> dist=0.1514 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.8000 -> dist=0.1529 > gate=0.1500
V13 INVARIANT 168 violations (7 skipped)
    YUM 2022-01-01 no bar on entry_date 2022-01-01 (nearest earlier bar: 2021-12-31)
    WSM 2012-09-01 no bar on entry_date 2012-09-01 (nearest earlier bar: 2012-08-31)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WFM 2013-05-18 no bar on entry_date 2013-05-18 (nearest earlier bar: 2013-05-17)
    WDC 2012-08-18 no bar on entry_date 2012-08-18 (nearest earlier bar: 2012-08-17)
    WAFD 2013-06-29 no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)
    VYX 2015-06-16 entry_price=36.5000 outside 2015-06-16 bar [31.2699, 36.4999]
    VRTX 2019-11-09 no bar on entry_date 2019-11-09 (nearest earlier bar: 2019-11-08)
    VICR 2021-07-03 no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)
    VFC 2006-05-06 no bar on entry_date 2006-05-06 (nearest earlier bar: 2006-05-05)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
