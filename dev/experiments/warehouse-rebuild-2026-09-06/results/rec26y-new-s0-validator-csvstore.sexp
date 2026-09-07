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
   ((id V9) (severity Expectation) (passed false) (n_violations 85)
    (n_skipped 230)
    (specimens
     (((symbol XL_old) (entry_date 2015-01-10)
       (detail "prior_top=35.88 within +25% of entry=35.73"))
      ((symbol X) (entry_date 2023-09-19)
       (detail "prior_top=37.63 within +25% of entry=31.75"))
      ((symbol WTRG) (entry_date 2025-10-20)
       (detail "prior_top=46.23 within +25% of entry=42.04"))
      ((symbol WAB) (entry_date 2023-07-08)
       (detail "prior_top=109.26 within +25% of entry=108.45"))
      ((symbol VSAT) (entry_date 2017-12-29)
       (detail "prior_top=81.15 within +25% of entry=75.32"))
      ((symbol VRTX) (entry_date 2014-06-28)
       (detail "prior_top=93.77 within +25% of entry=92.22"))
      ((symbol VRTX) (entry_date 2019-11-09)
       (detail "prior_top=201.31 within +25% of entry=197.08"))
      ((symbol VICR) (entry_date 2021-07-03)
       (detail "prior_top=107.97 within +25% of entry=107.30"))
      ((symbol URBN) (entry_date 2026-01-06)
       (detail "prior_top=81.84 within +25% of entry=81.27"))
      ((symbol UHS) (entry_date 2018-11-19)
       (detail "prior_top=138.68 within +25% of entry=133.32")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 9)
    (n_skipped 230)
    (specimens
     (((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol RDN) (entry_date 2009-08-06)
       (detail "entry_wk_close=5.51 > prior=1.50 (spike>60%)"))
      ((symbol RBAK) (entry_date 2006-12-23)
       (detail "entry_wk_close=24.94 > prior=14.52 (spike>60%)"))
      ((symbol GERN) (entry_date 2012-09-01)
       (detail "entry_wk_close=2.74 > prior=1.61 (spike>60%)"))
      ((symbol CYBX) (entry_date 2005-02-04)
       (detail "entry_wk_close=39.78 > prior=20.88 (spike>60%)"))
      ((symbol CLFD) (entry_date 2026-05-26)
       (detail "entry_wk_close=47.22 > prior=29.43 (spike>60%)"))
      ((symbol BPT) (entry_date 2022-01-22)
       (detail "entry_wk_close=5.52 > prior=2.85 (spike>60%)"))
      ((symbol BLDP) (entry_date 2026-05-16)
       (detail "entry_wk_close=5.54 > prior=3.28 (spike>60%)"))
      ((symbol APWR) (entry_date 2000-01-24)
       (detail "entry_wk_close=15.33 > prior=9.33 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 16)
    (n_skipped 0)
    (specimens
     (((symbol TRN) (entry_date 2013-10-31)
       (detail
        "installed_stop=32.9664 vs fill=17.3100 -> dist=0.9045 > gate=0.1500"))
      ((symbol TRMB) (entry_date 2003-11-24)
       (detail
        "installed_stop=25.8750 vs fill=19.6700 -> dist=0.3155 > gate=0.1500"))
      ((symbol PH) (entry_date 2007-04-04)
       (detail
        "installed_stop=77.1361 vs fill=58.9800 -> dist=0.3078 > gate=0.1500"))
      ((symbol NEOG) (entry_date 2017-09-05)
       (detail
        "installed_stop=60.8750 vs fill=52.4700 -> dist=0.1602 > gate=0.1500"))
      ((symbol MNT) (entry_date 2005-04-15)
       (detail
        "installed_stop=31.3920 vs fill=37.4500 -> dist=0.1618 > gate=0.1500"))
      ((symbol MMM) (entry_date 2003-07-26)
       (detail
        "installed_stop=131.9328 vs fill=69.6800 -> dist=0.8934 > gate=0.1500"))
      ((symbol MCK) (entry_date 2020-05-28)
       (detail
        "installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500"))
      ((symbol LRCX) (entry_date 2014-05-03)
       (detail
        "installed_stop=48.3750 vs fill=57.2000 -> dist=0.1543 > gate=0.1500"))
      ((symbol KOPN) (entry_date 2025-07-17)
       (detail
        "installed_stop=1.8750 vs fill=2.2200 -> dist=0.1554 > gate=0.1500"))
      ((symbol FULT) (entry_date 2002-03-07)
       (detail
        "installed_stop=23.3952 vs fill=19.5000 -> dist=0.1998 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 161)
    (n_skipped 5)
    (specimens
     (((symbol XL_old) (entry_date 2015-01-10)
       (detail
        "no bar on entry_date 2015-01-10 (nearest earlier bar: 2015-01-09)"))
      ((symbol WNC) (entry_date 2024-03-09)
       (detail
        "no bar on entry_date 2024-03-09 (nearest earlier bar: 2024-03-08)"))
      ((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)"))
      ((symbol WAFD) (entry_date 2013-06-29)
       (detail
        "no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)"))
      ((symbol WAB) (entry_date 2023-07-08)
       (detail
        "no bar on entry_date 2023-07-08 (nearest earlier bar: 2023-07-07)"))
      ((symbol VRTX) (entry_date 2014-06-28)
       (detail
        "no bar on entry_date 2014-06-28 (nearest earlier bar: 2014-06-27)"))
      ((symbol VRTX) (entry_date 2019-11-09)
       (detail
        "no bar on entry_date 2019-11-09 (nearest earlier bar: 2019-11-08)"))
      ((symbol VICR) (entry_date 2021-07-03)
       (detail
        "no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)"))
      ((symbol URBN) (entry_date 2025-12-20)
       (detail
        "no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)"))
      ((symbol UFPI) (entry_date 2013-06-22)
       (detail
        "no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol FII) (entry_date 2020-03-28)
       (detail
        "entry filled 2020-03-28 but last bar is 2020-01-31 (57 days stale)"))
      ((symbol FII) (entry_date 2020-04-04)
       (detail
        "entry filled 2020-04-04 but last bar is 2020-01-31 (64 days stale)"))
      ((symbol CY) (entry_date 2020-04-25)
       (detail
        "entry filled 2020-04-25 but last bar is 2020-04-15 (10 days stale)")))))))
 (audit_join ((matched 715) (total 715))))
