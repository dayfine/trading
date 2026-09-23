# Post-run validation report

Invariant checks failing: 3
audit join: 260/260 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 39 violations
    ZS 2020-05-29 Virgin_territory but only 117 weekly bars (< 520) before entry
    XPOF 2023-01-27 Virgin_territory but only 79 weekly bars (< 520) before entry
    VERI 2020-06-02 Virgin_territory but only 162 weekly bars (< 520) before entry
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
    TWST 2020-05-06 Virgin_territory but only 81 weekly bars (< 520) before entry
    TRMD 2024-01-24 Virgin_territory but only 311 weekly bars (< 520) before entry
    TOST 2023-07-13 Virgin_territory but only 94 weekly bars (< 520) before entry
    SSNC 2019-02-25 Virgin_territory but only 469 weekly bars (< 520) before entry
    SHAK 2019-06-28 Virgin_territory but only 231 weekly bars (< 520) before entry
    ROKU 2021-07-27 Virgin_territory but only 202 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 53 violations (34 skipped)
    ZWS 2024-09-21 prior_top=36.34 within +25% of entry=34.82
    ZGN 2023-09-08 prior_top=15.43 within +25% of entry=14.25
    WOLF_old2 2021-11-20 prior_top=139.55 within +25% of entry=130.94
    VRNS 2021-07-21 prior_top=71.50 within +25% of entry=60.99
    URBN 2025-03-13 prior_top=58.19 within +25% of entry=50.12
    STVN 2023-03-02 prior_top=28.27 within +25% of entry=23.47
    SAND 2025-06-02 prior_top=9.56 within +25% of entry=9.20
    ROST 2023-11-14 prior_top=125.52 within +25% of entry=124.00
    PJT 2023-11-03 prior_top=84.12 within +25% of entry=83.64
    PEN 2023-05-03 prior_top=305.99 within +25% of entry=294.56
V10 EXPECTATION 6 violations (34 skipped)
    VERI 2020-06-02 entry_wk_close=11.16 > prior=5.93 (spike>60%)
    GSIT 2025-10-20 entry_wk_close=9.23 > prior=3.84 (spike>60%)
    EXK 2020-07-20 entry_wk_close=4.20 > prior=2.14 (spike>60%)
    EOSE 2023-06-27 entry_wk_close=4.34 > prior=2.43 (spike>60%)
    CUTRQ 2022-03-28 entry_wk_close=72.31 > prior=40.49 (spike>60%)
    BLNK 2020-07-29 entry_wk_close=11.05 > prior=5.28 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 2 violations
    QLYS 2021-01-20 installed_stop=106.9728 vs fill=125.9600 -> dist=0.1507 > gate=0.1500
    LPG 2023-09-15 installed_stop=23.2022 vs fill=27.3000 -> dist=0.1501 > gate=0.1500
V13 INVARIANT 55 violations
    ZWS 2024-09-21 no bar on entry_date 2024-09-21 (nearest earlier bar: 2024-09-20)
    WPM 2024-04-20 no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)
    WOLF_old2 2021-11-20 no bar on entry_date 2021-11-20 (nearest earlier bar: 2021-11-19)
    TNET 2019-02-23 no bar on entry_date 2019-02-23 (nearest earlier bar: 2019-02-22)
    TDS 2023-08-26 no bar on entry_date 2023-08-26 (nearest earlier bar: 2023-08-25)
    SHEN 2020-03-21 no bar on entry_date 2020-03-21 (nearest earlier bar: 2020-03-20)
    QIWI 2019-06-08 no bar on entry_date 2019-06-08 (nearest earlier bar: 2019-06-07)
    PSMT 2025-05-03 no bar on entry_date 2025-05-03 (nearest earlier bar: 2025-05-02)
    PINS 2023-11-04 no bar on entry_date 2023-11-04 (nearest earlier bar: 2023-11-03)
    PECO 2023-07-22 no bar on entry_date 2023-07-22 (nearest earlier bar: 2023-07-21)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 6 violations
    BLNK 2020-07-29 median close 1.67 over 3957 bars (2008-07-15..2025-12-11); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0
    BOKF 2021-10-20 median close 49.28 over 8630 bars (1991-09-05..2025-12-11); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    FLO 2020-03-09 median close 18.38 over 11530 bars (1980-03-17..2025-12-11); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    IOVA 2020-03-24 median close 7.67 over 3813 bars (2010-10-15..2025-12-11); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0
    NOKBF 2025-10-28 median close 5.86 over 4347 bars (2001-07-11..2025-12-11); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0
    PECO 2023-07-22 median close 33.78 over 1206 bars (2021-02-25..2025-12-11); bar 2021-07-06 close 21.69 (+800.00% vs prior close 2.41) on volume 0
