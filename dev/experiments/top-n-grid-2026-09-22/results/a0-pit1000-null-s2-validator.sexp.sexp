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
   ((id V7) (severity Invariant) (passed false) (n_violations 96)
    (n_skipped 0)
    (specimens
     (((symbol ZS) (entry_date 2021-07-12)
       (detail
        "Virgin_territory but only 176 weekly bars (< 520) before entry"))
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
        "Virgin_territory but only 126 weekly bars (< 520) before entry"))
      ((symbol UAA) (entry_date 2010-09-15)
       (detail
        "Virgin_territory but only 254 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 67)
    (n_skipped 295)
    (specimens
     (((symbol YUM) (entry_date 2025-04-07)
       (detail "prior_top=158.67 within +25% of entry=144.64"))
      ((symbol WIX) (entry_date 2021-03-03)
       (detail "prior_top=353.09 within +25% of entry=327.36"))
      ((symbol VRTX) (entry_date 2014-06-28)
       (detail "prior_top=93.77 within +25% of entry=92.22"))
      ((symbol URBN) (entry_date 2025-03-13)
       (detail "prior_top=58.19 within +25% of entry=50.12"))
      ((symbol ULTA) (entry_date 2016-04-02)
       (detail "prior_top=194.18 within +25% of entry=192.62"))
      ((symbol UHS) (entry_date 2018-08-22)
       (detail "prior_top=138.68 within +25% of entry=128.79"))
      ((symbol TWX1) (entry_date 2000-01-28)
       (detail "prior_top=91.12 within +25% of entry=80.60"))
      ((symbol TW) (entry_date 2025-05-10)
       (detail "prior_top=146.66 within +25% of entry=145.25"))
      ((symbol TGT) (entry_date 2020-03-12)
       (detail "prior_top=107.27 within +25% of entry=92.66"))
      ((symbol SNPS) (entry_date 2025-07-19)
       (detail "prior_top=621.30 within +25% of entry=596.71")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 7)
    (n_skipped 295)
    (specimens
     (((symbol RMBS) (entry_date 2000-06-22)
       (detail "entry_wk_close=114.69 > prior=40.75 (spike>60%)"))
      ((symbol RBAK) (entry_date 2006-12-23)
       (detail "entry_wk_close=24.94 > prior=14.52 (spike>60%)"))
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
   ((id V12) (severity Invariant) (passed false) (n_violations 25)
    (n_skipped 0)
    (specimens
     (((symbol YMM) (entry_date 2024-11-20)
       (detail
        "installed_stop=8.2848 vs fill=9.7600 -> dist=0.1511 > gate=0.1500"))
      ((symbol VOYA) (entry_date 2017-11-29)
       (detail
        "installed_stop=36.7008 vs fill=43.5100 -> dist=0.1565 > gate=0.1500"))
      ((symbol TAP) (entry_date 2007-09-19)
       (detail
        "installed_stop=83.6448 vs fill=49.1200 -> dist=0.7029 > gate=0.1500"))
      ((symbol PENN) (entry_date 2001-06-02)
       (detail
        "installed_stop=15.7028 vs fill=18.8300 -> dist=0.1661 > gate=0.1500"))
      ((symbol ODFL) (entry_date 2005-11-11)
       (detail
        "installed_stop=37.1520 vs fill=25.8600 -> dist=0.4367 > gate=0.1500"))
      ((symbol ODFL) (entry_date 2005-11-11)
       (detail
        "installed_stop=37.1520 vs fill=25.8600 -> dist=0.4367 > gate=0.1500"))
      ((symbol NRG) (entry_date 2006-11-18)
       (detail
        "installed_stop=50.7552 vs fill=26.9500 -> dist=0.8833 > gate=0.1500"))
      ((symbol NKE) (entry_date 2006-10-25)
       (detail
        "installed_stop=88.3200 vs fill=46.0400 -> dist=0.9183 > gate=0.1500"))
      ((symbol NKE) (entry_date 2015-07-30)
       (detail
        "installed_stop=110.7648 vs fill=57.7000 -> dist=0.9197 > gate=0.1500"))
      ((symbol MMM) (entry_date 2003-07-26)
       (detail
        "installed_stop=131.9328 vs fill=69.6800 -> dist=0.8934 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 173)
    (n_skipped 12)
    (specimens
     (((symbol YUMC) (entry_date 2019-12-21)
       (detail
        "no bar on entry_date 2019-12-21 (nearest earlier bar: 2019-12-20)"))
      ((symbol YUM) (entry_date 2022-01-01)
       (detail
        "no bar on entry_date 2022-01-01 (nearest earlier bar: 2021-12-31)"))
      ((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)"))
      ((symbol WLK) (entry_date 2012-08-06)
       (detail
        "entry_price=64.6000 outside 2012-08-06 bar [65.8500, 68.4000]"))
      ((symbol WDC) (entry_date 2012-08-18)
       (detail
        "no bar on entry_date 2012-08-18 (nearest earlier bar: 2012-08-17)"))
      ((symbol VZ) (entry_date 2025-03-08)
       (detail
        "no bar on entry_date 2025-03-08 (nearest earlier bar: 2025-03-07)"))
      ((symbol VRTX) (entry_date 2014-06-28)
       (detail
        "no bar on entry_date 2014-06-28 (nearest earlier bar: 2014-06-27)"))
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
   ((id V18) (severity Expectation) (passed false) (n_violations 13)
    (n_skipped 0)
    (specimens
     (((symbol BRK-A) (entry_date 2006-05-18)
       (detail
        "median close 83000.00 over 11223 bars (1980-03-17..2026-06-04), above the 10000.00 ceiling"))
      ((symbol CBE) (entry_date 2005-02-03)
       (detail
        "median close 74.58 over 11518 bars (1972-06-01..2018-01-30); bar 1997-05-19 close 60.00 (+92.00% vs prior close 31.25) on volume 0"))
      ((symbol CLE) (entry_date 2006-12-11)
       (detail
        "median close 19.00 over 4813 bars (1997-12-31..2018-06-28); bar 2014-06-09 close 0.07 (-94.53% vs prior close 1.28) on volume 0"))
      ((symbol FERG) (entry_date 2025-07-23)
       (detail
        "median close 69.50 over 4395 bars (2001-07-20..2026-06-04); bar 2001-10-22 close 60.37 (-97.71% vs prior close 2641.96) on volume 0"))
      ((symbol IOVA) (entry_date 2020-12-01)
       (detail
        "median close 7.49 over 3932 bars (2010-10-15..2026-06-04); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0"))
      ((symbol ISA) (entry_date 2019-03-14)
       (detail
        "median close 7360.00 over 5664 bars (1997-12-31..2020-07-07); bar 2001-08-22 close 0.05 (-100.00% vs prior close 1070.00) on volume 0"))
      ((symbol LAR) (entry_date 2021-10-29)
       (detail
        "median close 1.46 over 4455 bars (2008-09-18..2026-06-04); bar 2017-11-08 close 7.65 (+400.03% vs prior close 1.53) on volume 0"))
      ((symbol LNG) (entry_date 2026-03-07)
       (detail
        "median close 27.68 over 8097 bars (1994-04-04..2026-06-04); bar 1994-07-19 close 6.00 (+500.00% vs prior close 1.00) on volume 0"))
      ((symbol RGLD) (entry_date 2009-11-06)
       (detail
        "median close 17.46 over 11339 bars (1981-06-09..2026-06-04); bar 1992-06-01 close 0.38 (+200.00% vs prior close 0.12) on volume 0"))
      ((symbol RRC) (entry_date 2006-11-30)
       (detail
        "median close 16.75 over 9577 bars (1984-11-05..2026-06-04); bar 1992-11-23 close 4.22 (+1399.47% vs prior close 0.28) on volume 0")))))))
 (audit_join ((matched 761) (total 761))))
