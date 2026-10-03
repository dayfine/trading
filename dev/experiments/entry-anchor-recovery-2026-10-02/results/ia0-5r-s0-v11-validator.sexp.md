# Post-run validation report

Invariant checks failing: 2
audit join: 126/126 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-anchor/trading/test_data/share_classes.sexp)
V7 INVARIANT 1 violations
    XERS 2024-02-14 Virgin_territory but only 297 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 32 violations (12 skipped)
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.75
    WOLF_old2 2021-11-22 prior_top=139.55 within +25% of entry=133.00
    URBN 2026-01-06 prior_top=81.84 within +25% of entry=81.27
    UA 2021-11-22 prior_top=27.04 within +25% of entry=22.69
    PTGX 2025-06-02 prior_top=54.78 within +25% of entry=49.15
    PJT 2023-11-03 prior_top=84.12 within +25% of entry=83.60
    ON 2021-08-27 prior_top=45.28 within +25% of entry=44.85
    MSEX 2022-04-27 prior_top=109.11 within +25% of entry=89.30
    MNSO 2025-01-06 prior_top=29.23 within +25% of entry=26.01
    MMYT 2023-10-26 prior_top=40.52 within +25% of entry=37.63
V10 EXPECTATION 1 violations (12 skipped)
    ISEE 2022-09-30 entry_wk_close=17.94 > prior=9.44 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 3 violations
    VLN 2026-05-26 installed_stop=2.9136 vs fill=3.4300 -> dist=0.1506 > gate=0.1500
    MNSO 2025-01-06 installed_stop=21.8750 vs fill=26.0100 -> dist=0.1590 > gate=0.1500
    CTO 2021-12-22 installed_stop=50.3750 vs fill=19.4800 -> dist=1.5860 > gate=0.1500
V13 INVARIANT PASS (1 skipped)
V14 EXPECTATION 9 violations
    UPWK 2025-09-30 entry bar 2025-09-30 open=18.9800 low=18.2150 close=18.5700 vs stop=17.8706, exit=17.8300
    TDS 2023-09-11 entry bar 2023-09-11 open=17.8500 low=17.3700 close=17.6500 vs stop=17.1658, exit=17.0600
    SDA 2023-07-12 entry bar 2023-07-12 open=14.1500 low=11.5500 close=11.7000 vs stop=10.4919, exit=10.4400
    RCAT 2026-03-06 entry bar 2026-03-06 open=14.6100 low=14.6100 close=15.3600 vs stop=14.8727, exit=14.8200
    EXTR 2022-01-21 entry bar 2022-01-21 open=12.8100 low=12.4900 close=12.4900 vs stop=12.1943, exit=12.0900
    DUOT 2026-06-08 entry bar 2026-06-08 open=12.3100 low=11.7500 close=12.2300 vs stop=10.9781, exit=10.9600
    CVNA 2025-12-31 entry bar 2025-12-31 open=429.5500 low=421.8550 close=422.0200 vs stop=406.8887, exit=406.7000
    APPF 2025-08-11 entry bar 2025-08-11 open=281.9800 low=279.6310 close=280.8800 vs stop=271.4265, exit=268.6000
    AAOI 2026-01-02 entry bar 2026-01-02 open=36.3450 low=35.7600 close=39.6000 vs stop=35.3762, exit=35.2600
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 3 violations
    ANIP 2024-03-11 median close 25.95 over 6150 bars (2001-07-24..2026-06-09); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    DUOT 2026-06-08 median close 2.71 over 3134 bars (2008-08-13..2026-06-09); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0
    RCAT 2026-03-06 median close 0.02 over 7327 bars (1995-11-27..2026-06-09); bar 1996-04-10 close 5.00 (+7900.32% vs prior close 0.06) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 14 violations
    VGR 2021-12-06 LONG installed_stop 10.3471 vs screener_proxy_stop 10.0280: 3.18% tighter > 3%
    UPWK 2025-09-30 LONG installed_stop 17.8750 vs screener_proxy_stop 16.7716: 6.58% tighter > 3%
    TDS 2023-09-11 LONG installed_stop 17.1648 vs screener_proxy_stop 16.0264: 7.10% tighter > 3%
    QCOM 2022-01-20 LONG installed_stop 164.3616 vs screener_proxy_stop 155.2776: 5.85% tighter > 3%
    PKG 2023-08-21 LONG installed_stop 139.8912 vs screener_proxy_stop 135.2124: 3.46% tighter > 3%
    MSEX 2022-04-27 LONG installed_stop 83.8560 vs screener_proxy_stop 80.5460: 4.11% tighter > 3%
    MMYT 2023-10-26 LONG installed_stop 35.3750 vs screener_proxy_stop 33.9388: 4.23% tighter > 3%
    LMAT 2026-03-03 LONG installed_stop 101.3750 vs screener_proxy_stop 93.3524: 8.59% tighter > 3%
    EXTR 2022-01-21 LONG installed_stop 12.1920 vs screener_proxy_stop 11.3620: 7.31% tighter > 3%
    CVNA 2025-12-31 LONG installed_stop 406.8750 vs screener_proxy_stop 382.1680: 6.46% tighter > 3%
