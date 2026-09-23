# Post-run validation report

Invariant checks failing: 3
audit join: 271/271 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 30 violations
    ZS 2020-05-29 Virgin_territory but only 117 weekly bars (< 520) before entry
    Z 2020-02-20 Virgin_territory but only 239 weekly bars (< 520) before entry
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
    TWST 2020-05-06 Virgin_territory but only 81 weekly bars (< 520) before entry
    TRMD 2024-01-24 Virgin_territory but only 311 weekly bars (< 520) before entry
    SSNC 2019-02-25 Virgin_territory but only 469 weekly bars (< 520) before entry
    SNDR 2023-07-28 Virgin_territory but only 331 weekly bars (< 520) before entry
    SHAK 2019-06-28 Virgin_territory but only 231 weekly bars (< 520) before entry
    ROKU 2021-07-27 Virgin_territory but only 202 weekly bars (< 520) before entry
    PLAN 2020-09-28 Virgin_territory but only 105 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 47 violations (36 skipped)
    VRNS 2021-07-21 prior_top=71.50 within +25% of entry=60.92
    TTWO 2020-05-19 prior_top=137.99 within +25% of entry=136.47
    TNI 2019-06-10 prior_top=13350.00 within +25% of entry=12061.93
    ROST 2023-11-14 prior_top=125.52 within +25% of entry=124.00
    QNST 2025-01-07 prior_top=24.76 within +25% of entry=22.44
    PTGX 2025-06-02 prior_top=54.78 within +25% of entry=49.19
    PEN 2023-05-03 prior_top=305.99 within +25% of entry=294.41
    ON 2021-08-27 prior_top=45.28 within +25% of entry=44.99
    NVCR 2021-05-08 prior_top=207.63 within +25% of entry=195.97
    NATL 2025-08-09 prior_top=37.11 within +25% of entry=36.39
V10 EXPECTATION 5 violations (36 skipped)
    WBTN 2025-08-30 entry_wk_close=14.41 > prior=8.92 (spike>60%)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    EXK 2020-07-20 entry_wk_close=4.20 > prior=2.14 (spike>60%)
    CUTRQ 2022-03-28 entry_wk_close=72.31 > prior=40.49 (spike>60%)
    BLNK 2020-07-29 entry_wk_close=11.05 > prior=5.28 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 4 violations
    QNST 2025-01-07 installed_stop=18.8016 vs fill=22.4400 -> dist=0.1621 > gate=0.1500
    DNOW 2025-02-26 installed_stop=13.4784 vs fill=16.0300 -> dist=0.1592 > gate=0.1500
    DAR 2022-04-20 installed_stop=73.4880 vs fill=86.4800 -> dist=0.1502 > gate=0.1500
    APG 2021-08-24 installed_stop=19.8750 vs fill=23.4000 -> dist=0.1506 > gate=0.1500
V13 INVARIANT 55 violations (1 skipped)
    WPM 2024-04-20 no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)
    WBTN 2025-08-30 no bar on entry_date 2025-08-30 (nearest earlier bar: 2025-08-29)
    VCYT 2024-08-10 no bar on entry_date 2024-08-10 (nearest earlier bar: 2024-08-09)
    TNET 2019-02-23 no bar on entry_date 2019-02-23 (nearest earlier bar: 2019-02-22)
    SPH 2025-02-15 no bar on entry_date 2025-02-15 (nearest earlier bar: 2025-02-14)
    SIRI 2023-07-22 no bar on entry_date 2023-07-22 (nearest earlier bar: 2023-07-21)
    SBS 2024-08-10 no bar on entry_date 2024-08-10 (nearest earlier bar: 2024-08-09)
    PSMT 2025-05-03 no bar on entry_date 2025-05-03 (nearest earlier bar: 2025-05-02)
    PINS 2023-11-04 no bar on entry_date 2023-11-04 (nearest earlier bar: 2023-11-03)
    OR 2021-05-15 no bar on entry_date 2021-05-15 (nearest earlier bar: 2021-05-14)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 5 violations
    BLNK 2020-07-29 median close 1.67 over 3954 bars (2008-07-15..2025-12-08); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0
    BOKF 2021-10-20 median close 49.27 over 8627 bars (1991-09-05..2025-12-08); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    FLO 2020-03-09 median close 18.39 over 11527 bars (1980-03-17..2025-12-08); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    IHG 2024-10-15 median close 36.19 over 5704 bars (2003-04-08..2025-12-08); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0
    IOVA 2020-03-24 median close 7.67 over 3810 bars (2010-10-15..2025-12-08); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0
