# Post-run validation report

Invariant checks failing: 4
audit join: 741/741 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT 1 violations
    AGYS 2006-01-09 twin positions: AGYS/HXL
V7 INVARIANT 115 violations
    ZS 2020-05-29 Virgin_territory but only 117 weekly bars (< 520) before entry
    Z 2020-02-20 Virgin_territory but only 239 weekly bars (< 520) before entry
    XPOF 2023-01-27 Virgin_territory but only 79 weekly bars (< 520) before entry
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    VOYA 2017-11-29 Virgin_territory but only 241 weekly bars (< 520) before entry
    VNA 2015-02-05 Virgin_territory but only 258 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    VC 2015-05-22 Virgin_territory but only 245 weekly bars (< 520) before entry
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
    UGP 2006-10-20 Virgin_territory but only 370 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 85 violations (246 skipped)
    ZWS 2024-09-23 prior_top=36.34 within +25% of entry=34.83
    ZGN 2023-09-08 prior_top=15.43 within +25% of entry=14.25
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.85
    VRNS 2021-07-21 prior_top=71.50 within +25% of entry=60.99
    URBN 2025-12-22 prior_top=81.84 within +25% of entry=81.28
    UMAC 2026-01-15 prior_top=18.73 within +25% of entry=17.82
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TVTX 2025-09-22 prior_top=31.77 within +25% of entry=25.42
    STVN 2023-03-02 prior_top=28.27 within +25% of entry=23.47
    SKYW 2013-11-19 prior_top=16.83 within +25% of entry=16.40
V10 EXPECTATION 14 violations (246 skipped)
    VUZI 2026-05-29 entry_wk_close=4.60 > prior=2.84 (spike>60%)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    RCF-UN 2007-11-15 entry_wk_close=82.50 > prior=50.30 (spike>60%)
    MVL 2002-03-08 entry_wk_close=5.33 > prior=3.00 (spike>60%)
    IPSU 2011-06-02 entry_wk_close=21.47 > prior=12.99 (spike>60%)
    GSIT 2025-10-20 entry_wk_close=9.23 > prior=3.84 (spike>60%)
    EXK 2020-07-20 entry_wk_close=4.20 > prior=2.14 (spike>60%)
    EOSE 2023-06-28 entry_wk_close=4.34 > prior=2.43 (spike>60%)
    ECHO 2025-08-26 entry_wk_close=61.79 > prior=26.93 (spike>60%)
    CUTRQ 2022-03-28 entry_wk_close=72.31 > prior=40.49 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 18 violations
    VOYA 2017-11-29 installed_stop=36.7008 vs fill=43.5100 -> dist=0.1565 > gate=0.1500
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.1800 -> dist=0.9189 > gate=0.1500
    SOUN 2024-04-02 installed_stop=4.3750 vs fill=5.2400 -> dist=0.1651 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.8100 -> dist=0.1527 > gate=0.1500
    MGM 2001-09-18 installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500
    MCK 2020-05-28 installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500
    LPG 2023-09-15 installed_stop=23.2022 vs fill=27.3000 -> dist=0.1501 > gate=0.1500
    GRA 2016-01-22 installed_stop=73.1724 vs fill=86.3000 -> dist=0.1521 > gate=0.1500
    GC 2020-04-06 installed_stop=1392.8640 vs fill=1647.7000 -> dist=0.1547 > gate=0.1500
    GAS1 2007-04-04 installed_stop=42.6816 vs fill=50.2400 -> dist=0.1504 > gate=0.1500
V13 INVARIANT 23 violations (5 skipped)
    WSFS 2006-11-10 exit_price=65.5200 outside 2006-11-20 bar [65.5201, 66.5500]
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    VRTX 2001-03-12 exit_price=31.6400 outside 2001-03-15 bar [31.6406, 35.6250]
    PAYC 2021-08-09 exit_price=454.0800 outside 2021-08-10 bar [454.0850, 472.4900]
    NPSNY 2009-08-28 entry_price=32.1200 outside 2009-08-28 bar [31.1960, 32.1180]
    NEOG 2017-09-05 entry_price=52.8100 outside 2017-09-05 bar [68.8760, 70.4406]
    MMSI 2011-03-14 entry_price=14.3300 outside 2011-03-14 bar [17.5400, 17.9500]
    MMCN 2000-08-11 no bar on exit_date 2000-10-26 (nearest earlier bar: 2000-10-25)
    KYOCY 2019-04-26 entry_price=64.4500 outside 2019-04-26 bar [64.4530, 64.4530]
    HZNP 2023-10-09 no bar on exit_date 2023-10-10 (nearest earlier bar: 2023-10-09)
V14 EXPECTATION 64 violations
    Z 2020-02-20 entry bar 2020-02-20 open=62.4700 low=61.9300 close=63.6300 vs stop=63.3905, exit=63.1600
    XRAY 2000-04-25 entry bar 2000-04-25 open=27.8750 low=27.8750 close=29.1876 vs stop=28.2853, exit=28.2500
    VUZI 2026-05-29 entry bar 2026-05-29 open=4.5200 low=4.2200 close=4.6000 vs stop=4.1413, exit=4.0400
    VNA 2015-02-05 entry bar 2015-02-05 open=4500.0000 low=4300.0000 close=4300.0000 vs stop=4244.8500, exit=4240.1900
    UTL 2022-07-01 entry bar 2022-07-01 open=58.7100 low=58.0800 close=61.0000 vs stop=57.2355, exit=57.2300
    URBN 2025-12-22 entry bar 2025-12-22 open=80.4200 low=79.8700 close=80.1200 vs stop=77.8662, exit=77.7900
    UMBF 2024-07-31 entry bar 2024-07-31 open=103.0000 low=100.7500 close=102.0200 vs stop=100.9815, exit=100.5300
    UBS 2014-11-26 entry bar 2014-11-26 open=17.5500 low=17.5200 close=23.2000 vs stop=21.8068, exit=18.0900
    TRMD 2024-01-24 entry bar 2024-01-24 open=36.5500 low=35.8800 close=35.9700 vs stop=35.3118, exit=35.2700
    TR 2021-01-27 entry bar 2021-01-27 open=45.1599 low=39.5799 close=42.8501 vs stop=39.3798, exit=39.2500
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 17 violations
    APLS 2023-04-03 median close 32.72 over 2165 bars (2017-11-09..2026-06-23); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0
    BLNK 2020-07-29 median close 1.61 over 4088 bars (2008-07-15..2026-06-23); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0
    BOKF 2003-06-04 median close 49.76 over 8761 bars (1991-09-05..2026-06-23); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    BRK-A 2006-05-18 median close 83100.00 over 11235 bars (1980-03-17..2026-06-23), above the 10000.00 ceiling
    CECO 2023-10-13 median close 4.62 over 11481 bars (1980-12-02..2026-06-23); bar 1992-09-29 close 2.66 (+399.96% vs prior close 0.53) on volume 0
    CIR 2013-04-24 median close 32.28 over 6046 bars (1999-10-18..2023-11-16); bar 2023-11-06 close 0.00 (-100.00% vs prior close 56.00) on volume 0
    DNBBY 2016-12-01 median close 25.46 over 3947 bars (2010-09-08..2026-06-23); bar 2010-10-15 close 135.70 (-99.99% vs prior close 1000000.00) on volume 0
    DUOT 2026-06-15 median close 2.72 over 3143 bars (2008-08-13..2026-06-23); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0
    FIT 2020-12-03 median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0
    FLO 2020-03-09 median close 18.17 over 11661 bars (1980-03-17..2026-06-23); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
