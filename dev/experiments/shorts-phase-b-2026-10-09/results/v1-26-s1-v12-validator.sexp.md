# Post-run validation report

Invariant checks failing: 2
audit join: 167/167 rows matched

QUALITY-FLAG: 2 fallback exits (V16)

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-spb-B/trading/test_data/share_classes.sexp)
V7 INVARIANT PASS
V8 EXPECTATION PASS
V9 EXPECTATION PASS
V10 EXPECTATION PASS
V11 EXPECTATION PASS
V12 INVARIANT 12 violations
    SY2 2001-03-27 installed_stop=19.5655 vs fill=16.8200 -> dist=0.1632 > gate=0.1500
    RIG 2010-05-27 installed_stop=73.6632 vs fill=63.4200 -> dist=0.1615 > gate=0.1500
    GBLI 2007-08-09 installed_stop=22.8696 vs fill=19.8800 -> dist=0.1504 > gate=0.1500
    FFBC 2022-05-02 installed_stop=24.1488 vs fill=20.7900 -> dist=0.1616 > gate=0.1500
    EMN 2008-09-16 installed_stop=64.1250 vs fill=55.0700 -> dist=0.1644 > gate=0.1500
    EFII 2004-08-09 installed_stop=21.7672 vs fill=18.9000 -> dist=0.1517 > gate=0.1500
    DIN 2007-11-26 installed_stop=58.5104 vs fill=50.8000 -> dist=0.1518 > gate=0.1500
    CYOU 2011-10-05 installed_stop=30.6488 vs fill=26.1400 -> dist=0.1725 > gate=0.1500
    CGNX 2015-08-24 installed_stop=40.1250 vs fill=34.2800 -> dist=0.1705 > gate=0.1500
    ATAR_old 2001-04-09 installed_stop=57.2000 vs fill=49.3000 -> dist=0.1602 > gate=0.1500
V13 INVARIANT 3 violations
    DNA_old 2002-04-15 entry_price=18.8200 outside 2002-04-15 bar [18.8250, 19.9000]
    CELSIA 2008-02-05 no bar on exit_date 2008-03-24 (nearest earlier bar: 2008-03-19)
    BBVA 2008-01-29 exit_price=22.1900 outside 2008-03-24 bar [20.8500, 22.1899]
V14 EXPECTATION 3 violations
    PDLI 2001-01-29 entry bar 2001-01-29 open=71.7500 low=69.6250 close=73.8125 vs stop=75.3327, exit=75.5100
    BIP 2022-10-25 entry bar 2022-10-25 open=33.6400 low=33.6400 close=35.6200 vs stop=36.5110, exit=36.5200
    BBOX 2003-03-17 entry bar 2003-03-17 open=26.2500 low=26.2500 close=28.6800 vs stop=29.1231, exit=29.3300
V15 EXPECTATION PASS
V16 EXPECTATION 2 violations
    CELSIA 2008-02-05 stale_force_exit exit 2008-03-24 (entry 2008-02-05 @ 19819.24, exit @ 18520.00)
    AIG 2005-04-04 margin_call exit 2005-07-18 (entry 2005-04-04 @ 52.93, exit @ 60.95)
V17 EXPECTATION PASS
V18 EXPECTATION 4 violations
    BOKF 2008-08-11 median close 48.89 over 8520 bars (1991-09-05..2025-07-08); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    FLO 2003-01-10 median close 18.56 over 11420 bars (1980-03-17..2025-07-08); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    LTRE 2001-03-19 median close 9.94 over 5588 bars (1997-12-31..2025-07-08); bar 2023-04-20 close 1.05 (+425.00% vs prior close 0.20) on volume 0
    NST 2001-01-26 median close 29.16 over 4326 bars (1999-08-25..2018-01-30); bar 2013-01-07 close 8.60 (+10650.00% vs prior close 0.08) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 30 violations
    ZD 2016-03-21 SHORT installed_stop 55.6679 vs screener_proxy_stop 59.7780: 6.88% tighter > 3%
    WTRG 2002-06-17 SHORT installed_stop 21.0080 vs screener_proxy_stop 22.6692: 7.33% tighter > 3%
    WMT 2022-07-15 SHORT installed_stop 135.0960 vs screener_proxy_stop 141.8580: 4.77% tighter > 3%
    SRL 2007-12-26 SHORT installed_stop 22.7363 vs screener_proxy_stop 24.0300: 5.38% tighter > 3%
    SPLK 2022-05-16 SHORT installed_stop 106.2568 vs screener_proxy_stop 113.3136: 6.23% tighter > 3%
    SLAB 2025-04-14 SHORT installed_stop 97.2608 vs screener_proxy_stop 101.0124: 3.71% tighter > 3%
    SEE 2008-11-03 SHORT installed_stop 18.1250 vs screener_proxy_stop 18.9756: 4.48% tighter > 3%
    PM 2019-01-28 SHORT installed_stop 77.1576 vs screener_proxy_stop 81.8964: 5.79% tighter > 3%
    PL_old 2008-07-21 SHORT installed_stop 37.0448 vs screener_proxy_stop 38.6640: 4.19% tighter > 3%
    NVDA 2000-12-05 SHORT installed_stop 50.7062 vs screener_proxy_stop 53.7300: 5.63% tighter > 3%
V22 EXPECTATION 7 violations (59 skipped: position has no stop-decision rows)
    BVN 2004-05-07 no stop move for 19 weeks (2004-05-19..2004-10-05), 1 completed cycle(s) stalled; last: stop 24.12, candidate 24.19, ma 9.74, correction extreme 23.95 (extreme/ma 2.46)
    CARG 2022-05-13 no stop move for 13 weeks (2022-05-18..2022-08-22), 3 completed cycle(s) stalled; last: stop 26.78, candidate 28.09, ma 27.81, correction extreme 26.43 (extreme/ma 0.95)
    CAT 2022-07-08 no stop move for 15 weeks (2022-07-11..2022-10-27), 1 completed cycle(s) stalled; last: stop 200.82, candidate 202.37, ma 179.59, correction extreme 200.37 (extreme/ma 1.12)
    EFII 2004-08-06 no stop move for 32 weeks (2004-08-09..2005-03-24), 1 completed cycle(s) stalled; last: stop 21.77, candidate 23.73, ma 23.50, correction extreme 20.76 (extreme/ma 0.88)
    HSP 2006-09-01 no stop move for 21 weeks (2006-09-05..2007-02-05), 1 completed cycle(s) stalled; last: stop 39.62, candidate 39.84, ma 38.56, correction extreme 39.45 (extreme/ma 1.02)
    NOV 2014-10-17 no stop move for 18 weeks (2015-03-10..2015-07-15), 1 completed cycle(s) stalled; last: stop 56.73, candidate 57.21, ma 43.53, correction extreme 56.64 (extreme/ma 1.30)
    SONY 2000-10-20 no stop move for 16 weeks (2000-11-21..2001-03-14), 1 completed cycle(s) stalled; last: stop 79.57, candidate 80.12, ma 13.90, correction extreme 79.32 (extreme/ma 5.71)
V23 EXPECTATION PASS
