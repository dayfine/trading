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
   ((id V6) (severity Invariant) (passed false) (n_violations 5)
    (n_skipped 0)
    (specimens
     (((symbol CSC) (entry_date 2014-02-26)
       (detail "twin positions: CSC/DXC"))
      ((symbol AMSWA) (entry_date 2020-04-29)
       (detail "twin positions: AMSWA/LGTY"))
      ((symbol AORT) (entry_date 2016-08-11)
       (detail "twin positions: AORT/CRY_old"))
      ((symbol PNM) (entry_date 2020-02-01)
       (detail "twin positions: PNM/TXNM"))
      ((symbol CECO_old) (entry_date 2019-05-09)
       (detail "twin positions: CECO_old/PRDO")))))
   ((id V7) (severity Invariant) (passed false) (n_violations 54)
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
        "Virgin_territory but only 411 weekly bars (< 520) before entry"))
      ((symbol PLCE) (entry_date 2004-11-10)
       (detail
        "Virgin_territory but only 377 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 90)
    (n_skipped 240)
    (specimens
     (((symbol X) (entry_date 2023-09-19)
       (detail "prior_top=37.63 within +25% of entry=31.85"))
      ((symbol VSAT) (entry_date 2019-03-15)
       (detail "prior_top=81.15 within +25% of entry=76.93"))
      ((symbol VICR) (entry_date 2021-07-03)
       (detail "prior_top=107.97 within +25% of entry=107.30"))
      ((symbol URBN) (entry_date 2026-01-06)
       (detail "prior_top=81.84 within +25% of entry=81.11"))
      ((symbol UHS) (entry_date 2018-08-22)
       (detail "prior_top=138.68 within +25% of entry=128.79"))
      ((symbol UHS) (entry_date 2018-11-19)
       (detail "prior_top=138.68 within +25% of entry=133.31"))
      ((symbol TWX1) (entry_date 2000-01-28)
       (detail "prior_top=91.12 within +25% of entry=80.60"))
      ((symbol TLB) (entry_date 2004-06-07)
       (detail "prior_top=42.90 within +25% of entry=38.84"))
      ((symbol TKR) (entry_date 2023-01-26)
       (detail "prior_top=83.40 within +25% of entry=79.90"))
      ((symbol TGT) (entry_date 2020-03-12)
       (detail "prior_top=107.27 within +25% of entry=92.66")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 7)
    (n_skipped 240)
    (specimens
     (((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol RDN) (entry_date 2009-08-06)
       (detail "entry_wk_close=5.51 > prior=1.50 (spike>60%)"))
      ((symbol FOSL) (entry_date 2018-05-29)
       (detail "entry_wk_close=23.70 > prior=14.51 (spike>60%)"))
      ((symbol CYBX) (entry_date 2005-02-04)
       (detail "entry_wk_close=39.78 > prior=20.88 (spike>60%)"))
      ((symbol CLFD) (entry_date 2026-05-26)
       (detail "entry_wk_close=47.22 > prior=29.43 (spike>60%)"))
      ((symbol BPT) (entry_date 2022-01-22)
       (detail "entry_wk_close=5.52 > prior=2.85 (spike>60%)"))
      ((symbol APWR) (entry_date 2000-01-24)
       (detail "entry_wk_close=15.33 > prior=9.33 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 21)
    (n_skipped 0)
    (specimens
     (((symbol TRN) (entry_date 2013-10-31)
       (detail
        "installed_stop=32.9664 vs fill=17.1800 -> dist=0.9189 > gate=0.1500"))
      ((symbol TRMB) (entry_date 2003-11-24)
       (detail
        "installed_stop=25.8750 vs fill=19.7100 -> dist=0.3128 > gate=0.1500"))
      ((symbol PH) (entry_date 2007-04-04)
       (detail
        "installed_stop=77.1361 vs fill=58.9800 -> dist=0.3078 > gate=0.1500"))
      ((symbol NVDA) (entry_date 2021-05-24)
       (detail
        "installed_stop=567.6864 vs fill=154.7800 -> dist=2.6677 > gate=0.1500"))
      ((symbol NEOG) (entry_date 2017-09-05)
       (detail
        "installed_stop=60.8750 vs fill=52.5300 -> dist=0.1589 > gate=0.1500"))
      ((symbol MNT) (entry_date 2005-04-15)
       (detail
        "installed_stop=31.3920 vs fill=37.4500 -> dist=0.1618 > gate=0.1500"))
      ((symbol MMS) (entry_date 2014-08-07)
       (detail
        "installed_stop=33.2640 vs fill=39.3800 -> dist=0.1553 > gate=0.1500"))
      ((symbol MMM) (entry_date 2003-07-26)
       (detail
        "installed_stop=131.9328 vs fill=69.6800 -> dist=0.8934 > gate=0.1500"))
      ((symbol LRCX) (entry_date 2014-05-03)
       (detail
        "installed_stop=48.3750 vs fill=57.2000 -> dist=0.1543 > gate=0.1500"))
      ((symbol LGTY) (entry_date 2020-04-29)
       (detail
        "installed_stop=14.7984 vs fill=17.5400 -> dist=0.1563 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 154)
    (n_skipped 5)
    (specimens
     (((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)"))
      ((symbol WAFD) (entry_date 2013-06-29)
       (detail
        "no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)"))
      ((symbol VICR) (entry_date 2021-07-03)
       (detail
        "no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)"))
      ((symbol UFPI) (entry_date 2013-06-22)
       (detail
        "no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)"))
      ((symbol TXNM) (entry_date 2020-02-01)
       (detail
        "no bar on entry_date 2020-02-01 (nearest earlier bar: 2020-01-31)"))
      ((symbol TWX1) (entry_date 2000-01-28)
       (detail
        "exit_price=76.5600 outside 2000-02-23 bar [76.5630, 82.0000]"))
      ((symbol TTE) (entry_date 2021-10-16)
       (detail
        "no bar on entry_date 2021-10-16 (nearest earlier bar: 2021-10-15)"))
      ((symbol TRV) (entry_date 2025-05-10)
       (detail
        "no bar on entry_date 2025-05-10 (nearest earlier bar: 2025-05-09)"))
      ((symbol TK) (entry_date 2023-11-04)
       (detail
        "no bar on entry_date 2023-11-04 (nearest earlier bar: 2023-11-03)"))
      ((symbol TIMB) (entry_date 2003-09-13)
       (detail
        "no bar on entry_date 2003-09-13 (nearest earlier bar: 2003-09-12)")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))))
 (audit_join ((matched 755) (total 755))))
