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
   ((id V7) (severity Invariant) (passed false) (n_violations 15)
    (n_skipped 0)
    (specimens
     (((symbol XERS) (entry_date 2024-02-14)
       (detail
        "Virgin_territory but only 295 weekly bars (< 520) before entry"))
      ((symbol WING) (entry_date 2017-08-08)
       (detail
        "Virgin_territory but only 113 weekly bars (< 520) before entry"))
      ((symbol VRSK) (entry_date 2017-02-22)
       (detail
        "Virgin_territory but only 385 weekly bars (< 520) before entry"))
      ((symbol VOYA) (entry_date 2017-11-29)
       (detail
        "Virgin_territory but only 239 weekly bars (< 520) before entry"))
      ((symbol UHAL) (entry_date 2015-02-03)
       (detail
        "Virgin_territory but only 318 weekly bars (< 520) before entry"))
      ((symbol TRNO) (entry_date 2017-04-11)
       (detail
        "Virgin_territory but only 374 weekly bars (< 520) before entry"))
      ((symbol NGVT) (entry_date 2017-10-05)
       (detail
        "Virgin_territory but only 74 weekly bars (< 520) before entry"))
      ((symbol MCHP) (entry_date 2015-02-13)
       (detail
        "Virgin_territory but only 319 weekly bars (< 520) before entry"))
      ((symbol HURN) (entry_date 2013-03-27)
       (detail
        "Virgin_territory but only 441 weekly bars (< 520) before entry"))
      ((symbol FN) (entry_date 2019-12-12)
       (detail
        "Virgin_territory but only 494 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 84)
    (n_skipped 59)
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
      ((symbol VSAT) (entry_date 2013-04-12)
       (detail "prior_top=49.67 within +25% of entry=49.17"))
      ((symbol VRTX) (entry_date 2014-07-30)
       (detail "prior_top=99.07 within +25% of entry=92.22"))
      ((symbol VICR) (entry_date 2021-07-27)
       (detail "prior_top=107.97 within +25% of entry=107.30"))
      ((symbol THO) (entry_date 2021-02-16)
       (detail "prior_top=130.65 within +25% of entry=123.20")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 5)
    (n_skipped 59)
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
   ((id V13) (severity Invariant) (passed false) (n_violations 4)
    (n_skipped 3)
    (specimens
     (((symbol QCOM) (entry_date 2026-05-18)
       (detail
        "no bar on entry_date 2026-05-18 (nearest earlier bar: 2026-04-10)"))
      ((symbol OKE) (entry_date 2013-09-18)
       (detail
        "entry_price=46.1500 outside 2013-09-18 bar [51.8900, 54.5300]"))
      ((symbol NEOG) (entry_date 2017-09-05)
       (detail
        "entry_price=52.4700 outside 2017-09-05 bar [68.8760, 70.4406]"))
      ((symbol MAR) (entry_date 2025-12-15)
       (detail
        "no bar on exit_date 2026-05-18 (nearest earlier bar: 2026-04-10)")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 13)
    (n_skipped 1)
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
      ((symbol GATX) (entry_date 2014-10-09)
       (detail
        "entry bar 2014-10-09 open=56.7000 low=55.2723 close=55.4300 vs stop=52.8780, exit=54.6500"))
      ((symbol FLNA) (entry_date 2020-10-12)
       (detail
        "entry bar 2020-10-12 open=11.8900 low=11.0700 close=11.4300 vs stop=10.8755, exit=10.8100"))
      ((symbol EXTR) (entry_date 2022-01-21)
       (detail
        "entry bar 2022-01-21 open=12.8100 low=12.4900 close=12.4900 vs stop=12.1943, exit=12.0900"))
      ((symbol CVNA) (entry_date 2025-12-31)
       (detail
        "entry bar 2025-12-31 open=429.5500 low=421.8550 close=422.0200 vs stop=406.8887, exit=406.7000"))
      ((symbol CRON) (entry_date 2018-09-24)
       (detail
        "entry bar 2018-09-24 open=11.8000 low=11.6500 close=11.8600 vs stop=11.7871, exit=11.7100")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 0)
    (specimens
     (((symbol QCOM) (entry_date 2026-05-18)
       (detail
        "entry filled 2026-05-18 but last bar is 2026-04-10 (38 days stale)")))))
   ((id V18) (severity Expectation) (passed false) (n_violations 4)
    (n_skipped 0)
    (specimens
     (((symbol ANIP) (entry_date 2024-03-11)
       (detail
        "median close 26.24 over 6160 bars (2001-07-24..2026-06-24); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0"))
      ((symbol EHC) (entry_date 2014-09-04)
       (detail
        "median close 23.25 over 10013 bars (1986-09-24..2026-06-24); bar 2006-10-26 close 23.75 (+400.00% vs prior close 4.75) on volume 0"))
      ((symbol FIT) (entry_date 2018-06-18)
       (detail
        "median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0"))
      ((symbol TNXP) (entry_date 2025-06-10)
       (detail
        "median close 0.16 over 3561 bars (2012-02-03..2026-06-24); bar 2012-05-10 close 0.00 (-99.99% vs prior close 1.50) on volume 0")))))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V21) (severity Expectation) (passed false) (n_violations 43)
    (n_skipped 0)
    (specimens
     (((symbol WIFI) (entry_date 2018-11-02)
       (detail
        "LONG installed_stop 27.8750 vs screener_proxy_stop 26.2016: 6.39% tighter > 3%"))
      ((symbol WD) (entry_date 2021-03-09)
       (detail
        "LONG installed_stop 91.2672 vs screener_proxy_stop 87.6852: 4.09% tighter > 3%"))
      ((symbol VGR) (entry_date 2021-12-06)
       (detail
        "LONG installed_stop 10.3471 vs screener_proxy_stop 10.0280: 3.18% tighter > 3%"))
      ((symbol UPWK) (entry_date 2025-09-30)
       (detail
        "LONG installed_stop 17.8750 vs screener_proxy_stop 16.7716: 6.58% tighter > 3%"))
      ((symbol TDS) (entry_date 2023-09-11)
       (detail
        "LONG installed_stop 17.1648 vs screener_proxy_stop 16.0264: 7.10% tighter > 3%"))
      ((symbol SSTK) (entry_date 2020-09-04)
       (detail
        "LONG installed_stop 44.4864 vs screener_proxy_stop 42.5132: 4.64% tighter > 3%"))
      ((symbol SPSC) (entry_date 2019-02-28)
       (detail
        "LONG installed_stop 98.2368 vs screener_proxy_stop 93.0856: 5.53% tighter > 3%"))
      ((symbol PYX) (entry_date 2018-10-22)
       (detail
        "LONG installed_stop 29.3750 vs screener_proxy_stop 28.3820: 3.50% tighter > 3%"))
      ((symbol PKG) (entry_date 2023-08-21)
       (detail
        "LONG installed_stop 139.8912 vs screener_proxy_stop 135.2124: 3.46% tighter > 3%"))
      ((symbol PEGA) (entry_date 2016-10-31)
       (detail
        "LONG installed_stop 28.8480 vs screener_proxy_stop 27.9496: 3.21% tighter > 3%")))))
   ((id V22) (severity Expectation) (passed false) (n_violations 44)
    (n_skipped 68)
    (specimens
     (((symbol ALSN) (entry_date 2013-09-27)
       (detail
        "no stop move for 32 weeks (2013-09-30..2014-05-16), 2 completed cycle(s) stalled; last: stop 23.34, candidate 20.81, ma 21.02, correction extreme 25.71 (extreme/ma 1.22)"))
      ((symbol AN) (entry_date 2020-07-31)
       (detail
        "no stop move for 16 weeks (2020-08-04..2020-11-24), 2 completed cycle(s) stalled; last: stop 48.84, candidate 48.78, ma 49.27, correction extreme 50.52 (extreme/ma 1.03)"))
      ((symbol ATNI) (entry_date 2013-02-01)
       (detail
        "no stop move for 24 weeks (2013-02-22..2013-08-09), 2 completed cycle(s) stalled; last: stop 39.93, candidate 32.84, ma 33.17, correction extreme 46.55 (extreme/ma 1.40)"))
      ((symbol AVGO) (entry_date 2013-08-30)
       (detail
        "no stop move for 99 weeks (2013-09-10..2015-08-10), 11 completed cycle(s) stalled; last: stop 34.32, candidate 9.14, ma 9.23, correction extreme 114.56 (extreme/ma 12.41)"))
      ((symbol BBWI) (entry_date 2020-07-31)
       (detail
        "no stop move for 31 weeks (2020-08-05..2021-03-12), 7 completed cycle(s) stalled; last: stop 22.92, candidate 20.38, ma 20.76, correction extreme 36.10 (extreme/ma 1.74)"))
      ((symbol BC) (entry_date 2013-08-16)
       (detail
        "no stop move for 22 weeks (2013-08-22..2014-01-24), 2 completed cycle(s) stalled; last: stop 34.73, candidate 29.88, ma 30.36, correction extreme 39.03 (extreme/ma 1.29)"))
      ((symbol CLX) (entry_date 2020-03-13)
       (detail
        "no stop move for 16 weeks (2020-03-16..2020-07-10), 1 completed cycle(s) stalled; last: stop 150.41, candidate 137.88, ma 139.40, correction extreme 161.11 (extreme/ma 1.16)"))
      ((symbol CVNA) (entry_date 2024-07-05)
       (detail
        "no stop move for 33 weeks (2024-07-08..2025-02-28), 4 completed cycle(s) stalled; last: stop 116.17, candidate 25.38, ma 25.76, correction extreme 124.39 (extreme/ma 4.83)"))
      ((symbol DECK) (entry_date 2014-07-18)
       (detail
        "no stop move for 13 weeks (2014-07-25..2014-10-27), 1 completed cycle(s) stalled; last: stop 77.22, candidate 14.25, ma 14.39, correction extreme 87.35 (extreme/ma 6.07)"))
      ((symbol DKS) (entry_date 2019-10-04)
       (detail
        "no stop move for 14 weeks (2019-11-07..2020-02-14), 1 completed cycle(s) stalled; last: stop 36.34, candidate 31.73, ma 32.06, correction extreme 38.81 (extreme/ma 1.21)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed false) (n_violations 5)
    (n_skipped 0)
    (specimens
     (((symbol SYK) (entry_date 2019-01-30)
       (detail "filled 2019-01-30 after the 2019-01-25 screen read Bearish"))
      ((symbol SPNT) (entry_date 2025-04-14)
       (detail "filled 2025-04-14 after the 2025-04-11 screen read Bearish"))
      ((symbol OFIX) (entry_date 2019-02-12)
       (detail "filled 2019-02-12 after the 2019-02-08 screen read Bearish"))
      ((symbol LIN) (entry_date 2019-02-15)
       (detail "filled 2019-02-15 after the 2019-02-08 screen read Bearish"))
      ((symbol ISEE) (entry_date 2022-09-30)
       (detail "filled 2022-09-30 after the 2022-09-23 screen read Bearish")))))))
 (audit_join ((matched 340) (total 340))))
