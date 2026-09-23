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
   ((id V7) (severity Invariant) (passed false) (n_violations 30)
    (n_skipped 0)
    (specimens
     (((symbol ZS) (entry_date 2020-05-29)
       (detail
        "Virgin_territory but only 117 weekly bars (< 520) before entry"))
      ((symbol Z) (entry_date 2020-02-20)
       (detail
        "Virgin_territory but only 239 weekly bars (< 520) before entry"))
      ((symbol VAL) (entry_date 2022-10-27)
       (detail
        "Virgin_territory but only 77 weekly bars (< 520) before entry"))
      ((symbol TWST) (entry_date 2020-05-06)
       (detail
        "Virgin_territory but only 81 weekly bars (< 520) before entry"))
      ((symbol TRMD) (entry_date 2024-01-24)
       (detail
        "Virgin_territory but only 311 weekly bars (< 520) before entry"))
      ((symbol SSNC) (entry_date 2019-02-25)
       (detail
        "Virgin_territory but only 469 weekly bars (< 520) before entry"))
      ((symbol SNDR) (entry_date 2023-07-28)
       (detail
        "Virgin_territory but only 331 weekly bars (< 520) before entry"))
      ((symbol SHAK) (entry_date 2019-06-28)
       (detail
        "Virgin_territory but only 231 weekly bars (< 520) before entry"))
      ((symbol ROKU) (entry_date 2021-07-27)
       (detail
        "Virgin_territory but only 202 weekly bars (< 520) before entry"))
      ((symbol PLAN) (entry_date 2020-09-28)
       (detail
        "Virgin_territory but only 105 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 47)
    (n_skipped 36)
    (specimens
     (((symbol VRNS) (entry_date 2021-07-21)
       (detail "prior_top=71.50 within +25% of entry=60.92"))
      ((symbol TTWO) (entry_date 2020-05-19)
       (detail "prior_top=137.99 within +25% of entry=136.47"))
      ((symbol TNI) (entry_date 2019-06-10)
       (detail "prior_top=13350.00 within +25% of entry=12061.93"))
      ((symbol ROST) (entry_date 2023-11-14)
       (detail "prior_top=125.52 within +25% of entry=124.00"))
      ((symbol QNST) (entry_date 2025-01-07)
       (detail "prior_top=24.76 within +25% of entry=22.44"))
      ((symbol PTGX) (entry_date 2025-06-02)
       (detail "prior_top=54.78 within +25% of entry=49.19"))
      ((symbol PEN) (entry_date 2023-05-03)
       (detail "prior_top=305.99 within +25% of entry=294.41"))
      ((symbol ON) (entry_date 2021-08-27)
       (detail "prior_top=45.28 within +25% of entry=44.99"))
      ((symbol NVCR) (entry_date 2021-05-08)
       (detail "prior_top=207.63 within +25% of entry=195.97"))
      ((symbol NATL) (entry_date 2025-08-09)
       (detail "prior_top=37.11 within +25% of entry=36.39")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 5)
    (n_skipped 36)
    (specimens
     (((symbol WBTN) (entry_date 2025-08-30)
       (detail "entry_wk_close=14.41 > prior=8.92 (spike>60%)"))
      ((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol EXK) (entry_date 2020-07-20)
       (detail "entry_wk_close=4.20 > prior=2.14 (spike>60%)"))
      ((symbol CUTRQ) (entry_date 2022-03-28)
       (detail "entry_wk_close=72.31 > prior=40.49 (spike>60%)"))
      ((symbol BLNK) (entry_date 2020-07-29)
       (detail "entry_wk_close=11.05 > prior=5.28 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 4)
    (n_skipped 0)
    (specimens
     (((symbol QNST) (entry_date 2025-01-07)
       (detail
        "installed_stop=18.8016 vs fill=22.4400 -> dist=0.1621 > gate=0.1500"))
      ((symbol DNOW) (entry_date 2025-02-26)
       (detail
        "installed_stop=13.4784 vs fill=16.0300 -> dist=0.1592 > gate=0.1500"))
      ((symbol DAR) (entry_date 2022-04-20)
       (detail
        "installed_stop=73.4880 vs fill=86.4800 -> dist=0.1502 > gate=0.1500"))
      ((symbol APG) (entry_date 2021-08-24)
       (detail
        "installed_stop=19.8750 vs fill=23.4000 -> dist=0.1506 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 55)
    (n_skipped 1)
    (specimens
     (((symbol WPM) (entry_date 2024-04-20)
       (detail
        "no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)"))
      ((symbol WBTN) (entry_date 2025-08-30)
       (detail
        "no bar on entry_date 2025-08-30 (nearest earlier bar: 2025-08-29)"))
      ((symbol VCYT) (entry_date 2024-08-10)
       (detail
        "no bar on entry_date 2024-08-10 (nearest earlier bar: 2024-08-09)"))
      ((symbol TNET) (entry_date 2019-02-23)
       (detail
        "no bar on entry_date 2019-02-23 (nearest earlier bar: 2019-02-22)"))
      ((symbol SPH) (entry_date 2025-02-15)
       (detail
        "no bar on entry_date 2025-02-15 (nearest earlier bar: 2025-02-14)"))
      ((symbol SIRI) (entry_date 2023-07-22)
       (detail
        "no bar on entry_date 2023-07-22 (nearest earlier bar: 2023-07-21)"))
      ((symbol SBS) (entry_date 2024-08-10)
       (detail
        "no bar on entry_date 2024-08-10 (nearest earlier bar: 2024-08-09)"))
      ((symbol PSMT) (entry_date 2025-05-03)
       (detail
        "no bar on entry_date 2025-05-03 (nearest earlier bar: 2025-05-02)"))
      ((symbol PINS) (entry_date 2023-11-04)
       (detail
        "no bar on entry_date 2023-11-04 (nearest earlier bar: 2023-11-03)"))
      ((symbol OR) (entry_date 2021-05-15)
       (detail
        "no bar on entry_date 2021-05-15 (nearest earlier bar: 2021-05-14)")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 5)
    (n_skipped 0)
    (specimens
     (((symbol BLNK) (entry_date 2020-07-29)
       (detail
        "median close 1.67 over 3954 bars (2008-07-15..2025-12-08); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0"))
      ((symbol BOKF) (entry_date 2021-10-20)
       (detail
        "median close 49.27 over 8627 bars (1991-09-05..2025-12-08); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0"))
      ((symbol FLO) (entry_date 2020-03-09)
       (detail
        "median close 18.39 over 11527 bars (1980-03-17..2025-12-08); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0"))
      ((symbol IHG) (entry_date 2024-10-15)
       (detail
        "median close 36.19 over 5704 bars (2003-04-08..2025-12-08); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0"))
      ((symbol IOVA) (entry_date 2020-03-24)
       (detail
        "median close 7.67 over 3810 bars (2010-10-15..2025-12-08); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0")))))))
 (audit_join ((matched 271) (total 271))))
