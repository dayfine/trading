# Post-run validation report

Invariant checks failing: 3
audit join: 748/748 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 107 violations
    ZS 2020-05-29 Virgin_territory but only 117 weekly bars (< 520) before entry
    XPOF 2023-01-27 Virgin_territory but only 79 weekly bars (< 520) before entry
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    VOYA 2017-11-29 Virgin_territory but only 241 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    VICI 2019-10-16 Virgin_territory but only 105 weekly bars (< 520) before entry
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
    UTHR 2002-11-21 Virgin_territory but only 180 weekly bars (< 520) before entry
    USNA 2005-02-01 Virgin_territory but only 502 weekly bars (< 520) before entry
    UNVR 2022-03-15 Virgin_territory but only 354 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 86 violations (255 skipped)
    ZGN 2023-09-08 prior_top=15.43 within +25% of entry=14.25
    WRLD 2010-03-12 prior_top=49.25 within +25% of entry=43.75
    WLY 2021-02-05 prior_top=52.55 within +25% of entry=50.09
    UNVR 2022-03-15 prior_top=32.43 within +25% of entry=32.37
    UMAC 2026-01-15 prior_top=18.73 within +25% of entry=17.59
    UHS 2018-08-22 prior_top=138.68 within +25% of entry=128.84
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TKO 2017-03-23 prior_top=25.14 within +25% of entry=21.77
    TEF 2024-04-29 prior_top=5.02 within +25% of entry=4.55
    SKYW 2013-11-23 prior_top=16.83 within +25% of entry=16.41
V10 EXPECTATION 14 violations (255 skipped)
    WBTN 2025-08-30 entry_wk_close=14.41 > prior=8.92 (spike>60%)
    VLN 2026-05-16 entry_wk_close=3.22 > prior=1.79 (spike>60%)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    PYX 2018-10-08 entry_wk_close=43.05 > prior=18.60 (spike>60%)
    OKLO 2024-10-26 entry_wk_close=21.67 > prior=11.19 (spike>60%)
    IPSU 2011-06-02 entry_wk_close=21.47 > prior=12.99 (spike>60%)
    GRPN 2025-03-26 entry_wk_close=18.82 > prior=11.12 (spike>60%)
    EXK 2020-07-20 entry_wk_close=4.20 > prior=2.14 (spike>60%)
    EOSE 2023-06-28 entry_wk_close=4.34 > prior=2.43 (spike>60%)
    ECHO 2025-08-26 entry_wk_close=61.79 > prior=26.93 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 19 violations
    VOYA 2017-11-29 installed_stop=36.7008 vs fill=43.5100 -> dist=0.1565 > gate=0.1500
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.1800 -> dist=0.9189 > gate=0.1500
    MNRO 2010-07-30 installed_stop=39.1488 vs fill=27.2100 -> dist=0.4388 > gate=0.1500
    MCK 2020-05-28 installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500
    GRA 2016-01-22 installed_stop=73.1724 vs fill=86.3000 -> dist=0.1521 > gate=0.1500
    GGG 2000-11-16 installed_stop=31.7399 vs fill=24.2600 -> dist=0.3083 > gate=0.1500
    FULT 2002-03-07 installed_stop=23.3952 vs fill=19.5000 -> dist=0.1998 > gate=0.1500
    ESI 2021-04-24 installed_stop=16.7424 vs fill=19.8900 -> dist=0.1583 > gate=0.1500
    EOG 2000-05-01 installed_stop=21.9602 vs fill=25.8500 -> dist=0.1505 > gate=0.1500
    ENB 2004-10-29 installed_stop=36.2112 vs fill=21.2700 -> dist=0.7025 > gate=0.1500
V13 INVARIANT 147 violations (4 skipped)
    ZWS 2018-10-06 no bar on entry_date 2018-10-06 (nearest earlier bar: 2018-10-05)
    WTTR 2024-03-16 no bar on entry_date 2024-03-16 (nearest earlier bar: 2024-03-15)
    WSO 2010-03-06 no bar on entry_date 2010-03-06 (nearest earlier bar: 2010-03-05)
    WPM 2024-04-20 no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WBTN 2025-08-30 no bar on entry_date 2025-08-30 (nearest earlier bar: 2025-08-29)
    WBS 2011-01-22 no bar on entry_date 2011-01-22 (nearest earlier bar: 2011-01-21)
    WAFD 2013-06-29 no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)
    VVC 2018-04-28 no bar on entry_date 2018-04-28 (nearest earlier bar: 2018-04-27)
    VMC 2012-10-06 no bar on entry_date 2012-10-06 (nearest earlier bar: 2012-10-05)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 17 violations
    ANIP 2024-03-02 median close 25.97 over 6151 bars (2001-07-24..2026-06-10); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    ATLKY 2026-01-15 median close 24.88 over 7437 bars (1996-11-18..2026-06-10); bar 2003-09-01 close 1000000.00 (+3311246.00% vs prior close 30.20) on volume 0
    BHRB 2022-09-20 median close 2015.05 over 5914 bars (1995-08-04..2026-06-10); bar 2003-10-07 close 2001.00 (-99.80% vs prior close 1000000.00) on volume 0
    BLNK 2020-07-29 median close 1.61 over 4080 bars (2008-07-15..2026-06-10); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0
    BOKF 2003-06-04 median close 49.75 over 8753 bars (1991-09-05..2026-06-10); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    BRK-A 2006-05-18 median close 83000.00 over 11227 bars (1980-03-17..2026-06-10), above the 10000.00 ceiling
    CIR 2013-04-24 median close 32.28 over 6046 bars (1999-10-18..2023-11-16); bar 2023-11-06 close 0.00 (-100.00% vs prior close 56.00) on volume 0
    CYRX 2020-05-18 median close 2.91 over 5233 bars (2005-08-22..2026-06-10); bar 2010-02-05 close 9.30 (+900.00% vs prior close 0.93) on volume 0
    FLO 2020-03-09 median close 18.19 over 11653 bars (1980-03-17..2026-06-10); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    IHG 2024-10-15 median close 37.40 over 5830 bars (2003-04-08..2026-06-10); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0
