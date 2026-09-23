# Post-run validation report

Invariant checks failing: 3
audit join: 279/279 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 34 violations
    ZS 2020-05-29 Virgin_territory but only 117 weekly bars (< 520) before entry
    Z 2020-02-20 Virgin_territory but only 239 weekly bars (< 520) before entry
    XERS 2024-02-14 Virgin_territory but only 297 weekly bars (< 520) before entry
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
    TWST 2020-05-06 Virgin_territory but only 81 weekly bars (< 520) before entry
    TRMD 2024-01-24 Virgin_territory but only 311 weekly bars (< 520) before entry
    SSNC 2019-02-25 Virgin_territory but only 469 weekly bars (< 520) before entry
    SNDR 2023-07-28 Virgin_territory but only 331 weekly bars (< 520) before entry
    SHAK 2019-06-28 Virgin_territory but only 231 weekly bars (< 520) before entry
    ROKU 2021-07-27 Virgin_territory but only 202 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 47 violations (37 skipped)
    VRNS 2021-07-21 prior_top=71.50 within +25% of entry=60.99
    URBN 2025-03-13 prior_top=58.19 within +25% of entry=50.12
    TNI 2019-06-10 prior_top=13350.00 within +25% of entry=12063.80
    STVN 2023-03-02 prior_top=28.27 within +25% of entry=23.47
    ROST 2023-11-14 prior_top=125.52 within +25% of entry=124.00
    PTGX 2025-06-02 prior_top=54.78 within +25% of entry=49.17
    PTC 2025-07-26 prior_top=204.51 within +25% of entry=204.14
    PEN 2023-05-03 prior_top=305.99 within +25% of entry=294.56
    ON 2021-08-27 prior_top=45.28 within +25% of entry=44.86
    NVCR 2021-05-08 prior_top=207.63 within +25% of entry=195.74
V10 EXPECTATION 5 violations (37 skipped)
    GSIT 2025-10-20 entry_wk_close=9.23 > prior=3.84 (spike>60%)
    EXK 2020-07-20 entry_wk_close=4.20 > prior=2.14 (spike>60%)
    EOSE 2023-06-27 entry_wk_close=4.34 > prior=2.43 (spike>60%)
    CUTRQ 2022-03-28 entry_wk_close=72.31 > prior=40.49 (spike>60%)
    BLNK 2020-07-29 entry_wk_close=11.05 > prior=5.28 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 10 violations
    YMM 2024-11-20 installed_stop=8.2848 vs fill=9.7600 -> dist=0.1511 > gate=0.1500
    XERS 2024-02-14 installed_stop=2.6496 vs fill=3.1300 -> dist=0.1535 > gate=0.1500
    QLYS 2021-01-20 installed_stop=106.9728 vs fill=125.9600 -> dist=0.1507 > gate=0.1500
    PANW 2024-10-21 installed_stop=329.6256 vs fill=191.4600 -> dist=0.7216 > gate=0.1500
    MNSO 2025-01-06 installed_stop=21.8400 vs fill=26.0100 -> dist=0.1603 > gate=0.1500
    LPG 2023-09-15 installed_stop=23.2022 vs fill=27.3000 -> dist=0.1501 > gate=0.1500
    HMN 2025-05-16 installed_stop=37.2096 vs fill=43.9000 -> dist=0.1524 > gate=0.1500
    ELF 2021-09-07 installed_stop=26.7552 vs fill=31.6600 -> dist=0.1549 > gate=0.1500
    DAR 2022-04-20 installed_stop=73.4880 vs fill=86.4900 -> dist=0.1503 > gate=0.1500
    APG 2021-08-24 installed_stop=19.8750 vs fill=23.4100 -> dist=0.1510 > gate=0.1500
V13 INVARIANT 57 violations (1 skipped)
    WPM 2024-04-20 no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)
    WMT 2019-08-31 no bar on entry_date 2019-08-31 (nearest earlier bar: 2019-08-30)
    WBTN 2025-08-23 no bar on entry_date 2025-08-23 (nearest earlier bar: 2025-08-22)
    VIRT 2021-03-13 no bar on entry_date 2021-03-13 (nearest earlier bar: 2021-03-12)
    URBN 2025-12-20 no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)
    TNET 2019-02-23 no bar on entry_date 2019-02-23 (nearest earlier bar: 2019-02-22)
    TDS 2023-08-26 no bar on entry_date 2023-08-26 (nearest earlier bar: 2023-08-25)
    QIWI 2019-06-08 no bar on entry_date 2019-06-08 (nearest earlier bar: 2019-06-07)
    PTC 2025-07-26 no bar on entry_date 2025-07-26 (nearest earlier bar: 2025-07-25)
    PSMT 2025-05-03 no bar on entry_date 2025-05-03 (nearest earlier bar: 2025-05-02)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 5 violations
    BLNK 2020-07-29 median close 1.67 over 3966 bars (2008-07-15..2025-12-24); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0
    BOKF 2021-10-20 median close 49.33 over 8639 bars (1991-09-05..2025-12-24); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    FLO 2020-03-09 median close 18.37 over 11539 bars (1980-03-17..2025-12-24); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    IOVA 2020-03-24 median close 7.65 over 3822 bars (2010-10-15..2025-12-24); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0
    NOKBF 2025-10-28 median close 5.86 over 4356 bars (2001-07-11..2025-12-24); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0
