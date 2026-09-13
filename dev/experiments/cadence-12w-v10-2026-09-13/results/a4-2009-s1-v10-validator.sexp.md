# Post-run validation report

Invariant checks failing: 4
audit join: 154/154 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT 1 violations
    CMD 2009-10-10 twin positions: CMD/CMN
V7 INVARIANT 22 violations
    UAA 2010-09-15 Virgin_territory but only 254 weekly bars (< 520) before entry
    PTP 2009-12-24 Virgin_territory but only 377 weekly bars (< 520) before entry
    NWG 2013-09-18 Virgin_territory but only 313 weekly bars (< 520) before entry
    MYRG 2013-10-17 Virgin_territory but only 272 weekly bars (< 520) before entry
    MRH 2010-02-18 Virgin_territory but only 388 weekly bars (< 520) before entry
    MOH 2011-01-27 Virgin_territory but only 398 weekly bars (< 520) before entry
    MNTA 2010-07-23 Virgin_territory but only 319 weekly bars (< 520) before entry
    MDAS 2010-06-10 Virgin_territory but only 132 weekly bars (< 520) before entry
    LPS 2009-09-16 Virgin_territory but only 65 weekly bars (< 520) before entry
    HLF 2013-07-22 Virgin_territory but only 452 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 23 violations (71 skipped)
    VRX1 2009-06-24 prior_top=26.54 within +25% of entry=24.77
    TWTC 2012-03-19 prior_top=23.75 within +25% of entry=23.00
    SCI 2011-08-03 prior_top=10.17 within +25% of entry=9.99
    OCR 2011-12-02 prior_top=41.38 within +25% of entry=33.20
    MYRG 2013-10-17 prior_top=26.23 within +25% of entry=25.90
    MRH 2010-02-18 prior_top=22.18 within +25% of entry=18.04
    MFN 2011-03-21 prior_top=13.31 within +25% of entry=11.96
    LPS 2009-09-16 prior_top=39.95 within +25% of entry=38.19
    ISCA 2013-03-27 prior_top=40.38 within +25% of entry=32.49
    HEW 2009-11-17 prior_top=41.94 within +25% of entry=41.49
V10 EXPECTATION 1 violations (71 skipped)
    ICGN 2009-09-01 entry_wk_close=9.52 > prior=4.80 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 2 violations
    SCI 2011-08-03 installed_stop=8.3750 vs fill=9.9900 -> dist=0.1617 > gate=0.1500
    MOH 2011-01-27 installed_stop=28.1258 vs fill=21.3300 -> dist=0.3186 > gate=0.1500
V13 INVARIANT 21 violations
    UMPQ 2013-06-15 no bar on entry_date 2013-06-15 (nearest earlier bar: 2013-06-14)
    UFPI 2013-06-22 no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)
    NUAN 2010-12-10 exit_price=17.9300 outside 2011-03-07 bar [17.1166, 17.9259]
    MRX_old 2011-03-12 no bar on entry_date 2011-03-12 (nearest earlier bar: 2011-03-11)
    MOH 2011-01-27 entry_price=21.3300 outside 2011-01-27 bar [31.1300, 32.0000]
    KFN 2011-01-18 entry_price=9.8500 outside 2011-01-18 bar [9.6270, 9.8450]
    INVA 2013-04-20 no bar on entry_date 2013-04-20 (nearest earlier bar: 2013-04-19)
    HUBG 2010-03-20 no bar on entry_date 2010-03-20 (nearest earlier bar: 2010-03-19)
    GAMI 2013-06-15 no bar on entry_date 2013-06-15 (nearest earlier bar: 2013-06-14)
    FCF 2013-07-13 no bar on entry_date 2013-07-13 (nearest earlier bar: 2013-07-12)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 1 violations
    BHRB 2013-05-15 median close 2015.00 over 2785 bars (1995-08-04..2013-12-30); bar 2003-10-07 close 2001.00 (-99.80% vs prior close 1000000.00) on volume 0
