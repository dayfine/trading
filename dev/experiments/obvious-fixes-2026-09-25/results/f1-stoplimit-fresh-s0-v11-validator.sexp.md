# Post-run validation report

Invariant checks failing: 3
audit join: 752/752 rows matched

QUALITY-FLAG: 1 fallback exits (V16)

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 117 violations
    ZS 2020-05-29 Virgin_territory but only 117 weekly bars (< 520) before entry
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    VOYA 2017-11-29 Virgin_territory but only 241 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    VICI 2019-10-16 Virgin_territory but only 105 weekly bars (< 520) before entry
    VC 2015-05-22 Virgin_territory but only 245 weekly bars (< 520) before entry
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
    UNVR 2022-03-15 Virgin_territory but only 354 weekly bars (< 520) before entry
    UE 2024-07-30 Virgin_territory but only 501 weekly bars (< 520) before entry
    UCM 2000-05-22 Virgin_territory but only 126 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 92 violations (243 skipped)
    Z 2017-08-10 prior_top=51.04 within +25% of entry=40.88
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.75
    WRLD 2010-03-12 prior_top=49.25 within +25% of entry=43.75
    VRTX 2014-07-30 prior_top=99.07 within +25% of entry=92.22
    URBN 2025-03-13 prior_top=58.19 within +25% of entry=50.12
    UNVR 2022-03-15 prior_top=32.43 within +25% of entry=32.15
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TTWO 2020-05-19 prior_top=137.99 within +25% of entry=136.42
    TGTX 2018-03-05 prior_top=18.68 within +25% of entry=15.48
    TECD 2016-11-21 prior_top=87.31 within +25% of entry=84.05
V10 EXPECTATION 16 violations (243 skipped)
    VTNRQ 2022-05-16 entry_wk_close=14.40 > prior=8.84 (spike>60%)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    PYX 2018-10-08 entry_wk_close=43.05 > prior=18.60 (spike>60%)
    MVL 2002-03-08 entry_wk_close=5.33 > prior=3.00 (spike>60%)
    IPSU 2011-06-02 entry_wk_close=21.47 > prior=12.99 (spike>60%)
    HIMX 2026-05-08 entry_wk_close=17.48 > prior=9.05 (spike>60%)
    GSIT 2025-10-20 entry_wk_close=9.23 > prior=3.84 (spike>60%)
    GRPN 2025-03-26 entry_wk_close=18.82 > prior=11.12 (spike>60%)
    EOSE 2023-06-27 entry_wk_close=4.34 > prior=2.43 (spike>60%)
    ECHO 2025-08-26 entry_wk_close=61.79 > prior=26.93 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 18 violations
    VOYA 2017-11-29 installed_stop=36.7008 vs fill=43.5100 -> dist=0.1565 > gate=0.1500
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.3100 -> dist=0.9045 > gate=0.1500
    NJDCY 2015-06-08 installed_stop=15.2160 vs fill=17.9500 -> dist=0.1523 > gate=0.1500
    MNSO 2025-01-06 installed_stop=21.8400 vs fill=26.0100 -> dist=0.1603 > gate=0.1500
    MGM 2001-09-18 installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500
    MEI 2014-09-04 installed_stop=32.4096 vs fill=38.4700 -> dist=0.1575 > gate=0.1500
    LZB 2024-07-15 installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500
    LPG 2023-09-15 installed_stop=23.2022 vs fill=27.3000 -> dist=0.1501 > gate=0.1500
    GC 2020-04-06 installed_stop=1392.8640 vs fill=1647.7000 -> dist=0.1547 > gate=0.1500
    FULT 2002-03-07 installed_stop=23.3952 vs fill=19.5000 -> dist=0.1998 > gate=0.1500
V13 INVARIANT 28 violations (5 skipped)
    ZWS 2019-10-30 entry_price=30.6400 outside 2019-10-30 bar [26.6378, 30.6358]
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    TWX1 2000-01-28 exit_price=76.5600 outside 2000-02-23 bar [76.5630, 82.0000]
    SHOO 2015-02-24 exit_price=35.9500 outside 2015-02-26 bar [35.9501, 36.8700]
    MVL 2002-03-08 exit_price=7.4000 outside 2002-03-14 bar [6.6600, 7.3995]
    MRC 2024-05-13 entry_price=14.0200 outside 2024-05-13 bar [13.4900, 14.0150]
    MMSI 2011-03-14 entry_price=14.2900 outside 2011-03-14 bar [17.5400, 17.9500]
    LACO 2020-05-27 no bar on exit_date 2020-10-09 (nearest earlier bar: 2020-10-08)
    KYOCY 2019-04-26 entry_price=64.4500 outside 2019-04-26 bar [64.4530, 64.4530]
    KD 2023-09-11 entry_price=17.3200 outside 2023-09-11 bar [16.7000, 17.3190]
V14 EXPECTATION 1 violations
    BGO 2007-02-26 entry bar 2007-02-26 open=6.3100 low=6.3000 close=6.4700 vs stop=5.8719, exit=5.9600
V15 EXPECTATION PASS
V16 EXPECTATION 1 violations
    ASPS 2017-04-20 force_liquidation exit 2017-04-21 (entry 2017-04-20 @ 35.53, exit @ 26.75)
V17 EXPECTATION PASS
V18 EXPECTATION 20 violations
    APLS 2023-04-03 median close 32.70 over 2166 bars (2017-11-09..2026-06-24); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0
    BHRB 2022-09-20 median close 2015.00 over 5923 bars (1995-08-04..2026-06-24); bar 2003-10-07 close 2001.00 (-99.80% vs prior close 1000000.00) on volume 0
    BLFS 2021-07-08 median close 1.73 over 9212 bars (1989-11-22..2026-06-24); bar 2014-01-29 close 8.12 (+1300.00% vs prior close 0.58) on volume 0
    BLNK 2020-07-29 median close 1.61 over 4089 bars (2008-07-15..2026-06-24); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0
    BOKF 2003-06-04 median close 49.77 over 8762 bars (1991-09-05..2026-06-24); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    BRK-A 2006-05-18 median close 83100.00 over 11236 bars (1980-03-17..2026-06-24), above the 10000.00 ceiling
    CECO 2023-10-13 median close 4.62 over 11482 bars (1980-12-02..2026-06-24); bar 1992-09-29 close 2.66 (+399.96% vs prior close 0.53) on volume 0
    CIR 2013-04-24 median close 32.28 over 6046 bars (1999-10-18..2023-11-16); bar 2023-11-06 close 0.00 (-100.00% vs prior close 56.00) on volume 0
    FLO 2020-03-09 median close 18.16 over 11662 bars (1980-03-17..2026-06-24); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    IHG 2024-10-15 median close 37.44 over 5839 bars (2003-04-08..2026-06-24); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0
