# Post-run validation report

Invariant checks failing: 3
audit join: 504/504 rows matched

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
V9 EXPECTATION 63 violations (149 skipped)
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.74
    WOLF_old2 2021-11-20 prior_top=139.55 within +25% of entry=130.58
    VRTX 2024-04-10 prior_top=435.02 within +25% of entry=397.15
    UHS 2018-08-22 prior_top=138.68 within +25% of entry=128.84
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TTWO 2020-05-19 prior_top=137.99 within +25% of entry=136.47
    TKO 2017-03-23 prior_top=25.14 within +25% of entry=21.77
    TGT 2020-03-12 prior_top=107.27 within +25% of entry=92.66
    TDY 2007-05-12 prior_top=46.50 within +25% of entry=45.71
    STE 2025-11-22 prior_top=261.84 within +25% of entry=257.13
V10 EXPECTATION 11 violations (149 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    SSP 2025-11-18 entry_wk_close=3.10 > prior=1.77 (spike>60%)
    SMRT_old 2018-05-04 entry_wk_close=2.60 > prior=1.52 (spike>60%)
    RBAK 2006-12-23 entry_wk_close=24.94 > prior=14.52 (spike>60%)
    MVL 2002-03-08 entry_wk_close=5.33 > prior=3.00 (spike>60%)
    FMCC 2013-05-24 entry_wk_close=2.81 > prior=0.82 (spike>60%)
    ENCO 2009-09-30 entry_wk_close=3.76 > prior=1.52 (spike>60%)
    CLPA 2000-01-31 entry_wk_close=25.25 > prior=12.12 (spike>60%)
    CLFD 2026-05-26 entry_wk_close=47.22 > prior=29.43 (spike>60%)
    BPT 2022-01-22 entry_wk_close=5.52 > prior=2.85 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 21 violations
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.1800 -> dist=0.9189 > gate=0.1500
    TRMB 2003-11-24 installed_stop=25.8750 vs fill=19.6900 -> dist=0.3141 > gate=0.1500
    SMTC 2018-04-10 installed_stop=35.8750 vs fill=42.2800 -> dist=0.1515 > gate=0.1500
    OSK 2003-08-09 installed_stop=63.8750 vs fill=33.7400 -> dist=0.8932 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.4800 -> dist=0.1600 > gate=0.1500
    MNT 2005-04-15 installed_stop=31.3920 vs fill=37.4500 -> dist=0.1618 > gate=0.1500
    MCK 2020-05-28 installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500
    GRA 2016-01-22 installed_stop=73.1724 vs fill=86.3000 -> dist=0.1521 > gate=0.1500
    GE 2024-04-13 installed_stop=128.6304 vs fill=154.1300 -> dist=0.1654 > gate=0.1500
    FULT 2002-03-07 installed_stop=23.3952 vs fill=19.5000 -> dist=0.1998 > gate=0.1500
V13 INVARIANT 129 violations (7 skipped)
    WOLF_old2 2021-11-20 no bar on entry_date 2021-11-20 (nearest earlier bar: 2021-11-19)
    WNC 2024-03-09 no bar on entry_date 2024-03-09 (nearest earlier bar: 2024-03-08)
    WAVX 2014-05-31 no bar on entry_date 2014-05-31 (nearest earlier bar: 2014-05-30)
    WAFD 2013-06-29 no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)
    UN 2017-03-11 no bar on entry_date 2017-03-11 (nearest earlier bar: 2017-03-10)
    UFPI 2013-06-22 no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)
    TXNM 2020-02-01 no bar on entry_date 2020-02-01 (nearest earlier bar: 2020-01-31)
    TWX1 2000-01-28 exit_price=76.5600 outside 2000-02-23 bar [76.5630, 82.0000]
    TRV 2025-05-10 no bar on entry_date 2025-05-10 (nearest earlier bar: 2025-05-09)
    TDY 2007-05-12 no bar on entry_date 2007-05-12 (nearest earlier bar: 2007-05-11)
V14 EXPECTATION PASS (1 skipped)
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 4 violations
    ARJ 2005-12-29 median close 0.16 over 4552 bars (1999-02-09..2017-03-13); bar 2010-01-29 close 0.13 (-99.55% vs prior close 28.25) on volume 0
    CLE 2014-11-18 median close 19.00 over 4813 bars (1997-12-31..2018-06-28); bar 2014-06-09 close 0.07 (-94.53% vs prior close 1.28) on volume 0
    FLO 2013-01-03 median close 18.18 over 11660 bars (1980-03-17..2026-06-22); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    MVL 2002-03-08 median close 9.00 over 4795 bars (1999-01-04..2018-01-24); bar 2010-01-26 close 60.00 (+96.88% vs prior close 30.48) on volume 0
