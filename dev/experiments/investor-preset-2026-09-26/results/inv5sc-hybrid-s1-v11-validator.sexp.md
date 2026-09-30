# Post-run validation report

Invariant checks failing: 3
audit join: 183/183 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 25 violations
    XPOF 2023-01-27 Virgin_territory but only 79 weekly bars (< 520) before entry
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
    UE 2024-07-30 Virgin_territory but only 501 weekly bars (< 520) before entry
    TRMD 2024-01-24 Virgin_territory but only 311 weekly bars (< 520) before entry
    SHOP 2021-06-21 Virgin_territory but only 320 weekly bars (< 520) before entry
    ROKU 2021-07-27 Virgin_territory but only 202 weekly bars (< 520) before entry
    QBTS 2024-11-25 Virgin_territory but only 207 weekly bars (< 520) before entry
    NTRA 2021-09-23 Virgin_territory but only 327 weekly bars (< 520) before entry
    NEXT 2025-01-16 Virgin_territory but only 469 weekly bars (< 520) before entry
    MNDT 2022-03-07 Virgin_territory but only 446 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 42 violations (15 skipped)
    VRNS 2021-07-21 prior_top=71.50 within +25% of entry=60.92
    URBN 2025-12-22 prior_top=81.84 within +25% of entry=81.15
    ROST 2023-11-14 prior_top=125.52 within +25% of entry=124.00
    PTGX 2025-06-02 prior_top=54.78 within +25% of entry=49.19
    PSLV 2024-04-22 prior_top=10.04 within +25% of entry=9.21
    PEN 2023-05-03 prior_top=305.99 within +25% of entry=294.41
    ON 2021-08-27 prior_top=45.28 within +25% of entry=44.99
    OKLO 2024-11-04 prior_top=21.67 within +25% of entry=19.27
    NATL 2025-08-11 prior_top=37.11 within +25% of entry=36.39
    MZTI 2022-10-26 prior_top=179.92 within +25% of entry=178.06
