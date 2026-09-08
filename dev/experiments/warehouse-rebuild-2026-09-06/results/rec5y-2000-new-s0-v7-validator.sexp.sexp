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
   ((id V7) (severity Invariant) (passed false) (n_violations 29)
    (n_skipped 0)
    (specimens
     (((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "Virgin_territory but only 214 weekly bars (< 520) before entry"))
      ((symbol VLCY) (entry_date 2002-03-19)
       (detail
        "Virgin_territory but only 222 weekly bars (< 520) before entry"))
      ((symbol UTHR) (entry_date 2002-11-21)
       (detail
        "Virgin_territory but only 180 weekly bars (< 520) before entry"))
      ((symbol TLB) (entry_date 2004-06-07)
       (detail
        "Virgin_territory but only 340 weekly bars (< 520) before entry"))
      ((symbol TBI1) (entry_date 2000-04-28)
       (detail
        "Virgin_territory but only 68 weekly bars (< 520) before entry"))
      ((symbol PLCE) (entry_date 2004-11-10)
       (detail
        "Virgin_territory but only 377 weekly bars (< 520) before entry"))
      ((symbol PHCC) (entry_date 2000-02-29)
       (detail
        "Virgin_territory but only 114 weekly bars (< 520) before entry"))
      ((symbol NHYDY) (entry_date 2002-03-14)
       (detail
        "Virgin_territory but only 221 weekly bars (< 520) before entry"))
      ((symbol NBIX) (entry_date 2001-11-21)
       (detail
        "Virgin_territory but only 289 weekly bars (< 520) before entry"))
      ((symbol MSTR) (entry_date 2004-11-03)
       (detail
        "Virgin_territory but only 337 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 6)
    (n_skipped 65)
    (specimens
     (((symbol TWX1) (entry_date 2000-01-28)
       (detail "prior_top=91.12 within +25% of entry=80.60"))
      ((symbol TLB) (entry_date 2004-06-07)
       (detail "prior_top=42.90 within +25% of entry=38.89"))
      ((symbol FLMIQ) (entry_date 2000-05-25)
       (detail "prior_top=16.44 within +25% of entry=13.78"))
      ((symbol CWLZ) (entry_date 2003-06-13)
       (detail "prior_top=80.00 within +25% of entry=79.48"))
      ((symbol ARTI_old) (entry_date 2004-05-19)
       (detail "prior_top=28.25 within +25% of entry=26.98"))
      ((symbol ABNK_old) (entry_date 2004-05-01)
       (detail "prior_top=22.00 within +25% of entry=20.15")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 65)
    (specimens
     (((symbol APWR) (entry_date 2000-01-24)
       (detail "entry_wk_close=15.33 > prior=9.33 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 4)
    (n_skipped 0)
    (specimens
     (((symbol TRMB) (entry_date 2003-11-24)
       (detail
        "installed_stop=25.8750 vs fill=19.6700 -> dist=0.3155 > gate=0.1500"))
      ((symbol MMM) (entry_date 2003-07-26)
       (detail
        "installed_stop=131.9328 vs fill=69.6800 -> dist=0.8934 > gate=0.1500"))
      ((symbol FULT) (entry_date 2002-03-07)
       (detail
        "installed_stop=23.3952 vs fill=19.5000 -> dist=0.1998 > gate=0.1500"))
      ((symbol BKNG) (entry_date 2003-06-12)
       (detail
        "installed_stop=4.4256 vs fill=28.2100 -> dist=0.8431 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 26)
    (n_skipped 2)
    (specimens
     (((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)"))
      ((symbol TWX1) (entry_date 2000-01-28)
       (detail
        "exit_price=76.5600 outside 2000-02-23 bar [76.5630, 82.0000]"))
      ((symbol TIMB) (entry_date 2003-09-13)
       (detail
        "no bar on entry_date 2003-09-13 (nearest earlier bar: 2003-09-12)"))
      ((symbol TGT) (entry_date 2004-02-21)
       (detail
        "no bar on entry_date 2004-02-21 (nearest earlier bar: 2004-02-20)"))
      ((symbol RYAAY) (entry_date 2003-10-18)
       (detail
        "no bar on entry_date 2003-10-18 (nearest earlier bar: 2003-10-17)"))
      ((symbol RGEN) (entry_date 2000-02-05)
       (detail
        "no bar on entry_date 2000-02-05 (nearest earlier bar: 2000-02-04)"))
      ((symbol ORLY) (entry_date 2004-05-01)
       (detail
        "no bar on entry_date 2004-05-01 (nearest earlier bar: 2004-04-30)"))
      ((symbol NOV) (entry_date 2000-01-22)
       (detail
        "no bar on entry_date 2000-01-22 (nearest earlier bar: 2000-01-21)"))
      ((symbol NEOG) (entry_date 2000-03-25)
       (detail
        "no bar on entry_date 2000-03-25 (nearest earlier bar: 2000-03-24)"))
      ((symbol MMM) (entry_date 2003-07-26)
       (detail
        "no bar on entry_date 2003-07-26 (nearest earlier bar: 2003-07-25)")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))))
 (audit_join ((matched 98) (total 98))))
