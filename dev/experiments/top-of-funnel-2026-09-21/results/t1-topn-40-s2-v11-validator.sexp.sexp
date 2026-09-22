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
   ((id V7) (severity Invariant) (passed false) (n_violations 107)
    (n_skipped 0)
    (specimens
     (((symbol ZS) (entry_date 2020-05-29)
       (detail
        "Virgin_territory but only 117 weekly bars (< 520) before entry"))
      ((symbol XERS) (entry_date 2024-02-14)
       (detail
        "Virgin_territory but only 297 weekly bars (< 520) before entry"))
      ((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "Virgin_territory but only 214 weekly bars (< 520) before entry"))
      ((symbol WLK) (entry_date 2012-08-06)
       (detail
        "Virgin_territory but only 419 weekly bars (< 520) before entry"))
      ((symbol W) (entry_date 2018-06-05)
       (detail
        "Virgin_territory but only 193 weekly bars (< 520) before entry"))
      ((symbol VLCY) (entry_date 2002-03-19)
       (detail
        "Virgin_territory but only 222 weekly bars (< 520) before entry"))
      ((symbol VAL) (entry_date 2022-10-27)
       (detail
        "Virgin_territory but only 77 weekly bars (< 520) before entry"))
      ((symbol UTHR) (entry_date 2002-11-21)
       (detail
        "Virgin_territory but only 180 weekly bars (< 520) before entry"))
      ((symbol USNA) (entry_date 2005-02-01)
       (detail
        "Virgin_territory but only 502 weekly bars (< 520) before entry"))
      ((symbol UNVR) (entry_date 2022-03-15)
       (detail
        "Virgin_territory but only 354 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 83)
    (n_skipped 242)
    (specimens
     (((symbol WRLD) (entry_date 2010-03-12)
       (detail "prior_top=49.25 within +25% of entry=43.73"))
      ((symbol WLY) (entry_date 2021-02-05)
       (detail "prior_top=52.55 within +25% of entry=50.09"))
      ((symbol UNVR) (entry_date 2022-03-15)
       (detail "prior_top=32.43 within +25% of entry=32.23"))
      ((symbol UHS) (entry_date 2018-08-22)
       (detail "prior_top=138.68 within +25% of entry=128.79"))
      ((symbol TWX1) (entry_date 2000-01-28)
       (detail "prior_top=91.12 within +25% of entry=80.60"))
      ((symbol SCI) (entry_date 2011-08-03)
       (detail "prior_top=10.17 within +25% of entry=9.99"))
      ((symbol ROST) (entry_date 2023-11-14)
       (detail "prior_top=125.52 within +25% of entry=124.00"))
      ((symbol RCRC) (entry_date 2006-12-01)
       (detail "prior_top=44.66 within +25% of entry=41.35"))
      ((symbol QTWO) (entry_date 2018-02-17)
       (detail "prior_top=45.70 within +25% of entry=44.70"))
      ((symbol QRVO) (entry_date 2018-02-27)
       (detail "prior_top=85.25 within +25% of entry=81.66")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 10)
    (n_skipped 242)
    (specimens
     (((symbol VUZI) (entry_date 2026-05-29)
       (detail "entry_wk_close=4.60 > prior=2.84 (spike>60%)"))
      ((symbol VLN) (entry_date 2026-05-16)
       (detail "entry_wk_close=3.22 > prior=1.79 (spike>60%)"))
      ((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol IPSU) (entry_date 2011-06-02)
       (detail "entry_wk_close=21.47 > prior=12.99 (spike>60%)"))
      ((symbol GSIT) (entry_date 2025-10-20)
       (detail "entry_wk_close=9.23 > prior=3.84 (spike>60%)"))
      ((symbol CUTRQ) (entry_date 2022-03-28)
       (detail "entry_wk_close=72.31 > prior=40.49 (spike>60%)"))
      ((symbol CLPA) (entry_date 2000-01-31)
       (detail "entry_wk_close=25.25 > prior=12.12 (spike>60%)"))
      ((symbol CBMC) (entry_date 2000-03-06)
       (detail "entry_wk_close=191.25 > prior=71.25 (spike>60%)"))
      ((symbol BLNK) (entry_date 2020-07-29)
       (detail "entry_wk_close=11.05 > prior=5.28 (spike>60%)"))
      ((symbol ARXX) (entry_date 2000-02-07)
       (detail "entry_wk_close=11.95 > prior=4.95 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 23)
    (n_skipped 0)
    (specimens
     (((symbol XERS) (entry_date 2024-02-14)
       (detail
        "installed_stop=2.6496 vs fill=3.1300 -> dist=0.1535 > gate=0.1500"))
      ((symbol VLN) (entry_date 2026-05-16)
       (detail
        "installed_stop=2.9136 vs fill=3.4300 -> dist=0.1506 > gate=0.1500"))
      ((symbol TRN) (entry_date 2013-10-31)
       (detail
        "installed_stop=32.9664 vs fill=17.1800 -> dist=0.9189 > gate=0.1500"))
      ((symbol SOUN) (entry_date 2024-04-02)
       (detail
        "installed_stop=4.3750 vs fill=5.2400 -> dist=0.1651 > gate=0.1500"))
      ((symbol PATK) (entry_date 2015-02-17)
       (detail
        "installed_stop=61.8750 vs fill=48.3400 -> dist=0.2800 > gate=0.1500"))
      ((symbol NEOG) (entry_date 2017-09-05)
       (detail
        "installed_stop=60.8750 vs fill=52.5300 -> dist=0.1589 > gate=0.1500"))
      ((symbol MNSO) (entry_date 2025-01-06)
       (detail
        "installed_stop=21.8400 vs fill=26.0100 -> dist=0.1603 > gate=0.1500"))
      ((symbol MMS) (entry_date 2014-08-07)
       (detail
        "installed_stop=33.2640 vs fill=39.3800 -> dist=0.1553 > gate=0.1500"))
      ((symbol MGM) (entry_date 2001-09-18)
       (detail
        "installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500"))
      ((symbol MCK) (entry_date 2020-05-28)
       (detail
        "installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 132)
    (n_skipped 5)
    (specimens
     (((symbol ZWS) (entry_date 2018-10-06)
       (detail
        "no bar on entry_date 2018-10-06 (nearest earlier bar: 2018-10-05)"))
      ((symbol WSO) (entry_date 2010-03-06)
       (detail
        "no bar on entry_date 2010-03-06 (nearest earlier bar: 2010-03-05)"))
      ((symbol WPM) (entry_date 2024-04-20)
       (detail
        "no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)"))
      ((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)"))
      ((symbol WLK) (entry_date 2012-08-06)
       (detail
        "entry_price=64.6000 outside 2012-08-06 bar [65.8500, 68.4000]"))
      ((symbol WAFD) (entry_date 2013-06-29)
       (detail
        "no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)"))
      ((symbol VLN) (entry_date 2026-05-16)
       (detail
        "no bar on entry_date 2026-05-16 (nearest earlier bar: 2026-05-15)"))
      ((symbol URBN) (entry_date 2025-12-20)
       (detail
        "no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)"))
      ((symbol UPS) (entry_date 2021-04-17)
       (detail
        "no bar on entry_date 2021-04-17 (nearest earlier bar: 2021-04-16)"))
      ((symbol UN) (entry_date 2017-03-11)
       (detail
        "no bar on entry_date 2017-03-11 (nearest earlier bar: 2017-03-10)")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 13)
    (n_skipped 0)
    (specimens
     (((symbol APLS) (entry_date 2023-04-03)
       (detail
        "median close 32.83 over 2156 bars (2017-11-09..2026-06-10); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0"))
      ((symbol BLNK) (entry_date 2020-07-29)
       (detail
        "median close 1.61 over 4080 bars (2008-07-15..2026-06-10); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0"))
      ((symbol BOKF) (entry_date 2003-06-04)
       (detail
        "median close 49.75 over 8753 bars (1991-09-05..2026-06-10); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0"))
      ((symbol BRK-A) (entry_date 2006-05-18)
       (detail
        "median close 83000.00 over 11227 bars (1980-03-17..2026-06-10), above the 10000.00 ceiling"))
      ((symbol CIR) (entry_date 2013-04-24)
       (detail
        "median close 32.28 over 6046 bars (1999-10-18..2023-11-16); bar 2023-11-06 close 0.00 (-100.00% vs prior close 56.00) on volume 0"))
      ((symbol CSKI) (entry_date 2009-12-19)
       (detail
        "median close 0.20 over 5186 bars (1995-02-01..2015-10-05); bar 2002-12-13 close 0.45 (+542.86% vs prior close 0.07) on volume 0"))
      ((symbol DUOT) (entry_date 2026-06-06)
       (detail
        "median close 2.71 over 3135 bars (2008-08-13..2026-06-10); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0"))
      ((symbol FLO) (entry_date 2020-03-09)
       (detail
        "median close 18.19 over 11653 bars (1980-03-17..2026-06-10); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0"))
      ((symbol IOVA) (entry_date 2020-03-24)
       (detail
        "median close 7.47 over 3936 bars (2010-10-15..2026-06-10); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0"))
      ((symbol ISA) (entry_date 2019-03-14)
       (detail
        "median close 7360.00 over 5664 bars (1997-12-31..2020-07-07); bar 2001-08-22 close 0.05 (-100.00% vs prior close 1070.00) on volume 0")))))))
 (audit_join ((matched 766) (total 766))))
