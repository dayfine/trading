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
     (((symbol CMD) (entry_date 2009-10-10)
       (detail "twin positions: CMD/CMN")))))
   ((id V7) (severity Invariant) (passed false) (n_violations 22)
    (n_skipped 0)
    (specimens
     (((symbol UAA) (entry_date 2010-09-15)
       (detail
        "Virgin_territory but only 254 weekly bars (< 520) before entry"))
      ((symbol PTP) (entry_date 2009-12-24)
       (detail
        "Virgin_territory but only 377 weekly bars (< 520) before entry"))
      ((symbol NWG) (entry_date 2013-09-18)
       (detail
        "Virgin_territory but only 313 weekly bars (< 520) before entry"))
      ((symbol MYRG) (entry_date 2013-10-17)
       (detail
        "Virgin_territory but only 272 weekly bars (< 520) before entry"))
      ((symbol MRH) (entry_date 2010-02-18)
       (detail
        "Virgin_territory but only 388 weekly bars (< 520) before entry"))
      ((symbol MOH) (entry_date 2011-01-27)
       (detail
        "Virgin_territory but only 398 weekly bars (< 520) before entry"))
      ((symbol MNTA) (entry_date 2010-07-23)
       (detail
        "Virgin_territory but only 319 weekly bars (< 520) before entry"))
      ((symbol MDAS) (entry_date 2010-06-10)
       (detail
        "Virgin_territory but only 132 weekly bars (< 520) before entry"))
      ((symbol LPS) (entry_date 2009-09-16)
       (detail
        "Virgin_territory but only 65 weekly bars (< 520) before entry"))
      ((symbol HLF) (entry_date 2013-07-22)
       (detail
        "Virgin_territory but only 452 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 23)
    (n_skipped 71)
    (specimens
     (((symbol VRX1) (entry_date 2009-06-24)
       (detail "prior_top=26.54 within +25% of entry=24.77"))
      ((symbol TWTC) (entry_date 2012-03-19)
       (detail "prior_top=23.75 within +25% of entry=23.00"))
      ((symbol SCI) (entry_date 2011-08-03)
       (detail "prior_top=10.17 within +25% of entry=9.99"))
      ((symbol OCR) (entry_date 2011-12-02)
       (detail "prior_top=41.38 within +25% of entry=33.20"))
      ((symbol MYRG) (entry_date 2013-10-17)
       (detail "prior_top=26.23 within +25% of entry=25.90"))
      ((symbol MRH) (entry_date 2010-02-18)
       (detail "prior_top=22.18 within +25% of entry=18.04"))
      ((symbol MFN) (entry_date 2011-03-21)
       (detail "prior_top=13.31 within +25% of entry=11.96"))
      ((symbol LPS) (entry_date 2009-09-16)
       (detail "prior_top=39.95 within +25% of entry=38.19"))
      ((symbol ISCA) (entry_date 2013-03-27)
       (detail "prior_top=40.38 within +25% of entry=32.49"))
      ((symbol HEW) (entry_date 2009-11-17)
       (detail "prior_top=41.94 within +25% of entry=41.49")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 71)
    (specimens
     (((symbol ICGN) (entry_date 2009-09-01)
       (detail "entry_wk_close=9.52 > prior=4.80 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 2)
    (n_skipped 0)
    (specimens
     (((symbol SCI) (entry_date 2011-08-03)
       (detail
        "installed_stop=8.3750 vs fill=9.9900 -> dist=0.1617 > gate=0.1500"))
      ((symbol MOH) (entry_date 2011-01-27)
       (detail
        "installed_stop=28.1258 vs fill=21.3300 -> dist=0.3186 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 21)
    (n_skipped 0)
    (specimens
     (((symbol UMPQ) (entry_date 2013-06-15)
       (detail
        "no bar on entry_date 2013-06-15 (nearest earlier bar: 2013-06-14)"))
      ((symbol UFPI) (entry_date 2013-06-22)
       (detail
        "no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)"))
      ((symbol NUAN) (entry_date 2010-12-10)
       (detail
        "exit_price=17.9300 outside 2011-03-07 bar [17.1166, 17.9259]"))
      ((symbol MRX_old) (entry_date 2011-03-12)
       (detail
        "no bar on entry_date 2011-03-12 (nearest earlier bar: 2011-03-11)"))
      ((symbol MOH) (entry_date 2011-01-27)
       (detail
        "entry_price=21.3300 outside 2011-01-27 bar [31.1300, 32.0000]"))
      ((symbol KFN) (entry_date 2011-01-18)
       (detail "entry_price=9.8500 outside 2011-01-18 bar [9.6270, 9.8450]"))
      ((symbol INVA) (entry_date 2013-04-20)
       (detail
        "no bar on entry_date 2013-04-20 (nearest earlier bar: 2013-04-19)"))
      ((symbol HUBG) (entry_date 2010-03-20)
       (detail
        "no bar on entry_date 2010-03-20 (nearest earlier bar: 2010-03-19)"))
      ((symbol GAMI) (entry_date 2013-06-15)
       (detail
        "no bar on entry_date 2013-06-15 (nearest earlier bar: 2013-06-14)"))
      ((symbol FCF) (entry_date 2013-07-13)
       (detail
        "no bar on entry_date 2013-07-13 (nearest earlier bar: 2013-07-12)")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 0)
    (specimens
     (((symbol BHRB) (entry_date 2013-05-15)
       (detail
        "median close 2015.00 over 2785 bars (1995-08-04..2013-12-30); bar 2003-10-07 close 2001.00 (-99.80% vs prior close 1000000.00) on volume 0")))))))
 (audit_join ((matched 154) (total 154))))
