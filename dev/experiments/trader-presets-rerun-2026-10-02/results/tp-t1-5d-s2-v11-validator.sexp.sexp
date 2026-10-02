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
     "share-class map: /workspaces/trading-1/.claude/worktrees/sweep-trader-rerun/trading/test_data/share_classes.sexp"))
   ((id V7) (severity Invariant) (passed false) (n_violations 15)
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
      ((symbol REXN) (entry_date 2011-02-14)
       (detail
        "Virgin_territory but only 326 weekly bars (< 520) before entry"))
      ((symbol NPSNY) (entry_date 2009-08-28)
       (detail
        "Virgin_territory but only 351 weekly bars (< 520) before entry"))
      ((symbol MOH) (entry_date 2011-01-27)
       (detail
        "Virgin_territory but only 398 weekly bars (< 520) before entry"))
      ((symbol MNTA) (entry_date 2010-07-23)
       (detail
        "Virgin_territory but only 319 weekly bars (< 520) before entry"))
      ((symbol IPSU) (entry_date 2011-06-02)
       (detail
        "Virgin_territory but only 427 weekly bars (< 520) before entry"))
      ((symbol FRFHF) (entry_date 2009-09-14)
       (detail
        "Virgin_territory but only 435 weekly bars (< 520) before entry"))
      ((symbol EVEP) (entry_date 2011-02-01)
       (detail
        "Virgin_territory but only 229 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 10)
    (n_skipped 56)
    (specimens
     (((symbol WTFC) (entry_date 2010-04-06)
       (detail "prior_top=46.07 within +25% of entry=39.46"))
      ((symbol WRLD) (entry_date 2010-03-12)
       (detail "prior_top=49.25 within +25% of entry=43.73"))
      ((symbol SAM) (entry_date 2007-06-05)
       (detail "prior_top=38.82 within +25% of entry=38.44"))
      ((symbol NSIT) (entry_date 2007-06-07)
       (detail "prior_top=25.19 within +25% of entry=21.26"))
      ((symbol MFN) (entry_date 2011-03-21)
       (detail "prior_top=13.31 within +25% of entry=11.97"))
      ((symbol FDO) (entry_date 2011-03-14)
       (detail "prior_top=52.55 within +25% of entry=52.09"))
      ((symbol CHKP) (entry_date 2007-09-26)
       (detail "prior_top=25.87 within +25% of entry=25.21"))
      ((symbol BWLD) (entry_date 2011-03-07)
       (detail "prior_top=54.48 within +25% of entry=53.36"))
      ((symbol ASEI) (entry_date 2007-08-29)
       (detail "prior_top=72.70 within +25% of entry=71.67"))
      ((symbol AAWW) (entry_date 2011-03-15)
       (detail "prior_top=72.26 within +25% of entry=62.58")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 56)
    (specimens
     (((symbol IPSU) (entry_date 2011-06-02)
       (detail "entry_wk_close=21.47 > prior=12.99 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol FNSR) (entry_date 2009-08-24)
       (detail
        "installed_stop=0.7680 vs fill=6.5300 -> dist=0.8824 > gate=0.1500"))
      ((symbol CCME) (entry_date 2010-12-03)
       (detail
        "installed_stop=12.8750 vs fill=15.1900 -> dist=0.1524 > gate=0.1500"))
      ((symbol AAON) (entry_date 2007-06-04)
       (detail
        "installed_stop=26.4772 vs fill=19.9700 -> dist=0.3258 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 2)
    (n_skipped 2)
    (specimens
     (((symbol WRLD) (entry_date 2010-03-12)
       (detail
        "exit_price=41.9300 outside 2010-03-15 bar [41.9301, 44.1000]"))
      ((symbol NPSNY) (entry_date 2009-08-28)
       (detail
        "entry_price=32.1200 outside 2009-08-28 bar [31.1960, 32.1180]")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 11)
    (n_skipped 0)
    (specimens
     (((symbol WRLD) (entry_date 2010-03-12)
       (detail
        "entry bar 2010-03-12 open=43.0000 low=42.5200 close=43.6500 vs stop=41.9721, exit=41.9300"))
      ((symbol TIE) (entry_date 2010-05-13)
       (detail
        "entry bar 2010-05-13 open=17.1200 low=16.9400 close=17.4100 vs stop=16.9831, exit=16.8400"))
      ((symbol PKE) (entry_date 2007-08-10)
       (detail
        "entry bar 2007-08-10 open=32.8900 low=32.7401 close=33.0800 vs stop=32.3800, exit=32.3700"))
      ((symbol NEOG) (entry_date 2009-09-02)
       (detail
        "entry bar 2009-09-02 open=29.2820 low=29.2220 close=31.6112 vs stop=30.8158, exit=30.8000"))
      ((symbol MOH) (entry_date 2011-01-27)
       (detail
        "entry bar 2011-01-27 open=31.5300 low=31.1300 close=31.8800 vs stop=30.6848, exit=30.5800"))
      ((symbol CPRT) (entry_date 2011-08-08)
       (detail
        "entry bar 2011-08-08 open=38.5600 low=37.4400 close=37.6000 vs stop=36.4315, exit=36.8500"))
      ((symbol CF) (entry_date 2009-12-16)
       (detail
        "entry bar 2009-12-16 open=89.3200 low=89.1600 close=92.5900 vs stop=88.6962, exit=88.6900"))
      ((symbol CASC1) (entry_date 2011-07-13)
       (detail
        "entry bar 2011-07-13 open=51.8800 low=51.5700 close=53.2400 vs stop=51.8718, exit=51.8000"))
      ((symbol ANDE) (entry_date 2010-05-04)
       (detail
        "entry bar 2010-05-04 open=36.5201 low=36.0701 close=36.6200 vs stop=36.2387, exit=35.6700"))
      ((symbol ACCO) (entry_date 2011-03-09)
       (detail
        "entry bar 2011-03-09 open=9.2500 low=9.2000 close=9.4700 vs stop=9.1431, exit=9.0200")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 0)
    (specimens
     (((symbol REXN) (entry_date 2011-02-14)
       (detail
        "median close 667.20 over 1891 bars (2004-11-30..2012-06-01); bar 2004-12-15 close 10080.00 (+320.00% vs prior close 2400.00) on volume 0")))))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V21) (severity Expectation) (passed false) (n_violations 84)
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
      ((symbol VSEC) (entry_date 2009-10-26)
       (detail
        "LONG installed_stop 46.7328 vs screener_proxy_stop 44.7856: 4.35% tighter > 3%"))
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
        "LONG installed_stop 16.9824 vs screener_proxy_stop 16.2748: 4.35% tighter > 3%")))))
   ((id V22) (severity Expectation) (passed false) (n_violations 14)
    (n_skipped 161)
    (specimens
     (((symbol ACIW) (entry_date 2012-02-10)
       (detail
        "no stop move for 18 weeks (2012-02-22..2012-06-28), 2 completed cycle(s) stalled; last: stop 36.38, candidate 12.69, ma 12.81, correction extreme 36.62 (extreme/ma 2.86)"))
      ((symbol AIT) (entry_date 2007-06-01)
       (detail
        "no stop move for 14 weeks (2012-01-10..2012-04-20), 1 completed cycle(s) stalled; last: stop 35.38, candidate 26.24, ma 26.50, correction extreme 36.19 (extreme/ma 1.37)"))
      ((symbol CGNX) (entry_date 2009-07-10)
       (detail
        "no stop move for 21 weeks (2010-09-28..2011-02-25), 4 completed cycle(s) stalled; last: stop 23.88, candidate 6.19, ma 6.25, correction extreme 31.07 (extreme/ma 4.97)"))
      ((symbol COKE) (entry_date 2011-03-18)
       (detail
        "no stop move for 16 weeks (2011-03-21..2011-07-15), 1 completed cycle(s) stalled; last: stop 58.85, candidate 4.88, ma 5.08, correction extreme 61.07 (extreme/ma 12.02)"))
      ((symbol CRESY) (entry_date 2009-05-08)
       (detail
        "no stop move for 16 weeks (2010-09-24..2011-01-14), 1 completed cycle(s) stalled; last: stop 13.61, candidate 7.99, ma 8.08, correction extreme 14.77 (extreme/ma 1.83)"))
      ((symbol EBAY) (entry_date 2011-07-22)
       (detail
        "no stop move for 18 weeks (2012-02-23..2012-06-28), 3 completed cycle(s) stalled; last: stop 33.88, candidate 13.97, ma 14.12, correction extreme 38.00 (extreme/ma 2.69)"))
      ((symbol EQIX) (entry_date 2008-05-16)
       (detail
        "no stop move for 22 weeks (2012-01-26..2012-06-28), 1 completed cycle(s) stalled; last: stop 116.87, candidate 107.86, ma 108.95, correction extreme 146.48 (extreme/ma 1.34)"))
      ((symbol EW) (entry_date 2009-11-13)
       (detail
        "no stop move for 34 weeks (2010-09-23..2011-05-20), 2 completed cycle(s) stalled; last: stop 32.94, candidate 12.88, ma 13.19, correction extreme 82.51 (extreme/ma 6.26)"))
      ((symbol FICO) (entry_date 2011-02-25)
       (detail
        "no stop move for 16 weeks (2011-02-28..2011-06-24), 1 completed cycle(s) stalled; last: stop 25.88, candidate 25.33, ma 25.59, correction extreme 26.93 (extreme/ma 1.05)"))
      ((symbol FNSR) (entry_date 2009-08-21)
       (detail
        "no stop move for 20 weeks (2009-09-23..2010-02-16), 1 completed cycle(s) stalled; last: stop 7.00, candidate 6.98, ma 8.35, correction extreme 7.05 (extreme/ma 0.84)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed false) (n_violations 23)
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
      ((symbol KSL) (entry_date 2007-09-04)
       (detail "filled 2007-09-04 after the 2007-08-31 screen read Bearish")))))))
 (audit_join ((matched 102) (total 102))))
