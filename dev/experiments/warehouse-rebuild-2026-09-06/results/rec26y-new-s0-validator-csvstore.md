# Post-run validation report

Invariant checks failing: 3
audit join: 715/715 rows matched

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
    RDA1 2005-02-02 Virgin_territory but only 374 weekly bars (< 520) before entry
    PLFE 2005-10-20 Virgin_territory but only 411 weekly bars (< 520) before entry
    PLCE 2004-11-10 Virgin_territory but only 377 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 85 violations (230 skipped)
    XL_old 2015-01-10 prior_top=35.88 within +25% of entry=35.73
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.75
    WTRG 2025-10-20 prior_top=46.23 within +25% of entry=42.04
    WAB 2023-07-08 prior_top=109.26 within +25% of entry=108.45
    VSAT 2017-12-29 prior_top=81.15 within +25% of entry=75.32
    VRTX 2014-06-28 prior_top=93.77 within +25% of entry=92.22
    VRTX 2019-11-09 prior_top=201.31 within +25% of entry=197.08
    VICR 2021-07-03 prior_top=107.97 within +25% of entry=107.30
    URBN 2026-01-06 prior_top=81.84 within +25% of entry=81.27
    UHS 2018-11-19 prior_top=138.68 within +25% of entry=133.32
V10 EXPECTATION 9 violations (230 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    RDN 2009-08-06 entry_wk_close=5.51 > prior=1.50 (spike>60%)
    RBAK 2006-12-23 entry_wk_close=24.94 > prior=14.52 (spike>60%)
    GERN 2012-09-01 entry_wk_close=2.74 > prior=1.61 (spike>60%)
    CYBX 2005-02-04 entry_wk_close=39.78 > prior=20.88 (spike>60%)
    CLFD 2026-05-26 entry_wk_close=47.22 > prior=29.43 (spike>60%)
    BPT 2022-01-22 entry_wk_close=5.52 > prior=2.85 (spike>60%)
    BLDP 2026-05-16 entry_wk_close=5.54 > prior=3.28 (spike>60%)
    APWR 2000-01-24 entry_wk_close=15.33 > prior=9.33 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 16 violations
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.3100 -> dist=0.9045 > gate=0.1500
    TRMB 2003-11-24 installed_stop=25.8750 vs fill=19.6700 -> dist=0.3155 > gate=0.1500
    PH 2007-04-04 installed_stop=77.1361 vs fill=58.9800 -> dist=0.3078 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.4700 -> dist=0.1602 > gate=0.1500
    MNT 2005-04-15 installed_stop=31.3920 vs fill=37.4500 -> dist=0.1618 > gate=0.1500
    MMM 2003-07-26 installed_stop=131.9328 vs fill=69.6800 -> dist=0.8934 > gate=0.1500
    MCK 2020-05-28 installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500
    LRCX 2014-05-03 installed_stop=48.3750 vs fill=57.2000 -> dist=0.1543 > gate=0.1500
    KOPN 2025-07-17 installed_stop=1.8750 vs fill=2.2200 -> dist=0.1554 > gate=0.1500
    FULT 2002-03-07 installed_stop=23.3952 vs fill=19.5000 -> dist=0.1998 > gate=0.1500
V13 INVARIANT 161 violations (5 skipped)
    XL_old 2015-01-10 no bar on entry_date 2015-01-10 (nearest earlier bar: 2015-01-09)
    WNC 2024-03-09 no bar on entry_date 2024-03-09 (nearest earlier bar: 2024-03-08)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WAFD 2013-06-29 no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)
    WAB 2023-07-08 no bar on entry_date 2023-07-08 (nearest earlier bar: 2023-07-07)
    VRTX 2014-06-28 no bar on entry_date 2014-06-28 (nearest earlier bar: 2014-06-27)
    VRTX 2019-11-09 no bar on entry_date 2019-11-09 (nearest earlier bar: 2019-11-08)
    VICR 2021-07-03 no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)
    URBN 2025-12-20 no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)
    UFPI 2013-06-22 no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION 3 violations
    FII 2020-03-28 entry filled 2020-03-28 but last bar is 2020-01-31 (57 days stale)
    FII 2020-04-04 entry filled 2020-04-04 but last bar is 2020-01-31 (64 days stale)
    CY 2020-04-25 entry filled 2020-04-25 but last bar is 2020-04-15 (10 days stale)
