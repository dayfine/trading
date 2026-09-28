((checks
  (((id V1) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 49) (specimens ()))
   ((id V2) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 49) (specimens ()))
   ((id V3) (severity Invariant) (passed true) (n_violations 0) (n_skipped 0)
    (specimens ()))
   ((id V4) (severity Invariant) (passed true) (n_violations 0) (n_skipped 0)
    (specimens ()))
   ((id V5) (severity Invariant) (passed true) (n_violations 0) (n_skipped 0)
    (specimens ()))
   ((id V6) (severity Invariant) (passed true) (n_violations 0) (n_skipped 0)
    (specimens ()))
   ((id V7) (severity Invariant) (passed false) (n_violations 19)
    (n_skipped 49)
    (specimens
     (((symbol TWLO) (entry_date 2026-04-22)
       (detail
        "Virgin_territory but only 517 weekly bars (< 520) before entry"))
      ((symbol TRMD) (entry_date 2024-01-24)
       (detail
        "Virgin_territory but only 311 weekly bars (< 520) before entry"))
      ((symbol TOST) (entry_date 2023-07-13)
       (detail
        "Virgin_territory but only 94 weekly bars (< 520) before entry"))
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
      ((symbol MNSO) (entry_date 2025-01-06)
       (detail
        "Virgin_territory but only 222 weekly bars (< 520) before entry"))
      ((symbol MNDT) (entry_date 2022-03-07)
       (detail
        "Virgin_territory but only 446 weekly bars (< 520) before entry"))
      ((symbol LQDA) (entry_date 2023-06-02)
       (detail
        "Virgin_territory but only 255 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 49) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 46)
    (n_skipped 19)
    (specimens
     (((symbol ZGN) (entry_date 2023-09-08)
       (detail "prior_top=15.43 within +25% of entry=14.25"))
      ((symbol VRNS) (entry_date 2021-07-21)
       (detail "prior_top=71.50 within +25% of entry=60.93"))
      ((symbol VAL) (entry_date 2022-11-18)
       (detail "prior_top=67.75 within +25% of entry=65.05"))
      ((symbol URBN) (entry_date 2025-03-13)
       (detail "prior_top=58.19 within +25% of entry=50.12"))
      ((symbol URBN) (entry_date 2025-12-22)
       (detail "prior_top=81.84 within +25% of entry=81.11"))
      ((symbol UMAC) (entry_date 2026-01-15)
       (detail "prior_top=18.73 within +25% of entry=17.69"))
      ((symbol STVN) (entry_date 2023-03-02)
       (detail "prior_top=28.27 within +25% of entry=23.43"))
      ((symbol STN) (entry_date 2026-02-12)
       (detail "prior_top=111.40 within +25% of entry=90.64"))
      ((symbol PTGX) (entry_date 2025-06-02)
       (detail "prior_top=54.78 within +25% of entry=49.15"))
      ((symbol PENG) (entry_date 2026-04-27)
       (detail "prior_top=35.49 within +25% of entry=30.55")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 3)
    (n_skipped 19)
    (specimens
     (((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol GSIT) (entry_date 2025-10-20)
       (detail "entry_wk_close=9.23 > prior=3.84 (spike>60%)"))
      ((symbol EOSE) (entry_date 2023-06-27)
       (detail "entry_wk_close=4.34 > prior=2.43 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 49) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 3)
    (n_skipped 49)
    (specimens
     (((symbol MNSO) (entry_date 2025-01-06)
       (detail
        "installed_stop=21.8400 vs fill=26.0100 -> dist=0.1603 > gate=0.1500"))
      ((symbol LZB) (entry_date 2024-07-15)
       (detail
        "installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500"))
      ((symbol EVCM) (entry_date 2026-01-20)
       (detail
        "installed_stop=10.4448 vs fill=12.5200 -> dist=0.1658 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 5)
    (n_skipped 1)
    (specimens
     (((symbol HZNP) (entry_date 2023-10-09)
       (detail
        "no bar on exit_date 2023-10-10 (nearest earlier bar: 2023-10-09)"))
      ((symbol EC) (entry_date 2022-03-15)
       (detail
        "entry_price=15.0600 outside 2022-03-15 bar [15.9500, 16.7200]"))
      ((symbol CIG) (entry_date 2022-04-12)
       (detail "exit_price=3.1700 outside 2022-04-19 bar [3.1701, 3.3500]"))
      ((symbol BAESY) (entry_date 2023-10-25)
       (detail
        "entry_price=53.2200 outside 2023-10-25 bar [53.2150, 53.2150]"))
      ((symbol AAGIY) (entry_date 2023-01-04)
       (detail
        "entry_price=46.7300 outside 2023-01-04 bar [46.7310, 46.7310]")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 18)
    (n_skipped 9)
    (specimens
     (((symbol WLFC) (entry_date 2026-04-15)
       (detail
        "entry bar 2026-04-15 open=210.8800 low=208.0900 close=209.7000 vs stop=203.3697, exit=203.3700"))
      ((symbol URBN) (entry_date 2025-12-22)
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
      ((symbol TWLO) (entry_date 2026-04-22)
       (detail
        "entry bar 2026-04-22 open=152.1100 low=146.8600 close=150.4500 vs stop=146.3824, exit=146.3600"))
      ((symbol TRMD) (entry_date 2024-01-24)
       (detail
        "entry bar 2024-01-24 open=36.5500 low=35.8800 close=35.9700 vs stop=35.3096, exit=35.2700"))
      ((symbol TOST) (entry_date 2023-07-13)
       (detail
        "entry bar 2023-07-13 open=24.9900 low=24.9000 close=25.9100 vs stop=24.8765, exit=24.8100"))
      ((symbol RCAT) (entry_date 2026-03-06)
       (detail
        "entry bar 2026-03-06 open=14.6100 low=14.6100 close=15.3600 vs stop=14.8727, exit=14.8200"))
      ((symbol QFIN) (entry_date 2024-04-11)
       (detail
        "entry bar 2024-04-11 open=20.2000 low=19.9400 close=20.0000 vs stop=19.6773, exit=19.2500")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 8)
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
      ((symbol DUOT) (entry_date 2026-06-08)
       (detail
        "median close 2.71 over 3134 bars (2008-08-13..2026-06-09); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0"))
      ((symbol NOKBF) (entry_date 2025-10-28)
       (detail
        "median close 5.96 over 4468 bars (2001-07-11..2026-06-09); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0"))
      ((symbol PECO) (entry_date 2023-07-24)
       (detail
        "median close 34.08 over 1328 bars (2021-02-25..2026-06-09); bar 2021-07-06 close 21.69 (+800.00% vs prior close 2.41) on volume 0"))
      ((symbol RCAT) (entry_date 2026-03-06)
       (detail
        "median close 0.02 over 7327 bars (1995-11-27..2026-06-09); bar 1996-04-10 close 5.00 (+7900.32% vs prior close 0.06) on volume 0"))
      ((symbol VTNRQ) (entry_date 2022-05-31)
       (detail
        "median close 1.36 over 7522 bars (1992-10-21..2025-01-21); bar 2003-11-11 close 0.00 (-90.00% vs prior close 0.02) on volume 0")))))))
 (audit_join ((matched 154) (total 203))))
