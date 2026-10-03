# Post-run validation report

Invariant checks failing: 3
audit join: 113/113 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-anchor/trading/test_data/share_classes.sexp)
V7 INVARIANT 13 violations
    WDR 2007-06-20 Virgin_territory but only 488 weekly bars (< 520) before entry
    TSM 2007-07-03 Virgin_territory but only 512 weekly bars (< 520) before entry
    TSAT 2009-11-23 Virgin_territory but only 228 weekly bars (< 520) before entry
    TRLG 2007-07-11 Virgin_territory but only 202 weekly bars (< 520) before entry
    SINT1 2007-06-25 Virgin_territory but only 243 weekly bars (< 520) before entry
    PXP 2009-06-11 Virgin_territory but only 342 weekly bars (< 520) before entry
    LPS 2009-08-24 Virgin_territory but only 62 weekly bars (< 520) before entry
    HRI 2010-12-01 Virgin_territory but only 213 weekly bars (< 520) before entry
    EQNR 2007-06-18 Virgin_territory but only 316 weekly bars (< 520) before entry
    EQIX 2008-05-29 Virgin_territory but only 411 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 13 violations (57 skipped)
    TRLG 2007-07-11 prior_top=23.68 within +25% of entry=21.86
    SINT1 2007-06-25 prior_top=35.15 within +25% of entry=33.11
    PFCB 2010-10-05 prior_top=51.57 within +25% of entry=48.71
    MRX_old 2011-03-30 prior_top=39.61 within +25% of entry=32.73
    MMSI 2011-03-16 prior_top=16.51 within +25% of entry=14.60
    LPS 2009-08-24 prior_top=39.95 within +25% of entry=35.03
    HLIT 2008-06-17 prior_top=12.35 within +25% of entry=10.43
    CRMT 2010-10-05 prior_top=26.71 within +25% of entry=26.63
    CI 2012-03-14 prior_top=50.29 within +25% of entry=46.26
    CACI 2010-12-07 prior_top=65.75 within +25% of entry=53.21
V10 EXPECTATION 1 violations (57 skipped)
    BONTQ 2012-03-13 entry_wk_close=8.01 > prior=4.45 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 6 violations
    NWBI 2009-12-07 installed_stop=20.2848 vs fill=10.4500 -> dist=0.9411 > gate=0.1500
    EQNR 2007-06-18 installed_stop=24.8750 vs fill=29.3000 -> dist=0.1510 > gate=0.1500
    DENN 2010-11-03 installed_stop=2.8800 vs fill=3.4000 -> dist=0.1529 > gate=0.1500
    CASY 2007-09-06 installed_stop=25.3750 vs fill=29.8700 -> dist=0.1505 > gate=0.1500
    BC 2012-02-03 installed_stop=19.9488 vs fill=23.5300 -> dist=0.1522 > gate=0.1500
    AAON 2007-06-19 installed_stop=26.4772 vs fill=20.4000 -> dist=0.2979 > gate=0.1500
V13 INVARIANT 5 violations (2 skipped)
    TSM 2007-07-03 entry_price=11.4800 outside 2007-07-03 bar [11.3268, 11.4776]
    NJDCY 2012-01-17 entry_price=23.0300 outside 2012-01-17 bar [23.0304, 23.2200]
    MMSI 2011-03-16 entry_price=14.6000 outside 2011-03-16 bar [17.8400, 18.2500]
    HLT1 2007-08-22 no bar on exit_date 2007-10-25 (nearest earlier bar: 2007-10-24)
    FFIN 2009-07-15 exit_price=51.7600 outside 2009-07-27 bar [51.7604, 52.7100]
V14 EXPECTATION 1 violations
    PETS 2012-05-04 entry bar 2012-05-04 open=13.0000 low=13.0000 close=13.7600 vs stop=11.9295, exit=11.8700
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION PASS
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION PASS
V22 EXPECTATION 20 violations (36 skipped: position has no stop-decision rows)
    ABCO 2009-05-29 no stop move for 14 weeks (2009-06-02..2009-09-11), 1 completed cycle(s) stalled; last: stop 21.40, candidate 10.88, ma 11.16, correction extreme 22.30 (extreme/ma 2.00)
    ALK 2009-10-02 no stop move for 46 weeks (2009-10-14..2010-09-03), 9 completed cycle(s) stalled; last: stop 24.19, candidate 10.35, ma 10.46, correction extreme 42.00 (extreme/ma 4.02)
    ALSK 2009-10-02 no stop move for 24 weeks (2010-07-27..2011-01-14), 1 completed cycle(s) stalled; last: stop 7.90, candidate 6.38, ma 6.60, correction extreme 8.44 (extreme/ma 1.28)
    AWI 2009-07-31 no stop move for 24 weeks (2009-08-04..2010-01-22), 5 completed cycle(s) stalled; last: stop 22.76, candidate 17.37, ma 17.54, correction extreme 36.17 (extreme/ma 2.06)
    B 2007-07-27 no stop move for 30 weeks (2007-09-06..2008-04-07), 4 completed cycle(s) stalled; last: stop 30.44, candidate 23.73, ma 23.97, correction extreme 45.00 (extreme/ma 1.88)
    BAYRY 2009-08-14 no stop move for 20 weeks (2009-09-09..2010-01-29), 1 completed cycle(s) stalled; last: stop 57.19, candidate 9.48, ma 9.57, correction extreme 68.35 (extreme/ma 7.14)
    BC 2012-01-27 no stop move for 16 weeks (2012-02-03..2012-05-25), 3 completed cycle(s) stalled; last: stop 19.95, candidate 18.44, ma 18.63, correction extreme 24.33 (extreme/ma 1.31)
    CASY 2007-06-22 no stop move for 18 weeks (2007-09-06..2008-01-14), 1 completed cycle(s) stalled; last: stop 25.38, candidate 23.64, ma 23.88, correction extreme 27.00 (extreme/ma 1.13)
    CMG 2010-02-05 no stop move for 51 weeks (2010-02-12..2011-02-04), 7 completed cycle(s) stalled; last: stop 89.88, candidate 3.43, ma 3.47, correction extreme 207.55 (extreme/ma 59.86)
    EAT 2010-09-24 no stop move for 16 weeks (2010-09-30..2011-01-21), 1 completed cycle(s) stalled; last: stop 16.38, candidate 13.66, ma 13.80, correction extreme 17.96 (extreme/ma 1.30)
V23 EXPECTATION 22 violations
    STM 2011-06-27 filled 2011-06-27 after the 2011-06-24 screen read Bearish
    RHI 2010-03-05 filled 2010-03-05 after the 2010-02-26 screen read Bearish
    NVS 2010-02-19 filled 2010-02-19 after the 2010-02-12 screen read Bearish
    NSP 2010-08-02 filled 2010-08-02 after the 2010-07-30 screen read Bearish
    MTZ 2008-07-16 filled 2008-07-16 after the 2008-07-11 screen read Bearish
    LNN 2007-08-08 filled 2007-08-08 after the 2007-08-03 screen read Bearish
    KOF 2008-01-02 filled 2008-01-02 after the 2007-12-28 screen read Bearish
    HSY 2008-08-07 filled 2008-08-07 after the 2008-08-01 screen read Bearish
    HLT1 2007-08-22 filled 2007-08-22 after the 2007-08-17 screen read Bearish
    HE 2011-11-04 filled 2011-11-04 after the 2011-10-28 screen read Bearish
