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
   ((id V7) (severity Invariant) (passed false) (n_violations 22)
    (n_skipped 0)
    (specimens
     (((symbol XENE) (entry_date 2023-05-04)
       (detail
        "Virgin_territory but only 446 weekly bars (< 520) before entry"))
      ((symbol VVV) (entry_date 2021-10-13)
       (detail
        "Virgin_territory but only 266 weekly bars (< 520) before entry"))
      ((symbol TW) (entry_date 2025-03-18)
       (detail
        "Virgin_territory but only 313 weekly bars (< 520) before entry"))
      ((symbol SNDX) (entry_date 2023-01-12)
       (detail
        "Virgin_territory but only 360 weekly bars (< 520) before entry"))
      ((symbol SKWD) (entry_date 2025-04-23)
       (detail
        "Virgin_territory but only 120 weekly bars (< 520) before entry"))
      ((symbol PSTG) (entry_date 2025-01-22)
       (detail
        "Virgin_territory but only 488 weekly bars (< 520) before entry"))
      ((symbol PANW) (entry_date 2021-07-29)
       (detail
        "Virgin_territory but only 476 weekly bars (< 520) before entry"))
      ((symbol NEXT) (entry_date 2025-01-16)
       (detail
        "Virgin_territory but only 469 weekly bars (< 520) before entry"))
      ((symbol MIRM) (entry_date 2022-08-05)
       (detail
        "Virgin_territory but only 160 weekly bars (< 520) before entry"))
      ((symbol LQDA) (entry_date 2023-06-02)
       (detail
        "Virgin_territory but only 255 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 44)
    (n_skipped 17)
    (specimens
     (((symbol VNOM) (entry_date 2022-02-18)
       (detail "prior_top=26.35 within +25% of entry=25.96"))
      ((symbol UTHR) (entry_date 2022-06-02)
       (detail "prior_top=235.83 within +25% of entry=223.86"))
      ((symbol TW) (entry_date 2024-02-05)
       (detail "prior_top=98.25 within +25% of entry=97.71"))
      ((symbol TEAM) (entry_date 2021-06-28)
       (detail "prior_top=266.56 within +25% of entry=265.22"))
      ((symbol STE) (entry_date 2025-12-02)
       (detail "prior_top=264.82 within +25% of entry=259.36"))
      ((symbol SPB) (entry_date 2021-10-04)
       (detail "prior_top=98.59 within +25% of entry=97.90"))
      ((symbol RELX) (entry_date 2025-05-13)
       (detail "prior_top=52.71 within +25% of entry=52.25"))
      ((symbol PTCT) (entry_date 2025-09-10)
       (detail "prior_top=68.49 within +25% of entry=58.76"))
      ((symbol PTC) (entry_date 2023-09-05)
       (detail "prior_top=152.69 within +25% of entry=146.72"))
      ((symbol PRGS) (entry_date 2021-09-28)
       (detail "prior_top=51.02 within +25% of entry=50.46")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 7)
    (n_skipped 17)
    (specimens
     (((symbol LIDR) (entry_date 2025-07-25)
       (detail "entry_wk_close=4.43 > prior=0.90 (spike>60%)"))
      ((symbol HIMX) (entry_date 2026-05-08)
       (detail "entry_wk_close=17.48 > prior=9.05 (spike>60%)"))
      ((symbol DADA) (entry_date 2023-01-10)
       (detail "entry_wk_close=14.00 > prior=7.86 (spike>60%)"))
      ((symbol CLFD) (entry_date 2026-05-26)
       (detail "entry_wk_close=47.22 > prior=29.43 (spike>60%)"))
      ((symbol ARTV) (entry_date 2026-04-16)
       (detail "entry_wk_close=12.55 > prior=5.32 (spike>60%)"))
      ((symbol APLD) (entry_date 2025-06-10)
       (detail "entry_wk_close=11.18 > prior=6.83 (spike>60%)"))
      ((symbol ALEC) (entry_date 2021-07-02)
       (detail "entry_wk_close=35.21 > prior=19.54 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 2)
    (n_skipped 0)
    (specimens
     (((symbol LZB) (entry_date 2024-07-15)
       (detail
        "installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500"))
      ((symbol APG) (entry_date 2021-08-24)
       (detail
        "installed_stop=19.8750 vs fill=23.4000 -> dist=0.1506 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 6)
    (n_skipped 0)
    (specimens
     (((symbol SKWD) (entry_date 2025-04-23)
       (detail
        "exit_price=53.6200 outside 2025-04-24 bar [53.6250, 54.8000]"))
      ((symbol DSNKY) (entry_date 2024-06-06)
       (detail
        "entry_price=37.0000 outside 2024-06-06 bar [37.0030, 37.0030]"))
      ((symbol CODYY) (entry_date 2025-06-30)
       (detail
        "entry_price=23.3900 outside 2025-06-30 bar [23.3920, 23.3920]"))
      ((symbol CHGCY) (entry_date 2025-06-09)
       (detail
        "entry_price=26.8400 outside 2025-06-09 bar [26.8410, 26.8410]"))
      ((symbol ABMD) (entry_date 2022-11-21)
       (detail
        "no bar on exit_date 2022-12-26 (nearest earlier bar: 2022-12-23)"))
      ((symbol AAGIY) (entry_date 2023-01-04)
       (detail
        "entry_price=46.7300 outside 2023-01-04 bar [46.7310, 46.7310]")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 11)
    (n_skipped 0)
    (specimens
     (((symbol SKWD) (entry_date 2025-04-23)
       (detail
        "entry bar 2025-04-23 open=56.0600 low=54.7200 close=54.8400 vs stop=53.6550, exit=53.6200"))
      ((symbol QFIN) (entry_date 2023-01-09)
       (detail
        "entry bar 2023-01-09 open=24.0000 low=23.2300 close=23.4900 vs stop=22.8480, exit=22.8100"))
      ((symbol NCNO) (entry_date 2024-03-28)
       (detail
        "entry bar 2024-03-28 open=36.0000 low=35.8700 close=37.3800 vs stop=35.9471, exit=35.9300"))
      ((symbol GENI) (entry_date 2025-07-21)
       (detail
        "entry bar 2025-07-21 open=11.7400 low=10.9650 close=11.0800 vs stop=10.8752, exit=10.8200"))
      ((symbol EVER) (entry_date 2025-03-17)
       (detail
        "entry bar 2025-03-17 open=26.4400 low=26.1100 close=28.0500 vs stop=26.8742, exit=26.7800"))
      ((symbol DTEGY) (entry_date 2025-10-29)
       (detail
        "entry bar 2025-10-29 open=33.6900 low=32.6400 close=32.7100 vs stop=28.1249, exit=31.6700"))
      ((symbol DADA) (entry_date 2023-01-10)
       (detail
        "entry bar 2023-01-10 open=12.2600 low=12.1600 close=13.8100 vs stop=12.8738, exit=12.8000"))
      ((symbol BJRI) (entry_date 2025-02-25)
       (detail
        "entry bar 2025-02-25 open=38.2000 low=37.8600 close=38.6300 vs stop=37.5026, exit=37.4300"))
      ((symbol BBW) (entry_date 2023-08-24)
       (detail
        "entry bar 2023-08-24 open=28.4400 low=25.9600 close=25.9800 vs stop=25.9206, exit=25.8000"))
      ((symbol ATEYY) (entry_date 2025-01-24)
       (detail
        "entry bar 2025-01-24 open=64.8800 low=64.5900 close=64.7900 vs stop=62.6549, exit=58.1000")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 4)
    (n_skipped 0)
    (specimens
     (((symbol AEL) (entry_date 2022-12-20)
       (detail
        "median close 16.73 over 5139 bars (2003-12-04..2024-05-14); bar 2024-05-13 close 0.00 (-100.00% vs prior close 56.47) on volume 0"))
      ((symbol APLS) (entry_date 2021-06-16)
       (detail
        "median close 32.83 over 2156 bars (2017-11-09..2026-06-10); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0"))
      ((symbol CECO) (entry_date 2026-05-05)
       (detail
        "median close 4.60 over 11473 bars (1980-12-02..2026-06-10); bar 1992-09-29 close 2.66 (+399.96% vs prior close 0.53) on volume 0"))
      ((symbol FERG) (entry_date 2023-12-13)
       (detail
        "median close 69.65 over 4399 bars (2001-07-20..2026-06-10); bar 2001-10-22 close 60.37 (-97.71% vs prior close 2641.96) on volume 0")))))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V21) (severity Expectation) (passed false) (n_violations 168)
    (n_skipped 0)
    (specimens
     (((symbol ZYME) (entry_date 2025-11-19)
       (detail
        "LONG installed_stop 20.6880 vs screener_proxy_stop 19.8260: 4.35% tighter > 3%"))
      ((symbol XENE) (entry_date 2023-05-04)
       (detail
        "LONG installed_stop 39.9360 vs screener_proxy_stop 38.2720: 4.35% tighter > 3%"))
      ((symbol WES) (entry_date 2026-05-26)
       (detail
        "LONG installed_stop 43.1616 vs screener_proxy_stop 41.3632: 4.35% tighter > 3%"))
      ((symbol WEC) (entry_date 2025-08-04)
       (detail
        "LONG installed_stop 106.8750 vs screener_proxy_stop 102.6352: 4.13% tighter > 3%"))
      ((symbol WCN) (entry_date 2023-12-13)
       (detail
        "LONG installed_stop 142.9824 vs screener_proxy_stop 137.0248: 4.35% tighter > 3%"))
      ((symbol VVV) (entry_date 2021-10-13)
       (detail
        "LONG installed_stop 33.4272 vs screener_proxy_stop 32.0344: 4.35% tighter > 3%"))
      ((symbol VNOM) (entry_date 2022-02-18)
       (detail
        "LONG installed_stop 24.4320 vs screener_proxy_stop 23.4140: 4.35% tighter > 3%"))
      ((symbol VEON) (entry_date 2025-08-11)
       (detail
        "LONG installed_stop 56.2464 vs screener_proxy_stop 53.9028: 4.35% tighter > 3%"))
      ((symbol UTHR) (entry_date 2022-06-02)
       (detail
        "LONG installed_stop 210.6912 vs screener_proxy_stop 201.9124: 4.35% tighter > 3%"))
      ((symbol UGP) (entry_date 2023-11-01)
       (detail
        "LONG installed_stop 3.9648 vs screener_proxy_stop 3.7996: 4.35% tighter > 3%")))))
   ((id V22) (severity Expectation) (passed false) (n_violations 7)
    (n_skipped 160)
    (specimens
     (((symbol ACA) (entry_date 2023-03-03)
       (detail
        "no stop move for 14 weeks (2023-04-28..2023-08-04), 2 completed cycle(s) stalled; last: stop 63.48, candidate 62.88, ma 63.67, correction extreme 65.36 (extreme/ma 1.03)"))
      ((symbol ARGX) (entry_date 2022-04-08)
       (detail
        "no stop move for 13 weeks (2022-06-21..2022-09-22), 2 completed cycle(s) stalled; last: stop 344.22, candidate 338.70, ma 342.12, correction extreme 345.57 (extreme/ma 1.01)"))
      ((symbol CELH) (entry_date 2023-05-12)
       (detail
        "no stop move for 18 weeks (2023-05-26..2023-10-05), 3 completed cycle(s) stalled; last: stop 117.94, candidate 46.86, ma 47.34, correction extreme 167.16 (extreme/ma 3.53)"))
      ((symbol CRWD) (entry_date 2023-09-08)
       (detail
        "no stop move for 22 weeks (2023-11-10..2024-04-15), 2 completed cycle(s) stalled; last: stop 188.42, candidate 51.23, ma 51.75, correction extreme 238.61 (extreme/ma 4.61)"))
      ((symbol HSY) (entry_date 2021-12-10)
       (detail
        "no stop move for 22 weeks (2021-12-13..2022-05-19), 1 completed cycle(s) stalled; last: stop 176.28, candidate 164.44, ma 166.10, correction extreme 185.17 (extreme/ma 1.11)"))
      ((symbol MFC) (entry_date 2024-09-06)
       (detail
        "no stop move for 14 weeks (2024-09-11..2024-12-23), 2 completed cycle(s) stalled; last: stop 26.38, candidate 26.20, ma 26.46, correction extreme 29.07 (extreme/ma 1.10)"))
      ((symbol VVV) (entry_date 2021-09-24)
       (detail
        "no stop move for 14 weeks (2021-10-13..2022-01-20), 1 completed cycle(s) stalled; last: stop 33.43, candidate 32.84, ma 33.18, correction extreme 33.58 (extreme/ma 1.01)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed false) (n_violations 7)
    (n_skipped 0)
    (specimens
     (((symbol TTE) (entry_date 2022-06-07)
       (detail "filled 2022-06-07 after the 2022-06-03 screen read Bearish"))
      ((symbol STN) (entry_date 2025-05-01)
       (detail "filled 2025-05-01 after the 2025-04-25 screen read Bearish"))
      ((symbol SKWD) (entry_date 2025-04-23)
       (detail "filled 2025-04-23 after the 2025-04-11 screen read Bearish"))
      ((symbol DEN) (entry_date 2022-10-05)
       (detail "filled 2022-10-05 after the 2022-09-30 screen read Bearish"))
      ((symbol CIB) (entry_date 2022-03-02)
       (detail "filled 2022-03-02 after the 2022-02-25 screen read Bearish"))
      ((symbol BSM) (entry_date 2022-10-06)
       (detail "filled 2022-10-06 after the 2022-09-30 screen read Bearish"))
      ((symbol ARGX) (entry_date 2022-06-21)
       (detail "filled 2022-06-21 after the 2022-06-17 screen read Bearish")))))))
 (audit_join ((matched 218) (total 218))))
