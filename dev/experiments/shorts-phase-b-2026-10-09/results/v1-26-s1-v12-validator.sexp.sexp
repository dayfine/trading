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
     "share-class map: /workspaces/trading-1/.claude/worktrees/sweep-spb-B/trading/test_data/share_classes.sexp"))
   ((id V7) (severity Invariant) (passed true) (n_violations 0) (n_skipped 0)
    (specimens ()))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V10) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 12)
    (n_skipped 0)
    (specimens
     (((symbol SY2) (entry_date 2001-03-27)
       (detail
        "installed_stop=19.5655 vs fill=16.8200 -> dist=0.1632 > gate=0.1500"))
      ((symbol RIG) (entry_date 2010-05-27)
       (detail
        "installed_stop=73.6632 vs fill=63.4200 -> dist=0.1615 > gate=0.1500"))
      ((symbol GBLI) (entry_date 2007-08-09)
       (detail
        "installed_stop=22.8696 vs fill=19.8800 -> dist=0.1504 > gate=0.1500"))
      ((symbol FFBC) (entry_date 2022-05-02)
       (detail
        "installed_stop=24.1488 vs fill=20.7900 -> dist=0.1616 > gate=0.1500"))
      ((symbol EMN) (entry_date 2008-09-16)
       (detail
        "installed_stop=64.1250 vs fill=55.0700 -> dist=0.1644 > gate=0.1500"))
      ((symbol EFII) (entry_date 2004-08-09)
       (detail
        "installed_stop=21.7672 vs fill=18.9000 -> dist=0.1517 > gate=0.1500"))
      ((symbol DIN) (entry_date 2007-11-26)
       (detail
        "installed_stop=58.5104 vs fill=50.8000 -> dist=0.1518 > gate=0.1500"))
      ((symbol CYOU) (entry_date 2011-10-05)
       (detail
        "installed_stop=30.6488 vs fill=26.1400 -> dist=0.1725 > gate=0.1500"))
      ((symbol CGNX) (entry_date 2015-08-24)
       (detail
        "installed_stop=40.1250 vs fill=34.2800 -> dist=0.1705 > gate=0.1500"))
      ((symbol ATAR_old) (entry_date 2001-04-09)
       (detail
        "installed_stop=57.2000 vs fill=49.3000 -> dist=0.1602 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol DNA_old) (entry_date 2002-04-15)
       (detail
        "entry_price=18.8200 outside 2002-04-15 bar [18.8250, 19.9000]"))
      ((symbol CELSIA) (entry_date 2008-02-05)
       (detail
        "no bar on exit_date 2008-03-24 (nearest earlier bar: 2008-03-19)"))
      ((symbol BBVA) (entry_date 2008-01-29)
       (detail
        "exit_price=22.1900 outside 2008-03-24 bar [20.8500, 22.1899]")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol PDLI) (entry_date 2001-01-29)
       (detail
        "entry bar 2001-01-29 open=71.7500 low=69.6250 close=73.8125 vs stop=75.3327, exit=75.5100"))
      ((symbol BIP) (entry_date 2022-10-25)
       (detail
        "entry bar 2022-10-25 open=33.6400 low=33.6400 close=35.6200 vs stop=36.5110, exit=36.5200"))
      ((symbol BBOX) (entry_date 2003-03-17)
       (detail
        "entry bar 2003-03-17 open=26.2500 low=26.2500 close=28.6800 vs stop=29.1231, exit=29.3300")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed false) (n_violations 2)
    (n_skipped 0)
    (specimens
     (((symbol CELSIA) (entry_date 2008-02-05)
       (detail
        "stale_force_exit exit 2008-03-24 (entry 2008-02-05 @ 19819.24, exit @ 18520.00)"))
      ((symbol AIG) (entry_date 2005-04-04)
       (detail
        "margin_call exit 2005-07-18 (entry 2005-04-04 @ 52.93, exit @ 60.95)")))))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 4)
    (n_skipped 0)
    (specimens
     (((symbol BOKF) (entry_date 2008-08-11)
       (detail
        "median close 48.89 over 8520 bars (1991-09-05..2025-07-08); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0"))
      ((symbol FLO) (entry_date 2003-01-10)
       (detail
        "median close 18.56 over 11420 bars (1980-03-17..2025-07-08); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0"))
      ((symbol LTRE) (entry_date 2001-03-19)
       (detail
        "median close 9.94 over 5588 bars (1997-12-31..2025-07-08); bar 2023-04-20 close 1.05 (+425.00% vs prior close 0.20) on volume 0"))
      ((symbol NST) (entry_date 2001-01-26)
       (detail
        "median close 29.16 over 4326 bars (1999-08-25..2018-01-30); bar 2013-01-07 close 8.60 (+10650.00% vs prior close 0.08) on volume 0")))))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V21) (severity Expectation) (passed false) (n_violations 30)
    (n_skipped 0)
    (specimens
     (((symbol ZD) (entry_date 2016-03-21)
       (detail
        "SHORT installed_stop 55.6679 vs screener_proxy_stop 59.7780: 6.88% tighter > 3%"))
      ((symbol WTRG) (entry_date 2002-06-17)
       (detail
        "SHORT installed_stop 21.0080 vs screener_proxy_stop 22.6692: 7.33% tighter > 3%"))
      ((symbol WMT) (entry_date 2022-07-15)
       (detail
        "SHORT installed_stop 135.0960 vs screener_proxy_stop 141.8580: 4.77% tighter > 3%"))
      ((symbol SRL) (entry_date 2007-12-26)
       (detail
        "SHORT installed_stop 22.7363 vs screener_proxy_stop 24.0300: 5.38% tighter > 3%"))
      ((symbol SPLK) (entry_date 2022-05-16)
       (detail
        "SHORT installed_stop 106.2568 vs screener_proxy_stop 113.3136: 6.23% tighter > 3%"))
      ((symbol SLAB) (entry_date 2025-04-14)
       (detail
        "SHORT installed_stop 97.2608 vs screener_proxy_stop 101.0124: 3.71% tighter > 3%"))
      ((symbol SEE) (entry_date 2008-11-03)
       (detail
        "SHORT installed_stop 18.1250 vs screener_proxy_stop 18.9756: 4.48% tighter > 3%"))
      ((symbol PM) (entry_date 2019-01-28)
       (detail
        "SHORT installed_stop 77.1576 vs screener_proxy_stop 81.8964: 5.79% tighter > 3%"))
      ((symbol PL_old) (entry_date 2008-07-21)
       (detail
        "SHORT installed_stop 37.0448 vs screener_proxy_stop 38.6640: 4.19% tighter > 3%"))
      ((symbol NVDA) (entry_date 2000-12-05)
       (detail
        "SHORT installed_stop 50.7062 vs screener_proxy_stop 53.7300: 5.63% tighter > 3%")))))
   ((id V22) (severity Expectation) (passed false) (n_violations 7)
    (n_skipped 59)
    (specimens
     (((symbol BVN) (entry_date 2004-05-07)
       (detail
        "no stop move for 19 weeks (2004-05-19..2004-10-05), 1 completed cycle(s) stalled; last: stop 24.12, candidate 24.19, ma 9.74, correction extreme 23.95 (extreme/ma 2.46)"))
      ((symbol CARG) (entry_date 2022-05-13)
       (detail
        "no stop move for 13 weeks (2022-05-18..2022-08-22), 3 completed cycle(s) stalled; last: stop 26.78, candidate 28.09, ma 27.81, correction extreme 26.43 (extreme/ma 0.95)"))
      ((symbol CAT) (entry_date 2022-07-08)
       (detail
        "no stop move for 15 weeks (2022-07-11..2022-10-27), 1 completed cycle(s) stalled; last: stop 200.82, candidate 202.37, ma 179.59, correction extreme 200.37 (extreme/ma 1.12)"))
      ((symbol EFII) (entry_date 2004-08-06)
       (detail
        "no stop move for 32 weeks (2004-08-09..2005-03-24), 1 completed cycle(s) stalled; last: stop 21.77, candidate 23.73, ma 23.50, correction extreme 20.76 (extreme/ma 0.88)"))
      ((symbol HSP) (entry_date 2006-09-01)
       (detail
        "no stop move for 21 weeks (2006-09-05..2007-02-05), 1 completed cycle(s) stalled; last: stop 39.62, candidate 39.84, ma 38.56, correction extreme 39.45 (extreme/ma 1.02)"))
      ((symbol NOV) (entry_date 2014-10-17)
       (detail
        "no stop move for 18 weeks (2015-03-10..2015-07-15), 1 completed cycle(s) stalled; last: stop 56.73, candidate 57.21, ma 43.53, correction extreme 56.64 (extreme/ma 1.30)"))
      ((symbol SONY) (entry_date 2000-10-20)
       (detail
        "no stop move for 16 weeks (2000-11-21..2001-03-14), 1 completed cycle(s) stalled; last: stop 79.57, candidate 80.12, ma 13.90, correction extreme 79.32 (extreme/ma 5.71)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))))
 (audit_join ((matched 167) (total 167))))
