# Post-run validation report

Invariant checks failing: 3
audit join: 108/108 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-trader-rerun/trading/test_data/share_classes.sexp)
V7 INVARIANT 14 violations
    UAA 2010-09-15 Virgin_territory but only 254 weekly bars (< 520) before entry
    TITN 2012-04-12 Virgin_territory but only 229 weekly bars (< 520) before entry
    ROVI 2007-06-06 Virgin_territory but only 496 weekly bars (< 520) before entry
    NPSNY 2009-08-28 Virgin_territory but only 351 weekly bars (< 520) before entry
    MOH 2011-01-27 Virgin_territory but only 398 weekly bars (< 520) before entry
    MNTA 2010-07-23 Virgin_territory but only 319 weekly bars (< 520) before entry
    IPSU 2011-06-02 Virgin_territory but only 427 weekly bars (< 520) before entry
    FRFHF 2009-09-14 Virgin_territory but only 435 weekly bars (< 520) before entry
    EVEP 2011-02-01 Virgin_territory but only 229 weekly bars (< 520) before entry
    DBI 2009-09-17 Virgin_territory but only 222 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 10 violations (59 skipped)
    WTFC 2010-04-06 prior_top=46.07 within +25% of entry=39.54
    WRLD 2010-03-12 prior_top=49.25 within +25% of entry=43.75
    SAM 2007-06-05 prior_top=38.82 within +25% of entry=38.44
    NSIT 2007-06-07 prior_top=25.19 within +25% of entry=21.26
    KSL 2011-07-28 prior_top=6.67 within +25% of entry=6.53
    HMY 2011-03-23 prior_top=14.22 within +25% of entry=13.28
    FDO 2011-03-14 prior_top=52.55 within +25% of entry=52.11
    CHKP 2007-09-26 prior_top=25.87 within +25% of entry=25.27
    BWLD 2011-03-07 prior_top=54.48 within +25% of entry=53.28
    ASEI 2007-08-29 prior_top=72.70 within +25% of entry=71.62
V10 EXPECTATION 1 violations (59 skipped)
    IPSU 2011-06-02 entry_wk_close=21.47 > prior=12.99 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 3 violations
    FNSR 2009-08-24 installed_stop=0.7680 vs fill=6.4600 -> dist=0.8811 > gate=0.1500
    CCME 2010-12-03 installed_stop=12.8750 vs fill=15.1900 -> dist=0.1524 > gate=0.1500
    AAON 2007-06-04 installed_stop=26.4772 vs fill=19.9700 -> dist=0.3258 > gate=0.1500
V13 INVARIANT 3 violations (1 skipped)
    WRLD 2010-03-12 exit_price=41.9300 outside 2010-03-15 bar [41.9301, 44.1000]
    NPSNY 2009-08-28 entry_price=32.1200 outside 2009-08-28 bar [31.1960, 32.1180]
    FNSR 2009-08-24 exit_price=14.8200 outside 2010-04-28 bar [14.8250, 15.4600]
V14 EXPECTATION 12 violations
    WRLD 2010-03-12 entry bar 2010-03-12 open=43.0000 low=42.5200 close=43.6500 vs stop=41.9694, exit=41.9300
    TIE 2010-05-13 entry bar 2010-05-13 open=17.1200 low=16.9400 close=17.4100 vs stop=16.9832, exit=16.9800
    RBCAA 2012-01-30 entry bar 2012-01-30 open=25.0600 low=25.0500 close=26.5000 vs stop=25.8699, exit=25.8700
    PKE 2007-08-10 entry bar 2007-08-10 open=32.8900 low=32.7401 close=33.0800 vs stop=32.3755, exit=32.3300
    NEOG 2009-09-02 entry bar 2009-09-02 open=29.2820 low=29.2220 close=31.6112 vs stop=30.8142, exit=30.8200
    MOH 2011-01-27 entry bar 2011-01-27 open=31.5300 low=31.1300 close=31.8800 vs stop=30.6848, exit=30.6500
    DOC 2011-03-21 entry bar 2011-03-21 open=38.2800 low=37.5900 close=37.6000 vs stop=36.7105, exit=36.6700
    CPRT 2011-08-08 entry bar 2011-08-08 open=38.5600 low=37.4400 close=37.6000 vs stop=36.4315, exit=36.8500
    CF 2009-12-16 entry bar 2009-12-16 open=89.3200 low=89.1600 close=92.5900 vs stop=88.6916, exit=88.6900
    CASC1 2011-07-13 entry bar 2011-07-13 open=51.8800 low=51.5700 close=53.2400 vs stop=51.8730, exit=51.8200
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION PASS
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 92 violations
    WTFC 2010-04-06 LONG installed_stop 37.8720 vs screener_proxy_stop 36.2940: 4.35% tighter > 3%
    WSO 2010-03-08 LONG installed_stop 55.3750 vs screener_proxy_stop 53.2864: 3.92% tighter > 3%
    WRLD 2010-03-12 LONG installed_stop 41.9712 vs screener_proxy_stop 40.2224: 4.35% tighter > 3%
    WBS 2011-01-24 LONG installed_stop 21.8784 vs screener_proxy_stop 20.9668: 4.35% tighter > 3%
    VSEC 2009-10-26 LONG installed_stop 46.7328 vs screener_proxy_stop 44.7856: 4.35% tighter > 3%
    UTL 2011-12-16 LONG installed_stop 26.8750 vs screener_proxy_stop 25.9348: 3.63% tighter > 3%
    UPS 2012-03-19 LONG installed_stop 76.9152 vs screener_proxy_stop 73.7104: 4.35% tighter > 3%
    UAA 2010-09-15 LONG installed_stop 43.3824 vs screener_proxy_stop 41.5748: 4.35% tighter > 3%
    TOL 2012-05-24 LONG installed_stop 26.8750 vs screener_proxy_stop 25.8888: 3.81% tighter > 3%
    TITN 2012-04-12 LONG installed_stop 33.2736 vs screener_proxy_stop 31.8872: 4.35% tighter > 3%
