# Post-run validation report

Invariant checks failing: 3
audit join: 193/193 rows matched

QUALITY-FLAG: 1 fallback exits (V16)

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-trader-rerun/trading/test_data/share_classes.sexp)
V7 INVARIANT 26 violations
    XPOF 2023-01-27 Virgin_territory but only 79 weekly bars (< 520) before entry
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
    UE 2024-07-30 Virgin_territory but only 501 weekly bars (< 520) before entry
    TRMD 2024-01-24 Virgin_territory but only 311 weekly bars (< 520) before entry
    SHOP 2021-06-21 Virgin_territory but only 320 weekly bars (< 520) before entry
    ROKU 2021-07-27 Virgin_territory but only 202 weekly bars (< 520) before entry
    NTRA 2021-09-23 Virgin_territory but only 327 weekly bars (< 520) before entry
    NEXT 2025-01-16 Virgin_territory but only 469 weekly bars (< 520) before entry
    NET 2024-12-17 Virgin_territory but only 276 weekly bars (< 520) before entry
    MNDT 2022-03-07 Virgin_territory but only 446 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 39 violations (16 skipped)
    VRNS 2021-07-21 prior_top=71.50 within +25% of entry=60.92
    URBN 2025-12-22 prior_top=81.84 within +25% of entry=81.15
    TTWO 2025-12-29 prior_top=261.35 within +25% of entry=255.00
    ROST 2023-11-14 prior_top=125.52 within +25% of entry=124.00
    PTGX 2025-06-02 prior_top=54.78 within +25% of entry=49.19
    PEN 2023-05-03 prior_top=305.99 within +25% of entry=294.41
    OWL 2025-03-03 prior_top=23.98 within +25% of entry=20.63
    ON 2021-08-27 prior_top=45.28 within +25% of entry=44.99
    NATL 2025-08-11 prior_top=37.11 within +25% of entry=36.39
    MZTI 2022-10-26 prior_top=179.92 within +25% of entry=178.06
V10 EXPECTATION 7 violations (16 skipped)
    VUZI 2026-05-29 entry_wk_close=4.60 > prior=2.84 (spike>60%)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    GSIT 2025-10-20 entry_wk_close=9.23 > prior=3.84 (spike>60%)
    GRPN 2025-03-26 entry_wk_close=18.82 > prior=11.12 (spike>60%)
    EH 2025-02-12 entry_wk_close=25.56 > prior=15.55 (spike>60%)
    CUTRQ 2022-03-28 entry_wk_close=72.31 > prior=40.49 (spike>60%)
    BTDR 2024-11-29 entry_wk_close=14.27 > prior=7.83 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 3 violations
    YMM 2024-11-20 installed_stop=8.2848 vs fill=9.7700 -> dist=0.1520 > gate=0.1500
    SOUN 2024-04-02 installed_stop=4.3750 vs fill=5.2400 -> dist=0.1651 > gate=0.1500
    LZB 2024-07-15 installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500
V13 INVARIANT 4 violations (1 skipped)
    GERN 2024-04-11 entry_price=3.7900 outside 2024-04-11 bar [3.4400, 3.7860]
    EC 2022-02-28 entry_price=14.7700 outside 2022-02-28 bar [15.4800, 16.1900]
    CRCT 2025-07-02 entry_price=6.3700 outside 2025-07-02 bar [6.9100, 7.2150]
    AAGIY 2023-01-04 entry_price=46.7300 outside 2023-01-04 bar [46.7310, 46.7310]
V14 EXPECTATION 21 violations
    VUZI 2026-05-29 entry bar 2026-05-29 open=4.5200 low=4.2200 close=4.6000 vs stop=4.1413, exit=4.1300
    URBN 2025-12-22 entry bar 2025-12-22 open=80.4200 low=79.8700 close=80.1200 vs stop=77.8715, exit=77.8100
    UMBF 2024-07-31 entry bar 2024-07-31 open=103.0000 low=100.7500 close=102.0200 vs stop=100.9806, exit=100.9500
    UEC 2021-10-18 entry bar 2021-10-18 open=3.4600 low=3.4300 close=3.4900 vs stop=3.3722, exit=3.3600
    TRMD 2024-01-24 entry bar 2024-01-24 open=36.5500 low=35.8800 close=35.9700 vs stop=35.3141, exit=35.2700
    RCAT 2026-03-06 entry bar 2026-03-06 open=14.6100 low=14.6100 close=15.3600 vs stop=14.8790, exit=14.8600
    OWL 2025-03-03 entry bar 2025-03-03 open=21.6800 low=20.5900 close=20.8300 vs stop=19.4170, exit=19.4000
    NTRA 2021-09-23 entry bar 2021-09-23 open=125.6700 low=122.0250 close=123.5400 vs stop=122.7168, exit=121.9000
    NET 2024-12-17 entry bar 2024-12-17 open=118.2300 low=116.0101 close=117.5600 vs stop=111.9165, exit=111.7000
    MNDT 2022-03-07 entry bar 2022-03-07 open=19.3800 low=18.5450 close=22.4900 vs stop=21.9963, exit=21.7300
V15 EXPECTATION PASS
V16 EXPECTATION 1 violations
    TIPT 2025-09-25 force_liquidation exit 2025-09-26 (entry 2025-09-25 @ 27.10, exit @ 20.00)
