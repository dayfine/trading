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
   ((id V7) (severity Invariant) (passed false) (n_violations 98)
    (n_skipped 0)
    (specimens
     (((symbol ZS) (entry_date 2021-07-12)
       (detail
        "Virgin_territory but only 176 weekly bars (< 520) before entry"))
      ((symbol Z) (entry_date 2020-02-20)
       (detail
        "Virgin_territory but only 239 weekly bars (< 520) before entry"))
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
      ((symbol VC) (entry_date 2015-05-22)
       (detail
        "Virgin_territory but only 245 weekly bars (< 520) before entry"))
      ((symbol UCM) (entry_date 2000-05-22)
       (detail
        "Virgin_territory but only 126 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 70)
    (n_skipped 282)
    (specimens
     (((symbol ZBH) (entry_date 2012-12-12)
       (detail "prior_top=67.87 within +25% of entry=67.54"))
      ((symbol YUM) (entry_date 2025-04-07)
       (detail "prior_top=158.67 within +25% of entry=144.64"))
      ((symbol X) (entry_date 2023-08-21)
       (detail "prior_top=37.63 within +25% of entry=31.79"))
      ((symbol WWAV) (entry_date 2016-10-07)
       (detail "prior_top=56.64 within +25% of entry=53.85"))
      ((symbol VRTX) (entry_date 2014-06-28)
       (detail "prior_top=93.77 within +25% of entry=92.22"))
      ((symbol VRTX) (entry_date 2019-11-09)
       (detail "prior_top=201.31 within +25% of entry=197.08"))
      ((symbol URBN) (entry_date 2025-03-13)
       (detail "prior_top=58.19 within +25% of entry=50.12"))
      ((symbol URBN) (entry_date 2026-01-06)
       (detail "prior_top=81.84 within +25% of entry=81.27"))
      ((symbol ULTA) (entry_date 2016-04-02)
       (detail "prior_top=194.18 within +25% of entry=192.62"))
      ((symbol UHS) (entry_date 2018-08-22)
       (detail "prior_top=138.68 within +25% of entry=128.80")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 7)
    (n_skipped 282)
    (specimens
     (((symbol RMBS) (entry_date 2000-06-22)
       (detail "entry_wk_close=114.69 > prior=40.75 (spike>60%)"))
      ((symbol RBAK) (entry_date 2006-12-23)
       (detail "entry_wk_close=24.94 > prior=14.52 (spike>60%)"))
      ((symbol OCHTQ) (entry_date 2000-02-17)
       (detail "entry_wk_close=6300.00 > prior=3075.00 (spike>60%)"))
      ((symbol DDD) (entry_date 2021-01-19)
       (detail "entry_wk_close=34.48 > prior=11.55 (spike>60%)"))
      ((symbol CBMC) (entry_date 2000-03-06)
       (detail "entry_wk_close=191.25 > prior=71.25 (spike>60%)"))
      ((symbol ATISZ) (entry_date 2000-02-09)
       (detail "entry_wk_close=7.13 > prior=3.56 (spike>60%)"))
      ((symbol ABRX) (entry_date 2000-03-09)
       (detail "entry_wk_close=15.00 > prior=8.44 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 26)
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
        "installed_stop=32.9664 vs fill=17.3100 -> dist=0.9045 > gate=0.1500"))
      ((symbol PENN) (entry_date 2001-06-02)
       (detail
        "installed_stop=15.7028 vs fill=18.8300 -> dist=0.1661 > gate=0.1500"))
      ((symbol ODFL) (entry_date 2005-11-11)
       (detail
        "installed_stop=37.1520 vs fill=25.9300 -> dist=0.4328 > gate=0.1500"))
      ((symbol ODFL) (entry_date 2005-11-11)
       (detail
        "installed_stop=37.1520 vs fill=25.9300 -> dist=0.4328 > gate=0.1500"))
      ((symbol NRG) (entry_date 2006-11-18)
       (detail
        "installed_stop=50.7552 vs fill=26.9500 -> dist=0.8833 > gate=0.1500"))
      ((symbol NKE) (entry_date 2006-10-25)
       (detail
        "installed_stop=88.3200 vs fill=46.0300 -> dist=0.9187 > gate=0.1500"))
      ((symbol MMM) (entry_date 2003-07-26)
       (detail
        "installed_stop=131.9328 vs fill=69.6800 -> dist=0.8934 > gate=0.1500"))
      ((symbol MGM) (entry_date 2001-09-18)
       (detail
        "installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 151)
    (n_skipped 12)
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
        "entry_price=64.5300 outside 2012-08-06 bar [65.8500, 68.4000]"))
      ((symbol WFM) (entry_date 2013-05-18)
       (detail
        "no bar on entry_date 2013-05-18 (nearest earlier bar: 2013-05-17)"))
      ((symbol VRTX) (entry_date 2014-06-28)
       (detail
        "no bar on entry_date 2014-06-28 (nearest earlier bar: 2014-06-27)"))
      ((symbol VRTX) (entry_date 2019-11-09)
       (detail
        "no bar on entry_date 2019-11-09 (nearest earlier bar: 2019-11-08)"))
      ((symbol VRSK) (entry_date 2017-11-04)
       (detail
        "no bar on entry_date 2017-11-04 (nearest earlier bar: 2017-11-03)"))
      ((symbol URBN) (entry_date 2025-12-20)
       (detail
        "no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)"))
      ((symbol ULTA) (entry_date 2016-04-02)
       (detail
        "no bar on entry_date 2016-04-02 (nearest earlier bar: 2016-04-01)")))))
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
     (((symbol BRK-A) (entry_date 2006-05-18)
       (detail
        "median close 83087.55 over 11234 bars (1980-03-17..2026-06-22), above the 10000.00 ceiling"))
      ((symbol CBE) (entry_date 2005-02-03)
       (detail
        "median close 74.58 over 11518 bars (1972-06-01..2018-01-30); bar 1997-05-19 close 60.00 (+92.00% vs prior close 31.25) on volume 0"))
      ((symbol CLE) (entry_date 2006-12-11)
       (detail
        "median close 19.00 over 4813 bars (1997-12-31..2018-06-28); bar 2014-06-09 close 0.07 (-94.53% vs prior close 1.28) on volume 0"))
      ((symbol IOVA) (entry_date 2020-12-01)
       (detail
        "median close 7.45 over 3943 bars (2010-10-15..2026-06-22); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0"))
      ((symbol LAR) (entry_date 2021-10-29)
       (detail
        "median close 1.48 over 4466 bars (2008-09-18..2026-06-22); bar 2017-11-08 close 7.65 (+400.03% vs prior close 1.53) on volume 0"))
      ((symbol RGLD) (entry_date 2009-11-06)
       (detail
        "median close 17.49 over 11350 bars (1981-06-09..2026-06-22); bar 1992-06-01 close 0.38 (+200.00% vs prior close 0.12) on volume 0"))
      ((symbol RRC) (entry_date 2006-11-30)
       (detail
        "median close 16.75 over 9588 bars (1984-11-05..2026-06-22); bar 1992-11-23 close 4.22 (+1399.47% vs prior close 0.28) on volume 0"))
      ((symbol UCM) (entry_date 2000-05-22)
       (detail
        "median close 0.10 over 3743 bars (1997-12-31..2019-12-09); bar 2010-01-04 close 0.28 (-97.37% vs prior close 10.65) on volume 0"))
      ((symbol WWY) (entry_date 2007-04-30)
       (detail
        "median close 45.02 over 4141 bars (1997-12-31..2016-06-22); bar 2010-10-13 close 4.77 (-94.04% vs prior close 79.97) on volume 0")))))))
 (audit_join ((matched 733) (total 733))))
