# Post-run validation report

Invariant checks failing: 3
audit join: 98/98 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 29 violations
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    UTHR 2002-11-21 Virgin_territory but only 180 weekly bars (< 520) before entry
    TLB 2004-06-07 Virgin_territory but only 340 weekly bars (< 520) before entry
    TBI1 2000-04-28 Virgin_territory but only 68 weekly bars (< 520) before entry
    PLCE 2004-11-10 Virgin_territory but only 377 weekly bars (< 520) before entry
    PHCC 2000-02-29 Virgin_territory but only 114 weekly bars (< 520) before entry
    NHYDY 2002-03-14 Virgin_territory but only 221 weekly bars (< 520) before entry
    NBIX 2001-11-21 Virgin_territory but only 289 weekly bars (< 520) before entry
    MSTR 2004-11-03 Virgin_territory but only 337 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 6 violations (65 skipped)
    TWX1 2000-01-28 prior_top=91.12 within +25% of entry=80.60
    TLB 2004-06-07 prior_top=42.90 within +25% of entry=38.89
    FLMIQ 2000-05-25 prior_top=16.44 within +25% of entry=13.78
    CWLZ 2003-06-13 prior_top=80.00 within +25% of entry=79.48
    ARTI_old 2004-05-19 prior_top=28.25 within +25% of entry=26.98
    ABNK_old 2004-05-01 prior_top=22.00 within +25% of entry=20.15
V10 EXPECTATION 1 violations (65 skipped)
    APWR 2000-01-24 entry_wk_close=15.33 > prior=9.33 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 4 violations
    TRMB 2003-11-24 installed_stop=25.8750 vs fill=19.6700 -> dist=0.3155 > gate=0.1500
    MMM 2003-07-26 installed_stop=131.9328 vs fill=69.6800 -> dist=0.8934 > gate=0.1500
    FULT 2002-03-07 installed_stop=23.3952 vs fill=19.5000 -> dist=0.1998 > gate=0.1500
    BKNG 2003-06-12 installed_stop=4.4256 vs fill=28.2100 -> dist=0.8431 > gate=0.1500
V13 INVARIANT 26 violations (2 skipped)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    TWX1 2000-01-28 exit_price=76.5600 outside 2000-02-23 bar [76.5630, 82.0000]
    TIMB 2003-09-13 no bar on entry_date 2003-09-13 (nearest earlier bar: 2003-09-12)
    TGT 2004-02-21 no bar on entry_date 2004-02-21 (nearest earlier bar: 2004-02-20)
    RYAAY 2003-10-18 no bar on entry_date 2003-10-18 (nearest earlier bar: 2003-10-17)
    RGEN 2000-02-05 no bar on entry_date 2000-02-05 (nearest earlier bar: 2000-02-04)
    ORLY 2004-05-01 no bar on entry_date 2004-05-01 (nearest earlier bar: 2004-04-30)
    NOV 2000-01-22 no bar on entry_date 2000-01-22 (nearest earlier bar: 2000-01-21)
    NEOG 2000-03-25 no bar on entry_date 2000-03-25 (nearest earlier bar: 2000-03-24)
    MMM 2003-07-26 no bar on entry_date 2003-07-26 (nearest earlier bar: 2003-07-25)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
