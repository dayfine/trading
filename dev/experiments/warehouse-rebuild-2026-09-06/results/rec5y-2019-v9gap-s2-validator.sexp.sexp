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
   ((id V6) (severity Invariant) (passed false) (n_violations 2)
    (n_skipped 0)
    (specimens
     (((symbol CMBT) (entry_date 2019-10-07)
       (detail "twin positions: CMBT/EURN"))
      ((symbol ELME) (entry_date 2020-02-13)
       (detail "twin positions: ELME/WRE")))))
   ((id V7) (severity Invariant) (passed false) (n_violations 25)
    (n_skipped 0)
    (specimens
     (((symbol ZS) (entry_date 2020-05-29)
       (detail
        "Virgin_territory but only 117 weekly bars (< 520) before entry"))
      ((symbol TWST) (entry_date 2020-05-06)
       (detail
        "Virgin_territory but only 81 weekly bars (< 520) before entry"))
      ((symbol SHAK) (entry_date 2019-06-28)
       (detail
        "Virgin_territory but only 231 weekly bars (< 520) before entry"))
      ((symbol SC) (entry_date 2021-03-12)
       (detail
        "Virgin_territory but only 375 weekly bars (< 520) before entry"))
      ((symbol ROKU) (entry_date 2021-07-27)
       (detail
        "Virgin_territory but only 202 weekly bars (< 520) before entry"))
      ((symbol PI) (entry_date 2022-08-04)
       (detail
        "Virgin_territory but only 317 weekly bars (< 520) before entry"))
      ((symbol PCRX) (entry_date 2020-07-02)
       (detail
        "Virgin_territory but only 496 weekly bars (< 520) before entry"))
      ((symbol PAYC) (entry_date 2021-08-09)
       (detail
        "Virgin_territory but only 385 weekly bars (< 520) before entry"))
      ((symbol LGIH) (entry_date 2020-02-06)
       (detail
        "Virgin_territory but only 330 weekly bars (< 520) before entry"))
      ((symbol KNSL) (entry_date 2022-08-05)
       (detail
        "Virgin_territory but only 316 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 40)
    (n_skipped 23)
    (specimens
     (((symbol VRNS) (entry_date 2021-07-21)
       (detail "prior_top=71.50 within +25% of entry=60.99"))
      ((symbol TNET) (entry_date 2021-12-20)
       (detail "prior_top=104.23 within +25% of entry=89.80"))
      ((symbol PEN) (entry_date 2019-06-15)
       (detail "prior_top=166.83 within +25% of entry=163.60"))
      ((symbol OSPN) (entry_date 2020-06-19)
       (detail "prior_top=25.75 within +25% of entry=25.59"))
      ((symbol ON) (entry_date 2021-08-27)
       (detail "prior_top=45.28 within +25% of entry=44.86"))
      ((symbol NVCR) (entry_date 2021-05-08)
       (detail "prior_top=207.63 within +25% of entry=195.74"))
      ((symbol NKE) (entry_date 2021-09-24)
       (detail "prior_top=159.03 within +25% of entry=151.04"))
      ((symbol MZTI) (entry_date 2022-10-26)
       (detail "prior_top=179.92 within +25% of entry=178.32"))
      ((symbol MRNA) (entry_date 2020-03-28)
       (detail "prior_top=30.05 within +25% of entry=30.01"))
      ((symbol MAT) (entry_date 2022-02-10)
       (detail "prior_top=25.00 within +25% of entry=23.48")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 3)
    (n_skipped 23)
    (specimens
     (((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol GGAL) (entry_date 2023-01-12)
       (detail "entry_wk_close=10.58 > prior=6.23 (spike>60%)"))
      ((symbol BPT) (entry_date 2022-01-22)
       (detail "entry_wk_close=5.52 > prior=2.85 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 2)
    (n_skipped 0)
    (specimens
     (((symbol QLYS) (entry_date 2021-01-20)
       (detail
        "installed_stop=106.9728 vs fill=125.9600 -> dist=0.1507 > gate=0.1500"))
      ((symbol MCK) (entry_date 2020-05-28)
       (detail
        "installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 36)
    (n_skipped 1)
    (specimens
     (((symbol UPS) (entry_date 2021-04-17)
       (detail
        "no bar on entry_date 2021-04-17 (nearest earlier bar: 2021-04-16)"))
      ((symbol TDS) (entry_date 2023-08-26)
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
      ((symbol OR) (entry_date 2021-05-15)
       (detail
        "no bar on entry_date 2021-05-15 (nearest earlier bar: 2021-05-14)"))
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
        "no bar on entry_date 2020-03-28 (nearest earlier bar: 2020-03-27)")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))))
 (audit_join ((matched 179) (total 179))))
