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
   ((id V7) (severity Invariant) (passed false) (n_violations 12)
    (n_skipped 0)
    (specimens
     (((symbol WDR) (entry_date 2007-06-20)
       (detail
        "Virgin_territory but only 488 weekly bars (< 520) before entry"))
      ((symbol TSM) (entry_date 2007-07-03)
       (detail
        "Virgin_territory but only 512 weekly bars (< 520) before entry"))
      ((symbol TSAT) (entry_date 2009-11-23)
       (detail
        "Virgin_territory but only 228 weekly bars (< 520) before entry"))
      ((symbol TRLG) (entry_date 2007-07-11)
       (detail
        "Virgin_territory but only 202 weekly bars (< 520) before entry"))
      ((symbol SINT1) (entry_date 2007-06-25)
       (detail
        "Virgin_territory but only 243 weekly bars (< 520) before entry"))
      ((symbol PXP) (entry_date 2009-06-11)
       (detail
        "Virgin_territory but only 342 weekly bars (< 520) before entry"))
      ((symbol LPS) (entry_date 2009-08-24)
       (detail
        "Virgin_territory but only 62 weekly bars (< 520) before entry"))
      ((symbol HRI) (entry_date 2010-12-01)
       (detail
        "Virgin_territory but only 213 weekly bars (< 520) before entry"))
      ((symbol EQIX) (entry_date 2008-05-29)
       (detail
        "Virgin_territory but only 411 weekly bars (< 520) before entry"))
      ((symbol CYOU) (entry_date 2011-02-01)
       (detail
        "Virgin_territory but only 96 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 14)
    (n_skipped 50)
    (specimens
     (((symbol TRLG) (entry_date 2007-07-11)
       (detail "prior_top=23.68 within +25% of entry=21.87"))
      ((symbol SINT1) (entry_date 2007-06-25)
       (detail "prior_top=35.15 within +25% of entry=33.11"))
      ((symbol PFCB) (entry_date 2010-10-05)
       (detail "prior_top=51.57 within +25% of entry=48.62"))
      ((symbol MRX_old) (entry_date 2011-03-30)
       (detail "prior_top=39.61 within +25% of entry=32.75"))
      ((symbol MMSI) (entry_date 2011-03-16)
       (detail "prior_top=16.51 within +25% of entry=14.60"))
      ((symbol LPS) (entry_date 2009-08-24)
       (detail "prior_top=39.95 within +25% of entry=35.06"))
      ((symbol IMGN) (entry_date 2010-04-15)
       (detail "prior_top=9.88 within +25% of entry=9.63"))
      ((symbol ICUI) (entry_date 2011-04-01)
       (detail "prior_top=47.79 within +25% of entry=44.29"))
      ((symbol HLIT) (entry_date 2008-06-17)
       (detail "prior_top=12.35 within +25% of entry=10.40"))
      ((symbol CRMT) (entry_date 2010-10-05)
       (detail "prior_top=26.71 within +25% of entry=26.64")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 50)
    (specimens
     (((symbol BONTQ) (entry_date 2012-03-13)
       (detail "entry_wk_close=8.01 > prior=4.45 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 11)
    (n_skipped 0)
    (specimens
     (((symbol MTZ) (entry_date 2008-07-16)
       (detail
        "installed_stop=10.3750 vs fill=12.2500 -> dist=0.1531 > gate=0.1500"))
      ((symbol KATE) (entry_date 2011-05-19)
       (detail
        "installed_stop=5.6736 vs fill=6.6900 -> dist=0.1519 > gate=0.1500"))
      ((symbol DXCM) (entry_date 2011-04-01)
       (detail
        "installed_stop=13.7472 vs fill=16.2300 -> dist=0.1530 > gate=0.1500"))
      ((symbol DENN) (entry_date 2010-11-03)
       (detail
        "installed_stop=2.8800 vs fill=3.4000 -> dist=0.1529 > gate=0.1500"))
      ((symbol CYOU) (entry_date 2011-02-01)
       (detail
        "installed_stop=31.2000 vs fill=36.7200 -> dist=0.1503 > gate=0.1500"))
      ((symbol CLC) (entry_date 2007-08-08)
       (detail
        "installed_stop=34.3750 vs fill=40.4900 -> dist=0.1510 > gate=0.1500"))
      ((symbol CASY) (entry_date 2007-09-06)
       (detail
        "installed_stop=25.3750 vs fill=29.8700 -> dist=0.1505 > gate=0.1500"))
      ((symbol BC) (entry_date 2012-02-03)
       (detail
        "installed_stop=19.9488 vs fill=23.4700 -> dist=0.1500 > gate=0.1500"))
      ((symbol ARCB) (entry_date 2009-06-01)
       (detail
        "installed_stop=24.8750 vs fill=29.3100 -> dist=0.1513 > gate=0.1500"))
      ((symbol ALV) (entry_date 2009-05-04)
       (detail
        "installed_stop=22.2209 vs fill=26.1800 -> dist=0.1512 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 4)
    (n_skipped 1)
    (specimens
     (((symbol MMSI) (entry_date 2011-03-16)
       (detail
        "entry_price=14.6000 outside 2011-03-16 bar [17.8400, 18.2500]"))
      ((symbol HLT1) (entry_date 2007-08-22)
       (detail
        "no bar on exit_date 2007-10-25 (nearest earlier bar: 2007-10-24)"))
      ((symbol GFF) (entry_date 2009-12-24)
       (detail
        "entry_price=12.4400 outside 2009-12-24 bar [12.2500, 12.4399]"))
      ((symbol ALD_old) (entry_date 2010-01-05)
       (detail
        "no bar on exit_date 2010-04-02 (nearest earlier bar: 2010-04-01)")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 0)
    (specimens
     (((symbol PETS) (entry_date 2012-05-04)
       (detail
        "entry bar 2012-05-04 open=13.0000 low=13.0000 close=13.7600 vs stop=11.9364, exit=11.8900")))))
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
   ((id V21) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V22) (severity Expectation) (passed false) (n_violations 20)
    (n_skipped 31)
    (specimens
     (((symbol ABCO) (entry_date 2009-05-29)
       (detail
        "no stop move for 14 weeks (2009-06-02..2009-09-11), 1 completed cycle(s) stalled; last: stop 21.40, candidate 10.88, ma 11.16, correction extreme 22.30 (extreme/ma 2.00)"))
      ((symbol ALK) (entry_date 2009-10-02)
       (detail
        "no stop move for 46 weeks (2009-10-14..2010-09-03), 9 completed cycle(s) stalled; last: stop 24.19, candidate 10.35, ma 10.46, correction extreme 42.00 (extreme/ma 4.02)"))
      ((symbol ALSK) (entry_date 2009-10-02)
       (detail
        "no stop move for 24 weeks (2010-07-27..2011-01-14), 1 completed cycle(s) stalled; last: stop 7.90, candidate 6.38, ma 6.60, correction extreme 8.44 (extreme/ma 1.28)"))
      ((symbol AWI) (entry_date 2009-07-31)
       (detail
        "no stop move for 24 weeks (2009-08-04..2010-01-22), 5 completed cycle(s) stalled; last: stop 22.76, candidate 17.37, ma 17.54, correction extreme 36.17 (extreme/ma 2.06)"))
      ((symbol B) (entry_date 2007-07-27)
       (detail
        "no stop move for 30 weeks (2007-09-06..2008-04-07), 4 completed cycle(s) stalled; last: stop 30.44, candidate 23.73, ma 23.97, correction extreme 45.00 (extreme/ma 1.88)"))
      ((symbol BAYRY) (entry_date 2009-08-14)
       (detail
        "no stop move for 20 weeks (2009-09-09..2010-01-29), 1 completed cycle(s) stalled; last: stop 57.19, candidate 9.48, ma 9.57, correction extreme 68.35 (extreme/ma 7.14)"))
      ((symbol BC) (entry_date 2012-01-27)
       (detail
        "no stop move for 16 weeks (2012-02-03..2012-05-25), 3 completed cycle(s) stalled; last: stop 19.95, candidate 18.44, ma 18.63, correction extreme 24.33 (extreme/ma 1.31)"))
      ((symbol CASY) (entry_date 2007-06-22)
       (detail
        "no stop move for 18 weeks (2007-09-06..2008-01-14), 1 completed cycle(s) stalled; last: stop 25.38, candidate 23.64, ma 23.88, correction extreme 27.00 (extreme/ma 1.13)"))
      ((symbol CMG) (entry_date 2010-02-05)
       (detail
        "no stop move for 51 weeks (2010-02-12..2011-02-04), 7 completed cycle(s) stalled; last: stop 89.88, candidate 3.43, ma 3.47, correction extreme 207.55 (extreme/ma 59.86)"))
      ((symbol EAT) (entry_date 2010-09-24)
       (detail
        "no stop move for 16 weeks (2010-09-30..2011-01-21), 1 completed cycle(s) stalled; last: stop 16.38, candidate 13.66, ma 13.80, correction extreme 17.96 (extreme/ma 1.30)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed false) (n_violations 21)
    (n_skipped 0)
    (specimens
     (((symbol STM) (entry_date 2011-06-27)
       (detail "filled 2011-06-27 after the 2011-06-24 screen read Bearish"))
      ((symbol RHI) (entry_date 2010-03-05)
       (detail "filled 2010-03-05 after the 2010-02-26 screen read Bearish"))
      ((symbol NSP) (entry_date 2010-08-02)
       (detail "filled 2010-08-02 after the 2010-07-30 screen read Bearish"))
      ((symbol MTZ) (entry_date 2008-07-16)
       (detail "filled 2008-07-16 after the 2008-07-11 screen read Bearish"))
      ((symbol LNN) (entry_date 2007-08-08)
       (detail "filled 2007-08-08 after the 2007-08-03 screen read Bearish"))
      ((symbol KOF) (entry_date 2008-01-02)
       (detail "filled 2008-01-02 after the 2007-12-28 screen read Bearish"))
      ((symbol HSY) (entry_date 2008-08-07)
       (detail "filled 2008-08-07 after the 2008-08-01 screen read Bearish"))
      ((symbol HLT1) (entry_date 2007-08-22)
       (detail "filled 2007-08-22 after the 2007-08-17 screen read Bearish"))
      ((symbol HE) (entry_date 2011-11-04)
       (detail "filled 2011-11-04 after the 2011-10-28 screen read Bearish"))
      ((symbol EQIX) (entry_date 2008-05-29)
       (detail "filled 2008-05-29 after the 2008-05-23 screen read Bearish")))))))
 (audit_join ((matched 106) (total 106))))
