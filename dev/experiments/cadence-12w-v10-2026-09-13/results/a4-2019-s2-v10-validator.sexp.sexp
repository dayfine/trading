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
   ((id V7) (severity Invariant) (passed false) (n_violations 25)
    (n_skipped 0)
    (specimens
     (((symbol WES) (entry_date 2021-05-14)
       (detail
        "Virgin_territory but only 445 weekly bars (< 520) before entry"))
      ((symbol ROKU) (entry_date 2021-07-27)
       (detail
        "Virgin_territory but only 202 weekly bars (< 520) before entry"))
      ((symbol PLAN) (entry_date 2020-09-28)
       (detail
        "Virgin_territory but only 105 weekly bars (< 520) before entry"))
      ((symbol PI) (entry_date 2022-08-04)
       (detail
        "Virgin_territory but only 317 weekly bars (< 520) before entry"))
      ((symbol PFSI) (entry_date 2019-07-31)
       (detail
        "Virgin_territory but only 328 weekly bars (< 520) before entry"))
      ((symbol PEN) (entry_date 2020-02-13)
       (detail
        "Virgin_territory but only 232 weekly bars (< 520) before entry"))
      ((symbol PAYC) (entry_date 2021-08-09)
       (detail
        "Virgin_territory but only 385 weekly bars (< 520) before entry"))
      ((symbol OMF) (entry_date 2019-08-14)
       (detail
        "Virgin_territory but only 307 weekly bars (< 520) before entry"))
      ((symbol NEX) (entry_date 2023-07-19)
       (detail
        "Virgin_territory but only 341 weekly bars (< 520) before entry"))
      ((symbol MGNI) (entry_date 2023-07-11)
       (detail
        "Virgin_territory but only 487 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 36)
    (n_skipped 21)
    (specimens
     (((symbol VRNS) (entry_date 2021-07-21)
       (detail "prior_top=71.50 within +25% of entry=60.99"))
      ((symbol TAL) (entry_date 2021-02-17)
       (detail "prior_top=89.10 within +25% of entry=85.77"))
      ((symbol PLAB) (entry_date 2019-10-22)
       (detail "prior_top=12.78 within +25% of entry=11.72"))
      ((symbol OSPN) (entry_date 2020-06-19)
       (detail "prior_top=25.75 within +25% of entry=25.59"))
      ((symbol ON) (entry_date 2021-08-27)
       (detail "prior_top=45.28 within +25% of entry=44.86"))
      ((symbol NVCR) (entry_date 2021-05-08)
       (detail "prior_top=207.63 within +25% of entry=195.74"))
      ((symbol MZTI) (entry_date 2022-10-26)
       (detail "prior_top=179.92 within +25% of entry=178.32"))
      ((symbol MRNA) (entry_date 2020-03-28)
       (detail "prior_top=30.05 within +25% of entry=30.01"))
      ((symbol MAT) (entry_date 2022-02-10)
       (detail "prior_top=25.00 within +25% of entry=23.48"))
      ((symbol LRN) (entry_date 2020-07-06)
       (detail "prior_top=36.46 within +25% of entry=33.39")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 3)
    (n_skipped 21)
    (specimens
     (((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol BPT) (entry_date 2022-01-22)
       (detail "entry_wk_close=5.52 > prior=2.85 (spike>60%)"))
      ((symbol AAOI) (entry_date 2023-07-11)
       (detail "entry_wk_close=9.14 > prior=4.85 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol ISRG) (entry_date 2021-05-04)
       (detail
        "installed_stop=731.2626 vs fill=282.5200 -> dist=1.5884 > gate=0.1500"))
      ((symbol BHRB) (entry_date 2022-09-20)
       (detail
        "installed_stop=2042.8750 vs fill=58.7500 -> dist=33.7723 > gate=0.1500"))
      ((symbol BBAR) (entry_date 2023-02-27)
       (detail
        "installed_stop=4.3750 vs fill=5.1600 -> dist=0.1521 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 35)
    (n_skipped 3)
    (specimens
     (((symbol SPF) (entry_date 2019-09-07)
       (detail
        "no bar on entry_date 2019-09-07 (nearest earlier bar: 2019-09-06)"))
      ((symbol SHEN) (entry_date 2020-03-28)
       (detail
        "no bar on entry_date 2020-03-28 (nearest earlier bar: 2020-03-27)"))
      ((symbol SAFM) (entry_date 2022-05-28)
       (detail
        "no bar on entry_date 2022-05-28 (nearest earlier bar: 2022-05-27)"))
      ((symbol OMF) (entry_date 2019-08-14)
       (detail
        "entry_price=35.9600 outside 2019-08-14 bar [37.4800, 38.2100]"))
      ((symbol NVCR) (entry_date 2021-05-08)
       (detail
        "no bar on entry_date 2021-05-08 (nearest earlier bar: 2021-05-07)"))
      ((symbol NGLOY) (entry_date 2020-11-30)
       (detail
        "entry_price=12.7100 outside 2020-11-30 bar [12.7092, 12.7092]"))
      ((symbol NEX) (entry_date 2023-07-19)
       (detail
        "no bar on exit_date 2023-09-07 (nearest earlier bar: 2023-09-06)"))
      ((symbol MRNA) (entry_date 2020-03-28)
       (detail
        "no bar on entry_date 2020-03-28 (nearest earlier bar: 2020-03-27)"))
      ((symbol LPLA) (entry_date 2019-11-23)
       (detail
        "no bar on entry_date 2019-11-23 (nearest earlier bar: 2019-11-22)"))
      ((symbol HVT) (entry_date 2020-08-29)
       (detail
        "no bar on entry_date 2020-08-29 (nearest earlier bar: 2020-08-28)")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 6)
    (n_skipped 0)
    (specimens
     (((symbol BHRB) (entry_date 2022-09-20)
       (detail
        "median close 2079.95 over 5294 bars (1995-08-04..2023-12-18); bar 2003-10-07 close 2001.00 (-99.80% vs prior close 1000000.00) on volume 0"))
      ((symbol BOKF) (entry_date 2021-10-20)
       (detail
        "median close 47.60 over 8133 bars (1991-09-05..2023-12-18); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0"))
      ((symbol CYRX) (entry_date 2021-11-08)
       (detail
        "median close 2.00 over 4613 bars (2005-08-22..2023-12-18); bar 2010-02-05 close 9.30 (+900.00% vs prior close 0.93) on volume 0"))
      ((symbol FLO) (entry_date 2020-03-09)
       (detail
        "median close 18.02 over 11033 bars (1980-03-17..2023-12-18); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0"))
      ((symbol IOVA) (entry_date 2020-03-24)
       (detail
        "median close 7.70 over 3316 bars (2010-10-15..2023-12-18); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0"))
      ((symbol KBL) (entry_date 2020-10-08)
       (detail
        "median close 199.09 over 3819 bars (1998-01-29..2022-03-02); bar 2012-01-09 close 165.81 (+481.17% vs prior close 28.53) on volume 0")))))))
 (audit_join ((matched 177) (total 177))))
