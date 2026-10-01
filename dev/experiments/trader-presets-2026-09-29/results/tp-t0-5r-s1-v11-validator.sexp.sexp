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
   ((id V7) (severity Invariant) (passed false) (n_violations 26)
    (n_skipped 0)
    (specimens
     (((symbol ZIM) (entry_date 2024-09-27)
       (detail
        "Virgin_territory but only 191 weekly bars (< 520) before entry"))
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
      ((symbol PANW) (entry_date 2021-07-29)
       (detail
        "Virgin_territory but only 476 weekly bars (< 520) before entry"))
      ((symbol NXE) (entry_date 2022-04-13)
       (detail
        "Virgin_territory but only 456 weekly bars (< 520) before entry"))
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
   ((id V9) (severity Expectation) (passed false) (n_violations 46)
    (n_skipped 21)
    (specimens
     (((symbol UTHR) (entry_date 2022-06-02)
       (detail "prior_top=235.83 within +25% of entry=223.86"))
      ((symbol TRI) (entry_date 2024-06-21)
       (detail "prior_top=167.10 within +25% of entry=165.63"))
      ((symbol TEAM) (entry_date 2021-06-28)
       (detail "prior_top=266.56 within +25% of entry=265.22"))
      ((symbol SWX) (entry_date 2025-11-24)
       (detail "prior_top=81.18 within +25% of entry=81.10"))
      ((symbol STE) (entry_date 2025-12-02)
       (detail "prior_top=264.82 within +25% of entry=259.36"))
      ((symbol SPB) (entry_date 2021-10-04)
       (detail "prior_top=98.59 within +25% of entry=97.78"))
      ((symbol PTGX) (entry_date 2025-06-02)
       (detail "prior_top=54.78 within +25% of entry=49.19"))
      ((symbol PTCT) (entry_date 2025-09-10)
       (detail "prior_top=68.49 within +25% of entry=58.76"))
      ((symbol PRGS) (entry_date 2021-09-28)
       (detail "prior_top=51.02 within +25% of entry=50.46"))
      ((symbol OSG) (entry_date 2024-06-05)
       (detail "prior_top=22.48 within +25% of entry=18.25")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 8)
    (n_skipped 21)
    (specimens
     (((symbol LIDR) (entry_date 2025-07-25)
       (detail "entry_wk_close=4.43 > prior=0.90 (spike>60%)"))
      ((symbol HIMX) (entry_date 2026-05-08)
       (detail "entry_wk_close=17.48 > prior=9.05 (spike>60%)"))
      ((symbol GRPN) (entry_date 2025-03-26)
       (detail "entry_wk_close=18.82 > prior=11.12 (spike>60%)"))
      ((symbol FCEL) (entry_date 2026-05-01)
       (detail "entry_wk_close=13.31 > prior=6.60 (spike>60%)"))
      ((symbol DADA) (entry_date 2023-01-10)
       (detail "entry_wk_close=14.00 > prior=7.86 (spike>60%)"))
      ((symbol ARTV) (entry_date 2026-04-16)
       (detail "entry_wk_close=12.55 > prior=5.32 (spike>60%)"))
      ((symbol APLD) (entry_date 2025-06-10)
       (detail "entry_wk_close=11.18 > prior=6.83 (spike>60%)"))
      ((symbol ALEC) (entry_date 2021-07-02)
       (detail "entry_wk_close=35.21 > prior=19.54 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol LZB) (entry_date 2024-07-15)
       (detail
        "installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500"))
      ((symbol DAR) (entry_date 2022-04-20)
       (detail
        "installed_stop=73.4880 vs fill=86.4800 -> dist=0.1502 > gate=0.1500"))
      ((symbol APG) (entry_date 2021-08-24)
       (detail
        "installed_stop=19.8750 vs fill=23.4000 -> dist=0.1506 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 5)
    (n_skipped 0)
    (specimens
     (((symbol SKWD) (entry_date 2025-04-23)
       (detail
        "exit_price=53.6200 outside 2025-04-24 bar [53.6250, 54.8000]"))
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
   ((id V14) (severity Expectation) (passed false) (n_violations 16)
    (n_skipped 0)
    (specimens
     (((symbol SKWD) (entry_date 2025-04-23)
       (detail
        "entry bar 2025-04-23 open=56.0600 low=54.7200 close=54.8400 vs stop=53.6550, exit=53.6200"))
      ((symbol SDA) (entry_date 2023-07-12)
       (detail
        "entry bar 2023-07-12 open=14.1500 low=11.5500 close=11.7000 vs stop=10.4919, exit=10.4900"))
      ((symbol QFIN) (entry_date 2023-01-09)
       (detail
        "entry bar 2023-01-09 open=24.0000 low=23.2300 close=23.4900 vs stop=22.8480, exit=22.8100"))
      ((symbol PIPR) (entry_date 2023-12-06)
       (detail
        "entry bar 2023-12-06 open=161.4900 low=156.8300 close=157.3500 vs stop=156.4916, exit=156.4700"))
      ((symbol NXE) (entry_date 2022-04-13)
       (detail
        "entry bar 2022-04-13 open=6.3000 low=6.2820 close=6.3300 vs stop=6.2687, exit=6.2400"))
      ((symbol GFI) (entry_date 2023-05-04)
       (detail
        "entry bar 2023-05-04 open=17.2000 low=17.0600 close=17.4000 vs stop=16.3744, exit=16.1600"))
      ((symbol FHN) (entry_date 2023-03-10)
       (detail
        "entry bar 2023-03-10 open=20.3300 low=19.5300 close=20.1000 vs stop=18.7675, exit=18.8700"))
      ((symbol EVER) (entry_date 2025-03-17)
       (detail
        "entry bar 2025-03-17 open=26.4400 low=26.1100 close=28.0500 vs stop=26.8742, exit=26.8400"))
      ((symbol DTEGY) (entry_date 2025-10-29)
       (detail
        "entry bar 2025-10-29 open=33.6900 low=32.6400 close=32.7100 vs stop=28.1249, exit=31.6700"))
      ((symbol DADA) (entry_date 2023-01-10)
       (detail
        "entry bar 2023-01-10 open=12.2600 low=12.1600 close=13.8100 vs stop=12.8712, exit=12.8300")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 2)
    (n_skipped 0)
    (specimens
     (((symbol APLS) (entry_date 2021-06-16)
       (detail
        "median close 32.70 over 2166 bars (2017-11-09..2026-06-24); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0"))
      ((symbol FERG) (entry_date 2023-12-13)
       (detail
        "median close 69.80 over 4408 bars (2001-07-20..2026-06-24); bar 2001-10-22 close 60.37 (-97.71% vs prior close 2641.96) on volume 0")))))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V21) (severity Expectation) (passed false) (n_violations 177)
    (n_skipped 0)
    (specimens
     (((symbol ZIM) (entry_date 2024-09-27)
       (detail
        "LONG installed_stop 22.9824 vs screener_proxy_stop 22.0248: 4.35% tighter > 3%"))
      ((symbol YUM) (entry_date 2022-01-03)
       (detail
        "LONG installed_stop 130.9920 vs screener_proxy_stop 125.5340: 4.35% tighter > 3%"))
      ((symbol WEC) (entry_date 2025-08-04)
       (detail
        "LONG installed_stop 106.8750 vs screener_proxy_stop 102.6352: 4.13% tighter > 3%"))
      ((symbol WCN) (entry_date 2023-12-13)
       (detail
        "LONG installed_stop 142.9824 vs screener_proxy_stop 137.0248: 4.35% tighter > 3%"))
      ((symbol VVV) (entry_date 2021-10-13)
       (detail
        "LONG installed_stop 33.4272 vs screener_proxy_stop 32.0344: 4.35% tighter > 3%"))
      ((symbol UTHR) (entry_date 2022-06-02)
       (detail
        "LONG installed_stop 210.6912 vs screener_proxy_stop 201.9124: 4.35% tighter > 3%"))
      ((symbol UGP) (entry_date 2023-11-01)
       (detail
        "LONG installed_stop 3.9648 vs screener_proxy_stop 3.7996: 4.35% tighter > 3%"))
      ((symbol UBSI) (entry_date 2024-11-25)
       (detail
        "LONG installed_stop 42.3750 vs screener_proxy_stop 40.8204: 3.81% tighter > 3%"))
      ((symbol TW) (entry_date 2025-03-18)
       (detail
        "LONG installed_stop 136.7040 vs screener_proxy_stop 131.0080: 4.35% tighter > 3%"))
      ((symbol TTE) (entry_date 2022-06-07)
       (detail
        "LONG installed_stop 57.9264 vs screener_proxy_stop 55.5128: 4.35% tighter > 3%")))))
   ((id V22) (severity Expectation) (passed false) (n_violations 3)
    (n_skipped 157)
    (specimens
     (((symbol CELH) (entry_date 2023-05-12)
       (detail
        "no stop move for 18 weeks (2023-05-26..2023-10-05), 3 completed cycle(s) stalled; last: stop 117.94, candidate 55.24, ma 55.80, correction extreme 167.16 (extreme/ma 3.00)"))
      ((symbol CRWD) (entry_date 2023-09-01)
       (detail
        "no stop move for 22 weeks (2023-11-10..2024-04-15), 2 completed cycle(s) stalled; last: stop 188.42, candidate 61.32, ma 61.94, correction extreme 238.61 (extreme/ma 3.85)"))
      ((symbol VVV) (entry_date 2021-09-24)
       (detail
        "no stop move for 14 weeks (2021-10-13..2022-01-20), 1 completed cycle(s) stalled; last: stop 33.43, candidate 33.24, ma 34.98, correction extreme 33.58 (extreme/ma 0.96)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed false) (n_violations 9)
    (n_skipped 0)
    (specimens
     (((symbol TTE) (entry_date 2022-06-07)
       (detail "filled 2022-06-07 after the 2022-06-03 screen read Bearish"))
      ((symbol STN) (entry_date 2025-05-01)
       (detail "filled 2025-05-01 after the 2025-04-25 screen read Bearish"))
      ((symbol SKWD) (entry_date 2025-04-23)
       (detail "filled 2025-04-23 after the 2025-04-11 screen read Bearish"))
      ((symbol REGN) (entry_date 2022-10-13)
       (detail "filled 2022-10-13 after the 2022-10-07 screen read Bearish"))
      ((symbol HLN) (entry_date 2025-05-02)
       (detail "filled 2025-05-02 after the 2025-04-25 screen read Bearish"))
      ((symbol DEN) (entry_date 2022-10-05)
       (detail "filled 2022-10-05 after the 2022-09-30 screen read Bearish"))
      ((symbol CIB) (entry_date 2022-03-02)
       (detail "filled 2022-03-02 after the 2022-02-25 screen read Bearish"))
      ((symbol BSM) (entry_date 2022-10-06)
       (detail "filled 2022-10-06 after the 2022-09-30 screen read Bearish"))
      ((symbol ARGX) (entry_date 2022-06-21)
       (detail "filled 2022-06-21 after the 2022-06-17 screen read Bearish")))))))
 (audit_join ((matched 232) (total 232))))
