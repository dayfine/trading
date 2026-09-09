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
   ((id V6) (severity Invariant) (passed false) (n_violations 6)
    (n_skipped 0)
    (specimens
     (((symbol AABA) (entry_date 2005-11-16)
       (detail "twin positions: AABA/YHOO"))
      ((symbol BFX) (entry_date 2020-04-22)
       (detail "twin positions: BFX/NLS"))
      ((symbol AORT) (entry_date 2016-08-11)
       (detail "twin positions: AORT/CRY_old"))
      ((symbol CSC) (entry_date 2014-02-26)
       (detail "twin positions: CSC/DXC"))
      ((symbol BB) (entry_date 2006-09-29)
       (detail "twin positions: BB/BBRY"))
      ((symbol RCII) (entry_date 2020-12-21)
       (detail "twin positions: RCII/UPBD")))))
   ((id V7) (severity Invariant) (passed false) (n_violations 64)
    (n_skipped 0)
    (specimens
     (((symbol YHOO) (entry_date 2005-11-16)
       (detail
        "Virgin_territory but only 415 weekly bars (< 520) before entry"))
      ((symbol WLL1) (entry_date 2002-01-22)
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
      ((symbol TLB) (entry_date 2004-06-07)
       (detail
        "Virgin_territory but only 340 weekly bars (< 520) before entry"))
      ((symbol TFSM) (entry_date 2003-06-02)
       (detail
        "Virgin_territory but only 232 weekly bars (< 520) before entry"))
      ((symbol TBI1) (entry_date 2000-04-28)
       (detail
        "Virgin_territory but only 68 weekly bars (< 520) before entry"))
      ((symbol STLD) (entry_date 2003-12-01)
       (detail
        "Virgin_territory but only 371 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 106)
    (n_skipped 242)
    (specimens
     (((symbol ZQKSQ) (entry_date 2004-05-12)
       (detail "prior_top=11.62 within +25% of entry=10.02"))
      ((symbol VSH) (entry_date 2023-09-07)
       (detail "prior_top=27.66 within +25% of entry=25.09"))
      ((symbol VSAT) (entry_date 2017-12-29)
       (detail "prior_top=81.15 within +25% of entry=75.15"))
      ((symbol VSAT) (entry_date 2019-03-15)
       (detail "prior_top=81.15 within +25% of entry=76.93"))
      ((symbol VRX1) (entry_date 2009-06-24)
       (detail "prior_top=26.54 within +25% of entry=24.78"))
      ((symbol VRTX) (entry_date 2014-07-30)
       (detail "prior_top=99.07 within +25% of entry=91.61"))
      ((symbol VICR) (entry_date 2021-07-03)
       (detail "prior_top=107.97 within +25% of entry=107.30"))
      ((symbol URBN) (entry_date 2025-03-13)
       (detail "prior_top=58.19 within +25% of entry=50.12"))
      ((symbol TXT) (entry_date 2023-08-05)
       (detail "prior_top=78.40 within +25% of entry=78.00"))
      ((symbol TWX1) (entry_date 2000-01-28)
       (detail "prior_top=91.12 within +25% of entry=80.60")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 7)
    (n_skipped 242)
    (specimens
     (((symbol RDN) (entry_date 2009-08-06)
       (detail "entry_wk_close=5.51 > prior=1.50 (spike>60%)"))
      ((symbol NLS) (entry_date 2020-04-22)
       (detail "entry_wk_close=6.49 > prior=2.80 (spike>60%)"))
      ((symbol CYBX) (entry_date 2005-02-04)
       (detail "entry_wk_close=39.78 > prior=20.88 (spike>60%)"))
      ((symbol CLPA) (entry_date 2000-01-31)
       (detail "entry_wk_close=25.25 > prior=12.12 (spike>60%)"))
      ((symbol CLFD) (entry_date 2026-05-26)
       (detail "entry_wk_close=47.22 > prior=29.43 (spike>60%)"))
      ((symbol BFX) (entry_date 2020-04-22)
       (detail "entry_wk_close=6.49 > prior=2.80 (spike>60%)"))
      ((symbol APWR) (entry_date 2000-01-24)
       (detail "entry_wk_close=15.33 > prior=9.33 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 20)
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
        "installed_stop=31.6477 vs fill=17.1800 -> dist=0.8421 > gate=0.1500"))
      ((symbol TIN) (entry_date 2005-02-04)
       (detail
        "installed_stop=27.9938 vs fill=16.0900 -> dist=0.7398 > gate=0.1500"))
      ((symbol PDLI) (entry_date 2003-05-19)
       (detail
        "installed_stop=12.3750 vs fill=14.6000 -> dist=0.1524 > gate=0.1500"))
      ((symbol NEOG) (entry_date 2017-09-05)
       (detail
        "installed_stop=60.8750 vs fill=52.8100 -> dist=0.1527 > gate=0.1500"))
      ((symbol KLIC) (entry_date 2014-05-09)
       (detail
        "installed_stop=11.8750 vs fill=14.0500 -> dist=0.1548 > gate=0.1500"))
      ((symbol IMMR) (entry_date 2024-08-27)
       (detail
        "installed_stop=7.3750 vs fill=8.8300 -> dist=0.1648 > gate=0.1500"))
      ((symbol HGSI) (entry_date 2011-11-17)
       (detail
        "installed_stop=6.8750 vs fill=8.2000 -> dist=0.1616 > gate=0.1500"))
      ((symbol GE) (entry_date 2024-04-13)
       (detail
        "installed_stop=128.6304 vs fill=154.1300 -> dist=0.1654 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 154)
    (n_skipped 7)
    (specimens
     (((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)"))
      ((symbol WFM) (entry_date 2013-05-18)
       (detail
        "no bar on entry_date 2013-05-18 (nearest earlier bar: 2013-05-17)"))
      ((symbol WAFD) (entry_date 2013-06-29)
       (detail
        "no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)"))
      ((symbol VICR) (entry_date 2021-07-03)
       (detail
        "no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)"))
      ((symbol URBN) (entry_date 2025-12-20)
       (detail
        "no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)"))
      ((symbol UN) (entry_date 2019-09-07)
       (detail
        "no bar on entry_date 2019-09-07 (nearest earlier bar: 2019-09-06)"))
      ((symbol UFPI) (entry_date 2013-06-22)
       (detail
        "no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)"))
      ((symbol TXT) (entry_date 2023-08-05)
       (detail
        "no bar on entry_date 2023-08-05 (nearest earlier bar: 2023-08-04)"))
      ((symbol TXNM) (entry_date 2020-02-01)
       (detail
        "no bar on entry_date 2020-02-01 (nearest earlier bar: 2020-01-31)"))
      ((symbol TWX1) (entry_date 2000-01-28)
       (detail
        "exit_price=76.5600 outside 2000-02-23 bar [76.5630, 82.0000]")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))))
 (audit_join ((matched 793) (total 793))))
