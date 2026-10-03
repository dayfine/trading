# Post-run validation report

Invariant checks failing: 3
audit join: 194/194 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-anchor/trading/test_data/share_classes.sexp)
V7 INVARIANT 30 violations
    XERS 2024-02-14 Virgin_territory but only 297 weekly bars (< 520) before entry
    TRIN 2026-01-12 Virgin_territory but only 261 weekly bars (< 520) before entry
    TENB 2021-10-07 Virgin_territory but only 169 weekly bars (< 520) before entry
    TENB 2023-03-21 Virgin_territory but only 245 weekly bars (< 520) before entry
    SMRT 2023-06-07 Virgin_territory but only 122 weekly bars (< 520) before entry
    SFM 2022-11-09 Virgin_territory but only 488 weekly bars (< 520) before entry
    RSI 2021-10-05 Virgin_territory but only 76 weekly bars (< 520) before entry
    PI 2025-08-13 Virgin_territory but only 476 weekly bars (< 520) before entry
    PFGC 2022-11-14 Virgin_territory but only 374 weekly bars (< 520) before entry
    NTRA 2021-07-22 Virgin_territory but only 318 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 51 violations (14 skipped)
    WFG 2024-08-26 prior_top=92.49 within +25% of entry=90.49
    TTGT 2021-08-31 prior_top=98.65 within +25% of entry=84.55
    TSEM 2021-11-01 prior_top=35.67 within +25% of entry=33.03
    TENB 2021-10-07 prior_top=54.68 within +25% of entry=49.33
    TD 2023-01-26 prior_top=69.53 within +25% of entry=67.81
    STE 2025-05-15 prior_top=240.43 within +25% of entry=240.30
    SPHR 2024-02-29 prior_top=53.40 within +25% of entry=43.80
    SKX 2025-01-14 prior_top=72.87 within +25% of entry=72.00
    SI_old1 2021-10-11 prior_top=170.88 within +25% of entry=169.60
    SFM 2022-11-09 prior_top=34.75 within +25% of entry=31.93
V10 EXPECTATION 4 violations (14 skipped)
    UPST 2024-08-19 entry_wk_close=42.00 > prior=26.11 (spike>60%)
    TREE 2025-08-12 entry_wk_close=63.52 > prior=37.93 (spike>60%)
    LMND 2024-11-25 entry_wk_close=51.81 > prior=24.15 (spike>60%)
    ASTS 2024-06-11 entry_wk_close=10.22 > prior=4.54 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 16 violations
    VRNS 2024-07-30 installed_stop=44.7552 vs fill=53.0400 -> dist=0.1562 > gate=0.1500
    SMRT 2023-06-07 installed_stop=3.2832 vs fill=3.8700 -> dist=0.1516 > gate=0.1500
    MUFG 2022-02-02 installed_stop=5.4240 vs fill=6.4000 -> dist=0.1525 > gate=0.1500
    MNKD 2024-07-15 installed_stop=4.9440 vs fill=5.8500 -> dist=0.1549 > gate=0.1500
    JOE 2022-03-22 installed_stop=49.6320 vs fill=58.4800 -> dist=0.1513 > gate=0.1500
    IOT 2023-12-14 installed_stop=30.9792 vs fill=36.7000 -> dist=0.1559 > gate=0.1500
    HUYA 2024-04-05 installed_stop=4.2048 vs fill=4.9500 -> dist=0.1505 > gate=0.1500
    HTZ 2023-03-06 installed_stop=17.3952 vs fill=20.4800 -> dist=0.1506 > gate=0.1500
    H 2022-11-03 installed_stop=83.2320 vs fill=98.1100 -> dist=0.1516 > gate=0.1500
    DHT 2023-10-12 installed_stop=8.8750 vs fill=10.4600 -> dist=0.1515 > gate=0.1500
