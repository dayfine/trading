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
     "share-class map: /workspaces/trading-1/.claude/worktrees/sweep-trader-rerun/trading/test_data/share_classes.sexp"))
   ((id V7) (severity Invariant) (passed false) (n_violations 25)
    (n_skipped 0)
    (specimens
     (((symbol XPOF) (entry_date 2023-01-27)
       (detail
        "Virgin_territory but only 79 weekly bars (< 520) before entry"))
      ((symbol VAL) (entry_date 2022-10-27)
       (detail
        "Virgin_territory but only 77 weekly bars (< 520) before entry"))
      ((symbol UE) (entry_date 2024-07-30)
       (detail
        "Virgin_territory but only 501 weekly bars (< 520) before entry"))
      ((symbol TRMD) (entry_date 2024-01-24)
       (detail
        "Virgin_territory but only 311 weekly bars (< 520) before entry"))
      ((symbol SHOP) (entry_date 2021-06-21)
       (detail
        "Virgin_territory but only 320 weekly bars (< 520) before entry"))
      ((symbol ROKU) (entry_date 2021-07-27)
       (detail
        "Virgin_territory but only 202 weekly bars (< 520) before entry"))
      ((symbol QBTS) (entry_date 2024-11-25)
       (detail
        "Virgin_territory but only 207 weekly bars (< 520) before entry"))
      ((symbol NTRA) (entry_date 2021-09-23)
       (detail
        "Virgin_territory but only 327 weekly bars (< 520) before entry"))
      ((symbol NEXT) (entry_date 2025-01-16)
       (detail
        "Virgin_territory but only 469 weekly bars (< 520) before entry"))
      ((symbol MNDT) (entry_date 2022-03-07)
       (detail
        "Virgin_territory but only 446 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 42)
    (n_skipped 15)
    (specimens
     (((symbol VRNS) (entry_date 2021-07-21)
       (detail "prior_top=71.50 within +25% of entry=60.92"))
      ((symbol URBN) (entry_date 2025-12-22)
       (detail "prior_top=81.84 within +25% of entry=81.15"))
      ((symbol ROST) (entry_date 2023-11-14)
       (detail "prior_top=125.52 within +25% of entry=124.00"))
      ((symbol PTGX) (entry_date 2025-06-02)
       (detail "prior_top=54.78 within +25% of entry=49.19"))
      ((symbol PSLV) (entry_date 2024-04-22)
       (detail "prior_top=10.04 within +25% of entry=9.21"))
      ((symbol PEN) (entry_date 2023-05-03)
       (detail "prior_top=305.99 within +25% of entry=294.41"))
      ((symbol ON) (entry_date 2021-08-27)
       (detail "prior_top=45.28 within +25% of entry=44.99"))
      ((symbol OKLO) (entry_date 2024-11-04)
       (detail "prior_top=21.67 within +25% of entry=19.27"))
      ((symbol NATL) (entry_date 2025-08-11)
       (detail "prior_top=37.11 within +25% of entry=36.39"))
      ((symbol MZTI) (entry_date 2022-10-26)
       (detail "prior_top=179.92 within +25% of entry=178.06")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 6)
    (n_skipped 15)
    (specimens
     (((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol QBTS) (entry_date 2024-11-25)
       (detail "entry_wk_close=3.02 > prior=1.04 (spike>60%)"))
      ((symbol OKLO) (entry_date 2024-11-04)
       (detail "entry_wk_close=24.47 > prior=9.15 (spike>60%)"))
      ((symbol GSIT) (entry_date 2025-10-20)
       (detail "entry_wk_close=9.23 > prior=3.84 (spike>60%)"))
      ((symbol CUTRQ) (entry_date 2022-03-28)
       (detail "entry_wk_close=72.31 > prior=40.49 (spike>60%)"))
      ((symbol BTDR) (entry_date 2024-11-29)
       (detail "entry_wk_close=14.27 > prior=7.83 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol MNSO) (entry_date 2025-01-06)
       (detail
        "installed_stop=21.8750 vs fill=26.0100 -> dist=0.1590 > gate=0.1500"))
      ((symbol LZB) (entry_date 2024-07-15)
       (detail
        "installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500"))
      ((symbol EVCM) (entry_date 2026-01-07)
       (detail
        "installed_stop=10.4448 vs fill=12.3100 -> dist=0.1515 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 2)
    (n_skipped 1)
    (specimens
     (((symbol EC) (entry_date 2022-02-28)
       (detail
        "entry_price=14.7700 outside 2022-02-28 bar [15.4800, 16.1900]"))
      ((symbol AAGIY) (entry_date 2023-01-04)
       (detail
        "entry_price=46.7300 outside 2023-01-04 bar [46.7310, 46.7310]")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 15)
    (n_skipped 0)
    (specimens
     (((symbol URBN) (entry_date 2025-12-22)
       (detail
        "entry bar 2025-12-22 open=80.4200 low=79.8700 close=80.1200 vs stop=77.8715, exit=77.8100"))
      ((symbol UMBF) (entry_date 2024-07-31)
       (detail
        "entry bar 2024-07-31 open=103.0000 low=100.7500 close=102.0200 vs stop=100.9806, exit=100.9500"))
      ((symbol UEC) (entry_date 2021-10-18)
       (detail
        "entry bar 2021-10-18 open=3.4600 low=3.4300 close=3.4900 vs stop=3.3722, exit=3.3600"))
      ((symbol TRMD) (entry_date 2024-01-24)
       (detail
        "entry bar 2024-01-24 open=36.5500 low=35.8800 close=35.9700 vs stop=35.3141, exit=35.2700"))
      ((symbol QBTS) (entry_date 2024-11-25)
       (detail
        "entry bar 2024-11-25 open=3.4200 low=2.7000 close=2.8900 vs stop=2.8713, exit=2.7000"))
      ((symbol NTRA) (entry_date 2021-09-23)
       (detail
        "entry bar 2021-09-23 open=125.6700 low=122.0250 close=123.5400 vs stop=122.7168, exit=121.9000"))
      ((symbol MNDT) (entry_date 2022-03-07)
       (detail
        "entry bar 2022-03-07 open=19.3800 low=18.5450 close=22.4900 vs stop=21.9963, exit=21.7300"))
      ((symbol IHT) (entry_date 2021-08-16)
       (detail
        "entry bar 2021-08-16 open=4.3500 low=4.0700 close=4.1900 vs stop=3.9342, exit=3.9300"))
      ((symbol IBKR) (entry_date 2023-01-18)
       (detail
        "entry bar 2023-01-18 open=80.8200 low=75.8100 close=80.9300 vs stop=79.9051, exit=79.8500"))
      ((symbol ENSG) (entry_date 2023-01-13)
       (detail
        "entry bar 2023-01-13 open=97.5000 low=97.5000 close=98.5300 vs stop=95.1900, exit=95.1500")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 6)
    (n_skipped 0)
    (specimens
     (((symbol ANIP) (entry_date 2024-03-04)
       (detail
        "median close 25.95 over 6150 bars (2001-07-24..2026-06-09); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0"))
      ((symbol APLS) (entry_date 2021-06-16)
       (detail
        "median close 32.85 over 2155 bars (2017-11-09..2026-06-09); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0"))
      ((symbol BOKF) (entry_date 2021-10-20)
       (detail
        "median close 49.74 over 8752 bars (1991-09-05..2026-06-09); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0"))
      ((symbol CECO) (entry_date 2024-12-09)
       (detail
        "median close 4.59 over 11472 bars (1980-12-02..2026-06-09); bar 1992-09-29 close 2.66 (+399.96% vs prior close 0.53) on volume 0"))
      ((symbol DUOT) (entry_date 2026-06-08)
       (detail
        "median close 2.71 over 3134 bars (2008-08-13..2026-06-09); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0"))
      ((symbol NOKBF) (entry_date 2025-10-28)
       (detail
        "median close 5.96 over 4468 bars (2001-07-11..2026-06-09); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0")))))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V21) (severity Expectation) (passed false) (n_violations 137)
    (n_skipped 0)
    (specimens
     (((symbol XPOF) (entry_date 2023-01-27)
       (detail
        "LONG installed_stop 25.9488 vs screener_proxy_stop 24.8676: 4.35% tighter > 3%"))
      ((symbol WSBC) (entry_date 2022-10-27)
       (detail
        "LONG installed_stop 38.4672 vs screener_proxy_stop 36.8644: 4.35% tighter > 3%"))
      ((symbol VRSK) (entry_date 2023-06-05)
       (detail
        "LONG installed_stop 214.2912 vs screener_proxy_stop 205.3624: 4.35% tighter > 3%"))
      ((symbol VRNS) (entry_date 2021-07-21)
       (detail
        "LONG installed_stop 58.4640 vs screener_proxy_stop 56.0280: 4.35% tighter > 3%"))
      ((symbol VAL) (entry_date 2022-10-27)
       (detail
        "LONG installed_stop 61.2192 vs screener_proxy_stop 58.6684: 4.35% tighter > 3%"))
      ((symbol URBN) (entry_date 2025-12-22)
       (detail
        "LONG installed_stop 77.8656 vs screener_proxy_stop 74.6212: 4.35% tighter > 3%"))
      ((symbol UMBF) (entry_date 2024-07-31)
       (detail
        "LONG installed_stop 100.9824 vs screener_proxy_stop 96.7748: 4.35% tighter > 3%"))
      ((symbol UE) (entry_date 2024-07-30)
       (detail
        "LONG installed_stop 19.3750 vs screener_proxy_stop 18.7956: 3.08% tighter > 3%"))
      ((symbol TRMD) (entry_date 2024-01-24)
       (detail
        "LONG installed_stop 35.3088 vs screener_proxy_stop 33.8376: 4.35% tighter > 3%"))
      ((symbol TDS) (entry_date 2023-08-28)
       (detail
        "LONG installed_stop 16.7232 vs screener_proxy_stop 16.0264: 4.35% tighter > 3%")))))
   ((id V22) (severity Expectation) (passed false) (n_violations 12)
    (n_skipped 149)
    (specimens
     (((symbol AAON) (entry_date 2022-08-12)
       (detail
        "no stop move for 14 weeks (2023-02-28..2023-06-09), 1 completed cycle(s) stalled; last: stop 80.84, candidate 51.88, ma 52.59, correction extreme 85.00 (extreme/ma 1.62)"))
      ((symbol AMX) (entry_date 2025-05-09)
       (detail
        "no stop move for 18 weeks (2025-08-22..2025-12-26), 2 completed cycle(s) stalled; last: stop 19.14, candidate 18.88, ma 19.25, correction extreme 20.86 (extreme/ma 1.08)"))
      ((symbol BBSI) (entry_date 2022-03-25)
       (detail
        "no stop move for 15 weeks (2022-10-31..2023-02-17), 1 completed cycle(s) stalled; last: stop 83.76, candidate 19.32, ma 19.51, correction extreme 84.91 (extreme/ma 4.35)"))
      ((symbol BKV) (entry_date 2025-11-28)
       (detail
        "no stop move for 14 weeks (2026-02-06..2026-05-15), 1 completed cycle(s) stalled; last: stop 25.92, candidate 25.78, ma 28.85, correction extreme 26.04 (extreme/ma 0.90)"))
      ((symbol BMY) (entry_date 2022-01-21)
       (detail
        "no stop move for 20 weeks (2022-03-15..2022-08-05), 1 completed cycle(s) stalled; last: stop 67.30, candidate 60.32, ma 60.93, correction extreme 71.71 (extreme/ma 1.18)"))
      ((symbol BOKF) (entry_date 2021-10-15)
       (detail
        "no stop move for 18 weeks (2021-10-20..2022-02-24), 2 completed cycle(s) stalled; last: stop 95.46, candidate 88.27, ma 89.16, correction extreme 97.77 (extreme/ma 1.10)"))
      ((symbol CPNG) (entry_date 2025-02-21)
       (detail
        "no stop move for 13 weeks (2025-05-15..2025-08-15), 1 completed cycle(s) stalled; last: stop 25.96, candidate 24.93, ma 25.18, correction extreme 26.31 (extreme/ma 1.04)"))
      ((symbol CTO) (entry_date 2021-11-19)
       (detail
        "no stop move for 19 weeks (2021-12-22..2022-05-09), 2 completed cycle(s) stalled; last: stop 50.38, candidate 13.28, ma 13.41, correction extreme 56.24 (extreme/ma 4.19)"))
      ((symbol EQNR) (entry_date 2025-03-28)
       (detail
        "no stop move for 17 weeks (2026-02-26..2026-06-25), 1 completed cycle(s) stalled; last: stop 28.29, candidate 24.73, ma 24.98, correction extreme 28.45 (extreme/ma 1.14)"))
      ((symbol GDDY) (entry_date 2023-11-03)
       (detail
        "no stop move for 13 weeks (2023-11-06..2024-02-05), 1 completed cycle(s) stalled; last: stop 82.32, candidate 76.67, ma 77.44, correction extreme 84.78 (extreme/ma 1.09)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed false) (n_violations 9)
    (n_skipped 0)
    (specimens
     (((symbol WSBC) (entry_date 2022-10-27)
       (detail "filled 2022-10-27 after the 2022-10-21 screen read Bearish"))
      ((symbol VAL) (entry_date 2022-10-27)
       (detail "filled 2022-10-27 after the 2022-10-21 screen read Bearish"))
      ((symbol MZTI) (entry_date 2022-10-26)
       (detail "filled 2022-10-26 after the 2022-10-21 screen read Bearish"))
      ((symbol HLN) (entry_date 2025-05-02)
       (detail "filled 2025-05-02 after the 2025-04-25 screen read Bearish"))
      ((symbol FSS) (entry_date 2022-11-10)
       (detail "filled 2022-11-10 after the 2022-11-04 screen read Bearish"))
      ((symbol FN) (entry_date 2022-11-11)
       (detail "filled 2022-11-11 after the 2022-11-04 screen read Bearish"))
      ((symbol EC) (entry_date 2022-02-28)
       (detail "filled 2022-02-28 after the 2022-02-25 screen read Bearish"))
      ((symbol BMI) (entry_date 2022-10-26)
       (detail "filled 2022-10-26 after the 2022-10-21 screen read Bearish"))
      ((symbol BBSI) (entry_date 2022-10-31)
       (detail "filled 2022-10-31 after the 2022-10-28 screen read Bearish")))))))
 (audit_join ((matched 183) (total 183))))
