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
V9 EXPECTATION 102 violations (258 skipped)
    ZQKSQ 2004-05-12 prior_top=11.62 within +25% of entry=10.02
    VSH 2023-09-07 prior_top=27.66 within +25% of entry=25.09
    VSAT 2019-03-15 prior_top=81.15 within +25% of entry=76.93
    VRX1 2009-06-24 prior_top=26.54 within +25% of entry=24.78
    VRTX 2014-06-28 prior_top=93.77 within +25% of entry=92.22
    VRTX 2019-11-09 prior_top=201.31 within +25% of entry=197.08
    VRTX 2024-04-10 prior_top=435.02 within +25% of entry=397.15
    VICR 2006-02-22 prior_top=20.29 within +25% of entry=19.33
    VICR 2021-07-03 prior_top=107.97 within +25% of entry=107.30
    USB 2024-08-28 prior_top=51.66 within +25% of entry=46.38
V10 EXPECTATION 9 violations (258 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    RDN 2009-08-06 entry_wk_close=5.51 > prior=1.50 (spike>60%)
    MVL 2002-03-08 entry_wk_close=5.33 > prior=3.00 (spike>60%)
    LIVN 2005-02-04 entry_wk_close=39.78 > prior=20.88 (spike>60%)
    CLFD 2026-05-26 entry_wk_close=47.22 > prior=29.43 (spike>60%)
    CBMC 2000-03-06 entry_wk_close=191.25 > prior=71.25 (spike>60%)
    BPT 2022-01-22 entry_wk_close=5.52 > prior=2.85 (spike>60%)
    BFX 2020-04-22 entry_wk_close=6.49 > prior=2.80 (spike>60%)
    APWR 2000-01-24 entry_wk_close=15.33 > prior=9.33 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 17 violations
    WFM 2013-05-18 installed_stop=89.8750 vs fill=51.3400 -> dist=0.7506 > gate=0.1500
    URBN 2003-06-05 installed_stop=32.9308 vs fill=18.7300 -> dist=0.7582 > gate=0.1500
    TRN 2013-10-31 installed_stop=30.2203 vs fill=17.1800 -> dist=0.7590 > gate=0.1500
    TEO 2024-01-02 installed_stop=5.8750 vs fill=7.0500 -> dist=0.1667 > gate=0.1500
    SRZ 2004-11-23 installed_stop=38.1318 vs fill=21.7300 -> dist=0.7548 > gate=0.1500
    PIM 2007-07-20 installed_stop=5.3750 vs fill=6.4000 -> dist=0.1602 > gate=0.1500
    PDLI 2003-05-19 installed_stop=12.3750 vs fill=14.6000 -> dist=0.1524 > gate=0.1500
    INFY 2006-07-12 installed_stop=73.7467 vs fill=41.9500 -> dist=0.7580 > gate=0.1500
    GAS1 2007-04-04 installed_stop=42.6816 vs fill=50.2400 -> dist=0.1504 > gate=0.1500
    FLO 2007-04-13 installed_stop=26.8750 vs fill=20.9600 -> dist=0.2822 > gate=0.1500
V13 INVARIANT 156 violations (7 skipped)
    WWW 2010-03-06 no bar on entry_date 2010-03-06 (nearest earlier bar: 2010-03-05)
    WLL1 2002-01-22 no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)
    WFM 2013-05-18 no bar on entry_date 2013-05-18 (nearest earlier bar: 2013-05-17)
    WDC 2012-08-18 no bar on entry_date 2012-08-18 (nearest earlier bar: 2012-08-17)
    WDC 2018-03-10 no bar on entry_date 2018-03-10 (nearest earlier bar: 2018-03-09)
    WBS 2011-01-22 no bar on entry_date 2011-01-22 (nearest earlier bar: 2011-01-21)
    VYX 2012-02-11 no bar on entry_date 2012-02-11 (nearest earlier bar: 2012-02-10)
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
    FLO 2007-04-13 median close 18.18 over 11660 bars (1980-03-17..2026-06-22); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    KBL 2021-07-26 median close 199.09 over 3819 bars (1998-01-29..2022-03-02); bar 2012-01-09 close 165.81 (+481.17% vs prior close 28.53) on volume 0
    MVL 2002-03-08 median close 9.00 over 4795 bars (1999-01-04..2018-01-24); bar 2010-01-26 close 60.00 (+96.88% vs prior close 30.48) on volume 0
