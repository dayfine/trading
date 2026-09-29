# Post-run validation report

Invariant checks failing: 3
audit join: 125/125 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT 1 violations
    GOOG 2025-01-03 twin positions: GOOG/GOOGL
V7 INVARIANT 1 violations
    XERS 2024-02-14 Virgin_territory but only 297 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 31 violations (12 skipped)
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.74
    WOLF_old2 2021-11-22 prior_top=139.55 within +25% of entry=133.00
    URBN 2026-01-06 prior_top=81.84 within +25% of entry=81.19
    UA 2021-11-22 prior_top=27.04 within +25% of entry=22.69
    PTGX 2025-06-02 prior_top=54.78 within +25% of entry=49.19
    PJT 2023-11-03 prior_top=84.12 within +25% of entry=83.64
    ON 2021-08-27 prior_top=45.28 within +25% of entry=44.99
    MSEX 2022-04-27 prior_top=109.11 within +25% of entry=89.30
    MMYT 2023-10-26 prior_top=40.52 within +25% of entry=37.63
    MEOH 2024-04-25 prior_top=52.47 within +25% of entry=49.91
V10 EXPECTATION 1 violations (12 skipped)
    ISEE 2022-09-30 entry_wk_close=17.94 > prior=9.44 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 4 violations
    XERS 2024-02-14 installed_stop=2.6496 vs fill=3.1500 -> dist=0.1589 > gate=0.1500
    VLN 2026-05-26 installed_stop=2.9136 vs fill=3.4300 -> dist=0.1506 > gate=0.1500
    EVCM 2026-01-07 installed_stop=10.4448 vs fill=12.3100 -> dist=0.1515 > gate=0.1500
    CTO 2021-12-22 installed_stop=50.3750 vs fill=19.4900 -> dist=1.5847 > gate=0.1500
V13 INVARIANT PASS (1 skipped)
V14 EXPECTATION 9 violations
    UPWK 2025-09-30 entry bar 2025-09-30 open=18.9800 low=18.2150 close=18.5700 vs stop=17.8706, exit=17.8000
    TDS 2023-09-11 entry bar 2023-09-11 open=17.8500 low=17.3700 close=17.6500 vs stop=17.1658, exit=17.1400
    SDA 2023-07-12 entry bar 2023-07-12 open=14.1500 low=11.5500 close=11.7000 vs stop=10.4919, exit=10.4900
    RCAT 2026-03-06 entry bar 2026-03-06 open=14.6100 low=14.6100 close=15.3600 vs stop=14.8790, exit=14.8600
    EXTR 2022-01-21 entry bar 2022-01-21 open=12.8100 low=12.4900 close=12.4900 vs stop=12.1943, exit=12.1700
    DUOT 2026-06-08 entry bar 2026-06-08 open=12.3100 low=11.7500 close=12.2300 vs stop=10.9781, exit=10.7600
    CVNA 2025-12-31 entry bar 2025-12-31 open=429.5500 low=421.8550 close=422.0200 vs stop=406.8887, exit=406.8700
    APPF 2025-08-11 entry bar 2025-08-11 open=281.9800 low=279.6310 close=280.8800 vs stop=271.4265, exit=271.4300
    AAOI 2026-01-02 entry bar 2026-01-02 open=36.3450 low=35.7600 close=39.6000 vs stop=35.3762, exit=35.2400
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 3 violations
    ANIP 2024-03-11 median close 25.95 over 6150 bars (2001-07-24..2026-06-09); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    DUOT 2026-06-08 median close 2.71 over 3134 bars (2008-08-13..2026-06-09); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0
    RCAT 2026-03-06 median close 0.02 over 7327 bars (1995-11-27..2026-06-09); bar 1996-04-10 close 5.00 (+7900.32% vs prior close 0.06) on volume 0
