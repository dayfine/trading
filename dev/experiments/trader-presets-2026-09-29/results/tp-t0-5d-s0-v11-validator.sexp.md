# Post-run validation report

Invariant checks failing: 4
audit join: 130/130 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT 1 violations (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-trader/trading/test_data/share_classes.sexp)
    CMD 2009-06-08 twin positions: CMD/CMN
V7 INVARIANT 13 violations
    MNTA 2010-07-23 Virgin_territory but only 319 weekly bars (< 520) before entry
    MBT 2009-05-29 Virgin_territory but only 470 weekly bars (< 520) before entry
    IHG 2012-03-13 Virgin_territory but only 469 weekly bars (< 520) before entry
    GTLS 2011-07-01 Virgin_territory but only 259 weekly bars (< 520) before entry
    GTIV 2007-08-14 Virgin_territory but only 390 weekly bars (< 520) before entry
    EXLS 2012-02-29 Virgin_territory but only 282 weekly bars (< 520) before entry
    EW 2009-06-18 Virgin_territory but only 486 weekly bars (< 520) before entry
    DWA 2009-08-31 Virgin_territory but only 255 weekly bars (< 520) before entry
    CRM 2007-09-26 Virgin_territory but only 170 weekly bars (< 520) before entry
    CNC 2007-12-24 Virgin_territory but only 318 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 9 violations (69 skipped)
    TFX 2011-07-27 prior_top=67.00 within +25% of entry=64.38
    SCSC 2007-11-05 prior_top=37.19 within +25% of entry=34.35
    RADS 2007-07-30 prior_top=15.07 within +25% of entry=14.13
    MMSI 2011-03-14 prior_top=16.51 within +25% of entry=14.29
    HEW 2009-12-02 prior_top=41.94 within +25% of entry=41.79
    DPZ 2010-03-03 prior_top=15.79 within +25% of entry=13.81
    CML 2009-10-05 prior_top=18.55 within +25% of entry=17.92
    AU 2009-05-28 prior_top=46.92 within +25% of entry=39.19
    ARTG 2007-07-30 prior_top=3.77 within +25% of entry=3.23
V10 EXPECTATION 2 violations (69 skipped)
    RDN 2009-08-06 entry_wk_close=5.51 > prior=1.50 (spike>60%)
    AIG-WS 2009-08-20 entry_wk_close=32.85 > prior=12.46 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 3 violations
    ROL 2007-08-01 installed_stop=23.3472 vs fill=16.2200 -> dist=0.4394 > gate=0.1500
    MO 2011-04-11 installed_stop=22.4064 vs fill=26.4700 -> dist=0.1535 > gate=0.1500
    CCME 2010-12-03 installed_stop=12.8750 vs fill=15.1900 -> dist=0.1524 > gate=0.1500
V13 INVARIANT 8 violations
    SCVL 2011-06-24 exit_price=28.4600 outside 2011-08-05 bar [28.4602, 30.4900]
    ROL 2007-08-01 entry_price=16.2200 outside 2007-08-01 bar [23.7105, 24.3305]
    POWL 2007-09-26 exit_price=35.6600 outside 2007-09-27 bar [35.6601, 37.6800]
    MMSI 2011-03-14 entry_price=14.2900 outside 2011-03-14 bar [17.5400, 17.9500]
    FMC 2009-10-19 exit_price=55.5600 outside 2009-11-16 bar [55.5601, 57.0599]
    CMD 2009-06-08 exit_price=15.3100 outside 2009-06-12 bar [15.3101, 16.0901]
    ASX 2010-11-22 entry_price=3.7800 outside 2010-11-22 bar [3.7042, 3.7751]
    ANDW 2007-10-31 no bar on exit_date 2007-12-28 (nearest earlier bar: 2007-12-27)
