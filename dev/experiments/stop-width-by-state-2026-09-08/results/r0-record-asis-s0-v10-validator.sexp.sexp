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
   ((id V7) (severity Invariant) (passed false) (n_violations 51)
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
      ((symbol UGP) (entry_date 2006-10-20)
       (detail
        "Virgin_territory but only 370 weekly bars (< 520) before entry"))
      ((symbol TLB) (entry_date 2004-06-07)
       (detail
        "Virgin_territory but only 340 weekly bars (< 520) before entry"))
      ((symbol TBI1) (entry_date 2000-04-28)
       (detail
        "Virgin_territory but only 68 weekly bars (< 520) before entry"))
      ((symbol SVM1) (entry_date 2005-10-10)
       (detail
        "Virgin_territory but only 410 weekly bars (< 520) before entry"))
      ((symbol SRCL) (entry_date 2005-06-13)
       (detail
        "Virgin_territory but only 465 weekly bars (< 520) before entry"))
      ((symbol RDA1) (entry_date 2005-02-02)
       (detail
        "Virgin_territory but only 374 weekly bars (< 520) before entry"))
      ((symbol PLFE) (entry_date 2005-10-20)
       (detail
        "Virgin_territory but only 411 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 86)
    (n_skipped 236)
    (specimens
     (((symbol WTRG) (entry_date 2025-10-20)
       (detail "prior_top=46.23 within +25% of entry=42.04"))
      ((symbol VSH) (entry_date 2023-09-07)
       (detail "prior_top=27.66 within +25% of entry=25.09"))
      ((symbol VICR) (entry_date 2021-07-03)
       (detail "prior_top=107.97 within +25% of entry=107.30"))
      ((symbol UHS) (entry_date 2018-11-19)
       (detail "prior_top=138.68 within +25% of entry=133.32"))
      ((symbol TWX1) (entry_date 2000-01-28)
       (detail "prior_top=91.12 within +25% of entry=80.60"))
      ((symbol TTWO) (entry_date 2020-05-19)
       (detail "prior_top=137.99 within +25% of entry=136.42"))
      ((symbol TLB) (entry_date 2004-06-07)
       (detail "prior_top=42.90 within +25% of entry=38.89"))
      ((symbol TKR) (entry_date 2023-01-26)
       (detail "prior_top=83.40 within +25% of entry=79.80"))
      ((symbol THO) (entry_date 2021-02-13)
       (detail "prior_top=130.65 within +25% of entry=123.01"))
      ((symbol TGT) (entry_date 2020-03-12)
       (detail "prior_top=107.27 within +25% of entry=92.66")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 9)
    (n_skipped 236)
    (specimens
     (((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol SSP) (entry_date 2025-11-18)
       (detail "entry_wk_close=3.10 > prior=1.77 (spike>60%)"))
      ((symbol RDN) (entry_date 2009-08-06)
       (detail "entry_wk_close=5.51 > prior=1.50 (spike>60%)"))
      ((symbol RBAK) (entry_date 2006-12-23)
       (detail "entry_wk_close=24.94 > prior=14.52 (spike>60%)"))
      ((symbol GERN) (entry_date 2012-09-01)
       (detail "entry_wk_close=2.74 > prior=1.61 (spike>60%)"))
      ((symbol DDD) (entry_date 2021-01-19)
       (detail "entry_wk_close=34.48 > prior=11.55 (spike>60%)"))
      ((symbol BLDP) (entry_date 2026-05-16)
       (detail "entry_wk_close=5.54 > prior=3.28 (spike>60%)"))
      ((symbol BFX) (entry_date 2020-04-22)
       (detail "entry_wk_close=6.49 > prior=2.80 (spike>60%)"))
      ((symbol APWR) (entry_date 2000-01-24)
       (detail "entry_wk_close=15.33 > prior=9.33 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 23)
    (n_skipped 0)
    (specimens
     (((symbol TRN) (entry_date 2013-10-31)
       (detail
        "installed_stop=32.9664 vs fill=17.3100 -> dist=0.9045 > gate=0.1500"))
      ((symbol TRMB) (entry_date 2003-11-24)
       (detail
        "installed_stop=25.8750 vs fill=19.6700 -> dist=0.3155 > gate=0.1500"))
      ((symbol TIN) (entry_date 2005-02-04)
       (detail
        "installed_stop=30.3750 vs fill=16.0900 -> dist=0.8878 > gate=0.1500"))
      ((symbol NEOG) (entry_date 2017-09-05)
       (detail
        "installed_stop=60.8750 vs fill=52.8000 -> dist=0.1529 > gate=0.1500"))
      ((symbol MMM) (entry_date 2003-07-26)
       (detail
        "installed_stop=131.9328 vs fill=69.6800 -> dist=0.8934 > gate=0.1500"))
      ((symbol MCK) (entry_date 2020-05-28)
       (detail
        "installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500"))
      ((symbol LRCX) (entry_date 2014-05-03)
       (detail
        "installed_stop=48.3750 vs fill=57.2000 -> dist=0.1543 > gate=0.1500"))
      ((symbol LINK) (entry_date 2025-09-23)
       (detail
        "installed_stop=9.3697 vs fill=11.0900 -> dist=0.1551 > gate=0.1500"))
      ((symbol L) (entry_date 2025-05-08)
       (detail
        "installed_stop=75.8208 vs fill=89.3900 -> dist=0.1518 > gate=0.1500"))
      ((symbol KOPN) (entry_date 2025-07-17)
       (detail
        "installed_stop=1.8750 vs fill=2.2200 -> dist=0.1554 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 155)
    (n_skipped 9)
    (specimens
     (((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)"))
      ((symbol WERN) (entry_date 2009-12-12)
       (detail
        "no bar on entry_date 2009-12-12 (nearest earlier bar: 2009-12-11)"))
      ((symbol WDC) (entry_date 2012-08-18)
       (detail
        "no bar on entry_date 2012-08-18 (nearest earlier bar: 2012-08-17)"))
      ((symbol WAVX) (entry_date 2014-05-31)
       (detail
        "no bar on entry_date 2014-05-31 (nearest earlier bar: 2014-05-30)"))
      ((symbol WAFD) (entry_date 2013-06-29)
       (detail
        "no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)"))
      ((symbol VYX) (entry_date 2015-06-16)
       (detail
        "entry_price=36.5000 outside 2015-06-16 bar [31.2699, 36.4999]"))
      ((symbol VICR) (entry_date 2021-07-03)
       (detail
        "no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)"))
      ((symbol UN) (entry_date 2017-03-11)
       (detail
        "no bar on entry_date 2017-03-11 (nearest earlier bar: 2017-03-10)"))
      ((symbol UFPI) (entry_date 2013-06-22)
       (detail
        "no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)"))
      ((symbol TWX1) (entry_date 2000-01-28)
       (detail
        "exit_price=76.5600 outside 2000-02-23 bar [76.5630, 82.0000]")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))))
 (audit_join ((matched 710) (total 710))))
