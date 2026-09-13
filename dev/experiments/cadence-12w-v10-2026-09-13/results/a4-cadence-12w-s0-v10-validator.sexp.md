# Post-run validation report

Invariant checks failing: 3
audit join: 851/851 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 71 violations
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
V9 EXPECTATION 109 violations (246 skipped)
    ZQKSQ 2004-05-12 prior_top=11.62 within +25% of entry=10.02
    VSH 2023-09-07 prior_top=27.66 within +25% of entry=25.09
    VSAT 2017-12-29 prior_top=81.15 within +25% of entry=75.32
    VSAT 2019-03-15 prior_top=81.15 within +25% of entry=76.80
    VRX1 2009-06-24 prior_top=26.54 within +25% of entry=24.83
    VRTX 2014-06-28 prior_top=93.77 within +25% of entry=92.22
    VRTX 2019-11-09 prior_top=201.31 within +25% of entry=197.08
    VRTX 2024-04-10 prior_top=435.02 within +25% of entry=397.15
    VICR 2006-02-22 prior_top=20.29 within +25% of entry=19.34
    VICR 2021-07-03 prior_top=107.97 within +25% of entry=107.30
V10 EXPECTATION 8 violations (246 skipped)
    RDN 2009-08-06 entry_wk_close=5.51 > prior=1.50 (spike>60%)
    MVL 2002-03-08 entry_wk_close=5.33 > prior=3.00 (spike>60%)
    LIVN 2005-02-04 entry_wk_close=39.78 > prior=20.88 (spike>60%)
    FNMA 2013-05-24 entry_wk_close=2.97 > prior=0.83 (spike>60%)
    CBMC 2000-03-06 entry_wk_close=191.25 > prior=71.25 (spike>60%)
    BPT 2022-01-22 entry_wk_close=5.52 > prior=2.85 (spike>60%)
    BFX 2020-04-22 entry_wk_close=6.49 > prior=2.80 (spike>60%)
    APWR 2000-01-24 entry_wk_close=15.33 > prior=9.33 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 21 violations
    WFM 2013-05-18 installed_stop=89.8750 vs fill=51.3400 -> dist=0.7506 > gate=0.1500
    URBN 2003-06-05 installed_stop=32.9308 vs fill=18.7500 -> dist=0.7563 > gate=0.1500
    TRN 2013-10-31 installed_stop=30.2203 vs fill=17.3100 -> dist=0.7458 > gate=0.1500
    SRZ 2004-11-23 installed_stop=38.1318 vs fill=21.6800 -> dist=0.7588 > gate=0.1500
    SGP_old1 2010-05-10 installed_stop=8.8750 vs fill=10.5500 -> dist=0.1588 > gate=0.1500
    PDLI 2003-05-19 installed_stop=12.3750 vs fill=14.6000 -> dist=0.1524 > gate=0.1500
    OSPN 2022-09-15 installed_stop=7.8750 vs fill=9.2800 -> dist=0.1514 > gate=0.1500
    NPKI 2005-06-24 installed_stop=5.8750 vs fill=6.9700 -> dist=0.1571 > gate=0.1500
    MCK 2020-05-28 installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500
    LSCC 2014-02-13 installed_stop=6.3750 vs fill=7.5700 -> dist=0.1579 > gate=0.1500
V13 INVARIANT 171 violations (7 skipped)
    WSM 2012-09-01 no bar on entry_date 2012-09-01 (nearest earlier bar: 2012-08-31)
    WNC 2016-12-17 no bar on entry_date 2016-12-17 (nearest earlier bar: 2016-12-16)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WFM 2013-05-18 no bar on entry_date 2013-05-18 (nearest earlier bar: 2013-05-17)
    WDC 2012-08-18 no bar on entry_date 2012-08-18 (nearest earlier bar: 2012-08-17)
    WBS 2011-01-22 no bar on entry_date 2011-01-22 (nearest earlier bar: 2011-01-21)
    VYX 2015-06-16 entry_price=36.5000 outside 2015-06-16 bar [31.2699, 36.4999]
    VRTX 2014-06-28 no bar on entry_date 2014-06-28 (nearest earlier bar: 2014-06-27)
    VRTX 2019-11-09 no bar on entry_date 2019-11-09 (nearest earlier bar: 2019-11-08)
    VICR 2021-07-03 no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 5 violations
    BRK-A 2006-05-18 median close 83087.55 over 11234 bars (1980-03-17..2026-06-22), above the 10000.00 ceiling
    EHC 2010-01-13 median close 23.25 over 10011 bars (1986-09-24..2026-06-22); bar 2006-10-26 close 23.75 (+400.00% vs prior close 4.75) on volume 0
    FLO 2020-03-09 median close 18.18 over 11660 bars (1980-03-17..2026-06-22); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    KBL 2021-07-26 median close 199.09 over 3819 bars (1998-01-29..2022-03-02); bar 2012-01-09 close 165.81 (+481.17% vs prior close 28.53) on volume 0
    MVL 2002-03-08 median close 9.00 over 4795 bars (1999-01-04..2018-01-24); bar 2010-01-26 close 60.00 (+96.88% vs prior close 30.48) on volume 0
