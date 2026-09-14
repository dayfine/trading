# Post-run validation report

Invariant checks failing: 3
audit join: 505/505 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 21 violations
    RDA1 2005-02-02 Virgin_territory but only 374 weekly bars (< 520) before entry
    NHYDY 2002-03-14 Virgin_territory but only 221 weekly bars (< 520) before entry
    MNT 2005-04-15 Virgin_territory but only 384 weekly bars (< 520) before entry
    HSII 2006-10-12 Virgin_territory but only 392 weekly bars (< 520) before entry
    GIFI 2006-11-01 Virgin_territory but only 465 weekly bars (< 520) before entry
    GAS1 2007-04-04 Virgin_territory but only 487 weekly bars (< 520) before entry
    DOX 2006-01-18 Virgin_territory but only 399 weekly bars (< 520) before entry
    CPT 2000-04-12 Virgin_territory but only 353 weekly bars (< 520) before entry
    COGN 2004-06-29 Virgin_territory but only 289 weekly bars (< 520) before entry
    CNI 2003-08-12 Virgin_territory but only 408 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 53 violations (153 skipped)
    VICR 2021-07-03 prior_top=107.97 within +25% of entry=107.30
    URBN 2026-01-06 prior_top=81.84 within +25% of entry=81.11
    UHS 2018-08-22 prior_top=138.68 within +25% of entry=128.79
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TKO 2017-03-23 prior_top=25.14 within +25% of entry=21.66
    TGT 2020-03-12 prior_top=107.27 within +25% of entry=92.66
    TDY 2007-05-12 prior_top=46.50 within +25% of entry=45.71
    TBI 2018-08-21 prior_top=31.21 within +25% of entry=29.69
    STE 2025-11-22 prior_top=261.84 within +25% of entry=257.13
    SKYW 2013-11-19 prior_top=16.83 within +25% of entry=16.40
V10 EXPECTATION 7 violations (153 skipped)
    RBAK 2006-12-23 entry_wk_close=24.94 > prior=14.52 (spike>60%)
    MVL 2002-03-08 entry_wk_close=5.33 > prior=3.00 (spike>60%)
    GERN 2012-09-01 entry_wk_close=2.74 > prior=1.61 (spike>60%)
    ENCO 2009-09-30 entry_wk_close=3.76 > prior=1.52 (spike>60%)
    CLPA 2000-01-31 entry_wk_close=25.25 > prior=12.12 (spike>60%)
    BPT 2022-01-22 entry_wk_close=5.52 > prior=2.85 (spike>60%)
    APWR 2000-01-24 entry_wk_close=15.33 > prior=9.33 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 16 violations
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.1800 -> dist=0.9189 > gate=0.1500
    TRMB 2003-11-24 installed_stop=25.8750 vs fill=19.7100 -> dist=0.3128 > gate=0.1500
    OSK 2003-08-09 installed_stop=63.8750 vs fill=33.7400 -> dist=0.8932 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.5300 -> dist=0.1589 > gate=0.1500
    MNT 2005-04-15 installed_stop=31.3920 vs fill=37.4500 -> dist=0.1618 > gate=0.1500
    MEI 2014-09-04 installed_stop=32.4096 vs fill=38.4700 -> dist=0.1575 > gate=0.1500
    MCK 2020-05-28 installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500
    LGTY 2020-04-29 installed_stop=14.7984 vs fill=17.5400 -> dist=0.1563 > gate=0.1500
    GAS1 2007-04-04 installed_stop=42.6816 vs fill=50.2400 -> dist=0.1504 > gate=0.1500
    FULT 2002-03-07 installed_stop=23.3952 vs fill=19.5000 -> dist=0.1998 > gate=0.1500
V13 INVARIANT 120 violations (4 skipped)
    WAFD 2013-06-29 no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)
    VICR 2021-07-03 no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)
    URBN 2025-12-20 no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)
    UN 2017-03-11 no bar on entry_date 2017-03-11 (nearest earlier bar: 2017-03-10)
    UFPI 2013-06-22 no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)
    TWX1 2000-01-28 exit_price=76.5600 outside 2000-02-23 bar [76.5630, 82.0000]
    TRV 2025-05-10 no bar on entry_date 2025-05-10 (nearest earlier bar: 2025-05-09)
    TK 2023-11-04 no bar on entry_date 2023-11-04 (nearest earlier bar: 2023-11-03)
    TDY 2007-05-12 no bar on entry_date 2007-05-12 (nearest earlier bar: 2007-05-11)
    TDS 2023-08-26 no bar on entry_date 2023-08-26 (nearest earlier bar: 2023-08-25)
V14 EXPECTATION PASS (1 skipped)
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 5 violations
    ARJ 2005-12-29 median close 0.16 over 4552 bars (1999-02-09..2017-03-13); bar 2010-01-29 close 0.13 (-99.55% vs prior close 28.25) on volume 0
    BRK-A 2018-09-19 median close 83000.00 over 11224 bars (1980-03-17..2026-06-05), above the 10000.00 ceiling
    CLE 2014-11-18 median close 19.00 over 4813 bars (1997-12-31..2018-06-28); bar 2014-06-09 close 0.07 (-94.53% vs prior close 1.28) on volume 0
    FLO 2020-03-09 median close 18.20 over 11650 bars (1980-03-17..2026-06-05); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    MVL 2002-03-08 median close 9.00 over 4795 bars (1999-01-04..2018-01-24); bar 2010-01-26 close 60.00 (+96.88% vs prior close 30.48) on volume 0