V14 EXPECTATION 9 violations
    TG 2011-05-04 entry bar 2011-05-04 open=21.4600 low=20.7600 close=20.8200 vs stop=19.6617, exit=19.5300
    POWL 2007-09-26 entry bar 2007-09-26 open=36.1500 low=36.1500 close=37.6200 vs stop=35.9408, exit=35.6600
    GTIV 2007-08-14 entry bar 2007-08-14 open=22.4800 low=21.7400 close=22.1700 vs stop=21.3740, exit=21.3200
    GRMN 2012-05-02 entry bar 2012-05-02 open=49.9100 low=47.6700 close=49.3300 vs stop=48.1354, exit=48.1000
    DXPE 2008-08-14 entry bar 2008-08-14 open=53.0000 low=52.8900 close=54.2700 vs stop=51.9857, exit=51.9200
    DOC 2012-01-03 entry bar 2012-01-03 open=41.9400 low=41.6100 close=41.8800 vs stop=40.6765, exit=40.6300
    CLNE 2010-03-08 entry bar 2010-03-08 open=19.5100 low=19.4100 close=19.6300 vs stop=19.2522, exit=19.1900
    BIDU 2010-02-08 entry bar 2010-02-08 open=445.9200 low=441.7100 close=443.2300 vs stop=390.4476, exit=437.1900
    ANDE 2007-08-02 entry bar 2007-08-02 open=49.1700 low=44.5100 close=46.8600 vs stop=46.7508, exit=46.6200
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 3 violations
    EHC 2010-01-13 median close 16.63 over 6479 bars (1986-09-24..2012-06-01); bar 2006-10-26 close 23.75 (+400.00% vs prior close 4.75) on volume 0
    FLO 2010-05-10 median close 3.77 over 8128 bars (1980-03-17..2012-06-01); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    IHG 2012-03-13 median close 14.84 over 2305 bars (2003-04-08..2012-06-01); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 106 violations
    UTL 2011-12-16 LONG installed_stop 26.8750 vs screener_proxy_stop 25.9348: 3.63% tighter > 3%
    TYL 2009-10-14 LONG installed_stop 17.1360 vs screener_proxy_stop 16.4220: 4.35% tighter > 3%
    TYL 2011-03-01 LONG installed_stop 21.4080 vs screener_proxy_stop 20.5160: 4.35% tighter > 3%
    TRMB 2011-01-14 LONG installed_stop 41.6352 vs screener_proxy_stop 39.9004: 4.35% tighter > 3%
    TNC 2012-04-02 LONG installed_stop 43.2960 vs screener_proxy_stop 41.4920: 4.35% tighter > 3%
    TMO 2011-05-18 LONG installed_stop 60.3750 vs screener_proxy_stop 58.0336: 4.03% tighter > 3%
    TLRD 2007-07-27 LONG installed_stop 46.9536 vs screener_proxy_stop 44.9972: 4.35% tighter > 3%
    TGT 2012-02-29 LONG installed_stop 53.8750 vs screener_proxy_stop 51.7776: 4.05% tighter > 3%
    TG 2011-05-04 LONG installed_stop 19.6608 vs screener_proxy_stop 18.8416: 4.35% tighter > 3%
    SPLS_old 2009-12-15 LONG installed_stop 22.6944 vs screener_proxy_stop 21.7488: 4.35% tighter > 3%
V22 EXPECTATION 6 violations (146 skipped: position has no stop-decision rows)
    CRESY 2009-05-08 no stop move for 13 weeks (2010-09-24..2010-12-27), 1 completed cycle(s) stalled; last: stop 13.61, candidate 8.88, ma 9.12, correction extreme 14.77 (extreme/ma 1.62)
    NVO 2010-02-05 no stop move for 14 weeks (2010-02-09..2010-05-24), 1 completed cycle(s) stalled; last: stop 67.38, candidate 5.38, ma 5.59, correction extreme 74.90 (extreme/ma 13.39)
    ROL 2007-07-27 no stop move for 20 weeks (2007-08-01..2007-12-21), 1 completed cycle(s) stalled; last: stop 23.35, candidate 2.76, ma 2.79, correction extreme 24.94 (extreme/ma 8.95)
    SKX 2009-07-17 no stop move for 30 weeks (2009-10-16..2010-05-19), 4 completed cycle(s) stalled; last: stop 20.38, candidate 10.38, ma 10.65, correction extreme 32.07 (extreme/ma 3.01)
    TRMB 2008-05-16 no stop move for 15 weeks (2011-01-14..2011-05-02), 2 completed cycle(s) stalled; last: stop 41.64, candidate 23.88, ma 24.30, correction extreme 45.15 (extreme/ma 1.86)
    TYL 2011-02-25 no stop move for 13 weeks (2011-03-01..2011-06-02), 1 completed cycle(s) stalled; last: stop 21.41, candidate 21.33, ma 22.65, correction extreme 21.55 (extreme/ma 0.95)
V23 EXPECTATION 25 violations
    UTL 2011-12-16 filled 2011-12-16 after the 2011-12-09 screen read Bearish
    SCVL 2011-06-24 filled 2011-06-24 after the 2011-06-17 screen read Bearish
    RHT 2011-10-27 filled 2011-10-27 after the 2011-10-21 screen read Bearish
    RES 2008-07-23 filled 2008-07-23 after the 2008-07-18 screen read Bearish
    POWL 2007-09-26 filled 2007-09-26 after the 2007-09-21 screen read Bearish
    NXGN 2009-03-24 filled 2009-03-24 after the 2009-03-20 screen read Bearish
    NTTYY 2011-10-12 filled 2011-10-12 after the 2011-10-07 screen read Bearish
    MNTA 2010-07-23 filled 2010-07-23 after the 2010-07-16 screen read Bearish
    MANH 2010-03-05 filled 2010-03-05 after the 2010-02-26 screen read Bearish
    LNN 2007-11-28 filled 2007-11-28 after the 2007-11-23 screen read Bearish
