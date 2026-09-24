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
     (((symbol IAC) (entry_date 2012-03-15)
       (detail "twin positions: IAC/MTCH")))))
   ((id V7) (severity Invariant) (passed false) (n_violations 95)
    (n_skipped 0)
    (specimens
     (((symbol ZS) (entry_date 2021-07-12)
       (detail
        "Virgin_territory but only 176 weekly bars (< 520) before entry"))
      ((symbol WWAV) (entry_date 2016-10-07)
       (detail
        "Virgin_territory but only 209 weekly bars (< 520) before entry"))
      ((symbol WLP1) (entry_date 2000-10-02)
       (detail
        "Virgin_territory but only 145 weekly bars (< 520) before entry"))
      ((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "Virgin_territory but only 214 weekly bars (< 520) before entry"))
      ((symbol WLK) (entry_date 2012-08-06)
       (detail
        "Virgin_territory but only 419 weekly bars (< 520) before entry"))
      ((symbol WAVX) (entry_date 2000-02-22)
       (detail
        "Virgin_territory but only 59 weekly bars (< 520) before entry"))
      ((symbol VOYA) (entry_date 2017-11-29)
       (detail
        "Virgin_territory but only 241 weekly bars (< 520) before entry"))
      ((symbol VNA) (entry_date 2015-02-05)
       (detail
        "Virgin_territory but only 258 weekly bars (< 520) before entry"))
      ((symbol VC) (entry_date 2015-05-22)
       (detail
        "Virgin_territory but only 245 weekly bars (< 520) before entry"))
      ((symbol UCM) (entry_date 2000-05-22)
       (detail
        "Virgin_territory but only 126 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 76)
    (n_skipped 271)
    (specimens
     (((symbol ZBH) (entry_date 2012-12-12)
       (detail "prior_top=67.87 within +25% of entry=67.53"))
      ((symbol YUM) (entry_date 2025-04-07)
       (detail "prior_top=158.67 within +25% of entry=144.64"))
      ((symbol WWAV) (entry_date 2016-10-07)
       (detail "prior_top=56.64 within +25% of entry=53.85"))
      ((symbol WIX) (entry_date 2021-04-28)
       (detail "prior_top=353.09 within +25% of entry=320.94"))
      ((symbol WAB) (entry_date 2018-05-14)
       (detail "prior_top=95.29 within +25% of entry=95.14"))
      ((symbol VRTX) (entry_date 2014-06-28)
       (detail "prior_top=93.77 within +25% of entry=92.22"))
      ((symbol VRTX) (entry_date 2019-11-09)
       (detail "prior_top=201.31 within +25% of entry=197.08"))
      ((symbol USB) (entry_date 2024-08-28)
       (detail "prior_top=51.66 within +25% of entry=46.10"))
      ((symbol URBN) (entry_date 2025-03-13)
       (detail "prior_top=58.19 within +25% of entry=50.12"))
      ((symbol ULTA) (entry_date 2016-04-02)
       (detail "prior_top=194.18 within +25% of entry=192.62")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 7)
    (n_skipped 271)
    (specimens
     (((symbol VTNRQ) (entry_date 2022-05-16)
       (detail "entry_wk_close=14.40 > prior=8.84 (spike>60%)"))
      ((symbol RMBS) (entry_date 2000-06-22)
       (detail "entry_wk_close=114.69 > prior=40.75 (spike>60%)"))
      ((symbol RBAK) (entry_date 2006-12-23)
       (detail "entry_wk_close=24.94 > prior=14.52 (spike>60%)"))
      ((symbol OCHTQ) (entry_date 2000-02-17)
       (detail "entry_wk_close=6300.00 > prior=3075.00 (spike>60%)"))
      ((symbol CBMC) (entry_date 2000-03-06)
       (detail "entry_wk_close=191.25 > prior=71.25 (spike>60%)"))
      ((symbol ATISZ) (entry_date 2000-02-09)
       (detail "entry_wk_close=7.13 > prior=3.56 (spike>60%)"))
      ((symbol ABRX) (entry_date 2000-03-09)
       (detail "entry_wk_close=15.00 > prior=8.44 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 25)
    (n_skipped 0)
    (specimens
     (((symbol WFM) (entry_date 2013-05-18)
       (detail
        "installed_stop=98.2752 vs fill=51.3400 -> dist=0.9142 > gate=0.1500"))
      ((symbol VOYA) (entry_date 2017-11-29)
       (detail
        "installed_stop=36.7008 vs fill=43.5100 -> dist=0.1565 > gate=0.1500"))
      ((symbol TRN) (entry_date 2013-10-31)
       (detail
        "installed_stop=32.9664 vs fill=17.1800 -> dist=0.9189 > gate=0.1500"))
      ((symbol TAP) (entry_date 2007-09-19)
       (detail
        "installed_stop=83.6448 vs fill=49.0700 -> dist=0.7046 > gate=0.1500"))
      ((symbol PRKS) (entry_date 2019-07-11)
       (detail
        "installed_stop=27.8750 vs fill=32.8900 -> dist=0.1525 > gate=0.1500"))
      ((symbol PENN) (entry_date 2001-06-02)
       (detail
        "installed_stop=15.7028 vs fill=18.8300 -> dist=0.1661 > gate=0.1500"))
      ((symbol ODFL) (entry_date 2005-11-11)
       (detail
        "installed_stop=37.1520 vs fill=25.9000 -> dist=0.4344 > gate=0.1500"))
      ((symbol ODFL) (entry_date 2005-11-11)
       (detail
        "installed_stop=37.1520 vs fill=25.9000 -> dist=0.4344 > gate=0.1500"))
      ((symbol NRG) (entry_date 2006-11-18)
       (detail
        "installed_stop=50.7552 vs fill=26.9500 -> dist=0.8833 > gate=0.1500"))
      ((symbol NKE) (entry_date 2006-10-25)
       (detail
        "installed_stop=88.3200 vs fill=46.0100 -> dist=0.9196 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 162)
    (n_skipped 11)
    (specimens
     (((symbol YUM) (entry_date 2022-01-01)
       (detail
        "no bar on entry_date 2022-01-01 (nearest earlier bar: 2021-12-31)"))
      ((symbol WPM) (entry_date 2024-04-20)
       (detail
        "no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)"))
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
      ((symbol VRTX) (entry_date 2019-11-09)
       (detail
        "no bar on entry_date 2019-11-09 (nearest earlier bar: 2019-11-08)"))
      ((symbol ULTA) (entry_date 2016-04-02)
       (detail
        "no bar on entry_date 2016-04-02 (nearest earlier bar: 2016-04-01)"))
      ((symbol UAA) (entry_date 2021-11-20)
       (detail
        "no bar on entry_date 2021-11-20 (nearest earlier bar: 2021-11-19)")))))
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
     (((symbol BRK-A) (entry_date 2006-05-18)
       (detail
        "median close 83025.10 over 11230 bars (1980-03-17..2026-06-15), above the 10000.00 ceiling"))
      ((symbol CBE) (entry_date 2005-02-03)
       (detail
        "median close 74.58 over 11518 bars (1972-06-01..2018-01-30); bar 1997-05-19 close 60.00 (+92.00% vs prior close 31.25) on volume 0"))
      ((symbol CLE) (entry_date 2006-12-11)
       (detail
        "median close 19.00 over 4813 bars (1997-12-31..2018-06-28); bar 2014-06-09 close 0.07 (-94.53% vs prior close 1.28) on volume 0"))
      ((symbol FERG) (entry_date 2025-07-23)
       (detail
        "median close 69.77 over 4402 bars (2001-07-20..2026-06-15); bar 2001-10-22 close 60.37 (-97.71% vs prior close 2641.96) on volume 0"))
      ((symbol ISA) (entry_date 2010-09-18)
       (detail
        "median close 7360.00 over 5664 bars (1997-12-31..2020-07-07); bar 2001-08-22 close 0.05 (-100.00% vs prior close 1070.00) on volume 0"))
      ((symbol LNG) (entry_date 2026-03-14)
       (detail
        "median close 27.70 over 8104 bars (1994-04-04..2026-06-15); bar 1994-07-19 close 6.00 (+500.00% vs prior close 1.00) on volume 0"))
      ((symbol RGLD) (entry_date 2009-11-06)
       (detail
        "median close 17.48 over 11346 bars (1981-06-09..2026-06-15); bar 1992-06-01 close 0.38 (+200.00% vs prior close 0.12) on volume 0"))
      ((symbol RRC) (entry_date 2006-11-30)
       (detail
        "median close 16.75 over 9584 bars (1984-11-05..2026-06-15); bar 1992-11-23 close 4.22 (+1399.47% vs prior close 0.28) on volume 0"))
      ((symbol UCM) (entry_date 2000-05-22)
       (detail
        "median close 0.10 over 3743 bars (1997-12-31..2019-12-09); bar 2010-01-04 close 0.28 (-97.37% vs prior close 10.65) on volume 0"))
      ((symbol VNA) (entry_date 2015-02-05)
       (detail
        "median close 3100.00 over 1882 bars (2010-02-22..2018-02-28); bar 2015-12-11 close 29.09 (-98.79% vs prior close 2400.00) on volume 0")))))))
 (audit_join ((matched 739) (total 739))))
