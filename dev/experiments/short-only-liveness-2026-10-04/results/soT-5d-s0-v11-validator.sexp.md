# Post-run validation report

Invariant checks failing: 4
audit join: 175/175 rows matched

QUALITY-FLAG: 68 fallback exits (V16)

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT 3 violations (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-shortonly/trading/test_data/share_classes.sexp)
    HEI 2009-03-16 share-class overlap: HEI/HEI-A held together 2009-03-23..2009-04-02
    ASB 2009-02-23 twin positions: ASB/PACW
    CQB 2007-08-27 twin positions: CQB/HOFF
V7 INVARIANT PASS
V8 EXPECTATION PASS
V9 EXPECTATION PASS
V10 EXPECTATION PASS
V11 EXPECTATION 83 violations
    WFC-WS 2009-01-26 stop_distance=0.6163 outside [0.0000, 0.3000]
    WFC 2009-01-28 stop_distance=0.5636 outside [0.0000, 0.3000]
    VSAT 2008-02-04 stop_distance=0.3728 outside [0.0000, 0.3000]
    UMPQ 2009-01-12 stop_distance=0.4966 outside [0.0000, 0.3000]
    UMPQ 2009-01-20 stop_distance=0.5799 outside [0.0000, 0.3000]
    UCB 2009-02-02 stop_distance=0.7436 outside [0.0000, 0.3000]
    UCB 2009-02-17 stop_distance=0.8322 outside [0.0000, 0.3000]
    UBSI 2009-02-17 stop_distance=0.4565 outside [0.0000, 0.3000]
    UAL 2009-02-27 stop_distance=0.8166 outside [0.0000, 0.3000]
    TTC 2009-02-23 stop_distance=0.5134 outside [0.0000, 0.3000]
V12 INVARIANT 4 violations
    OC 2008-11-17 installed_stop=15.6250 vs fill=13.4700 -> dist=0.1600 > gate=0.1500
    NCR 2007-10-08 installed_stop=30.1704 vs fill=26.2300 -> dist=0.1502 > gate=0.1500
    BOKF 2008-07-21 installed_stop=50.8664 vs fill=44.0000 -> dist=0.1561 > gate=0.1500
    AZZ 2008-11-17 installed_stop=25.5112 vs fill=22.0800 -> dist=0.1554 > gate=0.1500
V13 INVARIANT 3 violations
    TREX 2009-03-02 exit_price=7.6200 outside 2009-03-06 bar [6.7600, 7.6176]
    NXGN 2008-12-22 entry_price=10.4000 outside 2008-12-22 bar [10.4025, 10.9375]
    EEQ 2007-10-01 exit_price=24.6900 outside 2007-10-31 bar [24.6942, 25.2648]
V14 EXPECTATION 4 violations
    MSM 2012-05-21 entry bar 2012-05-21 open=68.3100 low=67.7900 close=69.0600 vs stop=71.0424, exit=71.0700
    LHCG 2009-03-09 entry bar 2009-03-09 open=17.1200 low=16.9000 close=17.0000 vs stop=17.8459, exit=17.9400
    ESV 2010-05-07 entry bar 2010-05-07 open=43.2200 low=40.2400 close=41.4400 vs stop=42.7497, exit=42.8400
    CM 2007-12-10 entry bar 2007-12-10 open=78.5900 low=77.9500 close=80.2500 vs stop=81.7336, exit=81.8000
V15 EXPECTATION PASS
V16 EXPECTATION 68 violations
    WFC-WS 2009-01-26 margin_call exit 2009-01-27 (entry 2009-01-26 @ 15.83, exit @ 15.80)
    UMPQ 2009-01-12 margin_call exit 2009-01-13 (entry 2009-01-12 @ 10.33, exit @ 10.30)
    UMPQ 2009-01-20 margin_call exit 2009-01-21 (entry 2009-01-20 @ 9.20, exit @ 8.50)
    UCB 2009-02-02 margin_call exit 2009-02-03 (entry 2009-02-02 @ 5.08, exit @ 4.92)
    UCB 2009-02-17 margin_call exit 2009-02-18 (entry 2009-02-17 @ 3.30, exit @ 3.27)
    UBSI 2009-02-17 margin_call exit 2009-02-18 (entry 2009-02-17 @ 19.21, exit @ 17.64)
    UAL 2009-02-27 margin_call exit 2009-03-02 (entry 2009-02-27 @ 5.34, exit @ 4.71)
    TREX 2009-03-02 margin_call exit 2009-03-06 (entry 2009-03-02 @ 9.01, exit @ 7.62)
    SUSQ 2009-01-20 margin_call exit 2009-01-21 (entry 2009-01-20 @ 11.27, exit @ 10.37)
    SUSQ 2009-01-26 margin_call exit 2009-01-27 (entry 2009-01-26 @ 10.83, exit @ 11.04)
