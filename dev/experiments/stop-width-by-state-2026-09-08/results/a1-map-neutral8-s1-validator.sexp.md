# Post-run validation report

Invariant checks failing: 4
audit join: 816/816 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT 5 violations
    AABA 2005-11-16 twin positions: AABA/YHOO
    BFX 2020-04-22 twin positions: BFX/NLS
    AORT 2016-08-11 twin positions: AORT/CRY_old
    BB 2006-09-29 twin positions: BB/BBRY
    AZN 2019-03-11 twin positions: AZN/AZN_old
V7 INVARIANT 69 violations
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
V9 EXPECTATION 114 violations (226 skipped)
    ZQKSQ 2004-05-12 prior_top=11.62 within +25% of entry=10.02
    VSH 2023-09-07 prior_top=27.66 within +25% of entry=25.09
    VSAT 2019-03-15 prior_top=81.15 within +25% of entry=76.86
    VRX1 2009-06-24 prior_top=26.54 within +25% of entry=24.77
    VRTX 2014-07-31 prior_top=99.07 within +25% of entry=89.97
    VICR 2021-07-03 prior_top=107.97 within +25% of entry=107.30
    URBN 2025-03-13 prior_top=58.19 within +25% of entry=50.12
    TXT 2023-08-05 prior_top=78.40 within +25% of entry=78.00
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TLB 2004-06-07 prior_top=42.90 within +25% of entry=38.90
V10 EXPECTATION 13 violations (226 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    RDN 2009-08-06 entry_wk_close=5.51 > prior=1.50 (spike>60%)
    RBAK 2006-12-23 entry_wk_close=24.94 > prior=14.52 (spike>60%)
    NLS 2020-04-22 entry_wk_close=6.49 > prior=2.80 (spike>60%)
    FOSL 2018-05-29 entry_wk_close=23.70 > prior=14.51 (spike>60%)
    FMCC 2024-11-13 entry_wk_close=3.00 > prior=1.29 (spike>60%)
    CYBX 2005-02-04 entry_wk_close=39.78 > prior=20.88 (spike>60%)
    CLPA 2000-01-31 entry_wk_close=25.25 > prior=12.12 (spike>60%)
    CLFD 2026-05-26 entry_wk_close=47.22 > prior=29.43 (spike>60%)
    BPT 2022-01-22 entry_wk_close=5.52 > prior=2.85 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 26 violations
    URBN 2003-06-05 installed_stop=32.9308 vs fill=18.7700 -> dist=0.7544 > gate=0.1500
    TRN 2013-10-31 installed_stop=31.6477 vs fill=17.1800 -> dist=0.8421 > gate=0.1500
    TIN 2005-02-04 installed_stop=27.9938 vs fill=16.0900 -> dist=0.7398 > gate=0.1500
    SMTC 2018-04-10 installed_stop=35.8750 vs fill=42.2800 -> dist=0.1515 > gate=0.1500
    SMRT_old 2018-05-11 installed_stop=2.3750 vs fill=2.8300 -> dist=0.1608 > gate=0.1500
    SID 2021-01-04 installed_stop=5.3750 vs fill=6.4500 -> dist=0.1667 > gate=0.1500
    PDLI 2003-05-19 installed_stop=12.3750 vs fill=14.6000 -> dist=0.1524 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.7700 -> dist=0.1536 > gate=0.1500
    IMMR 2024-08-27 installed_stop=7.3750 vs fill=8.8300 -> dist=0.1648 > gate=0.1500
    HGSI 2011-11-17 installed_stop=6.8750 vs fill=8.2000 -> dist=0.1616 > gate=0.1500
V13 INVARIANT 153 violations (9 skipped)
    YUM 2022-01-01 no bar on entry_date 2022-01-01 (nearest earlier bar: 2021-12-31)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WAFD 2013-06-29 no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)
    VICR 2021-07-03 no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)
    URBN 2025-12-20 no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)
    UFPI 2013-06-22 no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)
    TXT 2023-08-05 no bar on entry_date 2023-08-05 (nearest earlier bar: 2023-08-04)
    TWX1 2000-01-28 exit_price=76.5600 outside 2000-02-23 bar [76.5630, 82.0000]
    TTE 2021-10-16 no bar on entry_date 2021-10-16 (nearest earlier bar: 2021-10-15)
    TRV 2025-05-10 no bar on entry_date 2025-05-10 (nearest earlier bar: 2025-05-09)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