V22 EXPECTATION 10 violations (26 skipped: position has no stop-decision rows)
    AIT 2022-08-26 no stop move for 16 weeks (2022-10-05..2023-01-26), 1 completed cycle(s) stalled; last: stop 104.22, candidate 102.48, ma 103.52, correction extreme 114.59 (extreme/ma 1.11)
    ARLP 2024-05-10 no stop move for 13 weeks (2024-05-31..2024-08-30), 1 completed cycle(s) stalled; last: stop 20.97, candidate 17.73, ma 17.91, correction extreme 23.17 (extreme/ma 1.29)
    BKV 2025-11-21 no stop move for 14 weeks (2026-02-06..2026-05-15), 1 completed cycle(s) stalled; last: stop 25.92, candidate 25.78, ma 28.85, correction extreme 26.04 (extreme/ma 0.90)
    CTO 2021-11-19 no stop move for 26 weeks (2021-12-22..2022-06-27), 2 completed cycle(s) stalled; last: stop 50.38, candidate 13.28, ma 13.41, correction extreme 56.24 (extreme/ma 4.19)
    DOV 2025-02-07 no stop move for 16 weeks (2026-01-21..2026-05-15), 1 completed cycle(s) stalled; last: stop 193.00, candidate 188.90, ma 190.80, correction extreme 197.97 (extreme/ma 1.04)
    MUFG 2021-10-08 no stop move for 14 weeks (2022-01-11..2022-04-25), 2 completed cycle(s) stalled; last: stop 5.42, candidate 4.88, ma 5.17, correction extreme 5.68 (extreme/ma 1.10)
    PKG 2023-08-18 no stop move for 18 weeks (2023-08-21..2023-12-29), 1 completed cycle(s) stalled; last: stop 139.89, candidate 135.77, ma 137.14, correction extreme 143.82 (extreme/ma 1.05)
    R 2023-08-18 no stop move for 15 weeks (2023-09-01..2023-12-21), 1 completed cycle(s) stalled; last: stop 91.23, candidate 90.40, ma 93.10, correction extreme 91.31 (extreme/ma 0.98)
    SUN 2023-10-13 no stop move for 14 weeks (2023-10-27..2024-02-02), 1 completed cycle(s) stalled; last: stop 44.69, candidate 39.18, ma 39.57, correction extreme 49.00 (extreme/ma 1.24)
    TK 2023-11-03 no stop move for 16 weeks (2023-11-06..2024-03-01), 3 completed cycle(s) stalled; last: stop 6.38, candidate 3.78, ma 3.82, correction extreme 7.60 (extreme/ma 1.99)
V23 EXPECTATION 3 violations
    STN 2025-05-01 filled 2025-05-01 after the 2025-04-25 screen read Bearish
    ISEE 2022-09-30 filled 2022-09-30 after the 2022-09-23 screen read Bearish
    AIT 2022-10-05 filled 2022-10-05 after the 2022-09-30 screen read Bearish
