# Post-run validation report

Invariant checks failing: 3
audit join: 256/256 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 33 violations
    ZS 2020-05-29 Virgin_territory but only 117 weekly bars (< 520) before entry
    VERI 2020-06-02 Virgin_territory but only 162 weekly bars (< 520) before entry
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
    TWST 2020-05-06 Virgin_territory but only 81 weekly bars (< 520) before entry
    TOST 2023-07-13 Virgin_territory but only 94 weekly bars (< 520) before entry
    SSNC 2019-02-25 Virgin_territory but only 469 weekly bars (< 520) before entry
    SHAK 2019-06-28 Virgin_territory but only 231 weekly bars (< 520) before entry
    QTWO 2020-07-20 Virgin_territory but only 334 weekly bars (< 520) before entry
    PLAN 2020-09-28 Virgin_territory but only 105 weekly bars (< 520) before entry
    PETQ 2021-04-26 Virgin_territory but only 199 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 46 violations (42 skipped)
    ZGN 2023-09-08 prior_top=15.43 within +25% of entry=14.25
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.85
    WIX 2021-04-28 prior_top=353.09 within +25% of entry=320.97
    VRNS 2021-07-21 prior_top=71.50 within +25% of entry=60.99
    ROST 2023-11-14 prior_top=125.52 within +25% of entry=124.00
    PTGX 2025-06-02 prior_top=54.78 within +25% of entry=49.17
    PTC 2025-07-26 prior_top=204.51 within +25% of entry=204.14
    PSLV 2024-04-22 prior_top=10.04 within +25% of entry=9.21
    PJT 2023-11-03 prior_top=84.12 within +25% of entry=83.64
    PEN 2023-05-03 prior_top=305.99 within +25% of entry=294.56
V10 EXPECTATION 5 violations (42 skipped)
    VERI 2020-06-02 entry_wk_close=11.16 > prior=5.93 (spike>60%)
    GRPN 2025-03-26 entry_wk_close=18.82 > prior=11.12 (spike>60%)
    EXK 2020-07-20 entry_wk_close=4.20 > prior=2.14 (spike>60%)
    CUTRQ 2022-03-28 entry_wk_close=72.31 > prior=40.49 (spike>60%)
    BLNK 2020-07-29 entry_wk_close=11.05 > prior=5.28 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 1 violations
    LPG 2023-09-15 installed_stop=23.2022 vs fill=27.3000 -> dist=0.1501 > gate=0.1500
V13 INVARIANT 58 violations
    WPM 2024-04-20 no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)
    VCYT 2024-08-10 no bar on entry_date 2024-08-10 (nearest earlier bar: 2024-08-09)
    URBN 2025-12-20 no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)
    TNET 2019-02-23 no bar on entry_date 2019-02-23 (nearest earlier bar: 2019-02-22)
    TDS 2023-08-26 no bar on entry_date 2023-08-26 (nearest earlier bar: 2023-08-25)
    SMCI 2021-12-18 no bar on entry_date 2021-12-18 (nearest earlier bar: 2021-12-17)
    SIRI 2023-07-22 no bar on entry_date 2023-07-22 (nearest earlier bar: 2023-07-21)
    SHEN 2020-03-21 no bar on entry_date 2020-03-21 (nearest earlier bar: 2020-03-20)
    SAFM 2022-05-28 no bar on entry_date 2022-05-28 (nearest earlier bar: 2022-05-27)
    QIWI 2019-06-08 no bar on entry_date 2019-06-08 (nearest earlier bar: 2019-06-07)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 5 violations
    BLNK 2020-07-29 median close 1.67 over 3966 bars (2008-07-15..2025-12-24); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0
    BOKF 2021-10-20 median close 49.33 over 8639 bars (1991-09-05..2025-12-24); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    FIT 2020-11-11 median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0
    FLO 2020-03-09 median close 18.37 over 11539 bars (1980-03-17..2025-12-24); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    IOVA 2020-03-24 median close 7.65 over 3822 bars (2010-10-15..2025-12-24); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0
