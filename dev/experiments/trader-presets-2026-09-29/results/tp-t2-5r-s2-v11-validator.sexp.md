# Post-run validation report

Invariant checks failing: 3
audit join: 210/210 rows matched

QUALITY-FLAG: 1 fallback exits (V16)

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-trader/trading/test_data/share_classes.sexp)
V7 INVARIANT 25 violations
    XERS 2024-02-14 Virgin_territory but only 297 weekly bars (< 520) before entry
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
    TWLO 2026-04-22 Virgin_territory but only 517 weekly bars (< 520) before entry
    TRMD 2024-01-24 Virgin_territory but only 311 weekly bars (< 520) before entry
    SHOP 2021-06-21 Virgin_territory but only 320 weekly bars (< 520) before entry
    ROKU 2021-07-27 Virgin_territory but only 202 weekly bars (< 520) before entry
    QBTS 2024-11-25 Virgin_territory but only 207 weekly bars (< 520) before entry
    PFGC 2022-11-30 Virgin_territory but only 376 weekly bars (< 520) before entry
    NTRA 2021-09-23 Virgin_territory but only 327 weekly bars (< 520) before entry
    NEXT 2025-01-16 Virgin_territory but only 469 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 52 violations (16 skipped)
    ZGN 2023-09-08 prior_top=15.43 within +25% of entry=14.25
    VRNS 2021-07-21 prior_top=71.50 within +25% of entry=60.99
    URBN 2025-03-13 prior_top=58.19 within +25% of entry=50.12
    URBN 2025-12-22 prior_top=81.84 within +25% of entry=81.28
    RYAN 2024-04-04 prior_top=54.48 within +25% of entry=51.91
    ROST 2023-11-14 prior_top=125.52 within +25% of entry=124.00
    PTGX 2025-06-02 prior_top=54.78 within +25% of entry=49.17
    PENG 2026-04-27 prior_top=35.49 within +25% of entry=30.55
    PEN 2023-05-03 prior_top=305.99 within +25% of entry=294.56
    ORCL 2024-08-05 prior_top=141.64 within +25% of entry=128.21
V10 EXPECTATION 7 violations (16 skipped)
    VUZI 2026-05-29 entry_wk_close=4.60 > prior=2.84 (spike>60%)
    VTNRQ 2022-05-16 entry_wk_close=14.40 > prior=8.84 (spike>60%)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    QBTS 2024-11-25 entry_wk_close=3.02 > prior=1.04 (spike>60%)
    GSIT 2025-10-20 entry_wk_close=9.23 > prior=3.84 (spike>60%)
    CUTRQ 2022-03-28 entry_wk_close=72.31 > prior=40.49 (spike>60%)
    BTDR 2024-11-29 entry_wk_close=14.27 > prior=7.83 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 2 violations
    XERS 2024-02-14 installed_stop=2.6496 vs fill=3.1300 -> dist=0.1535 > gate=0.1500
    SOUN 2024-04-02 installed_stop=4.3750 vs fill=5.2400 -> dist=0.1651 > gate=0.1500
V13 INVARIANT 4 violations (1 skipped)
    OSIS 2024-03-26 entry_price=140.9700 outside 2024-03-26 bar [137.3000, 140.9650]
    GERN 2024-04-11 entry_price=3.7900 outside 2024-04-11 bar [3.4400, 3.7860]
    CRCT 2025-07-02 entry_price=6.3600 outside 2025-07-02 bar [6.9100, 7.2150]
    AAGIY 2023-01-04 entry_price=46.7300 outside 2023-01-04 bar [46.7310, 46.7310]
V14 EXPECTATION 28 violations
    VUZI 2026-05-29 entry bar 2026-05-29 open=4.5200 low=4.2200 close=4.6000 vs stop=4.1413, exit=4.0400
    URBN 2025-12-22 entry bar 2025-12-22 open=80.4200 low=79.8700 close=80.1200 vs stop=77.8662, exit=77.7900
    UEC 2021-10-18 entry bar 2021-10-18 open=3.4600 low=3.4300 close=3.4900 vs stop=3.3749, exit=3.3300
    UEC 2022-04-08 entry bar 2022-04-08 open=5.5500 low=5.3400 close=5.5000 vs stop=5.3728, exit=5.3600
    TWLO 2026-04-22 entry bar 2026-04-22 open=152.1100 low=146.8600 close=150.4500 vs stop=146.3826, exit=146.3300
    TRMD 2024-01-24 entry bar 2024-01-24 open=36.5500 low=35.8800 close=35.9700 vs stop=35.3118, exit=35.2700
    TGS 2026-03-24 entry bar 2026-03-24 open=32.9100 low=32.8500 close=33.9900 vs stop=33.1561, exit=33.0800
    TGLS 2023-01-27 entry bar 2023-01-27 open=33.8000 low=33.4600 close=33.7600 vs stop=33.6658, exit=33.5400
    RCAT 2026-03-06 entry bar 2026-03-06 open=14.6100 low=14.6100 close=15.3600 vs stop=14.8752, exit=14.7400
    QFIN 2024-04-11 entry bar 2024-04-11 open=20.2000 low=19.9400 close=20.0000 vs stop=19.6766, exit=19.2500
