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
   ((id V7) (severity Invariant) (passed false) (n_violations 21)
    (n_skipped 0)
    (specimens
     (((symbol VVV) (entry_date 2021-10-13)
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
        "Virgin_territory but only 255 weekly bars (< 520) before entry"))
      ((symbol LIDR) (entry_date 2025-07-25)
       (detail
        "Virgin_territory but only 237 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 45)
    (n_skipped 18)
    (specimens
     (((symbol UTHR) (entry_date 2022-06-02)
       (detail "prior_top=235.83 within +25% of entry=223.86"))
      ((symbol TEAM) (entry_date 2021-06-28)
       (detail "prior_top=266.56 within +25% of entry=265.22"))
      ((symbol SWX) (entry_date 2025-11-24)
       (detail "prior_top=81.18 within +25% of entry=81.00"))
      ((symbol SPB) (entry_date 2021-10-04)
       (detail "prior_top=98.59 within +25% of entry=97.90"))
      ((symbol RELX) (entry_date 2025-05-13)
       (detail "prior_top=52.71 within +25% of entry=52.25"))
      ((symbol PSMT) (entry_date 2024-05-13)
       (detail "prior_top=93.93 within +25% of entry=85.60"))
      ((symbol PRGS) (entry_date 2021-09-28)
       (detail "prior_top=51.02 within +25% of entry=50.46"))
      ((symbol OLLI) (entry_date 2025-01-03)
       (detail "prior_top=117.91 within +25% of entry=107.61"))
      ((symbol NMM) (entry_date 2024-09-18)
       (detail "prior_top=55.67 within +25% of entry=55.18"))
      ((symbol NABL) (entry_date 2024-07-01)
       (detail "prior_top=15.52 within +25% of entry=15.24")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 5)
    (n_skipped 18)
    (specimens
     (((symbol LIDR) (entry_date 2025-07-25)
       (detail "entry_wk_close=4.43 > prior=0.90 (spike>60%)"))
      ((symbol HIMX) (entry_date 2026-05-08)
       (detail "entry_wk_close=17.48 > prior=9.05 (spike>60%)"))
      ((symbol DADA) (entry_date 2023-01-10)
       (detail "entry_wk_close=14.00 > prior=7.86 (spike>60%)"))
      ((symbol APLD) (entry_date 2025-06-10)
       (detail "entry_wk_close=11.18 > prior=6.83 (spike>60%)"))
      ((symbol ALEC) (entry_date 2021-07-02)
       (detail "entry_wk_close=35.21 > prior=19.54 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol VLN) (entry_date 2026-05-26)
       (detail
        "installed_stop=2.9136 vs fill=3.4300 -> dist=0.1506 > gate=0.1500"))
      ((symbol DAR) (entry_date 2022-04-20)
       (detail
        "installed_stop=73.4880 vs fill=86.5100 -> dist=0.1505 > gate=0.1500"))
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
   ((id V14) (severity Expectation) (passed false) (n_violations 18)
    (n_skipped 0)
    (specimens
     (((symbol SKWD) (entry_date 2025-04-23)
       (detail
        "entry bar 2025-04-23 open=56.0600 low=54.7200 close=54.8400 vs stop=53.6550, exit=53.6200"))
      ((symbol SDA) (entry_date 2023-07-12)
       (detail
        "entry bar 2023-07-12 open=14.1500 low=11.5500 close=11.7000 vs stop=10.4919, exit=10.4400"))
      ((symbol QFIN) (entry_date 2023-01-09)
       (detail
        "entry bar 2023-01-09 open=24.0000 low=23.2300 close=23.4900 vs stop=22.8480, exit=22.8100"))
      ((symbol PIPR) (entry_date 2023-12-06)
       (detail
        "entry bar 2023-12-06 open=161.4900 low=156.8300 close=157.3500 vs stop=156.4954, exit=156.3400"))
      ((symbol NXE) (entry_date 2022-04-13)
       (detail
        "entry bar 2022-04-13 open=6.3000 low=6.2820 close=6.3300 vs stop=6.2666, exit=6.2200"))
      ((symbol NCNO) (entry_date 2024-03-28)
       (detail
        "entry bar 2024-03-28 open=36.0000 low=35.8700 close=37.3800 vs stop=35.9471, exit=35.9300"))
      ((symbol GFI) (entry_date 2023-05-04)
       (detail
        "entry bar 2023-05-04 open=17.2000 low=17.0600 close=17.4000 vs stop=16.3762, exit=16.1600"))
      ((symbol GENI) (entry_date 2025-07-21)
       (detail
        "entry bar 2025-07-21 open=11.7400 low=10.9650 close=11.0800 vs stop=10.8752, exit=10.8200"))
      ((symbol FHN) (entry_date 2023-03-10)
       (detail
        "entry bar 2023-03-10 open=20.3300 low=19.5300 close=20.1000 vs stop=18.7675, exit=18.8700"))
      ((symbol EVER) (entry_date 2025-03-17)
       (detail
        "entry bar 2025-03-17 open=26.4400 low=26.1100 close=28.0500 vs stop=26.8742, exit=26.7800")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol APLS) (entry_date 2021-06-16)
       (detail
        "median close 32.85 over 2155 bars (2017-11-09..2026-06-09); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0"))
      ((symbol CECO) (entry_date 2026-05-05)
       (detail
        "median close 4.59 over 11472 bars (1980-12-02..2026-06-09); bar 1992-09-29 close 2.66 (+399.96% vs prior close 0.53) on volume 0"))
      ((symbol FERG) (entry_date 2023-12-13)
       (detail
        "median close 69.61 over 4398 bars (2001-07-20..2026-06-09); bar 2001-10-22 close 60.37 (-97.71% vs prior close 2641.96) on volume 0")))))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V21) (severity Expectation) (passed false) (n_violations 181)
    (n_skipped 0)
    (specimens
     (((symbol YUM) (entry_date 2022-01-03)
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
      ((symbol VEON) (entry_date 2025-08-11)
       (detail
        "LONG installed_stop 56.2464 vs screener_proxy_stop 53.9028: 4.35% tighter > 3%"))
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
    (n_skipped 153)
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
   ((id V23) (severity Expectation) (passed false) (n_violations 8)
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
      ((symbol DEN) (entry_date 2022-10-05)
       (detail "filled 2022-10-05 after the 2022-09-30 screen read Bearish"))
      ((symbol CIB) (entry_date 2022-03-02)
       (detail "filled 2022-03-02 after the 2022-02-25 screen read Bearish"))
      ((symbol BSM) (entry_date 2022-10-06)
       (detail "filled 2022-10-06 after the 2022-09-30 screen read Bearish"))
      ((symbol ARGX) (entry_date 2022-06-21)
       (detail "filled 2022-06-21 after the 2022-06-17 screen read Bearish")))))))
 (audit_join ((matched 230) (total 230))))
