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
     "share-class map: /workspaces/trading-1/.claude/worktrees/sweep-trader/trading/test_data/share_classes.sexp"))
   ((id V7) (severity Invariant) (passed false) (n_violations 12)
    (n_skipped 0)
    (specimens
     (((symbol UAA) (entry_date 2010-09-15)
       (detail
        "Virgin_territory but only 254 weekly bars (< 520) before entry"))
      ((symbol TITN) (entry_date 2012-04-12)
       (detail
        "Virgin_territory but only 229 weekly bars (< 520) before entry"))
      ((symbol ROVI) (entry_date 2007-06-06)
       (detail
        "Virgin_territory but only 496 weekly bars (< 520) before entry"))
      ((symbol NPSNY) (entry_date 2009-08-28)
       (detail
        "Virgin_territory but only 351 weekly bars (< 520) before entry"))
      ((symbol MNTA) (entry_date 2010-07-23)
       (detail
        "Virgin_territory but only 319 weekly bars (< 520) before entry"))
      ((symbol FRFHF) (entry_date 2009-09-14)
       (detail
        "Virgin_territory but only 435 weekly bars (< 520) before entry"))
      ((symbol EVEP) (entry_date 2011-02-01)
       (detail
        "Virgin_territory but only 229 weekly bars (< 520) before entry"))
      ((symbol DTY) (entry_date 2007-09-24)
       (detail
        "Virgin_territory but only 181 weekly bars (< 520) before entry"))
      ((symbol DBI) (entry_date 2009-09-17)
       (detail
        "Virgin_territory but only 222 weekly bars (< 520) before entry"))
      ((symbol CVLT) (entry_date 2009-12-21)
       (detail
        "Virgin_territory but only 172 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 11)
    (n_skipped 57)
    (specimens
     (((symbol WTFC) (entry_date 2010-04-06)
       (detail "prior_top=46.07 within +25% of entry=39.46"))
      ((symbol WRLD) (entry_date 2010-03-12)
       (detail "prior_top=49.25 within +25% of entry=43.73"))
      ((symbol SAM) (entry_date 2007-06-05)
       (detail "prior_top=38.82 within +25% of entry=38.44"))
      ((symbol NVR) (entry_date 2011-01-24)
       (detail "prior_top=817.50 within +25% of entry=778.00"))
      ((symbol MMSI) (entry_date 2011-03-08)
       (detail "prior_top=16.51 within +25% of entry=14.30"))
      ((symbol KSL) (entry_date 2011-07-28)
       (detail "prior_top=6.67 within +25% of entry=6.58"))
      ((symbol HMY) (entry_date 2011-03-23)
       (detail "prior_top=14.22 within +25% of entry=13.02"))
      ((symbol FDO) (entry_date 2011-03-14)
       (detail "prior_top=52.55 within +25% of entry=52.09"))
      ((symbol CVLT) (entry_date 2010-10-06)
       (detail "prior_top=27.80 within +25% of entry=25.12"))
      ((symbol CHKP) (entry_date 2007-09-26)
       (detail "prior_top=25.87 within +25% of entry=25.21")))))
   ((id V10) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 57) (specimens ()))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 2)
    (n_skipped 0)
    (specimens
     (((symbol CCME) (entry_date 2010-12-03)
       (detail
        "installed_stop=12.8750 vs fill=15.1900 -> dist=0.1524 > gate=0.1500"))
      ((symbol AAON) (entry_date 2007-06-04)
       (detail
        "installed_stop=26.4772 vs fill=19.9700 -> dist=0.3258 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 3)
    (n_skipped 1)
    (specimens
     (((symbol WRLD) (entry_date 2010-03-12)
       (detail
        "exit_price=41.9300 outside 2010-03-15 bar [41.9301, 44.1000]"))
      ((symbol NPSNY) (entry_date 2009-08-28)
       (detail
        "entry_price=32.1200 outside 2009-08-28 bar [31.1960, 32.1180]"))
      ((symbol MMSI) (entry_date 2011-03-08)
       (detail
        "entry_price=14.3000 outside 2011-03-08 bar [17.0000, 17.8800]")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 14)
    (n_skipped 0)
    (specimens
     (((symbol WRLD) (entry_date 2010-03-12)
       (detail
        "entry bar 2010-03-12 open=43.0000 low=42.5200 close=43.6500 vs stop=41.9721, exit=41.9300"))
      ((symbol TIE) (entry_date 2010-05-13)
       (detail
        "entry bar 2010-05-13 open=17.1200 low=16.9400 close=17.4100 vs stop=16.9831, exit=16.8400"))
      ((symbol RBCAA) (entry_date 2012-01-30)
       (detail
        "entry bar 2012-01-30 open=25.0600 low=25.0500 close=26.5000 vs stop=25.8794, exit=25.8300"))
      ((symbol PKE) (entry_date 2007-08-10)
       (detail
        "entry bar 2007-08-10 open=32.8900 low=32.7401 close=33.0800 vs stop=32.3800, exit=32.3700"))
      ((symbol NEOG) (entry_date 2009-09-02)
       (detail
        "entry bar 2009-09-02 open=29.2820 low=29.2220 close=31.6112 vs stop=30.8158, exit=30.8000"))
      ((symbol EPRS) (entry_date 2011-01-19)
       (detail
        "entry bar 2011-01-19 open=127.2000 low=120.0000 close=120.6000 vs stop=109.8743, exit=109.7500"))
      ((symbol DOC) (entry_date 2011-03-21)
       (detail
        "entry bar 2011-03-21 open=38.2800 low=37.5900 close=37.6000 vs stop=36.7105, exit=36.6800"))
      ((symbol CPRT) (entry_date 2011-08-08)
       (detail
        "entry bar 2011-08-08 open=38.5600 low=37.4400 close=37.6000 vs stop=36.4315, exit=36.8500"))
      ((symbol CF) (entry_date 2009-12-16)
       (detail
        "entry bar 2009-12-16 open=89.3200 low=89.1600 close=92.5900 vs stop=88.6962, exit=88.6900"))
      ((symbol CASC1) (entry_date 2011-07-13)
       (detail
        "entry bar 2011-07-13 open=51.8800 low=51.5700 close=53.2400 vs stop=51.8718, exit=51.8000")))))
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
   ((id V21) (severity Expectation) (passed false) (n_violations 85)
    (n_skipped 0)
    (specimens
     (((symbol WTFC) (entry_date 2010-04-06)
       (detail
        "LONG installed_stop 37.8720 vs screener_proxy_stop 36.2940: 4.35% tighter > 3%"))
      ((symbol WSO) (entry_date 2010-03-08)
       (detail
        "LONG installed_stop 55.3750 vs screener_proxy_stop 53.2864: 3.92% tighter > 3%"))
      ((symbol WRLD) (entry_date 2010-03-12)
       (detail
        "LONG installed_stop 41.9712 vs screener_proxy_stop 40.2224: 4.35% tighter > 3%"))
      ((symbol UTL) (entry_date 2011-12-16)
       (detail
        "LONG installed_stop 26.8750 vs screener_proxy_stop 25.9348: 3.63% tighter > 3%"))
      ((symbol UPS) (entry_date 2012-03-19)
       (detail
        "LONG installed_stop 76.9152 vs screener_proxy_stop 73.7104: 4.35% tighter > 3%"))
      ((symbol UAA) (entry_date 2010-09-15)
       (detail
        "LONG installed_stop 43.3824 vs screener_proxy_stop 41.5748: 4.35% tighter > 3%"))
      ((symbol TOL) (entry_date 2012-05-24)
       (detail
        "LONG installed_stop 26.8750 vs screener_proxy_stop 25.8888: 3.81% tighter > 3%"))
      ((symbol TITN) (entry_date 2012-04-12)
       (detail
        "LONG installed_stop 33.2736 vs screener_proxy_stop 31.8872: 4.35% tighter > 3%"))
      ((symbol TIE) (entry_date 2010-05-13)
       (detail
        "LONG installed_stop 16.9824 vs screener_proxy_stop 16.2748: 4.35% tighter > 3%"))
      ((symbol SHW) (entry_date 2010-02-16)
       (detail
        "LONG installed_stop 61.8720 vs screener_proxy_stop 59.2940: 4.35% tighter > 3%")))))
   ((id V22) (severity Expectation) (passed false) (n_violations 11)
    (n_skipped 166)
    (specimens
     (((symbol ACIW) (entry_date 2012-02-10)
       (detail
        "no stop move for 18 weeks (2012-02-22..2012-06-28), 2 completed cycle(s) stalled; last: stop 36.38, candidate 12.69, ma 12.81, correction extreme 36.62 (extreme/ma 2.86)"))
      ((symbol AIT) (entry_date 2007-06-01)
       (detail
        "no stop move for 14 weeks (2012-01-10..2012-04-20), 1 completed cycle(s) stalled; last: stop 35.38, candidate 26.24, ma 26.50, correction extreme 36.19 (extreme/ma 1.37)"))
      ((symbol BWA) (entry_date 2010-01-29)
       (detail
        "no stop move for 67 weeks (2010-02-03..2011-05-20), 8 completed cycle(s) stalled; last: stop 32.38, candidate 25.69, ma 25.95, correction extreme 70.02 (extreme/ma 2.70)"))
      ((symbol COKE) (entry_date 2011-03-18)
       (detail
        "no stop move for 16 weeks (2011-03-21..2011-07-15), 1 completed cycle(s) stalled; last: stop 58.85, candidate 4.88, ma 5.08, correction extreme 61.07 (extreme/ma 12.02)"))
      ((symbol EBAY) (entry_date 2011-07-22)
       (detail
        "no stop move for 18 weeks (2012-02-23..2012-06-28), 3 completed cycle(s) stalled; last: stop 33.88, candidate 13.97, ma 14.12, correction extreme 38.00 (extreme/ma 2.69)"))
      ((symbol EQIX) (entry_date 2008-05-16)
       (detail
        "no stop move for 22 weeks (2012-01-26..2012-06-28), 1 completed cycle(s) stalled; last: stop 116.87, candidate 107.86, ma 108.95, correction extreme 146.48 (extreme/ma 1.34)"))
      ((symbol FICO) (entry_date 2011-02-18)
       (detail
        "no stop move for 17 weeks (2011-02-23..2011-06-24), 1 completed cycle(s) stalled; last: stop 25.88, candidate 25.33, ma 25.59, correction extreme 26.85 (extreme/ma 1.05)"))
      ((symbol GWW) (entry_date 2009-10-30)
       (detail
        "no stop move for 30 weeks (2009-11-02..2010-06-01), 1 completed cycle(s) stalled; last: stop 88.33, candidate 74.38, ma 75.37, correction extreme 95.56 (extreme/ma 1.27)"))
      ((symbol NPSNY) (entry_date 2008-05-30)
       (detail
        "no stop move for 22 weeks (2009-08-28..2010-01-29), 3 completed cycle(s) stalled; last: stop 30.38, candidate 0.88, ma 0.88, correction extreme 36.05 (extreme/ma 40.75)"))
      ((symbol UAA) (entry_date 2009-05-08)
       (detail
        "no stop move for 35 weeks (2010-09-15..2011-05-20), 3 completed cycle(s) stalled; last: stop 43.38, candidate 7.78, ma 7.86, correction extreme 64.34 (extreme/ma 8.19)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed false) (n_violations 22)
    (n_skipped 0)
    (specimens
     (((symbol WOR) (entry_date 2010-03-03)
       (detail "filled 2010-03-03 after the 2010-02-26 screen read Bearish"))
      ((symbol UTL) (entry_date 2011-12-16)
       (detail "filled 2011-12-16 after the 2011-12-09 screen read Bearish"))
      ((symbol UAA) (entry_date 2010-09-15)
       (detail "filled 2010-09-15 after the 2010-09-10 screen read Bearish"))
      ((symbol TOL) (entry_date 2012-05-24)
       (detail "filled 2012-05-24 after the 2012-05-18 screen read Bearish"))
      ((symbol SHW) (entry_date 2010-02-16)
       (detail "filled 2010-02-16 after the 2010-02-12 screen read Bearish"))
      ((symbol PKE) (entry_date 2007-08-10)
       (detail "filled 2007-08-10 after the 2007-08-03 screen read Bearish"))
      ((symbol NSP) (entry_date 2010-08-02)
       (detail "filled 2010-08-02 after the 2010-07-30 screen read Bearish"))
      ((symbol NKE) (entry_date 2011-10-14)
       (detail "filled 2011-10-14 after the 2011-10-07 screen read Bearish"))
      ((symbol MNTA) (entry_date 2010-07-23)
       (detail "filled 2010-07-23 after the 2010-07-16 screen read Bearish"))
      ((symbol HSY) (entry_date 2010-06-10)
       (detail "filled 2010-06-10 after the 2010-06-04 screen read Bearish")))))))
 (audit_join ((matched 104) (total 104))))
