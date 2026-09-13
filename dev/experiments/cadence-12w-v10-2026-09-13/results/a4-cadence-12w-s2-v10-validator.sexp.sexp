((checks
  (((id V1) (severity Invariant) (passed true) (n_violations 0) (n_skipped 0)
    (specimens ()))
   ((id V2) (severity Invariant) (passed true) (n_violations 0) (n_skipped 0)
    (specimens ()))
   ((id V3) (severity Invariant) (passed true) (n_violations 0) (n_skipped 0)
    (specimens ()))
   ((id V4) (severity Invariant) (passed true) (n_violations 0) (n_skipped 0)
    (specimens ()))
   ((id V5) (severity Invariant) (passed true) (n_violations 0) (n_skipped 0)
    (specimens ()))
   ((id V6) (severity Invariant) (passed false) (n_violations 1)
    (n_skipped 0)
    (specimens
     (((symbol IAC) (entry_date 2006-03-16)
       (detail "twin positions: IAC/MTCH")))))
   ((id V7) (severity Invariant) (passed false) (n_violations 68)
    (n_skipped 0)
    (specimens
     (((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "Virgin_territory but only 214 weekly bars (< 520) before entry"))
      ((symbol VLCY) (entry_date 2002-03-19)
       (detail
        "Virgin_territory but only 222 weekly bars (< 520) before entry"))
      ((symbol UTHR) (entry_date 2002-11-21)
       (detail
        "Virgin_territory but only 180 weekly bars (< 520) before entry"))
      ((symbol URBN) (entry_date 2003-06-05)
       (detail
        "Virgin_territory but only 503 weekly bars (< 520) before entry"))
      ((symbol UHAL) (entry_date 2003-09-12)
       (detail
        "Virgin_territory but only 466 weekly bars (< 520) before entry"))
      ((symbol TFSM) (entry_date 2003-06-02)
       (detail
        "Virgin_territory but only 232 weekly bars (< 520) before entry"))
      ((symbol TBI1) (entry_date 2000-04-28)
       (detail
        "Virgin_territory but only 68 weekly bars (< 520) before entry"))
      ((symbol STLD) (entry_date 2003-12-01)
       (detail
        "Virgin_territory but only 371 weekly bars (< 520) before entry"))
      ((symbol SRZ) (entry_date 2004-11-23)
       (detail
        "Virgin_territory but only 364 weekly bars (< 520) before entry"))
      ((symbol SRCL) (entry_date 2005-06-13)
       (detail
        "Virgin_territory but only 465 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 102)
    (n_skipped 258)
    (specimens
     (((symbol ZQKSQ) (entry_date 2004-05-12)
       (detail "prior_top=11.62 within +25% of entry=10.02"))
      ((symbol VSH) (entry_date 2023-09-07)
       (detail "prior_top=27.66 within +25% of entry=25.09"))
      ((symbol VSAT) (entry_date 2019-03-15)
       (detail "prior_top=81.15 within +25% of entry=76.93"))
      ((symbol VRX1) (entry_date 2009-06-24)
       (detail "prior_top=26.54 within +25% of entry=24.78"))
      ((symbol VRTX) (entry_date 2014-06-28)
       (detail "prior_top=93.77 within +25% of entry=92.22"))
      ((symbol VRTX) (entry_date 2019-11-09)
       (detail "prior_top=201.31 within +25% of entry=197.08"))
      ((symbol VRTX) (entry_date 2024-04-10)
       (detail "prior_top=435.02 within +25% of entry=397.15"))
      ((symbol VICR) (entry_date 2006-02-22)
       (detail "prior_top=20.29 within +25% of entry=19.33"))
      ((symbol VICR) (entry_date 2021-07-03)
       (detail "prior_top=107.97 within +25% of entry=107.30"))
      ((symbol USB) (entry_date 2024-08-28)
       (detail "prior_top=51.66 within +25% of entry=46.38")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 9)
    (n_skipped 258)
    (specimens
     (((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol RDN) (entry_date 2009-08-06)
       (detail "entry_wk_close=5.51 > prior=1.50 (spike>60%)"))
      ((symbol MVL) (entry_date 2002-03-08)
       (detail "entry_wk_close=5.33 > prior=3.00 (spike>60%)"))
      ((symbol LIVN) (entry_date 2005-02-04)
       (detail "entry_wk_close=39.78 > prior=20.88 (spike>60%)"))
      ((symbol CLFD) (entry_date 2026-05-26)
       (detail "entry_wk_close=47.22 > prior=29.43 (spike>60%)"))
      ((symbol CBMC) (entry_date 2000-03-06)
       (detail "entry_wk_close=191.25 > prior=71.25 (spike>60%)"))
      ((symbol BPT) (entry_date 2022-01-22)
       (detail "entry_wk_close=5.52 > prior=2.85 (spike>60%)"))
      ((symbol BFX) (entry_date 2020-04-22)
       (detail "entry_wk_close=6.49 > prior=2.80 (spike>60%)"))
      ((symbol APWR) (entry_date 2000-01-24)
       (detail "entry_wk_close=15.33 > prior=9.33 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 17)
    (n_skipped 0)
    (specimens
     (((symbol WFM) (entry_date 2013-05-18)
       (detail
        "installed_stop=89.8750 vs fill=51.3400 -> dist=0.7506 > gate=0.1500"))
      ((symbol URBN) (entry_date 2003-06-05)
       (detail
        "installed_stop=32.9308 vs fill=18.7300 -> dist=0.7582 > gate=0.1500"))
      ((symbol TRN) (entry_date 2013-10-31)
       (detail
        "installed_stop=30.2203 vs fill=17.1800 -> dist=0.7590 > gate=0.1500"))
      ((symbol TEO) (entry_date 2024-01-02)
       (detail
        "installed_stop=5.8750 vs fill=7.0500 -> dist=0.1667 > gate=0.1500"))
      ((symbol SRZ) (entry_date 2004-11-23)
       (detail
        "installed_stop=38.1318 vs fill=21.7300 -> dist=0.7548 > gate=0.1500"))
      ((symbol PIM) (entry_date 2007-07-20)
       (detail
        "installed_stop=5.3750 vs fill=6.4000 -> dist=0.1602 > gate=0.1500"))
      ((symbol PDLI) (entry_date 2003-05-19)
       (detail
        "installed_stop=12.3750 vs fill=14.6000 -> dist=0.1524 > gate=0.1500"))
      ((symbol INFY) (entry_date 2006-07-12)
       (detail
        "installed_stop=73.7467 vs fill=41.9500 -> dist=0.7580 > gate=0.1500"))
      ((symbol GAS1) (entry_date 2007-04-04)
       (detail
        "installed_stop=42.6816 vs fill=50.2400 -> dist=0.1504 > gate=0.1500"))
      ((symbol FLO) (entry_date 2007-04-13)
       (detail
        "installed_stop=26.8750 vs fill=20.9600 -> dist=0.2822 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 156)
    (n_skipped 7)
    (specimens
     (((symbol WWW) (entry_date 2010-03-06)
       (detail
        "no bar on entry_date 2010-03-06 (nearest earlier bar: 2010-03-05)"))
      ((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)"))
      ((symbol WFM) (entry_date 2013-05-18)
       (detail
        "no bar on entry_date 2013-05-18 (nearest earlier bar: 2013-05-17)"))
      ((symbol WDC) (entry_date 2012-08-18)
       (detail
        "no bar on entry_date 2012-08-18 (nearest earlier bar: 2012-08-17)"))
      ((symbol WDC) (entry_date 2018-03-10)
       (detail
        "no bar on entry_date 2018-03-10 (nearest earlier bar: 2018-03-09)"))
      ((symbol WBS) (entry_date 2011-01-22)
       (detail
        "no bar on entry_date 2011-01-22 (nearest earlier bar: 2011-01-21)"))
      ((symbol VYX) (entry_date 2012-02-11)
       (detail
        "no bar on entry_date 2012-02-11 (nearest earlier bar: 2012-02-10)"))
      ((symbol VRTX) (entry_date 2014-06-28)
       (detail
        "no bar on entry_date 2014-06-28 (nearest earlier bar: 2014-06-27)"))
      ((symbol VRTX) (entry_date 2019-11-09)
       (detail
        "no bar on entry_date 2019-11-09 (nearest earlier bar: 2019-11-08)"))
      ((symbol VICR) (entry_date 2021-07-03)
       (detail
        "no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 5)
    (n_skipped 0)
    (specimens
     (((symbol BRK-A) (entry_date 2006-05-18)
       (detail
        "median close 83087.55 over 11234 bars (1980-03-17..2026-06-22), above the 10000.00 ceiling"))
      ((symbol EHC) (entry_date 2010-01-13)
       (detail
        "median close 23.25 over 10011 bars (1986-09-24..2026-06-22); bar 2006-10-26 close 23.75 (+400.00% vs prior close 4.75) on volume 0"))
      ((symbol FLO) (entry_date 2007-04-13)
       (detail
        "median close 18.18 over 11660 bars (1980-03-17..2026-06-22); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0"))
      ((symbol KBL) (entry_date 2021-07-26)
       (detail
        "median close 199.09 over 3819 bars (1998-01-29..2022-03-02); bar 2012-01-09 close 165.81 (+481.17% vs prior close 28.53) on volume 0"))
      ((symbol MVL) (entry_date 2002-03-08)
       (detail
        "median close 9.00 over 4795 bars (1999-01-04..2018-01-24); bar 2010-01-26 close 60.00 (+96.88% vs prior close 30.48) on volume 0")))))))
 (audit_join ((matched 835) (total 835))))
