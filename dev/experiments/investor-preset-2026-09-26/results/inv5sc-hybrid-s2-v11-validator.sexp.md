# Post-run validation report

Invariant checks failing: 3
audit join: 199/199 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 24 violations
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
    TRMD 2024-01-24 Virgin_territory but only 311 weekly bars (< 520) before entry
    SHOP 2021-06-21 Virgin_territory but only 320 weekly bars (< 520) before entry
    ROKU 2021-07-27 Virgin_territory but only 202 weekly bars (< 520) before entry
    NTRA 2021-09-23 Virgin_territory but only 327 weekly bars (< 520) before entry
    NEXT 2025-01-16 Virgin_territory but only 469 weekly bars (< 520) before entry
    NET 2024-12-17 Virgin_territory but only 276 weekly bars (< 520) before entry
    MNDT 2022-03-07 Virgin_territory but only 446 weekly bars (< 520) before entry
    LQDA 2023-06-02 Virgin_territory but only 255 weekly bars (< 520) before entry
    LBRT 2023-10-18 Virgin_territory but only 303 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 47 violations (16 skipped)
    VRNS 2021-07-21 prior_top=71.50 within +25% of entry=60.99
    URBN 2025-03-13 prior_top=58.19 within +25% of entry=50.12
    URBN 2025-12-22 prior_top=81.84 within +25% of entry=81.28
    UMAC 2026-01-15 prior_top=18.73 within +25% of entry=17.82
    STVN 2023-03-02 prior_top=28.27 within +25% of entry=23.47
    RYAN 2024-04-04 prior_top=54.48 within +25% of entry=51.91
    ROST 2023-11-14 prior_top=125.52 within +25% of entry=124.00
    PTGX 2025-06-02 prior_top=54.78 within +25% of entry=49.17
    PJT 2023-11-03 prior_top=84.12 within +25% of entry=83.64
    PEN 2023-05-03 prior_top=305.99 within +25% of entry=294.56
V10 EXPECTATION 8 violations (16 skipped)
    VTNRQ 2022-05-16 entry_wk_close=14.40 > prior=8.84 (spike>60%)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    OKLO 2024-11-04 entry_wk_close=24.47 > prior=9.15 (spike>60%)
    ISEE 2022-09-30 entry_wk_close=17.94 > prior=9.44 (spike>60%)
    GSIT 2025-10-20 entry_wk_close=9.23 > prior=3.84 (spike>60%)
    GRPN 2025-03-26 entry_wk_close=18.82 > prior=11.12 (spike>60%)
    CUTRQ 2022-03-28 entry_wk_close=72.31 > prior=40.49 (spike>60%)
    BTDR 2024-11-29 entry_wk_close=14.27 > prior=7.83 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 3 violations
    SOUN 2024-04-02 installed_stop=4.3750 vs fill=5.2400 -> dist=0.1651 > gate=0.1500
    LZB 2024-07-15 installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500
    DAR 2022-04-20 installed_stop=73.4880 vs fill=86.4900 -> dist=0.1503 > gate=0.1500
V13 INVARIANT 5 violations (1 skipped)
    KD 2023-09-11 entry_price=17.3200 outside 2023-09-11 bar [16.7000, 17.3190]
    HZNP 2023-10-09 no bar on exit_date 2023-10-10 (nearest earlier bar: 2023-10-09)
    GERN 2024-04-11 entry_price=3.7900 outside 2024-04-11 bar [3.4400, 3.7860]
    CRCT 2025-07-02 entry_price=6.3600 outside 2025-07-02 bar [6.9100, 7.2150]
    AAGIY 2023-01-04 entry_price=46.7300 outside 2023-01-04 bar [46.7310, 46.7310]
