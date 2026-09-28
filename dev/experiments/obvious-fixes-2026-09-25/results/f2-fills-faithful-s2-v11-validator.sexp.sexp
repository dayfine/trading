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
     (((symbol AGYS) (entry_date 2006-01-09)
       (detail "twin positions: AGYS/HXL")))))
   ((id V7) (severity Invariant) (passed false) (n_violations 115)
    (n_skipped 0)
    (specimens
     (((symbol ZS) (entry_date 2020-05-29)
       (detail
        "Virgin_territory but only 117 weekly bars (< 520) before entry"))
      ((symbol Z) (entry_date 2020-02-20)
       (detail
        "Virgin_territory but only 239 weekly bars (< 520) before entry"))
      ((symbol XPOF) (entry_date 2023-01-27)
       (detail
        "Virgin_territory but only 79 weekly bars (< 520) before entry"))
      ((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "Virgin_territory but only 214 weekly bars (< 520) before entry"))
      ((symbol VOYA) (entry_date 2017-11-29)
       (detail
        "Virgin_territory but only 241 weekly bars (< 520) before entry"))
      ((symbol VNA) (entry_date 2015-02-05)
       (detail
        "Virgin_territory but only 258 weekly bars (< 520) before entry"))
      ((symbol VLCY) (entry_date 2002-03-19)
       (detail
        "Virgin_territory but only 222 weekly bars (< 520) before entry"))
      ((symbol VC) (entry_date 2015-05-22)
       (detail
        "Virgin_territory but only 245 weekly bars (< 520) before entry"))
      ((symbol VAL) (entry_date 2022-10-27)
       (detail
        "Virgin_territory but only 77 weekly bars (< 520) before entry"))
      ((symbol UGP) (entry_date 2006-10-20)
       (detail
        "Virgin_territory but only 370 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 85)
    (n_skipped 246)
    (specimens
     (((symbol ZWS) (entry_date 2024-09-23)
       (detail "prior_top=36.34 within +25% of entry=34.83"))
      ((symbol ZGN) (entry_date 2023-09-08)
       (detail "prior_top=15.43 within +25% of entry=14.25"))
      ((symbol X) (entry_date 2023-09-19)
       (detail "prior_top=37.63 within +25% of entry=31.85"))
      ((symbol VRNS) (entry_date 2021-07-21)
       (detail "prior_top=71.50 within +25% of entry=60.99"))
      ((symbol URBN) (entry_date 2025-12-22)
       (detail "prior_top=81.84 within +25% of entry=81.28"))
      ((symbol UMAC) (entry_date 2026-01-15)
       (detail "prior_top=18.73 within +25% of entry=17.82"))
      ((symbol TWX1) (entry_date 2000-01-28)
       (detail "prior_top=91.12 within +25% of entry=80.60"))
      ((symbol TVTX) (entry_date 2025-09-22)
       (detail "prior_top=31.77 within +25% of entry=25.42"))
      ((symbol STVN) (entry_date 2023-03-02)
       (detail "prior_top=28.27 within +25% of entry=23.47"))
      ((symbol SKYW) (entry_date 2013-11-19)
       (detail "prior_top=16.83 within +25% of entry=16.40")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 14)
    (n_skipped 246)
    (specimens
     (((symbol VUZI) (entry_date 2026-05-29)
       (detail "entry_wk_close=4.60 > prior=2.84 (spike>60%)"))
      ((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol RCF-UN) (entry_date 2007-11-15)
       (detail "entry_wk_close=82.50 > prior=50.30 (spike>60%)"))
      ((symbol MVL) (entry_date 2002-03-08)
       (detail "entry_wk_close=5.33 > prior=3.00 (spike>60%)"))
      ((symbol IPSU) (entry_date 2011-06-02)
       (detail "entry_wk_close=21.47 > prior=12.99 (spike>60%)"))
      ((symbol GSIT) (entry_date 2025-10-20)
       (detail "entry_wk_close=9.23 > prior=3.84 (spike>60%)"))
      ((symbol EXK) (entry_date 2020-07-20)
       (detail "entry_wk_close=4.20 > prior=2.14 (spike>60%)"))
      ((symbol EOSE) (entry_date 2023-06-28)
       (detail "entry_wk_close=4.34 > prior=2.43 (spike>60%)"))
      ((symbol ECHO) (entry_date 2025-08-26)
       (detail "entry_wk_close=61.79 > prior=26.93 (spike>60%)"))
      ((symbol CUTRQ) (entry_date 2022-03-28)
       (detail "entry_wk_close=72.31 > prior=40.49 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 18)
    (n_skipped 0)
    (specimens
     (((symbol VOYA) (entry_date 2017-11-29)
       (detail
        "installed_stop=36.7008 vs fill=43.5100 -> dist=0.1565 > gate=0.1500"))
      ((symbol TRN) (entry_date 2013-10-31)
       (detail
        "installed_stop=32.9664 vs fill=17.1800 -> dist=0.9189 > gate=0.1500"))
      ((symbol SOUN) (entry_date 2024-04-02)
       (detail
        "installed_stop=4.3750 vs fill=5.2400 -> dist=0.1651 > gate=0.1500"))
      ((symbol NEOG) (entry_date 2017-09-05)
       (detail
        "installed_stop=60.8750 vs fill=52.8100 -> dist=0.1527 > gate=0.1500"))
      ((symbol MGM) (entry_date 2001-09-18)
       (detail
        "installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500"))
      ((symbol MCK) (entry_date 2020-05-28)
       (detail
        "installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500"))
      ((symbol LPG) (entry_date 2023-09-15)
       (detail
        "installed_stop=23.2022 vs fill=27.3000 -> dist=0.1501 > gate=0.1500"))
      ((symbol GRA) (entry_date 2016-01-22)
       (detail
        "installed_stop=73.1724 vs fill=86.3000 -> dist=0.1521 > gate=0.1500"))
      ((symbol GC) (entry_date 2020-04-06)
       (detail
        "installed_stop=1392.8640 vs fill=1647.7000 -> dist=0.1547 > gate=0.1500"))
      ((symbol GAS1) (entry_date 2007-04-04)
       (detail
        "installed_stop=42.6816 vs fill=50.2400 -> dist=0.1504 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 23)
    (n_skipped 5)
    (specimens
     (((symbol WSFS) (entry_date 2006-11-10)
       (detail
        "exit_price=65.5200 outside 2006-11-20 bar [65.5201, 66.5500]"))
      ((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)"))
      ((symbol VRTX) (entry_date 2001-03-12)
       (detail
        "exit_price=31.6400 outside 2001-03-15 bar [31.6406, 35.6250]"))
      ((symbol PAYC) (entry_date 2021-08-09)
       (detail
        "exit_price=454.0800 outside 2021-08-10 bar [454.0850, 472.4900]"))
      ((symbol NPSNY) (entry_date 2009-08-28)
       (detail
        "entry_price=32.1200 outside 2009-08-28 bar [31.1960, 32.1180]"))
      ((symbol NEOG) (entry_date 2017-09-05)
       (detail
        "entry_price=52.8100 outside 2017-09-05 bar [68.8760, 70.4406]"))
      ((symbol MMSI) (entry_date 2011-03-14)
       (detail
        "entry_price=14.3300 outside 2011-03-14 bar [17.5400, 17.9500]"))
      ((symbol MMCN) (entry_date 2000-08-11)
       (detail
        "no bar on exit_date 2000-10-26 (nearest earlier bar: 2000-10-25)"))
      ((symbol KYOCY) (entry_date 2019-04-26)
       (detail
        "entry_price=64.4500 outside 2019-04-26 bar [64.4530, 64.4530]"))
      ((symbol HZNP) (entry_date 2023-10-09)
       (detail
        "no bar on exit_date 2023-10-10 (nearest earlier bar: 2023-10-09)")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 64)
    (n_skipped 0)
    (specimens
     (((symbol Z) (entry_date 2020-02-20)
       (detail
        "entry bar 2020-02-20 open=62.4700 low=61.9300 close=63.6300 vs stop=63.3905, exit=63.1600"))
      ((symbol XRAY) (entry_date 2000-04-25)
       (detail
        "entry bar 2000-04-25 open=27.8750 low=27.8750 close=29.1876 vs stop=28.2853, exit=28.2500"))
      ((symbol VUZI) (entry_date 2026-05-29)
       (detail
        "entry bar 2026-05-29 open=4.5200 low=4.2200 close=4.6000 vs stop=4.1413, exit=4.0400"))
      ((symbol VNA) (entry_date 2015-02-05)
       (detail
        "entry bar 2015-02-05 open=4500.0000 low=4300.0000 close=4300.0000 vs stop=4244.8500, exit=4240.1900"))
      ((symbol UTL) (entry_date 2022-07-01)
       (detail
        "entry bar 2022-07-01 open=58.7100 low=58.0800 close=61.0000 vs stop=57.2355, exit=57.2300"))
      ((symbol URBN) (entry_date 2025-12-22)
       (detail
        "entry bar 2025-12-22 open=80.4200 low=79.8700 close=80.1200 vs stop=77.8662, exit=77.7900"))
      ((symbol UMBF) (entry_date 2024-07-31)
       (detail
        "entry bar 2024-07-31 open=103.0000 low=100.7500 close=102.0200 vs stop=100.9815, exit=100.5300"))
      ((symbol UBS) (entry_date 2014-11-26)
       (detail
        "entry bar 2014-11-26 open=17.5500 low=17.5200 close=23.2000 vs stop=21.8068, exit=18.0900"))
      ((symbol TRMD) (entry_date 2024-01-24)
       (detail
        "entry bar 2024-01-24 open=36.5500 low=35.8800 close=35.9700 vs stop=35.3118, exit=35.2700"))
      ((symbol TR) (entry_date 2021-01-27)
       (detail
        "entry bar 2021-01-27 open=45.1599 low=39.5799 close=42.8501 vs stop=39.3798, exit=39.2500")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 17)
    (n_skipped 0)
    (specimens
     (((symbol APLS) (entry_date 2023-04-03)
       (detail
        "median close 32.72 over 2165 bars (2017-11-09..2026-06-23); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0"))
      ((symbol BLNK) (entry_date 2020-07-29)
       (detail
        "median close 1.61 over 4088 bars (2008-07-15..2026-06-23); bar 2009-01-20 close 1.50 (+500.00% vs prior close 0.25) on volume 0"))
      ((symbol BOKF) (entry_date 2003-06-04)
       (detail
        "median close 49.76 over 8761 bars (1991-09-05..2026-06-23); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0"))
      ((symbol BRK-A) (entry_date 2006-05-18)
       (detail
        "median close 83100.00 over 11235 bars (1980-03-17..2026-06-23), above the 10000.00 ceiling"))
      ((symbol CECO) (entry_date 2023-10-13)
       (detail
        "median close 4.62 over 11481 bars (1980-12-02..2026-06-23); bar 1992-09-29 close 2.66 (+399.96% vs prior close 0.53) on volume 0"))
      ((symbol CIR) (entry_date 2013-04-24)
       (detail
        "median close 32.28 over 6046 bars (1999-10-18..2023-11-16); bar 2023-11-06 close 0.00 (-100.00% vs prior close 56.00) on volume 0"))
      ((symbol DNBBY) (entry_date 2016-12-01)
       (detail
        "median close 25.46 over 3947 bars (2010-09-08..2026-06-23); bar 2010-10-15 close 135.70 (-99.99% vs prior close 1000000.00) on volume 0"))
      ((symbol DUOT) (entry_date 2026-06-15)
       (detail
        "median close 2.72 over 3143 bars (2008-08-13..2026-06-23); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0"))
      ((symbol FIT) (entry_date 2020-12-03)
       (detail
        "median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0"))
      ((symbol FLO) (entry_date 2020-03-09)
       (detail
        "median close 18.17 over 11661 bars (1980-03-17..2026-06-23); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0")))))))
 (audit_join ((matched 741) (total 741))))
