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
   ((id V7) (severity Invariant) (passed false) (n_violations 33)
    (n_skipped 0)
    (specimens
     (((symbol ZS) (entry_date 2020-05-29)
       (detail
        "Virgin_territory but only 117 weekly bars (< 520) before entry"))
      ((symbol VERI) (entry_date 2020-06-02)
       (detail
        "Virgin_territory but only 162 weekly bars (< 520) before entry"))
      ((symbol VAL) (entry_date 2022-10-27)
       (detail
        "Virgin_territory but only 77 weekly bars (< 520) before entry"))
      ((symbol TWST) (entry_date 2020-05-06)
       (detail
        "Virgin_territory but only 81 weekly bars (< 520) before entry"))
      ((symbol TOST) (entry_date 2023-07-13)
       (detail
        "Virgin_territory but only 94 weekly bars (< 520) before entry"))
      ((symbol SSNC) (entry_date 2019-02-25)
       (detail
        "Virgin_territory but only 469 weekly bars (< 520) before entry"))
      ((symbol SHAK) (entry_date 2019-06-28)
       (detail
        "Virgin_territory but only 231 weekly bars (< 520) before entry"))
      ((symbol QTWO) (entry_date 2020-07-20)
       (detail
        "Virgin_territory but only 334 weekly bars (< 520) before entry"))
      ((symbol PLAN) (entry_date 2020-09-28)
       (detail
        "Virgin_territory but only 105 weekly bars (< 520) before entry"))
      ((symbol PETQ) (entry_date 2021-04-26)
       (detail
        "Virgin_territory but only 199 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 46)
    (n_skipped 42)
    (specimens
     (((symbol ZGN) (entry_date 2023-09-08)
       (detail "prior_top=15.43 within +25% of entry=14.25"))
      ((symbol X) (entry_date 2023-09-19)
       (detail "prior_top=37.63 within +25% of entry=31.85"))
      ((symbol WIX) (entry_date 2021-04-28)
       (detail "prior_top=353.09 within +25% of entry=320.97"))
      ((symbol VRNS) (entry_date 2021-07-21)
       (detail "prior_top=71.50 within +25% of entry=60.99"))
      ((symbol ROST) (entry_date 2023-11-14)
       (detail "prior_top=125.52 within +25% of entry=124.00"))
      ((symbol PTGX) (entry_date 2025-06-02)
       (detail "prior_top=54.78 within +25% of entry=49.17"))
      ((symbol PTC) (entry_date 2025-07-26)
       (detail "prior_top=204.51 within +25% of entry=204.14"))
      ((symbol PSLV) (entry_date 2024-04-22)
       (detail "prior_top=10.04 within +25% of entry=9.21"))
      ((symbol PJT) (entry_date 2023-11-03)
       (detail "prior_top=84.12 within +25% of entry=83.64"))
      ((symbol PEN) (entry_date 2023-05-03)
       (detail "prior_top=305.99 within +25% of entry=294.56")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 5)
    (n_skipped 42)
    (specimens
     (((symbol VERI) (entry_date 2020-06-02)
       (detail "entry_wk_close=11.16 > prior=5.93 (spike>60%)"))
      ((symbol GRPN) (entry_date 2025-03-26)
       (detail "entry_wk_close=18.82 > prior=11.12 (spike>60%)"))
      ((symbol EXK) (entry_date 2020-07-20)
       (detail "entry_wk_close=4.20 > prior=2.14 (spike>60%)"))
      ((symbol CUTRQ) (entry_date 2022-03-28)
       (detail "entry_wk_close=72.31 > prior=40.49 (spike>60%)"))
      ((symbol BLNK) (entry_date 2020-07-29)
       (detail "entry_wk_close=11.05 > prior=5.28 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 1)
    (n_skipped 0)
    (specimens
     (((symbol LPG) (entry_date 2023-09-15)
       (detail
        "installed_stop=23.2022 vs fill=27.3000 -> dist=0.1501 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 58)
    (n_skipped 0)
    (specimens
     (((symbol WPM) (entry_date 2024-04-20)
       (detail
        "no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)"))
      ((symbol VCYT) (entry_date 2024-08-10)
       (detail
        "no bar on entry_date 2024-08-10 (nearest earlier bar: 2024-08-09)"))
      ((symbol URBN) (entry_date 2025-12-20)
       (detail
        "no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)"))
      ((symbol TNET) (entry_date 2019-02-23)
       (detail
        "no bar on entry_date 2019-02-23 (nearest earlier bar: 2019-02-22)"))
      ((symbol TDS) (entry_date 2023-08-26)
       (detail
        "no bar on entry_date 2023-08-26 (nearest earlier bar: 2023-08-25)"))
      ((symbol SMCI) (entry_date 2021-12-18)
       (detail
        "no bar on entry_date 2021-12-18 (nearest earlier bar: 2021-12-17)"))
      ((symbol SIRI) (entry_date 2023-07-22)
       (detail
        "no bar on entry_date 2023-07-22 (nearest earlier bar: 2023-07-21)"))
      ((symbol SHEN) (entry_date 2020-03-21)
       (detail
        "no bar on entry_date 2020-03-21 (nearest earlier bar: 2020-03-20)"))
      ((symbol SAFM) (entry_date 2022-05-28)
       (detail
        "no bar on entry_date 2022-05-28 (nearest earlier bar: 2022-05-27)"))
      ((symbol QIWI) (entry_date 2019-06-08)
       (detail
        "no bar on entry_date 2019-06-08 (nearest earlier bar: 2019-06-07)")))))
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
        "median close 1.67 over 3966 bars (2008-07-15..2025-12-24); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0"))
      ((symbol BOKF) (entry_date 2021-10-20)
       (detail
        "median close 49.33 over 8639 bars (1991-09-05..2025-12-24); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0"))
      ((symbol FIT) (entry_date 2020-11-11)
       (detail
        "median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0"))
      ((symbol FLO) (entry_date 2020-03-09)
       (detail
        "median close 18.37 over 11539 bars (1980-03-17..2025-12-24); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0"))
      ((symbol IOVA) (entry_date 2020-03-24)
       (detail
        "median close 7.65 over 3822 bars (2010-10-15..2025-12-24); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0")))))))
 (audit_join ((matched 256) (total 256))))
