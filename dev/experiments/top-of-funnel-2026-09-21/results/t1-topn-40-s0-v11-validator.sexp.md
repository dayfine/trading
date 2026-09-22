# Post-run validation report

Invariant checks failing: 3
audit join: 771/771 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 110 violations
    ZS 2020-05-29 Virgin_territory but only 117 weekly bars (< 520) before entry
    XPOF 2023-01-27 Virgin_territory but only 79 weekly bars (< 520) before entry
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    WING 2017-08-08 Virgin_territory but only 113 weekly bars (< 520) before entry
    VOYA 2017-11-29 Virgin_territory but only 241 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
    UTHR 2002-11-21 Virgin_territory but only 180 weekly bars (< 520) before entry
    USNA 2005-02-01 Virgin_territory but only 502 weekly bars (< 520) before entry
    UNVR 2022-03-15 Virgin_territory but only 354 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 94 violations (241 skipped)
    ZGN 2023-09-08 prior_top=15.43 within +25% of entry=14.25
    XLRN 2018-07-23 prior_top=51.43 within +25% of entry=47.46
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.75
    WRLD 2010-03-12 prior_top=49.25 within +25% of entry=43.75
    URBN 2025-03-13 prior_top=58.19 within +25% of entry=50.12
    UNVR 2022-03-15 prior_top=32.43 within +25% of entry=32.15
    UMAC 2026-01-15 prior_top=18.73 within +25% of entry=17.69
    UHS 2018-08-22 prior_top=138.68 within +25% of entry=128.80
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    STVN 2023-03-02 prior_top=28.27 within +25% of entry=23.43
V10 EXPECTATION 10 violations (241 skipped)
    ISEE 2022-09-30 entry_wk_close=17.94 > prior=9.44 (spike>60%)
    IPSU 2011-06-02 entry_wk_close=21.47 > prior=12.99 (spike>60%)
    GSIT 2025-10-20 entry_wk_close=9.23 > prior=3.84 (spike>60%)
    GRPN 2025-03-26 entry_wk_close=18.82 > prior=11.12 (spike>60%)
    EXK 2020-07-20 entry_wk_close=4.20 > prior=2.14 (spike>60%)
    EOSE 2023-06-27 entry_wk_close=4.34 > prior=2.43 (spike>60%)
    CLPA 2000-01-31 entry_wk_close=25.25 > prior=12.12 (spike>60%)
    CBMC 2000-03-06 entry_wk_close=191.25 > prior=71.25 (spike>60%)
    BLNK 2020-07-29 entry_wk_close=11.05 > prior=5.28 (spike>60%)
    ARXX 2000-02-07 entry_wk_close=11.95 > prior=4.95 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 24 violations
    VOYA 2017-11-29 installed_stop=36.7008 vs fill=43.5100 -> dist=0.1565 > gate=0.1500
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.3100 -> dist=0.9045 > gate=0.1500
    PGNY 2021-04-26 installed_stop=45.7536 vs fill=53.8700 -> dist=0.1507 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.8000 -> dist=0.1529 > gate=0.1500
    MNRO 2010-07-30 installed_stop=39.1488 vs fill=27.1900 -> dist=0.4398 > gate=0.1500
    MCK 2020-05-28 installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500
    LPG 2023-09-15 installed_stop=23.2022 vs fill=27.3000 -> dist=0.1501 > gate=0.1500
    GRA 2016-01-22 installed_stop=73.1724 vs fill=86.3000 -> dist=0.1521 > gate=0.1500
    GGG 2000-11-16 installed_stop=31.7399 vs fill=24.3300 -> dist=0.3046 > gate=0.1500
    FULT 2002-03-07 installed_stop=23.3952 vs fill=19.5000 -> dist=0.1998 > gate=0.1500
V13 INVARIANT 141 violations (4 skipped)
    ZWS 2018-10-06 no bar on entry_date 2018-10-06 (nearest earlier bar: 2018-10-05)
    WSO 2010-03-06 no bar on entry_date 2010-03-06 (nearest earlier bar: 2010-03-05)
    WPM 2024-04-20 no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WING 2017-08-08 entry_price=31.6500 outside 2017-08-08 bar [32.7300, 34.1600]
    WBS 2011-01-22 no bar on entry_date 2011-01-22 (nearest earlier bar: 2011-01-21)
    WAFD 2013-06-29 no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)
    VMC 2012-10-06 no bar on entry_date 2012-10-06 (nearest earlier bar: 2012-10-05)
    VIRT 2021-03-13 no bar on entry_date 2021-03-13 (nearest earlier bar: 2021-03-12)
    URBN 2025-12-20 no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 12 violations
    BLNK 2020-07-29 median close 1.61 over 4078 bars (2008-07-15..2026-06-08); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0
    BOKF 2003-06-04 median close 49.73 over 8751 bars (1991-09-05..2026-06-08); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    BRK-A 2006-05-18 median close 83000.00 over 11225 bars (1980-03-17..2026-06-08), above the 10000.00 ceiling
    CIR 2013-04-24 median close 32.28 over 6046 bars (1999-10-18..2023-11-16); bar 2023-11-06 close 0.00 (-100.00% vs prior close 56.00) on volume 0
    FLO 2020-03-09 median close 18.19 over 11651 bars (1980-03-17..2026-06-08); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    IHG 2024-10-15 median close 37.37 over 5828 bars (2003-04-08..2026-06-08); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0
    IOVA 2020-03-24 median close 7.47 over 3934 bars (2010-10-15..2026-06-08); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0
    ISA 2019-03-14 median close 7360.00 over 5664 bars (1997-12-31..2020-07-07); bar 2001-08-22 close 0.05 (-100.00% vs prior close 1070.00) on volume 0
    NOKBF 2025-10-28 median close 5.96 over 4467 bars (2001-07-11..2026-06-08); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0
    NPPXF 2014-02-12 median close 41.56 over 4371 bars (2002-12-23..2026-06-08); bar 2009-02-13 close 48.23 (-100.00% vs prior close 1000000.00) on volume 0
