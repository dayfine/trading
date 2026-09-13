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
   ((id V7) (severity Invariant) (passed false) (n_violations 25)
    (n_skipped 0)
    (specimens
     (((symbol VLTR) (entry_date 2012-01-18)
       (detail
        "Virgin_territory but only 392 weekly bars (< 520) before entry"))
      ((symbol UAA) (entry_date 2010-09-15)
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
      ((symbol MNTA) (entry_date 2010-07-23)
       (detail
        "Virgin_territory but only 319 weekly bars (< 520) before entry"))
      ((symbol MDAS) (entry_date 2010-06-10)
       (detail
        "Virgin_territory but only 132 weekly bars (< 520) before entry"))
      ((symbol LULU) (entry_date 2013-05-14)
       (detail
        "Virgin_territory but only 306 weekly bars (< 520) before entry"))
      ((symbol LPS) (entry_date 2009-09-16)
       (detail
        "Virgin_territory but only 65 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 21)
    (n_skipped 70)
    (specimens
     (((symbol VRX1) (entry_date 2009-06-24)
       (detail "prior_top=26.54 within +25% of entry=24.78"))
      ((symbol TWTC) (entry_date 2012-03-19)
       (detail "prior_top=23.75 within +25% of entry=23.00"))
      ((symbol OCR) (entry_date 2011-12-02)
       (detail "prior_top=41.38 within +25% of entry=33.20"))
      ((symbol MYRG) (entry_date 2013-10-17)
       (detail "prior_top=26.23 within +25% of entry=25.90"))
      ((symbol MRH) (entry_date 2010-02-18)
       (detail "prior_top=22.18 within +25% of entry=18.03"))
      ((symbol LPS) (entry_date 2009-09-16)
       (detail "prior_top=39.95 within +25% of entry=38.19"))
      ((symbol LIVN) (entry_date 2010-10-25)
       (detail "prior_top=34.29 within +25% of entry=29.10"))
      ((symbol KMX) (entry_date 2010-09-25)
       (detail "prior_top=28.77 within +25% of entry=27.04"))
      ((symbol ISCA) (entry_date 2013-03-27)
       (detail "prior_top=40.38 within +25% of entry=32.50"))
      ((symbol HEW) (entry_date 2009-11-17)
       (detail "prior_top=41.94 within +25% of entry=41.48")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 70)
    (specimens
     (((symbol ICGN) (entry_date 2009-09-01)
       (detail "entry_wk_close=9.52 > prior=4.80 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 2)
    (n_skipped 0)
    (specimens
     (((symbol ICGN) (entry_date 2009-09-01)
       (detail
        "installed_stop=10.3750 vs fill=12.2100 -> dist=0.1503 > gate=0.1500"))
      ((symbol EL) (entry_date 2011-11-21)
       (detail
        "installed_stop=96.1963 vs fill=55.3500 -> dist=0.7380 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 17)
    (n_skipped 1)
    (specimens
     (((symbol WWW) (entry_date 2010-03-06)
       (detail
        "no bar on entry_date 2010-03-06 (nearest earlier bar: 2010-03-05)"))
      ((symbol UFPI) (entry_date 2013-06-22)
       (detail
        "no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)"))
      ((symbol KMX) (entry_date 2010-09-25)
       (detail
        "no bar on entry_date 2010-09-25 (nearest earlier bar: 2010-09-24)"))
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
      ((symbol EXLS) (entry_date 2012-03-10)
       (detail
        "no bar on entry_date 2012-03-10 (nearest earlier bar: 2012-03-09)"))
      ((symbol DST) (entry_date 2012-09-29)
       (detail
        "no bar on entry_date 2012-09-29 (nearest earlier bar: 2012-09-28)"))
      ((symbol CMN) (entry_date 2009-10-10)
       (detail
        "no bar on entry_date 2009-10-10 (nearest earlier bar: 2009-10-09)")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))))
 (audit_join ((matched 149) (total 149))))
