# Post-run validation report

Invariant checks failing: 3
audit join: 761/761 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 96 violations
    ZS 2021-07-12 Virgin_territory but only 176 weekly bars (< 520) before entry
    WLP1 2000-10-02 Virgin_territory but only 145 weekly bars (< 520) before entry
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    WLK 2012-08-06 Virgin_territory but only 419 weekly bars (< 520) before entry
    WAVX 2000-02-22 Virgin_territory but only 59 weekly bars (< 520) before entry
    VOYA 2017-11-29 Virgin_territory but only 241 weekly bars (< 520) before entry
    VNA 2015-02-05 Virgin_territory but only 258 weekly bars (< 520) before entry
    VC 2015-05-22 Virgin_territory but only 245 weekly bars (< 520) before entry
    UCM 2000-05-22 Virgin_territory but only 126 weekly bars (< 520) before entry
    UAA 2010-09-15 Virgin_territory but only 254 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 67 violations (295 skipped)
    YUM 2025-04-07 prior_top=158.67 within +25% of entry=144.64
    WIX 2021-03-03 prior_top=353.09 within +25% of entry=327.36
    VRTX 2014-06-28 prior_top=93.77 within +25% of entry=92.22
    URBN 2025-03-13 prior_top=58.19 within +25% of entry=50.12
    ULTA 2016-04-02 prior_top=194.18 within +25% of entry=192.62
    UHS 2018-08-22 prior_top=138.68 within +25% of entry=128.79
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TW 2025-05-10 prior_top=146.66 within +25% of entry=145.25
    TGT 2020-03-12 prior_top=107.27 within +25% of entry=92.66
    SNPS 2025-07-19 prior_top=621.30 within +25% of entry=596.71
V10 EXPECTATION 7 violations (295 skipped)
    RMBS 2000-06-22 entry_wk_close=114.69 > prior=40.75 (spike>60%)
    RBAK 2006-12-23 entry_wk_close=24.94 > prior=14.52 (spike>60%)
    OCHTQ 2000-02-17 entry_wk_close=6300.00 > prior=3075.00 (spike>60%)
    JKS 2020-09-29 entry_wk_close=33.65 > prior=15.33 (spike>60%)
    CBMC 2000-03-06 entry_wk_close=191.25 > prior=71.25 (spike>60%)
    ATISZ 2000-02-09 entry_wk_close=7.13 > prior=3.56 (spike>60%)
    ABRX 2000-03-09 entry_wk_close=15.00 > prior=8.44 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 25 violations
    YMM 2024-11-20 installed_stop=8.2848 vs fill=9.7600 -> dist=0.1511 > gate=0.1500
    VOYA 2017-11-29 installed_stop=36.7008 vs fill=43.5100 -> dist=0.1565 > gate=0.1500
    TAP 2007-09-19 installed_stop=83.6448 vs fill=49.1200 -> dist=0.7029 > gate=0.1500
    PENN 2001-06-02 installed_stop=15.7028 vs fill=18.8300 -> dist=0.1661 > gate=0.1500
    ODFL 2005-11-11 installed_stop=37.1520 vs fill=25.8600 -> dist=0.4367 > gate=0.1500
    ODFL 2005-11-11 installed_stop=37.1520 vs fill=25.8600 -> dist=0.4367 > gate=0.1500
    NRG 2006-11-18 installed_stop=50.7552 vs fill=26.9500 -> dist=0.8833 > gate=0.1500
    NKE 2006-10-25 installed_stop=88.3200 vs fill=46.0400 -> dist=0.9183 > gate=0.1500
    NKE 2015-07-30 installed_stop=110.7648 vs fill=57.7000 -> dist=0.9197 > gate=0.1500
    MMM 2003-07-26 installed_stop=131.9328 vs fill=69.6800 -> dist=0.8934 > gate=0.1500
V13 INVARIANT 173 violations (12 skipped)
    YUMC 2019-12-21 no bar on entry_date 2019-12-21 (nearest earlier bar: 2019-12-20)
    YUM 2022-01-01 no bar on entry_date 2022-01-01 (nearest earlier bar: 2021-12-31)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WLK 2012-08-06 entry_price=64.6000 outside 2012-08-06 bar [65.8500, 68.4000]
    WDC 2012-08-18 no bar on entry_date 2012-08-18 (nearest earlier bar: 2012-08-17)
    VZ 2025-03-08 no bar on entry_date 2025-03-08 (nearest earlier bar: 2025-03-07)
    VRTX 2014-06-28 no bar on entry_date 2014-06-28 (nearest earlier bar: 2014-06-27)
    VRSK 2017-11-04 no bar on entry_date 2017-11-04 (nearest earlier bar: 2017-11-03)
    URBN 2025-12-20 no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)
    ULTA 2016-04-02 no bar on entry_date 2016-04-02 (nearest earlier bar: 2016-04-01)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 13 violations
    BRK-A 2006-05-18 median close 83000.00 over 11223 bars (1980-03-17..2026-06-04), above the 10000.00 ceiling
    CBE 2005-02-03 median close 74.58 over 11518 bars (1972-06-01..2018-01-30); bar 1997-05-19 close 60.00 (+92.00% vs prior close 31.25) on volume 0
    CLE 2006-12-11 median close 19.00 over 4813 bars (1997-12-31..2018-06-28); bar 2014-06-09 close 0.07 (-94.53% vs prior close 1.28) on volume 0
    FERG 2025-07-23 median close 69.50 over 4395 bars (2001-07-20..2026-06-04); bar 2001-10-22 close 60.37 (-97.71% vs prior close 2641.96) on volume 0
    IOVA 2020-12-01 median close 7.49 over 3932 bars (2010-10-15..2026-06-04); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0
    ISA 2019-03-14 median close 7360.00 over 5664 bars (1997-12-31..2020-07-07); bar 2001-08-22 close 0.05 (-100.00% vs prior close 1070.00) on volume 0
    LAR 2021-10-29 median close 1.46 over 4455 bars (2008-09-18..2026-06-04); bar 2017-11-08 close 7.65 (+400.03% vs prior close 1.53) on volume 0
    LNG 2026-03-07 median close 27.68 over 8097 bars (1994-04-04..2026-06-04); bar 1994-07-19 close 6.00 (+500.00% vs prior close 1.00) on volume 0
    RGLD 2009-11-06 median close 17.46 over 11339 bars (1981-06-09..2026-06-04); bar 1992-06-01 close 0.38 (+200.00% vs prior close 0.12) on volume 0
    RRC 2006-11-30 median close 16.75 over 9577 bars (1984-11-05..2026-06-04); bar 1992-11-23 close 4.22 (+1399.47% vs prior close 0.28) on volume 0