V10 EXPECTATION 6 violations (15 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    QBTS 2024-11-25 entry_wk_close=3.02 > prior=1.04 (spike>60%)
    OKLO 2024-11-04 entry_wk_close=24.47 > prior=9.15 (spike>60%)
    GSIT 2025-10-20 entry_wk_close=9.23 > prior=3.84 (spike>60%)
    CUTRQ 2022-03-28 entry_wk_close=72.31 > prior=40.49 (spike>60%)
    BTDR 2024-11-29 entry_wk_close=14.27 > prior=7.83 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 3 violations
    MNSO 2025-01-06 installed_stop=21.8750 vs fill=26.0100 -> dist=0.1590 > gate=0.1500
    LZB 2024-07-15 installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500
    EVCM 2026-01-07 installed_stop=10.4448 vs fill=12.3100 -> dist=0.1515 > gate=0.1500
V13 INVARIANT 2 violations (1 skipped)
    EC 2022-02-28 entry_price=14.7700 outside 2022-02-28 bar [15.4800, 16.1900]
    AAGIY 2023-01-04 entry_price=46.7300 outside 2023-01-04 bar [46.7310, 46.7310]
V14 EXPECTATION 15 violations
    URBN 2025-12-22 entry bar 2025-12-22 open=80.4200 low=79.8700 close=80.1200 vs stop=77.8715, exit=77.8100
    UMBF 2024-07-31 entry bar 2024-07-31 open=103.0000 low=100.7500 close=102.0200 vs stop=100.9806, exit=100.9500
    UEC 2021-10-18 entry bar 2021-10-18 open=3.4600 low=3.4300 close=3.4900 vs stop=3.3722, exit=3.3600
    TRMD 2024-01-24 entry bar 2024-01-24 open=36.5500 low=35.8800 close=35.9700 vs stop=35.3141, exit=35.2700
    QBTS 2024-11-25 entry bar 2024-11-25 open=3.4200 low=2.7000 close=2.8900 vs stop=2.8713, exit=2.7000
    NTRA 2021-09-23 entry bar 2021-09-23 open=125.6700 low=122.0250 close=123.5400 vs stop=122.7168, exit=121.9000
    MNDT 2022-03-07 entry bar 2022-03-07 open=19.3800 low=18.5450 close=22.4900 vs stop=21.9963, exit=21.7300
    IHT 2021-08-16 entry bar 2021-08-16 open=4.3500 low=4.0700 close=4.1900 vs stop=3.9342, exit=3.9300
    IBKR 2023-01-18 entry bar 2023-01-18 open=80.8200 low=75.8100 close=80.9300 vs stop=79.9051, exit=79.8500
    ENSG 2023-01-13 entry bar 2023-01-13 open=97.5000 low=97.5000 close=98.5300 vs stop=95.1900, exit=95.1500
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 6 violations
    ANIP 2024-03-04 median close 25.95 over 6150 bars (2001-07-24..2026-06-09); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    APLS 2021-06-16 median close 32.85 over 2155 bars (2017-11-09..2026-06-09); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0
    BOKF 2021-10-20 median close 49.74 over 8752 bars (1991-09-05..2026-06-09); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    CECO 2024-12-09 median close 4.59 over 11472 bars (1980-12-02..2026-06-09); bar 1992-09-29 close 2.66 (+399.96% vs prior close 0.53) on volume 0
    DUOT 2026-06-08 median close 2.71 over 3134 bars (2008-08-13..2026-06-09); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0
    NOKBF 2025-10-28 median close 5.96 over 4468 bars (2001-07-11..2026-06-09); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 137 violations
    XPOF 2023-01-27 LONG installed_stop 25.9488 vs screener_proxy_stop 24.8676: 4.35% tighter > 3%
    WSBC 2022-10-27 LONG installed_stop 38.4672 vs screener_proxy_stop 36.8644: 4.35% tighter > 3%
    VRSK 2023-06-05 LONG installed_stop 214.2912 vs screener_proxy_stop 205.3624: 4.35% tighter > 3%
    VRNS 2021-07-21 LONG installed_stop 58.4640 vs screener_proxy_stop 56.0280: 4.35% tighter > 3%
    VAL 2022-10-27 LONG installed_stop 61.2192 vs screener_proxy_stop 58.6684: 4.35% tighter > 3%
    URBN 2025-12-22 LONG installed_stop 77.8656 vs screener_proxy_stop 74.6212: 4.35% tighter > 3%
    UMBF 2024-07-31 LONG installed_stop 100.9824 vs screener_proxy_stop 96.7748: 4.35% tighter > 3%
    UE 2024-07-30 LONG installed_stop 19.3750 vs screener_proxy_stop 18.7956: 3.08% tighter > 3%
    TRMD 2024-01-24 LONG installed_stop 35.3088 vs screener_proxy_stop 33.8376: 4.35% tighter > 3%
    TDS 2023-08-28 LONG installed_stop 16.7232 vs screener_proxy_stop 16.0264: 4.35% tighter > 3%
V23 EXPECTATION 9 violations
    WSBC 2022-10-27 filled 2022-10-27 after the 2022-10-21 screen read Bearish
    VAL 2022-10-27 filled 2022-10-27 after the 2022-10-21 screen read Bearish
    MZTI 2022-10-26 filled 2022-10-26 after the 2022-10-21 screen read Bearish
    HLN 2025-05-02 filled 2025-05-02 after the 2025-04-25 screen read Bearish
    FSS 2022-11-10 filled 2022-11-10 after the 2022-11-04 screen read Bearish
    FN 2022-11-11 filled 2022-11-11 after the 2022-11-04 screen read Bearish
    EC 2022-02-28 filled 2022-02-28 after the 2022-02-25 screen read Bearish
    BMI 2022-10-26 filled 2022-10-26 after the 2022-10-21 screen read Bearish
    BBSI 2022-10-31 filled 2022-10-31 after the 2022-10-28 screen read Bearish
