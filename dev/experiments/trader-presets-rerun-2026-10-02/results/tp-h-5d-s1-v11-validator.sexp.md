# Post-run validation report

Invariant checks failing: 3
audit join: 103/103 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-trader-rerun/trading/test_data/share_classes.sexp)
V7 INVARIANT 12 violations
    UAA 2010-09-15 Virgin_territory but only 254 weekly bars (< 520) before entry
    TITN 2012-04-12 Virgin_territory but only 229 weekly bars (< 520) before entry
    ROVI 2007-06-06 Virgin_territory but only 496 weekly bars (< 520) before entry
    NPSNY 2009-08-28 Virgin_territory but only 351 weekly bars (< 520) before entry
    MNTA 2010-07-23 Virgin_territory but only 319 weekly bars (< 520) before entry
    FRFHF 2009-09-14 Virgin_territory but only 435 weekly bars (< 520) before entry
    EVEP 2011-02-01 Virgin_territory but only 229 weekly bars (< 520) before entry
    DTY 2007-09-24 Virgin_territory but only 181 weekly bars (< 520) before entry
    DBI 2009-09-17 Virgin_territory but only 222 weekly bars (< 520) before entry
    CVLT 2009-12-21 Virgin_territory but only 172 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 12 violations (53 skipped)
    WTFC 2010-04-06 prior_top=46.07 within +25% of entry=39.54
    WRLD 2010-03-12 prior_top=49.25 within +25% of entry=43.75
    SCI 2011-08-03 prior_top=10.17 within +25% of entry=9.99
    SAM 2007-06-05 prior_top=38.82 within +25% of entry=38.44
    NVR 2011-01-18 prior_top=817.50 within +25% of entry=788.82
    MMSI 2011-03-14 prior_top=16.51 within +25% of entry=14.28
    KSL 2011-07-28 prior_top=6.67 within +25% of entry=6.53
    HMY 2011-03-23 prior_top=14.22 within +25% of entry=13.28
    FDO 2011-03-14 prior_top=52.55 within +25% of entry=52.11
    CVLT 2010-10-06 prior_top=27.80 within +25% of entry=25.12
V10 EXPECTATION PASS (53 skipped)
V11 EXPECTATION PASS
V12 INVARIANT 2 violations
    CCME 2010-12-03 installed_stop=12.8750 vs fill=15.1900 -> dist=0.1524 > gate=0.1500
    AAON 2007-06-04 installed_stop=26.4772 vs fill=19.9700 -> dist=0.3258 > gate=0.1500
V13 INVARIANT 3 violations (1 skipped)
    WRLD 2010-03-12 exit_price=41.9300 outside 2010-03-15 bar [41.9301, 44.1000]
    NPSNY 2009-08-28 entry_price=32.1200 outside 2009-08-28 bar [31.1960, 32.1180]
    MMSI 2011-03-14 entry_price=14.2800 outside 2011-03-14 bar [17.5400, 17.9500]
V14 EXPECTATION 13 violations
    WRLD 2010-03-12 entry bar 2010-03-12 open=43.0000 low=42.5200 close=43.6500 vs stop=41.9694, exit=41.9300
    TIE 2010-05-13 entry bar 2010-05-13 open=17.1200 low=16.9400 close=17.4100 vs stop=16.9832, exit=16.9800
    RBCAA 2012-01-30 entry bar 2012-01-30 open=25.0600 low=25.0500 close=26.5000 vs stop=25.8699, exit=25.8700
    PKE 2007-08-10 entry bar 2007-08-10 open=32.8900 low=32.7401 close=33.0800 vs stop=32.3755, exit=32.3300
    NEOG 2009-09-02 entry bar 2009-09-02 open=29.2820 low=29.2220 close=31.6112 vs stop=30.8142, exit=30.8200
    DOC 2011-03-21 entry bar 2011-03-21 open=38.2800 low=37.5900 close=37.6000 vs stop=36.7105, exit=36.6700
    CPRT 2011-08-08 entry bar 2011-08-08 open=38.5600 low=37.4400 close=37.6000 vs stop=36.4315, exit=36.8500
    CF 2009-12-16 entry bar 2009-12-16 open=89.3200 low=89.1600 close=92.5900 vs stop=88.6916, exit=88.6900
    CASC1 2011-07-13 entry bar 2011-07-13 open=51.8800 low=51.5700 close=53.2400 vs stop=51.8730, exit=51.8200
    ASR 2009-12-17 entry bar 2009-12-17 open=54.7000 low=54.0500 close=54.4900 vs stop=53.8842, exit=53.8700
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION PASS
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 88 violations
    WTFC 2010-04-06 LONG installed_stop 37.8720 vs screener_proxy_stop 36.2940: 4.35% tighter > 3%
    WSO 2010-03-08 LONG installed_stop 55.3750 vs screener_proxy_stop 53.2864: 3.92% tighter > 3%
    WRLD 2010-03-12 LONG installed_stop 41.9712 vs screener_proxy_stop 40.2224: 4.35% tighter > 3%
    UTL 2011-12-16 LONG installed_stop 26.8750 vs screener_proxy_stop 25.9348: 3.63% tighter > 3%
    UPS 2012-03-19 LONG installed_stop 76.9152 vs screener_proxy_stop 73.7104: 4.35% tighter > 3%
    UAA 2010-09-15 LONG installed_stop 43.3824 vs screener_proxy_stop 41.5748: 4.35% tighter > 3%
    TOL 2012-05-24 LONG installed_stop 26.8750 vs screener_proxy_stop 25.8888: 3.81% tighter > 3%
    TITN 2012-04-12 LONG installed_stop 33.2736 vs screener_proxy_stop 31.8872: 4.35% tighter > 3%
    TIE 2010-05-13 LONG installed_stop 16.9824 vs screener_proxy_stop 16.2748: 4.35% tighter > 3%
    SHW 2010-02-16 LONG installed_stop 61.8720 vs screener_proxy_stop 59.2940: 4.35% tighter > 3%
