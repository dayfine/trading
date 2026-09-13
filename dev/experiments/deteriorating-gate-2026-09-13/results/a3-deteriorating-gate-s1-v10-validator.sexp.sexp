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
   ((id V6) (severity Invariant) (passed true) (n_violations 0) (n_skipped 0)
    (specimens ()))
   ((id V7) (severity Invariant) (passed false) (n_violations 45)
    (n_skipped 0)
    (specimens
     (((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "Virgin_territory but only 214 weekly bars (< 520) before entry"))
      ((symbol WDR) (entry_date 2007-07-13)
       (detail
        "Virgin_territory but only 491 weekly bars (< 520) before entry"))
      ((symbol VLCY) (entry_date 2002-03-19)
       (detail
        "Virgin_territory but only 222 weekly bars (< 520) before entry"))
      ((symbol UTHR) (entry_date 2002-11-21)
       (detail
        "Virgin_territory but only 180 weekly bars (< 520) before entry"))
      ((symbol TLRD) (entry_date 2000-08-23)
       (detail
        "Virgin_territory but only 139 weekly bars (< 520) before entry"))
      ((symbol TLB) (entry_date 2004-06-07)
       (detail
        "Virgin_territory but only 340 weekly bars (< 520) before entry"))
      ((symbol TBI1) (entry_date 2000-04-28)
       (detail
        "Virgin_territory but only 68 weekly bars (< 520) before entry"))
      ((symbol STLD) (entry_date 2003-12-01)
       (detail
        "Virgin_territory but only 371 weekly bars (< 520) before entry"))
      ((symbol SRCL) (entry_date 2005-06-13)
       (detail
        "Virgin_territory but only 465 weekly bars (< 520) before entry"))
      ((symbol ROVI) (entry_date 2007-06-06)
       (detail
        "Virgin_territory but only 496 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 76)
    (n_skipped 231)
    (specimens
     (((symbol X) (entry_date 2023-09-19)
       (detail "prior_top=37.63 within +25% of entry=31.74"))
      ((symbol VSAT) (entry_date 2019-03-15)
       (detail "prior_top=81.15 within +25% of entry=76.86"))
      ((symbol VRTX) (entry_date 2014-06-28)
       (detail "prior_top=93.77 within +25% of entry=92.22"))
      ((symbol VICR) (entry_date 2021-07-03)
       (detail "prior_top=107.97 within +25% of entry=107.30"))
      ((symbol TWX1) (entry_date 2000-01-28)
       (detail "prior_top=91.12 within +25% of entry=80.60"))
      ((symbol TTWO) (entry_date 2020-05-19)
       (detail "prior_top=137.99 within +25% of entry=136.47"))
      ((symbol TLB) (entry_date 2004-06-07)
       (detail "prior_top=42.90 within +25% of entry=38.90"))
      ((symbol TKO) (entry_date 2022-07-25)
       (detail "prior_top=88.08 within +25% of entry=71.21"))
      ((symbol TGT) (entry_date 2020-03-12)
       (detail "prior_top=107.27 within +25% of entry=92.66"))
      ((symbol TBI) (entry_date 2018-08-21)
       (detail "prior_top=31.21 within +25% of entry=29.69")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 10)
    (n_skipped 231)
    (specimens
     (((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol RDN) (entry_date 2009-08-06)
       (detail "entry_wk_close=5.51 > prior=1.50 (spike>60%)"))
      ((symbol RBAK) (entry_date 2006-12-23)
       (detail "entry_wk_close=24.94 > prior=14.52 (spike>60%)"))
      ((symbol MVL) (entry_date 2002-03-08)
       (detail "entry_wk_close=5.33 > prior=3.00 (spike>60%)"))
      ((symbol GERN) (entry_date 2012-09-01)
       (detail "entry_wk_close=2.74 > prior=1.61 (spike>60%)"))
      ((symbol FOSL) (entry_date 2018-05-29)
       (detail "entry_wk_close=23.70 > prior=14.51 (spike>60%)"))
      ((symbol CLFD) (entry_date 2026-05-26)
       (detail "entry_wk_close=47.22 > prior=29.43 (spike>60%)"))
      ((symbol BLDP) (entry_date 2026-05-16)
       (detail "entry_wk_close=5.54 > prior=3.28 (spike>60%)"))
      ((symbol BFX) (entry_date 2020-04-22)
       (detail "entry_wk_close=6.49 > prior=2.80 (spike>60%)"))
      ((symbol APWR) (entry_date 2000-01-24)
       (detail "entry_wk_close=15.33 > prior=9.33 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 23)
    (n_skipped 0)
    (specimens
     (((symbol WDR) (entry_date 2007-07-13)
       (detail
        "installed_stop=23.8272 vs fill=28.0500 -> dist=0.1505 > gate=0.1500"))
      ((symbol TRN) (entry_date 2013-10-31)
       (detail
        "installed_stop=32.9664 vs fill=17.1800 -> dist=0.9189 > gate=0.1500"))
      ((symbol TRMB) (entry_date 2003-11-24)
       (detail
        "installed_stop=25.8750 vs fill=19.6900 -> dist=0.3141 > gate=0.1500"))
      ((symbol SMTC) (entry_date 2018-04-10)
       (detail
        "installed_stop=35.8750 vs fill=42.2800 -> dist=0.1515 > gate=0.1500"))
      ((symbol R) (entry_date 2024-03-28)
       (detail
        "installed_stop=102.3552 vs fill=120.9300 -> dist=0.1536 > gate=0.1500"))
      ((symbol PH) (entry_date 2007-04-04)
       (detail
        "installed_stop=77.1361 vs fill=58.9800 -> dist=0.3078 > gate=0.1500"))
      ((symbol NEOG) (entry_date 2017-09-05)
       (detail
        "installed_stop=60.8750 vs fill=52.4800 -> dist=0.1600 > gate=0.1500"))
      ((symbol MNT) (entry_date 2005-04-15)
       (detail
        "installed_stop=31.3920 vs fill=37.4500 -> dist=0.1618 > gate=0.1500"))
      ((symbol MMM) (entry_date 2003-07-26)
       (detail
        "installed_stop=131.9328 vs fill=69.6800 -> dist=0.8934 > gate=0.1500"))
      ((symbol MGM) (entry_date 2001-09-18)
       (detail
        "installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 133)
    (n_skipped 8)
    (specimens
     (((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)"))
      ((symbol WERN) (entry_date 2009-12-12)
       (detail
        "no bar on entry_date 2009-12-12 (nearest earlier bar: 2009-12-11)"))
      ((symbol WDC) (entry_date 2012-08-18)
       (detail
        "no bar on entry_date 2012-08-18 (nearest earlier bar: 2012-08-17)"))
      ((symbol WAFD) (entry_date 2013-06-29)
       (detail
        "no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)"))
      ((symbol VRTX) (entry_date 2014-06-28)
       (detail
        "no bar on entry_date 2014-06-28 (nearest earlier bar: 2014-06-27)"))
      ((symbol VICR) (entry_date 2021-07-03)
       (detail
        "no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)"))
      ((symbol URBN) (entry_date 2025-12-20)
       (detail
        "no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)"))
      ((symbol UFPI) (entry_date 2013-06-22)
       (detail
        "no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)"))
      ((symbol TXNM) (entry_date 2020-02-01)
       (detail
        "no bar on entry_date 2020-02-01 (nearest earlier bar: 2020-01-31)"))
      ((symbol TWX1) (entry_date 2000-01-28)
       (detail
        "exit_price=76.5600 outside 2000-02-23 bar [76.5630, 82.0000]")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 1) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 7)
    (n_skipped 0)
    (specimens
     (((symbol AKR) (entry_date 2016-06-30)
       (detail
        "median close 1000000.00 over 8326 bars (1993-05-27..2026-06-25), above the 10000.00 ceiling"))
      ((symbol BRK-A) (entry_date 2006-05-18)
       (detail
        "median close 83100.00 over 11237 bars (1980-03-17..2026-06-25), above the 10000.00 ceiling"))
      ((symbol CLE) (entry_date 2014-11-18)
       (detail
        "median close 19.00 over 4813 bars (1997-12-31..2018-06-28); bar 2014-06-09 close 0.07 (-94.53% vs prior close 1.28) on volume 0"))
      ((symbol EHC) (entry_date 2011-01-10)
       (detail
        "median close 23.25 over 10014 bars (1986-09-24..2026-06-25); bar 2006-10-26 close 23.75 (+400.00% vs prior close 4.75) on volume 0"))
      ((symbol KBL) (entry_date 2021-07-26)
       (detail
        "median close 199.09 over 3819 bars (1998-01-29..2022-03-02); bar 2012-01-09 close 165.81 (+481.17% vs prior close 28.53) on volume 0"))
      ((symbol MVL) (entry_date 2002-03-08)
       (detail
        "median close 9.00 over 4795 bars (1999-01-04..2018-01-24); bar 2010-01-26 close 60.00 (+96.88% vs prior close 30.48) on volume 0"))
      ((symbol RRC) (entry_date 2006-11-30)
       (detail
        "median close 16.75 over 9591 bars (1984-11-05..2026-06-25); bar 1992-11-23 close 4.22 (+1399.47% vs prior close 0.28) on volume 0")))))))
 (audit_join ((matched 675) (total 675))))
