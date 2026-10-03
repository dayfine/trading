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
   ((id V7) (severity Invariant) (passed false) (n_violations 30)
    (n_skipped 0)
    (specimens
     (((symbol XERS) (entry_date 2024-02-14)
       (detail
        "Virgin_territory but only 297 weekly bars (< 520) before entry"))
      ((symbol TRIN) (entry_date 2026-01-12)
       (detail
        "Virgin_territory but only 261 weekly bars (< 520) before entry"))
      ((symbol TENB) (entry_date 2021-10-07)
       (detail
        "Virgin_territory but only 169 weekly bars (< 520) before entry"))
      ((symbol TENB) (entry_date 2023-03-21)
       (detail
        "Virgin_territory but only 245 weekly bars (< 520) before entry"))
      ((symbol SMRT) (entry_date 2023-06-07)
       (detail
        "Virgin_territory but only 122 weekly bars (< 520) before entry"))
      ((symbol SFM) (entry_date 2022-11-09)
       (detail
        "Virgin_territory but only 488 weekly bars (< 520) before entry"))
      ((symbol RSI) (entry_date 2021-10-05)
       (detail
        "Virgin_territory but only 76 weekly bars (< 520) before entry"))
      ((symbol PI) (entry_date 2025-08-13)
       (detail
        "Virgin_territory but only 476 weekly bars (< 520) before entry"))
      ((symbol PFGC) (entry_date 2022-11-14)
       (detail
        "Virgin_territory but only 374 weekly bars (< 520) before entry"))
      ((symbol NTRA) (entry_date 2021-07-22)
       (detail
        "Virgin_territory but only 318 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 51)
    (n_skipped 14)
    (specimens
     (((symbol WFG) (entry_date 2024-08-26)
       (detail "prior_top=92.49 within +25% of entry=90.52"))
      ((symbol TTGT) (entry_date 2021-08-31)
       (detail "prior_top=98.65 within +25% of entry=84.46"))
      ((symbol TSEM) (entry_date 2021-11-01)
       (detail "prior_top=35.67 within +25% of entry=33.00"))
      ((symbol TENB) (entry_date 2021-10-07)
       (detail "prior_top=54.68 within +25% of entry=49.33"))
      ((symbol TD) (entry_date 2023-01-26)
       (detail "prior_top=69.53 within +25% of entry=67.83"))
      ((symbol STE) (entry_date 2025-05-15)
       (detail "prior_top=240.43 within +25% of entry=240.30"))
      ((symbol SPHR) (entry_date 2024-02-29)
       (detail "prior_top=53.40 within +25% of entry=43.21"))
      ((symbol SKX) (entry_date 2025-01-14)
       (detail "prior_top=72.87 within +25% of entry=72.00"))
      ((symbol SI_old1) (entry_date 2021-10-11)
       (detail "prior_top=170.88 within +25% of entry=169.48"))
      ((symbol SFM) (entry_date 2022-11-09)
       (detail "prior_top=34.75 within +25% of entry=31.86")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 4)
    (n_skipped 14)
    (specimens
     (((symbol UPST) (entry_date 2024-08-19)
       (detail "entry_wk_close=42.00 > prior=26.11 (spike>60%)"))
      ((symbol TREE) (entry_date 2025-08-12)
       (detail "entry_wk_close=63.52 > prior=37.93 (spike>60%)"))
      ((symbol LMND) (entry_date 2024-11-25)
       (detail "entry_wk_close=51.81 > prior=24.15 (spike>60%)"))
      ((symbol ASTS) (entry_date 2024-06-11)
       (detail "entry_wk_close=10.22 > prior=4.54 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 17)
    (n_skipped 0)
    (specimens
     (((symbol VRNS) (entry_date 2024-07-30)
       (detail
        "installed_stop=44.7552 vs fill=53.0400 -> dist=0.1562 > gate=0.1500"))
      ((symbol PFGC) (entry_date 2022-11-14)
       (detail
        "installed_stop=49.7280 vs fill=58.5500 -> dist=0.1507 > gate=0.1500"))
      ((symbol MUFG) (entry_date 2022-02-02)
       (detail
        "installed_stop=5.4240 vs fill=6.4200 -> dist=0.1551 > gate=0.1500"))
      ((symbol MNKD) (entry_date 2024-07-15)
       (detail
        "installed_stop=4.9440 vs fill=5.8700 -> dist=0.1578 > gate=0.1500"))
      ((symbol KROS) (entry_date 2024-01-22)
       (detail
        "installed_stop=46.3750 vs fill=54.5600 -> dist=0.1500 > gate=0.1500"))
      ((symbol JOE) (entry_date 2022-03-22)
       (detail
        "installed_stop=49.6320 vs fill=58.4000 -> dist=0.1501 > gate=0.1500"))
      ((symbol IOT) (entry_date 2023-12-14)
       (detail
        "installed_stop=30.9792 vs fill=36.7000 -> dist=0.1559 > gate=0.1500"))
      ((symbol HTZ) (entry_date 2023-03-06)
       (detail
        "installed_stop=17.3952 vs fill=20.4800 -> dist=0.1506 > gate=0.1500"))
      ((symbol EDIT) (entry_date 2021-09-02)
       (detail
        "installed_stop=58.8192 vs fill=69.2100 -> dist=0.1501 > gate=0.1500"))
      ((symbol DHT) (entry_date 2023-10-12)
       (detail
        "installed_stop=8.8750 vs fill=10.4600 -> dist=0.1515 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 6)
    (n_skipped 1)
    (specimens
     (((symbol OSIS) (entry_date 2024-03-26)
       (detail
        "entry_price=140.9700 outside 2024-03-26 bar [137.3000, 140.9650]"))
      ((symbol LYFT) (entry_date 2024-11-11)
       (detail
        "entry_price=19.0700 outside 2024-11-11 bar [17.7600, 19.0650]"))
      ((symbol JWN) (entry_date 2025-05-19)
       (detail
        "entry_price=25.2600 outside 2025-05-19 bar [24.3850, 25.2597]"))
      ((symbol HTZ) (entry_date 2023-03-06)
       (detail
        "entry_price=20.4800 outside 2023-03-06 bar [19.4000, 20.4799]"))
      ((symbol CNX) (entry_date 2022-01-18)
       (detail
        "entry_price=16.2000 outside 2022-01-18 bar [15.7600, 16.1950]"))
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
   ((id V18) (severity Expectation) (passed false) (n_violations 4)
    (n_skipped 0)
    (specimens
     (((symbol CYRX) (entry_date 2021-09-17)
       (detail
        "median close 2.90 over 5228 bars (2005-08-22..2026-06-03); bar 2010-02-05 close 9.30 (+900.00% vs prior close 0.93) on volume 0"))
      ((symbol JWN) (entry_date 2025-05-19)
       (detail
        "median close 30.25 over 13357 bars (1972-06-02..2025-05-20); bar 1981-08-10 close 32.25 (+3326.41% vs prior close 0.94) on volume 0"))
      ((symbol LAR) (entry_date 2021-09-10)
       (detail
        "median close 1.46 over 4454 bars (2008-09-18..2026-06-03); bar 2017-11-08 close 7.65 (+400.03% vs prior close 1.53) on volume 0"))
      ((symbol SLCA) (entry_date 2022-03-07)
       (detail
        "median close 16.41 over 3151 bars (2012-02-01..2024-08-13); bar 2024-08-01 close 0.00 (-100.00% vs prior close 15.49) on volume 0")))))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V21) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V22) (severity Expectation) (passed false) (n_violations 19)
    (n_skipped 63)
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
      ((symbol ASR) (entry_date 2022-09-02)
       (detail
        "no stop move for 22 weeks (2022-10-24..2023-03-29), 2 completed cycle(s) stalled; last: stop 196.81, candidate 190.45, ma 192.37, correction extreme 261.40 (extreme/ma 1.36)"))
      ((symbol AVGO) (entry_date 2024-02-02)
       (detail
        "no stop move for 24 weeks (2024-02-08..2024-07-26), 3 completed cycle(s) stalled; last: stop 1127.34, candidate 126.73, ma 128.01, correction extreme 1302.53 (extreme/ma 10.18)"))
      ((symbol BSI) (entry_date 2021-10-01)
       (detail
        "no stop move for 18 weeks (2021-10-07..2022-02-11), 1 completed cycle(s) stalled; last: stop 24911.88, candidate 19008.88, ma 19201.08, correction extreme 28600.00 (extreme/ma 1.49)"))
      ((symbol CNA) (entry_date 2022-02-04)
       (detail
        "no stop move for 13 weeks (2022-02-07..2022-05-10), 1 completed cycle(s) stalled; last: stop 41.87, candidate 36.13, ma 36.49, correction extreme 42.87 (extreme/ma 1.17)"))
      ((symbol CTRA) (entry_date 2021-10-08)
       (detail
        "no stop move for 15 weeks (2022-02-04..2022-05-25), 4 completed cycle(s) stalled; last: stop 20.65, candidate 20.48, ma 20.69, correction extreme 26.91 (extreme/ma 1.30)"))
      ((symbol GBX) (entry_date 2022-11-18)
       (detail
        "no stop move for 14 weeks (2023-06-29..2023-10-06), 1 completed cycle(s) stalled; last: stop 34.38, candidate 30.67, ma 30.98, correction extreme 41.34 (extreme/ma 1.33)"))
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
      ((symbol SFM) (entry_date 2022-11-09)
       (detail "filled 2022-11-09 after the 2022-11-04 screen read Bearish"))
      ((symbol H) (entry_date 2022-11-03)
       (detail "filled 2022-11-03 after the 2022-10-28 screen read Bearish"))
      ((symbol GNW) (entry_date 2022-10-26)
       (detail "filled 2022-10-26 after the 2022-10-21 screen read Bearish"))
      ((symbol GLNG) (entry_date 2022-02-22)
       (detail "filled 2022-02-22 after the 2022-02-18 screen read Bearish"))
      ((symbol FNB) (entry_date 2022-10-24)
       (detail "filled 2022-10-24 after the 2022-10-21 screen read Bearish"))
      ((symbol CSGP) (entry_date 2025-04-23)
       (detail "filled 2025-04-23 after the 2025-04-11 screen read Bearish"))
      ((symbol ASR) (entry_date 2022-10-24)
       (detail "filled 2022-10-24 after the 2022-10-21 screen read Bearish")))))))
 (audit_join ((matched 194) (total 194))))
