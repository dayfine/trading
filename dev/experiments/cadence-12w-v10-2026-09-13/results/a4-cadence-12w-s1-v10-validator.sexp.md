# Post-run validation report

Invariant checks failing: 4
audit join: 835/835 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT 1 violations
    IAC 2006-03-16 twin positions: IAC/MTCH
V7 INVARIANT 68 violations
    WLL1 2002-01-22 Virgin_territory but only 214 weekly bars (< 520) before entry
    VLCY 2002-03-19 Virgin_territory but only 222 weekly bars (< 520) before entry
    UTHR 2002-11-21 Virgin_territory but only 180 weekly bars (< 520) before entry
    URBN 2003-06-05 Virgin_territory but only 503 weekly bars (< 520) before entry
    UHAL 2003-09-12 Virgin_territory but only 466 weekly bars (< 520) before entry
    TFSM 2003-06-02 Virgin_territory but only 232 weekly bars (< 520) before entry
    TBI1 2000-04-28 Virgin_territory but only 68 weekly bars (< 520) before entry
    STLD 2003-12-01 Virgin_territory but only 371 weekly bars (< 520) before entry
    SRZ 2004-11-23 Virgin_territory but only 364 weekly bars (< 520) before entry
    SRCL 2005-06-13 Virgin_territory but only 465 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 117 violations (250 skipped)
    ZQKSQ 2004-05-12 prior_top=11.62 within +25% of entry=10.02
    VSH 2023-09-07 prior_top=27.66 within +25% of entry=25.09
    VSAT 2017-12-29 prior_top=81.15 within +25% of entry=75.08
    VSAT 2019-03-15 prior_top=81.15 within +25% of entry=76.86
    VRX1 2009-06-24 prior_top=26.54 within +25% of entry=24.77
    VRTX 2014-06-28 prior_top=93.77 within +25% of entry=92.22
    VRTX 2019-11-09 prior_top=201.31 within +25% of entry=197.08
    VRTX 2024-04-10 prior_top=435.02 within +25% of entry=397.15
    VICR 2006-02-22 prior_top=20.29 within +25% of entry=19.33
    VICR 2021-07-03 prior_top=107.97 within +25% of entry=107.30
V10 EXPECTATION 8 violations (250 skipped)
    RDN 2009-08-06 entry_wk_close=5.51 > prior=1.50 (spike>60%)
    MVL 2002-03-08 entry_wk_close=5.33 > prior=3.00 (spike>60%)
    LIVN 2005-02-04 entry_wk_close=39.78 > prior=20.88 (spike>60%)
    CLFD 2026-05-26 entry_wk_close=47.22 > prior=29.43 (spike>60%)
    CBMC 2000-03-06 entry_wk_close=191.25 > prior=71.25 (spike>60%)
    BPT 2022-01-22 entry_wk_close=5.52 > prior=2.85 (spike>60%)
    BFX 2020-04-22 entry_wk_close=6.49 > prior=2.80 (spike>60%)
    APWR 2000-01-24 entry_wk_close=15.33 > prior=9.33 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 18 violations
    WFM 2013-05-18 installed_stop=89.8750 vs fill=51.3400 -> dist=0.7506 > gate=0.1500
    URBN 2003-06-05 installed_stop=32.9308 vs fill=18.7700 -> dist=0.7544 > gate=0.1500
    TRN 2013-10-31 installed_stop=30.2203 vs fill=17.1800 -> dist=0.7590 > gate=0.1500
    SRZ 2004-11-23 installed_stop=38.1318 vs fill=21.7100 -> dist=0.7564 > gate=0.1500
    SMTC 2018-04-10 installed_stop=35.8750 vs fill=42.2800 -> dist=0.1515 > gate=0.1500
    SID 2021-01-04 installed_stop=5.3750 vs fill=6.4500 -> dist=0.1667 > gate=0.1500
    PIM 2007-07-20 installed_stop=5.3750 vs fill=6.4000 -> dist=0.1602 > gate=0.1500
    PDLI 2003-05-19 installed_stop=12.3750 vs fill=14.6000 -> dist=0.1524 > gate=0.1500
    INFY 2006-07-12 installed_stop=73.7467 vs fill=41.9200 -> dist=0.7592 > gate=0.1500
    INFY 2014-10-10 installed_stop=55.8996 vs fill=31.7800 -> dist=0.7590 > gate=0.1500
V13 INVARIANT 161 violations (7 skipped)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WFM 2013-05-18 no bar on entry_date 2013-05-18 (nearest earlier bar: 2013-05-17)
    WDC 2012-08-18 no bar on entry_date 2012-08-18 (nearest earlier bar: 2012-08-17)
    WBS 2011-01-22 no bar on entry_date 2011-01-22 (nearest earlier bar: 2011-01-21)
    VRTX 2014-06-28 no bar on entry_date 2014-06-28 (nearest earlier bar: 2014-06-27)
    VRTX 2019-11-09 no bar on entry_date 2019-11-09 (nearest earlier bar: 2019-11-08)
    VICR 2021-07-03 no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)
    VFC 2006-05-06 no bar on entry_date 2006-05-06 (nearest earlier bar: 2006-05-05)
    UN 2012-08-04 no bar on entry_date 2012-08-04 (nearest earlier bar: 2012-08-03)
    UFPI 2013-06-22 no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 5 violations
    BRK-A 2006-05-18 median close 83000.10 over 11229 bars (1980-03-17..2026-06-12), above the 10000.00 ceiling
    EHC 2010-01-13 median close 23.25 over 10006 bars (1986-09-24..2026-06-12); bar 2006-10-26 close 23.75 (+400.00% vs prior close 4.75) on volume 0
    FLO 2007-04-13 median close 18.18 over 11655 bars (1980-03-17..2026-06-12); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    MVL 2002-03-08 median close 9.00 over 4795 bars (1999-01-04..2018-01-24); bar 2010-01-26 close 60.00 (+96.88% vs prior close 30.48) on volume 0
    RAL_old 2017-08-03 median close 45000.00 over 4022 bars (1997-12-31..2022-03-02), above the 10000.00 ceiling; bar 2010-04-23 close 49.84 (-99.84% vs prior close 31800.00) on volume 0
