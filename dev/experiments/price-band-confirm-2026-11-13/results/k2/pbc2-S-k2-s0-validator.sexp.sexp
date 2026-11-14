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
   ((id V7) (severity Invariant) (passed false) (n_violations 66)
    (n_skipped 0)
    (specimens
     (((symbol VVV) (entry_date 2024-02-08)
       (detail
        "Virgin_territory but only 385 weekly bars (< 520) before entry"))
      ((symbol VRSK) (entry_date 2017-02-22)
       (detail
        "Virgin_territory but only 385 weekly bars (< 520) before entry"))
      ((symbol VOYA) (entry_date 2017-11-29)
       (detail
        "Virgin_territory but only 239 weekly bars (< 520) before entry"))
      ((symbol ULTA) (entry_date 2017-03-06)
       (detail
        "Virgin_territory but only 427 weekly bars (< 520) before entry"))
      ((symbol TRW1) (entry_date 2000-03-27)
       (detail
        "Virgin_territory but only 117 weekly bars (< 520) before entry"))
      ((symbol TRV) (entry_date 2016-06-30)
       (detail
        "Virgin_territory but only 391 weekly bars (< 520) before entry"))
      ((symbol TFC) (entry_date 2006-09-25)
       (detail
        "Virgin_territory but only 0 weekly bars (< 520) before entry"))
      ((symbol TEVA) (entry_date 2004-06-16)
       (detail
        "Virgin_territory but only 0 weekly bars (< 520) before entry"))
      ((symbol SPGI) (entry_date 2016-05-24)
       (detail
        "Virgin_territory but only 386 weekly bars (< 520) before entry"))
      ((symbol SK) (entry_date 2010-06-01)
       (detail
        "Virgin_territory but only 241 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 88)
    (n_skipped 245)
    (specimens
     (((symbol ZS) (entry_date 2020-10-29)
       (detail "prior_top=154.85 within +25% of entry=142.28"))
      ((symbol ZD) (entry_date 2021-06-07)
       (detail "prior_top=111.23 within +25% of entry=110.55"))
      ((symbol YETI) (entry_date 2021-07-06)
       (detail "prior_top=94.97 within +25% of entry=92.81"))
      ((symbol X) (entry_date 2023-08-21)
       (detail "prior_top=37.63 within +25% of entry=31.79"))
      ((symbol WOLF_old2) (entry_date 2021-11-22)
       (detail "prior_top=139.55 within +25% of entry=133.00"))
      ((symbol VRTX) (entry_date 2012-06-28)
       (detail "prior_top=64.85 within +25% of entry=54.67"))
      ((symbol VRTX) (entry_date 2014-07-30)
       (detail "prior_top=99.07 within +25% of entry=92.22"))
      ((symbol VLO) (entry_date 2022-02-01)
       (detail "prior_top=90.84 within +25% of entry=85.41"))
      ((symbol TWX1) (entry_date 2000-01-28)
       (detail "prior_top=91.12 within +25% of entry=80.60"))
      ((symbol THO) (entry_date 2021-02-16)
       (detail "prior_top=130.65 within +25% of entry=123.20")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 3)
    (n_skipped 245)
    (specimens
     (((symbol IREN) (entry_date 2025-07-15)
       (detail "entry_wk_close=17.94 > prior=10.47 (spike>60%)"))
      ((symbol HOFF) (entry_date 2000-05-17)
       (detail "entry_wk_close=262.50 > prior=157.81 (spike>60%)"))
      ((symbol GMGC) (entry_date 2000-01-24)
       (detail "entry_wk_close=103.69 > prior=54.25 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V13) (severity Invariant) (passed false) (n_violations 108)
    (n_skipped 13)
    (specimens
     (((symbol ZION) (entry_date 2004-10-21)
       (detail "no bar on entry_date 2004-10-21 (nearest earlier bar: none)"))
      ((symbol WYNN) (entry_date 2005-01-03)
       (detail "no bar on entry_date 2005-01-03 (nearest earlier bar: none)"))
      ((symbol WRB) (entry_date 2003-08-18)
       (detail "no bar on entry_date 2003-08-18 (nearest earlier bar: none)"))
      ((symbol WDC) (entry_date 2003-10-06)
       (detail "no bar on entry_date 2003-10-06 (nearest earlier bar: none)"))
      ((symbol VTR) (entry_date 2011-04-28)
       (detail
        "entry_price=43.6000 outside 2011-04-28 bar [56.3200, 57.0800]"))
      ((symbol TJX) (entry_date 2003-11-24)
       (detail "no bar on entry_date 2003-11-24 (nearest earlier bar: none)"))
      ((symbol TFC) (entry_date 2006-09-25)
       (detail "no bar on entry_date 2006-09-25 (nearest earlier bar: none)"))
      ((symbol TEVA) (entry_date 2004-06-16)
       (detail "no bar on entry_date 2004-06-16 (nearest earlier bar: none)"))
      ((symbol STT) (entry_date 2000-04-10)
       (detail "no bar on entry_date 2000-04-10 (nearest earlier bar: none)"))
      ((symbol SNPS) (entry_date 2003-09-16)
       (detail "no bar on entry_date 2003-09-16 (nearest earlier bar: none)")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 14)
    (n_skipped 45)
    (specimens
     (((symbol TER) (entry_date 2020-03-12)
       (detail
        "entry bar 2020-03-12 open=50.8000 low=49.6000 close=49.8300 vs stop=47.8942, exit=48.6800"))
      ((symbol TECK) (entry_date 2022-04-25)
       (detail
        "entry bar 2022-04-25 open=36.0000 low=34.1400 close=35.8800 vs stop=35.1252, exit=35.0700"))
      ((symbol STX) (entry_date 2018-02-05)
       (detail
        "entry bar 2018-02-05 open=51.2600 low=49.5100 close=49.6500 vs stop=49.3224, exit=48.0800"))
      ((symbol RH) (entry_date 2025-02-11)
       (detail
        "entry bar 2025-02-11 open=399.7100 low=377.0400 close=384.4200 vs stop=366.8941, exit=366.5700"))
      ((symbol OKLO) (entry_date 2025-06-18)
       (detail
        "entry bar 2025-06-18 open=63.2650 low=59.6200 close=62.0200 vs stop=58.1745, exit=58.1500"))
      ((symbol MTCH) (entry_date 2019-09-10)
       (detail
        "entry bar 2019-09-10 open=267.0275 low=263.0702 close=264.5411 vs stop=261.7962, exit=261.7400"))
      ((symbol GFI) (entry_date 2024-04-29)
       (detail
        "entry bar 2024-04-29 open=17.7600 low=17.6000 close=17.8900 vs stop=16.3743, exit=16.1600"))
      ((symbol DG) (entry_date 2012-12-11)
       (detail
        "entry bar 2012-12-11 open=45.6500 low=42.7700 close=42.9400 vs stop=41.4573, exit=42.2600"))
      ((symbol DECK) (entry_date 2018-11-19)
       (detail
        "entry bar 2018-11-19 open=129.9402 low=123.0300 close=123.3798 vs stop=119.4512, exit=119.3900"))
      ((symbol CVNA) (entry_date 2025-12-31)
       (detail
        "entry bar 2025-12-31 open=429.5500 low=421.8550 close=422.0200 vs stop=406.8887, exit=406.7000")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 0)
    (specimens
     (((symbol MAY) (entry_date 2005-03-02)
       (detail
        "stale_force_exit exit 2005-09-05 (entry 2005-03-02 @ 36.72, exit @ 39.75)")))))
   ((id V17) (severity Expectation) (passed false) (n_violations 3)
    (n_skipped 95)
    (specimens
     (((symbol QCOM) (entry_date 2026-05-18)
       (detail
        "entry filled 2026-05-18 but last bar is 2026-04-10 (38 days stale)"))
      ((symbol PBR) (entry_date 2026-02-09)
       (detail
        "entry filled 2026-02-09 but last bar is 2025-05-16 (269 days stale)"))
      ((symbol NVS) (entry_date 2025-12-03)
       (detail
        "entry filled 2025-12-03 but last bar is 2025-05-16 (201 days stale)")))))
   ((id V18) (severity Expectation) (passed false) (n_violations 5)
    (n_skipped 0)
    (specimens
     (((symbol AUY) (entry_date 2011-08-08)
       (detail
        "median close 5.11 over 5183 bars (2001-06-22..2023-03-31); bar 2001-10-04 close 1.67 (+1571.60% vs prior close 0.10) on volume 0"))
      ((symbol BRK-A) (entry_date 2017-08-03)
       (detail
        "median close 83025.10 over 11230 bars (1980-03-17..2026-06-15), above the 10000.00 ceiling"))
      ((symbol ISA) (entry_date 2019-03-14)
       (detail
        "median close 7360.00 over 5664 bars (1997-12-31..2020-07-07); bar 2001-08-22 close 0.05 (-100.00% vs prior close 1070.00) on volume 0"))
      ((symbol PPP) (entry_date 2005-06-13)
       (detail
        "median close 5.31 over 2978 bars (2003-09-10..2017-08-14); bar 2009-12-14 close 4.40 (-92.67% vs prior close 60.00) on volume 0"))
      ((symbol SK) (entry_date 2010-06-01)
       (detail
        "median close 806.09 over 2776 bars (2005-10-18..2016-10-26); bar 2016-07-26 close 72.37 (-91.87% vs prior close 890.00) on volume 0")))))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V21) (severity Expectation) (passed false) (n_violations 85)
    (n_skipped 0)
    (specimens
     (((symbol WYNN) (entry_date 2005-01-03)
       (detail
        "LONG installed_stop 63.2256 vs screener_proxy_stop 58.8524: 7.43% tighter > 3%"))
      ((symbol WY) (entry_date 2010-01-21)
       (detail
        "LONG installed_stop 15.8750 vs screener_proxy_stop 15.0696: 5.34% tighter > 3%"))
      ((symbol VVUS) (entry_date 2008-06-18)
       (detail
        "LONG installed_stop 6.3750 vs screener_proxy_stop 6.0536: 5.31% tighter > 3%"))
      ((symbol TYC) (entry_date 2011-06-01)
       (detail
        "LONG installed_stop 45.3750 vs screener_proxy_stop 43.7644: 3.68% tighter > 3%"))
      ((symbol TSLA) (entry_date 2013-04-09)
       (detail
        "LONG installed_stop 38.3750 vs screener_proxy_stop 36.9840: 3.76% tighter > 3%"))
      ((symbol TRN) (entry_date 2014-07-30)
       (detail
        "LONG installed_stop 33.7002 vs screener_proxy_stop 31.6572: 6.45% tighter > 3%"))
      ((symbol TNDM) (entry_date 2020-07-24)
       (detail
        "LONG installed_stop 88.2528 vs screener_proxy_stop 85.4036: 3.34% tighter > 3%"))
      ((symbol TER) (entry_date 2020-03-12)
       (detail
        "LONG installed_stop 47.8944 vs screener_proxy_stop 46.0736: 3.95% tighter > 3%"))
      ((symbol TECK) (entry_date 2022-04-25)
       (detail
        "LONG installed_stop 35.1264 vs screener_proxy_stop 32.7060: 7.40% tighter > 3%"))
      ((symbol TEAM) (entry_date 2018-10-19)
       (detail
        "LONG installed_stop 66.3648 vs screener_proxy_stop 63.5628: 4.41% tighter > 3%")))))
   ((id V22) (severity Expectation) (passed false) (n_violations 88)
    (n_skipped 135)
    (specimens
     (((symbol ACN) (entry_date 2006-10-13)
       (detail
        "no stop move for 27 weeks (2006-10-30..2007-05-11), 3 completed cycle(s) stalled; last: stop 28.66, candidate 25.44, ma 25.69, correction extreme 34.28 (extreme/ma 1.33)"))
      ((symbol ADSK) (entry_date 2003-09-12)
       (detail
        "no stop move for 49 weeks (2003-09-15..2004-08-25), 6 completed cycle(s) stalled; last: stop 16.66, candidate 16.39, ma 16.55, correction extreme 35.50 (extreme/ma 2.14)"))
      ((symbol AMAT) (entry_date 2007-06-22)
       (detail
        "no stop move for 17 weeks (2007-06-25..2007-10-25), 1 completed cycle(s) stalled; last: stop 17.64, candidate 14.45, ma 14.60, correction extreme 19.60 (extreme/ma 1.34)"))
      ((symbol ANET) (entry_date 2023-02-24)
       (detail
        "no stop move for 14 weeks (2023-03-06..2023-06-16), 1 completed cycle(s) stalled; last: stop 127.22, candidate 35.88, ma 36.48, correction extreme 131.68 (extreme/ma 3.61)"))
      ((symbol APD) (entry_date 2013-12-27)
       (detail
        "no stop move for 14 weeks (2014-02-13..2014-05-23), 1 completed cycle(s) stalled; last: stop 98.14, candidate 75.33, ma 76.09, correction extreme 110.61 (extreme/ma 1.45)"))
      ((symbol APH) (entry_date 2023-10-06)
       (detail
        "no stop move for 29 weeks (2023-11-29..2024-06-21), 3 completed cycle(s) stalled; last: stop 77.93, candidate 54.92, ma 55.47, correction extreme 118.40 (extreme/ma 2.13)"))
      ((symbol ARCH) (entry_date 2005-02-11)
       (detail
        "no stop move for 23 weeks (2005-02-16..2005-07-28), 4 completed cycle(s) stalled; last: stop 16.88, candidate 16.88, ma 17.24, correction extreme 24.60 (extreme/ma 1.43)"))
      ((symbol AUY) (entry_date 2011-08-05)
       (detail
        "no stop move for 15 weeks (2011-08-08..2011-11-25), 1 completed cycle(s) stalled; last: stop 12.18, candidate 10.89, ma 11.00, correction extreme 14.47 (extreme/ma 1.32)"))
      ((symbol AVGO) (entry_date 2023-07-21)
       (detail
        "no stop move for 50 weeks (2023-08-11..2024-07-26), 6 completed cycle(s) stalled; last: stop 745.32, candidate 126.73, ma 128.01, correction extreme 1302.53 (extreme/ma 10.18)"))
      ((symbol AVGO) (entry_date 2013-08-30)
       (detail
        "no stop move for 99 weeks (2013-09-10..2015-08-10), 11 completed cycle(s) stalled; last: stop 34.32, candidate 9.14, ma 9.23, correction extreme 114.56 (extreme/ma 12.41)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed false) (n_violations 15)
    (n_skipped 0)
    (specimens
     (((symbol WTW) (entry_date 2019-02-01)
       (detail "filled 2019-02-01 after the 2019-01-25 screen read Bearish"))
      ((symbol SYK) (entry_date 2019-01-30)
       (detail "filled 2019-01-30 after the 2019-01-25 screen read Bearish"))
      ((symbol PM) (entry_date 2011-10-27)
       (detail "filled 2011-10-27 after the 2011-10-21 screen read Bearish"))
      ((symbol NRG) (entry_date 2006-07-28)
       (detail "filled 2006-07-28 after the 2006-07-21 screen read Bearish"))
      ((symbol NOK) (entry_date 2008-01-22)
       (detail "filled 2008-01-22 after the 2008-01-18 screen read Bearish"))
      ((symbol MDLZ) (entry_date 2011-10-27)
       (detail "filled 2011-10-27 after the 2011-10-21 screen read Bearish"))
      ((symbol LIN) (entry_date 2019-02-15)
       (detail "filled 2019-02-15 after the 2019-02-08 screen read Bearish"))
      ((symbol HRB) (entry_date 2015-09-09)
       (detail "filled 2015-09-09 after the 2015-09-04 screen read Bearish"))
      ((symbol HOFF) (entry_date 2000-05-17)
       (detail "filled 2000-05-17 after the 2000-05-12 screen read Bearish"))
      ((symbol HAL) (entry_date 2022-06-17)
       (detail "filled 2022-06-17 after the 2022-06-10 screen read Bearish")))))))
 (audit_join ((matched 648) (total 648))))
