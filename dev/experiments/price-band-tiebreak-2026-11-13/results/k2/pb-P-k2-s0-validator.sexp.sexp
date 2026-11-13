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
   ((id V7) (severity Invariant) (passed false) (n_violations 33)
    (n_skipped 0)
    (specimens
     (((symbol WRB) (entry_date 2018-04-20)
       (detail
        "Virgin_territory but only 485 weekly bars (< 520) before entry"))
      ((symbol WING) (entry_date 2017-08-08)
       (detail
        "Virgin_territory but only 113 weekly bars (< 520) before entry"))
      ((symbol WDR) (entry_date 2007-07-13)
       (detail
        "Virgin_territory but only 488 weekly bars (< 520) before entry"))
      ((symbol VRSK) (entry_date 2017-02-22)
       (detail
        "Virgin_territory but only 385 weekly bars (< 520) before entry"))
      ((symbol VOYA) (entry_date 2017-11-29)
       (detail
        "Virgin_territory but only 239 weekly bars (< 520) before entry"))
      ((symbol UHAL) (entry_date 2015-02-03)
       (detail
        "Virgin_territory but only 318 weekly bars (< 520) before entry"))
      ((symbol TRW1) (entry_date 2000-03-27)
       (detail
        "Virgin_territory but only 117 weekly bars (< 520) before entry"))
      ((symbol TRNO) (entry_date 2017-04-11)
       (detail
        "Virgin_territory but only 374 weekly bars (< 520) before entry"))
      ((symbol PBF) (entry_date 2015-03-25)
       (detail
        "Virgin_territory but only 119 weekly bars (< 520) before entry"))
      ((symbol NABZY) (entry_date 2006-01-31)
       (detail
        "Virgin_territory but only 422 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 110)
    (n_skipped 150)
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
      ((symbol WITS) (entry_date 2005-10-20)
       (detail "prior_top=20.89 within +25% of entry=20.10"))
      ((symbol WIFI) (entry_date 2018-11-02)
       (detail "prior_top=34.90 within +25% of entry=29.05"))
      ((symbol VRTX) (entry_date 2012-06-07)
       (detail "prior_top=64.85 within +25% of entry=56.30"))
      ((symbol VRTX) (entry_date 2014-07-30)
       (detail "prior_top=99.07 within +25% of entry=92.22"))
      ((symbol VMC) (entry_date 2012-10-17)
       (detail "prior_top=57.96 within +25% of entry=48.33")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 5)
    (n_skipped 150)
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
   ((id V13) (severity Invariant) (passed false) (n_violations 39)
    (n_skipped 4)
    (specimens
     (((symbol ZION) (entry_date 2004-10-21)
       (detail "no bar on entry_date 2004-10-21 (nearest earlier bar: none)"))
      ((symbol WRB) (entry_date 2000-08-28)
       (detail "no bar on entry_date 2000-08-28 (nearest earlier bar: none)"))
      ((symbol WDC) (entry_date 2003-10-02)
       (detail "no bar on entry_date 2003-10-02 (nearest earlier bar: none)"))
      ((symbol WAB) (entry_date 2003-08-18)
       (detail "no bar on entry_date 2003-08-18 (nearest earlier bar: none)"))
      ((symbol TYL) (entry_date 2007-09-17)
       (detail "no bar on entry_date 2007-09-17 (nearest earlier bar: none)"))
      ((symbol TRMB) (entry_date 2003-11-24)
       (detail "no bar on entry_date 2003-11-24 (nearest earlier bar: none)"))
      ((symbol STT) (entry_date 2000-04-10)
       (detail "no bar on entry_date 2000-04-10 (nearest earlier bar: none)"))
      ((symbol SNA) (entry_date 2004-03-08)
       (detail "no bar on entry_date 2004-03-08 (nearest earlier bar: none)"))
      ((symbol RYAAY) (entry_date 2003-10-27)
       (detail "no bar on entry_date 2003-10-27 (nearest earlier bar: none)"))
      ((symbol ROL) (entry_date 2007-03-12)
       (detail "no bar on entry_date 2007-03-12 (nearest earlier bar: none)")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 13)
    (n_skipped 12)
    (specimens
     (((symbol VCYT) (entry_date 2020-07-27)
       (detail
        "entry bar 2020-07-27 open=30.3700 low=29.3700 close=30.2400 vs stop=28.6744, exit=28.6200"))
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
      ((symbol FLNA) (entry_date 2020-10-12)
       (detail
        "entry bar 2020-10-12 open=11.8900 low=11.0700 close=11.4300 vs stop=10.8755, exit=10.8100"))
      ((symbol EXTR) (entry_date 2022-01-21)
       (detail
        "entry bar 2022-01-21 open=12.8100 low=12.4900 close=12.4900 vs stop=12.1943, exit=12.0900"))
      ((symbol EPRS) (entry_date 2011-01-19)
       (detail
        "entry bar 2011-01-19 open=127.2000 low=120.0000 close=120.6000 vs stop=109.8743, exit=109.7200"))
      ((symbol CVNA) (entry_date 2025-12-31)
       (detail
        "entry bar 2025-12-31 open=429.5500 low=421.8550 close=422.0200 vs stop=406.8887, exit=406.7000"))
      ((symbol CRON) (entry_date 2018-09-24)
       (detail
        "entry bar 2018-09-24 open=11.8000 low=11.6500 close=11.8600 vs stop=11.7871, exit=11.7100")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 0)
    (specimens
     (((symbol NLC) (entry_date 2011-08-11)
       (detail
        "stale_force_exit exit 2011-12-06 (entry 2011-08-11 @ 32.79, exit @ 38.80)")))))
   ((id V17) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 31)
    (specimens
     (((symbol QCOM) (entry_date 2026-05-18)
       (detail
        "entry filled 2026-05-18 but last bar is 2026-04-10 (38 days stale)")))))
   ((id V18) (severity Expectation) (passed false) (n_violations 8)
    (n_skipped 1)
    (specimens
     (((symbol ANIP) (entry_date 2024-03-11)
       (detail
        "median close 26.24 over 6160 bars (2001-07-24..2026-06-24); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0"))
      ((symbol BRK-A) (entry_date 2017-08-03)
       (detail
        "median close 83100.00 over 11236 bars (1980-03-17..2026-06-24), above the 10000.00 ceiling"))
      ((symbol EHC) (entry_date 2014-09-04)
       (detail
        "median close 23.25 over 10013 bars (1986-09-24..2026-06-24); bar 2006-10-26 close 23.75 (+400.00% vs prior close 4.75) on volume 0"))
      ((symbol FIT) (entry_date 2019-11-26)
       (detail
        "median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0"))
      ((symbol FLO) (entry_date 2013-01-03)
       (detail
        "median close 18.16 over 11662 bars (1980-03-17..2026-06-24); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0"))
      ((symbol IHG) (entry_date 2012-06-19)
       (detail
        "median close 37.44 over 5839 bars (2003-04-08..2026-06-24); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0"))
      ((symbol NLC) (entry_date 2011-08-11)
       (detail
        "median close 18.62 over 2816 bars (2004-11-11..2018-01-30); bar 2015-04-15 close 15.54 (+8533.33% vs prior close 0.18) on volume 0"))
      ((symbol TNXP) (entry_date 2025-06-10)
       (detail
        "median close 0.16 over 3561 bars (2012-02-03..2026-06-24); bar 2012-05-10 close 0.00 (-99.99% vs prior close 1.50) on volume 0")))))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V21) (severity Expectation) (passed false) (n_violations 59)
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
      ((symbol TWI) (entry_date 2010-04-19)
       (detail
        "LONG installed_stop 10.3750 vs screener_proxy_stop 9.6600: 7.40% tighter > 3%"))
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
   ((id V22) (severity Expectation) (passed false) (n_violations 98)
    (n_skipped 100)
    (specimens
     (((symbol ACN) (entry_date 2006-10-13)
       (detail
        "no stop move for 27 weeks (2006-10-30..2007-05-11), 3 completed cycle(s) stalled; last: stop 28.66, candidate 25.44, ma 25.69, correction extreme 34.28 (extreme/ma 1.33)"))
      ((symbol ADNT) (entry_date 2020-02-21)
       (detail
        "no stop move for 31 weeks (2020-11-09..2021-06-18), 1 completed cycle(s) stalled; last: stop 25.38, candidate 20.66, ma 20.86, correction extreme 26.23 (extreme/ma 1.26)"))
      ((symbol ADSK) (entry_date 2003-09-12)
       (detail
        "no stop move for 49 weeks (2003-09-15..2004-08-25), 6 completed cycle(s) stalled; last: stop 16.66, candidate 16.39, ma 16.55, correction extreme 35.50 (extreme/ma 2.14)"))
      ((symbol ALJ) (entry_date 2012-08-10)
       (detail
        "no stop move for 18 weeks (2012-08-14..2012-12-21), 3 completed cycle(s) stalled; last: stop 10.67, candidate 9.88, ma 10.16, correction extreme 12.06 (extreme/ma 1.19)"))
      ((symbol ALSK) (entry_date 2006-03-10)
       (detail
        "no stop move for 49 weeks (2006-03-21..2007-03-02), 6 completed cycle(s) stalled; last: stop 10.37, candidate 8.72, ma 8.81, correction extreme 15.15 (extreme/ma 1.72)"))
      ((symbol ALSN) (entry_date 2013-09-27)
       (detail
        "no stop move for 32 weeks (2013-09-30..2014-05-16), 2 completed cycle(s) stalled; last: stop 23.34, candidate 20.81, ma 21.02, correction extreme 25.71 (extreme/ma 1.22)"))
      ((symbol AN) (entry_date 2020-07-31)
       (detail
        "no stop move for 16 weeks (2020-08-04..2020-11-24), 2 completed cycle(s) stalled; last: stop 48.84, candidate 48.78, ma 49.27, correction extreme 50.52 (extreme/ma 1.03)"))
      ((symbol APOG) (entry_date 2007-01-12)
       (detail
        "no stop move for 33 weeks (2007-01-17..2007-09-10), 3 completed cycle(s) stalled; last: stop 17.33, candidate 14.76, ma 14.91, correction extreme 22.90 (extreme/ma 1.54)"))
      ((symbol ARLP) (entry_date 2024-05-10)
       (detail
        "no stop move for 13 weeks (2024-05-31..2024-08-30), 1 completed cycle(s) stalled; last: stop 20.97, candidate 17.73, ma 17.91, correction extreme 23.17 (extreme/ma 1.29)"))
      ((symbol AUOTY) (entry_date 2003-07-18)
       (detail
        "no stop move for 17 weeks (2003-07-24..2003-11-21), 2 completed cycle(s) stalled; last: stop 8.38, candidate 3.88, ma 4.07, correction extreme 12.62 (extreme/ma 3.10)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed false) (n_violations 15)
    (n_skipped 0)
    (specimens
     (((symbol TCR) (entry_date 2000-12-18)
       (detail "filled 2000-12-18 after the 2000-12-15 screen read Bearish"))
      ((symbol SYK) (entry_date 2019-01-30)
       (detail "filled 2019-01-30 after the 2019-01-25 screen read Bearish"))
      ((symbol SPNT) (entry_date 2025-04-14)
       (detail "filled 2025-04-14 after the 2025-04-11 screen read Bearish"))
      ((symbol SGEN) (entry_date 2011-10-27)
       (detail "filled 2011-10-27 after the 2011-10-21 screen read Bearish"))
      ((symbol PPDI) (entry_date 2011-10-03)
       (detail "filled 2011-10-03 after the 2011-09-30 screen read Bearish"))
      ((symbol OFIX) (entry_date 2019-02-12)
       (detail "filled 2019-02-12 after the 2019-02-08 screen read Bearish"))
      ((symbol NRG) (entry_date 2006-07-28)
       (detail "filled 2006-07-28 after the 2006-07-21 screen read Bearish"))
      ((symbol NMK1) (entry_date 2000-11-15)
       (detail "filled 2000-11-15 after the 2000-11-10 screen read Bearish"))
      ((symbol NJR) (entry_date 2006-07-24)
       (detail "filled 2006-07-24 after the 2006-07-21 screen read Bearish"))
      ((symbol LIN) (entry_date 2019-02-15)
       (detail "filled 2019-02-15 after the 2019-02-08 screen read Bearish")))))))
 (audit_join ((matched 531) (total 531))))
