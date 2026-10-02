# Post-run validation report

Invariant checks failing: 3
audit join: 219/219 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-trader-rerun/trading/test_data/share_classes.sexp)
V7 INVARIANT 32 violations
    VAL 2022-10-27 Virgin_territory but only 77 weekly bars (< 520) before entry
    TWLO 2026-04-22 Virgin_territory but only 517 weekly bars (< 520) before entry
    TRMD 2024-01-24 Virgin_territory but only 311 weekly bars (< 520) before entry
    SNOW 2025-08-28 Virgin_territory but only 259 weekly bars (< 520) before entry
    SHOP 2021-06-21 Virgin_territory but only 320 weekly bars (< 520) before entry
    ROKU 2021-07-27 Virgin_territory but only 202 weekly bars (< 520) before entry
    REAL 2025-10-03 Virgin_territory but only 329 weekly bars (< 520) before entry
    NTRA 2021-09-23 Virgin_territory but only 327 weekly bars (< 520) before entry
    NEXT 2025-01-16 Virgin_territory but only 469 weekly bars (< 520) before entry
    NET 2024-12-17 Virgin_territory but only 276 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 47 violations (20 skipped)
    ZGN 2023-09-08 prior_top=15.43 within +25% of entry=14.25
    WOLF_old2 2021-11-22 prior_top=139.55 within +25% of entry=133.00
    VRNS 2021-07-21 prior_top=71.50 within +25% of entry=60.92
    URBN 2025-12-22 prior_top=81.84 within +25% of entry=81.15
    TVTX 2025-09-22 prior_top=31.77 within +25% of entry=25.50
    SAND 2025-06-02 prior_top=9.56 within +25% of entry=9.17
    RYAN 2024-04-04 prior_top=54.48 within +25% of entry=51.91
    ROST 2023-11-14 prior_top=125.52 within +25% of entry=124.00
    PTGX 2025-06-02 prior_top=54.78 within +25% of entry=49.19
    PJT 2023-11-03 prior_top=84.12 within +25% of entry=83.64
V10 EXPECTATION 5 violations (20 skipped)
    VUZI 2026-05-29 entry_wk_close=4.60 > prior=2.84 (spike>60%)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    GSIT 2025-10-20 entry_wk_close=9.23 > prior=3.84 (spike>60%)
    GRPN 2025-03-26 entry_wk_close=18.82 > prior=11.12 (spike>60%)
    BTDR 2024-11-29 entry_wk_close=14.27 > prior=7.83 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 4 violations
    YMM 2024-11-20 installed_stop=8.2848 vs fill=9.7700 -> dist=0.1520 > gate=0.1500
    VLN 2026-05-26 installed_stop=2.9136 vs fill=3.4300 -> dist=0.1506 > gate=0.1500
    NNI 2025-03-06 installed_stop=97.8048 vs fill=116.9600 -> dist=0.1638 > gate=0.1500
    LPG 2023-09-15 installed_stop=23.2022 vs fill=27.3000 -> dist=0.1501 > gate=0.1500
V13 INVARIANT 7 violations (1 skipped)
    TVTX 2025-09-22 exit_price=22.0500 outside 2025-09-29 bar [22.0550, 25.4600]
    NTTYY 2024-01-16 entry_price=31.7800 outside 2024-01-16 bar [31.7820, 31.7820]
    EC 2022-02-28 entry_price=14.7700 outside 2022-02-28 bar [15.4800, 16.1900]
    CRCT 2025-07-02 entry_price=6.3700 outside 2025-07-02 bar [6.9100, 7.2150]
    CIG 2022-04-12 exit_price=3.1700 outside 2022-04-19 bar [3.1701, 3.3500]
    AZPN 2025-01-30 no bar on exit_date 2025-03-13 (nearest earlier bar: 2025-03-12)
    AAGIY 2023-01-04 entry_price=46.7300 outside 2023-01-04 bar [46.7310, 46.7310]
