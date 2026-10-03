# Post-run validation report

Invariant checks failing: 3
audit join: 72/72 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-anchor/trading/test_data/share_classes.sexp)
V7 INVARIANT 2 violations
    WDR 2007-07-13 Virgin_territory but only 491 weekly bars (< 520) before entry
    CYOU 2011-02-01 Virgin_territory but only 96 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 11 violations (44 skipped)
    SCSC 2007-11-05 prior_top=37.19 within +25% of entry=34.33
    PFCB 2010-10-05 prior_top=51.57 within +25% of entry=48.67
    OPSW 2007-06-29 prior_top=10.07 within +25% of entry=10.00
    ONTO 2011-01-24 prior_top=17.32 within +25% of entry=15.88
    MMSI 2011-03-14 prior_top=16.51 within +25% of entry=14.28
    HITK 2011-05-12 prior_top=27.38 within +25% of entry=26.43
    FDO 2011-03-14 prior_top=52.55 within +25% of entry=52.11
    CHKP 2007-09-26 prior_top=25.87 within +25% of entry=25.27
    CACI 2010-12-07 prior_top=65.75 within +25% of entry=53.21
    BWLD 2011-02-28 prior_top=54.48 within +25% of entry=53.66
V10 EXPECTATION PASS (44 skipped)
V11 EXPECTATION PASS
V12 INVARIANT 4 violations
    WDR 2007-07-13 installed_stop=23.8272 vs fill=28.0500 -> dist=0.1505 > gate=0.1500
    CYOU 2011-02-01 installed_stop=31.2000 vs fill=37.3100 -> dist=0.1638 > gate=0.1500
    CCME 2010-12-03 installed_stop=12.8750 vs fill=15.1900 -> dist=0.1524 > gate=0.1500
    AAON 2007-06-04 installed_stop=26.4772 vs fill=19.9700 -> dist=0.3258 > gate=0.1500
V13 INVARIANT 6 violations (1 skipped)
    OPSW 2007-06-29 no bar on exit_date 2007-09-21 (nearest earlier bar: 2007-09-20)
    NUAN 2010-12-10 exit_price=17.9300 outside 2011-03-07 bar [17.1166, 17.9259]
    MMSI 2011-03-14 entry_price=14.2800 outside 2011-03-14 bar [17.5400, 17.9500]
    FMC 2009-10-19 exit_price=55.5600 outside 2009-11-16 bar [55.5601, 57.0599]
    BCH 2009-12-02 entry_price=43.0500 outside 2009-12-02 bar [45.7674, 47.0205]
    AOS 2009-11-04 exit_price=42.6700 outside 2009-11-16 bar [42.6704, 43.6100]
V14 EXPECTATION 3 violations
    EPRS 2011-01-19 entry bar 2011-01-19 open=127.2000 low=120.0000 close=120.6000 vs stop=109.8743, exit=109.7500
    BX 2009-10-26 entry bar 2009-10-26 open=15.6428 low=14.7399 close=14.8184 vs stop=14.3639, exit=14.3600
    AAWW 2011-03-15 entry bar 2011-03-15 open=62.5800 low=61.4900 close=63.2900 vs stop=61.8728, exit=61.8400
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION PASS
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 12 violations
    POWI 2012-05-21 LONG installed_stop 39.3504 vs screener_proxy_stop 36.9656: 6.45% tighter > 3%
    NSIT 2011-03-07 LONG installed_stop 16.4544 vs screener_proxy_stop 15.6308: 5.27% tighter > 3%
    MNRO 2009-11-03 LONG installed_stop 28.6657 vs screener_proxy_stop 27.1860: 5.44% tighter > 3%
    ITT 2011-01-18 LONG installed_stop 56.4863 vs screener_proxy_stop 53.6176: 5.35% tighter > 3%
    FMS 2011-03-21 LONG installed_stop 61.2768 vs screener_proxy_stop 59.2848: 3.36% tighter > 3%
    DCI 2010-01-21 LONG installed_stop 39.9072 vs screener_proxy_stop 36.8184: 8.39% tighter > 3%
    CLC 2007-07-24 LONG installed_stop 34.3750 vs screener_proxy_stop 32.6600: 5.25% tighter > 3%
    CCU 2012-04-16 LONG installed_stop 68.9760 vs screener_proxy_stop 65.4856: 5.33% tighter > 3%
    BCH 2012-03-28 LONG installed_stop 82.2856 vs screener_proxy_stop 78.6968: 4.56% tighter > 3%
    AOS 2009-10-26 LONG installed_stop 39.8750 vs screener_proxy_stop 38.2996: 4.11% tighter > 3%
