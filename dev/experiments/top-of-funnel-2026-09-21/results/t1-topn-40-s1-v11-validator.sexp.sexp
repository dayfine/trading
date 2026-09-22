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
   ((id V7) (severity Invariant) (passed false) (n_violations 107)
    (n_skipped 0)
    (specimens
     (((symbol ZS) (entry_date 2020-05-29)
       (detail
        "Virgin_territory but only 117 weekly bars (< 520) before entry"))
      ((symbol XPOF) (entry_date 2023-01-27)
       (detail
        "Virgin_territory but only 79 weekly bars (< 520) before entry"))
      ((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "Virgin_territory but only 214 weekly bars (< 520) before entry"))
      ((symbol VOYA) (entry_date 2017-11-29)
       (detail
        "Virgin_territory but only 241 weekly bars (< 520) before entry"))
      ((symbol VLCY) (entry_date 2002-03-19)
       (detail
        "Virgin_territory but only 222 weekly bars (< 520) before entry"))
      ((symbol VICI) (entry_date 2019-10-16)
       (detail
        "Virgin_territory but only 105 weekly bars (< 520) before entry"))
      ((symbol VAL) (entry_date 2022-10-27)
       (detail
        "Virgin_territory but only 77 weekly bars (< 520) before entry"))
      ((symbol UTHR) (entry_date 2002-11-21)
       (detail
        "Virgin_territory but only 180 weekly bars (< 520) before entry"))
      ((symbol USNA) (entry_date 2005-02-01)
       (detail
        "Virgin_territory but only 502 weekly bars (< 520) before entry"))
      ((symbol UNVR) (entry_date 2022-03-15)
       (detail
        "Virgin_territory but only 354 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 86)
    (n_skipped 255)
    (specimens
     (((symbol ZGN) (entry_date 2023-09-08)
       (detail "prior_top=15.43 within +25% of entry=14.25"))
      ((symbol WRLD) (entry_date 2010-03-12)
       (detail "prior_top=49.25 within +25% of entry=43.75"))
      ((symbol WLY) (entry_date 2021-02-05)
       (detail "prior_top=52.55 within +25% of entry=50.09"))
      ((symbol UNVR) (entry_date 2022-03-15)
       (detail "prior_top=32.43 within +25% of entry=32.37"))
      ((symbol UMAC) (entry_date 2026-01-15)
       (detail "prior_top=18.73 within +25% of entry=17.59"))
      ((symbol UHS) (entry_date 2018-08-22)
       (detail "prior_top=138.68 within +25% of entry=128.84"))
      ((symbol TWX1) (entry_date 2000-01-28)
       (detail "prior_top=91.12 within +25% of entry=80.60"))
      ((symbol TKO) (entry_date 2017-03-23)
       (detail "prior_top=25.14 within +25% of entry=21.77"))
      ((symbol TEF) (entry_date 2024-04-29)
       (detail "prior_top=5.02 within +25% of entry=4.55"))
      ((symbol SKYW) (entry_date 2013-11-23)
       (detail "prior_top=16.83 within +25% of entry=16.41")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 14)
    (n_skipped 255)
    (specimens
     (((symbol WBTN) (entry_date 2025-08-30)
       (detail "entry_wk_close=14.41 > prior=8.92 (spike>60%)"))
      ((symbol VLN) (entry_date 2026-05-16)
       (detail "entry_wk_close=3.22 > prior=1.79 (spike>60%)"))
      ((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol PYX) (entry_date 2018-10-08)
       (detail "entry_wk_close=43.05 > prior=18.60 (spike>60%)"))
      ((symbol OKLO) (entry_date 2024-10-26)
       (detail "entry_wk_close=21.67 > prior=11.19 (spike>60%)"))
      ((symbol IPSU) (entry_date 2011-06-02)
       (detail "entry_wk_close=21.47 > prior=12.99 (spike>60%)"))
      ((symbol GRPN) (entry_date 2025-03-26)
       (detail "entry_wk_close=18.82 > prior=11.12 (spike>60%)"))
      ((symbol EXK) (entry_date 2020-07-20)
       (detail "entry_wk_close=4.20 > prior=2.14 (spike>60%)"))
      ((symbol EOSE) (entry_date 2023-06-28)
       (detail "entry_wk_close=4.34 > prior=2.43 (spike>60%)"))
      ((symbol ECHO) (entry_date 2025-08-26)
       (detail "entry_wk_close=61.79 > prior=26.93 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 19)
    (n_skipped 0)
    (specimens
     (((symbol VOYA) (entry_date 2017-11-29)
       (detail
        "installed_stop=36.7008 vs fill=43.5100 -> dist=0.1565 > gate=0.1500"))
      ((symbol TRN) (entry_date 2013-10-31)
       (detail
        "installed_stop=32.9664 vs fill=17.1800 -> dist=0.9189 > gate=0.1500"))
      ((symbol MNRO) (entry_date 2010-07-30)
       (detail
        "installed_stop=39.1488 vs fill=27.2100 -> dist=0.4388 > gate=0.1500"))
      ((symbol MCK) (entry_date 2020-05-28)
       (detail
        "installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500"))
      ((symbol GRA) (entry_date 2016-01-22)
       (detail
        "installed_stop=73.1724 vs fill=86.3000 -> dist=0.1521 > gate=0.1500"))
      ((symbol GGG) (entry_date 2000-11-16)
       (detail
        "installed_stop=31.7399 vs fill=24.2600 -> dist=0.3083 > gate=0.1500"))
      ((symbol FULT) (entry_date 2002-03-07)
       (detail
        "installed_stop=23.3952 vs fill=19.5000 -> dist=0.1998 > gate=0.1500"))
      ((symbol ESI) (entry_date 2021-04-24)
       (detail
        "installed_stop=16.7424 vs fill=19.8900 -> dist=0.1583 > gate=0.1500"))
      ((symbol EOG) (entry_date 2000-05-01)
       (detail
        "installed_stop=21.9602 vs fill=25.8500 -> dist=0.1505 > gate=0.1500"))
      ((symbol ENB) (entry_date 2004-10-29)
       (detail
        "installed_stop=36.2112 vs fill=21.2700 -> dist=0.7025 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 147)
    (n_skipped 4)
    (specimens
     (((symbol ZWS) (entry_date 2018-10-06)
       (detail
        "no bar on entry_date 2018-10-06 (nearest earlier bar: 2018-10-05)"))
      ((symbol WTTR) (entry_date 2024-03-16)
       (detail
        "no bar on entry_date 2024-03-16 (nearest earlier bar: 2024-03-15)"))
      ((symbol WSO) (entry_date 2010-03-06)
       (detail
        "no bar on entry_date 2010-03-06 (nearest earlier bar: 2010-03-05)"))
      ((symbol WPM) (entry_date 2024-04-20)
       (detail
        "no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)"))
      ((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)"))
      ((symbol WBTN) (entry_date 2025-08-30)
       (detail
        "no bar on entry_date 2025-08-30 (nearest earlier bar: 2025-08-29)"))
      ((symbol WBS) (entry_date 2011-01-22)
       (detail
        "no bar on entry_date 2011-01-22 (nearest earlier bar: 2011-01-21)"))
      ((symbol WAFD) (entry_date 2013-06-29)
       (detail
        "no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)"))
      ((symbol VVC) (entry_date 2018-04-28)
       (detail
        "no bar on entry_date 2018-04-28 (nearest earlier bar: 2018-04-27)"))
      ((symbol VMC) (entry_date 2012-10-06)
       (detail
        "no bar on entry_date 2012-10-06 (nearest earlier bar: 2012-10-05)")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 17)
    (n_skipped 0)
    (specimens
     (((symbol ANIP) (entry_date 2024-03-02)
       (detail
        "median close 25.97 over 6151 bars (2001-07-24..2026-06-10); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0"))
      ((symbol ATLKY) (entry_date 2026-01-15)
       (detail
        "median close 24.88 over 7437 bars (1996-11-18..2026-06-10); bar 2003-09-01 close 1000000.00 (+3311246.00% vs prior close 30.20) on volume 0"))
      ((symbol BHRB) (entry_date 2022-09-20)
       (detail
        "median close 2015.05 over 5914 bars (1995-08-04..2026-06-10); bar 2003-10-07 close 2001.00 (-99.80% vs prior close 1000000.00) on volume 0"))
      ((symbol BLNK) (entry_date 2020-07-29)
       (detail
        "median close 1.61 over 4080 bars (2008-07-15..2026-06-10); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0"))
      ((symbol BOKF) (entry_date 2003-06-04)
       (detail
        "median close 49.75 over 8753 bars (1991-09-05..2026-06-10); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0"))
      ((symbol BRK-A) (entry_date 2006-05-18)
       (detail
        "median close 83000.00 over 11227 bars (1980-03-17..2026-06-10), above the 10000.00 ceiling"))
      ((symbol CIR) (entry_date 2013-04-24)
       (detail
        "median close 32.28 over 6046 bars (1999-10-18..2023-11-16); bar 2023-11-06 close 0.00 (-100.00% vs prior close 56.00) on volume 0"))
      ((symbol CYRX) (entry_date 2020-05-18)
       (detail
        "median close 2.91 over 5233 bars (2005-08-22..2026-06-10); bar 2010-02-05 close 9.30 (+900.00% vs prior close 0.93) on volume 0"))
      ((symbol FLO) (entry_date 2020-03-09)
       (detail
        "median close 18.19 over 11653 bars (1980-03-17..2026-06-10); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0"))
      ((symbol IHG) (entry_date 2024-10-15)
       (detail
        "median close 37.40 over 5830 bars (2003-04-08..2026-06-10); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0")))))))
 (audit_join ((matched 748) (total 748))))
