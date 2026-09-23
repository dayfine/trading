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
   ((id V7) (severity Invariant) (passed false) (n_violations 36)
    (n_skipped 0)
    (specimens
     (((symbol ZS) (entry_date 2020-05-29)
       (detail
        "Virgin_territory but only 117 weekly bars (< 520) before entry"))
      ((symbol XPOF) (entry_date 2023-01-27)
       (detail
        "Virgin_territory but only 79 weekly bars (< 520) before entry"))
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
      ((symbol PSTG) (entry_date 2025-01-22)
       (detail
        "Virgin_territory but only 488 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 52)
    (n_skipped 33)
    (specimens
     (((symbol ZGN) (entry_date 2023-09-08)
       (detail "prior_top=15.43 within +25% of entry=14.25"))
      ((symbol WLY) (entry_date 2021-02-05)
       (detail "prior_top=52.55 within +25% of entry=50.09"))
      ((symbol VRNS) (entry_date 2021-07-21)
       (detail "prior_top=71.50 within +25% of entry=60.99"))
      ((symbol URBN) (entry_date 2025-03-13)
       (detail "prior_top=58.19 within +25% of entry=50.12"))
      ((symbol TMHC) (entry_date 2021-02-06)
       (detail "prior_top=30.36 within +25% of entry=28.61"))
      ((symbol STVN) (entry_date 2023-03-02)
       (detail "prior_top=28.27 within +25% of entry=23.47"))
      ((symbol SAND) (entry_date 2025-06-02)
       (detail "prior_top=9.56 within +25% of entry=9.20"))
      ((symbol ROST) (entry_date 2023-11-14)
       (detail "prior_top=125.52 within +25% of entry=124.00"))
      ((symbol RDWR) (entry_date 2020-12-22)
       (detail "prior_top=28.14 within +25% of entry=27.14"))
      ((symbol PTGX) (entry_date 2025-06-02)
       (detail "prior_top=54.78 within +25% of entry=49.17")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 6)
    (n_skipped 33)
    (specimens
     (((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol GSIT) (entry_date 2025-10-20)
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
   ((id V12) (severity Invariant) (passed false) (n_violations 4)
    (n_skipped 0)
    (specimens
     (((symbol MNSO) (entry_date 2025-01-06)
       (detail
        "installed_stop=21.8400 vs fill=26.0100 -> dist=0.1603 > gate=0.1500"))
      ((symbol ELF) (entry_date 2021-09-07)
       (detail
        "installed_stop=26.7552 vs fill=31.6600 -> dist=0.1549 > gate=0.1500"))
      ((symbol DAR) (entry_date 2022-04-20)
       (detail
        "installed_stop=73.4880 vs fill=86.4900 -> dist=0.1503 > gate=0.1500"))
      ((symbol BRC) (entry_date 2024-05-22)
       (detail
        "installed_stop=53.8464 vs fill=63.3900 -> dist=0.1506 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 57)
    (n_skipped 1)
    (specimens
     (((symbol WRLD) (entry_date 2025-02-15)
       (detail
        "no bar on entry_date 2025-02-15 (nearest earlier bar: 2025-02-14)"))
      ((symbol WPM) (entry_date 2024-04-20)
       (detail
        "no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)"))
      ((symbol VIRT) (entry_date 2021-03-13)
       (detail
        "no bar on entry_date 2021-03-13 (nearest earlier bar: 2021-03-12)"))
      ((symbol URBN) (entry_date 2025-12-20)
       (detail
        "no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)"))
      ((symbol TNET) (entry_date 2019-02-23)
       (detail
        "no bar on entry_date 2019-02-23 (nearest earlier bar: 2019-02-22)"))
      ((symbol TMHC) (entry_date 2021-02-06)
       (detail
        "no bar on entry_date 2021-02-06 (nearest earlier bar: 2021-02-05)"))
      ((symbol TDS) (entry_date 2023-08-26)
       (detail
        "no bar on entry_date 2023-08-26 (nearest earlier bar: 2023-08-25)"))
      ((symbol SHEN) (entry_date 2020-03-21)
       (detail
        "no bar on entry_date 2020-03-21 (nearest earlier bar: 2020-03-20)"))
      ((symbol QIWI) (entry_date 2019-06-08)
       (detail
        "no bar on entry_date 2019-06-08 (nearest earlier bar: 2019-06-07)"))
      ((symbol PSMT) (entry_date 2025-05-03)
       (detail
        "no bar on entry_date 2025-05-03 (nearest earlier bar: 2025-05-02)")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 8)
    (n_skipped 0)
    (specimens
     (((symbol ANIP) (entry_date 2024-03-02)
       (detail
        "median close 17.05 over 6037 bars (2001-07-24..2025-12-24); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0"))
      ((symbol BLFS) (entry_date 2021-07-08)
       (detail
        "median close 1.68 over 9089 bars (1989-11-22..2025-12-24); bar 2014-01-29 close 8.12 (+1300.00% vs prior close 0.58) on volume 0"))
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
 (audit_join ((matched 275) (total 275))))
