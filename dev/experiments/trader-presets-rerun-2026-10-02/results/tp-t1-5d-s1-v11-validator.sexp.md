# Post-run validation report

Invariant checks failing: 3
audit join: 103/103 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-trader-rerun/trading/test_data/share_classes.sexp)
V7 INVARIANT 15 violations
    UAA 2010-09-15 Virgin_territory but only 254 weekly bars (< 520) before entry
    TITN 2012-04-12 Virgin_territory but only 229 weekly bars (< 520) before entry
    ROVI 2007-06-06 Virgin_territory but only 496 weekly bars (< 520) before entry
    REXN 2011-02-14 Virgin_territory but only 326 weekly bars (< 520) before entry
    NPSNY 2009-08-28 Virgin_territory but only 351 weekly bars (< 520) before entry
    MOH 2011-01-27 Virgin_territory but only 398 weekly bars (< 520) before entry
    MNTA 2010-07-23 Virgin_territory but only 319 weekly bars (< 520) before entry
    IPSU 2011-06-02 Virgin_territory but only 427 weekly bars (< 520) before entry
    FRFHF 2009-09-14 Virgin_territory but only 435 weekly bars (< 520) before entry
    EVEP 2011-02-01 Virgin_territory but only 229 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 10 violations (57 skipped)
    WTFC 2010-04-06 prior_top=46.07 within +25% of entry=39.54
    WRLD 2010-03-12 prior_top=49.25 within +25% of entry=43.75
    SAM 2007-06-05 prior_top=38.82 within +25% of entry=38.44
    NSIT 2007-06-07 prior_top=25.19 within +25% of entry=21.26
    MFN 2011-03-21 prior_top=13.31 within +25% of entry=11.96
    FDO 2011-03-14 prior_top=52.55 within +25% of entry=52.11
    CHKP 2007-09-26 prior_top=25.87 within +25% of entry=25.27
    BWLD 2011-03-07 prior_top=54.48 within +25% of entry=53.28
    ASEI 2007-08-29 prior_top=72.70 within +25% of entry=71.62
    AAWW 2011-03-15 prior_top=72.26 within +25% of entry=62.58
V10 EXPECTATION 1 violations (57 skipped)
    IPSU 2011-06-02 entry_wk_close=21.47 > prior=12.99 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 3 violations
    FNSR 2009-08-24 installed_stop=0.7680 vs fill=6.4600 -> dist=0.8811 > gate=0.1500
    CCME 2010-12-03 installed_stop=12.8750 vs fill=15.1900 -> dist=0.1524 > gate=0.1500
    AAON 2007-06-04 installed_stop=26.4772 vs fill=19.9700 -> dist=0.3258 > gate=0.1500
V13 INVARIANT 2 violations (2 skipped)
    WRLD 2010-03-12 exit_price=41.9300 outside 2010-03-15 bar [41.9301, 44.1000]
    NPSNY 2009-08-28 entry_price=32.1200 outside 2009-08-28 bar [31.1960, 32.1180]