V22 EXPECTATION 11 violations (158 skipped: position has no stop-decision rows)
    ACIW 2012-02-10 no stop move for 18 weeks (2012-02-22..2012-06-28), 2 completed cycle(s) stalled; last: stop 36.38, candidate 13.15, ma 13.29, correction extreme 36.62 (extreme/ma 2.76)
    AIT 2007-06-01 no stop move for 14 weeks (2012-01-10..2012-04-20), 1 completed cycle(s) stalled; last: stop 35.38, candidate 28.88, ma 29.29, correction extreme 36.19 (extreme/ma 1.24)
    CRESY 2009-05-08 no stop move for 16 weeks (2010-09-24..2011-01-14), 1 completed cycle(s) stalled; last: stop 13.61, candidate 8.88, ma 9.12, correction extreme 14.77 (extreme/ma 1.62)
    EBAY 2011-07-22 no stop move for 18 weeks (2012-02-23..2012-06-28), 3 completed cycle(s) stalled; last: stop 33.88, candidate 14.94, ma 15.09, correction extreme 38.00 (extreme/ma 2.52)
    EW 2009-11-13 no stop move for 34 weeks (2010-09-23..2011-05-20), 2 completed cycle(s) stalled; last: stop 32.94, candidate 14.47, ma 14.62, correction extreme 82.51 (extreme/ma 5.65)
    FMS 2011-02-25 no stop move for 21 weeks (2011-03-15..2011-08-15), 1 completed cycle(s) stalled; last: stop 61.86, candidate 27.88, ma 28.33, correction extreme 68.87 (extreme/ma 2.43)
    FNSR 2009-08-21 no stop move for 20 weeks (2009-09-23..2010-02-16), 1 completed cycle(s) stalled; last: stop 7.00, candidate 6.98, ma 9.12, correction extreme 7.05 (extreme/ma 0.77)
    GWW 2009-10-30 no stop move for 30 weeks (2009-11-02..2010-06-01), 1 completed cycle(s) stalled; last: stop 88.33, candidate 77.23, ma 78.01, correction extreme 95.56 (extreme/ma 1.22)
    NPSNY 2008-05-30 no stop move for 22 weeks (2009-08-28..2010-01-29), 3 completed cycle(s) stalled; last: stop 30.38, candidate 0.97, ma 0.98, correction extreme 36.05 (extreme/ma 36.95)
    UAA 2009-05-08 no stop move for 35 weeks (2010-09-15..2011-05-20), 3 completed cycle(s) stalled; last: stop 43.38, candidate 8.65, ma 8.73, correction extreme 64.34 (extreme/ma 7.37)
V23 EXPECTATION 25 violations
    WOR 2010-03-03 filled 2010-03-03 after the 2010-02-26 screen read Bearish
    UTL 2011-12-16 filled 2011-12-16 after the 2011-12-09 screen read Bearish
    UAA 2010-09-15 filled 2010-09-15 after the 2010-09-10 screen read Bearish
    TOL 2012-05-24 filled 2012-05-24 after the 2012-05-18 screen read Bearish
    SHW 2010-02-16 filled 2010-02-16 after the 2010-02-12 screen read Bearish
    PKE 2007-08-10 filled 2007-08-10 after the 2007-08-03 screen read Bearish
    NSP 2010-08-02 filled 2010-08-02 after the 2010-07-30 screen read Bearish
    NKE 2011-10-14 filled 2011-10-14 after the 2011-10-07 screen read Bearish
    MNTA 2010-07-23 filled 2010-07-23 after the 2010-07-16 screen read Bearish
    KSL 2007-09-04 filled 2007-09-04 after the 2007-08-31 screen read Bearish