V14 EXPECTATION 32 violations
    VUZI 2026-05-29 entry bar 2026-05-29 open=4.5200 low=4.2200 close=4.6000 vs stop=4.1413, exit=4.1300
    URBN 2025-12-22 entry bar 2025-12-22 open=80.4200 low=79.8700 close=80.1200 vs stop=77.8715, exit=77.8100
    UMBF 2024-07-31 entry bar 2024-07-31 open=103.0000 low=100.7500 close=102.0200 vs stop=100.9806, exit=100.9500
    UEC 2021-10-18 entry bar 2021-10-18 open=3.4600 low=3.4300 close=3.4900 vs stop=3.3722, exit=3.3600
    UEC 2022-04-08 entry bar 2022-04-08 open=5.5500 low=5.3400 close=5.5000 vs stop=5.3752, exit=5.3600
    TWLO 2026-04-22 entry bar 2026-04-22 open=152.1100 low=146.8600 close=150.4500 vs stop=146.3769, exit=146.2200
    TRMD 2024-01-24 entry bar 2024-01-24 open=36.5500 low=35.8800 close=35.9700 vs stop=35.3141, exit=35.2700
    TGS 2026-03-24 entry bar 2026-03-24 open=32.9100 low=32.8500 close=33.9900 vs stop=33.1602, exit=33.0700
    TGLS 2023-01-27 entry bar 2023-01-27 open=33.8000 low=33.4600 close=33.7600 vs stop=33.6682, exit=33.6300
    REAL 2025-10-03 entry bar 2025-10-03 open=11.2500 low=10.8950 close=10.9900 vs stop=10.9707, exit=10.9500
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 8 violations
    ANIP 2024-03-04 median close 25.95 over 6150 bars (2001-07-24..2026-06-09); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    APLS 2021-06-16 median close 32.85 over 2155 bars (2017-11-09..2026-06-09); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0
    BOKF 2021-10-20 median close 49.74 over 8752 bars (1991-09-05..2026-06-09); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    CECO 2024-12-09 median close 4.59 over 11472 bars (1980-12-02..2026-06-09); bar 1992-09-29 close 2.66 (+399.96% vs prior close 0.53) on volume 0
    DUOT 2026-06-08 median close 2.71 over 3134 bars (2008-08-13..2026-06-09); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0
    IHG 2024-10-15 median close 37.39 over 5829 bars (2003-04-08..2026-06-09); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0
    NOKBF 2025-10-28 median close 5.96 over 4468 bars (2001-07-11..2026-06-09); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0
    TVTX 2025-09-22 median close 17.10 over 4112 bars (2003-08-13..2026-06-09); bar 2008-02-27 close 0.00 (+240.00% vs prior close 0.00) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 173 violations
    ZGN 2023-09-08 LONG installed_stop 13.4112 vs screener_proxy_stop 12.8524: 4.35% tighter > 3%
    VVX 2026-01-22 LONG installed_stop 67.2960 vs screener_proxy_stop 64.4920: 4.35% tighter > 3%
    VUZI 2026-05-29 LONG installed_stop 4.1376 vs screener_proxy_stop 3.9652: 4.35% tighter > 3%
    VRSK 2023-06-05 LONG installed_stop 214.2912 vs screener_proxy_stop 205.3624: 4.35% tighter > 3%
    VRNS 2021-07-21 LONG installed_stop 58.4640 vs screener_proxy_stop 56.0280: 4.35% tighter > 3%
    VAL 2022-10-27 LONG installed_stop 61.2192 vs screener_proxy_stop 58.6684: 4.35% tighter > 3%
    UUUU 2025-08-26 LONG installed_stop 10.9920 vs screener_proxy_stop 10.5340: 4.35% tighter > 3%
    URBN 2025-12-22 LONG installed_stop 77.8656 vs screener_proxy_stop 74.6212: 4.35% tighter > 3%
    UMBF 2024-07-31 LONG installed_stop 100.9824 vs screener_proxy_stop 96.7748: 4.35% tighter > 3%
    TWLO 2026-04-22 LONG installed_stop 146.3750 vs screener_proxy_stop 140.4932: 4.19% tighter > 3%
V22 EXPECTATION 6 violations (173 skipped: position has no stop-decision rows)
    AAON 2022-08-12 no stop move for 14 weeks (2023-02-28..2023-06-09), 1 completed cycle(s) stalled; last: stop 80.84, candidate 57.63, ma 58.21, correction extreme 85.00 (extreme/ma 1.46)
    BBSI 2022-03-25 no stop move for 15 weeks (2022-10-31..2023-02-17), 1 completed cycle(s) stalled; last: stop 83.76, candidate 20.31, ma 20.51, correction extreme 84.91 (extreme/ma 4.14)
    BMY 2022-01-21 no stop move for 20 weeks (2022-03-15..2022-08-05), 1 completed cycle(s) stalled; last: stop 67.30, candidate 62.77, ma 63.41, correction extreme 71.71 (extreme/ma 1.13)
    BOKF 2021-10-15 no stop move for 18 weeks (2021-10-20..2022-02-24), 2 completed cycle(s) stalled; last: stop 95.46, candidate 94.66, ma 95.62, correction extreme 97.77 (extreme/ma 1.02)
    LPG 2023-09-08 no stop move for 21 weeks (2023-09-15..2024-02-09), 1 completed cycle(s) stalled; last: stop 23.20, candidate 20.38, ma 20.76, correction extreme 25.58 (extreme/ma 1.23)
    MFC 2022-01-28 no stop move for 14 weeks (2024-01-31..2024-05-09), 1 completed cycle(s) stalled; last: stop 21.47, candidate 21.32, ma 21.89, correction extreme 21.54 (extreme/ma 0.98)
V23 EXPECTATION 10 violations
    VAL 2022-10-27 filled 2022-10-27 after the 2022-10-21 screen read Bearish
    STN 2025-05-01 filled 2025-05-01 after the 2025-04-25 screen read Bearish
    MZTI 2022-10-26 filled 2022-10-26 after the 2022-10-21 screen read Bearish
    HRTG 2025-04-14 filled 2025-04-14 after the 2025-04-11 screen read Bearish
    FSS 2022-11-10 filled 2022-11-10 after the 2022-11-04 screen read Bearish
    FN 2022-11-11 filled 2022-11-11 after the 2022-11-04 screen read Bearish
    EC 2022-02-28 filled 2022-02-28 after the 2022-02-25 screen read Bearish
    BMI 2022-10-26 filled 2022-10-26 after the 2022-10-21 screen read Bearish
    BBSI 2022-10-31 filled 2022-10-31 after the 2022-10-28 screen read Bearish
    ADMA 2025-04-28 filled 2025-04-28 after the 2025-04-25 screen read Bearish
