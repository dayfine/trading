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
   ((id V7) (severity Invariant) (passed false) (n_violations 61)
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
        "Virgin_territory but only 371 weekly bars (< 520) before entry"))
      ((symbol SRCL) (entry_date 2005-06-13)
       (detail
        "Virgin_territory but only 465 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 106)
    (n_skipped 241)
    (specimens
     (((symbol ZQKSQ) (entry_date 2004-05-12)
       (detail "prior_top=11.62 within +25% of entry=10.02"))
      ((symbol WAB) (entry_date 2023-07-08)
       (detail "prior_top=109.26 within +25% of entry=108.41"))
      ((symbol VSH) (entry_date 2023-09-07)
       (detail "prior_top=27.66 within +25% of entry=25.09"))
      ((symbol VRX1) (entry_date 2009-06-24)
       (detail "prior_top=26.54 within +25% of entry=24.78"))
      ((symbol VRTX) (entry_date 2014-07-31)
       (detail "prior_top=99.07 within +25% of entry=89.97"))
      ((symbol VICR) (entry_date 2021-07-03)
       (detail "prior_top=107.97 within +25% of entry=107.30"))
      ((symbol URBN) (entry_date 2025-03-13)
       (detail "prior_top=58.19 within +25% of entry=50.12"))
      ((symbol TWX1) (entry_date 2000-01-28)
       (detail "prior_top=91.12 within +25% of entry=80.60"))
      ((symbol TLB) (entry_date 2004-06-07)
       (detail "prior_top=42.90 within +25% of entry=38.84"))
      ((symbol TKO) (entry_date 2022-07-25)
       (detail "prior_top=88.08 within +25% of entry=71.18")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 8)
    (n_skipped 241)
    (specimens
     (((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol RDN) (entry_date 2009-08-06)
       (detail "entry_wk_close=5.51 > prior=1.50 (spike>60%)"))
      ((symbol RBAK) (entry_date 2006-12-23)
       (detail "entry_wk_close=24.94 > prior=14.52 (spike>60%)"))
      ((symbol CLPA) (entry_date 2000-01-31)
       (detail "entry_wk_close=25.25 > prior=12.12 (spike>60%)"))
      ((symbol CLFD) (entry_date 2026-05-26)
       (detail "entry_wk_close=47.22 > prior=29.43 (spike>60%)"))
      ((symbol BPT) (entry_date 2022-01-22)
       (detail "entry_wk_close=5.52 > prior=2.85 (spike>60%)"))
      ((symbol BFX) (entry_date 2020-04-22)
       (detail "entry_wk_close=6.49 > prior=2.80 (spike>60%)"))
      ((symbol APWR) (entry_date 2000-01-24)
       (detail "entry_wk_close=15.33 > prior=9.33 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 20)
    (n_skipped 0)
    (specimens
     (((symbol URBN) (entry_date 2003-06-05)
       (detail
        "installed_stop=32.9308 vs fill=18.7300 -> dist=0.7582 > gate=0.1500"))
      ((symbol TRN) (entry_date 2013-10-31)
       (detail
        "installed_stop=31.6477 vs fill=17.1800 -> dist=0.8421 > gate=0.1500"))
      ((symbol TIN) (entry_date 2005-02-04)
       (detail
        "installed_stop=27.9938 vs fill=16.0900 -> dist=0.7398 > gate=0.1500"))
      ((symbol PIM) (entry_date 2007-07-20)
       (detail
        "installed_stop=5.3750 vs fill=6.4000 -> dist=0.1602 > gate=0.1500"))
      ((symbol PDLI) (entry_date 2003-05-19)
       (detail
        "installed_stop=12.3750 vs fill=14.6000 -> dist=0.1524 > gate=0.1500"))
      ((symbol NEOG) (entry_date 2017-09-05)
       (detail
        "installed_stop=60.8750 vs fill=52.8100 -> dist=0.1527 > gate=0.1500"))
      ((symbol LGTY) (entry_date 2020-04-29)
       (detail
        "installed_stop=14.7984 vs fill=17.5400 -> dist=0.1563 > gate=0.1500"))
      ((symbol KYOCY) (entry_date 2023-12-29)
       (detail
        "installed_stop=51.3763 vs fill=14.6300 -> dist=2.5117 > gate=0.1500"))
      ((symbol KLIC) (entry_date 2014-05-09)
       (detail
        "installed_stop=11.8750 vs fill=14.0500 -> dist=0.1548 > gate=0.1500"))
      ((symbol IMMR) (entry_date 2024-08-27)
       (detail
        "installed_stop=7.3750 vs fill=8.8300 -> dist=0.1648 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 145)
    (n_skipped 6)
    (specimens
     (((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)"))
      ((symbol WBS) (entry_date 2011-01-22)
       (detail
        "no bar on entry_date 2011-01-22 (nearest earlier bar: 2011-01-21)"))
      ((symbol WAFD) (entry_date 2013-06-29)
       (detail
        "no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)"))
      ((symbol WAB) (entry_date 2023-07-08)
       (detail
        "no bar on entry_date 2023-07-08 (nearest earlier bar: 2023-07-07)"))
      ((symbol VICR) (entry_date 2021-07-03)
       (detail
        "no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)"))
      ((symbol UFPI) (entry_date 2013-06-22)
       (detail
        "no bar on entry_date 2013-06-22 (nearest earlier bar: 2013-06-21)"))
      ((symbol TXNM) (entry_date 2020-02-01)
       (detail
        "no bar on entry_date 2020-02-01 (nearest earlier bar: 2020-01-31)"))
      ((symbol TWX1) (entry_date 2000-01-28)
       (detail
        "exit_price=76.5600 outside 2000-02-23 bar [76.5630, 82.0000]"))
      ((symbol TTE) (entry_date 2021-10-16)
       (detail
        "no bar on entry_date 2021-10-16 (nearest earlier bar: 2021-10-15)"))
      ((symbol TRV) (entry_date 2025-05-10)
       (detail
        "no bar on entry_date 2025-05-10 (nearest earlier bar: 2025-05-09)")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))))
 (audit_join ((matched 804) (total 804))))
