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
   ((id V7) (severity Invariant) (passed false) (n_violations 71)
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
      ((symbol UHAL) (entry_date 2003-09-12)
       (detail
        "Virgin_territory but only 466 weekly bars (< 520) before entry"))
      ((symbol TFSM) (entry_date 2003-06-02)
       (detail
        "Virgin_territory but only 232 weekly bars (< 520) before entry"))
      ((symbol TBI1) (entry_date 2000-04-28)
       (detail
        "Virgin_territory but only 68 weekly bars (< 520) before entry"))
      ((symbol STLD) (entry_date 2003-12-01)
       (detail
        "Virgin_territory but only 371 weekly bars (< 520) before entry"))
      ((symbol SRZ) (entry_date 2004-11-23)
       (detail
        "Virgin_territory but only 364 weekly bars (< 520) before entry"))
      ((symbol SRCL) (entry_date 2005-06-13)
       (detail
        "Virgin_territory but only 465 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 109)
    (n_skipped 246)
    (specimens
     (((symbol ZQKSQ) (entry_date 2004-05-12)
       (detail "prior_top=11.62 within +25% of entry=10.02"))
      ((symbol VSH) (entry_date 2023-09-07)
       (detail "prior_top=27.66 within +25% of entry=25.09"))
      ((symbol VSAT) (entry_date 2017-12-29)
       (detail "prior_top=81.15 within +25% of entry=75.32"))
      ((symbol VSAT) (entry_date 2019-03-15)
       (detail "prior_top=81.15 within +25% of entry=76.80"))
      ((symbol VRX1) (entry_date 2009-06-24)
       (detail "prior_top=26.54 within +25% of entry=24.83"))
      ((symbol VRTX) (entry_date 2014-06-28)
       (detail "prior_top=93.77 within +25% of entry=92.22"))
      ((symbol VRTX) (entry_date 2019-11-09)
       (detail "prior_top=201.31 within +25% of entry=197.08"))
      ((symbol VRTX) (entry_date 2024-04-10)
       (detail "prior_top=435.02 within +25% of entry=397.15"))
      ((symbol VICR) (entry_date 2006-02-22)
       (detail "prior_top=20.29 within +25% of entry=19.34"))
      ((symbol VICR) (entry_date 2021-07-03)
       (detail "prior_top=107.97 within +25% of entry=107.30")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 8)
    (n_skipped 246)
    (specimens
     (((symbol RDN) (entry_date 2009-08-06)
       (detail "entry_wk_close=5.51 > prior=1.50 (spike>60%)"))
      ((symbol MVL) (entry_date 2002-03-08)
       (detail "entry_wk_close=5.33 > prior=3.00 (spike>60%)"))
      ((symbol LIVN) (entry_date 2005-02-04)
       (detail "entry_wk_close=39.78 > prior=20.88 (spike>60%)"))
      ((symbol FNMA) (entry_date 2013-05-24)
       (detail "entry_wk_close=2.97 > prior=0.83 (spike>60%)"))
      ((symbol CBMC) (entry_date 2000-03-06)
       (detail "entry_wk_close=191.25 > prior=71.25 (spike>60%)"))
      ((symbol BPT) (entry_date 2022-01-22)
       (detail "entry_wk_close=5.52 > prior=2.85 (spike>60%)"))
      ((symbol BFX) (entry_date 2020-04-22)
       (detail "entry_wk_close=6.49 > prior=2.80 (spike>60%)"))
      ((symbol APWR) (entry_date 2000-01-24)
       (detail "entry_wk_close=15.33 > prior=9.33 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 21)
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
        "installed_stop=30.2203 vs fill=17.3100 -> dist=0.7458 > gate=0.1500"))
      ((symbol SRZ) (entry_date 2004-11-23)
       (detail
        "installed_stop=38.1318 vs fill=21.6800 -> dist=0.7588 > gate=0.1500"))
      ((symbol SGP_old1) (entry_date 2010-05-10)
       (detail
        "installed_stop=8.8750 vs fill=10.5500 -> dist=0.1588 > gate=0.1500"))
      ((symbol PDLI) (entry_date 2003-05-19)
       (detail
        "installed_stop=12.3750 vs fill=14.6000 -> dist=0.1524 > gate=0.1500"))
      ((symbol OSPN) (entry_date 2022-09-15)
       (detail
        "installed_stop=7.8750 vs fill=9.2800 -> dist=0.1514 > gate=0.1500"))
      ((symbol NPKI) (entry_date 2005-06-24)
       (detail
        "installed_stop=5.8750 vs fill=6.9700 -> dist=0.1571 > gate=0.1500"))
      ((symbol MCK) (entry_date 2020-05-28)
       (detail
        "installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500"))
      ((symbol LSCC) (entry_date 2014-02-13)
       (detail
        "installed_stop=6.3750 vs fill=7.5700 -> dist=0.1579 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 171)
    (n_skipped 7)
    (specimens
     (((symbol WSM) (entry_date 2012-09-01)
       (detail
        "no bar on entry_date 2012-09-01 (nearest earlier bar: 2012-08-31)"))
      ((symbol WNC) (entry_date 2016-12-17)
       (detail
        "no bar on entry_date 2016-12-17 (nearest earlier bar: 2016-12-16)"))
      ((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)"))
      ((symbol WFM) (entry_date 2013-05-18)
       (detail
        "no bar on entry_date 2013-05-18 (nearest earlier bar: 2013-05-17)"))
      ((symbol WDC) (entry_date 2012-08-18)
       (detail
        "no bar on entry_date 2012-08-18 (nearest earlier bar: 2012-08-17)"))
      ((symbol WBS) (entry_date 2011-01-22)
       (detail
        "no bar on entry_date 2011-01-22 (nearest earlier bar: 2011-01-21)"))
      ((symbol VYX) (entry_date 2015-06-16)
       (detail
        "entry_price=36.5000 outside 2015-06-16 bar [31.2699, 36.4999]"))
      ((symbol VRTX) (entry_date 2014-06-28)
       (detail
        "no bar on entry_date 2014-06-28 (nearest earlier bar: 2014-06-27)"))
      ((symbol VRTX) (entry_date 2019-11-09)
       (detail
        "no bar on entry_date 2019-11-09 (nearest earlier bar: 2019-11-08)"))
      ((symbol VICR) (entry_date 2021-07-03)
       (detail
        "no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 5)
    (n_skipped 0)
    (specimens
     (((symbol BRK-A) (entry_date 2006-05-18)
       (detail
        "median close 83087.55 over 11234 bars (1980-03-17..2026-06-22), above the 10000.00 ceiling"))
      ((symbol EHC) (entry_date 2010-01-13)
       (detail
        "median close 23.25 over 10011 bars (1986-09-24..2026-06-22); bar 2006-10-26 close 23.75 (+400.00% vs prior close 4.75) on volume 0"))
      ((symbol FLO) (entry_date 2020-03-09)
       (detail
        "median close 18.18 over 11660 bars (1980-03-17..2026-06-22); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0"))
      ((symbol KBL) (entry_date 2021-07-26)
       (detail
        "median close 199.09 over 3819 bars (1998-01-29..2022-03-02); bar 2012-01-09 close 165.81 (+481.17% vs prior close 28.53) on volume 0"))
      ((symbol MVL) (entry_date 2002-03-08)
       (detail
        "median close 9.00 over 4795 bars (1999-01-04..2018-01-24); bar 2010-01-26 close 60.00 (+96.88% vs prior close 30.48) on volume 0")))))))
 (audit_join ((matched 851) (total 851))))
