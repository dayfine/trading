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
   ((id V6) (severity Invariant) (passed false) (n_violations 1)
    (n_skipped 0)
    (specimens
     (((symbol LANC) (entry_date 2022-10-26)
       (detail "twin positions: LANC/MZTI")))))
   ((id V7) (severity Invariant) (passed false) (n_violations 23)
    (n_skipped 0)
    (specimens
     (((symbol WES) (entry_date 2021-05-14)
       (detail
        "Virgin_territory but only 445 weekly bars (< 520) before entry"))
      ((symbol SSTK) (entry_date 2020-08-04)
       (detail
        "Virgin_territory but only 413 weekly bars (< 520) before entry"))
      ((symbol SFM) (entry_date 2023-03-02)
       (detail
        "Virgin_territory but only 504 weekly bars (< 520) before entry"))
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
      ((symbol PANW) (entry_date 2020-07-13)
       (detail
        "Virgin_territory but only 422 weekly bars (< 520) before entry"))
      ((symbol OMF) (entry_date 2019-08-14)
       (detail
        "Virgin_territory but only 307 weekly bars (< 520) before entry"))
      ((symbol MGNI) (entry_date 2023-07-11)
       (detail
        "Virgin_territory but only 487 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 33)
    (n_skipped 27)
    (specimens
     (((symbol WOLF_old2) (entry_date 2021-11-20)
       (detail "prior_top=139.55 within +25% of entry=130.58"))
      ((symbol VRNS) (entry_date 2021-07-21)
       (detail "prior_top=71.50 within +25% of entry=60.92"))
      ((symbol VICR) (entry_date 2021-07-03)
       (detail "prior_top=107.97 within +25% of entry=107.30"))
      ((symbol RDWR) (entry_date 2020-12-22)
       (detail "prior_top=28.14 within +25% of entry=27.18"))
      ((symbol PSTG) (entry_date 2023-10-20)
       (detail "prior_top=39.10 within +25% of entry=33.26"))
      ((symbol PEN) (entry_date 2019-06-15)
       (detail "prior_top=166.83 within +25% of entry=163.60"))
      ((symbol OSPN) (entry_date 2020-06-19)
       (detail "prior_top=25.75 within +25% of entry=25.59"))
      ((symbol ON) (entry_date 2021-08-27)
       (detail "prior_top=45.28 within +25% of entry=44.99"))
      ((symbol NVCR) (entry_date 2021-05-08)
       (detail "prior_top=207.63 within +25% of entry=195.97"))
      ((symbol NKE) (entry_date 2021-09-24)
       (detail "prior_top=159.03 within +25% of entry=151.04")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 3)
    (n_skipped 27)
    (specimens
     (((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol GGAL) (entry_date 2023-01-12)
       (detail "entry_wk_close=10.58 > prior=6.23 (spike>60%)"))
      ((symbol BPT) (entry_date 2022-01-22)
       (detail "entry_wk_close=5.52 > prior=2.85 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V13) (severity Invariant) (passed false) (n_violations 33)
    (n_skipped 1)
    (specimens
     (((symbol WOLF_old2) (entry_date 2021-11-20)
       (detail
        "no bar on entry_date 2021-11-20 (nearest earlier bar: 2021-11-19)"))
      ((symbol VICR) (entry_date 2021-07-03)
       (detail
        "no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)"))
      ((symbol TDS) (entry_date 2023-08-26)
       (detail
        "no bar on entry_date 2023-08-26 (nearest earlier bar: 2023-08-25)"))
      ((symbol SHEN) (entry_date 2020-03-28)
       (detail
        "no bar on entry_date 2020-03-28 (nearest earlier bar: 2020-03-27)"))
      ((symbol PEN) (entry_date 2019-06-15)
       (detail
        "no bar on entry_date 2019-06-15 (nearest earlier bar: 2019-06-14)"))
      ((symbol OMF) (entry_date 2019-08-14)
       (detail
        "entry_price=35.9600 outside 2019-08-14 bar [37.4800, 38.2100]"))
      ((symbol NVCR) (entry_date 2021-05-08)
       (detail
        "no bar on entry_date 2021-05-08 (nearest earlier bar: 2021-05-07)"))
      ((symbol NGLOY) (entry_date 2020-11-30)
       (detail
        "entry_price=12.7100 outside 2020-11-30 bar [12.7092, 12.7092]"))
      ((symbol MRNA) (entry_date 2020-03-28)
       (detail
        "no bar on entry_date 2020-03-28 (nearest earlier bar: 2020-03-27)"))
      ((symbol LPLA) (entry_date 2019-11-23)
       (detail
        "no bar on entry_date 2019-11-23 (nearest earlier bar: 2019-11-22)")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))))
 (audit_join ((matched 181) (total 181))))
