# Post-run validation report

Invariant checks failing: 3
audit join: 746/746 rows matched

QUALITY-FLAG: 1 fallback exits (V16)

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 117 violations
    ZS 2020-05-29 Virgin_territory but only 117 weekly bars (< 520) before entry
    Z 2020-02-20 Virgin_territory but only 239 weekly bars (< 520) before entry
    XPOF 2023-01-27 Virgin_territory but only 79 weekly bars (< 520) before entry
    XERS 2024-02-14 Virgin_territory but only 297 weekly bars (< 520) before entry
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    WING 2017-08-08 Virgin_territory but only 113 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    VICI 2019-10-16 Virgin_territory but only 105 weekly bars (< 520) before entry
    VC 2015-05-22 Virgin_territory but only 245 weekly bars (< 520) before entry
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 78 violations (244 skipped)
    ZGN 2023-09-08 prior_top=15.43 within +25% of entry=14.25
    WRLD 2010-03-12 prior_top=49.25 within +25% of entry=43.75
    WOLF_old2 2021-11-22 prior_top=139.55 within +25% of entry=133.00
    WIX 2021-04-28 prior_top=353.09 within +25% of entry=320.94
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TGTX 2018-03-05 prior_top=18.68 within +25% of entry=15.45
    TEF 2024-04-29 prior_top=5.02 within +25% of entry=4.55
    STVN 2023-03-02 prior_top=28.27 within +25% of entry=23.47
    SAND 2025-06-02 prior_top=9.56 within +25% of entry=9.17
    RCRC 2006-12-01 prior_top=44.66 within +25% of entry=41.35
V10 EXPECTATION 16 violations (244 skipped)
    VUZI 2026-05-29 entry_wk_close=4.60 > prior=2.84 (spike>60%)
    SATL 2026-04-01 entry_wk_close=6.77 > prior=3.09 (spike>60%)
    MVL 2002-03-08 entry_wk_close=5.33 > prior=3.00 (spike>60%)
    ISEE 2022-09-30 entry_wk_close=17.94 > prior=9.44 (spike>60%)
    IPSU 2011-06-02 entry_wk_close=21.47 > prior=12.99 (spike>60%)
    GSIT 2025-10-20 entry_wk_close=9.23 > prior=3.84 (spike>60%)
    GRPN 2025-03-26 entry_wk_close=18.82 > prior=11.12 (spike>60%)
    FNMA 2013-05-24 entry_wk_close=2.97 > prior=0.83 (spike>60%)
    EXK 2020-07-20 entry_wk_close=4.20 > prior=2.14 (spike>60%)
    EOSE 2023-06-28 entry_wk_close=4.34 > prior=2.43 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 20 violations
    XERS 2024-02-14 installed_stop=2.6496 vs fill=3.1500 -> dist=0.1589 > gate=0.1500
    SMTC 2018-04-10 installed_stop=35.8750 vs fill=42.2800 -> dist=0.1515 > gate=0.1500
    PRTA 2017-09-27 installed_stop=58.7808 vs fill=69.4700 -> dist=0.1539 > gate=0.1500
    NJDCY 2015-06-08 installed_stop=15.2160 vs fill=17.9500 -> dist=0.1523 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.7700 -> dist=0.1536 > gate=0.1500
    MGM 2001-09-18 installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500
    MEI 2014-09-04 installed_stop=32.4096 vs fill=38.4700 -> dist=0.1575 > gate=0.1500
    MCK 2020-05-28 installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500
    LZB 2024-07-15 installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500
    GRA 2016-01-22 installed_stop=73.1724 vs fill=86.3000 -> dist=0.1521 > gate=0.1500
