# Post-run validation report

Invariant checks failing: 3
audit join: 174/174 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-anchor/trading/test_data/share_classes.sexp)
V7 INVARIANT 21 violations
    XPEV 2021-11-23 Virgin_territory but only 65 weekly bars (< 520) before entry
    XERS 2024-02-14 Virgin_territory but only 297 weekly bars (< 520) before entry
    TNET 2023-04-28 Virgin_territory but only 477 weekly bars (< 520) before entry
    TENB 2021-10-07 Virgin_territory but only 169 weekly bars (< 520) before entry
    SMRT 2023-06-07 Virgin_territory but only 122 weekly bars (< 520) before entry
    RSI 2021-10-05 Virgin_territory but only 76 weekly bars (< 520) before entry
    RNAM 2025-08-28 Virgin_territory but only 273 weekly bars (< 520) before entry
    PI 2025-08-13 Virgin_territory but only 476 weekly bars (< 520) before entry
    PFGC 2022-11-14 Virgin_territory but only 374 weekly bars (< 520) before entry
    MUSA 2023-06-29 Virgin_territory but only 518 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 41 violations (12 skipped)
    X 2023-09-29 prior_top=37.63 within +25% of entry=32.68
    WFG 2024-08-26 prior_top=92.49 within +25% of entry=90.43
    USB 2024-08-28 prior_top=51.66 within +25% of entry=46.18
    TSEM 2021-11-01 prior_top=35.67 within +25% of entry=33.03
    TNET 2023-04-28 prior_top=104.23 within +25% of entry=91.95
    TENB 2021-10-07 prior_top=54.68 within +25% of entry=49.33
    TD 2023-02-03 prior_top=69.53 within +25% of entry=69.49
    STE 2025-05-15 prior_top=240.43 within +25% of entry=240.30
    SRPT 2024-05-07 prior_top=175.40 within +25% of entry=143.80
    SPHR 2024-02-29 prior_top=53.40 within +25% of entry=44.06
V10 EXPECTATION 3 violations (12 skipped)
    UPST 2024-08-19 entry_wk_close=42.00 > prior=26.11 (spike>60%)
    LMND 2024-11-25 entry_wk_close=51.81 > prior=24.15 (spike>60%)
    ASTS 2024-06-11 entry_wk_close=10.22 > prior=4.54 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 12 violations
    SMRT 2023-06-07 installed_stop=3.2832 vs fill=3.8700 -> dist=0.1516 > gate=0.1500
    PFGC 2022-11-14 installed_stop=49.7280 vs fill=58.6400 -> dist=0.1520 > gate=0.1500
    MYGN 2022-08-08 installed_stop=23.7408 vs fill=27.9500 -> dist=0.1506 > gate=0.1500
    MUFG 2022-02-02 installed_stop=5.4240 vs fill=6.4400 -> dist=0.1578 > gate=0.1500
    IOT 2023-12-14 installed_stop=30.9792 vs fill=36.7000 -> dist=0.1559 > gate=0.1500
    IMGN 2023-06-05 installed_stop=12.9216 vs fill=15.2800 -> dist=0.1543 > gate=0.1500
    EVER 2025-03-17 installed_stop=23.4144 vs fill=27.6600 -> dist=0.1535 > gate=0.1500
    CUK 2024-07-16 installed_stop=14.8750 vs fill=17.5300 -> dist=0.1515 > gate=0.1500
    CTO 2021-12-22 installed_stop=50.3750 vs fill=19.4900 -> dist=1.5847 > gate=0.1500
    CGNT 2026-05-06 installed_stop=8.8512 vs fill=10.4500 -> dist=0.1530 > gate=0.1500
V13 INVARIANT 4 violations (2 skipped)
    SMRT 2023-06-07 entry_price=3.8700 outside 2023-06-07 bar [3.5700, 3.8650]
    QFIN 2022-12-13 entry_price=18.4500 outside 2022-12-13 bar [17.8700, 18.4450]
    CORT 2024-06-04 entry_price=33.4700 outside 2024-06-04 bar [31.4000, 33.4650]
    CGNT 2026-05-06 exit_price=8.9600 outside 2026-06-03 bar [8.9650, 9.6300]
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 3 violations
    FERG 2023-01-05 median close 69.58 over 4397 bars (2001-07-20..2026-06-08); bar 2001-10-22 close 60.37 (-97.71% vs prior close 2641.96) on volume 0
    LAR 2021-09-10 median close 1.47 over 4457 bars (2008-09-18..2026-06-08); bar 2017-11-08 close 7.65 (+400.03% vs prior close 1.53) on volume 0
    SLCA 2022-03-07 median close 16.41 over 3151 bars (2012-02-01..2024-08-13); bar 2024-08-01 close 0.00 (-100.00% vs prior close 15.49) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION PASS
