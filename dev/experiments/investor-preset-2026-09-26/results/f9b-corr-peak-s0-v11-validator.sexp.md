# Post-run validation report

Invariant checks failing: 3
audit join: 190/190 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 23 violations
    XPOF 2023-01-27 Virgin_territory but only 79 weekly bars (< 520) before entry
    XERS 2024-02-14 Virgin_territory but only 297 weekly bars (< 520) before entry
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
    SHOP 2021-06-21 Virgin_territory but only 320 weekly bars (< 520) before entry
    ROKU 2021-07-27 Virgin_territory but only 202 weekly bars (< 520) before entry
    NTRA 2021-09-23 Virgin_territory but only 327 weekly bars (< 520) before entry
    NEXT 2025-01-16 Virgin_territory but only 469 weekly bars (< 520) before entry
    MIRM 2022-08-05 Virgin_territory but only 160 weekly bars (< 520) before entry
    LQDA 2023-06-02 Virgin_territory but only 255 weekly bars (< 520) before entry
    LBRT 2023-10-18 Virgin_territory but only 303 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 42 violations (16 skipped)
    VRNS 2021-07-21 prior_top=71.50 within +25% of entry=60.93
    URBN 2025-12-22 prior_top=81.84 within +25% of entry=81.11
    UMAC 2026-01-15 prior_top=18.73 within +25% of entry=17.69
    STVN 2023-03-02 prior_top=28.27 within +25% of entry=23.43
    PTGX 2025-06-02 prior_top=54.78 within +25% of entry=49.15
    PEN 2023-05-03 prior_top=305.99 within +25% of entry=294.35
    ON 2021-08-27 prior_top=45.28 within +25% of entry=44.85
    OKLO 2024-11-04 prior_top=21.67 within +25% of entry=19.27
    NATL 2025-08-11 prior_top=37.11 within +25% of entry=36.39
    MZTI 2022-10-26 prior_top=179.92 within +25% of entry=178.21
V10 EXPECTATION 6 violations (16 skipped)
    VUZI 2026-05-29 entry_wk_close=4.60 > prior=2.84 (spike>60%)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    OKLO 2024-11-04 entry_wk_close=24.47 > prior=9.15 (spike>60%)
    GSIT 2025-10-20 entry_wk_close=9.23 > prior=3.84 (spike>60%)
    EOSE 2023-06-28 entry_wk_close=4.34 > prior=2.43 (spike>60%)
    BTDR 2024-11-29 entry_wk_close=14.27 > prior=7.83 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 1 violations
    LZB 2024-07-15 installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500
V13 INVARIANT 5 violations (1 skipped)
    HZNP 2023-10-09 no bar on exit_date 2023-10-10 (nearest earlier bar: 2023-10-09)
    EC 2022-02-28 entry_price=14.7700 outside 2022-02-28 bar [15.4800, 16.1900]
    CRCT 2025-07-02 entry_price=6.3700 outside 2025-07-02 bar [6.9100, 7.2150]
    AZPN 2025-01-30 no bar on exit_date 2025-03-13 (nearest earlier bar: 2025-03-12)
    AAGIY 2023-01-04 entry_price=46.7300 outside 2023-01-04 bar [46.7310, 46.7310]
V14 EXPECTATION 20 violations
    WLFC 2026-04-15 entry bar 2026-04-15 open=210.8800 low=208.0900 close=209.7000 vs stop=203.3697, exit=203.3700
    VUZI 2026-05-29 entry bar 2026-05-29 open=4.5200 low=4.2200 close=4.6000 vs stop=4.1413, exit=4.0400
    UTL 2022-07-01 entry bar 2022-07-01 open=58.7100 low=58.0800 close=61.0000 vs stop=57.2322, exit=57.1400
    URBN 2025-12-22 entry bar 2025-12-22 open=80.4200 low=79.8700 close=80.1200 vs stop=77.8656, exit=77.8600
    UEC 2021-10-18 entry bar 2021-10-18 open=3.4600 low=3.4300 close=3.4900 vs stop=3.3780, exit=3.3500
    UEC 2022-04-08 entry bar 2022-04-08 open=5.5500 low=5.3400 close=5.5000 vs stop=5.3721, exit=5.3600
    SDA 2023-07-12 entry bar 2023-07-12 open=14.1500 low=11.5500 close=11.7000 vs stop=10.4919, exit=10.4400
    ODFL 2023-02-02 entry bar 2023-02-02 open=373.2500 low=368.7600 close=371.4100 vs stop=360.4329, exit=360.4100
    NTRA 2021-09-23 entry bar 2021-09-23 open=125.6700 low=122.0250 close=123.5400 vs stop=122.7168, exit=121.9000
    INOD 2024-06-06 entry bar 2024-06-06 open=14.9100 low=14.7634 close=15.1600 vs stop=14.8200, exit=14.7500
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 5 violations
    ANIP 2024-03-04 median close 25.95 over 6150 bars (2001-07-24..2026-06-09); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    APLS 2021-06-16 median close 32.85 over 2155 bars (2017-11-09..2026-06-09); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0
    BOKF 2021-10-20 median close 49.74 over 8752 bars (1991-09-05..2026-06-09); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    DUOT 2026-06-08 median close 2.71 over 3134 bars (2008-08-13..2026-06-09); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0
    NOKBF 2025-10-28 median close 5.96 over 4468 bars (2001-07-11..2026-06-09); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0
