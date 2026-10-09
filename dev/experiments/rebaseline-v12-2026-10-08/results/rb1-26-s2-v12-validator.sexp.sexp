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
     "share-class map: /workspaces/trading-1/.claude/worktrees/sweep-rb12/trading/test_data/share_classes.sexp"))
   ((id V7) (severity Invariant) (passed false) (n_violations 23)
    (n_skipped 0)
    (specimens
     (((symbol XERS) (entry_date 2024-02-14)
       (detail
        "Virgin_territory but only 297 weekly bars (< 520) before entry"))
      ((symbol WING) (entry_date 2017-08-08)
       (detail
        "Virgin_territory but only 113 weekly bars (< 520) before entry"))
      ((symbol VRSK) (entry_date 2017-02-22)
       (detail
        "Virgin_territory but only 388 weekly bars (< 520) before entry"))
      ((symbol VOYA) (entry_date 2017-11-29)
       (detail
        "Virgin_territory but only 241 weekly bars (< 520) before entry"))
      ((symbol TRW1) (entry_date 2000-03-27)
       (detail
        "Virgin_territory but only 118 weekly bars (< 520) before entry"))
      ((symbol TRNO) (entry_date 2017-04-11)
       (detail
        "Virgin_territory but only 377 weekly bars (< 520) before entry"))
      ((symbol PDM) (entry_date 2015-01-28)
       (detail
        "Virgin_territory but only 472 weekly bars (< 520) before entry"))
      ((symbol PBF) (entry_date 2015-03-25)
       (detail
        "Virgin_territory but only 122 weekly bars (< 520) before entry"))
      ((symbol NABZY) (entry_date 2006-01-31)
       (detail
        "Virgin_territory but only 426 weekly bars (< 520) before entry"))
      ((symbol MSTR) (entry_date 2004-11-03)
       (detail
        "Virgin_territory but only 337 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 97)
    (n_skipped 161)
    (specimens
     (((symbol XLRN) (entry_date 2018-07-23)
       (detail "prior_top=51.43 within +25% of entry=47.49"))
      ((symbol XLRN) (entry_date 2020-04-20)
       (detail "prior_top=97.78 within +25% of entry=97.02"))
      ((symbol X) (entry_date 2023-09-19)
       (detail "prior_top=37.63 within +25% of entry=31.85"))
      ((symbol WOLF_old2) (entry_date 2021-11-22)
       (detail "prior_top=139.55 within +25% of entry=133.00"))
      ((symbol WIX) (entry_date 2021-03-03)
       (detail "prior_top=353.09 within +25% of entry=327.36"))
      ((symbol VRTX) (entry_date 2014-07-30)
       (detail "prior_top=99.07 within +25% of entry=92.22"))
      ((symbol UA) (entry_date 2021-11-22)
       (detail "prior_top=27.04 within +25% of entry=22.69"))
      ((symbol TWX1) (entry_date 2000-01-28)
       (detail "prior_top=91.12 within +25% of entry=80.60"))
      ((symbol TTWO) (entry_date 2020-05-19)
       (detail "prior_top=137.99 within +25% of entry=136.41"))
      ((symbol THO) (entry_date 2021-02-16)
       (detail "prior_top=130.65 within +25% of entry=123.20")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 5)
    (n_skipped 161)
    (specimens
     (((symbol SATL) (entry_date 2026-04-01)
       (detail "entry_wk_close=6.77 > prior=3.09 (spike>60%)"))
      ((symbol PUMP) (entry_date 2025-11-12)
       (detail "entry_wk_close=9.92 > prior=5.54 (spike>60%)"))
      ((symbol ISEE) (entry_date 2022-09-30)
       (detail "entry_wk_close=17.94 > prior=9.44 (spike>60%)"))
      ((symbol INOD) (entry_date 2025-09-29)
       (detail "entry_wk_close=84.14 > prior=43.48 (spike>60%)"))
      ((symbol CLPA) (entry_date 2000-01-31)
       (detail "entry_wk_close=25.25 > prior=12.12 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 23)
    (n_skipped 0)
    (specimens
     (((symbol XERS) (entry_date 2024-02-14)
       (detail
        "installed_stop=2.6496 vs fill=3.1300 -> dist=0.1535 > gate=0.1500"))
      ((symbol VOYA) (entry_date 2017-11-29)
       (detail
        "installed_stop=36.7008 vs fill=43.5100 -> dist=0.1565 > gate=0.1500"))
      ((symbol TRMB) (entry_date 2003-11-24)
       (detail
        "installed_stop=25.8750 vs fill=19.7100 -> dist=0.3128 > gate=0.1500"))
      ((symbol QLYS) (entry_date 2021-01-20)
       (detail
        "installed_stop=106.9728 vs fill=125.9600 -> dist=0.1507 > gate=0.1500"))
      ((symbol NEOG) (entry_date 2017-09-05)
       (detail
        "installed_stop=60.8750 vs fill=52.8100 -> dist=0.1527 > gate=0.1500"))
      ((symbol MNT) (entry_date 2005-04-15)
       (detail
        "installed_stop=31.3920 vs fill=37.4500 -> dist=0.1618 > gate=0.1500"))
      ((symbol MNSO) (entry_date 2025-01-06)
       (detail
        "installed_stop=21.8750 vs fill=26.0100 -> dist=0.1590 > gate=0.1500"))
      ((symbol MEI) (entry_date 2014-09-04)
       (detail
        "installed_stop=32.4096 vs fill=38.4700 -> dist=0.1575 > gate=0.1500"))
      ((symbol INOD) (entry_date 2025-09-29)
       (detail
        "installed_stop=61.6320 vs fill=72.6400 -> dist=0.1515 > gate=0.1500"))
      ((symbol INOD) (entry_date 2026-06-09)
       (detail
        "installed_stop=81.3750 vs fill=96.2100 -> dist=0.1542 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 20)
    (n_skipped 4)
    (specimens
     (((symbol SPIL) (entry_date 2003-07-15)
       (detail "exit_price=2.4300 outside 2003-07-21 bar [2.4313, 2.5722]"))
      ((symbol SHOO) (entry_date 2016-11-28)
       (detail
        "exit_price=34.7500 outside 2017-01-03 bar [34.7501, 36.2000]"))
      ((symbol PETC) (entry_date 2000-05-30)
       (detail
        "entry_price=18.5600 outside 2000-05-30 bar [18.5630, 18.8750]"))
      ((symbol OSIS) (entry_date 2024-03-26)
       (detail
        "entry_price=140.9700 outside 2024-03-26 bar [137.3000, 140.9650]"))
      ((symbol NUAN) (entry_date 2010-12-10)
       (detail
        "exit_price=17.9300 outside 2011-03-07 bar [17.1166, 17.9259]"))
      ((symbol NTTYY) (entry_date 2017-11-07)
       (detail
        "entry_price=50.4200 outside 2017-11-07 bar [50.4190, 50.4190]"))
      ((symbol NFLX) (entry_date 2020-03-03)
       (detail
        "exit_price=341.7200 outside 2020-03-09 bar [341.7209, 357.4701]"))
      ((symbol NEOG) (entry_date 2017-09-05)
       (detail
        "entry_price=52.8100 outside 2017-09-05 bar [68.8760, 70.4406]"))
      ((symbol MOND_old) (entry_date 2000-09-11)
       (detail
        "exit_price=37.6200 outside 2000-10-10 bar [37.6250, 38.7500]"))
      ((symbol MMSI) (entry_date 2011-03-14)
       (detail
        "entry_price=14.3300 outside 2011-03-14 bar [17.5400, 17.9500]")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 22)
    (n_skipped 0)
    (specimens
     (((symbol UPWK) (entry_date 2025-09-30)
       (detail
        "entry bar 2025-09-30 open=18.9800 low=18.2150 close=18.5700 vs stop=17.8706, exit=17.8400"))
      ((symbol TDS) (entry_date 2023-09-11)
       (detail
        "entry bar 2023-09-11 open=17.8500 low=17.3700 close=17.6500 vs stop=17.1658, exit=17.0600"))
      ((symbol SDA) (entry_date 2023-07-12)
       (detail
        "entry bar 2023-07-12 open=14.1500 low=11.5500 close=11.7000 vs stop=10.4919, exit=10.4400"))
      ((symbol QCOM) (entry_date 2026-05-18)
       (detail
        "entry bar 2026-05-18 open=206.7700 low=193.5800 close=203.6400 vs stop=191.1970, exit=191.0800"))
      ((symbol PUMP) (entry_date 2025-11-12)
       (detail
        "entry bar 2025-11-12 open=11.0100 low=10.1850 close=10.4300 vs stop=9.8352, exit=9.7600"))
      ((symbol MLNX) (entry_date 2018-11-19)
       (detail
        "entry bar 2018-11-19 open=92.8500 low=91.1200 close=91.2800 vs stop=85.8773, exit=85.7800"))
      ((symbol FSH) (entry_date 2005-11-15)
       (detail
        "entry bar 2005-11-15 open=65.0000 low=64.8200 close=65.5000 vs stop=58.4676, exit=64.1700"))
      ((symbol FMI) (entry_date 2015-04-27)
       (detail
        "entry bar 2015-04-27 open=46.3500 low=43.8900 close=44.3900 vs stop=42.4950, exit=42.3900"))
      ((symbol FLNA) (entry_date 2020-10-12)
       (detail
        "entry bar 2020-10-12 open=11.8900 low=11.0700 close=11.4300 vs stop=10.8755, exit=10.8100"))
      ((symbol EXTR) (entry_date 2022-01-21)
       (detail
        "entry bar 2022-01-21 open=12.8100 low=12.4900 close=12.4900 vs stop=12.1943, exit=12.1800")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 9)
    (n_skipped 0)
    (specimens
     (((symbol ANIP) (entry_date 2024-03-11)
       (detail
        "median close 26.24 over 6160 bars (2001-07-24..2026-06-24); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0"))
      ((symbol ARJ) (entry_date 2005-12-29)
       (detail
        "median close 0.16 over 4552 bars (1999-02-09..2017-03-13); bar 2010-01-29 close 0.13 (-99.55% vs prior close 28.25) on volume 0"))
      ((symbol DRX) (entry_date 2007-06-14)
       (detail
        "median close 8.92 over 4248 bars (2000-01-04..2018-02-22); bar 2014-10-27 close 0.01 (-99.92% vs prior close 12.71) on volume 0"))
      ((symbol EHC) (entry_date 2014-09-04)
       (detail
        "median close 23.25 over 10013 bars (1986-09-24..2026-06-24); bar 2006-10-26 close 23.75 (+400.00% vs prior close 4.75) on volume 0"))
      ((symbol FIT) (entry_date 2019-11-26)
       (detail
        "median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0"))
      ((symbol FLO) (entry_date 2021-06-03)
       (detail
        "median close 18.16 over 11662 bars (1980-03-17..2026-06-24); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0"))
      ((symbol IHG) (entry_date 2013-11-27)
       (detail
        "median close 37.44 over 5839 bars (2003-04-08..2026-06-24); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0"))
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
     (((symbol VMC) (entry_date 2016-11-28)
       (detail
        "LONG installed_stop 121.2960 vs screener_proxy_stop 117.6128: 3.13% tighter > 3%"))
      ((symbol VGR) (entry_date 2021-12-06)
       (detail
        "LONG installed_stop 10.3471 vs screener_proxy_stop 10.0280: 3.18% tighter > 3%"))
      ((symbol UPWK) (entry_date 2025-09-30)
       (detail
        "LONG installed_stop 17.8750 vs screener_proxy_stop 16.7716: 6.58% tighter > 3%"))
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
      ((symbol RYAAY) (entry_date 2003-10-27)
       (detail
        "LONG installed_stop 46.3750 vs screener_proxy_stop 44.5832: 4.02% tighter > 3%"))
      ((symbol QCOM) (entry_date 2022-01-20)
       (detail
        "LONG installed_stop 164.3616 vs screener_proxy_stop 155.2776: 5.85% tighter > 3%"))
      ((symbol PYX) (entry_date 2018-10-22)
       (detail
        "LONG installed_stop 29.3750 vs screener_proxy_stop 28.3820: 3.50% tighter > 3%")))))
   ((id V22) (severity Expectation) (passed false) (n_violations 94)
    (n_skipped 92)
    (specimens
     (((symbol ABEV) (entry_date 2012-11-02)
       (detail
        "no stop move for 15 weeks (2012-11-29..2013-03-15), 1 completed cycle(s) stalled; last: stop 32.19, candidate 4.39, ma 4.44, correction extreme 40.74 (extreme/ma 9.18)"))
      ((symbol ACIW) (entry_date 2013-09-06)
       (detail
        "no stop move for 21 weeks (2013-09-18..2014-02-14), 1 completed cycle(s) stalled; last: stop 45.88, candidate 18.88, ma 19.24, correction extreme 59.42 (extreme/ma 3.09)"))
      ((symbol ACN) (entry_date 2006-10-13)
       (detail
        "no stop move for 27 weeks (2006-10-30..2007-05-11), 3 completed cycle(s) stalled; last: stop 28.66, candidate 25.44, ma 25.69, correction extreme 34.28 (extreme/ma 1.33)"))
      ((symbol ADNT) (entry_date 2020-02-21)
       (detail
        "no stop move for 31 weeks (2020-11-09..2021-06-18), 1 completed cycle(s) stalled; last: stop 25.38, candidate 20.66, ma 20.86, correction extreme 26.23 (extreme/ma 1.26)"))
      ((symbol AIN) (entry_date 2005-02-04)
       (detail
        "no stop move for 23 weeks (2005-07-12..2005-12-23), 2 completed cycle(s) stalled; last: stop 29.71, candidate 23.88, ma 24.31, correction extreme 34.60 (extreme/ma 1.42)"))
      ((symbol AIT) (entry_date 2022-08-26)
       (detail
        "no stop move for 16 weeks (2022-10-05..2023-01-26), 1 completed cycle(s) stalled; last: stop 104.22, candidate 102.48, ma 103.52, correction extreme 114.59 (extreme/ma 1.11)"))
      ((symbol ALJ) (entry_date 2012-08-10)
       (detail
        "no stop move for 18 weeks (2012-08-14..2012-12-21), 3 completed cycle(s) stalled; last: stop 10.67, candidate 9.88, ma 10.16, correction extreme 12.06 (extreme/ma 1.19)"))
      ((symbol ALSK) (entry_date 2006-03-10)
       (detail
        "no stop move for 49 weeks (2006-03-21..2007-03-02), 6 completed cycle(s) stalled; last: stop 10.37, candidate 8.72, ma 8.81, correction extreme 15.15 (extreme/ma 1.72)"))
      ((symbol ALXN) (entry_date 2004-02-06)
       (detail
        "no stop move for 14 weeks (2004-02-10..2004-05-21), 1 completed cycle(s) stalled; last: stop 18.69, candidate 4.77, ma 4.82, correction extreme 20.99 (extreme/ma 4.36)"))
      ((symbol AN) (entry_date 2020-07-31)
       (detail
        "no stop move for 16 weeks (2020-08-04..2020-11-24), 2 completed cycle(s) stalled; last: stop 48.84, candidate 48.78, ma 49.27, correction extreme 50.52 (extreme/ma 1.03)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed false) (n_violations 36)
    (n_skipped 0)
    (specimens
     (((symbol WTM) (entry_date 2015-07-27)
       (detail "filled 2015-07-27 after the 2015-07-24 screen read Bearish"))
      ((symbol WST) (entry_date 2012-05-24)
       (detail "filled 2012-05-24 after the 2012-05-18 screen read Bearish"))
      ((symbol VRSK) (entry_date 2013-01-02)
       (detail "filled 2013-01-02 after the 2012-12-28 screen read Bearish"))
      ((symbol SYK) (entry_date 2019-01-30)
       (detail "filled 2019-01-30 after the 2019-01-25 screen read Bearish"))
      ((symbol STN) (entry_date 2025-05-01)
       (detail "filled 2025-05-01 after the 2025-04-25 screen read Bearish"))
      ((symbol QDEL) (entry_date 2013-01-02)
       (detail "filled 2013-01-02 after the 2012-12-28 screen read Bearish"))
      ((symbol POWI) (entry_date 2012-05-21)
       (detail "filled 2012-05-21 after the 2012-05-18 screen read Bearish"))
      ((symbol ONXX) (entry_date 2012-05-24)
       (detail "filled 2012-05-24 after the 2012-05-18 screen read Bearish"))
      ((symbol OFIX) (entry_date 2019-02-12)
       (detail "filled 2019-02-12 after the 2019-02-08 screen read Bearish"))
      ((symbol NJR) (entry_date 2006-07-24)
       (detail "filled 2006-07-24 after the 2006-07-21 screen read Bearish")))))))
 (audit_join ((matched 510) (total 510))))
