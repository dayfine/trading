# Post-run validation report

Invariant checks failing: 3
audit join: 206/206 rows matched

QUALITY-FLAG: 1 fallback exits (V16)

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 31 violations
    XPOF 2023-01-27 Virgin_territory but only 79 weekly bars (< 520) before entry
    XERS 2024-02-14 Virgin_territory but only 297 weekly bars (< 520) before entry
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
    TWLO 2026-04-22 Virgin_territory but only 517 weekly bars (< 520) before entry
    SYRE 2026-02-20 Virgin_territory but only 519 weekly bars (< 520) before entry
    SNOW 2025-08-28 Virgin_territory but only 259 weekly bars (< 520) before entry
    SHOP 2021-06-21 Virgin_territory but only 320 weekly bars (< 520) before entry
    ROKU 2021-07-27 Virgin_territory but only 202 weekly bars (< 520) before entry
    REAL 2025-10-03 Virgin_territory but only 329 weekly bars (< 520) before entry
    NXE 2022-04-13 Virgin_territory but only 456 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 43 violations (18 skipped)
    ZGN 2023-09-08 prior_top=15.43 within +25% of entry=14.25
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.75
    VRNS 2021-07-21 prior_top=71.50 within +25% of entry=60.93
    URBN 2025-12-22 prior_top=81.84 within +25% of entry=81.11
    SAND 2025-06-02 prior_top=9.56 within +25% of entry=9.14
    PTGX 2025-06-02 prior_top=54.78 within +25% of entry=49.15
    PJT 2023-11-03 prior_top=84.12 within +25% of entry=83.60
    ON 2021-08-27 prior_top=45.28 within +25% of entry=44.85
    NATL 2025-08-11 prior_top=37.11 within +25% of entry=36.39
    MZTI 2022-10-26 prior_top=179.92 within +25% of entry=178.21
V10 EXPECTATION 5 violations (18 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    GSIT 2025-10-20 entry_wk_close=9.23 > prior=3.84 (spike>60%)
    GRPN 2025-03-26 entry_wk_close=18.82 > prior=11.12 (spike>60%)
    EOSE 2023-06-28 entry_wk_close=4.34 > prior=2.43 (spike>60%)
    BTDR 2024-11-29 entry_wk_close=14.27 > prior=7.83 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 4 violations
    YMM 2024-11-20 installed_stop=8.2848 vs fill=9.7700 -> dist=0.1520 > gate=0.1500
    VLN 2026-05-26 installed_stop=2.9136 vs fill=3.4300 -> dist=0.1506 > gate=0.1500
    SOUN 2024-04-02 installed_stop=4.3750 vs fill=5.2400 -> dist=0.1651 > gate=0.1500
    LZB 2024-07-15 installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500
V13 INVARIANT 7 violations (1 skipped)
    NTTYY 2024-01-16 entry_price=31.7800 outside 2024-01-16 bar [31.7820, 31.7820]
    HZNP 2023-10-09 no bar on exit_date 2023-10-10 (nearest earlier bar: 2023-10-09)
    EC 2022-02-28 entry_price=14.7700 outside 2022-02-28 bar [15.4800, 16.1900]
    CRCT 2025-07-02 entry_price=6.3700 outside 2025-07-02 bar [6.9100, 7.2150]
    CHS 2023-10-23 no bar on exit_date 2024-01-05 (nearest earlier bar: 2024-01-04)
    AZPN 2025-01-30 no bar on exit_date 2025-03-13 (nearest earlier bar: 2025-03-12)
    AAGIY 2023-01-04 entry_price=46.7300 outside 2023-01-04 bar [46.7310, 46.7310]
V14 EXPECTATION 24 violations
    UTL 2022-07-01 entry bar 2022-07-01 open=58.7100 low=58.0800 close=61.0000 vs stop=57.2322, exit=57.1400
    URBN 2025-12-22 entry bar 2025-12-22 open=80.4200 low=79.8700 close=80.1200 vs stop=77.8656, exit=77.8600
    UMBF 2024-07-31 entry bar 2024-07-31 open=103.0000 low=100.7500 close=102.0200 vs stop=100.9806, exit=100.8300
    UEC 2021-10-18 entry bar 2021-10-18 open=3.4600 low=3.4300 close=3.4900 vs stop=3.3780, exit=3.3500
    TWLO 2026-04-22 entry bar 2026-04-22 open=152.1100 low=146.8600 close=150.4500 vs stop=146.3824, exit=146.3600
    TGLS 2023-01-27 entry bar 2023-01-27 open=33.8000 low=33.4600 close=33.7600 vs stop=33.6642, exit=33.6300
    REAL 2025-10-03 entry bar 2025-10-03 open=11.2500 low=10.8950 close=10.9900 vs stop=10.9744, exit=10.8500
    ODFL 2023-02-02 entry bar 2023-02-02 open=373.2500 low=368.7600 close=371.4100 vs stop=360.4329, exit=360.4100
    NXE 2022-04-13 entry bar 2022-04-13 open=6.3000 low=6.2820 close=6.3300 vs stop=6.2666, exit=6.2200
    NTRA 2021-09-23 entry bar 2021-09-23 open=125.6700 low=122.0250 close=123.5400 vs stop=122.7168, exit=121.9000
V15 EXPECTATION PASS
V16 EXPECTATION 1 violations
    TIPT 2025-09-25 force_liquidation exit 2025-09-26 (entry 2025-09-25 @ 27.11, exit @ 20.00)
V17 EXPECTATION PASS
V18 EXPECTATION 4 violations
    ANIP 2024-03-04 median close 25.92 over 6149 bars (2001-07-24..2026-06-08); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    APLS 2021-06-16 median close 32.88 over 2154 bars (2017-11-09..2026-06-08); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0
    BOKF 2021-10-20 median close 49.73 over 8751 bars (1991-09-05..2026-06-08); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    NOKBF 2025-10-28 median close 5.96 over 4467 bars (2001-07-11..2026-06-08); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0
