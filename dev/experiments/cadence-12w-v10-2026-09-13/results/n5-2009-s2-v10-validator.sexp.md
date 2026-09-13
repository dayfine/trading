# Post-run validation report

Invariant checks failing: 2
audit join: 128/128 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 19 violations
    VLTR 2012-01-18 Virgin_territory but only 392 weekly bars (< 520) before entry
    ULTA 2013-08-02 Virgin_territory but only 304 weekly bars (< 520) before entry
    UAA 2010-09-15 Virgin_territory but only 254 weekly bars (< 520) before entry
    NWG 2013-09-18 Virgin_territory but only 313 weekly bars (< 520) before entry
    MRH 2010-02-18 Virgin_territory but only 388 weekly bars (< 520) before entry
    MNTA 2010-07-23 Virgin_territory but only 319 weekly bars (< 520) before entry
    FRFHF 2009-09-14 Virgin_territory but only 435 weekly bars (< 520) before entry
    ETE 2012-12-10 Virgin_territory but only 360 weekly bars (< 520) before entry
    ET 2012-12-10 Virgin_territory but only 360 weekly bars (< 520) before entry
    DWA 2009-08-31 Virgin_territory but only 255 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 17 violations (62 skipped)
    TWTC 2012-03-19 prior_top=23.75 within +25% of entry=23.00
    SKYW 2013-11-19 prior_top=16.83 within +25% of entry=16.40
    OCR 2011-12-02 prior_top=41.38 within +25% of entry=33.20
    NLC 2011-08-02 prior_top=36.65 within +25% of entry=33.44
    MRH 2010-02-18 prior_top=22.18 within +25% of entry=18.03
    MMSI 2011-03-12 prior_top=16.51 within +25% of entry=14.29
    JACK 2012-05-22 prior_top=30.17 within +25% of entry=24.70
    ISCA 2013-03-27 prior_top=40.38 within +25% of entry=32.50
    FDO 2011-03-14 prior_top=52.55 within +25% of entry=52.09
    ECOL 2012-10-31 prior_top=24.52 within +25% of entry=22.85
V10 EXPECTATION PASS (62 skipped)
V11 EXPECTATION PASS
V12 INVARIANT PASS
V13 INVARIANT 19 violations
    WOR 2010-01-16 no bar on entry_date 2010-01-16 (nearest earlier bar: 2010-01-15)
    SIRI 2012-08-11 no bar on entry_date 2012-08-11 (nearest earlier bar: 2012-08-10)
    MNRO 2009-11-03 exit_price=28.9600 outside 2009-12-04 bar [28.9601, 29.8500]
    MMSI 2011-03-12 no bar on entry_date 2011-03-12 (nearest earlier bar: 2011-03-11)
    INVA 2013-04-20 no bar on entry_date 2013-04-20 (nearest earlier bar: 2013-04-19)
    GSKNF 2013-09-14 no bar on entry_date 2013-09-14 (nearest earlier bar: 2013-09-13)
    GAMI 2013-06-15 no bar on entry_date 2013-06-15 (nearest earlier bar: 2013-06-14)
    EADSY 2009-09-18 entry_price=24.1400 outside 2009-09-18 bar [24.1450, 24.1450]
    CPHD 2012-02-18 no bar on entry_date 2012-02-18 (nearest earlier bar: 2012-02-17)
    CNH 2009-10-31 no bar on entry_date 2009-10-31 (nearest earlier bar: 2009-10-30)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 1 violations
    CSKI 2009-12-18 median close 0.22 over 4738 bars (1995-02-01..2013-12-23); bar 2002-12-13 close 0.45 (+542.86% vs prior close 0.07) on volume 0
