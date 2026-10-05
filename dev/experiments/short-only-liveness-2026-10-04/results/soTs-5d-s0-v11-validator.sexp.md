# Post-run validation report

Invariant checks failing: 3
audit join: 116/116 rows matched

QUALITY-FLAG: 50 fallback exits (V16)

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-shortonly/trading/test_data/share_classes.sexp)
V7 INVARIANT PASS
V8 EXPECTATION PASS
V9 EXPECTATION PASS
V10 EXPECTATION PASS
V11 EXPECTATION 50 violations
    ZION 2008-12-22 stop_distance=0.5008 outside [0.0000, 0.3000]
    WFC-WS 2009-02-02 stop_distance=0.5206 outside [0.0000, 0.3000]
    WFC 2009-01-26 stop_distance=0.6163 outside [0.0000, 0.3000]
    UNH 2009-04-06 stop_distance=0.4090 outside [0.0000, 0.3000]
    UMPQ 2009-01-12 stop_distance=0.4966 outside [0.0000, 0.3000]
    UFCS 2009-02-23 stop_distance=0.4728 outside [0.0000, 0.3000]
    UAL 2009-03-09 stop_distance=0.8339 outside [0.0000, 0.3000]
    TRN 2008-10-07 stop_distance=0.4439 outside [0.0000, 0.3000]
    TLEO 2008-10-15 stop_distance=0.5688 outside [0.0000, 0.3000]
    SUSQ 2009-01-20 stop_distance=0.4613 outside [0.0000, 0.3000]
V12 INVARIANT 16 violations
    ZION 2008-12-22 installed_stop=28.6250 vs fill=24.8600 -> dist=0.1514 > gate=0.1500
    WFC-WS 2009-02-02 installed_stop=21.5592 vs fill=18.5200 -> dist=0.1641 > gate=0.1500
    SUSQ 2009-01-20 installed_stop=13.0104 vs fill=11.2700 -> dist=0.1544 > gate=0.1500
    RJF 2008-01-22 installed_stop=31.6250 vs fill=27.4000 -> dist=0.1542 > gate=0.1500
    OC 2008-11-17 installed_stop=15.6250 vs fill=13.4700 -> dist=0.1600 > gate=0.1500
    NPBC 2009-01-20 installed_stop=12.0848 vs fill=10.5000 -> dist=0.1509 > gate=0.1500
    NGLOY 2008-08-04 installed_stop=26.1829 vs fill=22.4700 -> dist=0.1652 > gate=0.1500
    IAG 2011-11-21 installed_stop=21.7984 vs fill=18.9200 -> dist=0.1521 > gate=0.1500
    HPY 2008-07-28 installed_stop=25.6250 vs fill=22.2200 -> dist=0.1532 > gate=0.1500
    FNB 2008-06-30 installed_stop=14.0088 vs fill=12.1800 -> dist=0.1501 > gate=0.1500
V13 INVARIANT 2 violations
    NXGN 2008-12-22 entry_price=10.4000 outside 2008-12-22 bar [10.4025, 10.9375]
    EEQ 2007-10-01 exit_price=24.6900 outside 2007-10-31 bar [24.6942, 25.2648]
V14 EXPECTATION 2 violations
    ESV 2010-05-07 entry bar 2010-05-07 open=43.2200 low=40.2400 close=41.4400 vs stop=42.7497, exit=42.8400
    DLR 2007-08-06 entry bar 2007-08-06 open=34.7463 low=32.8955 close=35.1343 vs stop=36.1199, exit=36.2100
V15 EXPECTATION PASS
V16 EXPECTATION 50 violations
    WFC-WS 2009-02-02 margin_call exit 2009-02-06 (entry 2009-02-02 @ 18.52, exit @ 17.35)
    WFC 2009-01-26 margin_call exit 2009-01-27 (entry 2009-01-26 @ 15.83, exit @ 15.80)
    UNH 2009-04-06 margin_call exit 2009-04-08 (entry 2009-04-06 @ 20.33, exit @ 24.12)
    UMPQ 2009-01-12 margin_call exit 2009-01-13 (entry 2009-01-12 @ 10.33, exit @ 10.30)
    UFCS 2009-02-23 margin_call exit 2009-03-02 (entry 2009-02-23 @ 19.15, exit @ 16.54)
    UAL 2009-03-09 margin_call exit 2009-03-10 (entry 2009-03-09 @ 3.86, exit @ 4.02)
    TRN 2008-10-07 margin_call exit 2008-10-08 (entry 2008-10-07 @ 15.05, exit @ 13.16)
    TLEO 2008-10-15 margin_call exit 2008-10-16 (entry 2008-10-15 @ 13.51, exit @ 13.15)
    TCBI 2010-08-09 margin_call exit 2010-08-12 (entry 2010-08-09 @ 16.84, exit @ 16.10)
    SUSQ 2009-01-20 margin_call exit 2009-01-21 (entry 2009-01-20 @ 11.27, exit @ 10.37)
V17 EXPECTATION PASS
V18 EXPECTATION 2 violations
    ANG 2011-05-31 median close 264.00 over 3137 bars (2000-01-10..2012-06-27); bar 2000-03-21 close 0.00 (-100.00% vs prior close 149.79) on volume 0
    BOKF 2011-09-06 median close 36.52 over 5246 bars (1991-09-05..2012-06-27); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
V19 INVARIANT PASS
V20 INVARIANT 1 violations
    NST 2009-01-05 adjusted_close_at_decision 0.76 / ma_value 6.10 = 0.12 outside [0.2, 5]
V21 EXPECTATION 116 violations
    ZION 2008-12-22 SHORT installed_stop 28.6250 vs screener_proxy_stop 61.9272: 53.78% tighter > 3%
    WFC-WS 2009-02-02 SHORT installed_stop 21.5592 vs screener_proxy_stop 48.5676: 55.61% tighter > 3%
    WFC 2009-01-26 SHORT installed_stop 17.2536 vs screener_proxy_stop 48.5676: 64.48% tighter > 3%
    WBMD 2007-11-12 SHORT installed_stop 49.6250 vs screener_proxy_stop 63.6552: 22.04% tighter > 3%
    VMC 2012-05-29 SHORT installed_stop 38.1888 vs screener_proxy_stop 52.1964: 26.84% tighter > 3%
    UNH 2009-04-06 SHORT installed_stop 22.6304 vs screener_proxy_stop 41.3532: 45.28% tighter > 3%
    UMPQ 2009-01-12 SHORT installed_stop 11.6896 vs screener_proxy_stop 25.0776: 53.39% tighter > 3%
    UFCS 2009-02-23 SHORT installed_stop 20.8104 vs screener_proxy_stop 42.6276: 51.18% tighter > 3%
    UAL 2009-03-09 SHORT installed_stop 4.1496 vs screener_proxy_stop 26.9892: 84.62% tighter > 3%
    TRN 2008-10-07 SHORT installed_stop 16.5547 vs screener_proxy_stop 32.1516: 48.51% tighter > 3%
V22 EXPECTATION 2 violations (1 skipped: position has no stop-decision rows)
    DRWI 2011-05-27 no stop move for 35 weeks (2011-05-31..2012-02-06), 4 completed cycle(s) stalled; last: stop 180.70, candidate 3191.12, ma 3159.52, correction extreme 97.50 (extreme/ma 0.03)
    JEF 2011-08-12 no stop move for 13 weeks (2011-08-18..2011-11-23), 1 completed cycle(s) stalled; last: stop 30.34, candidate 30.34, ma 22.96, correction extreme 30.04 (extreme/ma 1.31)
V23 EXPECTATION PASS