V13 INVARIANT 27 violations (3 skipped)
    WSFS 2006-11-10 exit_price=65.5200 outside 2006-11-20 bar [65.5201, 66.5500]
    WRLD 2010-03-12 exit_price=41.9300 outside 2010-03-15 bar [41.9301, 44.1000]
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WIRE 2023-12-14 no bar on exit_date 2024-07-03 (nearest earlier bar: 2024-07-02)
    WING 2017-08-08 entry_price=31.6000 outside 2017-08-08 bar [32.7300, 34.1600]
    VRTX 2001-03-12 exit_price=31.6400 outside 2001-03-15 bar [31.6406, 35.6250]
    SAFM 2022-05-31 no bar on exit_date 2022-07-25 (nearest earlier bar: 2022-07-22)
    PAYC 2021-08-09 exit_price=454.0800 outside 2021-08-10 bar [454.0850, 472.4900]
    NPSNY 2009-08-28 entry_price=32.1200 outside 2009-08-28 bar [31.1960, 32.1180]
    NEOG 2017-09-05 entry_price=52.7700 outside 2017-09-05 bar [68.8760, 70.4406]
V14 EXPECTATION 58 violations
    ZQKSQ 2013-05-22 entry bar 2013-05-22 open=7.9200 low=7.7200 close=7.8200 vs stop=7.6760, exit=7.6600
    Z 2020-02-20 entry bar 2020-02-20 open=62.4700 low=61.9300 close=63.6300 vs stop=63.3852, exit=63.1600
    XRAY 2000-04-25 entry bar 2000-04-25 open=27.8750 low=27.8750 close=29.1876 vs stop=28.2787, exit=28.2500
    WRLD 2010-03-12 entry bar 2010-03-12 open=43.0000 low=42.5200 close=43.6500 vs stop=41.9694, exit=41.9300
    VUZI 2026-05-29 entry bar 2026-05-29 open=4.5200 low=4.2200 close=4.6000 vs stop=4.1413, exit=4.1300
    VRNS 2022-01-27 entry bar 2022-01-27 open=34.2100 low=32.4900 close=32.7600 vs stop=30.9184, exit=32.1100
    UTL 2022-07-01 entry bar 2022-07-01 open=58.7100 low=58.0800 close=61.0000 vs stop=57.2358, exit=57.1900
    UMBF 2024-07-31 entry bar 2024-07-31 open=103.0000 low=100.7500 close=102.0200 vs stop=100.9806, exit=100.9500
    UEC 2021-10-18 entry bar 2021-10-18 open=3.4600 low=3.4300 close=3.4900 vs stop=3.3722, exit=3.3600
    UBS 2014-11-26 entry bar 2014-11-26 open=17.5500 low=17.5200 close=23.2000 vs stop=21.8103, exit=18.0900
V15 EXPECTATION PASS
V16 EXPECTATION 1 violations
    ASPS 2017-04-20 force_liquidation exit 2017-04-21 (entry 2017-04-20 @ 35.53, exit @ 26.75)
V17 EXPECTATION PASS
V18 EXPECTATION 16 violations
    ARJ 2005-12-29 median close 0.16 over 4552 bars (1999-02-09..2017-03-13); bar 2010-01-29 close 0.13 (-99.55% vs prior close 28.25) on volume 0
    BLNK 2020-07-29 median close 1.61 over 4088 bars (2008-07-15..2026-06-23); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0
    BOKF 2003-06-04 median close 49.76 over 8761 bars (1991-09-05..2026-06-23); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    BRK-A 2006-05-18 median close 83100.00 over 11235 bars (1980-03-17..2026-06-23), above the 10000.00 ceiling
    CECO 2023-10-13 median close 4.62 over 11481 bars (1980-12-02..2026-06-23); bar 1992-09-29 close 2.66 (+399.96% vs prior close 0.53) on volume 0
    DUOT 2026-06-08 median close 2.72 over 3143 bars (2008-08-13..2026-06-23); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0
    FIT 2020-12-03 median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0
    FLO 2020-03-09 median close 18.17 over 11661 bars (1980-03-17..2026-06-23); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    IOVA 2020-03-24 median close 7.45 over 3944 bars (2010-10-15..2026-06-23); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0
    MVL 2002-03-08 median close 9.00 over 4795 bars (1999-01-04..2018-01-24); bar 2010-01-26 close 60.00 (+96.88% vs prior close 30.48) on volume 0
