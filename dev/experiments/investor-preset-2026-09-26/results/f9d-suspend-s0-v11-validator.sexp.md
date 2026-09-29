# Post-run validation report

Invariant checks failing: 3
audit join: 154/203 rows matched

V1 INVARIANT PASS (49 skipped)
V2 INVARIANT PASS (49 skipped)
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 19 violations (49 skipped)
    TWLO 2026-04-22 Virgin_territory but only 517 weekly bars (< 520) before entry
    TRMD 2024-01-24 Virgin_territory but only 311 weekly bars (< 520) before entry
    TOST 2023-07-13 Virgin_territory but only 94 weekly bars (< 520) before entry
    SHOP 2021-06-21 Virgin_territory but only 320 weekly bars (< 520) before entry
    ROKU 2021-07-27 Virgin_territory but only 202 weekly bars (< 520) before entry
    NTRA 2021-09-23 Virgin_territory but only 327 weekly bars (< 520) before entry
    NEXT 2025-01-16 Virgin_territory but only 469 weekly bars (< 520) before entry
    MNSO 2025-01-06 Virgin_territory but only 222 weekly bars (< 520) before entry
    MNDT 2022-03-07 Virgin_territory but only 446 weekly bars (< 520) before entry
    LQDA 2023-06-02 Virgin_territory but only 255 weekly bars (< 520) before entry
V8 EXPECTATION PASS (49 skipped)
V9 EXPECTATION 46 violations (19 skipped)
    ZGN 2023-09-08 prior_top=15.43 within +25% of entry=14.25
    VRNS 2021-07-21 prior_top=71.50 within +25% of entry=60.93
    VAL 2022-11-18 prior_top=67.75 within +25% of entry=65.05
    URBN 2025-03-13 prior_top=58.19 within +25% of entry=50.12
    URBN 2025-12-22 prior_top=81.84 within +25% of entry=81.11
    UMAC 2026-01-15 prior_top=18.73 within +25% of entry=17.69
    STVN 2023-03-02 prior_top=28.27 within +25% of entry=23.43
    STN 2026-02-12 prior_top=111.40 within +25% of entry=90.64
    PTGX 2025-06-02 prior_top=54.78 within +25% of entry=49.15
    PENG 2026-04-27 prior_top=35.49 within +25% of entry=30.55
V10 EXPECTATION 3 violations (19 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    GSIT 2025-10-20 entry_wk_close=9.23 > prior=3.84 (spike>60%)
    EOSE 2023-06-27 entry_wk_close=4.34 > prior=2.43 (spike>60%)
V11 EXPECTATION PASS (49 skipped)
V12 INVARIANT 3 violations (49 skipped)
    MNSO 2025-01-06 installed_stop=21.8400 vs fill=26.0100 -> dist=0.1603 > gate=0.1500
    LZB 2024-07-15 installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500
    EVCM 2026-01-20 installed_stop=10.4448 vs fill=12.5200 -> dist=0.1658 > gate=0.1500
V13 INVARIANT 5 violations (1 skipped)
    HZNP 2023-10-09 no bar on exit_date 2023-10-10 (nearest earlier bar: 2023-10-09)
    EC 2022-03-15 entry_price=15.0600 outside 2022-03-15 bar [15.9500, 16.7200]
    CIG 2022-04-12 exit_price=3.1700 outside 2022-04-19 bar [3.1701, 3.3500]
    BAESY 2023-10-25 entry_price=53.2200 outside 2023-10-25 bar [53.2150, 53.2150]
    AAGIY 2023-01-04 entry_price=46.7300 outside 2023-01-04 bar [46.7310, 46.7310]
V14 EXPECTATION 18 violations (9 skipped)
    WLFC 2026-04-15 entry bar 2026-04-15 open=210.8800 low=208.0900 close=209.7000 vs stop=203.3697, exit=203.3700
    URBN 2025-12-22 entry bar 2025-12-22 open=80.4200 low=79.8700 close=80.1200 vs stop=77.8656, exit=77.8600
    UMBF 2024-07-31 entry bar 2024-07-31 open=103.0000 low=100.7500 close=102.0200 vs stop=100.9806, exit=100.8300
    UEC 2021-10-18 entry bar 2021-10-18 open=3.4600 low=3.4300 close=3.4900 vs stop=3.3780, exit=3.3500
    UEC 2022-04-08 entry bar 2022-04-08 open=5.5500 low=5.3400 close=5.5000 vs stop=5.3721, exit=5.3600
    TWLO 2026-04-22 entry bar 2026-04-22 open=152.1100 low=146.8600 close=150.4500 vs stop=146.3824, exit=146.3600
    TRMD 2024-01-24 entry bar 2024-01-24 open=36.5500 low=35.8800 close=35.9700 vs stop=35.3096, exit=35.2700
    TOST 2023-07-13 entry bar 2023-07-13 open=24.9900 low=24.9000 close=25.9100 vs stop=24.8765, exit=24.8100
    RCAT 2026-03-06 entry bar 2026-03-06 open=14.6100 low=14.6100 close=15.3600 vs stop=14.8727, exit=14.8200
    QFIN 2024-04-11 entry bar 2024-04-11 open=20.2000 low=19.9400 close=20.0000 vs stop=19.6773, exit=19.2500
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 8 violations
    ANIP 2024-03-04 median close 25.95 over 6150 bars (2001-07-24..2026-06-09); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    APLS 2021-06-16 median close 32.85 over 2155 bars (2017-11-09..2026-06-09); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0
    BOKF 2021-10-20 median close 49.74 over 8752 bars (1991-09-05..2026-06-09); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    DUOT 2026-06-08 median close 2.71 over 3134 bars (2008-08-13..2026-06-09); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0
    NOKBF 2025-10-28 median close 5.96 over 4468 bars (2001-07-11..2026-06-09); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0
    PECO 2023-07-24 median close 34.08 over 1328 bars (2021-02-25..2026-06-09); bar 2021-07-06 close 21.69 (+800.00% vs prior close 2.41) on volume 0
    RCAT 2026-03-06 median close 0.02 over 7327 bars (1995-11-27..2026-06-09); bar 1996-04-10 close 5.00 (+7900.32% vs prior close 0.06) on volume 0
    VTNRQ 2022-05-31 median close 1.36 over 7522 bars (1992-10-21..2025-01-21); bar 2003-11-11 close 0.00 (-90.00% vs prior close 0.02) on volume 0