V17 EXPECTATION PASS
V18 EXPECTATION 2 violations
    BOKF 2008-07-21 median close 36.29 over 5231 bars (1991-09-05..2012-06-06); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    SSC 2011-09-06 median close 618.75 over 1271 bars (2007-05-23..2012-06-06); bar 2008-04-11 close 5625.00 (+96.08% vs prior close 2868.75) on volume 0
V19 INVARIANT PASS
V20 INVARIANT 1 violations
    NST 2009-01-05 adjusted_close_at_decision 0.76 / ma_value 6.10 = 0.12 outside [0.2, 5]
V21 EXPECTATION 175 violations
    ZBH 2007-08-06 SHORT installed_stop 80.1840 vs screener_proxy_stop 102.4380: 21.72% tighter > 3%
    WTFC 2010-08-06 SHORT installed_stop 32.3648 vs screener_proxy_stop 48.7620: 33.63% tighter > 3%
    WSO 2011-08-01 SHORT installed_stop 61.5472 vs screener_proxy_stop 79.6500: 22.73% tighter > 3%
    WFC-WS 2009-01-26 SHORT installed_stop 17.2536 vs screener_proxy_stop 48.5676: 64.48% tighter > 3%
    WFC 2009-01-28 SHORT installed_stop 19.6250 vs screener_proxy_stop 48.5676: 59.59% tighter > 3%
    VSAT 2008-02-04 SHORT installed_stop 22.6928 vs screener_proxy_stop 39.0744: 41.92% tighter > 3%
    UMPQ 2009-01-12 SHORT installed_stop 11.6896 vs screener_proxy_stop 25.0776: 53.39% tighter > 3%
    UMPQ 2009-01-20 SHORT installed_stop 9.7552 vs screener_proxy_stop 25.0776: 61.10% tighter > 3%
    UCB 2009-02-02 SHORT installed_stop 5.3560 vs screener_proxy_stop 22.5612: 76.26% tighter > 3%
    UCB 2009-02-17 SHORT installed_stop 3.5048 vs screener_proxy_stop 22.5612: 84.47% tighter > 3%
V22 EXPECTATION 8 violations (2 skipped: position has no stop-decision rows)
    AMRX 2011-07-01 no stop move for 25 weeks (2011-07-05..2011-12-27), 1 completed cycle(s) stalled; last: stop 23.12, candidate 23.73, ma 23.50, correction extreme 21.93 (extreme/ma 0.93)
    BLUD 2008-02-01 no stop move for 24 weeks (2008-02-04..2008-07-22), 1 completed cycle(s) stalled; last: stop 30.73, candidate 30.75, ma 30.45, correction extreme 30.32 (extreme/ma 1.00)
    DMND 2011-11-04 no stop move for 13 weeks (2011-11-07..2012-02-09), 2 completed cycle(s) stalled; last: stop 48.26, candidate 60.69, ma 60.09, correction extreme 30.81 (extreme/ma 0.51)
    DRWI 2011-05-27 no stop move for 35 weeks (2011-05-31..2012-02-06), 4 completed cycle(s) stalled; last: stop 180.70, candidate 3191.12, ma 3159.52, correction extreme 97.50 (extreme/ma 0.03)
    ERIE 2008-06-20 no stop move for 13 weeks (2008-07-03..2008-10-06), 1 completed cycle(s) stalled; last: stop 49.62, candidate 50.12, ma 27.54, correction extreme 49.49 (extreme/ma 1.80)
    FE 2010-02-12 no stop move for 13 weeks (2010-02-16..2010-05-20), 1 completed cycle(s) stalled; last: stop 40.76, candidate 41.12, ma 19.48, correction extreme 40.59 (extreme/ma 2.08)
    MO 2008-04-04 no stop move for 20 weeks (2008-04-29..2008-09-17), 1 completed cycle(s) stalled; last: stop 23.12, candidate 23.25, ma 11.67, correction extreme 23.02 (extreme/ma 1.97)
    NCR 2007-10-05 no stop move for 14 weeks (2007-10-08..2008-01-17), 2 completed cycle(s) stalled; last: stop 30.17, candidate 30.67, ma 30.37, correction extreme 25.59 (extreme/ma 0.84)
V23 EXPECTATION PASS
