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
   ((id V7) (severity Invariant) (passed false) (n_violations 91)
    (n_skipped 0)
    (specimens
     (((symbol ZS) (entry_date 2021-07-12)
       (detail
        "Virgin_territory but only 176 weekly bars (< 520) before entry"))
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
      ((symbol ULTA) (entry_date 2013-08-02)
       (detail
        "Virgin_territory but only 304 weekly bars (< 520) before entry"))
      ((symbol ULTA) (entry_date 2017-03-06)
       (detail
        "Virgin_territory but only 494 weekly bars (< 520) before entry"))
      ((symbol UCM) (entry_date 2000-05-22)
       (detail
        "Virgin_territory but only 126 weekly bars (< 520) before entry"))
      ((symbol UAA) (entry_date 2010-09-15)
       (detail
        "Virgin_territory but only 254 weekly bars (< 520) before entry"))
      ((symbol TTWO) (entry_date 2003-11-18)
       (detail
        "Virgin_territory but only 345 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 73)
    (n_skipped 294)
    (specimens
     (((symbol ZD) (entry_date 2021-06-05)
       (detail "prior_top=111.23 within +25% of entry=111.00"))
      ((symbol YUM) (entry_date 2025-04-07)
       (detail "prior_top=158.67 within +25% of entry=144.64"))
      ((symbol YETI) (entry_date 2021-07-03)
       (detail "prior_top=94.97 within +25% of entry=92.81"))
      ((symbol WWAV) (entry_date 2016-10-07)
       (detail "prior_top=56.64 within +25% of entry=53.85"))
      ((symbol WAB) (entry_date 2018-05-14)
       (detail "prior_top=95.29 within +25% of entry=95.13"))
      ((symbol VRTX) (entry_date 2014-06-28)
       (detail "prior_top=93.77 within +25% of entry=92.22"))
      ((symbol URBN) (entry_date 2025-03-13)
       (detail "prior_top=58.19 within +25% of entry=50.12"))
      ((symbol ULTA) (entry_date 2016-04-02)
       (detail "prior_top=194.18 within +25% of entry=192.62"))
      ((symbol UHS) (entry_date 2018-08-22)
       (detail "prior_top=138.68 within +25% of entry=128.79"))
      ((symbol UAA) (entry_date 2021-11-20)
       (detail "prior_top=30.47 within +25% of entry=26.66")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 7)
    (n_skipped 294)
    (specimens
     (((symbol RMBS) (entry_date 2000-06-22)
       (detail "entry_wk_close=114.69 > prior=40.75 (spike>60%)"))
      ((symbol OCHTQ) (entry_date 2000-02-17)
       (detail "entry_wk_close=6300.00 > prior=3075.00 (spike>60%)"))
      ((symbol MARA) (entry_date 2023-12-19)
       (detail "entry_wk_close=26.71 > prior=11.41 (spike>60%)"))
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
     (((symbol YMM) (entry_date 2024-11-20)
       (detail
        "installed_stop=8.2848 vs fill=9.7600 -> dist=0.1511 > gate=0.1500"))
      ((symbol WFM) (entry_date 2013-05-18)
       (detail
        "installed_stop=98.2752 vs fill=51.3400 -> dist=0.9142 > gate=0.1500"))
      ((symbol PNR) (entry_date 2003-12-01)
       (detail
        "installed_stop=42.1632 vs fill=22.0000 -> dist=0.9165 > gate=0.1500"))
      ((symbol PENN) (entry_date 2001-06-02)
       (detail
        "installed_stop=15.7028 vs fill=18.8300 -> dist=0.1661 > gate=0.1500"))
      ((symbol ODFL) (entry_date 2005-11-11)
       (detail
        "installed_stop=37.1520 vs fill=25.8600 -> dist=0.4367 > gate=0.1500"))
      ((symbol ODFL) (entry_date 2005-11-11)
       (detail
        "installed_stop=37.1520 vs fill=25.8600 -> dist=0.4367 > gate=0.1500"))
      ((symbol O) (entry_date 2019-09-03)
       (detail
        "installed_stop=63.3750 vs fill=74.5600 -> dist=0.1500 > gate=0.1500"))
      ((symbol NKE) (entry_date 2006-10-25)
       (detail
        "installed_stop=88.3200 vs fill=46.0400 -> dist=0.9183 > gate=0.1500"))
      ((symbol NKE) (entry_date 2015-07-30)
       (detail
        "installed_stop=110.7648 vs fill=57.7000 -> dist=0.9197 > gate=0.1500"))
      ((symbol MTN) (entry_date 2020-11-09)
       (detail
        "installed_stop=218.2464 vs fill=261.7800 -> dist=0.1663 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 170)
    (n_skipped 12)
    (specimens
     (((symbol ZD) (entry_date 2021-06-05)
       (detail
        "no bar on entry_date 2021-06-05 (nearest earlier bar: 2021-06-04)"))
      ((symbol YUMC) (entry_date 2019-12-21)
       (detail
        "no bar on entry_date 2019-12-21 (nearest earlier bar: 2019-12-20)"))
      ((symbol YUM) (entry_date 2022-01-01)
       (detail
        "no bar on entry_date 2022-01-01 (nearest earlier bar: 2021-12-31)"))
      ((symbol YETI) (entry_date 2021-07-03)
       (detail
        "no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)"))
      ((symbol WPM) (entry_date 2024-04-20)
       (detail
        "no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)"))
      ((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)"))
      ((symbol WLK) (entry_date 2012-08-06)
       (detail
        "entry_price=64.6000 outside 2012-08-06 bar [65.8500, 68.4000]"))
      ((symbol WFM) (entry_date 2013-05-18)
       (detail
        "no bar on entry_date 2013-05-18 (nearest earlier bar: 2013-05-17)"))
      ((symbol WDC) (entry_date 2012-08-18)
       (detail
        "no bar on entry_date 2012-08-18 (nearest earlier bar: 2012-08-17)"))
      ((symbol VZ) (entry_date 2025-03-08)
       (detail
        "no bar on entry_date 2025-03-08 (nearest earlier bar: 2025-03-07)")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 12)
    (n_skipped 0)
    (specimens
     (((symbol BRK-A) (entry_date 2018-09-19)
       (detail
        "median close 83025.10 over 11230 bars (1980-03-17..2026-06-15), above the 10000.00 ceiling"))
      ((symbol CBE) (entry_date 2005-02-03)
       (detail
        "median close 74.58 over 11518 bars (1972-06-01..2018-01-30); bar 1997-05-19 close 60.00 (+92.00% vs prior close 31.25) on volume 0"))
      ((symbol CLE) (entry_date 2006-12-11)
       (detail
        "median close 19.00 over 4813 bars (1997-12-31..2018-06-28); bar 2014-06-09 close 0.07 (-94.53% vs prior close 1.28) on volume 0"))
      ((symbol IOVA) (entry_date 2020-12-01)
       (detail
        "median close 7.46 over 3939 bars (2010-10-15..2026-06-15); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0"))
      ((symbol ISA) (entry_date 2010-09-18)
       (detail
        "median close 7360.00 over 5664 bars (1997-12-31..2020-07-07); bar 2001-08-22 close 0.05 (-100.00% vs prior close 1070.00) on volume 0"))
      ((symbol LNG) (entry_date 2026-03-14)
       (detail
        "median close 27.70 over 8104 bars (1994-04-04..2026-06-15); bar 1994-07-19 close 6.00 (+500.00% vs prior close 1.00) on volume 0"))
      ((symbol RAL_old) (entry_date 2017-04-24)
       (detail
        "median close 45000.00 over 4022 bars (1997-12-31..2022-03-02), above the 10000.00 ceiling; bar 2010-04-23 close 49.84 (-99.84% vs prior close 31800.00) on volume 0"))
      ((symbol RGLD) (entry_date 2009-11-06)
       (detail
        "median close 17.48 over 11346 bars (1981-06-09..2026-06-15); bar 1992-06-01 close 0.38 (+200.00% vs prior close 0.12) on volume 0"))
      ((symbol RRC) (entry_date 2006-11-30)
       (detail
        "median close 16.75 over 9584 bars (1984-11-05..2026-06-15); bar 1992-11-23 close 4.22 (+1399.47% vs prior close 0.28) on volume 0"))
      ((symbol SFI) (entry_date 2020-12-02)
       (detail
        "median close 24200.00 over 2823 bars (2010-12-14..2022-03-02), above the 10000.00 ceiling")))))))
 (audit_join ((matched 767) (total 767))))