V15 EXPECTATION PASS
V16 EXPECTATION 1 violations
    TIPT 2025-09-25 force_liquidation exit 2025-09-26 (entry 2025-09-25 @ 27.13, exit @ 20.00)
V17 EXPECTATION PASS
V18 EXPECTATION 8 violations
    ANIP 2024-03-04 median close 25.85 over 6148 bars (2001-07-24..2026-06-05); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    APLS 2021-06-16 median close 32.90 over 2153 bars (2017-11-09..2026-06-05); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0
    ATLKY 2026-01-15 median close 24.89 over 7434 bars (1996-11-18..2026-06-05); bar 2003-09-01 close 1000000.00 (+3311246.00% vs prior close 30.20) on volume 0
    BOKF 2021-10-20 median close 49.72 over 8750 bars (1991-09-05..2026-06-05); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    IHG 2024-10-15 median close 37.35 over 5827 bars (2003-04-08..2026-06-05); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0
    LNG 2026-03-16 median close 27.68 over 8098 bars (1994-04-04..2026-06-05); bar 1994-07-19 close 6.00 (+500.00% vs prior close 1.00) on volume 0
    RCAT 2026-03-06 median close 0.02 over 7325 bars (1995-11-27..2026-06-05); bar 1996-04-10 close 5.00 (+7900.32% vs prior close 0.06) on volume 0
    VTNRQ 2022-05-16 median close 1.36 over 7522 bars (1992-10-21..2025-01-21); bar 2003-11-11 close 0.00 (-90.00% vs prior close 0.02) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 157 violations
    ZGN 2023-09-08 LONG installed_stop 13.4112 vs screener_proxy_stop 12.8524: 4.35% tighter > 3%
    WSR 2026-02-26 LONG installed_stop 14.8224 vs screener_proxy_stop 14.2048: 4.35% tighter > 3%
    VUZI 2026-05-29 LONG installed_stop 4.1376 vs screener_proxy_stop 3.9652: 4.35% tighter > 3%
    VTNRQ 2022-05-16 LONG installed_stop 13.8144 vs screener_proxy_stop 13.2388: 4.35% tighter > 3%
    VRSK 2023-06-05 LONG installed_stop 214.2912 vs screener_proxy_stop 205.3624: 4.35% tighter > 3%
    VRNS 2021-07-21 LONG installed_stop 58.4640 vs screener_proxy_stop 56.0280: 4.35% tighter > 3%
    VAL 2022-10-27 LONG installed_stop 61.2192 vs screener_proxy_stop 58.6684: 4.35% tighter > 3%
    URBN 2025-03-13 LONG installed_stop 47.1744 vs screener_proxy_stop 45.2088: 4.35% tighter > 3%
    URBN 2025-12-22 LONG installed_stop 77.8656 vs screener_proxy_stop 74.6212: 4.35% tighter > 3%
    TWLO 2026-04-22 LONG installed_stop 146.3750 vs screener_proxy_stop 140.4932: 4.19% tighter > 3%
V22 EXPECTATION 5 violations (173 skipped: position has no stop-decision rows)
    AAON 2022-08-12 no stop move for 14 weeks (2023-02-28..2023-06-09), 1 completed cycle(s) stalled; last: stop 80.84, candidate 57.63, ma 58.21, correction extreme 85.00 (extreme/ma 1.46)
    BBSI 2022-03-25 no stop move for 15 weeks (2022-10-31..2023-02-17), 1 completed cycle(s) stalled; last: stop 83.76, candidate 20.31, ma 20.51, correction extreme 84.91 (extreme/ma 4.14)
    BMY 2022-01-21 no stop move for 20 weeks (2022-03-15..2022-08-05), 1 completed cycle(s) stalled; last: stop 67.30, candidate 62.77, ma 63.41, correction extreme 71.71 (extreme/ma 1.13)
    BOKF 2021-10-15 no stop move for 18 weeks (2021-10-20..2022-02-24), 2 completed cycle(s) stalled; last: stop 95.46, candidate 94.66, ma 95.62, correction extreme 97.77 (extreme/ma 1.02)
    CTO 2021-11-19 no stop move for 19 weeks (2021-12-22..2022-05-09), 2 completed cycle(s) stalled; last: stop 50.38, candidate 13.94, ma 14.08, correction extreme 56.24 (extreme/ma 3.99)
V23 EXPECTATION 8 violations
    VTNRQ 2022-05-16 filled 2022-05-16 after the 2022-05-13 screen read Bearish
    VAL 2022-10-27 filled 2022-10-27 after the 2022-10-21 screen read Bearish
    MZTI 2022-10-26 filled 2022-10-26 after the 2022-10-21 screen read Bearish
    HLN 2025-05-02 filled 2025-05-02 after the 2025-04-25 screen read Bearish
    FSS 2022-11-10 filled 2022-11-10 after the 2022-11-04 screen read Bearish
    FN 2022-11-11 filled 2022-11-11 after the 2022-11-04 screen read Bearish
    BMI 2022-10-26 filled 2022-10-26 after the 2022-10-21 screen read Bearish
    BBSI 2022-10-31 filled 2022-10-31 after the 2022-10-28 screen read Bearish