V22 EXPECTATION 13 violations (7 skipped: position has no stop-decision rows)
    AJG 2010-05-07 no stop move for 15 weeks (2010-05-11..2010-08-24), 1 completed cycle(s) stalled; last: stop 21.72, candidate 16.44, ma 16.61, correction extreme 23.66 (extreme/ma 1.42)
    AOS 2009-11-27 no stop move for 27 weeks (2009-11-30..2010-06-07), 2 completed cycle(s) stalled; last: stop 37.16, candidate 5.81, ma 5.87, correction extreme 48.43 (extreme/ma 8.25)
    BCH 2009-11-27 no stop move for 20 weeks (2009-12-02..2010-04-23), 1 completed cycle(s) stalled; last: stop 41.33, candidate 5.94, ma 6.00, correction extreme 48.25 (extreme/ma 8.04)
    BTI 2011-03-18 no stop move for 25 weeks (2011-03-30..2011-09-26), 2 completed cycle(s) stalled; last: stop 70.38, candidate 17.50, ma 17.68, correction extreme 84.37 (extreme/ma 4.77)
    BWA 2010-01-29 no stop move for 67 weeks (2010-02-03..2011-05-20), 8 completed cycle(s) stalled; last: stop 32.38, candidate 25.69, ma 25.95, correction extreme 70.02 (extreme/ma 2.70)
    CMG 2010-02-05 no stop move for 51 weeks (2010-02-08..2011-02-04), 8 completed cycle(s) stalled; last: stop 89.88, candidate 3.43, ma 3.47, correction extreme 207.55 (extreme/ma 59.86)
    CNH 2009-10-30 no stop move for 28 weeks (2009-11-05..2010-05-24), 4 completed cycle(s) stalled; last: stop 15.89, candidate 3.99, ma 4.03, correction extreme 18.74 (extreme/ma 4.65)
    FMS 2011-03-18 no stop move for 22 weeks (2011-03-21..2011-08-22), 1 completed cycle(s) stalled; last: stop 61.28, candidate 26.74, ma 27.01, correction extreme 68.87 (extreme/ma 2.55)
    GFF 2009-12-18 no stop move for 22 weeks (2009-12-22..2010-05-28), 3 completed cycle(s) stalled; last: stop 10.75, candidate 8.78, ma 8.87, correction extreme 12.28 (extreme/ma 1.38)
    KOF 2007-11-02 no stop move for 24 weeks (2007-12-31..2008-06-20), 3 completed cycle(s) stalled; last: stop 42.99, candidate 30.39, ma 30.70, correction extreme 51.04 (extreme/ma 1.66)
V23 EXPECTATION 6 violations
    POWI 2012-05-21 filled 2012-05-21 after the 2012-05-18 screen read Bearish
    KOF 2007-12-31 filled 2007-12-31 after the 2007-12-28 screen read Bearish
    DLX 2010-02-17 filled 2010-02-17 after the 2010-02-12 screen read Bearish
    CHKP 2007-09-26 filled 2007-09-26 after the 2007-09-21 screen read Bearish
    B 2007-08-10 filled 2007-08-10 after the 2007-08-03 screen read Bearish
    AGN 2012-05-29 filled 2012-05-29 after the 2012-05-25 screen read Bearish
