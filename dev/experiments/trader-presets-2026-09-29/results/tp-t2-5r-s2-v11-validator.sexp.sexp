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
     "share-class map: /workspaces/trading-1/.claude/worktrees/sweep-trader/trading/test_data/share_classes.sexp"))
   ((id V7) (severity Invariant) (passed false) (n_violations 25)
    (n_skipped 0)
    (specimens
     (((symbol XERS) (entry_date 2024-02-14)
       (detail
        "Virgin_territory but only 297 weekly bars (< 520) before entry"))
      ((symbol VAL) (entry_date 2022-10-27)
       (detail
        "Virgin_territory but only 77 weekly bars (< 520) before entry"))
      ((symbol TWLO) (entry_date 2026-04-22)
       (detail
        "Virgin_territory but only 517 weekly bars (< 520) before entry"))
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
      ((symbol PFGC) (entry_date 2022-11-30)
       (detail
        "Virgin_territory but only 376 weekly bars (< 520) before entry"))
      ((symbol NTRA) (entry_date 2021-09-23)
       (detail
        "Virgin_territory but only 327 weekly bars (< 520) before entry"))
      ((symbol NEXT) (entry_date 2025-01-16)
       (detail
        "Virgin_territory but only 469 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 52)
    (n_skipped 16)
    (specimens
     (((symbol ZGN) (entry_date 2023-09-08)
       (detail "prior_top=15.43 within +25% of entry=14.25"))
      ((symbol VRNS) (entry_date 2021-07-21)
       (detail "prior_top=71.50 within +25% of entry=60.99"))
      ((symbol URBN) (entry_date 2025-03-13)
       (detail "prior_top=58.19 within +25% of entry=50.12"))
      ((symbol URBN) (entry_date 2025-12-22)
       (detail "prior_top=81.84 within +25% of entry=81.28"))
      ((symbol RYAN) (entry_date 2024-04-04)
       (detail "prior_top=54.48 within +25% of entry=51.91"))
      ((symbol ROST) (entry_date 2023-11-14)
       (detail "prior_top=125.52 within +25% of entry=124.00"))
      ((symbol PTGX) (entry_date 2025-06-02)
       (detail "prior_top=54.78 within +25% of entry=49.17"))
      ((symbol PENG) (entry_date 2026-04-27)
       (detail "prior_top=35.49 within +25% of entry=30.55"))
      ((symbol PEN) (entry_date 2023-05-03)
       (detail "prior_top=305.99 within +25% of entry=294.56"))
      ((symbol ORCL) (entry_date 2024-08-05)
       (detail "prior_top=141.64 within +25% of entry=128.21")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 7)
    (n_skipped 16)
    (specimens
     (((symbol VUZI) (entry_date 2026-05-29)
       (detail "entry_wk_close=4.60 > prior=2.84 (spike>60%)"))
      ((symbol VTNRQ) (entry_date 2022-05-16)
       (detail "entry_wk_close=14.40 > prior=8.84 (spike>60%)"))
      ((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol QBTS) (entry_date 2024-11-25)
       (detail "entry_wk_close=3.02 > prior=1.04 (spike>60%)"))
      ((symbol GSIT) (entry_date 2025-10-20)
       (detail "entry_wk_close=9.23 > prior=3.84 (spike>60%)"))
      ((symbol CUTRQ) (entry_date 2022-03-28)
       (detail "entry_wk_close=72.31 > prior=40.49 (spike>60%)"))
      ((symbol BTDR) (entry_date 2024-11-29)
       (detail "entry_wk_close=14.27 > prior=7.83 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 2)
    (n_skipped 0)
    (specimens
     (((symbol XERS) (entry_date 2024-02-14)
       (detail
        "installed_stop=2.6496 vs fill=3.1300 -> dist=0.1535 > gate=0.1500"))
      ((symbol SOUN) (entry_date 2024-04-02)
       (detail
        "installed_stop=4.3750 vs fill=5.2400 -> dist=0.1651 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 4)
    (n_skipped 1)
    (specimens
     (((symbol OSIS) (entry_date 2024-03-26)
       (detail
        "entry_price=140.9700 outside 2024-03-26 bar [137.3000, 140.9650]"))
      ((symbol GERN) (entry_date 2024-04-11)
       (detail "entry_price=3.7900 outside 2024-04-11 bar [3.4400, 3.7860]"))
      ((symbol CRCT) (entry_date 2025-07-02)
       (detail "entry_price=6.3600 outside 2025-07-02 bar [6.9100, 7.2150]"))
      ((symbol AAGIY) (entry_date 2023-01-04)
       (detail
        "entry_price=46.7300 outside 2023-01-04 bar [46.7310, 46.7310]")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 28)
    (n_skipped 0)
    (specimens
     (((symbol VUZI) (entry_date 2026-05-29)
       (detail
        "entry bar 2026-05-29 open=4.5200 low=4.2200 close=4.6000 vs stop=4.1413, exit=4.0400"))
      ((symbol URBN) (entry_date 2025-12-22)
       (detail
        "entry bar 2025-12-22 open=80.4200 low=79.8700 close=80.1200 vs stop=77.8662, exit=77.7900"))
      ((symbol UEC) (entry_date 2021-10-18)
       (detail
        "entry bar 2021-10-18 open=3.4600 low=3.4300 close=3.4900 vs stop=3.3749, exit=3.3300"))
      ((symbol UEC) (entry_date 2022-04-08)
       (detail
        "entry bar 2022-04-08 open=5.5500 low=5.3400 close=5.5000 vs stop=5.3728, exit=5.3600"))
      ((symbol TWLO) (entry_date 2026-04-22)
       (detail
        "entry bar 2026-04-22 open=152.1100 low=146.8600 close=150.4500 vs stop=146.3826, exit=146.3300"))
      ((symbol TRMD) (entry_date 2024-01-24)
       (detail
        "entry bar 2024-01-24 open=36.5500 low=35.8800 close=35.9700 vs stop=35.3118, exit=35.2700"))
      ((symbol TGS) (entry_date 2026-03-24)
       (detail
        "entry bar 2026-03-24 open=32.9100 low=32.8500 close=33.9900 vs stop=33.1561, exit=33.0800"))
      ((symbol TGLS) (entry_date 2023-01-27)
       (detail
        "entry bar 2023-01-27 open=33.8000 low=33.4600 close=33.7600 vs stop=33.6658, exit=33.5400"))
      ((symbol RCAT) (entry_date 2026-03-06)
       (detail
        "entry bar 2026-03-06 open=14.6100 low=14.6100 close=15.3600 vs stop=14.8752, exit=14.7400"))
      ((symbol QFIN) (entry_date 2024-04-11)
       (detail
        "entry bar 2024-04-11 open=20.2000 low=19.9400 close=20.0000 vs stop=19.6766, exit=19.2500")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 0)
    (specimens
     (((symbol TIPT) (entry_date 2025-09-25)
       (detail
        "force_liquidation exit 2025-09-26 (entry 2025-09-25 @ 27.13, exit @ 20.00)")))))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 8)
    (n_skipped 0)
    (specimens
     (((symbol ANIP) (entry_date 2024-03-04)
       (detail
        "median close 25.85 over 6148 bars (2001-07-24..2026-06-05); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0"))
      ((symbol APLS) (entry_date 2021-06-16)
       (detail
        "median close 32.90 over 2153 bars (2017-11-09..2026-06-05); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0"))
      ((symbol ATLKY) (entry_date 2026-01-15)
       (detail
        "median close 24.89 over 7434 bars (1996-11-18..2026-06-05); bar 2003-09-01 close 1000000.00 (+3311246.00% vs prior close 30.20) on volume 0"))
      ((symbol BOKF) (entry_date 2021-10-20)
       (detail
        "median close 49.72 over 8750 bars (1991-09-05..2026-06-05); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0"))
      ((symbol IHG) (entry_date 2024-10-15)
       (detail
        "median close 37.35 over 5827 bars (2003-04-08..2026-06-05); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0"))
      ((symbol LNG) (entry_date 2026-03-16)
       (detail
        "median close 27.68 over 8098 bars (1994-04-04..2026-06-05); bar 1994-07-19 close 6.00 (+500.00% vs prior close 1.00) on volume 0"))
      ((symbol RCAT) (entry_date 2026-03-06)
       (detail
        "median close 0.02 over 7325 bars (1995-11-27..2026-06-05); bar 1996-04-10 close 5.00 (+7900.32% vs prior close 0.06) on volume 0"))
      ((symbol VTNRQ) (entry_date 2022-05-16)
       (detail
        "median close 1.36 over 7522 bars (1992-10-21..2025-01-21); bar 2003-11-11 close 0.00 (-90.00% vs prior close 0.02) on volume 0")))))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V21) (severity Expectation) (passed false) (n_violations 157)
    (n_skipped 0)
    (specimens
     (((symbol ZGN) (entry_date 2023-09-08)
       (detail
        "LONG installed_stop 13.4112 vs screener_proxy_stop 12.8524: 4.35% tighter > 3%"))
      ((symbol WSR) (entry_date 2026-02-26)
       (detail
        "LONG installed_stop 14.8224 vs screener_proxy_stop 14.2048: 4.35% tighter > 3%"))
      ((symbol VUZI) (entry_date 2026-05-29)
       (detail
        "LONG installed_stop 4.1376 vs screener_proxy_stop 3.9652: 4.35% tighter > 3%"))
      ((symbol VTNRQ) (entry_date 2022-05-16)
       (detail
        "LONG installed_stop 13.8144 vs screener_proxy_stop 13.2388: 4.35% tighter > 3%"))
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
      ((symbol TWLO) (entry_date 2026-04-22)
       (detail
        "LONG installed_stop 146.3750 vs screener_proxy_stop 140.4932: 4.19% tighter > 3%")))))
   ((id V22) (severity Expectation) (passed false) (n_violations 5)
    (n_skipped 173)
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
      ((symbol CTO) (entry_date 2021-11-19)
       (detail
        "no stop move for 19 weeks (2021-12-22..2022-05-09), 2 completed cycle(s) stalled; last: stop 50.38, candidate 13.94, ma 14.08, correction extreme 56.24 (extreme/ma 3.99)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed false) (n_violations 8)
    (n_skipped 0)
    (specimens
     (((symbol VTNRQ) (entry_date 2022-05-16)
       (detail "filled 2022-05-16 after the 2022-05-13 screen read Bearish"))
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
      ((symbol BMI) (entry_date 2022-10-26)
       (detail "filled 2022-10-26 after the 2022-10-21 screen read Bearish"))
      ((symbol BBSI) (entry_date 2022-10-31)
       (detail "filled 2022-10-31 after the 2022-10-28 screen read Bearish")))))))
 (audit_join ((matched 210) (total 210))))
