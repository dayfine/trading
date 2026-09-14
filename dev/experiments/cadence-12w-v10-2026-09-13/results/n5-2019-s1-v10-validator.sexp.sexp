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
   ((id V7) (severity Invariant) (passed false) (n_violations 26)
    (n_skipped 0)
    (specimens
     (((symbol ZS) (entry_date 2020-05-29)
       (detail
        "Virgin_territory but only 117 weekly bars (< 520) before entry"))
      ((symbol WES) (entry_date 2021-05-14)
       (detail
        "Virgin_territory but only 445 weekly bars (< 520) before entry"))
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
        "Virgin_territory but only 422 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 39)
    (n_skipped 21)
    (specimens
     (((symbol WOLF_old2) (entry_date 2021-11-20)
       (detail "prior_top=139.55 within +25% of entry=130.58"))
      ((symbol VRNS) (entry_date 2021-07-21)
       (detail "prior_top=71.50 within +25% of entry=60.92"))
      ((symbol PEN) (entry_date 2019-06-15)
       (detail "prior_top=166.83 within +25% of entry=163.60"))
      ((symbol OSPN) (entry_date 2020-06-19)
       (detail "prior_top=25.75 within +25% of entry=25.59"))
      ((symbol ON) (entry_date 2021-08-27)
       (detail "prior_top=45.28 within +25% of entry=44.99"))
      ((symbol NVCR) (entry_date 2021-05-08)
       (detail "prior_top=207.63 within +25% of entry=195.97"))
      ((symbol NKE) (entry_date 2021-09-24)
       (detail "prior_top=159.03 within +25% of entry=151.04"))
      ((symbol MZTI) (entry_date 2022-10-26)
       (detail "prior_top=179.92 within +25% of entry=178.06"))
      ((symbol LRN) (entry_date 2020-07-06)
       (detail "prior_top=36.46 within +25% of entry=33.17"))
      ((symbol KRA) (entry_date 2021-09-29)
       (detail "prior_top=52.72 within +25% of entry=46.16")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 5)
    (n_skipped 21)
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
       (detail "entry_wk_close=10.38 > prior=5.82 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 2)
    (n_skipped 0)
    (specimens
     (((symbol DAR) (entry_date 2022-04-20)
       (detail
        "installed_stop=73.4880 vs fill=86.4800 -> dist=0.1502 > gate=0.1500"))
      ((symbol APPS) (entry_date 2020-06-13)
       (detail
        "installed_stop=7.8816 vs fill=9.3500 -> dist=0.1570 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 38)
    (n_skipped 1)
    (specimens
     (((symbol WOLF_old2) (entry_date 2021-11-20)
       (detail
        "no bar on entry_date 2021-11-20 (nearest earlier bar: 2021-11-19)"))
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
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 6)
    (n_skipped 0)
    (specimens
     (((symbol BHRB) (entry_date 2022-09-20)
       (detail
        "median close 2075.00 over 5297 bars (1995-08-04..2023-12-21); bar 2003-10-07 close 2001.00 (-99.80% vs prior close 1000000.00) on volume 0"))
      ((symbol BOKF) (entry_date 2021-10-20)
       (detail
        "median close 47.61 over 8136 bars (1991-09-05..2023-12-21); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0"))
      ((symbol FLO) (entry_date 2020-03-09)
       (detail
        "median close 18.04 over 11036 bars (1980-03-17..2023-12-21); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0"))
      ((symbol IOVA) (entry_date 2020-03-24)
       (detail
        "median close 7.70 over 3319 bars (2010-10-15..2023-12-21); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0"))
      ((symbol KBL) (entry_date 2020-10-08)
       (detail
        "median close 199.09 over 3819 bars (1998-01-29..2022-03-02); bar 2012-01-09 close 165.81 (+481.17% vs prior close 28.53) on volume 0"))
      ((symbol NXGN) (entry_date 2023-09-28)
       (detail
        "median close 12.92 over 7854 bars (1990-01-02..2023-11-20); bar 2023-11-20 close 0.00 (-100.00% vs prior close 23.94) on volume 0")))))))
 (audit_join ((matched 181) (total 181))))
