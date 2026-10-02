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
   ((id V7) (severity Invariant) (passed false) (n_violations 29)
    (n_skipped 0)
    (specimens
     (((symbol VAL) (entry_date 2022-10-27)
       (detail
        "Virgin_territory but only 77 weekly bars (< 520) before entry"))
      ((symbol TRMD) (entry_date 2024-01-24)
       (detail
        "Virgin_territory but only 311 weekly bars (< 520) before entry"))
      ((symbol SHOP) (entry_date 2021-06-21)
       (detail
        "Virgin_territory but only 320 weekly bars (< 520) before entry"))
      ((symbol ROKU) (entry_date 2021-07-27)
       (detail
        "Virgin_territory but only 202 weekly bars (< 520) before entry"))
      ((symbol NTRA) (entry_date 2021-09-23)
       (detail
        "Virgin_territory but only 327 weekly bars (< 520) before entry"))
      ((symbol NEXT) (entry_date 2025-01-16)
       (detail
        "Virgin_territory but only 469 weekly bars (< 520) before entry"))
      ((symbol NET) (entry_date 2024-12-17)
       (detail
        "Virgin_territory but only 276 weekly bars (< 520) before entry"))
      ((symbol MNDT) (entry_date 2022-03-07)
       (detail
        "Virgin_territory but only 446 weekly bars (< 520) before entry"))
      ((symbol MIRM) (entry_date 2022-08-05)
       (detail
        "Virgin_territory but only 160 weekly bars (< 520) before entry"))
      ((symbol LQDA) (entry_date 2023-06-02)
       (detail
        "Virgin_territory but only 255 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 54)
    (n_skipped 21)
    (specimens
     (((symbol ZGN) (entry_date 2023-09-08)
       (detail "prior_top=15.43 within +25% of entry=14.25"))
      ((symbol WOLF_old2) (entry_date 2021-11-22)
       (detail "prior_top=139.55 within +25% of entry=133.00"))
      ((symbol WFG) (entry_date 2024-08-26)
       (detail "prior_top=92.49 within +25% of entry=90.10"))
      ((symbol VRNS) (entry_date 2021-07-21)
       (detail "prior_top=71.50 within +25% of entry=60.93"))
      ((symbol URBN) (entry_date 2025-03-13)
       (detail "prior_top=58.19 within +25% of entry=50.12"))
      ((symbol URBN) (entry_date 2025-12-22)
       (detail "prior_top=81.84 within +25% of entry=81.11"))
      ((symbol TTWO) (entry_date 2025-12-29)
       (detail "prior_top=261.35 within +25% of entry=255.00"))
      ((symbol RYAN) (entry_date 2024-04-04)
       (detail "prior_top=54.48 within +25% of entry=51.91"))
      ((symbol ROST) (entry_date 2023-11-14)
       (detail "prior_top=125.52 within +25% of entry=124.00"))
      ((symbol PTGX) (entry_date 2025-06-02)
       (detail "prior_top=54.78 within +25% of entry=49.15")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 2)
    (n_skipped 21)
    (specimens
     (((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol BTDR) (entry_date 2024-11-29)
       (detail "entry_wk_close=14.27 > prior=7.83 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 4)
    (n_skipped 0)
    (specimens
     (((symbol YMM) (entry_date 2024-11-20)
       (detail
        "installed_stop=8.2848 vs fill=9.7700 -> dist=0.1520 > gate=0.1500"))
      ((symbol NNI) (entry_date 2025-03-06)
       (detail
        "installed_stop=97.8048 vs fill=116.9600 -> dist=0.1638 > gate=0.1500"))
      ((symbol LPG) (entry_date 2023-09-15)
       (detail
        "installed_stop=23.2022 vs fill=27.3000 -> dist=0.1501 > gate=0.1500"))
      ((symbol BRC) (entry_date 2024-05-22)
       (detail
        "installed_stop=53.8464 vs fill=63.3500 -> dist=0.1500 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 6)
    (n_skipped 1)
    (specimens
     (((symbol NTTYY) (entry_date 2024-01-16)
       (detail
        "entry_price=31.7800 outside 2024-01-16 bar [31.7820, 31.7820]"))
      ((symbol EC) (entry_date 2022-02-28)
       (detail
        "entry_price=14.7700 outside 2022-02-28 bar [15.4800, 16.1900]"))
      ((symbol CRCT) (entry_date 2025-07-02)
       (detail "entry_price=6.3700 outside 2025-07-02 bar [6.9100, 7.2150]"))
      ((symbol CIG) (entry_date 2022-04-12)
       (detail "exit_price=3.1700 outside 2022-04-19 bar [3.1701, 3.3500]"))
      ((symbol AZPN) (entry_date 2025-01-30)
       (detail
        "no bar on exit_date 2025-03-13 (nearest earlier bar: 2025-03-12)"))
      ((symbol AAGIY) (entry_date 2023-01-04)
       (detail
        "entry_price=46.7300 outside 2023-01-04 bar [46.7310, 46.7310]")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 25)
    (n_skipped 0)
    (specimens
     (((symbol URBN) (entry_date 2025-12-22)
       (detail
        "entry bar 2025-12-22 open=80.4200 low=79.8700 close=80.1200 vs stop=77.8656, exit=77.8600"))
      ((symbol UMBF) (entry_date 2024-07-31)
       (detail
        "entry bar 2024-07-31 open=103.0000 low=100.7500 close=102.0200 vs stop=100.9806, exit=100.8300"))
      ((symbol UEC) (entry_date 2021-10-18)
       (detail
        "entry bar 2021-10-18 open=3.4600 low=3.4300 close=3.4900 vs stop=3.3780, exit=3.3500"))
      ((symbol UEC) (entry_date 2022-04-08)
       (detail
        "entry bar 2022-04-08 open=5.5500 low=5.3400 close=5.5000 vs stop=5.3721, exit=5.3600"))
      ((symbol TRMD) (entry_date 2024-01-24)
       (detail
        "entry bar 2024-01-24 open=36.5500 low=35.8800 close=35.9700 vs stop=35.3096, exit=35.2700"))
      ((symbol TGLS) (entry_date 2023-01-27)
       (detail
        "entry bar 2023-01-27 open=33.8000 low=33.4600 close=33.7600 vs stop=33.6642, exit=33.6300"))
      ((symbol ODFL) (entry_date 2023-02-02)
       (detail
        "entry bar 2023-02-02 open=373.2500 low=368.7600 close=371.4100 vs stop=360.4329, exit=360.4100"))
      ((symbol NTRA) (entry_date 2021-09-23)
       (detail
        "entry bar 2021-09-23 open=125.6700 low=122.0250 close=123.5400 vs stop=122.7168, exit=121.9000"))
      ((symbol NET) (entry_date 2024-12-17)
       (detail
        "entry bar 2024-12-17 open=118.2300 low=116.0101 close=117.5600 vs stop=111.9165, exit=111.8600"))
      ((symbol MNDT) (entry_date 2022-03-07)
       (detail
        "entry bar 2022-03-07 open=19.3800 low=18.5450 close=22.4900 vs stop=21.9894, exit=21.7300")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 5)
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
        "median close 2.71 over 3134 bars (2008-08-13..2026-06-09); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0")))))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V21) (severity Expectation) (passed false) (n_violations 162)
    (n_skipped 0)
    (specimens
     (((symbol ZGN) (entry_date 2023-09-08)
       (detail
        "LONG installed_stop 13.4112 vs screener_proxy_stop 12.8524: 4.35% tighter > 3%"))
      ((symbol WSR) (entry_date 2026-02-26)
       (detail
        "LONG installed_stop 14.8224 vs screener_proxy_stop 14.2048: 4.35% tighter > 3%"))
      ((symbol VVX) (entry_date 2026-01-22)
       (detail
        "LONG installed_stop 67.2960 vs screener_proxy_stop 64.4920: 4.35% tighter > 3%"))
      ((symbol VRSK) (entry_date 2023-06-05)
       (detail
        "LONG installed_stop 214.2912 vs screener_proxy_stop 205.3624: 4.35% tighter > 3%"))
      ((symbol VRNS) (entry_date 2021-07-21)
       (detail
        "LONG installed_stop 58.4640 vs screener_proxy_stop 56.0280: 4.35% tighter > 3%"))
      ((symbol VAL) (entry_date 2022-10-27)
       (detail
        "LONG installed_stop 61.2192 vs screener_proxy_stop 58.6684: 4.35% tighter > 3%"))
      ((symbol URBN) (entry_date 2025-03-13)
       (detail
        "LONG installed_stop 47.1744 vs screener_proxy_stop 45.2088: 4.35% tighter > 3%"))
      ((symbol URBN) (entry_date 2025-12-22)
       (detail
        "LONG installed_stop 77.8656 vs screener_proxy_stop 74.6212: 4.35% tighter > 3%"))
      ((symbol UMBF) (entry_date 2024-07-31)
       (detail
        "LONG installed_stop 100.9824 vs screener_proxy_stop 96.7748: 4.35% tighter > 3%"))
      ((symbol TRMD) (entry_date 2024-01-24)
       (detail
        "LONG installed_stop 35.3088 vs screener_proxy_stop 33.8376: 4.35% tighter > 3%")))))
   ((id V22) (severity Expectation) (passed false) (n_violations 7)
    (n_skipped 175)
    (specimens
     (((symbol AAON) (entry_date 2022-08-12)
       (detail
        "no stop move for 14 weeks (2023-02-28..2023-06-09), 1 completed cycle(s) stalled; last: stop 80.84, candidate 57.63, ma 58.21, correction extreme 85.00 (extreme/ma 1.46)"))
      ((symbol BBSI) (entry_date 2022-03-25)
       (detail
        "no stop move for 15 weeks (2022-10-31..2023-02-17), 1 completed cycle(s) stalled; last: stop 83.76, candidate 20.31, ma 20.51, correction extreme 84.91 (extreme/ma 4.14)"))
      ((symbol BMY) (entry_date 2022-01-21)
       (detail
        "no stop move for 20 weeks (2022-03-15..2022-08-05), 1 completed cycle(s) stalled; last: stop 67.30, candidate 62.77, ma 63.41, correction extreme 71.71 (extreme/ma 1.13)"))
      ((symbol BOKF) (entry_date 2021-10-15)
       (detail
        "no stop move for 18 weeks (2021-10-20..2022-02-24), 2 completed cycle(s) stalled; last: stop 95.46, candidate 94.66, ma 95.62, correction extreme 97.77 (extreme/ma 1.02)"))
      ((symbol CPNG) (entry_date 2025-02-21)
       (detail
        "no stop move for 13 weeks (2025-05-15..2025-08-15), 1 completed cycle(s) stalled; last: stop 25.96, candidate 25.88, ma 28.06, correction extreme 26.31 (extreme/ma 0.94)"))
      ((symbol LPG) (entry_date 2023-09-08)
       (detail
        "no stop move for 21 weeks (2023-09-15..2024-02-09), 1 completed cycle(s) stalled; last: stop 23.20, candidate 20.38, ma 20.76, correction extreme 25.58 (extreme/ma 1.23)"))
      ((symbol MFC) (entry_date 2022-01-28)
       (detail
        "no stop move for 14 weeks (2024-01-31..2024-05-09), 1 completed cycle(s) stalled; last: stop 21.47, candidate 21.32, ma 21.89, correction extreme 21.54 (extreme/ma 0.98)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed false) (n_violations 9)
    (n_skipped 0)
    (specimens
     (((symbol VAL) (entry_date 2022-10-27)
       (detail "filled 2022-10-27 after the 2022-10-21 screen read Bearish"))
      ((symbol STN) (entry_date 2025-05-01)
       (detail "filled 2025-05-01 after the 2025-04-25 screen read Bearish"))
      ((symbol MZTI) (entry_date 2022-10-26)
       (detail "filled 2022-10-26 after the 2022-10-21 screen read Bearish"))
      ((symbol FSS) (entry_date 2022-11-10)
       (detail "filled 2022-11-10 after the 2022-11-04 screen read Bearish"))
      ((symbol FN) (entry_date 2022-11-11)
       (detail "filled 2022-11-11 after the 2022-11-04 screen read Bearish"))
      ((symbol EC) (entry_date 2022-02-28)
       (detail "filled 2022-02-28 after the 2022-02-25 screen read Bearish"))
      ((symbol BMI) (entry_date 2022-10-26)
       (detail "filled 2022-10-26 after the 2022-10-21 screen read Bearish"))
      ((symbol BBSI) (entry_date 2022-10-31)
       (detail "filled 2022-10-31 after the 2022-10-28 screen read Bearish"))
      ((symbol ADMA) (entry_date 2025-04-28)
       (detail "filled 2025-04-28 after the 2025-04-25 screen read Bearish")))))))
 (audit_join ((matched 216) (total 216))))
