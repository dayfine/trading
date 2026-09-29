# Post-run validation report

Invariant checks failing: 3
audit join: 191/191 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 26 violations
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
    UE 2024-07-30 Virgin_territory but only 501 weekly bars (< 520) before entry
    TRMD 2024-01-24 Virgin_territory but only 311 weekly bars (< 520) before entry
    TOST 2023-07-13 Virgin_territory but only 94 weekly bars (< 520) before entry
    SHOP 2021-06-21 Virgin_territory but only 320 weekly bars (< 520) before entry
    ROKU 2021-07-27 Virgin_territory but only 202 weekly bars (< 520) before entry
    QBTS 2024-11-25 Virgin_territory but only 207 weekly bars (< 520) before entry
    NTRA 2021-09-23 Virgin_territory but only 327 weekly bars (< 520) before entry
    NEXT 2025-01-16 Virgin_territory but only 469 weekly bars (< 520) before entry
    MNDT 2022-03-07 Virgin_territory but only 446 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 45 violations (18 skipped)
    ZGN 2023-09-08 prior_top=15.43 within +25% of entry=14.25
    VRNS 2021-07-21 prior_top=71.50 within +25% of entry=60.93
    URBN 2025-12-22 prior_top=81.84 within +25% of entry=81.11
    ROST 2023-11-14 prior_top=125.52 within +25% of entry=124.00
    PTGX 2025-06-02 prior_top=54.78 within +25% of entry=49.15
    PSLV 2024-04-22 prior_top=10.04 within +25% of entry=9.21
    PEN 2023-05-03 prior_top=305.99 within +25% of entry=294.35
    ORCL 2024-08-05 prior_top=141.64 within +25% of entry=128.84
    ON 2021-08-27 prior_top=45.28 within +25% of entry=44.85
    OKLO 2024-11-04 prior_top=21.67 within +25% of entry=19.27
V10 EXPECTATION 6 violations (18 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    QBTS 2024-11-25 entry_wk_close=3.02 > prior=1.04 (spike>60%)
    OKLO 2024-11-04 entry_wk_close=24.47 > prior=9.15 (spike>60%)
    GSIT 2025-10-20 entry_wk_close=9.23 > prior=3.84 (spike>60%)
    GRPN 2025-03-26 entry_wk_close=18.82 > prior=11.12 (spike>60%)
    BTDR 2024-11-29 entry_wk_close=14.27 > prior=7.83 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 2 violations
    MNSO 2025-01-06 installed_stop=21.8750 vs fill=26.0100 -> dist=0.1590 > gate=0.1500
    LZB 2024-07-15 installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500
V13 INVARIANT 3 violations (1 skipped)
    EC 2022-02-28 entry_price=14.7700 outside 2022-02-28 bar [15.4800, 16.1900]
    CIG 2022-04-12 exit_price=3.1700 outside 2022-04-19 bar [3.1701, 3.3500]
    AAGIY 2023-01-04 entry_price=46.7300 outside 2023-01-04 bar [46.7310, 46.7310]
V14 EXPECTATION 21 violations
    URBN 2025-12-22 entry bar 2025-12-22 open=80.4200 low=79.8700 close=80.1200 vs stop=77.8656, exit=77.8600
    UMBF 2024-07-31 entry bar 2024-07-31 open=103.0000 low=100.7500 close=102.0200 vs stop=100.9806, exit=100.8300
    UEC 2021-10-18 entry bar 2021-10-18 open=3.4600 low=3.4300 close=3.4900 vs stop=3.3780, exit=3.3500
    UEC 2022-04-08 entry bar 2022-04-08 open=5.5500 low=5.3400 close=5.5000 vs stop=5.3721, exit=5.3600
    TRMD 2024-01-24 entry bar 2024-01-24 open=36.5500 low=35.8800 close=35.9700 vs stop=35.3096, exit=35.2700
    TOST 2023-07-13 entry bar 2023-07-13 open=24.9900 low=24.9000 close=25.9100 vs stop=24.8765, exit=24.8100
    TGLS 2023-01-27 entry bar 2023-01-27 open=33.8000 low=33.4600 close=33.7600 vs stop=33.6642, exit=33.6300
    RCAT 2026-03-06 entry bar 2026-03-06 open=14.6100 low=14.6100 close=15.3600 vs stop=14.8727, exit=14.8200
    QBTS 2024-11-25 entry bar 2024-11-25 open=3.4200 low=2.7000 close=2.8900 vs stop=2.8713, exit=2.7000
    ODFL 2023-02-02 entry bar 2023-02-02 open=373.2500 low=368.7600 close=371.4100 vs stop=360.4329, exit=360.4100
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 6 violations
    ANIP 2024-03-04 median close 25.92 over 6149 bars (2001-07-24..2026-06-08); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    APLS 2021-06-16 median close 32.88 over 2154 bars (2017-11-09..2026-06-08); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0
    BOKF 2021-10-20 median close 49.73 over 8751 bars (1991-09-05..2026-06-08); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    LNG 2026-03-16 median close 27.68 over 8099 bars (1994-04-04..2026-06-08); bar 1994-07-19 close 6.00 (+500.00% vs prior close 1.00) on volume 0
    NOKBF 2025-10-28 median close 5.96 over 4467 bars (2001-07-11..2026-06-08); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0
    RCAT 2026-03-06 median close 0.02 over 7326 bars (1995-11-27..2026-06-08); bar 1996-04-10 close 5.00 (+7900.32% vs prior close 0.06) on volume 0
