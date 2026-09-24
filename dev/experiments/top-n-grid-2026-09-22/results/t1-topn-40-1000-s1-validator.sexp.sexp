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
   ((id V7) (severity Invariant) (passed false) (n_violations 88)
    (n_skipped 0)
    (specimens
     (((symbol ZTO) (entry_date 2023-05-18)
       (detail
        "Virgin_territory but only 344 weekly bars (< 520) before entry"))
      ((symbol WWAV) (entry_date 2016-10-07)
       (detail
        "Virgin_territory but only 209 weekly bars (< 520) before entry"))
      ((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "Virgin_territory but only 214 weekly bars (< 520) before entry"))
      ((symbol WLK) (entry_date 2012-08-06)
       (detail
        "Virgin_territory but only 419 weekly bars (< 520) before entry"))
      ((symbol WAVX) (entry_date 2000-02-22)
       (detail
        "Virgin_territory but only 59 weekly bars (< 520) before entry"))
      ((symbol VC) (entry_date 2015-05-22)
       (detail
        "Virgin_territory but only 245 weekly bars (< 520) before entry"))
      ((symbol UCM) (entry_date 2000-05-22)
       (detail
        "Virgin_territory but only 126 weekly bars (< 520) before entry"))
      ((symbol UAA) (entry_date 2010-09-15)
       (detail
        "Virgin_territory but only 254 weekly bars (< 520) before entry"))
      ((symbol TTWO) (entry_date 2003-11-18)
       (detail
        "Virgin_territory but only 345 weekly bars (< 520) before entry"))
      ((symbol TSLA) (entry_date 2014-02-10)
       (detail
        "Virgin_territory but only 191 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 69)
    (n_skipped 288)
    (specimens
     (((symbol ZTO) (entry_date 2023-05-18)
       (detail "prior_top=33.97 within +25% of entry=30.04"))
      ((symbol YETI) (entry_date 2021-07-03)
       (detail "prior_top=94.97 within +25% of entry=92.81"))
      ((symbol X) (entry_date 2023-08-21)
       (detail "prior_top=37.63 within +25% of entry=31.72"))
      ((symbol WWAV) (entry_date 2016-10-07)
       (detail "prior_top=56.64 within +25% of entry=53.85"))
      ((symbol WIX) (entry_date 2021-04-28)
       (detail "prior_top=353.09 within +25% of entry=320.94"))
      ((symbol WAB) (entry_date 2018-05-14)
       (detail "prior_top=95.29 within +25% of entry=95.14"))
      ((symbol VRTX) (entry_date 2014-06-28)
       (detail "prior_top=93.77 within +25% of entry=92.22"))
      ((symbol VLO) (entry_date 2022-02-01)
       (detail "prior_top=90.06 within +25% of entry=85.44"))
      ((symbol URBN) (entry_date 2025-03-13)
       (detail "prior_top=58.19 within +25% of entry=50.12"))
      ((symbol ULTA) (entry_date 2022-11-18)
       (detail "prior_top=442.90 within +25% of entry=441.66")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 6)
    (n_skipped 288)
    (specimens
     (((symbol RMBS) (entry_date 2000-06-22)
       (detail "entry_wk_close=114.69 > prior=40.75 (spike>60%)"))
      ((symbol OCHTQ) (entry_date 2000-02-17)
       (detail "entry_wk_close=6300.00 > prior=3075.00 (spike>60%)"))
      ((symbol JKS) (entry_date 2020-09-29)
       (detail "entry_wk_close=33.65 > prior=15.33 (spike>60%)"))
      ((symbol CBMC) (entry_date 2000-03-06)
       (detail "entry_wk_close=191.25 > prior=71.25 (spike>60%)"))
      ((symbol ATISZ) (entry_date 2000-02-09)
       (detail "entry_wk_close=7.13 > prior=3.56 (spike>60%)"))
      ((symbol ABRX) (entry_date 2000-03-09)
       (detail "entry_wk_close=15.00 > prior=8.44 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 29)
    (n_skipped 0)
    (specimens
     (((symbol WFM) (entry_date 2013-05-18)
       (detail
        "installed_stop=98.2752 vs fill=51.3400 -> dist=0.9142 > gate=0.1500"))
      ((symbol QLYS) (entry_date 2021-01-20)
       (detail
        "installed_stop=106.9728 vs fill=125.8900 -> dist=0.1503 > gate=0.1500"))
      ((symbol PNR) (entry_date 2003-12-01)
       (detail
        "installed_stop=42.1632 vs fill=21.9700 -> dist=0.9191 > gate=0.1500"))
      ((symbol PENN) (entry_date 2001-06-02)
       (detail
        "installed_stop=15.7028 vs fill=18.8300 -> dist=0.1661 > gate=0.1500"))
      ((symbol ODFL) (entry_date 2005-11-11)
       (detail
        "installed_stop=37.1520 vs fill=25.9000 -> dist=0.4344 > gate=0.1500"))
      ((symbol ODFL) (entry_date 2005-11-11)
       (detail
        "installed_stop=37.1520 vs fill=25.9000 -> dist=0.4344 > gate=0.1500"))
      ((symbol NKE) (entry_date 2006-10-25)
       (detail
        "installed_stop=88.3200 vs fill=46.0100 -> dist=0.9196 > gate=0.1500"))
      ((symbol NKE) (entry_date 2015-07-30)
       (detail
        "installed_stop=110.7648 vs fill=57.7000 -> dist=0.9197 > gate=0.1500"))
      ((symbol MMM) (entry_date 2003-07-26)
       (detail
        "installed_stop=131.9328 vs fill=69.6800 -> dist=0.8934 > gate=0.1500"))
      ((symbol MGM) (entry_date 2001-09-18)
       (detail
        "installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 173)
    (n_skipped 11)
    (specimens
     (((symbol YUM) (entry_date 2022-01-01)
       (detail
        "no bar on entry_date 2022-01-01 (nearest earlier bar: 2021-12-31)"))
      ((symbol YETI) (entry_date 2021-07-03)
       (detail
        "no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)"))
      ((symbol WPM) (entry_date 2024-04-20)
       (detail
        "no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)"))
      ((symbol WMB) (entry_date 2024-03-23)
       (detail
        "no bar on entry_date 2024-03-23 (nearest earlier bar: 2024-03-22)"))
      ((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)"))
      ((symbol WLK) (entry_date 2012-08-06)
       (detail
        "entry_price=64.5400 outside 2012-08-06 bar [65.8500, 68.4000]"))
      ((symbol WFM) (entry_date 2013-05-18)
       (detail
        "no bar on entry_date 2013-05-18 (nearest earlier bar: 2013-05-17)"))
      ((symbol WDC) (entry_date 2012-08-18)
       (detail
        "no bar on entry_date 2012-08-18 (nearest earlier bar: 2012-08-17)"))
      ((symbol VRTX) (entry_date 2014-06-28)
       (detail
        "no bar on entry_date 2014-06-28 (nearest earlier bar: 2014-06-27)"))
      ((symbol TXT) (entry_date 2014-11-15)
       (detail
        "no bar on entry_date 2014-11-15 (nearest earlier bar: 2014-11-14)")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 9)
    (n_skipped 0)
    (specimens
     (((symbol CBE) (entry_date 2005-02-03)
       (detail
        "median close 74.58 over 11518 bars (1972-06-01..2018-01-30); bar 1997-05-19 close 60.00 (+92.00% vs prior close 31.25) on volume 0"))
      ((symbol CLE) (entry_date 2006-12-11)
       (detail
        "median close 19.00 over 4813 bars (1997-12-31..2018-06-28); bar 2014-06-09 close 0.07 (-94.53% vs prior close 1.28) on volume 0"))
      ((symbol FERG) (entry_date 2025-07-23)
       (detail
        "median close 69.80 over 4406 bars (2001-07-20..2026-06-22); bar 2001-10-22 close 60.37 (-97.71% vs prior close 2641.96) on volume 0"))
      ((symbol ISA) (entry_date 2010-09-18)
       (detail
        "median close 7360.00 over 5664 bars (1997-12-31..2020-07-07); bar 2001-08-22 close 0.05 (-100.00% vs prior close 1070.00) on volume 0"))
      ((symbol NPPXF) (entry_date 2014-02-12)
       (detail
        "median close 41.56 over 4380 bars (2002-12-23..2026-06-22); bar 2009-02-13 close 48.23 (-100.00% vs prior close 1000000.00) on volume 0"))
      ((symbol RAL_old) (entry_date 2018-01-26)
       (detail
        "median close 45000.00 over 4022 bars (1997-12-31..2022-03-02), above the 10000.00 ceiling; bar 2010-04-23 close 49.84 (-99.84% vs prior close 31800.00) on volume 0"))
      ((symbol RGLD) (entry_date 2009-11-06)
       (detail
        "median close 17.49 over 11350 bars (1981-06-09..2026-06-22); bar 1992-06-01 close 0.38 (+200.00% vs prior close 0.12) on volume 0"))
      ((symbol RRC) (entry_date 2006-11-30)
       (detail
        "median close 16.75 over 9588 bars (1984-11-05..2026-06-22); bar 1992-11-23 close 4.22 (+1399.47% vs prior close 0.28) on volume 0"))
      ((symbol UCM) (entry_date 2000-05-22)
       (detail
        "median close 0.10 over 3743 bars (1997-12-31..2019-12-09); bar 2010-01-04 close 0.28 (-97.37% vs prior close 10.65) on volume 0")))))))
 (audit_join ((matched 757) (total 757))))
