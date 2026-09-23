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
   ((id V7) (severity Invariant) (passed false) (n_violations 35)
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
      ((symbol PLAN) (entry_date 2020-09-28)
       (detail
        "Virgin_territory but only 105 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 52)
    (n_skipped 36)
    (specimens
     (((symbol ZGN) (entry_date 2023-09-08)
       (detail "prior_top=15.43 within +25% of entry=14.25"))
      ((symbol VRNS) (entry_date 2021-07-21)
       (detail "prior_top=71.50 within +25% of entry=60.93"))
      ((symbol URBN) (entry_date 2025-03-13)
       (detail "prior_top=58.19 within +25% of entry=50.12"))
      ((symbol TNI) (entry_date 2019-06-10)
       (detail "prior_top=13350.00 within +25% of entry=12100.12"))
      ((symbol STVN) (entry_date 2023-03-02)
       (detail "prior_top=28.27 within +25% of entry=23.43"))
      ((symbol ROST) (entry_date 2023-11-14)
       (detail "prior_top=125.52 within +25% of entry=124.00"))
      ((symbol PJT) (entry_date 2023-11-03)
       (detail "prior_top=84.12 within +25% of entry=83.60"))
      ((symbol PEN) (entry_date 2023-05-03)
       (detail "prior_top=305.99 within +25% of entry=294.35"))
      ((symbol ON) (entry_date 2021-08-27)
       (detail "prior_top=45.28 within +25% of entry=44.85"))
      ((symbol NVCR) (entry_date 2021-05-08)
       (detail "prior_top=207.63 within +25% of entry=195.74")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 6)
    (n_skipped 36)
    (specimens
     (((symbol VTNRQ) (entry_date 2022-05-16)
       (detail "entry_wk_close=14.40 > prior=8.84 (spike>60%)"))
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
     (((symbol QLYS) (entry_date 2021-01-20)
       (detail
        "installed_stop=106.9728 vs fill=125.8900 -> dist=0.1503 > gate=0.1500"))
      ((symbol MNSO) (entry_date 2025-01-06)
       (detail
        "installed_stop=21.8400 vs fill=26.0100 -> dist=0.1603 > gate=0.1500"))
      ((symbol DNOW) (entry_date 2025-02-26)
       (detail
        "installed_stop=13.4784 vs fill=16.0300 -> dist=0.1592 > gate=0.1500"))
      ((symbol APG) (entry_date 2021-08-24)
       (detail
        "installed_stop=19.8750 vs fill=23.4000 -> dist=0.1506 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 55)
    (n_skipped 0)
    (specimens
     (((symbol WPM) (entry_date 2024-04-20)
       (detail
        "no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)"))
      ((symbol WMT) (entry_date 2019-08-31)
       (detail
        "no bar on entry_date 2019-08-31 (nearest earlier bar: 2019-08-30)"))
      ((symbol VIRT) (entry_date 2021-03-13)
       (detail
        "no bar on entry_date 2021-03-13 (nearest earlier bar: 2021-03-12)"))
      ((symbol TNET) (entry_date 2019-02-23)
       (detail
        "no bar on entry_date 2019-02-23 (nearest earlier bar: 2019-02-22)"))
      ((symbol TDS) (entry_date 2023-08-26)
       (detail
        "no bar on entry_date 2023-08-26 (nearest earlier bar: 2023-08-25)"))
      ((symbol QIWI) (entry_date 2019-06-08)
       (detail
        "no bar on entry_date 2019-06-08 (nearest earlier bar: 2019-06-07)"))
      ((symbol PSMT) (entry_date 2025-05-03)
       (detail
        "no bar on entry_date 2025-05-03 (nearest earlier bar: 2025-05-02)"))
      ((symbol PINS) (entry_date 2023-11-04)
       (detail
        "no bar on entry_date 2023-11-04 (nearest earlier bar: 2023-11-03)"))
      ((symbol ORCL) (entry_date 2024-03-23)
       (detail
        "no bar on entry_date 2024-03-23 (nearest earlier bar: 2024-03-22)"))
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
   ((id V18) (severity Expectation) (passed false) (n_violations 8)
    (n_skipped 0)
    (specimens
     (((symbol ANIP) (entry_date 2024-03-02)
       (detail
        "median close 17.12 over 6039 bars (2001-07-24..2025-12-29); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0"))
      ((symbol BLNK) (entry_date 2020-07-29)
       (detail
        "median close 1.67 over 3968 bars (2008-07-15..2025-12-29); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0"))
      ((symbol BOKF) (entry_date 2021-10-20)
       (detail
        "median close 49.34 over 8641 bars (1991-09-05..2025-12-29); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0"))
      ((symbol FLO) (entry_date 2020-03-09)
       (detail
        "median close 18.37 over 11541 bars (1980-03-17..2025-12-29); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0"))
      ((symbol IHG) (entry_date 2024-10-15)
       (detail
        "median close 36.48 over 5718 bars (2003-04-08..2025-12-29); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0"))
      ((symbol IOVA) (entry_date 2020-03-24)
       (detail
        "median close 7.65 over 3824 bars (2010-10-15..2025-12-29); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0"))
      ((symbol NOKBF) (entry_date 2025-10-28)
       (detail
        "median close 5.87 over 4358 bars (2001-07-11..2025-12-29); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0"))
      ((symbol VTNRQ) (entry_date 2022-05-16)
       (detail
        "median close 1.36 over 7522 bars (1992-10-21..2025-01-21); bar 2003-11-11 close 0.00 (-90.00% vs prior close 0.02) on volume 0")))))))
 (audit_join ((matched 267) (total 267))))