V17 EXPECTATION PASS
V18 EXPECTATION 6 violations
    APLS 2021-06-16 median close 32.72 over 2165 bars (2017-11-09..2026-06-23); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0
    BOKF 2021-10-20 median close 49.76 over 8761 bars (1991-09-05..2026-06-23); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    DUOT 2026-06-08 median close 2.72 over 3143 bars (2008-08-13..2026-06-23); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0
    IHG 2024-10-15 median close 37.44 over 5838 bars (2003-04-08..2026-06-23); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0
    NOKBF 2025-10-28 median close 5.97 over 4477 bars (2001-07-11..2026-06-23); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0
    RCAT 2026-03-06 median close 0.02 over 7336 bars (1995-11-27..2026-06-23); bar 1996-04-10 close 5.00 (+7900.32% vs prior close 0.06) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 143 violations
    XPOF 2023-01-27 LONG installed_stop 25.9488 vs screener_proxy_stop 24.8676: 4.35% tighter > 3%
    WSBC 2022-10-27 LONG installed_stop 38.4672 vs screener_proxy_stop 36.8644: 4.35% tighter > 3%
    VUZI 2026-05-29 LONG installed_stop 4.1376 vs screener_proxy_stop 3.9652: 4.35% tighter > 3%
    VRSK 2023-06-05 LONG installed_stop 214.2912 vs screener_proxy_stop 205.3624: 4.35% tighter > 3%
    VRNS 2021-07-21 LONG installed_stop 58.4640 vs screener_proxy_stop 56.0280: 4.35% tighter > 3%
    VAL 2022-10-27 LONG installed_stop 61.2192 vs screener_proxy_stop 58.6684: 4.35% tighter > 3%
    UUUU 2025-08-26 LONG installed_stop 10.9920 vs screener_proxy_stop 10.5340: 4.35% tighter > 3%
    URBN 2025-12-22 LONG installed_stop 77.8656 vs screener_proxy_stop 74.6212: 4.35% tighter > 3%
    UMBF 2024-07-31 LONG installed_stop 100.9824 vs screener_proxy_stop 96.7748: 4.35% tighter > 3%
    UE 2024-07-30 LONG installed_stop 19.3750 vs screener_proxy_stop 18.7956: 3.08% tighter > 3%
V22 EXPECTATION 11 violations (157 skipped: position has no stop-decision rows)
    AAON 2022-08-12 no stop move for 14 weeks (2023-02-28..2023-06-09), 1 completed cycle(s) stalled; last: stop 80.84, candidate 51.88, ma 52.59, correction extreme 85.00 (extreme/ma 1.62)
    BBSI 2022-03-25 no stop move for 15 weeks (2022-10-31..2023-02-17), 1 completed cycle(s) stalled; last: stop 83.76, candidate 19.32, ma 19.51, correction extreme 84.91 (extreme/ma 4.35)
    BKV 2025-11-21 no stop move for 14 weeks (2026-02-06..2026-05-15), 1 completed cycle(s) stalled; last: stop 25.92, candidate 25.78, ma 28.85, correction extreme 26.04 (extreme/ma 0.90)
    BMY 2022-01-21 no stop move for 20 weeks (2022-03-15..2022-08-05), 1 completed cycle(s) stalled; last: stop 67.30, candidate 60.32, ma 60.93, correction extreme 71.71 (extreme/ma 1.18)
    BOKF 2021-10-15 no stop move for 18 weeks (2021-10-20..2022-02-24), 2 completed cycle(s) stalled; last: stop 95.46, candidate 88.27, ma 89.16, correction extreme 97.77 (extreme/ma 1.10)
    CTO 2021-11-19 no stop move for 19 weeks (2021-12-22..2022-05-09), 2 completed cycle(s) stalled; last: stop 50.38, candidate 13.28, ma 13.41, correction extreme 56.24 (extreme/ma 4.19)
    ETON 2026-03-13 no stop move for 13 weeks (2026-03-23..2026-06-25), 2 completed cycle(s) stalled; last: stop 22.20, candidate 21.88, ma 22.25, correction extreme 28.00 (extreme/ma 1.26)
    FSM 2024-04-05 no stop move for 13 weeks (2024-04-22..2024-07-26), 1 completed cycle(s) stalled; last: stop 3.88, candidate 3.78, ma 3.81, correction extreme 4.29 (extreme/ma 1.12)
    GDDY 2023-11-03 no stop move for 13 weeks (2023-11-06..2024-02-05), 1 completed cycle(s) stalled; last: stop 82.32, candidate 76.67, ma 77.44, correction extreme 84.78 (extreme/ma 1.09)
    MFC 2022-01-28 no stop move for 23 weeks (2024-01-31..2024-07-10), 2 completed cycle(s) stalled; last: stop 21.47, candidate 20.84, ma 21.05, correction extreme 22.61 (extreme/ma 1.07)
V23 EXPECTATION 11 violations
    WSBC 2022-10-27 filled 2022-10-27 after the 2022-10-21 screen read Bearish
    VAL 2022-10-27 filled 2022-10-27 after the 2022-10-21 screen read Bearish
    STN 2025-05-01 filled 2025-05-01 after the 2025-04-25 screen read Bearish
    MZTI 2022-10-26 filled 2022-10-26 after the 2022-10-21 screen read Bearish
    HLN 2025-05-02 filled 2025-05-02 after the 2025-04-25 screen read Bearish
    FSS 2022-11-10 filled 2022-11-10 after the 2022-11-04 screen read Bearish
    FN 2022-11-11 filled 2022-11-11 after the 2022-11-04 screen read Bearish
    EC 2022-02-28 filled 2022-02-28 after the 2022-02-25 screen read Bearish
    BMI 2022-10-26 filled 2022-10-26 after the 2022-10-21 screen read Bearish
    BBSI 2022-10-31 filled 2022-10-31 after the 2022-10-28 screen read Bearish
