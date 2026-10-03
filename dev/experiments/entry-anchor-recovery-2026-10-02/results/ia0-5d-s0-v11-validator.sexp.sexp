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
     "share-class map: /workspaces/trading-1/.claude/worktrees/sweep-anchor/trading/test_data/share_classes.sexp"))
   ((id V7) (severity Invariant) (passed false) (n_violations 2)
    (n_skipped 0)
    (specimens
     (((symbol WDR) (entry_date 2007-07-13)
       (detail
        "Virgin_territory but only 491 weekly bars (< 520) before entry"))
      ((symbol CYOU) (entry_date 2011-02-01)
       (detail
        "Virgin_territory but only 96 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 11)
    (n_skipped 44)
    (specimens
     (((symbol SCSC) (entry_date 2007-11-05)
       (detail "prior_top=37.19 within +25% of entry=34.35"))
      ((symbol PFCB) (entry_date 2010-10-05)
       (detail "prior_top=51.57 within +25% of entry=48.68"))
      ((symbol OPSW) (entry_date 2007-06-29)
       (detail "prior_top=10.07 within +25% of entry=9.98"))
      ((symbol ONTO) (entry_date 2011-01-24)
       (detail "prior_top=17.32 within +25% of entry=15.94"))
      ((symbol MMSI) (entry_date 2011-03-14)
       (detail "prior_top=16.51 within +25% of entry=14.29"))
      ((symbol HITK) (entry_date 2011-05-12)
       (detail "prior_top=27.38 within +25% of entry=26.42"))
      ((symbol FDO) (entry_date 2011-03-14)
       (detail "prior_top=52.55 within +25% of entry=52.17"))
      ((symbol CHKP) (entry_date 2007-09-26)
       (detail "prior_top=25.87 within +25% of entry=25.27"))
      ((symbol CACI) (entry_date 2010-12-07)
       (detail "prior_top=65.75 within +25% of entry=53.21"))
      ((symbol BWLD) (entry_date 2011-02-28)
       (detail "prior_top=54.48 within +25% of entry=53.66")))))
   ((id V10) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 44) (specimens ()))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 4)
    (n_skipped 0)
    (specimens
     (((symbol CYOU) (entry_date 2011-02-01)
       (detail
        "installed_stop=31.2000 vs fill=36.7200 -> dist=0.1503 > gate=0.1500"))
      ((symbol CCME) (entry_date 2010-12-03)
       (detail
        "installed_stop=12.8750 vs fill=15.1900 -> dist=0.1524 > gate=0.1500"))
      ((symbol B) (entry_date 2009-11-06)
       (detail
        "installed_stop=35.1264 vs fill=41.3400 -> dist=0.1503 > gate=0.1500"))
      ((symbol AAON) (entry_date 2007-06-04)
       (detail
        "installed_stop=26.4772 vs fill=19.9700 -> dist=0.3258 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 6)
    (n_skipped 1)
    (specimens
     (((symbol OPSW) (entry_date 2007-06-29)
       (detail
        "no bar on exit_date 2007-09-21 (nearest earlier bar: 2007-09-20)"))
      ((symbol NUAN) (entry_date 2010-12-10)
       (detail
        "exit_price=17.9300 outside 2011-03-07 bar [17.1166, 17.9259]"))
      ((symbol MMSI) (entry_date 2011-03-14)
       (detail
        "entry_price=14.2900 outside 2011-03-14 bar [17.5400, 17.9500]"))
      ((symbol FMC) (entry_date 2009-10-19)
       (detail
        "exit_price=55.5600 outside 2009-11-16 bar [55.5601, 57.0599]"))
      ((symbol BCH) (entry_date 2009-12-02)
       (detail
        "entry_price=43.0500 outside 2009-12-02 bar [45.7674, 47.0205]"))
      ((symbol AOS) (entry_date 2009-11-04)
       (detail
        "exit_price=42.6700 outside 2009-11-16 bar [42.6704, 43.6100]")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol EPRS) (entry_date 2011-01-19)
       (detail
        "entry bar 2011-01-19 open=127.2000 low=120.0000 close=120.6000 vs stop=109.8743, exit=109.7200"))
      ((symbol BX) (entry_date 2009-10-26)
       (detail
        "entry bar 2009-10-26 open=15.6428 low=14.7399 close=14.8184 vs stop=14.3639, exit=14.3300"))
      ((symbol AAWW) (entry_date 2011-03-15)
       (detail
        "entry bar 2011-03-15 open=62.5800 low=61.4900 close=63.2900 vs stop=61.8728, exit=61.8700")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V21) (severity Expectation) (passed false) (n_violations 12)
    (n_skipped 0)
    (specimens
     (((symbol POWI) (entry_date 2012-05-21)
       (detail
        "LONG installed_stop 39.3504 vs screener_proxy_stop 36.9656: 6.45% tighter > 3%"))
      ((symbol NSIT) (entry_date 2011-03-07)
       (detail
        "LONG installed_stop 16.4544 vs screener_proxy_stop 15.6308: 5.27% tighter > 3%"))
      ((symbol MNRO) (entry_date 2009-11-03)
       (detail
        "LONG installed_stop 28.6657 vs screener_proxy_stop 27.1860: 5.44% tighter > 3%"))
      ((symbol ITT) (entry_date 2011-01-18)
       (detail
        "LONG installed_stop 56.4863 vs screener_proxy_stop 53.6176: 5.35% tighter > 3%"))
      ((symbol FMS) (entry_date 2011-03-21)
       (detail
        "LONG installed_stop 61.2768 vs screener_proxy_stop 59.2848: 3.36% tighter > 3%"))
      ((symbol DCI) (entry_date 2010-01-21)
       (detail
        "LONG installed_stop 39.9072 vs screener_proxy_stop 36.8184: 8.39% tighter > 3%"))
      ((symbol CLC) (entry_date 2007-07-24)
       (detail
        "LONG installed_stop 34.3750 vs screener_proxy_stop 32.6600: 5.25% tighter > 3%"))
      ((symbol CCU) (entry_date 2012-04-16)
       (detail
        "LONG installed_stop 68.9760 vs screener_proxy_stop 65.4856: 5.33% tighter > 3%"))
      ((symbol BCH) (entry_date 2012-03-28)
       (detail
        "LONG installed_stop 82.2856 vs screener_proxy_stop 78.6968: 4.56% tighter > 3%"))
      ((symbol AOS) (entry_date 2009-10-26)
       (detail
        "LONG installed_stop 39.8750 vs screener_proxy_stop 38.2996: 4.11% tighter > 3%")))))
   ((id V22) (severity Expectation) (passed false) (n_violations 13)
    (n_skipped 7)
    (specimens
     (((symbol AJG) (entry_date 2010-05-07)
       (detail
        "no stop move for 15 weeks (2010-05-11..2010-08-24), 1 completed cycle(s) stalled; last: stop 21.72, candidate 16.44, ma 16.61, correction extreme 23.66 (extreme/ma 1.42)"))
      ((symbol AOS) (entry_date 2009-11-27)
       (detail
        "no stop move for 27 weeks (2009-11-30..2010-06-07), 2 completed cycle(s) stalled; last: stop 37.16, candidate 5.81, ma 5.87, correction extreme 48.43 (extreme/ma 8.25)"))
      ((symbol BCH) (entry_date 2009-11-27)
       (detail
        "no stop move for 20 weeks (2009-12-02..2010-04-23), 1 completed cycle(s) stalled; last: stop 41.33, candidate 5.94, ma 6.00, correction extreme 48.25 (extreme/ma 8.04)"))
      ((symbol BTI) (entry_date 2011-03-18)
       (detail
        "no stop move for 25 weeks (2011-03-30..2011-09-26), 2 completed cycle(s) stalled; last: stop 70.38, candidate 17.50, ma 17.68, correction extreme 84.37 (extreme/ma 4.77)"))
      ((symbol BWA) (entry_date 2010-01-29)
       (detail
        "no stop move for 67 weeks (2010-02-03..2011-05-20), 8 completed cycle(s) stalled; last: stop 32.38, candidate 25.69, ma 25.95, correction extreme 70.02 (extreme/ma 2.70)"))
      ((symbol CMG) (entry_date 2010-02-05)
       (detail
        "no stop move for 51 weeks (2010-02-08..2011-02-04), 8 completed cycle(s) stalled; last: stop 89.88, candidate 3.43, ma 3.47, correction extreme 207.55 (extreme/ma 59.86)"))
      ((symbol CNH) (entry_date 2009-10-30)
       (detail
        "no stop move for 28 weeks (2009-11-05..2010-05-24), 4 completed cycle(s) stalled; last: stop 15.89, candidate 3.99, ma 4.03, correction extreme 18.74 (extreme/ma 4.65)"))
      ((symbol FMS) (entry_date 2011-03-18)
       (detail
        "no stop move for 22 weeks (2011-03-21..2011-08-22), 1 completed cycle(s) stalled; last: stop 61.28, candidate 26.74, ma 27.01, correction extreme 68.87 (extreme/ma 2.55)"))
      ((symbol GFF) (entry_date 2009-12-18)
       (detail
        "no stop move for 22 weeks (2009-12-22..2010-05-28), 3 completed cycle(s) stalled; last: stop 10.75, candidate 8.78, ma 8.87, correction extreme 12.28 (extreme/ma 1.38)"))
      ((symbol KOF) (entry_date 2007-11-02)
       (detail
        "no stop move for 24 weeks (2007-12-31..2008-06-20), 3 completed cycle(s) stalled; last: stop 42.99, candidate 30.39, ma 30.70, correction extreme 51.04 (extreme/ma 1.66)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed false) (n_violations 6)
    (n_skipped 0)
    (specimens
     (((symbol POWI) (entry_date 2012-05-21)
       (detail "filled 2012-05-21 after the 2012-05-18 screen read Bearish"))
      ((symbol KOF) (entry_date 2007-12-31)
       (detail "filled 2007-12-31 after the 2007-12-28 screen read Bearish"))
      ((symbol DLX) (entry_date 2010-02-17)
       (detail "filled 2010-02-17 after the 2010-02-12 screen read Bearish"))
      ((symbol CHKP) (entry_date 2007-09-26)
       (detail "filled 2007-09-26 after the 2007-09-21 screen read Bearish"))
      ((symbol B) (entry_date 2007-08-10)
       (detail "filled 2007-08-10 after the 2007-08-03 screen read Bearish"))
      ((symbol AGN) (entry_date 2012-05-29)
       (detail "filled 2012-05-29 after the 2012-05-25 screen read Bearish")))))))
 (audit_join ((matched 72) (total 72))))
