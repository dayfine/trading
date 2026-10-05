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
   ((id V6) (severity Invariant) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol HEI) (entry_date 2009-03-16)
       (detail
        "share-class overlap: HEI/HEI-A held together 2009-03-23..2009-04-02"))
      ((symbol ASB) (entry_date 2009-02-23)
       (detail "twin positions: ASB/PACW"))
      ((symbol CQB) (entry_date 2007-08-27)
       (detail "twin positions: CQB/HOFF"))))
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
   ((id V11) (severity Expectation) (passed false) (n_violations 83)
    (n_skipped 0)
    (specimens
     (((symbol WFC-WS) (entry_date 2009-01-26)
       (detail "stop_distance=0.6163 outside [0.0000, 0.3000]"))
      ((symbol WFC) (entry_date 2009-01-28)
       (detail "stop_distance=0.5636 outside [0.0000, 0.3000]"))
      ((symbol VSAT) (entry_date 2008-02-04)
       (detail "stop_distance=0.3728 outside [0.0000, 0.3000]"))
      ((symbol UMPQ) (entry_date 2009-01-12)
       (detail "stop_distance=0.4966 outside [0.0000, 0.3000]"))
      ((symbol UMPQ) (entry_date 2009-01-20)
       (detail "stop_distance=0.5799 outside [0.0000, 0.3000]"))
      ((symbol UCB) (entry_date 2009-02-02)
       (detail "stop_distance=0.7436 outside [0.0000, 0.3000]"))
      ((symbol UCB) (entry_date 2009-02-17)
       (detail "stop_distance=0.8322 outside [0.0000, 0.3000]"))
      ((symbol UBSI) (entry_date 2009-02-17)
       (detail "stop_distance=0.4565 outside [0.0000, 0.3000]"))
      ((symbol UAL) (entry_date 2009-02-27)
       (detail "stop_distance=0.8166 outside [0.0000, 0.3000]"))
      ((symbol TTC) (entry_date 2009-02-23)
       (detail "stop_distance=0.5134 outside [0.0000, 0.3000]")))))
   ((id V12) (severity Invariant) (passed false) (n_violations 4)
    (n_skipped 0)
    (specimens
     (((symbol OC) (entry_date 2008-11-17)
       (detail
        "installed_stop=15.6250 vs fill=13.4700 -> dist=0.1600 > gate=0.1500"))
      ((symbol NCR) (entry_date 2007-10-08)
       (detail
        "installed_stop=30.1704 vs fill=26.2300 -> dist=0.1502 > gate=0.1500"))
      ((symbol BOKF) (entry_date 2008-07-21)
       (detail
        "installed_stop=50.8664 vs fill=44.0000 -> dist=0.1561 > gate=0.1500"))
      ((symbol AZZ) (entry_date 2008-11-17)
       (detail
        "installed_stop=25.5112 vs fill=22.0800 -> dist=0.1554 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol TREX) (entry_date 2009-03-02)
       (detail "exit_price=7.6200 outside 2009-03-06 bar [6.7600, 7.6176]"))
      ((symbol NXGN) (entry_date 2008-12-22)
       (detail
        "entry_price=10.4000 outside 2008-12-22 bar [10.4025, 10.9375]"))
      ((symbol EEQ) (entry_date 2007-10-01)
       (detail
        "exit_price=24.6900 outside 2007-10-31 bar [24.6942, 25.2648]")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 4)
    (n_skipped 0)
    (specimens
     (((symbol MSM) (entry_date 2012-05-21)
       (detail
        "entry bar 2012-05-21 open=68.3100 low=67.7900 close=69.0600 vs stop=71.0424, exit=71.0700"))
      ((symbol LHCG) (entry_date 2009-03-09)
       (detail
        "entry bar 2009-03-09 open=17.1200 low=16.9000 close=17.0000 vs stop=17.8459, exit=17.9400"))
      ((symbol ESV) (entry_date 2010-05-07)
       (detail
        "entry bar 2010-05-07 open=43.2200 low=40.2400 close=41.4400 vs stop=42.7497, exit=42.8400"))
      ((symbol CM) (entry_date 2007-12-10)
       (detail
        "entry bar 2007-12-10 open=78.5900 low=77.9500 close=80.2500 vs stop=81.7336, exit=81.8000")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed false) (n_violations 68)
    (n_skipped 0)
    (specimens
     (((symbol WFC-WS) (entry_date 2009-01-26)
       (detail
        "margin_call exit 2009-01-27 (entry 2009-01-26 @ 15.83, exit @ 15.80)"))
      ((symbol UMPQ) (entry_date 2009-01-12)
       (detail
        "margin_call exit 2009-01-13 (entry 2009-01-12 @ 10.33, exit @ 10.30)"))
      ((symbol UMPQ) (entry_date 2009-01-20)
       (detail
        "margin_call exit 2009-01-21 (entry 2009-01-20 @ 9.20, exit @ 8.50)"))
      ((symbol UCB) (entry_date 2009-02-02)
       (detail
        "margin_call exit 2009-02-03 (entry 2009-02-02 @ 5.08, exit @ 4.92)"))
      ((symbol UCB) (entry_date 2009-02-17)
       (detail
        "margin_call exit 2009-02-18 (entry 2009-02-17 @ 3.30, exit @ 3.27)"))
      ((symbol UBSI) (entry_date 2009-02-17)
       (detail
        "margin_call exit 2009-02-18 (entry 2009-02-17 @ 19.21, exit @ 17.64)"))
      ((symbol UAL) (entry_date 2009-02-27)
       (detail
        "margin_call exit 2009-03-02 (entry 2009-02-27 @ 5.34, exit @ 4.71)"))
      ((symbol TREX) (entry_date 2009-03-02)
       (detail
        "margin_call exit 2009-03-06 (entry 2009-03-02 @ 9.01, exit @ 7.62)"))
      ((symbol SUSQ) (entry_date 2009-01-20)
       (detail
        "margin_call exit 2009-01-21 (entry 2009-01-20 @ 11.27, exit @ 10.37)"))
      ((symbol SUSQ) (entry_date 2009-01-26)
       (detail
        "margin_call exit 2009-01-27 (entry 2009-01-26 @ 10.83, exit @ 11.04)")))))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 2)
    (n_skipped 0)
    (specimens
     (((symbol BOKF) (entry_date 2008-07-21)
       (detail
        "median close 36.29 over 5231 bars (1991-09-05..2012-06-06); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0"))
      ((symbol SSC) (entry_date 2011-09-06)
       (detail
        "median close 618.75 over 1271 bars (2007-05-23..2012-06-06); bar 2008-04-11 close 5625.00 (+96.08% vs prior close 2868.75) on volume 0")))))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed false) (n_violations 1)
    (n_skipped 0)
    (specimens
     (((symbol NST) (entry_date 2009-01-05)
       (detail
        "adjusted_close_at_decision 0.76 / ma_value 6.10 = 0.12 outside [0.2, 5]")))))
   ((id V21) (severity Expectation) (passed false) (n_violations 175)
    (n_skipped 0)
    (specimens
     (((symbol ZBH) (entry_date 2007-08-06)
       (detail
        "SHORT installed_stop 80.1840 vs screener_proxy_stop 102.4380: 21.72% tighter > 3%"))
      ((symbol WTFC) (entry_date 2010-08-06)
       (detail
        "SHORT installed_stop 32.3648 vs screener_proxy_stop 48.7620: 33.63% tighter > 3%"))
      ((symbol WSO) (entry_date 2011-08-01)
       (detail
        "SHORT installed_stop 61.5472 vs screener_proxy_stop 79.6500: 22.73% tighter > 3%"))
      ((symbol WFC-WS) (entry_date 2009-01-26)
       (detail
        "SHORT installed_stop 17.2536 vs screener_proxy_stop 48.5676: 64.48% tighter > 3%"))
      ((symbol WFC) (entry_date 2009-01-28)
       (detail
        "SHORT installed_stop 19.6250 vs screener_proxy_stop 48.5676: 59.59% tighter > 3%"))
      ((symbol VSAT) (entry_date 2008-02-04)
       (detail
        "SHORT installed_stop 22.6928 vs screener_proxy_stop 39.0744: 41.92% tighter > 3%"))
      ((symbol UMPQ) (entry_date 2009-01-12)
       (detail
        "SHORT installed_stop 11.6896 vs screener_proxy_stop 25.0776: 53.39% tighter > 3%"))
      ((symbol UMPQ) (entry_date 2009-01-20)
       (detail
        "SHORT installed_stop 9.7552 vs screener_proxy_stop 25.0776: 61.10% tighter > 3%"))
      ((symbol UCB) (entry_date 2009-02-02)
       (detail
        "SHORT installed_stop 5.3560 vs screener_proxy_stop 22.5612: 76.26% tighter > 3%"))
      ((symbol UCB) (entry_date 2009-02-17)
       (detail
        "SHORT installed_stop 3.5048 vs screener_proxy_stop 22.5612: 84.47% tighter > 3%")))))
   ((id V22) (severity Expectation) (passed false) (n_violations 8)
    (n_skipped 2)
    (specimens
     (((symbol AMRX) (entry_date 2011-07-01)
       (detail
        "no stop move for 25 weeks (2011-07-05..2011-12-27), 1 completed cycle(s) stalled; last: stop 23.12, candidate 23.73, ma 23.50, correction extreme 21.93 (extreme/ma 0.93)"))
      ((symbol BLUD) (entry_date 2008-02-01)
       (detail
        "no stop move for 24 weeks (2008-02-04..2008-07-22), 1 completed cycle(s) stalled; last: stop 30.73, candidate 30.75, ma 30.45, correction extreme 30.32 (extreme/ma 1.00)"))
      ((symbol DMND) (entry_date 2011-11-04)
       (detail
        "no stop move for 13 weeks (2011-11-07..2012-02-09), 2 completed cycle(s) stalled; last: stop 48.26, candidate 60.69, ma 60.09, correction extreme 30.81 (extreme/ma 0.51)"))
      ((symbol DRWI) (entry_date 2011-05-27)
       (detail
        "no stop move for 35 weeks (2011-05-31..2012-02-06), 4 completed cycle(s) stalled; last: stop 180.70, candidate 3191.12, ma 3159.52, correction extreme 97.50 (extreme/ma 0.03)"))
      ((symbol ERIE) (entry_date 2008-06-20)
       (detail
        "no stop move for 13 weeks (2008-07-03..2008-10-06), 1 completed cycle(s) stalled; last: stop 49.62, candidate 50.12, ma 27.54, correction extreme 49.49 (extreme/ma 1.80)"))
      ((symbol FE) (entry_date 2010-02-12)
       (detail
        "no stop move for 13 weeks (2010-02-16..2010-05-20), 1 completed cycle(s) stalled; last: stop 40.76, candidate 41.12, ma 19.48, correction extreme 40.59 (extreme/ma 2.08)"))
      ((symbol MO) (entry_date 2008-04-04)
       (detail
        "no stop move for 20 weeks (2008-04-29..2008-09-17), 1 completed cycle(s) stalled; last: stop 23.12, candidate 23.25, ma 11.67, correction extreme 23.02 (extreme/ma 1.97)"))
      ((symbol NCR) (entry_date 2007-10-05)
       (detail
        "no stop move for 14 weeks (2007-10-08..2008-01-17), 2 completed cycle(s) stalled; last: stop 30.17, candidate 30.67, ma 30.37, correction extreme 25.59 (extreme/ma 0.84)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))))
 (audit_join ((matched 175) (total 175))))
