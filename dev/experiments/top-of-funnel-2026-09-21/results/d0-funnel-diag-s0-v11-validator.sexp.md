# Post-run validation report

Invariant checks failing: 3
audit join: 732/732 rows matched

QUALITY-FLAG: 2 fallback exits (V16)

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 110 violations
    ZS 2020-05-29 Virgin_territory but only 117 weekly bars (< 520) before entry
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    WING 2017-08-08 Virgin_territory but only 113 weekly bars (< 520) before entry
    VOYA 2017-11-29 Virgin_territory but only 241 weekly bars (< 520) before entry
    VNA 2015-02-05 Virgin_territory but only 258 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    VICI 2019-10-16 Virgin_territory but only 105 weekly bars (< 520) before entry
    VERI 2020-06-02 Virgin_territory but only 162 weekly bars (< 520) before entry
    VC 2015-05-22 Virgin_territory but only 245 weekly bars (< 520) before entry
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 88 violations (239 skipped)
    ZGN 2023-09-08 prior_top=15.43 within +25% of entry=14.25
    XLRN 2018-07-23 prior_top=51.43 within +25% of entry=47.46
    WRLD 2010-03-12 prior_top=49.25 within +25% of entry=43.75
    WIX 2021-04-28 prior_top=353.09 within +25% of entry=321.01
    UNVR 2022-03-15 prior_top=32.43 within +25% of entry=32.15
    UHS 2018-08-22 prior_top=138.68 within +25% of entry=128.80
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TTWO 2020-05-19 prior_top=137.99 within +25% of entry=136.42
    TNM 2017-04-11 prior_top=765.00 within +25% of entry=763.00
    STVN 2023-03-02 prior_top=28.27 within +25% of entry=23.43
V10 EXPECTATION 17 violations (239 skipped)
    VUZI 2026-05-29 entry_wk_close=4.60 > prior=2.84 (spike>60%)
    VLN 2026-05-16 entry_wk_close=3.22 > prior=1.79 (spike>60%)
    VERI 2020-06-02 entry_wk_close=11.16 > prior=5.93 (spike>60%)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    PYX 2018-10-08 entry_wk_close=43.05 > prior=18.60 (spike>60%)
    MVL 2002-03-08 entry_wk_close=5.33 > prior=3.00 (spike>60%)
    ISEE 2022-09-30 entry_wk_close=17.94 > prior=9.44 (spike>60%)
    IPSU 2011-06-02 entry_wk_close=21.47 > prior=12.99 (spike>60%)
    GSIT 2025-10-20 entry_wk_close=9.23 > prior=3.84 (spike>60%)
    GRPN 2025-03-26 entry_wk_close=18.82 > prior=11.12 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 20 violations
    VOYA 2017-11-29 installed_stop=36.7008 vs fill=43.5100 -> dist=0.1565 > gate=0.1500
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.3100 -> dist=0.9045 > gate=0.1500
    PSB 2017-04-24 installed_stop=104.3750 vs fill=122.9800 -> dist=0.1513 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.8000 -> dist=0.1529 > gate=0.1500
    MMS 2014-08-07 installed_stop=33.2640 vs fill=39.3800 -> dist=0.1553 > gate=0.1500
    MGM 2001-09-18 installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500
    MEI 2014-09-04 installed_stop=32.4096 vs fill=38.4700 -> dist=0.1575 > gate=0.1500
    MCK 2020-05-28 installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500
    LPG 2023-09-15 installed_stop=23.2022 vs fill=27.3000 -> dist=0.1501 > gate=0.1500
    GRA 2016-01-22 installed_stop=73.1724 vs fill=86.3000 -> dist=0.1521 > gate=0.1500
V13 INVARIANT 123 violations (5 skipped)
    ZWS 2018-10-06 no bar on entry_date 2018-10-06 (nearest earlier bar: 2018-10-05)
    WSO 2010-03-06 no bar on entry_date 2010-03-06 (nearest earlier bar: 2010-03-05)
    WPM 2024-04-20 no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WING 2017-08-08 entry_price=31.6500 outside 2017-08-08 bar [32.7300, 34.1600]
    VLN 2026-05-16 no bar on entry_date 2026-05-16 (nearest earlier bar: 2026-05-15)
    UN 2017-03-11 no bar on entry_date 2017-03-11 (nearest earlier bar: 2017-03-10)
    TWX1 2000-01-28 exit_price=76.5600 outside 2000-02-23 bar [76.5630, 82.0000]
    TSCO 2005-02-05 no bar on entry_date 2005-02-05 (nearest earlier bar: 2005-02-04)
    TGT 2004-02-21 no bar on entry_date 2004-02-21 (nearest earlier bar: 2004-02-20)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION 2 violations
    CLE 2014-11-18 force_liquidation exit 2014-11-19 (entry 2014-11-18 @ 37.65, exit @ 0.71)
    ASPS 2017-04-20 force_liquidation exit 2017-04-21 (entry 2017-04-20 @ 35.53, exit @ 26.75)
V17 EXPECTATION PASS
V18 EXPECTATION 14 violations
    APLS 2023-04-03 median close 32.88 over 2154 bars (2017-11-09..2026-06-08); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0
    BLNK 2020-07-29 median close 1.61 over 4078 bars (2008-07-15..2026-06-08); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0
    BOKF 2003-06-04 median close 49.73 over 8751 bars (1991-09-05..2026-06-08); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    BRK-A 2006-05-18 median close 83000.00 over 11225 bars (1980-03-17..2026-06-08), above the 10000.00 ceiling
    CIR 2013-04-24 median close 32.28 over 6046 bars (1999-10-18..2023-11-16); bar 2023-11-06 close 0.00 (-100.00% vs prior close 56.00) on volume 0
    CLE 2014-11-18 median close 19.00 over 4813 bars (1997-12-31..2018-06-28); bar 2014-06-09 close 0.07 (-94.53% vs prior close 1.28) on volume 0
    CSKI 2009-12-19 median close 0.20 over 5186 bars (1995-02-01..2015-10-05); bar 2002-12-13 close 0.45 (+542.86% vs prior close 0.07) on volume 0
    FLO 2013-01-03 median close 18.19 over 11651 bars (1980-03-17..2026-06-08); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    IHG 2024-10-15 median close 37.37 over 5828 bars (2003-04-08..2026-06-08); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0
    IOVA 2020-03-24 median close 7.47 over 3934 bars (2010-10-15..2026-06-08); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0
