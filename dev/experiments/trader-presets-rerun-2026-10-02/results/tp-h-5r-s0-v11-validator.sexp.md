# Post-run validation report

Invariant checks failing: 3
audit join: 196/196 rows matched

QUALITY-FLAG: 1 fallback exits (V16)

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-trader-rerun/trading/test_data/share_classes.sexp)
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
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 145 violations
    ZGN 2023-09-08 LONG installed_stop 13.4112 vs screener_proxy_stop 12.8524: 4.35% tighter > 3%
    WSBC 2022-10-27 LONG installed_stop 38.4672 vs screener_proxy_stop 36.8644: 4.35% tighter > 3%
    VRSK 2023-06-05 LONG installed_stop 214.2912 vs screener_proxy_stop 205.3624: 4.35% tighter > 3%
    VRNS 2021-07-21 LONG installed_stop 58.4640 vs screener_proxy_stop 56.0280: 4.35% tighter > 3%
    VAL 2022-10-27 LONG installed_stop 61.2192 vs screener_proxy_stop 58.6684: 4.35% tighter > 3%
    UUUU 2025-08-26 LONG installed_stop 10.9920 vs screener_proxy_stop 10.5340: 4.35% tighter > 3%
    URBN 2025-12-22 LONG installed_stop 77.8656 vs screener_proxy_stop 74.6212: 4.35% tighter > 3%
    TWLO 2026-04-22 LONG installed_stop 146.3750 vs screener_proxy_stop 140.4932: 4.19% tighter > 3%
    TIPT 2025-09-25 LONG installed_stop 25.9488 vs screener_proxy_stop 24.8676: 4.35% tighter > 3%
    TGLS 2023-01-27 LONG installed_stop 33.6672 vs screener_proxy_stop 32.2644: 4.35% tighter > 3%
V22 EXPECTATION 12 violations (173 skipped: position has no stop-decision rows)
    AAON 2022-08-12 no stop move for 14 weeks (2023-02-28..2023-06-09), 1 completed cycle(s) stalled; last: stop 80.84, candidate 51.88, ma 52.59, correction extreme 85.00 (extreme/ma 1.62)
    AMX 2025-05-09 no stop move for 18 weeks (2025-08-22..2025-12-26), 2 completed cycle(s) stalled; last: stop 19.14, candidate 18.88, ma 19.25, correction extreme 20.86 (extreme/ma 1.08)
    ARLP 2024-05-10 no stop move for 13 weeks (2024-05-31..2024-08-30), 1 completed cycle(s) stalled; last: stop 20.97, candidate 17.73, ma 17.91, correction extreme 23.17 (extreme/ma 1.29)
    BBSI 2022-03-25 no stop move for 15 weeks (2022-10-31..2023-02-17), 1 completed cycle(s) stalled; last: stop 83.76, candidate 19.32, ma 19.51, correction extreme 84.91 (extreme/ma 4.35)
    BMY 2022-01-21 no stop move for 20 weeks (2022-03-15..2022-08-05), 1 completed cycle(s) stalled; last: stop 67.30, candidate 60.32, ma 60.93, correction extreme 71.71 (extreme/ma 1.18)
    BOKF 2021-10-15 no stop move for 18 weeks (2021-10-20..2022-02-24), 2 completed cycle(s) stalled; last: stop 95.46, candidate 88.27, ma 89.16, correction extreme 97.77 (extreme/ma 1.10)
    CPNG 2025-02-21 no stop move for 13 weeks (2025-05-15..2025-08-15), 1 completed cycle(s) stalled; last: stop 25.96, candidate 24.93, ma 25.18, correction extreme 26.31 (extreme/ma 1.04)
    CTO 2021-11-19 no stop move for 19 weeks (2021-12-22..2022-05-09), 2 completed cycle(s) stalled; last: stop 50.38, candidate 13.28, ma 13.41, correction extreme 56.24 (extreme/ma 4.19)
    EQNR 2025-03-28 no stop move for 17 weeks (2026-02-26..2026-06-25), 1 completed cycle(s) stalled; last: stop 28.29, candidate 24.73, ma 24.98, correction extreme 28.45 (extreme/ma 1.14)
    GDDY 2023-11-03 no stop move for 13 weeks (2023-11-06..2024-02-05), 1 completed cycle(s) stalled; last: stop 82.32, candidate 76.67, ma 77.44, correction extreme 84.78 (extreme/ma 1.09)
V23 EXPECTATION 9 violations
    WSBC 2022-10-27 filled 2022-10-27 after the 2022-10-21 screen read Bearish
    VAL 2022-10-27 filled 2022-10-27 after the 2022-10-21 screen read Bearish
    MZTI 2022-10-26 filled 2022-10-26 after the 2022-10-21 screen read Bearish
    HLN 2025-05-02 filled 2025-05-02 after the 2025-04-25 screen read Bearish
    FSS 2022-11-10 filled 2022-11-10 after the 2022-11-04 screen read Bearish
    FN 2022-11-11 filled 2022-11-11 after the 2022-11-04 screen read Bearish
    EC 2022-02-28 filled 2022-02-28 after the 2022-02-25 screen read Bearish
    BMI 2022-10-26 filled 2022-10-26 after the 2022-10-21 screen read Bearish
    BBSI 2022-10-31 filled 2022-10-31 after the 2022-10-28 screen read Bearish
