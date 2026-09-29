# Post-run validation report

Invariant checks failing: 3
audit join: 196/196 rows matched

QUALITY-FLAG: 1 fallback exits (V16)

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 23 violations
    XERS 2024-02-14 Virgin_territory but only 297 weekly bars (< 520) before entry
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
    TWLO 2026-04-22 Virgin_territory but only 517 weekly bars (< 520) before entry
    SHOP 2021-06-21 Virgin_territory but only 320 weekly bars (< 520) before entry
    ROKU 2021-07-27 Virgin_territory but only 202 weekly bars (< 520) before entry
    REAL 2025-10-03 Virgin_territory but only 329 weekly bars (< 520) before entry
    NTRA 2021-09-23 Virgin_territory but only 327 weekly bars (< 520) before entry
    NEXT 2025-01-16 Virgin_territory but only 469 weekly bars (< 520) before entry
    MNDT 2022-03-07 Virgin_territory but only 446 weekly bars (< 520) before entry
    LQDA 2023-06-02 Virgin_territory but only 255 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 52 violations (17 skipped)
    ZGN 2023-09-08 prior_top=15.43 within +25% of entry=14.25
    VRNS 2021-07-21 prior_top=71.50 within +25% of entry=60.93
    URBN 2025-12-22 prior_top=81.84 within +25% of entry=81.11
    RYAN 2024-04-04 prior_top=54.48 within +25% of entry=51.91
    ROST 2023-11-14 prior_top=125.52 within +25% of entry=124.00
    PTGX 2025-06-02 prior_top=54.78 within +25% of entry=49.15
    PJT 2023-11-03 prior_top=84.12 within +25% of entry=83.60
    PEN 2023-05-03 prior_top=305.99 within +25% of entry=294.35
    OWL 2025-03-03 prior_top=23.98 within +25% of entry=20.63
    ORCL 2024-08-05 prior_top=141.64 within +25% of entry=128.84
V10 EXPECTATION 4 violations (17 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    OKLO 2024-11-04 entry_wk_close=24.47 > prior=9.15 (spike>60%)
    GSIT 2025-10-20 entry_wk_close=9.23 > prior=3.84 (spike>60%)
    GRPN 2025-03-26 entry_wk_close=18.82 > prior=11.12 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 3 violations
    VLN 2026-05-26 installed_stop=2.9136 vs fill=3.4300 -> dist=0.1506 > gate=0.1500
    LZB 2024-07-15 installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500
    LPG 2023-09-15 installed_stop=23.2022 vs fill=27.3000 -> dist=0.1501 > gate=0.1500
V13 INVARIANT 5 violations (1 skipped)
    HZNP 2023-10-09 no bar on exit_date 2023-10-10 (nearest earlier bar: 2023-10-09)
    EC 2022-02-28 entry_price=14.7700 outside 2022-02-28 bar [15.4800, 16.1900]
    CIG 2022-04-12 exit_price=3.1700 outside 2022-04-19 bar [3.1701, 3.3500]
    CHS 2023-10-23 no bar on exit_date 2024-01-05 (nearest earlier bar: 2024-01-04)
    AAGIY 2023-01-04 entry_price=46.7300 outside 2023-01-04 bar [46.7310, 46.7310]
V14 EXPECTATION 21 violations
    URBN 2025-12-22 entry bar 2025-12-22 open=80.4200 low=79.8700 close=80.1200 vs stop=77.8656, exit=77.8600
    UEC 2021-10-18 entry bar 2021-10-18 open=3.4600 low=3.4300 close=3.4900 vs stop=3.3780, exit=3.3500
    UEC 2022-04-08 entry bar 2022-04-08 open=5.5500 low=5.3400 close=5.5000 vs stop=5.3721, exit=5.3600
    TWLO 2026-04-22 entry bar 2026-04-22 open=152.1100 low=146.8600 close=150.4500 vs stop=146.3824, exit=146.3600
    TGLS 2023-01-27 entry bar 2023-01-27 open=33.8000 low=33.4600 close=33.7600 vs stop=33.6642, exit=33.6300
    REAL 2025-10-03 entry bar 2025-10-03 open=11.2500 low=10.8950 close=10.9900 vs stop=10.9744, exit=10.8500
    QFIN 2024-04-11 entry bar 2024-04-11 open=20.2000 low=19.9400 close=20.0000 vs stop=19.6773, exit=19.2500
    OWL 2025-03-03 entry bar 2025-03-03 open=21.6800 low=20.5900 close=20.8300 vs stop=19.4170, exit=19.4100
    ODFL 2023-02-02 entry bar 2023-02-02 open=373.2500 low=368.7600 close=371.4100 vs stop=360.4329, exit=360.4100
    NTRA 2021-09-23 entry bar 2021-09-23 open=125.6700 low=122.0250 close=123.5400 vs stop=122.7168, exit=121.9000
V15 EXPECTATION PASS
V16 EXPECTATION 1 violations
    TIPT 2025-09-25 force_liquidation exit 2025-09-26 (entry 2025-09-25 @ 27.11, exit @ 20.00)
V17 EXPECTATION PASS
V18 EXPECTATION 7 violations
    ANIP 2024-04-01 median close 26.24 over 6159 bars (2001-07-24..2026-06-23); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    APLS 2021-06-16 median close 32.72 over 2165 bars (2017-11-09..2026-06-23); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0
    ATLKY 2026-01-15 median close 24.88 over 7445 bars (1996-11-18..2026-06-23); bar 2003-09-01 close 1000000.00 (+3311246.00% vs prior close 30.20) on volume 0
    BOKF 2021-10-20 median close 49.76 over 8761 bars (1991-09-05..2026-06-23); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    DUOT 2026-06-08 median close 2.72 over 3143 bars (2008-08-13..2026-06-23); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0
    IHG 2024-10-15 median close 37.44 over 5838 bars (2003-04-08..2026-06-23); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0
    NOKBF 2025-10-28 median close 5.97 over 4477 bars (2001-07-11..2026-06-23); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0
