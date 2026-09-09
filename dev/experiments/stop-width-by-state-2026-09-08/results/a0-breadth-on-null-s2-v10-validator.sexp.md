# Post-run validation report

Invariant checks failing: 3
audit join: 728/728 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 54 violations
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    UTHR 2002-11-21 Virgin_territory but only 180 weekly bars (< 520) before entry
    TLB 2004-06-07 Virgin_territory but only 340 weekly bars (< 520) before entry
    TBI1 2000-04-28 Virgin_territory but only 68 weekly bars (< 520) before entry
    SVM1 2005-10-10 Virgin_territory but only 410 weekly bars (< 520) before entry
    SRCL 2005-06-13 Virgin_territory but only 465 weekly bars (< 520) before entry
    RVSN_old 2005-11-01 Virgin_territory but only 297 weekly bars (< 520) before entry
    RDA1 2005-02-02 Virgin_territory but only 374 weekly bars (< 520) before entry
    RAH 2006-08-10 Virgin_territory but only 453 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 95 violations (233 skipped)
    WAB 2023-07-08 prior_top=109.26 within +25% of entry=108.41
    VRTX 2014-06-28 prior_top=93.77 within +25% of entry=92.22
    VICR 2021-07-03 prior_top=107.97 within +25% of entry=107.30
    UHS 2018-11-19 prior_top=138.68 within +25% of entry=133.31
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TLB 2004-06-07 prior_top=42.90 within +25% of entry=38.84
    TKO 2017-03-23 prior_top=25.14 within +25% of entry=21.66
    THO 2021-02-13 prior_top=130.65 within +25% of entry=123.01
    TGT 2020-03-12 prior_top=107.27 within +25% of entry=92.66
    TER 2019-08-05 prior_top=54.73 within +25% of entry=51.85
V10 EXPECTATION 7 violations (233 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    RDN 2009-08-06 entry_wk_close=5.51 > prior=1.50 (spike>60%)
    RBAK 2006-12-23 entry_wk_close=24.94 > prior=14.52 (spike>60%)
    CLFD 2026-05-26 entry_wk_close=47.22 > prior=29.43 (spike>60%)
    BPT 2022-01-22 entry_wk_close=5.52 > prior=2.85 (spike>60%)
    BFX 2020-04-22 entry_wk_close=6.49 > prior=2.80 (spike>60%)
    APWR 2000-01-24 entry_wk_close=15.33 > prior=9.33 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 20 violations
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.1800 -> dist=0.9189 > gate=0.1500
    TRMB 2003-11-24 installed_stop=25.8750 vs fill=19.7100 -> dist=0.3128 > gate=0.1500
    TIN 2005-02-04 installed_stop=30.3750 vs fill=16.0900 -> dist=0.8878 > gate=0.1500
    ORLY 2025-01-27 installed_stop=1127.3750 vs fill=84.4300 -> dist=12.3528 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.5300 -> dist=0.1589 > gate=0.1500
    MMM 2003-07-26 installed_stop=131.9328 vs fill=69.6800 -> dist=0.8934 > gate=0.1500
    LGTY 2020-04-29 installed_stop=14.7984 vs fill=17.5400 -> dist=0.1563 > gate=0.1500
    GRA 2016-01-22 installed_stop=73.1724 vs fill=86.3000 -> dist=0.1521 > gate=0.1500
    GAS1 2007-04-04 installed_stop=42.6816 vs fill=50.2400 -> dist=0.1504 > gate=0.1500
    FULT 2002-03-07 installed_stop=23.3952 vs fill=19.5000 -> dist=0.1998 > gate=0.1500
V13 INVARIANT 166 violations (10 skipped)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WERN 2009-12-12 no bar on entry_date 2009-12-12 (nearest earlier bar: 2009-12-11)
    WDC 2012-08-18 no bar on entry_date 2012-08-18 (nearest earlier bar: 2012-08-17)
    WBS 2011-01-22 no bar on entry_date 2011-01-22 (nearest earlier bar: 2011-01-21)
    WAVX 2014-05-31 no bar on entry_date 2014-05-31 (nearest earlier bar: 2014-05-30)
    WAFD 2013-06-29 no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)
    WAB 2023-07-08 no bar on entry_date 2023-07-08 (nearest earlier bar: 2023-07-07)
    VRTX 2014-06-28 no bar on entry_date 2014-06-28 (nearest earlier bar: 2014-06-27)
    VICR 2021-07-03 no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)
    UN 2017-03-11 no bar on entry_date 2017-03-11 (nearest earlier bar: 2017-03-10)
V14 EXPECTATION PASS (1 skipped)
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