V22 EXPECTATION 10 violations (167 skipped: position has no stop-decision rows)
    ACIW 2012-02-10 no stop move for 18 weeks (2012-02-22..2012-06-28), 2 completed cycle(s) stalled; last: stop 36.38, candidate 12.69, ma 12.81, correction extreme 36.62 (extreme/ma 2.86)
    AIT 2007-06-01 no stop move for 14 weeks (2012-01-10..2012-04-20), 1 completed cycle(s) stalled; last: stop 35.38, candidate 26.24, ma 26.50, correction extreme 36.19 (extreme/ma 1.37)
    BWA 2010-01-29 no stop move for 67 weeks (2010-02-03..2011-05-20), 8 completed cycle(s) stalled; last: stop 32.38, candidate 25.69, ma 25.95, correction extreme 70.02 (extreme/ma 2.70)
    EBAY 2011-07-22 no stop move for 18 weeks (2012-02-23..2012-06-28), 3 completed cycle(s) stalled; last: stop 33.88, candidate 13.97, ma 14.12, correction extreme 38.00 (extreme/ma 2.69)
    EQIX 2008-05-16 no stop move for 22 weeks (2012-01-26..2012-06-28), 1 completed cycle(s) stalled; last: stop 116.87, candidate 107.86, ma 108.95, correction extreme 146.48 (extreme/ma 1.34)
    FICO 2011-02-18 no stop move for 17 weeks (2011-02-23..2011-06-24), 1 completed cycle(s) stalled; last: stop 25.88, candidate 25.33, ma 25.59, correction extreme 26.85 (extreme/ma 1.05)
    GWW 2009-10-30 no stop move for 30 weeks (2009-11-02..2010-06-01), 1 completed cycle(s) stalled; last: stop 88.33, candidate 74.38, ma 75.37, correction extreme 95.56 (extreme/ma 1.27)
    NPSNY 2008-05-30 no stop move for 22 weeks (2009-08-28..2010-01-29), 3 completed cycle(s) stalled; last: stop 30.38, candidate 0.88, ma 0.88, correction extreme 36.05 (extreme/ma 40.75)
    UAA 2009-05-08 no stop move for 35 weeks (2010-09-15..2011-05-20), 3 completed cycle(s) stalled; last: stop 43.38, candidate 7.78, ma 7.86, correction extreme 64.34 (extreme/ma 8.19)
    USNA 2010-05-07 no stop move for 21 weeks (2010-05-11..2010-10-08), 2 completed cycle(s) stalled; last: stop 32.88, candidate 17.74, ma 17.91, correction extreme 38.07 (extreme/ma 2.13)
V23 EXPECTATION 23 violations
    WOR 2010-03-03 filled 2010-03-03 after the 2010-02-26 screen read Bearish
    UTL 2011-12-16 filled 2011-12-16 after the 2011-12-09 screen read Bearish
    UAA 2010-09-15 filled 2010-09-15 after the 2010-09-10 screen read Bearish
    TOL 2012-05-24 filled 2012-05-24 after the 2012-05-18 screen read Bearish
    SHW 2010-02-16 filled 2010-02-16 after the 2010-02-12 screen read Bearish
    SCI 2011-08-03 filled 2011-08-03 after the 2011-07-29 screen read Bearish
    PKE 2007-08-10 filled 2007-08-10 after the 2007-08-03 screen read Bearish
    NSP 2010-08-02 filled 2010-08-02 after the 2010-07-30 screen read Bearish
    NKE 2011-10-14 filled 2011-10-14 after the 2011-10-07 screen read Bearish
    MNTA 2010-07-23 filled 2010-07-23 after the 2010-07-16 screen read Bearish
