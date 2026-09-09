# Post-run validation report

Invariant checks failing: 3
audit join: 710/710 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 51 violations
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
V9 EXPECTATION 86 violations (236 skipped)
    WTRG 2025-10-20 prior_top=46.23 within +25% of entry=42.04
    VSH 2023-09-07 prior_top=27.66 within +25% of entry=25.09
    VICR 2021-07-03 prior_top=107.97 within +25% of entry=107.30
    UHS 2018-11-19 prior_top=138.68 within +25% of entry=133.32
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TTWO 2020-05-19 prior_top=137.99 within +25% of entry=136.42
    TLB 2004-06-07 prior_top=42.90 within +25% of entry=38.89
    TKR 2023-01-26 prior_top=83.40 within +25% of entry=79.80
    THO 2021-02-13 prior_top=130.65 within +25% of entry=123.01
    TGT 2020-03-12 prior_top=107.27 within +25% of entry=92.66
V10 EXPECTATION 9 violations (236 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    SSP 2025-11-18 entry_wk_close=3.10 > prior=1.77 (spike>60%)
    RDN 2009-08-06 entry_wk_close=5.51 > prior=1.50 (spike>60%)
    RBAK 2006-12-23 entry_wk_close=24.94 > prior=14.52 (spike>60%)
    GERN 2012-09-01 entry_wk_close=2.74 > prior=1.61 (spike>60%)
    DDD 2021-01-19 entry_wk_close=34.48 > prior=11.55 (spike>60%)
    BLDP 2026-05-16 entry_wk_close=5.54 > prior=3.28 (spike>60%)
    BFX 2020-04-22 entry_wk_close=6.49 > prior=2.80 (spike>60%)
    APWR 2000-01-24 entry_wk_close=15.33 > prior=9.33 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 23 violations
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.3100 -> dist=0.9045 > gate=0.1500
    TRMB 2003-11-24 installed_stop=25.8750 vs fill=19.6700 -> dist=0.3155 > gate=0.1500
    TIN 2005-02-04 installed_stop=30.3750 vs fill=16.0900 -> dist=0.8878 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.8000 -> dist=0.1529 > gate=0.1500
    MMM 2003-07-26 installed_stop=131.9328 vs fill=69.6800 -> dist=0.8934 > gate=0.1500
    MCK 2020-05-28 installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500
    LRCX 2014-05-03 installed_stop=48.3750 vs fill=57.2000 -> dist=0.1543 > gate=0.1500
    LINK 2025-09-23 installed_stop=9.3697 vs fill=11.0900 -> dist=0.1551 > gate=0.1500
    L 2025-05-08 installed_stop=75.8208 vs fill=89.3900 -> dist=0.1518 > gate=0.1500
    KOPN 2025-07-17 installed_stop=1.8750 vs fill=2.2200 -> dist=0.1554 > gate=0.1500
V13 INVARIANT 155 violations (9 skipped)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WERN 2009-12-12 no bar on entry_date 2009-12-12 (nearest earlier bar: 2009-12-11)
    WDC 2012-08-18 no bar on entry_date 2012-08-18 (nearest earlier bar: 2012-08-17)
    WAVX 2014-05-31 no bar on entry_date 2014-05-31 (nearest earlier bar: 2014-05-30)
    WAFD 2013-06-29 no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)
    VYX 2015-06-16 entry_price=36.5000 outside 2015-06-16 bar [31.2699, 36.4999]
    VICR 2021-07-03 no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)
    UN 2017-03-11 no bar on entry_date 2017-03-11 (nearest earlier bar: 2017-03-10)
    UFPI 2013-06-22 no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)
    TWX1 2000-01-28 exit_price=76.5600 outside 2000-02-23 bar [76.5630, 82.0000]
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
