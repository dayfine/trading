((checks
  (((id V1) (severity Invariant) (passed true) (n_violations 0) (n_skipped 0)
    (specimens ()))
   ((id V2) (severity Invariant) (passed true) (n_violations 0) (n_skipped 0)
    (specimens ()))
   ((id V3) (severity Invariant) (passed true) (n_violations 0) (n_skipped 0)
    (specimens ()))
   ((id V4) (severity Invariant) (passed true) (n_violations 0) (n_skipped 0)
    (specimens ()))
   ((id V5) (severity Invariant) (passed true) (n_violations 0) (n_skipped 0)
    (specimens ()))
   ((id V6) (severity Invariant) (passed true) (n_violations 0) (n_skipped 0)
    (specimens ())
    (skip_reason
     "share-class map: /workspaces/trading-1/.claude/worktrees/sweep-anchor/trading/test_data/share_classes.sexp"))
   ((id V7) (severity Invariant) (passed false) (n_violations 21)
    (n_skipped 0)
    (specimens
     (((symbol XPEV) (entry_date 2021-11-23)
       (detail
        "Virgin_territory but only 65 weekly bars (< 520) before entry"))
      ((symbol XERS) (entry_date 2024-02-14)
       (detail
        "Virgin_territory but only 297 weekly bars (< 520) before entry"))
      ((symbol TNET) (entry_date 2023-04-28)
       (detail
        "Virgin_territory but only 477 weekly bars (< 520) before entry"))
      ((symbol TENB) (entry_date 2021-10-07)
       (detail
        "Virgin_territory but only 169 weekly bars (< 520) before entry"))
      ((symbol SMRT) (entry_date 2023-06-07)
       (detail
        "Virgin_territory but only 122 weekly bars (< 520) before entry"))
      ((symbol RSI) (entry_date 2021-10-05)
       (detail
        "Virgin_territory but only 76 weekly bars (< 520) before entry"))
      ((symbol RNAM) (entry_date 2025-08-28)
       (detail
        "Virgin_territory but only 273 weekly bars (< 520) before entry"))
      ((symbol PI) (entry_date 2025-08-13)
       (detail
        "Virgin_territory but only 476 weekly bars (< 520) before entry"))
      ((symbol PFGC) (entry_date 2022-11-14)
       (detail
        "Virgin_territory but only 374 weekly bars (< 520) before entry"))
      ((symbol MUSA) (entry_date 2023-06-29)
       (detail
        "Virgin_territory but only 518 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 41)
    (n_skipped 12)
    (specimens
     (((symbol X) (entry_date 2023-09-29)
       (detail "prior_top=37.63 within +25% of entry=32.68"))
      ((symbol WFG) (entry_date 2024-08-26)
       (detail "prior_top=92.49 within +25% of entry=90.43"))
      ((symbol USB) (entry_date 2024-08-28)
       (detail "prior_top=51.66 within +25% of entry=46.18"))
      ((symbol TSEM) (entry_date 2021-11-01)
       (detail "prior_top=35.67 within +25% of entry=33.03"))
      ((symbol TNET) (entry_date 2023-04-28)
       (detail "prior_top=104.23 within +25% of entry=91.95"))
      ((symbol TENB) (entry_date 2021-10-07)
       (detail "prior_top=54.68 within +25% of entry=49.33"))
      ((symbol TD) (entry_date 2023-02-03)
       (detail "prior_top=69.53 within +25% of entry=69.49"))
      ((symbol STE) (entry_date 2025-05-15)
       (detail "prior_top=240.43 within +25% of entry=240.30"))
      ((symbol SRPT) (entry_date 2024-05-07)
       (detail "prior_top=175.40 within +25% of entry=143.80"))
      ((symbol SPHR) (entry_date 2024-02-29)
       (detail "prior_top=53.40 within +25% of entry=44.06")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 3)
    (n_skipped 12)
    (specimens
     (((symbol UPST) (entry_date 2024-08-19)
       (detail "entry_wk_close=42.00 > prior=26.11 (spike>60%)"))
      ((symbol LMND) (entry_date 2024-11-25)
       (detail "entry_wk_close=51.81 > prior=24.15 (spike>60%)"))
      ((symbol ASTS) (entry_date 2024-06-11)
       (detail "entry_wk_close=10.22 > prior=4.54 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 12)
    (n_skipped 0)
    (specimens
     (((symbol SMRT) (entry_date 2023-06-07)
       (detail
        "installed_stop=3.2832 vs fill=3.8700 -> dist=0.1516 > gate=0.1500"))
      ((symbol PFGC) (entry_date 2022-11-14)
       (detail
        "installed_stop=49.7280 vs fill=58.6400 -> dist=0.1520 > gate=0.1500"))
      ((symbol MYGN) (entry_date 2022-08-08)
       (detail
        "installed_stop=23.7408 vs fill=27.9500 -> dist=0.1506 > gate=0.1500"))
      ((symbol MUFG) (entry_date 2022-02-02)
       (detail
        "installed_stop=5.4240 vs fill=6.4400 -> dist=0.1578 > gate=0.1500"))
      ((symbol IOT) (entry_date 2023-12-14)
       (detail
        "installed_stop=30.9792 vs fill=36.7000 -> dist=0.1559 > gate=0.1500"))
      ((symbol IMGN) (entry_date 2023-06-05)
       (detail
        "installed_stop=12.9216 vs fill=15.2800 -> dist=0.1543 > gate=0.1500"))
      ((symbol EVER) (entry_date 2025-03-17)
       (detail
        "installed_stop=23.4144 vs fill=27.6600 -> dist=0.1535 > gate=0.1500"))
      ((symbol CUK) (entry_date 2024-07-16)
       (detail
        "installed_stop=14.8750 vs fill=17.5300 -> dist=0.1515 > gate=0.1500"))
      ((symbol CTO) (entry_date 2021-12-22)
       (detail
        "installed_stop=50.3750 vs fill=19.4900 -> dist=1.5847 > gate=0.1500"))
      ((symbol CGNT) (entry_date 2026-05-06)
       (detail
        "installed_stop=8.8512 vs fill=10.4500 -> dist=0.1530 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 4)
    (n_skipped 2)
    (specimens
     (((symbol SMRT) (entry_date 2023-06-07)
       (detail "entry_price=3.8700 outside 2023-06-07 bar [3.5700, 3.8650]"))
      ((symbol QFIN) (entry_date 2022-12-13)
       (detail
        "entry_price=18.4500 outside 2022-12-13 bar [17.8700, 18.4450]"))
      ((symbol CORT) (entry_date 2024-06-04)
       (detail
        "entry_price=33.4700 outside 2024-06-04 bar [31.4000, 33.4650]"))
      ((symbol CGNT) (entry_date 2026-05-06)
       (detail "exit_price=8.9600 outside 2026-06-03 bar [8.9650, 9.6300]")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol FERG) (entry_date 2023-01-05)
       (detail
        "median close 69.58 over 4397 bars (2001-07-20..2026-06-08); bar 2001-10-22 close 60.37 (-97.71% vs prior close 2641.96) on volume 0"))
      ((symbol LAR) (entry_date 2021-09-10)
       (detail
        "median close 1.47 over 4457 bars (2008-09-18..2026-06-08); bar 2017-11-08 close 7.65 (+400.03% vs prior close 1.53) on volume 0"))
      ((symbol SLCA) (entry_date 2022-03-07)
       (detail
        "median close 16.41 over 3151 bars (2012-02-01..2024-08-13); bar 2024-08-01 close 0.00 (-100.00% vs prior close 15.49) on volume 0")))))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V21) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V22) (severity Expectation) (passed false) (n_violations 21)
    (n_skipped 44)
    (specimens
     (((symbol AAON) (entry_date 2022-11-11)
       (detail
        "no stop move for 13 weeks (2022-11-15..2023-02-17), 1 completed cycle(s) stalled; last: stop 69.91, candidate 45.88, ma 46.53, correction extreme 70.31 (extreme/ma 1.51)"))
      ((symbol ANET) (entry_date 2023-06-02)
       (detail
        "no stop move for 38 weeks (2023-08-01..2024-04-26), 6 completed cycle(s) stalled; last: stop 155.94, candidate 61.80, ma 62.43, correction extreme 263.60 (extreme/ma 4.22)"))
      ((symbol ARLP) (entry_date 2024-05-10)
       (detail
        "no stop move for 13 weeks (2024-05-31..2024-08-30), 1 completed cycle(s) stalled; last: stop 20.97, candidate 17.73, ma 17.91, correction extreme 23.17 (extreme/ma 1.29)"))
      ((symbol AVGO) (entry_date 2024-02-02)
       (detail
        "no stop move for 24 weeks (2024-02-08..2024-07-26), 3 completed cycle(s) stalled; last: stop 1127.34, candidate 126.73, ma 128.01, correction extreme 1302.53 (extreme/ma 10.18)"))
      ((symbol BSI) (entry_date 2021-10-01)
       (detail
        "no stop move for 18 weeks (2021-10-07..2022-02-11), 1 completed cycle(s) stalled; last: stop 24911.88, candidate 19008.88, ma 19201.08, correction extreme 28600.00 (extreme/ma 1.49)"))
      ((symbol CNA) (entry_date 2022-02-04)
       (detail
        "no stop move for 13 weeks (2022-02-07..2022-05-10), 1 completed cycle(s) stalled; last: stop 41.87, candidate 36.13, ma 36.49, correction extreme 42.87 (extreme/ma 1.17)"))
      ((symbol CTO) (entry_date 2021-11-19)
       (detail
        "no stop move for 26 weeks (2021-12-22..2022-06-27), 2 completed cycle(s) stalled; last: stop 50.38, candidate 13.28, ma 13.41, correction extreme 56.24 (extreme/ma 4.19)"))
      ((symbol CTRA) (entry_date 2021-10-08)
       (detail
        "no stop move for 15 weeks (2022-02-04..2022-05-25), 4 completed cycle(s) stalled; last: stop 20.65, candidate 20.48, ma 20.69, correction extreme 26.91 (extreme/ma 1.30)"))
      ((symbol GE) (entry_date 2023-03-24)
       (detail
        "no stop move for 30 weeks (2023-03-31..2023-10-30), 2 completed cycle(s) stalled; last: stop 82.99, candidate 77.13, ma 77.91, correction extreme 99.71 (extreme/ma 1.28)"))
      ((symbol KLAC) (entry_date 2025-05-23)
       (detail
        "no stop move for 52 weeks (2025-06-09..2026-06-12), 10 completed cycle(s) stalled; last: stop 714.88, candidate 165.88, ma 167.76, correction extreme 1927.73 (extreme/ma 11.49)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed false) (n_violations 11)
    (n_skipped 0)
    (specimens
     (((symbol WSBC) (entry_date 2022-10-18)
       (detail "filled 2022-10-18 after the 2022-10-14 screen read Bearish"))
      ((symbol TR) (entry_date 2022-10-25)
       (detail "filled 2022-10-25 after the 2022-10-21 screen read Bearish"))
      ((symbol SLNO) (entry_date 2025-04-23)
       (detail "filled 2025-04-23 after the 2025-04-11 screen read Bearish"))
      ((symbol KALV) (entry_date 2025-04-24)
       (detail "filled 2025-04-24 after the 2025-04-11 screen read Bearish"))
      ((symbol GNW) (entry_date 2022-10-26)
       (detail "filled 2022-10-26 after the 2022-10-21 screen read Bearish"))
      ((symbol GLNG) (entry_date 2022-02-22)
       (detail "filled 2022-02-22 after the 2022-02-18 screen read Bearish"))
      ((symbol FNB) (entry_date 2022-10-24)
       (detail "filled 2022-10-24 after the 2022-10-21 screen read Bearish"))
      ((symbol FMX) (entry_date 2025-04-17)
       (detail "filled 2025-04-17 after the 2025-04-11 screen read Bearish"))
      ((symbol CSGP) (entry_date 2025-04-23)
       (detail "filled 2025-04-23 after the 2025-04-11 screen read Bearish"))
      ((symbol ASR) (entry_date 2025-04-23)
       (detail "filled 2025-04-23 after the 2025-04-11 screen read Bearish")))))))
 (audit_join ((matched 174) (total 174))))
