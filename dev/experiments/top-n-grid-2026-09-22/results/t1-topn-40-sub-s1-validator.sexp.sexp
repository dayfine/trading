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
    (specimens ()))
   ((id V7) (severity Invariant) (passed false) (n_violations 32)
    (n_skipped 0)
    (specimens
     (((symbol ZS) (entry_date 2020-05-29)
       (detail
        "Virgin_territory but only 117 weekly bars (< 520) before entry"))
      ((symbol VAL) (entry_date 2022-10-27)
       (detail
        "Virgin_territory but only 77 weekly bars (< 520) before entry"))
      ((symbol TWST) (entry_date 2020-05-06)
       (detail
        "Virgin_territory but only 81 weekly bars (< 520) before entry"))
      ((symbol TRMD) (entry_date 2024-01-24)
       (detail
        "Virgin_territory but only 311 weekly bars (< 520) before entry"))
      ((symbol TOST) (entry_date 2023-07-13)
       (detail
        "Virgin_territory but only 94 weekly bars (< 520) before entry"))
      ((symbol SSNC) (entry_date 2019-02-25)
       (detail
        "Virgin_territory but only 469 weekly bars (< 520) before entry"))
      ((symbol SHAK) (entry_date 2019-06-28)
       (detail
        "Virgin_territory but only 231 weekly bars (< 520) before entry"))
      ((symbol ROKU) (entry_date 2021-07-27)
       (detail
        "Virgin_territory but only 202 weekly bars (< 520) before entry"))
      ((symbol PETQ) (entry_date 2021-04-26)
       (detail
        "Virgin_territory but only 199 weekly bars (< 520) before entry"))
      ((symbol PDD) (entry_date 2019-08-29)
       (detail
        "Virgin_territory but only 58 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 49)
    (n_skipped 31)
    (specimens
     (((symbol ZGN) (entry_date 2023-09-08)
       (detail "prior_top=15.43 within +25% of entry=14.25"))
      ((symbol VRNS) (entry_date 2021-07-21)
       (detail "prior_top=71.50 within +25% of entry=60.92"))
      ((symbol URBN) (entry_date 2025-03-13)
       (detail "prior_top=58.19 within +25% of entry=50.12"))
      ((symbol TTWO) (entry_date 2020-05-19)
       (detail "prior_top=137.99 within +25% of entry=136.47"))
      ((symbol STVN) (entry_date 2023-03-02)
       (detail "prior_top=28.27 within +25% of entry=23.47"))
      ((symbol SPNT) (entry_date 2025-04-05)
       (detail "prior_top=17.06 within +25% of entry=16.91"))
      ((symbol SAND) (entry_date 2025-06-02)
       (detail "prior_top=9.56 within +25% of entry=9.17"))
      ((symbol ROST) (entry_date 2023-11-14)
       (detail "prior_top=125.52 within +25% of entry=124.00"))
      ((symbol PJT) (entry_date 2023-11-03)
       (detail "prior_top=84.12 within +25% of entry=83.64"))
      ((symbol PEN) (entry_date 2023-05-03)
       (detail "prior_top=305.99 within +25% of entry=294.41")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 5)
    (n_skipped 31)
    (specimens
     (((symbol GSIT) (entry_date 2025-10-20)
       (detail "entry_wk_close=9.23 > prior=3.84 (spike>60%)"))
      ((symbol EXK) (entry_date 2020-07-20)
       (detail "entry_wk_close=4.20 > prior=2.14 (spike>60%)"))
      ((symbol EOSE) (entry_date 2023-06-27)
       (detail "entry_wk_close=4.34 > prior=2.43 (spike>60%)"))
      ((symbol CUTRQ) (entry_date 2022-03-28)
       (detail "entry_wk_close=72.31 > prior=40.49 (spike>60%)"))
      ((symbol BLNK) (entry_date 2020-07-29)
       (detail "entry_wk_close=11.05 > prior=5.28 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 5)
    (n_skipped 0)
    (specimens
     (((symbol QLYS) (entry_date 2021-01-20)
       (detail
        "installed_stop=106.9728 vs fill=125.8900 -> dist=0.1503 > gate=0.1500"))
      ((symbol MNSO) (entry_date 2025-01-06)
       (detail
        "installed_stop=21.8400 vs fill=26.0100 -> dist=0.1603 > gate=0.1500"))
      ((symbol ESI) (entry_date 2021-04-24)
       (detail
        "installed_stop=16.7424 vs fill=19.8900 -> dist=0.1583 > gate=0.1500"))
      ((symbol DAR) (entry_date 2022-04-20)
       (detail
        "installed_stop=73.4880 vs fill=86.4800 -> dist=0.1502 > gate=0.1500"))
      ((symbol BRC) (entry_date 2024-05-22)
       (detail
        "installed_stop=53.8464 vs fill=63.4700 -> dist=0.1516 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 51)
    (n_skipped 0)
    (specimens
     (((symbol WPM) (entry_date 2024-04-20)
       (detail
        "no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)"))
      ((symbol URBN) (entry_date 2025-12-20)
       (detail
        "no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)"))
      ((symbol UPS) (entry_date 2021-04-17)
       (detail
        "no bar on entry_date 2021-04-17 (nearest earlier bar: 2021-04-16)"))
      ((symbol TNET) (entry_date 2019-02-23)
       (detail
        "no bar on entry_date 2019-02-23 (nearest earlier bar: 2019-02-22)"))
      ((symbol TDS) (entry_date 2023-08-26)
       (detail
        "no bar on entry_date 2023-08-26 (nearest earlier bar: 2023-08-25)"))
      ((symbol SPNT) (entry_date 2025-04-05)
       (detail
        "no bar on entry_date 2025-04-05 (nearest earlier bar: 2025-04-04)"))
      ((symbol PSMT) (entry_date 2025-05-03)
       (detail
        "no bar on entry_date 2025-05-03 (nearest earlier bar: 2025-05-02)"))
      ((symbol PINS) (entry_date 2023-11-04)
       (detail
        "no bar on entry_date 2023-11-04 (nearest earlier bar: 2023-11-03)"))
      ((symbol PECO) (entry_date 2023-07-22)
       (detail
        "no bar on entry_date 2023-07-22 (nearest earlier bar: 2023-07-21)"))
      ((symbol ORCL) (entry_date 2024-03-23)
       (detail
        "no bar on entry_date 2024-03-23 (nearest earlier bar: 2024-03-22)")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 7)
    (n_skipped 0)
    (specimens
     (((symbol ANIP) (entry_date 2024-03-02)
       (detail
        "median close 17.05 over 6037 bars (2001-07-24..2025-12-24); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0"))
      ((symbol BLNK) (entry_date 2020-07-29)
       (detail
        "median close 1.67 over 3966 bars (2008-07-15..2025-12-24); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0"))
      ((symbol BOKF) (entry_date 2021-10-20)
       (detail
        "median close 49.33 over 8639 bars (1991-09-05..2025-12-24); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0"))
      ((symbol FLO) (entry_date 2020-03-09)
       (detail
        "median close 18.37 over 11539 bars (1980-03-17..2025-12-24); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0"))
      ((symbol IOVA) (entry_date 2020-03-24)
       (detail
        "median close 7.65 over 3822 bars (2010-10-15..2025-12-24); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0"))
      ((symbol NOKBF) (entry_date 2025-10-28)
       (detail
        "median close 5.86 over 4356 bars (2001-07-11..2025-12-24); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0"))
      ((symbol PECO) (entry_date 2023-07-22)
       (detail
        "median close 33.80 over 1215 bars (2021-02-25..2025-12-24); bar 2021-07-06 close 21.69 (+800.00% vs prior close 2.41) on volume 0")))))))
 (audit_join ((matched 266) (total 266))))
