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
   ((id V6) (severity Invariant) (passed false) (n_violations 1)
    (n_skipped 0)
    (specimens
     (((symbol CMD) (entry_date 2009-06-08)
       (detail "twin positions: CMD/CMN"))))
    (skip_reason
     "share-class map: /workspaces/trading-1/.claude/worktrees/sweep-trader/trading/test_data/share_classes.sexp"))
   ((id V7) (severity Invariant) (passed false) (n_violations 13)
    (n_skipped 0)
    (specimens
     (((symbol MNTA) (entry_date 2010-07-23)
       (detail
        "Virgin_territory but only 319 weekly bars (< 520) before entry"))
      ((symbol MBT) (entry_date 2009-05-29)
       (detail
        "Virgin_territory but only 470 weekly bars (< 520) before entry"))
      ((symbol IHG) (entry_date 2012-03-13)
       (detail
        "Virgin_territory but only 469 weekly bars (< 520) before entry"))
      ((symbol GTLS) (entry_date 2011-07-01)
       (detail
        "Virgin_territory but only 259 weekly bars (< 520) before entry"))
      ((symbol GTIV) (entry_date 2007-08-14)
       (detail
        "Virgin_territory but only 390 weekly bars (< 520) before entry"))
      ((symbol EXLS) (entry_date 2012-02-29)
       (detail
        "Virgin_territory but only 282 weekly bars (< 520) before entry"))
      ((symbol EW) (entry_date 2009-06-18)
       (detail
        "Virgin_territory but only 486 weekly bars (< 520) before entry"))
      ((symbol DWA) (entry_date 2009-08-31)
       (detail
        "Virgin_territory but only 255 weekly bars (< 520) before entry"))
      ((symbol CRM) (entry_date 2007-09-26)
       (detail
        "Virgin_territory but only 170 weekly bars (< 520) before entry"))
      ((symbol CNC) (entry_date 2007-12-24)
       (detail
        "Virgin_territory but only 318 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 10)
    (n_skipped 64)
    (specimens
     (((symbol ZBRA) (entry_date 2011-05-09)
       (detail "prior_top=42.18 within +25% of entry=41.72"))
      ((symbol SCSC) (entry_date 2007-11-05)
       (detail "prior_top=37.19 within +25% of entry=34.32"))
      ((symbol RADS) (entry_date 2007-07-30)
       (detail "prior_top=15.07 within +25% of entry=14.14"))
      ((symbol MMSI) (entry_date 2011-03-14)
       (detail "prior_top=16.51 within +25% of entry=14.33"))
      ((symbol HEW) (entry_date 2009-12-02)
       (detail "prior_top=41.94 within +25% of entry=41.78"))
      ((symbol DPZ) (entry_date 2010-03-03)
       (detail "prior_top=15.79 within +25% of entry=13.78"))
      ((symbol CML) (entry_date 2009-10-05)
       (detail "prior_top=18.55 within +25% of entry=17.81"))
      ((symbol BHC) (entry_date 2010-03-11)
       (detail "prior_top=19.51 within +25% of entry=15.61"))
      ((symbol AU) (entry_date 2009-05-28)
       (detail "prior_top=46.92 within +25% of entry=39.18"))
      ((symbol ARTG) (entry_date 2007-07-30)
       (detail "prior_top=3.77 within +25% of entry=3.23")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 2)
    (n_skipped 64)
    (specimens
     (((symbol RDN) (entry_date 2009-08-06)
       (detail "entry_wk_close=5.51 > prior=1.50 (spike>60%)"))
      ((symbol AIG-WS) (entry_date 2009-08-20)
       (detail "entry_wk_close=32.85 > prior=12.46 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 2)
    (n_skipped 0)
    (specimens
     (((symbol ROL) (entry_date 2007-08-01)
       (detail
        "installed_stop=23.3472 vs fill=16.2200 -> dist=0.4394 > gate=0.1500"))
      ((symbol CCME) (entry_date 2010-12-03)
       (detail
        "installed_stop=12.8750 vs fill=15.1900 -> dist=0.1524 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 6)
    (n_skipped 0)
    (specimens
     (((symbol ROL) (entry_date 2007-08-01)
       (detail
        "entry_price=16.2200 outside 2007-08-01 bar [23.7105, 24.3305]"))
      ((symbol POWL) (entry_date 2007-09-26)
       (detail
        "exit_price=35.6600 outside 2007-09-27 bar [35.6601, 37.6800]"))
      ((symbol MMSI) (entry_date 2011-03-14)
       (detail
        "entry_price=14.3300 outside 2011-03-14 bar [17.5400, 17.9500]"))
      ((symbol FMC) (entry_date 2009-10-19)
       (detail
        "exit_price=55.5600 outside 2009-11-16 bar [55.5601, 57.0599]"))
      ((symbol CMD) (entry_date 2009-06-08)
       (detail
        "exit_price=15.3100 outside 2009-06-12 bar [15.3101, 16.0901]"))
      ((symbol ANDW) (entry_date 2007-10-31)
       (detail
        "no bar on exit_date 2007-12-28 (nearest earlier bar: 2007-12-27)")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 8)
    (n_skipped 0)
    (specimens
     (((symbol POWL) (entry_date 2007-09-26)
       (detail
        "entry bar 2007-09-26 open=36.1500 low=36.1500 close=37.6200 vs stop=35.9456, exit=35.6600"))
      ((symbol GTIV) (entry_date 2007-08-14)
       (detail
        "entry bar 2007-08-14 open=22.4800 low=21.7400 close=22.1700 vs stop=21.3740, exit=21.3200"))
      ((symbol GRMN) (entry_date 2012-05-02)
       (detail
        "entry bar 2012-05-02 open=49.9100 low=47.6700 close=49.3300 vs stop=48.1304, exit=48.1300"))
      ((symbol DXPE) (entry_date 2008-08-14)
       (detail
        "entry bar 2008-08-14 open=53.0000 low=52.8900 close=54.2700 vs stop=51.9790, exit=51.9700"))
      ((symbol DOC) (entry_date 2012-01-03)
       (detail
        "entry bar 2012-01-03 open=41.9400 low=41.6100 close=41.8800 vs stop=40.6721, exit=40.6700"))
      ((symbol CLNE) (entry_date 2010-03-08)
       (detail
        "entry bar 2010-03-08 open=19.5100 low=19.4100 close=19.6300 vs stop=19.2476, exit=19.2100"))
      ((symbol BIDU) (entry_date 2010-02-08)
       (detail
        "entry bar 2010-02-08 open=445.9200 low=441.7100 close=443.2300 vs stop=390.4476, exit=437.2400"))
      ((symbol ANDE) (entry_date 2007-08-02)
       (detail
        "entry bar 2007-08-02 open=49.1700 low=44.5100 close=46.8600 vs stop=46.7508, exit=46.7500")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol EHC) (entry_date 2010-01-13)
       (detail
        "median close 16.63 over 6479 bars (1986-09-24..2012-06-01); bar 2006-10-26 close 23.75 (+400.00% vs prior close 4.75) on volume 0"))
      ((symbol FLO) (entry_date 2010-05-10)
       (detail
        "median close 3.77 over 8128 bars (1980-03-17..2012-06-01); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0"))
      ((symbol IHG) (entry_date 2012-03-13)
       (detail
        "median close 14.84 over 2305 bars (2003-04-08..2012-06-01); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0")))))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V21) (severity Expectation) (passed false) (n_violations 103)
    (n_skipped 0)
    (specimens
     (((symbol ZBRA) (entry_date 2011-05-09)
       (detail
        "LONG installed_stop 39.8750 vs screener_proxy_stop 38.3548: 3.96% tighter > 3%"))
      ((symbol UTL) (entry_date 2011-12-16)
       (detail
        "LONG installed_stop 26.8750 vs screener_proxy_stop 25.9348: 3.63% tighter > 3%"))
      ((symbol TYL) (entry_date 2009-10-14)
       (detail
        "LONG installed_stop 17.1360 vs screener_proxy_stop 16.4220: 4.35% tighter > 3%"))
      ((symbol TYL) (entry_date 2011-03-01)
       (detail
        "LONG installed_stop 21.4080 vs screener_proxy_stop 20.5160: 4.35% tighter > 3%"))
      ((symbol TRMB) (entry_date 2011-01-14)
       (detail
        "LONG installed_stop 41.6352 vs screener_proxy_stop 39.9004: 4.35% tighter > 3%"))
      ((symbol TMO) (entry_date 2011-05-18)
       (detail
        "LONG installed_stop 60.3750 vs screener_proxy_stop 58.0336: 4.03% tighter > 3%"))
      ((symbol TLRD) (entry_date 2007-07-27)
       (detail
        "LONG installed_stop 46.9536 vs screener_proxy_stop 44.9972: 4.35% tighter > 3%"))
      ((symbol TGT) (entry_date 2012-02-29)
       (detail
        "LONG installed_stop 53.8750 vs screener_proxy_stop 51.7776: 4.05% tighter > 3%"))
      ((symbol STJ) (entry_date 2011-03-03)
       (detail
        "LONG installed_stop 46.7808 vs screener_proxy_stop 44.8316: 4.35% tighter > 3%"))
      ((symbol SPLS_old) (entry_date 2009-12-15)
       (detail
        "LONG installed_stop 22.6944 vs screener_proxy_stop 21.7488: 4.35% tighter > 3%")))))
   ((id V22) (severity Expectation) (passed false) (n_violations 6)
    (n_skipped 147)
    (specimens
     (((symbol CRESY) (entry_date 2009-05-08)
       (detail
        "no stop move for 13 weeks (2010-09-24..2010-12-27), 1 completed cycle(s) stalled; last: stop 13.61, candidate 8.88, ma 9.12, correction extreme 14.77 (extreme/ma 1.62)"))
      ((symbol NVO) (entry_date 2010-02-05)
       (detail
        "no stop move for 14 weeks (2010-02-09..2010-05-24), 1 completed cycle(s) stalled; last: stop 67.38, candidate 5.38, ma 5.59, correction extreme 74.90 (extreme/ma 13.39)"))
      ((symbol ROL) (entry_date 2007-07-27)
       (detail
        "no stop move for 20 weeks (2007-08-01..2007-12-21), 1 completed cycle(s) stalled; last: stop 23.35, candidate 2.76, ma 2.79, correction extreme 24.94 (extreme/ma 8.95)"))
      ((symbol SKX) (entry_date 2009-07-17)
       (detail
        "no stop move for 30 weeks (2009-10-16..2010-05-19), 4 completed cycle(s) stalled; last: stop 20.38, candidate 10.38, ma 10.65, correction extreme 32.07 (extreme/ma 3.01)"))
      ((symbol TRMB) (entry_date 2008-05-16)
       (detail
        "no stop move for 15 weeks (2011-01-14..2011-05-02), 2 completed cycle(s) stalled; last: stop 41.64, candidate 23.88, ma 24.30, correction extreme 45.15 (extreme/ma 1.86)"))
      ((symbol TYL) (entry_date 2011-02-25)
       (detail
        "no stop move for 13 weeks (2011-03-01..2011-06-02), 1 completed cycle(s) stalled; last: stop 21.41, candidate 21.33, ma 22.65, correction extreme 21.55 (extreme/ma 0.95)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed false) (n_violations 23)
    (n_skipped 0)
    (specimens
     (((symbol UTL) (entry_date 2011-12-16)
       (detail "filled 2011-12-16 after the 2011-12-09 screen read Bearish"))
      ((symbol RHT) (entry_date 2011-10-27)
       (detail "filled 2011-10-27 after the 2011-10-21 screen read Bearish"))
      ((symbol RES) (entry_date 2008-07-23)
       (detail "filled 2008-07-23 after the 2008-07-18 screen read Bearish"))
      ((symbol POWL) (entry_date 2007-09-26)
       (detail "filled 2007-09-26 after the 2007-09-21 screen read Bearish"))
      ((symbol NXGN) (entry_date 2009-03-24)
       (detail "filled 2009-03-24 after the 2009-03-20 screen read Bearish"))
      ((symbol NTTYY) (entry_date 2011-10-12)
       (detail "filled 2011-10-12 after the 2011-10-07 screen read Bearish"))
      ((symbol MNTA) (entry_date 2010-07-23)
       (detail "filled 2010-07-23 after the 2010-07-16 screen read Bearish"))
      ((symbol MANH) (entry_date 2010-03-05)
       (detail "filled 2010-03-05 after the 2010-02-26 screen read Bearish"))
      ((symbol LNN) (entry_date 2007-11-28)
       (detail "filled 2007-11-28 after the 2007-11-23 screen read Bearish"))
      ((symbol HSY) (entry_date 2010-06-10)
       (detail "filled 2010-06-10 after the 2010-06-04 screen read Bearish")))))))
 (audit_join ((matched 125) (total 125))))
