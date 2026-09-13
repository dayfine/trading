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
   ((id V7) (severity Invariant) (passed false) (n_violations 24)
    (n_skipped 0)
    (specimens
     (((symbol ZS) (entry_date 2020-05-29)
       (detail
        "Virgin_territory but only 117 weekly bars (< 520) before entry"))
      ((symbol VERI) (entry_date 2020-06-02)
       (detail
        "Virgin_territory but only 162 weekly bars (< 520) before entry"))
      ((symbol TWST) (entry_date 2020-05-06)
       (detail
        "Virgin_territory but only 81 weekly bars (< 520) before entry"))
      ((symbol SHAK) (entry_date 2019-06-28)
       (detail
        "Virgin_territory but only 231 weekly bars (< 520) before entry"))
      ((symbol ROKU) (entry_date 2021-07-27)
       (detail
        "Virgin_territory but only 202 weekly bars (< 520) before entry"))
      ((symbol PI) (entry_date 2022-08-04)
       (detail
        "Virgin_territory but only 317 weekly bars (< 520) before entry"))
      ((symbol PETQ) (entry_date 2021-04-26)
       (detail
        "Virgin_territory but only 199 weekly bars (< 520) before entry"))
      ((symbol PAYC) (entry_date 2021-08-09)
       (detail
        "Virgin_territory but only 385 weekly bars (< 520) before entry"))
      ((symbol PANW) (entry_date 2020-07-13)
       (detail
        "Virgin_territory but only 422 weekly bars (< 520) before entry"))
      ((symbol LNTH) (entry_date 2023-04-14)
       (detail
        "Virgin_territory but only 409 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 37)
    (n_skipped 23)
    (specimens
     (((symbol VRNS) (entry_date 2021-07-21)
       (detail "prior_top=71.50 within +25% of entry=60.93"))
      ((symbol PEN) (entry_date 2019-06-15)
       (detail "prior_top=166.83 within +25% of entry=163.60"))
      ((symbol PEN) (entry_date 2023-05-03)
       (detail "prior_top=305.99 within +25% of entry=294.35"))
      ((symbol OSPN) (entry_date 2020-06-19)
       (detail "prior_top=25.75 within +25% of entry=25.61"))
      ((symbol ON) (entry_date 2021-08-27)
       (detail "prior_top=45.28 within +25% of entry=44.85"))
      ((symbol NVCR) (entry_date 2021-05-08)
       (detail "prior_top=207.63 within +25% of entry=195.74"))
      ((symbol NKE) (entry_date 2021-09-24)
       (detail "prior_top=159.03 within +25% of entry=151.04"))
      ((symbol MRNA) (entry_date 2020-03-28)
       (detail "prior_top=30.05 within +25% of entry=30.04"))
      ((symbol MAT) (entry_date 2022-02-10)
       (detail "prior_top=25.00 within +25% of entry=23.48"))
      ((symbol LRN) (entry_date 2020-07-06)
       (detail "prior_top=36.46 within +25% of entry=33.15")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 6)
    (n_skipped 23)
    (specimens
     (((symbol VERI) (entry_date 2020-06-02)
       (detail "entry_wk_close=11.16 > prior=5.93 (spike>60%)"))
      ((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol GGAL) (entry_date 2023-01-12)
       (detail "entry_wk_close=10.58 > prior=6.23 (spike>60%)"))
      ((symbol BPT) (entry_date 2022-01-22)
       (detail "entry_wk_close=5.52 > prior=2.85 (spike>60%)"))
      ((symbol APPS) (entry_date 2020-06-13)
       (detail "entry_wk_close=10.38 > prior=5.82 (spike>60%)"))
      ((symbol AAOI) (entry_date 2023-06-24)
       (detail "entry_wk_close=5.96 > prior=2.27 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V13) (severity Invariant) (passed false) (n_violations 37)
    (n_skipped 1)
    (specimens
     (((symbol TDS) (entry_date 2023-08-26)
       (detail
        "no bar on entry_date 2023-08-26 (nearest earlier bar: 2023-08-25)"))
      ((symbol SPF) (entry_date 2019-09-07)
       (detail
        "no bar on entry_date 2019-09-07 (nearest earlier bar: 2019-09-06)"))
      ((symbol SHEN) (entry_date 2020-03-28)
       (detail
        "no bar on entry_date 2020-03-28 (nearest earlier bar: 2020-03-27)"))
      ((symbol PEN) (entry_date 2019-06-15)
       (detail
        "no bar on entry_date 2019-06-15 (nearest earlier bar: 2019-06-14)"))
      ((symbol NXGN) (entry_date 2023-09-28)
       (detail
        "no bar on exit_date 2023-11-15 (nearest earlier bar: 2023-11-14)"))
      ((symbol NVCR) (entry_date 2021-05-08)
       (detail
        "no bar on entry_date 2021-05-08 (nearest earlier bar: 2021-05-07)"))
      ((symbol NINE) (entry_date 2022-04-02)
       (detail
        "no bar on entry_date 2022-04-02 (nearest earlier bar: 2022-04-01)"))
      ((symbol MRNA) (entry_date 2020-03-28)
       (detail
        "no bar on entry_date 2020-03-28 (nearest earlier bar: 2020-03-27)"))
      ((symbol LPLA) (entry_date 2019-11-23)
       (detail
        "no bar on entry_date 2019-11-23 (nearest earlier bar: 2019-11-22)"))
      ((symbol KBH) (entry_date 2021-02-06)
       (detail
        "no bar on entry_date 2021-02-06 (nearest earlier bar: 2021-02-05)")))))
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
     (((symbol BHRB) (entry_date 2022-09-20)
       (detail
        "median close 2080.00 over 5289 bars (1995-08-04..2023-12-11); bar 2003-10-07 close 2001.00 (-99.80% vs prior close 1000000.00) on volume 0"))
      ((symbol BOKF) (entry_date 2021-10-20)
       (detail
        "median close 47.57 over 8128 bars (1991-09-05..2023-12-11); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0"))
      ((symbol FLO) (entry_date 2020-03-09)
       (detail
        "median close 18.01 over 11028 bars (1980-03-17..2023-12-11); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0"))
      ((symbol IOVA) (entry_date 2020-03-24)
       (detail
        "median close 7.69 over 3311 bars (2010-10-15..2023-12-11); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0"))
      ((symbol NXGN) (entry_date 2023-09-28)
       (detail
        "median close 12.92 over 7854 bars (1990-01-02..2023-11-20); bar 2023-11-20 close 0.00 (-100.00% vs prior close 23.94) on volume 0")))))))
 (audit_join ((matched 179) (total 179))))
