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
    (skip_reason
     "share-class map: /workspaces/trading-1/.claude/worktrees/sweep-td/trading/test_data/share_classes.sexp"))
   ((id V7) (severity Invariant) (passed false) (n_violations 20)
    (n_skipped 0)
    (specimens
     (((symbol XERS) (entry_date 2024-02-14)
       (detail
        "Virgin_territory but only 295 weekly bars (< 520) before entry"))
      ((symbol WING) (entry_date 2017-08-08)
       (detail
        "Virgin_territory but only 113 weekly bars (< 520) before entry"))
      ((symbol WDR) (entry_date 2007-07-13)
       (detail
        "Virgin_territory but only 488 weekly bars (< 520) before entry"))
      ((symbol VRSK) (entry_date 2017-02-22)
       (detail
        "Virgin_territory but only 385 weekly bars (< 520) before entry"))
      ((symbol TRW1) (entry_date 2000-03-27)
       (detail
        "Virgin_territory but only 117 weekly bars (< 520) before entry"))
      ((symbol POM_old) (entry_date 2006-07-26)
       (detail
        "Virgin_territory but only 447 weekly bars (< 520) before entry"))
      ((symbol PBF) (entry_date 2015-03-25)
       (detail
        "Virgin_territory but only 119 weekly bars (< 520) before entry"))
      ((symbol NVS) (entry_date 2005-10-03)
       (detail
        "Virgin_territory but only 465 weekly bars (< 520) before entry"))
      ((symbol NABZY) (entry_date 2006-01-31)
       (detail
        "Virgin_territory but only 422 weekly bars (< 520) before entry"))
      ((symbol MSTR) (entry_date 2004-11-03)
       (detail
        "Virgin_territory but only 334 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 112)
    (n_skipped 183)
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
      ((symbol VICR) (entry_date 2021-07-27)
       (detail "prior_top=107.97 within +25% of entry=107.30"))
      ((symbol VAS) (entry_date 2004-02-02)
       (detail "prior_top=24.49 within +25% of entry=23.76"))
      ((symbol USB) (entry_date 2024-08-28)
       (detail "prior_top=51.66 within +25% of entry=46.10"))
      ((symbol URBN) (entry_date 2026-01-06)
       (detail "prior_top=81.84 within +25% of entry=81.27")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 5)
    (n_skipped 183)
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
   ((id V12) (severity Invariant) (passed false) (n_violations 24)
    (n_skipped 0)
    (specimens
     (((symbol VIRT) (entry_date 2021-03-18)
       (detail
        "installed_stop=24.8750 vs fill=29.3000 -> dist=0.1510 > gate=0.1500"))
      ((symbol TRMB) (entry_date 2003-11-24)
       (detail
        "installed_stop=25.8750 vs fill=19.6700 -> dist=0.3155 > gate=0.1500"))
      ((symbol TLK) (entry_date 2012-07-17)
       (detail
        "installed_stop=31.7760 vs fill=37.7000 -> dist=0.1571 > gate=0.1500"))
      ((symbol SNX) (entry_date 2020-11-09)
       (detail
        "installed_stop=136.8750 vs fill=77.6400 -> dist=0.7629 > gate=0.1500"))
      ((symbol SNEX) (entry_date 2025-01-14)
       (detail
        "installed_stop=87.2355 vs fill=68.1400 -> dist=0.2802 > gate=0.1500"))
      ((symbol POM_old) (entry_date 2006-07-26)
       (detail
        "installed_stop=20.9184 vs fill=24.6400 -> dist=0.1510 > gate=0.1500"))
      ((symbol PH) (entry_date 2007-04-04)
       (detail
        "installed_stop=77.1361 vs fill=58.9800 -> dist=0.3078 > gate=0.1500"))
      ((symbol NEOG) (entry_date 2017-09-05)
       (detail
        "installed_stop=60.8750 vs fill=52.4700 -> dist=0.1602 > gate=0.1500"))
      ((symbol MNT) (entry_date 2005-04-15)
       (detail
        "installed_stop=31.3920 vs fill=37.4500 -> dist=0.1618 > gate=0.1500"))
      ((symbol MCHP) (entry_date 2015-02-13)
       (detail
        "installed_stop=42.9888 vs fill=51.3000 -> dist=0.1620 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 22)
    (n_skipped 9)
    (specimens
     (((symbol WTRG) (entry_date 2003-11-21)
       (detail
        "entry_price=20.1800 outside 2003-11-21 bar [24.9200, 25.2300]"))
      ((symbol SHOO) (entry_date 2016-11-28)
       (detail
        "exit_price=34.7500 outside 2017-01-03 bar [34.7501, 36.2000]"))
      ((symbol SGNT) (entry_date 2014-07-14)
       (detail
        "exit_price=23.7300 outside 2014-08-05 bar [23.7350, 24.6700]"))
      ((symbol PPDI) (entry_date 2011-10-03)
       (detail
        "no bar on exit_date 2011-12-06 (nearest earlier bar: 2011-12-05)"))
      ((symbol PH) (entry_date 2007-04-04)
       (detail
        "entry_price=58.9800 outside 2007-04-04 bar [87.3701, 88.6500]"))
      ((symbol OPSW) (entry_date 2007-06-29)
       (detail
        "no bar on exit_date 2007-09-21 (nearest earlier bar: 2007-09-20)"))
      ((symbol OKE) (entry_date 2013-09-18)
       (detail
        "entry_price=46.1500 outside 2013-09-18 bar [51.8900, 54.5300]"))
      ((symbol NUAN) (entry_date 2010-12-10)
       (detail
        "exit_price=17.9300 outside 2011-03-07 bar [17.1166, 17.9259]"))
      ((symbol NTTYY) (entry_date 2017-11-07)
       (detail
        "entry_price=50.4200 outside 2017-11-07 bar [50.4190, 50.4190]"))
      ((symbol NTO) (entry_date 2007-10-01)
       (detail
        "no bar on exit_date 2007-10-22 (nearest earlier bar: 2007-10-15)")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 18)
    (n_skipped 0)
    (specimens
     (((symbol VION) (entry_date 2000-04-14)
       (detail
        "entry bar 2000-04-14 open=100.0000 low=76.8750 close=82.5000 vs stop=75.3697, exit=75.3200"))
      ((symbol TDS) (entry_date 2023-09-11)
       (detail
        "entry bar 2023-09-11 open=17.8500 low=17.3700 close=17.6500 vs stop=17.1658, exit=17.0600"))
      ((symbol SDA) (entry_date 2023-07-12)
       (detail
        "entry bar 2023-07-12 open=14.1500 low=11.5500 close=11.7000 vs stop=10.4919, exit=10.4400"))
      ((symbol QCOM) (entry_date 2026-05-18)
       (detail
        "entry bar 2026-05-18 open=206.7700 low=193.5800 close=203.6400 vs stop=191.2040, exit=191.1600"))
      ((symbol PUMP) (entry_date 2025-11-12)
       (detail
        "entry bar 2025-11-12 open=11.0100 low=10.1850 close=10.4300 vs stop=9.8372, exit=9.7100"))
      ((symbol ORA) (entry_date 2007-08-13)
       (detail
        "entry bar 2007-08-13 open=44.3000 low=40.3600 close=41.9300 vs stop=40.3780, exit=40.3400"))
      ((symbol MLNX) (entry_date 2018-11-19)
       (detail
        "entry bar 2018-11-19 open=92.8500 low=91.1200 close=91.2800 vs stop=85.8773, exit=85.8500"))
      ((symbol FSH) (entry_date 2005-11-15)
       (detail
        "entry bar 2005-11-15 open=65.0000 low=64.8200 close=65.5000 vs stop=58.4590, exit=64.1500"))
      ((symbol FLNA) (entry_date 2020-10-12)
       (detail
        "entry bar 2020-10-12 open=11.8900 low=11.0700 close=11.4300 vs stop=10.8755, exit=10.8100"))
      ((symbol EXTR) (entry_date 2022-01-21)
       (detail
        "entry bar 2022-01-21 open=12.8100 low=12.4900 close=12.4900 vs stop=12.1943, exit=12.0900")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed false) (n_violations 2)
    (n_skipped 0)
    (specimens
     (((symbol NTO) (entry_date 2007-10-01)
       (detail
        "stale_force_exit exit 2007-10-22 (entry 2007-10-01 @ 6.34, exit @ 7.64)"))
      ((symbol NLC) (entry_date 2011-08-15)
       (detail
        "stale_force_exit exit 2011-12-06 (entry 2011-08-15 @ 33.17, exit @ 38.80)")))))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 6)
    (n_skipped 1)
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
   ((id V21) (severity Expectation) (passed false) (n_violations 66)
    (n_skipped 0)
    (specimens
     (((symbol VMC) (entry_date 2016-11-28)
       (detail
        "LONG installed_stop 121.2960 vs screener_proxy_stop 117.6128: 3.13% tighter > 3%"))
      ((symbol VION) (entry_date 2000-04-14)
       (detail
        "LONG installed_stop 75.3750 vs screener_proxy_stop 70.4996: 6.92% tighter > 3%"))
      ((symbol TROX) (entry_date 2014-09-19)
       (detail
        "LONG installed_stop 25.8048 vs screener_proxy_stop 24.9872: 3.27% tighter > 3%"))
      ((symbol TREX) (entry_date 2004-08-16)
       (detail
        "LONG installed_stop 39.3750 vs screener_proxy_stop 37.9224: 3.83% tighter > 3%"))
      ((symbol TDS) (entry_date 2023-09-11)
       (detail
        "LONG installed_stop 17.1648 vs screener_proxy_stop 16.0264: 7.10% tighter > 3%"))
      ((symbol SYY) (entry_date 2013-12-16)
       (detail
        "LONG installed_stop 34.4928 vs screener_proxy_stop 33.3316: 3.48% tighter > 3%"))
      ((symbol STK1) (entry_date 2004-01-21)
       (detail
        "LONG installed_stop 27.4848 vs screener_proxy_stop 25.8796: 6.20% tighter > 3%"))
      ((symbol SSTK) (entry_date 2020-09-04)
       (detail
        "LONG installed_stop 44.4864 vs screener_proxy_stop 42.5132: 4.64% tighter > 3%"))
      ((symbol SNBR) (entry_date 2011-11-10)
       (detail
        "LONG installed_stop 18.8160 vs screener_proxy_stop 17.7836: 5.81% tighter > 3%"))
      ((symbol SIMO) (entry_date 2022-01-24)
       (detail
        "LONG installed_stop 79.4880 vs screener_proxy_stop 75.6976: 5.01% tighter > 3%")))))
   ((id V22) (severity Expectation) (passed false) (n_violations 100)
    (n_skipped 110)
    (specimens
     (((symbol ACN) (entry_date 2006-10-13)
       (detail
        "no stop move for 27 weeks (2006-10-30..2007-05-11), 3 completed cycle(s) stalled; last: stop 28.66, candidate 25.44, ma 25.69, correction extreme 34.28 (extreme/ma 1.33)"))
      ((symbol ADSK) (entry_date 2003-09-12)
       (detail
        "no stop move for 49 weeks (2003-09-15..2004-08-25), 6 completed cycle(s) stalled; last: stop 16.66, candidate 16.39, ma 16.55, correction extreme 35.50 (extreme/ma 2.14)"))
      ((symbol AIN) (entry_date 2005-02-04)
       (detail
        "no stop move for 23 weeks (2005-07-12..2005-12-23), 2 completed cycle(s) stalled; last: stop 29.71, candidate 23.88, ma 24.31, correction extreme 34.60 (extreme/ma 1.42)"))
      ((symbol ALSK) (entry_date 2006-03-10)
       (detail
        "no stop move for 49 weeks (2006-03-21..2007-03-02), 6 completed cycle(s) stalled; last: stop 10.37, candidate 8.72, ma 8.81, correction extreme 15.15 (extreme/ma 1.72)"))
      ((symbol AN) (entry_date 2020-07-31)
       (detail
        "no stop move for 16 weeks (2020-08-04..2020-11-24), 2 completed cycle(s) stalled; last: stop 48.84, candidate 48.78, ma 49.27, correction extreme 50.52 (extreme/ma 1.03)"))
      ((symbol APOG) (entry_date 2007-01-12)
       (detail
        "no stop move for 33 weeks (2007-01-17..2007-09-10), 3 completed cycle(s) stalled; last: stop 17.33, candidate 14.76, ma 14.91, correction extreme 22.90 (extreme/ma 1.54)"))
      ((symbol ARCH) (entry_date 2005-02-11)
       (detail
        "no stop move for 23 weeks (2005-02-16..2005-07-28), 4 completed cycle(s) stalled; last: stop 16.88, candidate 16.88, ma 17.24, correction extreme 24.60 (extreme/ma 1.43)"))
      ((symbol ARLP) (entry_date 2024-05-10)
       (detail
        "no stop move for 13 weeks (2024-05-31..2024-08-30), 1 completed cycle(s) stalled; last: stop 20.97, candidate 17.73, ma 17.91, correction extreme 23.17 (extreme/ma 1.29)"))
      ((symbol AUOTY) (entry_date 2003-07-18)
       (detail
        "no stop move for 17 weeks (2003-07-24..2003-11-21), 2 completed cycle(s) stalled; last: stop 8.38, candidate 3.88, ma 4.07, correction extreme 12.62 (extreme/ma 3.10)"))
      ((symbol AVGO) (entry_date 2013-08-30)
       (detail
        "no stop move for 99 weeks (2013-09-10..2015-08-10), 11 completed cycle(s) stalled; last: stop 34.32, candidate 9.14, ma 9.23, correction extreme 114.56 (extreme/ma 12.41)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed false) (n_violations 20)
    (n_skipped 0)
    (specimens
     (((symbol WDFC) (entry_date 2011-10-14)
       (detail "filled 2011-10-14 after the 2011-10-07 screen read Bearish"))
      ((symbol TCR) (entry_date 2000-12-18)
       (detail "filled 2000-12-18 after the 2000-12-15 screen read Bearish"))
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
      ((symbol NMK1) (entry_date 2000-11-15)
       (detail "filled 2000-11-15 after the 2000-11-10 screen read Bearish")))))))
 (audit_join ((matched 555) (total 555))))