V13 INVARIANT 6 violations (1 skipped)
    SMRT 2023-06-07 entry_price=3.8700 outside 2023-06-07 bar [3.5700, 3.8650]
    JWN 2025-05-19 no bar on exit_date 2025-05-21 (nearest earlier bar: 2025-05-20)
    HTZ 2023-03-06 entry_price=20.4800 outside 2023-03-06 bar [19.4000, 20.4799]
    HE 2022-08-16 entry_price=44.0100 outside 2022-08-16 bar [43.5100, 44.0050]
    CNX 2022-01-18 entry_price=16.2000 outside 2022-01-18 bar [15.7600, 16.1950]
    CGNT 2026-05-06 exit_price=8.9600 outside 2026-06-03 bar [8.9650, 9.6300]
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 4 violations
    CYRX 2021-09-17 median close 2.90 over 5228 bars (2005-08-22..2026-06-03); bar 2010-02-05 close 9.30 (+900.00% vs prior close 0.93) on volume 0
    JWN 2025-05-19 median close 30.25 over 13357 bars (1972-06-02..2025-05-20); bar 1981-08-10 close 32.25 (+3326.41% vs prior close 0.94) on volume 0
    LAR 2021-09-10 median close 1.46 over 4454 bars (2008-09-18..2026-06-03); bar 2017-11-08 close 7.65 (+400.03% vs prior close 1.53) on volume 0
    SLCA 2022-03-07 median close 16.41 over 3151 bars (2012-02-01..2024-08-13); bar 2024-08-01 close 0.00 (-100.00% vs prior close 15.49) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION PASS
V22 EXPECTATION 19 violations (62 skipped: position has no stop-decision rows)
    AAON 2022-11-11 no stop move for 13 weeks (2022-11-15..2023-02-17), 1 completed cycle(s) stalled; last: stop 69.91, candidate 45.88, ma 46.53, correction extreme 70.31 (extreme/ma 1.51)
    ANET 2023-06-02 no stop move for 38 weeks (2023-08-01..2024-04-26), 6 completed cycle(s) stalled; last: stop 155.94, candidate 61.80, ma 62.43, correction extreme 263.60 (extreme/ma 4.22)
    ARLP 2024-05-10 no stop move for 13 weeks (2024-05-31..2024-08-30), 1 completed cycle(s) stalled; last: stop 20.97, candidate 17.73, ma 17.91, correction extreme 23.17 (extreme/ma 1.29)
    ASR 2022-09-02 no stop move for 22 weeks (2022-10-24..2023-03-29), 2 completed cycle(s) stalled; last: stop 196.81, candidate 190.45, ma 192.37, correction extreme 261.40 (extreme/ma 1.36)
    AVGO 2024-02-02 no stop move for 24 weeks (2024-02-08..2024-07-26), 3 completed cycle(s) stalled; last: stop 1127.34, candidate 126.73, ma 128.01, correction extreme 1302.53 (extreme/ma 10.18)
    BSI 2021-10-01 no stop move for 18 weeks (2021-10-07..2022-02-11), 1 completed cycle(s) stalled; last: stop 24911.88, candidate 19008.88, ma 19201.08, correction extreme 28600.00 (extreme/ma 1.49)
    CNA 2022-02-04 no stop move for 13 weeks (2022-02-07..2022-05-10), 1 completed cycle(s) stalled; last: stop 41.87, candidate 36.13, ma 36.49, correction extreme 42.87 (extreme/ma 1.17)
    CTRA 2021-10-08 no stop move for 15 weeks (2022-02-04..2022-05-25), 4 completed cycle(s) stalled; last: stop 20.65, candidate 20.48, ma 20.69, correction extreme 26.91 (extreme/ma 1.30)
    GBX 2022-11-18 no stop move for 14 weeks (2023-06-29..2023-10-06), 1 completed cycle(s) stalled; last: stop 34.38, candidate 30.67, ma 30.98, correction extreme 41.34 (extreme/ma 1.33)
    KLAC 2025-05-23 no stop move for 52 weeks (2025-06-09..2026-06-12), 10 completed cycle(s) stalled; last: stop 714.88, candidate 165.88, ma 167.76, correction extreme 1927.73 (extreme/ma 11.49)
V23 EXPECTATION 11 violations
    WSBC 2022-10-18 filled 2022-10-18 after the 2022-10-14 screen read Bearish
    TR 2022-10-25 filled 2022-10-25 after the 2022-10-21 screen read Bearish
    SLNO 2025-04-23 filled 2025-04-23 after the 2025-04-11 screen read Bearish
    SFM 2022-11-09 filled 2022-11-09 after the 2022-11-04 screen read Bearish
    H 2022-11-03 filled 2022-11-03 after the 2022-10-28 screen read Bearish
    GNW 2022-10-26 filled 2022-10-26 after the 2022-10-21 screen read Bearish
    GLNG 2022-02-22 filled 2022-02-22 after the 2022-02-18 screen read Bearish
    FNB 2022-10-24 filled 2022-10-24 after the 2022-10-21 screen read Bearish
    CSGP 2025-04-23 filled 2025-04-23 after the 2025-04-11 screen read Bearish
    ASR 2022-10-24 filled 2022-10-24 after the 2022-10-21 screen read Bearish
