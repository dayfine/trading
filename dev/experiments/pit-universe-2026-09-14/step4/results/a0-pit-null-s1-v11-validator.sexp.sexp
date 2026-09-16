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
   ((id V7) (severity Invariant) (passed false) (n_violations 117)
    (n_skipped 0)
    (specimens
     (((symbol ZS) (entry_date 2020-05-29)
       (detail
        "Virgin_territory but only 117 weekly bars (< 520) before entry"))
      ((symbol ZG) (entry_date 2020-02-20)
       (detail
        "Virgin_territory but only 453 weekly bars (< 520) before entry"))
      ((symbol XPOF) (entry_date 2023-01-27)
       (detail
        "Virgin_territory but only 79 weekly bars (< 520) before entry"))
      ((symbol XERS) (entry_date 2024-02-14)
       (detail
        "Virgin_territory but only 297 weekly bars (< 520) before entry"))
      ((symbol WSC) (entry_date 2020-11-06)
       (detail
        "Virgin_territory but only 263 weekly bars (< 520) before entry"))
      ((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "Virgin_territory but only 214 weekly bars (< 520) before entry"))
      ((symbol WING) (entry_date 2017-08-08)
       (detail
        "Virgin_territory but only 113 weekly bars (< 520) before entry"))
      ((symbol VRSK) (entry_date 2017-02-22)
       (detail
        "Virgin_territory but only 388 weekly bars (< 520) before entry"))
      ((symbol VLCY) (entry_date 2002-03-19)
       (detail
        "Virgin_territory but only 222 weekly bars (< 520) before entry"))
      ((symbol VICI) (entry_date 2019-10-16)
       (detail
        "Virgin_territory but only 105 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 84)
    (n_skipped 249)
    (specimens
     (((symbol ZGN) (entry_date 2023-09-08)
       (detail "prior_top=15.43 within +25% of entry=14.25"))
      ((symbol WRLD) (entry_date 2010-03-12)
       (detail "prior_top=49.25 within +25% of entry=43.75"))
      ((symbol WFG) (entry_date 2024-08-26)
       (detail "prior_top=92.49 within +25% of entry=90.07"))
      ((symbol VRTX) (entry_date 2014-06-28)
       (detail "prior_top=93.77 within +25% of entry=92.22"))
      ((symbol UNVR) (entry_date 2022-03-15)
       (detail "prior_top=32.43 within +25% of entry=32.37"))
      ((symbol UHS) (entry_date 2018-08-22)
       (detail "prior_top=138.68 within +25% of entry=128.84"))
      ((symbol TWX1) (entry_date 2000-01-28)
       (detail "prior_top=91.12 within +25% of entry=80.60"))
      ((symbol TRC) (entry_date 2026-03-14)
       (detail "prior_top=21.27 within +25% of entry=19.50"))
      ((symbol THI) (entry_date 2014-08-09)
       (detail "prior_top=62.34 within +25% of entry=61.84"))
      ((symbol TGTX) (entry_date 2018-03-05)
       (detail "prior_top=18.68 within +25% of entry=15.45")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 15)
    (n_skipped 249)
    (specimens
     (((symbol VUZI) (entry_date 2026-05-29)
       (detail "entry_wk_close=4.60 > prior=2.84 (spike>60%)"))
      ((symbol VLN) (entry_date 2026-05-16)
       (detail "entry_wk_close=3.22 > prior=1.79 (spike>60%)"))
      ((symbol VERI) (entry_date 2020-06-02)
       (detail "entry_wk_close=11.16 > prior=5.93 (spike>60%)"))
      ((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol PYX) (entry_date 2018-10-08)
       (detail "entry_wk_close=43.05 > prior=18.60 (spike>60%)"))
      ((symbol MVL) (entry_date 2002-03-08)
       (detail "entry_wk_close=5.33 > prior=3.00 (spike>60%)"))
      ((symbol ISEE) (entry_date 2022-09-30)
       (detail "entry_wk_close=17.94 > prior=9.44 (spike>60%)"))
      ((symbol IPSU) (entry_date 2011-06-02)
       (detail "entry_wk_close=21.47 > prior=12.99 (spike>60%)"))
      ((symbol GSIT) (entry_date 2025-10-20)
       (detail "entry_wk_close=9.23 > prior=3.84 (spike>60%)"))
      ((symbol EXK) (entry_date 2020-07-20)
       (detail "entry_wk_close=4.20 > prior=2.14 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 17)
    (n_skipped 0)
    (specimens
     (((symbol YMM) (entry_date 2024-11-20)
       (detail
        "installed_stop=8.2848 vs fill=9.7700 -> dist=0.1520 > gate=0.1500"))
      ((symbol XERS) (entry_date 2024-02-14)
       (detail
        "installed_stop=2.6496 vs fill=3.1500 -> dist=0.1589 > gate=0.1500"))
      ((symbol TRN) (entry_date 2013-10-31)
       (detail
        "installed_stop=32.9664 vs fill=17.1800 -> dist=0.9189 > gate=0.1500"))
      ((symbol SOUN) (entry_date 2024-04-02)
       (detail
        "installed_stop=4.3750 vs fill=5.2400 -> dist=0.1651 > gate=0.1500"))
      ((symbol SMTC) (entry_date 2018-04-10)
       (detail
        "installed_stop=35.8750 vs fill=42.2800 -> dist=0.1515 > gate=0.1500"))
      ((symbol NJDCY) (entry_date 2015-06-08)
       (detail
        "installed_stop=15.2160 vs fill=17.9500 -> dist=0.1523 > gate=0.1500"))
      ((symbol NEOG) (entry_date 2017-09-05)
       (detail
        "installed_stop=60.8750 vs fill=52.7700 -> dist=0.1536 > gate=0.1500"))
      ((symbol MGM) (entry_date 2001-09-18)
       (detail
        "installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500"))
      ((symbol GRA) (entry_date 2016-01-22)
       (detail
        "installed_stop=73.1724 vs fill=86.3000 -> dist=0.1521 > gate=0.1500"))
      ((symbol FULT) (entry_date 2002-03-07)
       (detail
        "installed_stop=23.3952 vs fill=19.5000 -> dist=0.1998 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 135)
    (n_skipped 4)
    (specimens
     (((symbol ZWS) (entry_date 2018-10-06)
       (detail
        "no bar on entry_date 2018-10-06 (nearest earlier bar: 2018-10-05)"))
      ((symbol ZIM) (entry_date 2024-05-11)
       (detail
        "no bar on entry_date 2024-05-11 (nearest earlier bar: 2024-05-10)"))
      ((symbol WSO) (entry_date 2010-03-06)
       (detail
        "no bar on entry_date 2010-03-06 (nearest earlier bar: 2010-03-05)"))
      ((symbol WPM) (entry_date 2024-04-20)
       (detail
        "no bar on entry_date 2024-04-20 (nearest earlier bar: 2024-04-19)"))
      ((symbol WPC) (entry_date 2012-10-06)
       (detail
        "no bar on entry_date 2012-10-06 (nearest earlier bar: 2012-10-05)"))
      ((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)"))
      ((symbol WING) (entry_date 2017-08-08)
       (detail
        "entry_price=31.6000 outside 2017-08-08 bar [32.7300, 34.1600]"))
      ((symbol WAFD) (entry_date 2013-06-29)
       (detail
        "no bar on entry_date 2013-06-29 (nearest earlier bar: 2013-06-28)"))
      ((symbol VVC) (entry_date 2018-04-28)
       (detail
        "no bar on entry_date 2018-04-28 (nearest earlier bar: 2018-04-27)"))
      ((symbol VRTX) (entry_date 2014-06-28)
       (detail
        "no bar on entry_date 2014-06-28 (nearest earlier bar: 2014-06-27)")))))
   ((id V14) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 0)
    (specimens
     (((symbol CLE) (entry_date 2014-11-18)
       (detail
        "force_liquidation exit 2014-11-19 (entry 2014-11-18 @ 37.65, exit @ 0.71)")))))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 17)
    (n_skipped 0)
    (specimens
     (((symbol BLFS) (entry_date 2021-07-08)
       (detail
        "median close 1.72 over 9201 bars (1989-11-22..2026-06-08); bar 2014-01-29 close 8.12 (+1300.00% vs prior close 0.58) on volume 0"))
      ((symbol BLNK) (entry_date 2020-07-29)
       (detail
        "median close 1.61 over 4078 bars (2008-07-15..2026-06-08); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0"))
      ((symbol BOKF) (entry_date 2003-06-04)
       (detail
        "median close 49.73 over 8751 bars (1991-09-05..2026-06-08); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0"))
      ((symbol BRK-A) (entry_date 2006-05-18)
       (detail
        "median close 83000.00 over 11225 bars (1980-03-17..2026-06-08), above the 10000.00 ceiling"))
      ((symbol CEQP) (entry_date 2018-01-22)
       (detail
        "median close 25.49 over 5608 bars (2001-07-26..2023-11-16); bar 2023-11-14 close 0.00 (-100.00% vs prior close 28.26) on volume 0"))
      ((symbol CIR) (entry_date 2013-04-24)
       (detail
        "median close 32.28 over 6046 bars (1999-10-18..2023-11-16); bar 2023-11-06 close 0.00 (-100.00% vs prior close 56.00) on volume 0"))
      ((symbol CLE) (entry_date 2014-11-18)
       (detail
        "median close 19.00 over 4813 bars (1997-12-31..2018-06-28); bar 2014-06-09 close 0.07 (-94.53% vs prior close 1.28) on volume 0"))
      ((symbol CSKI) (entry_date 2009-12-19)
       (detail
        "median close 0.20 over 5186 bars (1995-02-01..2015-10-05); bar 2002-12-13 close 0.45 (+542.86% vs prior close 0.07) on volume 0"))
      ((symbol FLO) (entry_date 2020-03-09)
       (detail
        "median close 18.19 over 11651 bars (1980-03-17..2026-06-08); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0"))
      ((symbol IOVA) (entry_date 2020-03-24)
       (detail
        "median close 7.47 over 3934 bars (2010-10-15..2026-06-08); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0")))))))
 (audit_join ((matched 766) (total 766))))
