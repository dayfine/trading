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
   ((id V7) (severity Invariant) (passed false) (n_violations 15)
    (n_skipped 0)
    (specimens
     (((symbol WING) (entry_date 2017-08-08)
       (detail
        "Virgin_territory but only 113 weekly bars (< 520) before entry"))
      ((symbol VRSK) (entry_date 2017-02-22)
       (detail
        "Virgin_territory but only 385 weekly bars (< 520) before entry"))
      ((symbol TRW1) (entry_date 2000-03-27)
       (detail
        "Virgin_territory but only 117 weekly bars (< 520) before entry"))
      ((symbol SBS) (entry_date 2010-09-30)
       (detail
        "Virgin_territory but only 438 weekly bars (< 520) before entry"))
      ((symbol PBF) (entry_date 2015-03-25)
       (detail
        "Virgin_territory but only 119 weekly bars (< 520) before entry"))
      ((symbol NABZY) (entry_date 2006-01-31)
       (detail
        "Virgin_territory but only 422 weekly bars (< 520) before entry"))
      ((symbol MSM) (entry_date 2003-08-19)
       (detail
        "Virgin_territory but only 401 weekly bars (< 520) before entry"))
      ((symbol MNT) (entry_date 2005-04-15)
       (detail
        "Virgin_territory but only 380 weekly bars (< 520) before entry"))
      ((symbol MHX) (entry_date 2005-06-27)
       (detail
        "Virgin_territory but only 338 weekly bars (< 520) before entry"))
      ((symbol LULU) (entry_date 2013-05-14)
       (detail
        "Virgin_territory but only 303 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 107)
    (n_skipped 172)
    (specimens
     (((symbol ZS) (entry_date 2020-10-29)
       (detail "prior_top=154.85 within +25% of entry=142.28"))
      ((symbol ZBH) (entry_date 2012-12-12)
       (detail "prior_top=67.87 within +25% of entry=67.54"))
      ((symbol XLRN) (entry_date 2018-07-23)
       (detail "prior_top=51.43 within +25% of entry=47.46"))
      ((symbol XLRN) (entry_date 2020-04-20)
       (detail "prior_top=97.78 within +25% of entry=97.02"))
      ((symbol X) (entry_date 2023-09-19)
       (detail "prior_top=37.63 within +25% of entry=31.75"))
      ((symbol WOLF_old2) (entry_date 2021-11-22)
       (detail "prior_top=139.55 within +25% of entry=133.00"))
      ((symbol WIX) (entry_date 2021-03-03)
       (detail "prior_top=353.09 within +25% of entry=327.36"))
      ((symbol VRTX) (entry_date 2014-07-30)
       (detail "prior_top=99.07 within +25% of entry=92.22"))
      ((symbol VICR) (entry_date 2021-07-27)
       (detail "prior_top=107.97 within +25% of entry=107.30"))
      ((symbol VAS) (entry_date 2004-02-02)
       (detail "prior_top=24.49 within +25% of entry=23.76")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 5)
    (n_skipped 172)
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
   ((id V12) (severity Invariant) (passed false) (n_violations 29)
    (n_skipped 0)
    (specimens
     (((symbol ZS) (entry_date 2020-10-29)
       (detail
        "installed_stop=118.8750 vs fill=142.2800 -> dist=0.1645 > gate=0.1500"))
      ((symbol YMM) (entry_date 2024-11-20)
       (detail
        "installed_stop=8.2848 vs fill=9.7700 -> dist=0.1520 > gate=0.1500"))
      ((symbol TRMB) (entry_date 2003-11-24)
       (detail
        "installed_stop=25.8750 vs fill=19.6700 -> dist=0.3155 > gate=0.1500"))
      ((symbol TLK) (entry_date 2012-07-17)
       (detail
        "installed_stop=31.7760 vs fill=37.7000 -> dist=0.1571 > gate=0.1500"))
      ((symbol SOUN) (entry_date 2024-04-02)
       (detail
        "installed_stop=4.3750 vs fill=5.2400 -> dist=0.1651 > gate=0.1500"))
      ((symbol SNEX) (entry_date 2025-01-14)
       (detail
        "installed_stop=87.2355 vs fill=68.1400 -> dist=0.2802 > gate=0.1500"))
      ((symbol NEOG) (entry_date 2017-09-05)
       (detail
        "installed_stop=60.8750 vs fill=52.8000 -> dist=0.1529 > gate=0.1500"))
      ((symbol MNT) (entry_date 2005-04-15)
       (detail
        "installed_stop=31.3920 vs fill=37.4500 -> dist=0.1618 > gate=0.1500"))
      ((symbol MNSO) (entry_date 2025-01-06)
       (detail
        "installed_stop=21.8750 vs fill=26.0100 -> dist=0.1590 > gate=0.1500"))
      ((symbol MMS) (entry_date 2014-08-07)
       (detail
        "installed_stop=33.2640 vs fill=39.3800 -> dist=0.1553 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 21)
    (n_skipped 8)
    (specimens
     (((symbol WY) (entry_date 2010-01-21)
       (detail
        "exit_price=15.8300 outside 2010-01-28 bar [15.8333, 16.4453]"))
      ((symbol SHOO) (entry_date 2016-11-28)
       (detail
        "exit_price=34.7500 outside 2017-01-03 bar [34.7501, 36.2000]"))
      ((symbol SGNT) (entry_date 2014-07-14)
       (detail
        "exit_price=23.7300 outside 2014-08-05 bar [23.7350, 24.6700]"))
      ((symbol PPDI) (entry_date 2011-10-03)
       (detail
        "no bar on exit_date 2011-12-06 (nearest earlier bar: 2011-12-05)"))
      ((symbol PLMD) (entry_date 2007-08-27)
       (detail
        "no bar on exit_date 2007-11-01 (nearest earlier bar: 2007-10-31)"))
      ((symbol NUAN) (entry_date 2010-12-10)
       (detail
        "exit_price=17.9300 outside 2011-03-07 bar [17.1166, 17.9259]"))
      ((symbol NTTYY) (entry_date 2017-11-07)
       (detail
        "entry_price=50.4200 outside 2017-11-07 bar [50.4190, 50.4190]"))
      ((symbol NMK1) (entry_date 2000-11-15)
       (detail
        "entry_price=16.3800 outside 2000-11-15 bar [16.1880, 16.3750]"))
      ((symbol NLC) (entry_date 2011-08-15)
       (detail
        "no bar on exit_date 2011-12-06 (nearest earlier bar: 2011-12-01)"))
      ((symbol NEOG) (entry_date 2017-09-05)
       (detail
        "entry_price=52.8000 outside 2017-09-05 bar [68.8760, 70.4406]")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 18)
    (n_skipped 0)
    (specimens
     (((symbol TDS) (entry_date 2023-09-11)
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
      ((symbol PEGA) (entry_date 2020-03-10)
       (detail
        "entry bar 2020-03-10 open=79.5400 low=76.5800 close=83.4400 vs stop=78.9307, exit=78.9000"))
      ((symbol MLNX) (entry_date 2018-11-19)
       (detail
        "entry bar 2018-11-19 open=92.8500 low=91.1200 close=91.2800 vs stop=85.8773, exit=85.8500"))
      ((symbol GATX) (entry_date 2014-10-09)
       (detail
        "entry bar 2014-10-09 open=56.7000 low=55.2723 close=55.4300 vs stop=52.8780, exit=54.6500"))
      ((symbol FSH) (entry_date 2005-11-15)
       (detail
        "entry bar 2005-11-15 open=65.0000 low=64.8200 close=65.5000 vs stop=58.4590, exit=64.1500"))
      ((symbol FMI) (entry_date 2015-04-27)
       (detail
        "entry bar 2015-04-27 open=46.3500 low=43.8900 close=44.3900 vs stop=42.4950, exit=42.4700"))
      ((symbol FLNA) (entry_date 2020-10-12)
       (detail
        "entry bar 2020-10-12 open=11.8900 low=11.0700 close=11.4300 vs stop=10.8755, exit=10.8100")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 0)
    (specimens
     (((symbol NLC) (entry_date 2011-08-15)
       (detail
        "stale_force_exit exit 2011-12-06 (entry 2011-08-15 @ 33.17, exit @ 38.80)")))))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 9)
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
      ((symbol FLO) (entry_date 2021-06-03)
       (detail
        "median close 18.16 over 11662 bars (1980-03-17..2026-06-24); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0"))
      ((symbol IHG) (entry_date 2012-06-19)
       (detail
        "median close 37.44 over 5839 bars (2003-04-08..2026-06-24); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0"))
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
   ((id V21) (severity Expectation) (passed false) (n_violations 65)
    (n_skipped 0)
    (specimens
     (((symbol WY) (entry_date 2010-01-21)
       (detail
        "LONG installed_stop 15.8750 vs screener_proxy_stop 15.0696: 5.34% tighter > 3%"))
      ((symbol VMC) (entry_date 2016-11-28)
       (detail
        "LONG installed_stop 121.2960 vs screener_proxy_stop 117.6128: 3.13% tighter > 3%"))
      ((symbol VGR) (entry_date 2021-12-06)
       (detail
        "LONG installed_stop 10.3471 vs screener_proxy_stop 10.0280: 3.18% tighter > 3%"))
      ((symbol TROX) (entry_date 2012-04-23)
       (detail
        "LONG installed_stop 161.2800 vs screener_proxy_stop 152.8856: 5.49% tighter > 3%"))
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
      ((symbol SPSC) (entry_date 2019-02-28)
       (detail
        "LONG installed_stop 98.2368 vs screener_proxy_stop 93.0856: 5.53% tighter > 3%"))
      ((symbol SNBR) (entry_date 2011-11-10)
       (detail
        "LONG installed_stop 18.8160 vs screener_proxy_stop 17.7836: 5.81% tighter > 3%")))))
   ((id V22) (severity Expectation) (passed false) (n_violations 95)
    (n_skipped 106)
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
   ((id V23) (severity Expectation) (passed false) (n_violations 21)
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
      ((symbol SGEN) (entry_date 2011-10-27)
       (detail "filled 2011-10-27 after the 2011-10-21 screen read Bearish"))
      ((symbol PPDI) (entry_date 2011-10-03)
       (detail "filled 2011-10-03 after the 2011-09-30 screen read Bearish"))
      ((symbol PAET) (entry_date 2011-10-04)
       (detail "filled 2011-10-04 after the 2011-09-30 screen read Bearish"))
      ((symbol OFIX) (entry_date 2019-02-12)
       (detail "filled 2019-02-12 after the 2019-02-08 screen read Bearish"))
      ((symbol NRG) (entry_date 2006-07-28)
       (detail "filled 2006-07-28 after the 2006-07-21 screen read Bearish"))
      ((symbol NMK1) (entry_date 2000-11-15)
       (detail "filled 2000-11-15 after the 2000-11-10 screen read Bearish")))))))
 (audit_join ((matched 552) (total 552))))