V14 EXPECTATION 11 violations
    WRLD 2010-03-12 entry bar 2010-03-12 open=43.0000 low=42.5200 close=43.6500 vs stop=41.9694, exit=41.9300
    TIE 2010-05-13 entry bar 2010-05-13 open=17.1200 low=16.9400 close=17.4100 vs stop=16.9832, exit=16.9800
    PKE 2007-08-10 entry bar 2007-08-10 open=32.8900 low=32.7401 close=33.0800 vs stop=32.3755, exit=32.3300
    NEOG 2009-09-02 entry bar 2009-09-02 open=29.2820 low=29.2220 close=31.6112 vs stop=30.8142, exit=30.8200
    MOH 2011-01-27 entry bar 2011-01-27 open=31.5300 low=31.1300 close=31.8800 vs stop=30.6848, exit=30.6500
    CPRT 2011-08-08 entry bar 2011-08-08 open=38.5600 low=37.4400 close=37.6000 vs stop=36.4315, exit=36.8500
    CF 2009-12-16 entry bar 2009-12-16 open=89.3200 low=89.1600 close=92.5900 vs stop=88.6916, exit=88.6900
    CASC1 2011-07-13 entry bar 2011-07-13 open=51.8800 low=51.5700 close=53.2400 vs stop=51.8730, exit=51.8200
    ANDE 2010-05-04 entry bar 2010-05-04 open=36.5201 low=36.0701 close=36.6200 vs stop=36.2387, exit=35.6700
    ACCO 2011-03-09 entry bar 2011-03-09 open=9.2500 low=9.2000 close=9.4700 vs stop=9.1344, exit=9.1300
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 1 violations
    REXN 2011-02-14 median close 667.20 over 1891 bars (2004-11-30..2012-06-01); bar 2004-12-15 close 10080.00 (+320.00% vs prior close 2400.00) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 85 violations
    WTFC 2010-04-06 LONG installed_stop 37.8720 vs screener_proxy_stop 36.2940: 4.35% tighter > 3%
    WSO 2010-03-08 LONG installed_stop 55.3750 vs screener_proxy_stop 53.2864: 3.92% tighter > 3%
    WRLD 2010-03-12 LONG installed_stop 41.9712 vs screener_proxy_stop 40.2224: 4.35% tighter > 3%
    VSEC 2009-10-26 LONG installed_stop 46.7328 vs screener_proxy_stop 44.7856: 4.35% tighter > 3%
    UTL 2011-12-16 LONG installed_stop 26.8750 vs screener_proxy_stop 25.9348: 3.63% tighter > 3%
    UPS 2012-03-19 LONG installed_stop 76.9152 vs screener_proxy_stop 73.7104: 4.35% tighter > 3%
    UAA 2010-09-15 LONG installed_stop 43.3824 vs screener_proxy_stop 41.5748: 4.35% tighter > 3%
    TOL 2012-05-24 LONG installed_stop 26.8750 vs screener_proxy_stop 25.8888: 3.81% tighter > 3%
    TITN 2012-04-12 LONG installed_stop 33.2736 vs screener_proxy_stop 31.8872: 4.35% tighter > 3%
    TIE 2010-05-13 LONG installed_stop 16.9824 vs screener_proxy_stop 16.2748: 4.35% tighter > 3%
V22 EXPECTATION 14 violations (161 skipped: position has no stop-decision rows)
    ACIW 2012-02-10 no stop move for 18 weeks (2012-02-22..2012-06-28), 2 completed cycle(s) stalled; last: stop 36.38, candidate 12.69, ma 12.81, correction extreme 36.62 (extreme/ma 2.86)
    AIT 2007-06-01 no stop move for 14 weeks (2012-01-10..2012-04-20), 1 completed cycle(s) stalled; last: stop 35.38, candidate 26.24, ma 26.50, correction extreme 36.19 (extreme/ma 1.37)
    CGNX 2009-07-10 no stop move for 21 weeks (2010-09-28..2011-02-25), 4 completed cycle(s) stalled; last: stop 23.88, candidate 6.19, ma 6.25, correction extreme 31.07 (extreme/ma 4.97)
    COKE 2011-03-18 no stop move for 16 weeks (2011-03-21..2011-07-15), 1 completed cycle(s) stalled; last: stop 58.85, candidate 4.88, ma 5.08, correction extreme 61.07 (extreme/ma 12.02)
    CRESY 2009-05-08 no stop move for 16 weeks (2010-09-24..2011-01-14), 1 completed cycle(s) stalled; last: stop 13.61, candidate 7.99, ma 8.08, correction extreme 14.77 (extreme/ma 1.83)
    EBAY 2011-07-22 no stop move for 18 weeks (2012-02-23..2012-06-28), 3 completed cycle(s) stalled; last: stop 33.88, candidate 13.97, ma 14.12, correction extreme 38.00 (extreme/ma 2.69)
    EQIX 2008-05-16 no stop move for 22 weeks (2012-01-26..2012-06-28), 1 completed cycle(s) stalled; last: stop 116.87, candidate 107.86, ma 108.95, correction extreme 146.48 (extreme/ma 1.34)
    EW 2009-11-13 no stop move for 34 weeks (2010-09-23..2011-05-20), 2 completed cycle(s) stalled; last: stop 32.94, candidate 12.88, ma 13.19, correction extreme 82.51 (extreme/ma 6.26)
    FICO 2011-02-25 no stop move for 16 weeks (2011-02-28..2011-06-24), 1 completed cycle(s) stalled; last: stop 25.88, candidate 25.33, ma 25.59, correction extreme 26.93 (extreme/ma 1.05)
    FNSR 2009-08-21 no stop move for 20 weeks (2009-09-23..2010-02-16), 1 completed cycle(s) stalled; last: stop 7.00, candidate 6.98, ma 8.35, correction extreme 7.05 (extreme/ma 0.84)
V23 EXPECTATION 23 violations
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
