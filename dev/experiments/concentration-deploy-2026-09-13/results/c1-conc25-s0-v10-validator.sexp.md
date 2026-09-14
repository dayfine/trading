# Post-run validation report

Invariant checks failing: 3
audit join: 474/474 rows matched

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
V9 EXPECTATION 70 violations (135 skipped)
    WTRG 2025-10-20 prior_top=46.23 within +25% of entry=42.04
    WAB 2023-07-08 prior_top=109.26 within +25% of entry=108.45
    VRTX 2019-11-09 prior_top=201.31 within +25% of entry=197.08
    VICR 2021-07-03 prior_top=107.97 within +25% of entry=107.30
    USB 2024-08-28 prior_top=51.66 within +25% of entry=46.10
    URBN 2025-03-13 prior_top=58.19 within +25% of entry=50.12
    UHS 2018-08-22 prior_top=138.68 within +25% of entry=128.80
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TTWO 2020-05-19 prior_top=137.99 within +25% of entry=136.42
    TKO 2017-03-23 prior_top=25.14 within +25% of entry=21.67
V10 EXPECTATION 8 violations (135 skipped)
    RBAK 2006-12-23 entry_wk_close=24.94 > prior=14.52 (spike>60%)
    MVL 2002-03-08 entry_wk_close=5.33 > prior=3.00 (spike>60%)
    GERN 2012-09-01 entry_wk_close=2.74 > prior=1.61 (spike>60%)
    FMCC 2013-05-24 entry_wk_close=2.81 > prior=0.82 (spike>60%)
    ENCO 2009-09-30 entry_wk_close=3.76 > prior=1.52 (spike>60%)
    CLPA 2000-01-31 entry_wk_close=25.25 > prior=12.12 (spike>60%)
    BPT 2022-01-22 entry_wk_close=5.52 > prior=2.85 (spike>60%)
    APWR 2000-01-24 entry_wk_close=15.33 > prior=9.33 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 15 violations
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.3100 -> dist=0.9045 > gate=0.1500
    TRMB 2003-11-24 installed_stop=25.8750 vs fill=19.6700 -> dist=0.3155 > gate=0.1500
    OSK 2003-08-09 installed_stop=63.8750 vs fill=33.7400 -> dist=0.8932 > gate=0.1500
    ORLY 2025-01-27 installed_stop=1127.3750 vs fill=84.4300 -> dist=12.3528 > gate=0.1500
    NVDA 2021-05-24 installed_stop=567.6864 vs fill=154.5500 -> dist=2.6732 > gate=0.1500
    MNT 2005-04-15 installed_stop=31.3920 vs fill=37.4500 -> dist=0.1618 > gate=0.1500
    LRCX 2014-05-03 installed_stop=48.3750 vs fill=57.2000 -> dist=0.1543 > gate=0.1500
    KLIC 2019-11-05 installed_stop=21.4752 vs fill=25.3100 -> dist=0.1515 > gate=0.1500
    FULT 2002-03-07 installed_stop=23.3952 vs fill=19.5000 -> dist=0.1998 > gate=0.1500
    DGX 2020-03-05 installed_stop=100.2720 vs fill=118.3000 -> dist=0.1524 > gate=0.1500
V13 INVARIANT 127 violations (6 skipped)
    WNC 2024-03-16 no bar on entry_date 2024-03-16 (nearest earlier bar: 2024-03-15)
    WAFD 2013-06-29 no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)
    WAB 2023-07-08 no bar on entry_date 2023-07-08 (nearest earlier bar: 2023-07-07)
    VRTX 2019-11-09 no bar on entry_date 2019-11-09 (nearest earlier bar: 2019-11-08)
    VICR 2021-07-03 no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)
    UN 2017-03-11 no bar on entry_date 2017-03-11 (nearest earlier bar: 2017-03-10)
    UFPI 2013-06-22 no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)
    TXNM 2020-02-01 no bar on entry_date 2020-02-01 (nearest earlier bar: 2020-01-31)
    TWX1 2000-01-28 exit_price=76.5600 outside 2000-02-23 bar [76.5630, 82.0000]
    TDY 2007-05-12 no bar on entry_date 2007-05-12 (nearest earlier bar: 2007-05-11)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 4 violations
    ARJ 2005-12-29 median close 0.16 over 4552 bars (1999-02-09..2017-03-13); bar 2010-01-29 close 0.13 (-99.55% vs prior close 28.25) on volume 0
    BRK-A 2017-08-19 median close 83000.00 over 11225 bars (1980-03-17..2026-06-08), above the 10000.00 ceiling
    FLO 2020-03-09 median close 18.19 over 11651 bars (1980-03-17..2026-06-08); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    MVL 2002-03-08 median close 9.00 over 4795 bars (1999-01-04..2018-01-24); bar 2010-01-26 close 60.00 (+96.88% vs prior close 30.48) on volume 0
