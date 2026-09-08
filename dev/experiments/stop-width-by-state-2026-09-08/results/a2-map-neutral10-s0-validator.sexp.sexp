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
   ((id V6) (severity Invariant) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol BFX) (entry_date 2020-04-22)
       (detail "twin positions: BFX/NLS"))
      ((symbol LANC) (entry_date 2006-09-15)
       (detail "twin positions: LANC/MZTI"))
      ((symbol HPT) (entry_date 2013-05-20)
       (detail "twin positions: HPT/SVC")))))
   ((id V7) (severity Invariant) (passed false) (n_violations 61)
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
      ((symbol URBN) (entry_date 2003-06-05)
       (detail
        "Virgin_territory but only 503 weekly bars (< 520) before entry"))
      ((symbol TLB) (entry_date 2004-06-07)
       (detail
        "Virgin_territory but only 340 weekly bars (< 520) before entry"))
      ((symbol TFSM) (entry_date 2003-06-02)
       (detail
        "Virgin_territory but only 232 weekly bars (< 520) before entry"))
      ((symbol TBI1) (entry_date 2000-04-28)
       (detail
        "Virgin_territory but only 68 weekly bars (< 520) before entry"))
      ((symbol STLD) (entry_date 2003-12-01)
       (detail
        "Virgin_territory but only 371 weekly bars (< 520) before entry"))
      ((symbol SRCL) (entry_date 2005-06-13)
       (detail
        "Virgin_territory but only 465 weekly bars (< 520) before entry"))
      ((symbol SNDK_old) (entry_date 2003-05-21)
       (detail
        "Virgin_territory but only 284 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 98)
    (n_skipped 257)
    (specimens
     (((symbol ZQKSQ) (entry_date 2004-05-12)
       (detail "prior_top=11.62 within +25% of entry=10.02"))
      ((symbol X) (entry_date 2023-09-19)
       (detail "prior_top=37.63 within +25% of entry=31.75"))
      ((symbol VSH) (entry_date 2023-09-07)
       (detail "prior_top=27.66 within +25% of entry=25.09"))
      ((symbol VRX1) (entry_date 2009-06-24)
       (detail "prior_top=26.54 within +25% of entry=24.83"))
      ((symbol VRTX) (entry_date 2014-07-31)
       (detail "prior_top=99.07 within +25% of entry=89.97"))
      ((symbol VRTX) (entry_date 2019-11-09)
       (detail "prior_top=201.31 within +25% of entry=197.08"))
      ((symbol VICR) (entry_date 2021-07-03)
       (detail "prior_top=107.97 within +25% of entry=107.30"))
      ((symbol USB) (entry_date 2024-08-28)
       (detail "prior_top=51.66 within +25% of entry=46.10"))
      ((symbol URBN) (entry_date 2025-03-13)
       (detail "prior_top=58.19 within +25% of entry=50.12"))
      ((symbol UNT) (entry_date 2003-12-20)
       (detail "prior_top=24.18 within +25% of entry=23.84")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 8)
    (n_skipped 257)
    (specimens
     (((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol RDN) (entry_date 2009-08-06)
       (detail "entry_wk_close=5.51 > prior=1.50 (spike>60%)"))
      ((symbol NLS) (entry_date 2020-04-22)
       (detail "entry_wk_close=6.49 > prior=2.80 (spike>60%)"))
      ((symbol FOSL) (entry_date 2018-05-29)
       (detail "entry_wk_close=23.70 > prior=14.51 (spike>60%)"))
      ((symbol CYBX) (entry_date 2005-02-04)
       (detail "entry_wk_close=39.78 > prior=20.88 (spike>60%)"))
      ((symbol BPT) (entry_date 2022-01-22)
       (detail "entry_wk_close=5.52 > prior=2.85 (spike>60%)"))
      ((symbol BFX) (entry_date 2020-04-22)
       (detail "entry_wk_close=6.49 > prior=2.80 (spike>60%)"))
      ((symbol APWR) (entry_date 2000-01-24)
       (detail "entry_wk_close=15.33 > prior=9.33 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 23)
    (n_skipped 0)
    (specimens
     (((symbol WFM) (entry_date 2013-05-18)
       (detail
        "installed_stop=89.8750 vs fill=51.3400 -> dist=0.7506 > gate=0.1500"))
      ((symbol URBN) (entry_date 2003-06-05)
       (detail
        "installed_stop=32.9308 vs fill=18.7500 -> dist=0.7563 > gate=0.1500"))
      ((symbol TRN) (entry_date 2013-10-31)
       (detail
        "installed_stop=30.9884 vs fill=17.3100 -> dist=0.7902 > gate=0.1500"))
      ((symbol TIN) (entry_date 2005-02-04)
       (detail
        "installed_stop=27.9938 vs fill=16.0900 -> dist=0.7398 > gate=0.1500"))
      ((symbol SID) (entry_date 2021-01-04)
       (detail
        "installed_stop=5.3750 vs fill=6.4500 -> dist=0.1667 > gate=0.1500"))
      ((symbol SGP_old1) (entry_date 2010-05-10)
       (detail
        "installed_stop=8.8750 vs fill=10.5500 -> dist=0.1588 > gate=0.1500"))
      ((symbol PDLI) (entry_date 2003-05-19)
       (detail
        "installed_stop=12.3750 vs fill=14.6000 -> dist=0.1524 > gate=0.1500"))
      ((symbol PDLI) (entry_date 2005-02-28)
       (detail
        "installed_stop=12.8750 vs fill=15.1700 -> dist=0.1513 > gate=0.1500"))
      ((symbol OSPN) (entry_date 2022-09-15)
       (detail
        "installed_stop=7.8750 vs fill=9.2800 -> dist=0.1514 > gate=0.1500"))
      ((symbol NEOG) (entry_date 2017-09-05)
       (detail
        "installed_stop=60.8750 vs fill=52.8000 -> dist=0.1529 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 168)
    (n_skipped 7)
    (specimens
     (((symbol YUM) (entry_date 2022-01-01)
       (detail
        "no bar on entry_date 2022-01-01 (nearest earlier bar: 2021-12-31)"))
      ((symbol WSM) (entry_date 2012-09-01)
       (detail
        "no bar on entry_date 2012-09-01 (nearest earlier bar: 2012-08-31)"))
      ((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)"))
      ((symbol WFM) (entry_date 2013-05-18)
       (detail
        "no bar on entry_date 2013-05-18 (nearest earlier bar: 2013-05-17)"))
      ((symbol WDC) (entry_date 2012-08-18)
       (detail
        "no bar on entry_date 2012-08-18 (nearest earlier bar: 2012-08-17)"))
      ((symbol WAFD) (entry_date 2013-06-29)
       (detail
        "no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)"))
      ((symbol VYX) (entry_date 2015-06-16)
       (detail
        "entry_price=36.5000 outside 2015-06-16 bar [31.2699, 36.4999]"))
      ((symbol VRTX) (entry_date 2019-11-09)
       (detail
        "no bar on entry_date 2019-11-09 (nearest earlier bar: 2019-11-08)"))
      ((symbol VICR) (entry_date 2021-07-03)
       (detail
        "no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)"))
      ((symbol VFC) (entry_date 2006-05-06)
       (detail
        "no bar on entry_date 2006-05-06 (nearest earlier bar: 2006-05-05)")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))))
 (audit_join ((matched 806) (total 806))))