V14 EXPECTATION 21 violations
    URBN 2025-12-22 entry bar 2025-12-22 open=80.4200 low=79.8700 close=80.1200 vs stop=77.8662, exit=77.7900
    UMBF 2024-07-31 entry bar 2024-07-31 open=103.0000 low=100.7500 close=102.0200 vs stop=100.9815, exit=100.5300
    UEC 2021-10-18 entry bar 2021-10-18 open=3.4600 low=3.4300 close=3.4900 vs stop=3.3749, exit=3.3300
    TRMD 2024-01-24 entry bar 2024-01-24 open=36.5500 low=35.8800 close=35.9700 vs stop=35.3118, exit=35.2700
    TGLS 2023-01-27 entry bar 2023-01-27 open=33.8000 low=33.4600 close=33.7600 vs stop=33.6658, exit=33.5400
    QFIN 2024-04-11 entry bar 2024-04-11 open=20.2000 low=19.9400 close=20.0000 vs stop=19.6766, exit=19.2500
    NTRA 2021-09-23 entry bar 2021-09-23 open=125.6700 low=122.0250 close=123.5400 vs stop=122.7232, exit=121.9000
    NET 2024-12-17 entry bar 2024-12-17 open=118.2300 low=116.0101 close=117.5600 vs stop=111.9165, exit=111.8900
    MNDT 2022-03-07 entry bar 2022-03-07 open=19.3800 low=18.5450 close=22.4900 vs stop=21.9988, exit=21.7300
    INOD 2024-06-06 entry bar 2024-06-06 open=14.9100 low=14.7634 close=15.1600 vs stop=14.8247, exit=14.7700
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 8 violations
    APLS 2021-06-16 median close 32.72 over 2165 bars (2017-11-09..2026-06-23); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0
    ATLKY 2026-01-15 median close 24.88 over 7445 bars (1996-11-18..2026-06-23); bar 2003-09-01 close 1000000.00 (+3311246.00% vs prior close 30.20) on volume 0
    BOKF 2021-10-20 median close 49.76 over 8761 bars (1991-09-05..2026-06-23); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    CECO 2024-12-09 median close 4.62 over 11481 bars (1980-12-02..2026-06-23); bar 1992-09-29 close 2.66 (+399.96% vs prior close 0.53) on volume 0
    DUOT 2026-06-08 median close 2.72 over 3143 bars (2008-08-13..2026-06-23); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0
    IHG 2024-10-15 median close 37.44 over 5838 bars (2003-04-08..2026-06-23); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0
    NOKBF 2025-10-28 median close 5.97 over 4477 bars (2001-07-11..2026-06-23); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0
    VTNRQ 2022-05-16 median close 1.36 over 7522 bars (1992-10-21..2025-01-21); bar 2003-11-11 close 0.00 (-90.00% vs prior close 0.02) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 146 violations
    VTNRQ 2022-05-16 LONG installed_stop 13.8144 vs screener_proxy_stop 13.2388: 4.35% tighter > 3%
    VRSK 2023-06-05 LONG installed_stop 214.2912 vs screener_proxy_stop 205.3624: 4.35% tighter > 3%
    VRNS 2021-07-21 LONG installed_stop 58.4640 vs screener_proxy_stop 56.0280: 4.35% tighter > 3%
    VAL 2022-10-27 LONG installed_stop 61.2192 vs screener_proxy_stop 58.6684: 4.35% tighter > 3%
    UUUU 2025-08-26 LONG installed_stop 10.9920 vs screener_proxy_stop 10.5340: 4.35% tighter > 3%
    URBN 2025-03-13 LONG installed_stop 47.1744 vs screener_proxy_stop 45.2088: 4.35% tighter > 3%
    URBN 2025-12-22 LONG installed_stop 77.8656 vs screener_proxy_stop 74.6212: 4.35% tighter > 3%
    UMBF 2024-07-31 LONG installed_stop 100.9824 vs screener_proxy_stop 96.7748: 4.35% tighter > 3%
    UMAC 2026-01-15 LONG installed_stop 16.8672 vs screener_proxy_stop 16.1644: 4.35% tighter > 3%
    TRMD 2024-01-24 LONG installed_stop 35.3088 vs screener_proxy_stop 33.8376: 4.35% tighter > 3%
V23 EXPECTATION 11 violations
    VTNRQ 2022-05-16 filled 2022-05-16 after the 2022-05-13 screen read Bearish
    VAL 2022-10-27 filled 2022-10-27 after the 2022-10-21 screen read Bearish
    STN 2025-05-01 filled 2025-05-01 after the 2025-04-25 screen read Bearish
    ISEE 2022-09-30 filled 2022-09-30 after the 2022-09-23 screen read Bearish
    HLN 2025-05-02 filled 2025-05-02 after the 2025-04-25 screen read Bearish
    FSS 2022-11-10 filled 2022-11-10 after the 2022-11-04 screen read Bearish
    FN 2022-11-11 filled 2022-11-11 after the 2022-11-04 screen read Bearish
    BMI 2022-10-26 filled 2022-10-26 after the 2022-10-21 screen read Bearish
    BBSI 2022-10-31 filled 2022-10-31 after the 2022-10-28 screen read Bearish
    ARGX 2022-06-21 filled 2022-06-21 after the 2022-06-17 screen read Bearish
