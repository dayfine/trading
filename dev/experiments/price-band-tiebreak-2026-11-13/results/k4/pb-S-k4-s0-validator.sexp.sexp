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
    (specimens ())
    (skip_reason "share-class map: /w/trading/test_data/share_classes.sexp"))
   ((id V7) (severity Invariant) (passed false) (n_violations 38)
    (n_skipped 0)
    (specimens
     (((symbol ZION) (entry_date 2005-11-18)
       (detail
        "Virgin_territory but only 0 weekly bars (< 520) before entry"))
      ((symbol XERS) (entry_date 2024-02-14)
       (detail
        "Virgin_territory but only 295 weekly bars (< 520) before entry"))
      ((symbol WRB) (entry_date 2018-04-20)
       (detail
        "Virgin_territory but only 485 weekly bars (< 520) before entry"))
      ((symbol VRSK) (entry_date 2017-02-22)
       (detail
        "Virgin_territory but only 385 weekly bars (< 520) before entry"))
      ((symbol UHAL) (entry_date 2015-02-03)
       (detail
        "Virgin_territory but only 318 weekly bars (< 520) before entry"))
      ((symbol TRW1) (entry_date 2000-03-27)
       (detail
        "Virgin_territory but only 117 weekly bars (< 520) before entry"))
      ((symbol TRNO) (entry_date 2017-04-11)
       (detail
        "Virgin_territory but only 374 weekly bars (< 520) before entry"))
      ((symbol POM_old) (entry_date 2006-07-26)
       (detail
        "Virgin_territory but only 447 weekly bars (< 520) before entry"))
      ((symbol PBF) (entry_date 2015-03-25)
       (detail
        "Virgin_territory but only 119 weekly bars (< 520) before entry"))
      ((symbol NVS) (entry_date 2005-10-03)
       (detail
        "Virgin_territory but only 0 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 111)
    (n_skipped 177)
    (specimens
     (((symbol XLRN) (entry_date 2018-07-23)
       (detail "prior_top=51.43 within +25% of entry=47.46"))
      ((symbol XLRN) (entry_date 2020-04-20)
       (detail "prior_top=97.78 within +25% of entry=97.02"))
      ((symbol X) (entry_date 2023-09-19)
       (detail "prior_top=37.63 within +25% of entry=31.75"))
      ((symbol WOLF_old2) (entry_date 2021-11-22)
       (detail "prior_top=139.55 within +25% of entry=133.00"))
      ((symbol WIX) (entry_date 2021-03-03)
       (detail "prior_top=353.09 within +25% of entry=327.36"))
      ((symbol WIFI) (entry_date 2018-11-02)
       (detail "prior_top=34.90 within +25% of entry=29.05"))
      ((symbol VMC) (entry_date 2012-10-04)
       (detail "prior_top=57.96 within +25% of entry=48.49"))
      ((symbol VICR) (entry_date 2021-07-27)
       (detail "prior_top=107.97 within +25% of entry=107.30"))
      ((symbol VAS) (entry_date 2004-02-02)
       (detail "prior_top=24.49 within +25% of entry=23.76"))
      ((symbol USB) (entry_date 2024-08-28)
       (detail "prior_top=52.11 within +25% of entry=46.10")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 5)
    (n_skipped 177)
    (specimens
     (((symbol SATL) (entry_date 2026-04-01)
       (detail "entry_wk_close=6.77 > prior=3.09 (spike>60%)"))
      ((symbol PUMP) (entry_date 2025-11-12)
       (detail "entry_wk_close=9.92 > prior=5.54 (spike>60%)"))
      ((symbol ISEE) (entry_date 2022-09-30)
       (detail "entry_wk_close=17.94 > prior=9.44 (spike>60%)"))
      ((symbol INOD) (entry_date 2025-09-29)
       (detail "entry_wk_close=84.14 > prior=43.48 (spike>60%)"))
      ((symbol APPS) (entry_date 2020-06-15)
       (detail "entry_wk_close=10.38 > prior=5.82 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V13) (severity Invariant) (passed false) (n_violations 42)
    (n_skipped 3)
    (specimens
     (((symbol ZION) (entry_date 2004-10-21)
       (detail "no bar on entry_date 2004-10-21 (nearest earlier bar: none)"))
      ((symbol ZION) (entry_date 2005-11-18)
       (detail "no bar on entry_date 2005-11-18 (nearest earlier bar: none)"))
      ((symbol WTRG) (entry_date 2003-11-21)
       (detail
        "entry_price=20.1800 outside 2003-11-21 bar [24.9200, 25.2300]"))
      ((symbol WRB) (entry_date 2000-08-28)
       (detail "no bar on entry_date 2000-08-28 (nearest earlier bar: none)"))
      ((symbol WDC) (entry_date 2003-10-06)
       (detail "no bar on entry_date 2003-10-06 (nearest earlier bar: none)"))
      ((symbol TYL) (entry_date 2007-09-11)
       (detail "no bar on entry_date 2007-09-11 (nearest earlier bar: none)"))
      ((symbol TSCO) (entry_date 2005-03-28)
       (detail "no bar on entry_date 2005-03-28 (nearest earlier bar: none)"))
      ((symbol TRMB) (entry_date 2003-11-24)
       (detail "no bar on entry_date 2003-11-24 (nearest earlier bar: none)"))
      ((symbol STT) (entry_date 2000-04-10)
       (detail "no bar on entry_date 2000-04-10 (nearest earlier bar: none)"))
      ((symbol SNA) (entry_date 2004-03-08)
       (detail "no bar on entry_date 2004-03-08 (nearest earlier bar: none)")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 15)
    (n_skipped 16)
    (specimens
     (((symbol UPWK) (entry_date 2025-09-30)
       (detail
        "entry bar 2025-09-30 open=18.9800 low=18.2150 close=18.5700 vs stop=17.8706, exit=17.8300"))
      ((symbol TDS) (entry_date 2023-09-11)
       (detail
        "entry bar 2023-09-11 open=17.8500 low=17.3700 close=17.6500 vs stop=17.1658, exit=17.0600"))
      ((symbol SDA) (entry_date 2023-07-12)
       (detail
        "entry bar 2023-07-12 open=14.1500 low=11.5500 close=11.7000 vs stop=10.4919, exit=10.4400"))
      ((symbol PUMP) (entry_date 2025-11-12)
       (detail
        "entry bar 2025-11-12 open=11.0100 low=10.1850 close=10.4300 vs stop=9.8372, exit=9.7100"))
      ((symbol MLNX) (entry_date 2018-11-19)
       (detail
        "entry bar 2018-11-19 open=92.8500 low=91.1200 close=91.2800 vs stop=85.8773, exit=85.8500"))
      ((symbol MBI) (entry_date 2013-03-18)
       (detail
        "entry bar 2013-03-18 open=11.8800 low=11.7600 close=11.7900 vs stop=11.4139, exit=11.3800"))
      ((symbol FSH) (entry_date 2005-11-15)
       (detail
        "entry bar 2005-11-15 open=65.0000 low=64.8200 close=65.5000 vs stop=58.4590, exit=64.1500"))
      ((symbol FLNA) (entry_date 2020-10-12)
       (detail
        "entry bar 2020-10-12 open=11.8900 low=11.0700 close=11.4300 vs stop=10.8755, exit=10.8100"))
      ((symbol EXTR) (entry_date 2022-01-21)
       (detail
        "entry bar 2022-01-21 open=12.8100 low=12.4900 close=12.4900 vs stop=12.1943, exit=12.0900"))
      ((symbol EPRS) (entry_date 2011-01-19)
       (detail
        "entry bar 2011-01-19 open=127.2000 low=120.0000 close=120.6000 vs stop=109.8743, exit=109.7200")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 0)
    (specimens
     (((symbol NLC) (entry_date 2011-08-15)
       (detail
        "stale_force_exit exit 2011-12-06 (entry 2011-08-15 @ 33.17, exit @ 38.80)")))))
   ((id V17) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 33)
    (specimens
     (((symbol QCOM) (entry_date 2026-05-18)
       (detail
        "entry filled 2026-05-18 but last bar is 2026-04-10 (38 days stale)")))))
   ((id V18) (severity Expectation) (passed false) (n_violations 7)
    (n_skipped 1)
    (specimens
     (((symbol ANIP) (entry_date 2024-03-11)
       (detail
        "median close 26.24 over 6160 bars (2001-07-24..2026-06-24); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0"))
      ((symbol ARJ) (entry_date 2005-12-29)
       (detail
        "median close 0.16 over 4552 bars (1999-02-09..2017-03-13); bar 2010-01-29 close 0.13 (-99.55% vs prior close 28.25) on volume 0"))
      ((symbol EHC) (entry_date 2014-09-04)
       (detail
        "median close 23.25 over 10013 bars (1986-09-24..2026-06-24); bar 2006-10-26 close 23.75 (+400.00% vs prior close 4.75) on volume 0"))
      ((symbol FIT) (entry_date 2019-11-26)
       (detail
        "median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0"))
      ((symbol NLC) (entry_date 2011-08-15)
       (detail
        "median close 18.62 over 2816 bars (2004-11-11..2018-01-30); bar 2015-04-15 close 15.54 (+8533.33% vs prior close 0.18) on volume 0"))
      ((symbol PPP) (entry_date 2005-06-13)
       (detail
        "median close 5.31 over 2978 bars (2003-09-10..2017-08-14); bar 2009-12-14 close 4.40 (-92.67% vs prior close 60.00) on volume 0"))
      ((symbol TNXP) (entry_date 2025-06-10)
       (detail
        "median close 0.16 over 3561 bars (2012-02-03..2026-06-24); bar 2012-05-10 close 0.00 (-99.99% vs prior close 1.50) on volume 0")))))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V21) (severity Expectation) (passed false) (n_violations 63)
    (n_skipped 0)
    (specimens
     (((symbol WIFI) (entry_date 2018-11-02)
       (detail
        "LONG installed_stop 27.8750 vs screener_proxy_stop 26.2016: 6.39% tighter > 3%"))
      ((symbol VMC) (entry_date 2016-11-28)
       (detail
        "LONG installed_stop 121.2960 vs screener_proxy_stop 117.6128: 3.13% tighter > 3%"))
      ((symbol VGR) (entry_date 2021-12-06)
       (detail
        "LONG installed_stop 10.3471 vs screener_proxy_stop 10.0280: 3.18% tighter > 3%"))
      ((symbol UPWK) (entry_date 2025-09-30)
       (detail
        "LONG installed_stop 17.8750 vs screener_proxy_stop 16.7716: 6.58% tighter > 3%"))
      ((symbol TROX) (entry_date 2014-09-19)
       (detail
        "LONG installed_stop 25.8048 vs screener_proxy_stop 24.9872: 3.27% tighter > 3%"))
      ((symbol TDS) (entry_date 2023-09-11)
       (detail
        "LONG installed_stop 17.1648 vs screener_proxy_stop 16.0264: 7.10% tighter > 3%"))
      ((symbol SYY) (entry_date 2013-12-16)
       (detail
        "LONG installed_stop 34.4928 vs screener_proxy_stop 33.3316: 3.48% tighter > 3%"))
      ((symbol SSTK) (entry_date 2020-09-04)
       (detail
        "LONG installed_stop 44.4864 vs screener_proxy_stop 42.5132: 4.64% tighter > 3%"))
      ((symbol SNBR) (entry_date 2011-11-10)
       (detail
        "LONG installed_stop 18.8160 vs screener_proxy_stop 17.7836: 5.81% tighter > 3%"))
      ((symbol RYAAY) (entry_date 2003-10-27)
       (detail
        "LONG installed_stop 46.3750 vs screener_proxy_stop 44.5832: 4.02% tighter > 3%")))))
   ((id V22) (severity Expectation) (passed false) (n_violations 96)
    (n_skipped 105)
    (specimens
     (((symbol ABEV) (entry_date 2012-11-02)
       (detail
        "no stop move for 16 weeks (2012-11-29..2013-03-22), 1 completed cycle(s) stalled; last: stop 32.19, candidate 4.34, ma 4.38, correction extreme 40.74 (extreme/ma 9.30)"))
      ((symbol ACN) (entry_date 2006-10-13)
       (detail
        "no stop move for 27 weeks (2006-10-30..2007-05-11), 3 completed cycle(s) stalled; last: stop 28.66, candidate 25.44, ma 25.69, correction extreme 34.28 (extreme/ma 1.33)"))
      ((symbol ADNT) (entry_date 2020-02-21)
       (detail
        "no stop move for 31 weeks (2020-11-09..2021-06-18), 1 completed cycle(s) stalled; last: stop 25.38, candidate 20.66, ma 20.86, correction extreme 26.23 (extreme/ma 1.26)"))
      ((symbol ADSK) (entry_date 2003-09-12)
       (detail
        "no stop move for 49 weeks (2003-09-15..2004-08-25), 6 completed cycle(s) stalled; last: stop 16.66, candidate 16.39, ma 16.55, correction extreme 35.50 (extreme/ma 2.14)"))
      ((symbol AIT) (entry_date 2022-08-26)
       (detail
        "no stop move for 16 weeks (2022-10-05..2023-01-26), 1 completed cycle(s) stalled; last: stop 104.22, candidate 102.48, ma 103.52, correction extreme 114.59 (extreme/ma 1.11)"))
      ((symbol ALSK) (entry_date 2006-03-10)
       (detail
        "no stop move for 49 weeks (2006-03-21..2007-03-02), 6 completed cycle(s) stalled; last: stop 10.37, candidate 8.72, ma 8.81, correction extreme 15.15 (extreme/ma 1.72)"))
      ((symbol ALXN) (entry_date 2004-02-06)
       (detail
        "no stop move for 14 weeks (2004-02-10..2004-05-21), 1 completed cycle(s) stalled; last: stop 18.69, candidate 4.77, ma 4.82, correction extreme 20.99 (extreme/ma 4.36)"))
      ((symbol AN) (entry_date 2020-07-31)
       (detail
        "no stop move for 16 weeks (2020-08-04..2020-11-24), 2 completed cycle(s) stalled; last: stop 48.84, candidate 48.78, ma 49.27, correction extreme 50.52 (extreme/ma 1.03)"))
      ((symbol AOS) (entry_date 2009-11-27)
       (detail
        "no stop move for 27 weeks (2009-11-30..2010-06-07), 2 completed cycle(s) stalled; last: stop 37.16, candidate 5.81, ma 5.87, correction extreme 48.43 (extreme/ma 8.25)"))
      ((symbol APOG) (entry_date 2007-01-12)
       (detail
        "no stop move for 33 weeks (2007-01-17..2007-09-10), 3 completed cycle(s) stalled; last: stop 17.33, candidate 14.76, ma 14.91, correction extreme 22.90 (extreme/ma 1.54)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed false) (n_violations 17)
    (n_skipped 0)
    (specimens
     (((symbol WDFC) (entry_date 2011-10-14)
       (detail "filled 2011-10-14 after the 2011-10-07 screen read Bearish"))
      ((symbol SYK) (entry_date 2019-01-30)
       (detail "filled 2019-01-30 after the 2019-01-25 screen read Bearish"))
      ((symbol SPNT) (entry_date 2025-04-14)
       (detail "filled 2025-04-14 after the 2025-04-11 screen read Bearish"))
      ((symbol PPDI) (entry_date 2011-10-03)
       (detail "filled 2011-10-03 after the 2011-09-30 screen read Bearish"))
      ((symbol POM_old) (entry_date 2006-07-26)
       (detail "filled 2006-07-26 after the 2006-07-21 screen read Bearish"))
      ((symbol PAET) (entry_date 2011-10-04)
       (detail "filled 2011-10-04 after the 2011-09-30 screen read Bearish"))
      ((symbol OFIX) (entry_date 2019-02-12)
       (detail "filled 2019-02-12 after the 2019-02-08 screen read Bearish"))
      ((symbol NRG) (entry_date 2006-07-28)
       (detail "filled 2006-07-28 after the 2006-07-21 screen read Bearish"))
      ((symbol NJR) (entry_date 2006-07-24)
       (detail "filled 2006-07-24 after the 2006-07-21 screen read Bearish"))
      ((symbol MZTI) (entry_date 2015-09-03)
       (detail "filled 2015-09-03 after the 2015-08-28 screen read Bearish")))))))
 (audit_join ((matched 548) (total 548))))
