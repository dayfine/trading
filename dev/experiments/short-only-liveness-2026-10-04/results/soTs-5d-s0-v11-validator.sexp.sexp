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
     "share-class map: /workspaces/trading-1/.claude/worktrees/sweep-shortonly/trading/test_data/share_classes.sexp"))
   ((id V7) (severity Invariant) (passed true) (n_violations 0) (n_skipped 0)
    (specimens ()))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V10) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V11) (severity Expectation) (passed false) (n_violations 50)
    (n_skipped 0)
    (specimens
     (((symbol ZION) (entry_date 2008-12-22)
       (detail "stop_distance=0.5008 outside [0.0000, 0.3000]"))
      ((symbol WFC-WS) (entry_date 2009-02-02)
       (detail "stop_distance=0.5206 outside [0.0000, 0.3000]"))
      ((symbol WFC) (entry_date 2009-01-26)
       (detail "stop_distance=0.6163 outside [0.0000, 0.3000]"))
      ((symbol UNH) (entry_date 2009-04-06)
       (detail "stop_distance=0.4090 outside [0.0000, 0.3000]"))
      ((symbol UMPQ) (entry_date 2009-01-12)
       (detail "stop_distance=0.4966 outside [0.0000, 0.3000]"))
      ((symbol UFCS) (entry_date 2009-02-23)
       (detail "stop_distance=0.4728 outside [0.0000, 0.3000]"))
      ((symbol UAL) (entry_date 2009-03-09)
       (detail "stop_distance=0.8339 outside [0.0000, 0.3000]"))
      ((symbol TRN) (entry_date 2008-10-07)
       (detail "stop_distance=0.4439 outside [0.0000, 0.3000]"))
      ((symbol TLEO) (entry_date 2008-10-15)
       (detail "stop_distance=0.5688 outside [0.0000, 0.3000]"))
      ((symbol SUSQ) (entry_date 2009-01-20)
       (detail "stop_distance=0.4613 outside [0.0000, 0.3000]")))))
   ((id V12) (severity Invariant) (passed false) (n_violations 16)
    (n_skipped 0)
    (specimens
     (((symbol ZION) (entry_date 2008-12-22)
       (detail
        "installed_stop=28.6250 vs fill=24.8600 -> dist=0.1514 > gate=0.1500"))
      ((symbol WFC-WS) (entry_date 2009-02-02)
       (detail
        "installed_stop=21.5592 vs fill=18.5200 -> dist=0.1641 > gate=0.1500"))
      ((symbol SUSQ) (entry_date 2009-01-20)
       (detail
        "installed_stop=13.0104 vs fill=11.2700 -> dist=0.1544 > gate=0.1500"))
      ((symbol RJF) (entry_date 2008-01-22)
       (detail
        "installed_stop=31.6250 vs fill=27.4000 -> dist=0.1542 > gate=0.1500"))
      ((symbol OC) (entry_date 2008-11-17)
       (detail
        "installed_stop=15.6250 vs fill=13.4700 -> dist=0.1600 > gate=0.1500"))
      ((symbol NPBC) (entry_date 2009-01-20)
       (detail
        "installed_stop=12.0848 vs fill=10.5000 -> dist=0.1509 > gate=0.1500"))
      ((symbol NGLOY) (entry_date 2008-08-04)
       (detail
        "installed_stop=26.1829 vs fill=22.4700 -> dist=0.1652 > gate=0.1500"))
      ((symbol IAG) (entry_date 2011-11-21)
       (detail
        "installed_stop=21.7984 vs fill=18.9200 -> dist=0.1521 > gate=0.1500"))
      ((symbol HPY) (entry_date 2008-07-28)
       (detail
        "installed_stop=25.6250 vs fill=22.2200 -> dist=0.1532 > gate=0.1500"))
      ((symbol FNB) (entry_date 2008-06-30)
       (detail
        "installed_stop=14.0088 vs fill=12.1800 -> dist=0.1501 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 2)
    (n_skipped 0)
    (specimens
     (((symbol NXGN) (entry_date 2008-12-22)
       (detail
        "entry_price=10.4000 outside 2008-12-22 bar [10.4025, 10.9375]"))
      ((symbol EEQ) (entry_date 2007-10-01)
       (detail
        "exit_price=24.6900 outside 2007-10-31 bar [24.6942, 25.2648]")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 2)
    (n_skipped 0)
    (specimens
     (((symbol ESV) (entry_date 2010-05-07)
       (detail
        "entry bar 2010-05-07 open=43.2200 low=40.2400 close=41.4400 vs stop=42.7497, exit=42.8400"))
      ((symbol DLR) (entry_date 2007-08-06)
       (detail
        "entry bar 2007-08-06 open=34.7463 low=32.8955 close=35.1343 vs stop=36.1199, exit=36.2100")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed false) (n_violations 50)
    (n_skipped 0)
    (specimens
     (((symbol WFC-WS) (entry_date 2009-02-02)
       (detail
        "margin_call exit 2009-02-06 (entry 2009-02-02 @ 18.52, exit @ 17.35)"))
      ((symbol WFC) (entry_date 2009-01-26)
       (detail
        "margin_call exit 2009-01-27 (entry 2009-01-26 @ 15.83, exit @ 15.80)"))
      ((symbol UNH) (entry_date 2009-04-06)
       (detail
        "margin_call exit 2009-04-08 (entry 2009-04-06 @ 20.33, exit @ 24.12)"))
      ((symbol UMPQ) (entry_date 2009-01-12)
       (detail
        "margin_call exit 2009-01-13 (entry 2009-01-12 @ 10.33, exit @ 10.30)"))
      ((symbol UFCS) (entry_date 2009-02-23)
       (detail
        "margin_call exit 2009-03-02 (entry 2009-02-23 @ 19.15, exit @ 16.54)"))
      ((symbol UAL) (entry_date 2009-03-09)
       (detail
        "margin_call exit 2009-03-10 (entry 2009-03-09 @ 3.86, exit @ 4.02)"))
      ((symbol TRN) (entry_date 2008-10-07)
       (detail
        "margin_call exit 2008-10-08 (entry 2008-10-07 @ 15.05, exit @ 13.16)"))
      ((symbol TLEO) (entry_date 2008-10-15)
       (detail
        "margin_call exit 2008-10-16 (entry 2008-10-15 @ 13.51, exit @ 13.15)"))
      ((symbol TCBI) (entry_date 2010-08-09)
       (detail
        "margin_call exit 2010-08-12 (entry 2010-08-09 @ 16.84, exit @ 16.10)"))
      ((symbol SUSQ) (entry_date 2009-01-20)
       (detail
        "margin_call exit 2009-01-21 (entry 2009-01-20 @ 11.27, exit @ 10.37)")))))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 2)
    (n_skipped 0)
    (specimens
     (((symbol ANG) (entry_date 2011-05-31)
       (detail
        "median close 264.00 over 3137 bars (2000-01-10..2012-06-27); bar 2000-03-21 close 0.00 (-100.00% vs prior close 149.79) on volume 0"))
      ((symbol BOKF) (entry_date 2011-09-06)
       (detail
        "median close 36.52 over 5246 bars (1991-09-05..2012-06-27); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0")))))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed false) (n_violations 1)
    (n_skipped 0)
    (specimens
     (((symbol NST) (entry_date 2009-01-05)
       (detail
        "adjusted_close_at_decision 0.76 / ma_value 6.10 = 0.12 outside [0.2, 5]")))))
   ((id V21) (severity Expectation) (passed false) (n_violations 116)
    (n_skipped 0)
    (specimens
     (((symbol ZION) (entry_date 2008-12-22)
       (detail
        "SHORT installed_stop 28.6250 vs screener_proxy_stop 61.9272: 53.78% tighter > 3%"))
      ((symbol WFC-WS) (entry_date 2009-02-02)
       (detail
        "SHORT installed_stop 21.5592 vs screener_proxy_stop 48.5676: 55.61% tighter > 3%"))
      ((symbol WFC) (entry_date 2009-01-26)
       (detail
        "SHORT installed_stop 17.2536 vs screener_proxy_stop 48.5676: 64.48% tighter > 3%"))
      ((symbol WBMD) (entry_date 2007-11-12)
       (detail
        "SHORT installed_stop 49.6250 vs screener_proxy_stop 63.6552: 22.04% tighter > 3%"))
      ((symbol VMC) (entry_date 2012-05-29)
       (detail
        "SHORT installed_stop 38.1888 vs screener_proxy_stop 52.1964: 26.84% tighter > 3%"))
      ((symbol UNH) (entry_date 2009-04-06)
       (detail
        "SHORT installed_stop 22.6304 vs screener_proxy_stop 41.3532: 45.28% tighter > 3%"))
      ((symbol UMPQ) (entry_date 2009-01-12)
       (detail
        "SHORT installed_stop 11.6896 vs screener_proxy_stop 25.0776: 53.39% tighter > 3%"))
      ((symbol UFCS) (entry_date 2009-02-23)
       (detail
        "SHORT installed_stop 20.8104 vs screener_proxy_stop 42.6276: 51.18% tighter > 3%"))
      ((symbol UAL) (entry_date 2009-03-09)
       (detail
        "SHORT installed_stop 4.1496 vs screener_proxy_stop 26.9892: 84.62% tighter > 3%"))
      ((symbol TRN) (entry_date 2008-10-07)
       (detail
        "SHORT installed_stop 16.5547 vs screener_proxy_stop 32.1516: 48.51% tighter > 3%")))))
   ((id V22) (severity Expectation) (passed false) (n_violations 2)
    (n_skipped 1)
    (specimens
     (((symbol DRWI) (entry_date 2011-05-27)
       (detail
        "no stop move for 35 weeks (2011-05-31..2012-02-06), 4 completed cycle(s) stalled; last: stop 180.70, candidate 3191.12, ma 3159.52, correction extreme 97.50 (extreme/ma 0.03)"))
      ((symbol JEF) (entry_date 2011-08-12)
       (detail
        "no stop move for 13 weeks (2011-08-18..2011-11-23), 1 completed cycle(s) stalled; last: stop 30.34, candidate 30.34, ma 22.96, correction extreme 30.04 (extreme/ma 1.31)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))))
 (audit_join ((matched 116) (total 116))))
