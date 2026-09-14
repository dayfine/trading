# Post-run validation report

Invariant checks failing: 4
audit join: 149/149 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT 1 violations
    CMD 2009-10-10 twin positions: CMD/CMN
V7 INVARIANT 25 violations
    VLTR 2012-01-18 Virgin_territory but only 392 weekly bars (< 520) before entry
    UAA 2010-09-15 Virgin_territory but only 254 weekly bars (< 520) before entry
    PTP 2009-12-24 Virgin_territory but only 377 weekly bars (< 520) before entry
    NWG 2013-09-18 Virgin_territory but only 313 weekly bars (< 520) before entry
    MYRG 2013-10-17 Virgin_territory but only 272 weekly bars (< 520) before entry
    MRH 2010-02-18 Virgin_territory but only 388 weekly bars (< 520) before entry
    MNTA 2010-07-23 Virgin_territory but only 319 weekly bars (< 520) before entry
    MDAS 2010-06-10 Virgin_territory but only 132 weekly bars (< 520) before entry
    LULU 2013-05-14 Virgin_territory but only 306 weekly bars (< 520) before entry
    LPS 2009-09-16 Virgin_territory but only 65 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 21 violations (70 skipped)
    VRX1 2009-06-24 prior_top=26.54 within +25% of entry=24.78
    TWTC 2012-03-19 prior_top=23.75 within +25% of entry=23.00
    OCR 2011-12-02 prior_top=41.38 within +25% of entry=33.20
    MYRG 2013-10-17 prior_top=26.23 within +25% of entry=25.90
    MRH 2010-02-18 prior_top=22.18 within +25% of entry=18.03
    LPS 2009-09-16 prior_top=39.95 within +25% of entry=38.19
    LIVN 2010-10-25 prior_top=34.29 within +25% of entry=29.10
    KMX 2010-09-25 prior_top=28.77 within +25% of entry=27.04
    ISCA 2013-03-27 prior_top=40.38 within +25% of entry=32.50
    HEW 2009-11-17 prior_top=41.94 within +25% of entry=41.48
V10 EXPECTATION 1 violations (70 skipped)
    ICGN 2009-09-01 entry_wk_close=9.52 > prior=4.80 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 2 violations
    ICGN 2009-09-01 installed_stop=10.3750 vs fill=12.2100 -> dist=0.1503 > gate=0.1500
    EL 2011-11-21 installed_stop=96.1963 vs fill=55.3500 -> dist=0.7380 > gate=0.1500
V13 INVARIANT 17 violations (1 skipped)
    WWW 2010-03-06 no bar on entry_date 2010-03-06 (nearest earlier bar: 2010-03-05)
    UFPI 2013-06-22 no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)
    KMX 2010-09-25 no bar on entry_date 2010-09-25 (nearest earlier bar: 2010-09-24)
    KFN 2011-01-18 entry_price=9.8500 outside 2011-01-18 bar [9.6270, 9.8450]
    INVA 2013-04-20 no bar on entry_date 2013-04-20 (nearest earlier bar: 2013-04-19)
    HUBG 2010-03-20 no bar on entry_date 2010-03-20 (nearest earlier bar: 2010-03-19)
    GAMI 2013-06-15 no bar on entry_date 2013-06-15 (nearest earlier bar: 2013-06-14)
    EXLS 2012-03-10 no bar on entry_date 2012-03-10 (nearest earlier bar: 2012-03-09)
    DST 2012-09-29 no bar on entry_date 2012-09-29 (nearest earlier bar: 2012-09-28)
    CMN 2009-10-10 no bar on entry_date 2009-10-10 (nearest earlier bar: 2009-10-09)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION PASS