V22 EXPECTATION 21 violations (44 skipped: position has no stop-decision rows)
    AAON 2022-11-11 no stop move for 13 weeks (2022-11-15..2023-02-17), 1 completed cycle(s) stalled; last: stop 69.91, candidate 45.88, ma 46.53, correction extreme 70.31 (extreme/ma 1.51)
    ANET 2023-06-02 no stop move for 38 weeks (2023-08-01..2024-04-26), 6 completed cycle(s) stalled; last: stop 155.94, candidate 61.80, ma 62.43, correction extreme 263.60 (extreme/ma 4.22)
    ARLP 2024-05-10 no stop move for 13 weeks (2024-05-31..2024-08-30), 1 completed cycle(s) stalled; last: stop 20.97, candidate 17.73, ma 17.91, correction extreme 23.17 (extreme/ma 1.29)
    AVGO 2024-02-02 no stop move for 24 weeks (2024-02-08..2024-07-26), 3 completed cycle(s) stalled; last: stop 1127.34, candidate 126.73, ma 128.01, correction extreme 1302.53 (extreme/ma 10.18)
    BSI 2021-10-01 no stop move for 18 weeks (2021-10-07..2022-02-11), 1 completed cycle(s) stalled; last: stop 24911.88, candidate 19008.88, ma 19201.08, correction extreme 28600.00 (extreme/ma 1.49)
    CNA 2022-02-04 no stop move for 13 weeks (2022-02-07..2022-05-10), 1 completed cycle(s) stalled; last: stop 41.87, candidate 36.13, ma 36.49, correction extreme 42.87 (extreme/ma 1.17)
    CTO 2021-11-19 no stop move for 26 weeks (2021-12-22..2022-06-27), 2 completed cycle(s) stalled; last: stop 50.38, candidate 13.28, ma 13.41, correction extreme 56.24 (extreme/ma 4.19)
    CTRA 2021-10-08 no stop move for 15 weeks (2022-02-04..2022-05-25), 4 completed cycle(s) stalled; last: stop 20.65, candidate 20.48, ma 20.69, correction extreme 26.91 (extreme/ma 1.30)
    GE 2023-03-24 no stop move for 30 weeks (2023-03-31..2023-10-30), 2 completed cycle(s) stalled; last: stop 82.99, candidate 77.13, ma 77.91, correction extreme 99.71 (extreme/ma 1.28)
    KLAC 2025-05-23 no stop move for 52 weeks (2025-06-09..2026-06-12), 10 completed cycle(s) stalled; last: stop 714.88, candidate 165.88, ma 167.76, correction extreme 1927.73 (extreme/ma 11.49)
V23 EXPECTATION 11 violations
    WSBC 2022-10-18 filled 2022-10-18 after the 2022-10-14 screen read Bearish
    TR 2022-10-25 filled 2022-10-25 after the 2022-10-21 screen read Bearish
    SLNO 2025-04-23 filled 2025-04-23 after the 2025-04-11 screen read Bearish
    KALV 2025-04-24 filled 2025-04-24 after the 2025-04-11 screen read Bearish
    GNW 2022-10-26 filled 2022-10-26 after the 2022-10-21 screen read Bearish
    GLNG 2022-02-22 filled 2022-02-22 after the 2022-02-18 screen read Bearish
    FNB 2022-10-24 filled 2022-10-24 after the 2022-10-21 screen read Bearish
    FMX 2025-04-17 filled 2025-04-17 after the 2025-04-11 screen read Bearish
    CSGP 2025-04-23 filled 2025-04-23 after the 2025-04-11 screen read Bearish
    ASR 2025-04-23 filled 2025-04-23 after the 2025-04-11 screen read Bearish
