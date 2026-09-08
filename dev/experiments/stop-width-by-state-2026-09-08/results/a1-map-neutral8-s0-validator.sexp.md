# Post-run validation report

Invariant checks failing: 4
audit join: 784/784 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT 6 violations
    AABA 2005-11-16 twin positions: AABA/YHOO
    BFX 2020-04-22 twin positions: BFX/NLS
    DOC 2012-01-03 twin positions: DOC/HCP_old
    AORT 2016-08-11 twin positions: AORT/CRY_old
    BB 2006-09-29 twin positions: BB/BBRY
    AZN 2019-03-11 twin positions: AZN/AZN_old
V7 INVARIANT 66 violations
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
V9 EXPECTATION 102 violations (228 skipped)
    ZQKSQ 2004-05-12 prior_top=11.62 within +25% of entry=10.02
    WTRG 2025-10-20 prior_top=46.23 within +25% of entry=42.04
    WAB 2023-07-08 prior_top=109.26 within +25% of entry=108.45
    VSH 2023-09-07 prior_top=27.66 within +25% of entry=25.09
    VSAT 2019-03-15 prior_top=81.15 within +25% of entry=76.80
    VRX1 2009-06-24 prior_top=26.54 within +25% of entry=24.83
    VICR 2021-07-03 prior_top=107.97 within +25% of entry=107.30
    URBN 2025-03-13 prior_top=58.19 within +25% of entry=50.12
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TLB 2004-06-07 prior_top=42.90 within +25% of entry=38.89
V10 EXPECTATION 10 violations (228 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    RDN 2009-08-06 entry_wk_close=5.51 > prior=1.50 (spike>60%)
    NLS 2020-04-22 entry_wk_close=6.49 > prior=2.80 (spike>60%)
    CYBX 2005-02-04 entry_wk_close=39.78 > prior=20.88 (spike>60%)
    CLPA 2000-01-31 entry_wk_close=25.25 > prior=12.12 (spike>60%)
    CLFD 2026-05-26 entry_wk_close=47.22 > prior=29.43 (spike>60%)
    BPT 2022-01-22 entry_wk_close=5.52 > prior=2.85 (spike>60%)
    BFX 2020-04-22 entry_wk_close=6.49 > prior=2.80 (spike>60%)
    BB 2021-01-20 entry_wk_close=14.04 > prior=7.06 (spike>60%)
    APWR 2000-01-24 entry_wk_close=15.33 > prior=9.33 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 21 violations
    WFM 2013-05-18 installed_stop=89.8750 vs fill=51.3400 -> dist=0.7506 > gate=0.1500
    URBN 2003-06-05 installed_stop=32.9308 vs fill=18.7500 -> dist=0.7563 > gate=0.1500
    TRN 2013-10-31 installed_stop=31.6477 vs fill=17.3100 -> dist=0.8283 > gate=0.1500
    TIN 2005-02-04 installed_stop=27.9938 vs fill=16.0900 -> dist=0.7398 > gate=0.1500
    SGP_old1 2010-05-10 installed_stop=8.8750 vs fill=10.5500 -> dist=0.1588 > gate=0.1500
    RAD 2015-03-27 installed_stop=7.3750 vs fill=8.7300 -> dist=0.1552 > gate=0.1500
    PDLI 2003-05-19 installed_stop=12.3750 vs fill=14.6000 -> dist=0.1524 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.8000 -> dist=0.1529 > gate=0.1500
    LSCC 2013-11-18 installed_stop=4.8750 vs fill=5.7500 -> dist=0.1522 > gate=0.1500
    HGSI 2011-11-17 installed_stop=6.8750 vs fill=8.2000 -> dist=0.1616 > gate=0.1500
V13 INVARIANT 147 violations (8 skipped)
    WMB 2024-03-23 no bar on entry_date 2024-03-23 (nearest earlier bar: 2024-03-22)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WFM 2013-05-18 no bar on entry_date 2013-05-18 (nearest earlier bar: 2013-05-17)
    WBS 2011-01-22 no bar on entry_date 2011-01-22 (nearest earlier bar: 2011-01-21)
    WAB 2023-07-08 no bar on entry_date 2023-07-08 (nearest earlier bar: 2023-07-07)
    VYX 2015-06-16 entry_price=36.5000 outside 2015-06-16 bar [31.2699, 36.4999]
    VICR 2021-07-03 no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)
    URBN 2025-12-20 no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)
    UFPI 2013-06-22 no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)
    TXNM 2020-02-01 no bar on entry_date 2020-02-01 (nearest earlier bar: 2020-01-31)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
