# Post-run validation report

Invariant checks failing: 3
audit join: 794/794 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 62 violations
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    UTHR 2002-11-21 Virgin_territory but only 180 weekly bars (< 520) before entry
    URBN 2003-06-05 Virgin_territory but only 503 weekly bars (< 520) before entry
    UHAL 2003-09-12 Virgin_territory but only 466 weekly bars (< 520) before entry
    TLB 2004-06-07 Virgin_territory but only 340 weekly bars (< 520) before entry
    TFSM 2003-06-02 Virgin_territory but only 232 weekly bars (< 520) before entry
    TBI1 2000-04-28 Virgin_territory but only 68 weekly bars (< 520) before entry
    STLD 2003-12-01 Virgin_territory but only 371 weekly bars (< 520) before entry
    SRCL 2005-06-13 Virgin_territory but only 465 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 99 violations (242 skipped)
    ZQKSQ 2004-05-12 prior_top=11.62 within +25% of entry=10.02
    WTRG 2025-10-20 prior_top=46.23 within +25% of entry=42.04
    VSH 2023-09-07 prior_top=27.66 within +25% of entry=25.09
    VSAT 2017-12-29 prior_top=81.15 within +25% of entry=75.32
    VSAT 2019-03-15 prior_top=81.15 within +25% of entry=76.80
    VRX1 2009-06-24 prior_top=26.54 within +25% of entry=24.83
    VRTX 2014-07-30 prior_top=99.07 within +25% of entry=91.61
    VICR 2021-07-03 prior_top=107.97 within +25% of entry=107.30
    USB 2024-08-28 prior_top=51.66 within +25% of entry=46.10
    URBN 2025-03-13 prior_top=58.19 within +25% of entry=50.12
V10 EXPECTATION 8 violations (242 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    RDN 2009-08-06 entry_wk_close=5.51 > prior=1.50 (spike>60%)
    RBAK 2006-12-23 entry_wk_close=24.94 > prior=14.52 (spike>60%)
    CLPA 2000-01-31 entry_wk_close=25.25 > prior=12.12 (spike>60%)
    CLFD 2026-05-26 entry_wk_close=47.22 > prior=29.43 (spike>60%)
    BPT 2022-01-22 entry_wk_close=5.52 > prior=2.85 (spike>60%)
    BFX 2020-04-22 entry_wk_close=6.49 > prior=2.80 (spike>60%)
    APWR 2000-01-24 entry_wk_close=15.33 > prior=9.33 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 24 violations
    URBN 2003-06-05 installed_stop=32.9308 vs fill=18.7500 -> dist=0.7563 > gate=0.1500
    TRN 2013-10-31 installed_stop=31.6477 vs fill=17.3100 -> dist=0.8283 > gate=0.1500
    TIN 2005-02-04 installed_stop=27.9938 vs fill=16.0900 -> dist=0.7398 > gate=0.1500
    SGP_old1 2010-05-10 installed_stop=8.8750 vs fill=10.5500 -> dist=0.1588 > gate=0.1500
    PDLI 2003-05-19 installed_stop=12.3750 vs fill=14.6000 -> dist=0.1524 > gate=0.1500
    OSPN 2022-09-15 installed_stop=7.8750 vs fill=9.2800 -> dist=0.1514 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.8000 -> dist=0.1529 > gate=0.1500
    LSCC 2014-02-13 installed_stop=6.3750 vs fill=7.5700 -> dist=0.1579 > gate=0.1500
    KYOCY 2023-12-29 installed_stop=51.3763 vs fill=14.6300 -> dist=2.5117 > gate=0.1500
    HQH 2013-06-29 installed_stop=18.9600 vs fill=22.7400 -> dist=0.1662 > gate=0.1500
V13 INVARIANT 148 violations (7 skipped)
    YUM 2022-01-01 no bar on entry_date 2022-01-01 (nearest earlier bar: 2021-12-31)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WAFD 2013-06-29 no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)
    VICR 2021-07-03 no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)
    URBN 2025-12-20 no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)
    UFPI 2013-06-22 no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)
    TWX1 2000-01-28 exit_price=76.5600 outside 2000-02-23 bar [76.5630, 82.0000]
    TTWO 2015-07-17 entry_price=31.3200 outside 2015-07-17 bar [29.9300, 31.3199]
    TTE 2021-10-16 no bar on entry_date 2021-10-16 (nearest earlier bar: 2021-10-15)
    TRV 2025-05-10 no bar on entry_date 2025-05-10 (nearest earlier bar: 2025-05-09)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
