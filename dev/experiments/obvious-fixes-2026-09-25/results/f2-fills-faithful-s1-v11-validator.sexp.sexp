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
      ((symbol Z) (entry_date 2020-02-20)
       (detail
        "Virgin_territory but only 239 weekly bars (< 520) before entry"))
      ((symbol XPOF) (entry_date 2023-01-27)
       (detail
        "Virgin_territory but only 79 weekly bars (< 520) before entry"))
      ((symbol XERS) (entry_date 2024-02-14)
       (detail
        "Virgin_territory but only 297 weekly bars (< 520) before entry"))
      ((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "Virgin_territory but only 214 weekly bars (< 520) before entry"))
      ((symbol WING) (entry_date 2017-08-08)
       (detail
        "Virgin_territory but only 113 weekly bars (< 520) before entry"))
      ((symbol VLCY) (entry_date 2002-03-19)
       (detail
        "Virgin_territory but only 222 weekly bars (< 520) before entry"))
      ((symbol VICI) (entry_date 2019-10-16)
       (detail
        "Virgin_territory but only 105 weekly bars (< 520) before entry"))
      ((symbol VC) (entry_date 2015-05-22)
       (detail
        "Virgin_territory but only 245 weekly bars (< 520) before entry"))
      ((symbol VAL) (entry_date 2022-10-27)
       (detail
        "Virgin_territory but only 77 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 78)
    (n_skipped 244)
    (specimens
     (((symbol ZGN) (entry_date 2023-09-08)
       (detail "prior_top=15.43 within +25% of entry=14.25"))
      ((symbol WRLD) (entry_date 2010-03-12)
       (detail "prior_top=49.25 within +25% of entry=43.75"))
      ((symbol WOLF_old2) (entry_date 2021-11-22)
       (detail "prior_top=139.55 within +25% of entry=133.00"))
      ((symbol WIX) (entry_date 2021-04-28)
       (detail "prior_top=353.09 within +25% of entry=320.94"))
      ((symbol TWX1) (entry_date 2000-01-28)
       (detail "prior_top=91.12 within +25% of entry=80.60"))
      ((symbol TGTX) (entry_date 2018-03-05)
       (detail "prior_top=18.68 within +25% of entry=15.45"))
      ((symbol TEF) (entry_date 2024-04-29)
       (detail "prior_top=5.02 within +25% of entry=4.55"))
      ((symbol STVN) (entry_date 2023-03-02)
       (detail "prior_top=28.27 within +25% of entry=23.47"))
      ((symbol SAND) (entry_date 2025-06-02)
       (detail "prior_top=9.56 within +25% of entry=9.17"))
      ((symbol RCRC) (entry_date 2006-12-01)
       (detail "prior_top=44.66 within +25% of entry=41.35")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 16)
    (n_skipped 244)
    (specimens
     (((symbol VUZI) (entry_date 2026-05-29)
       (detail "entry_wk_close=4.60 > prior=2.84 (spike>60%)"))
      ((symbol SATL) (entry_date 2026-04-01)
       (detail "entry_wk_close=6.77 > prior=3.09 (spike>60%)"))
      ((symbol MVL) (entry_date 2002-03-08)
       (detail "entry_wk_close=5.33 > prior=3.00 (spike>60%)"))
      ((symbol ISEE) (entry_date 2022-09-30)
       (detail "entry_wk_close=17.94 > prior=9.44 (spike>60%)"))
      ((symbol IPSU) (entry_date 2011-06-02)
       (detail "entry_wk_close=21.47 > prior=12.99 (spike>60%)"))
      ((symbol GSIT) (entry_date 2025-10-20)
       (detail "entry_wk_close=9.23 > prior=3.84 (spike>60%)"))
      ((symbol GRPN) (entry_date 2025-03-26)
       (detail "entry_wk_close=18.82 > prior=11.12 (spike>60%)"))
      ((symbol FNMA) (entry_date 2013-05-24)
       (detail "entry_wk_close=2.97 > prior=0.83 (spike>60%)"))
      ((symbol EXK) (entry_date 2020-07-20)
       (detail "entry_wk_close=4.20 > prior=2.14 (spike>60%)"))
      ((symbol EOSE) (entry_date 2023-06-28)
       (detail "entry_wk_close=4.34 > prior=2.43 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 20)
    (n_skipped 0)
    (specimens
     (((symbol XERS) (entry_date 2024-02-14)
       (detail
        "installed_stop=2.6496 vs fill=3.1500 -> dist=0.1589 > gate=0.1500"))
      ((symbol SMTC) (entry_date 2018-04-10)
       (detail
        "installed_stop=35.8750 vs fill=42.2800 -> dist=0.1515 > gate=0.1500"))
      ((symbol PRTA) (entry_date 2017-09-27)
       (detail
        "installed_stop=58.7808 vs fill=69.4700 -> dist=0.1539 > gate=0.1500"))
      ((symbol NJDCY) (entry_date 2015-06-08)
       (detail
        "installed_stop=15.2160 vs fill=17.9500 -> dist=0.1523 > gate=0.1500"))
      ((symbol NEOG) (entry_date 2017-09-05)
       (detail
        "installed_stop=60.8750 vs fill=52.7700 -> dist=0.1536 > gate=0.1500"))
      ((symbol MGM) (entry_date 2001-09-18)
       (detail
        "installed_stop=17.7000 vs fill=21.0100 -> dist=0.1575 > gate=0.1500"))
      ((symbol MEI) (entry_date 2014-09-04)
       (detail
        "installed_stop=32.4096 vs fill=38.4700 -> dist=0.1575 > gate=0.1500"))
      ((symbol MCK) (entry_date 2020-05-28)
       (detail
        "installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500"))
      ((symbol LZB) (entry_date 2024-07-15)
       (detail
        "installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500"))
      ((symbol GRA) (entry_date 2016-01-22)
       (detail
        "installed_stop=73.1724 vs fill=86.3000 -> dist=0.1521 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 27)
    (n_skipped 3)
    (specimens
     (((symbol WSFS) (entry_date 2006-11-10)
       (detail
        "exit_price=65.5200 outside 2006-11-20 bar [65.5201, 66.5500]"))
      ((symbol WRLD) (entry_date 2010-03-12)
       (detail
        "exit_price=41.9300 outside 2010-03-15 bar [41.9301, 44.1000]"))
      ((symbol WLL1) (entry_date 2002-01-22)
       (detail
        "no bar on exit_date 2002-03-15 (nearest earlier bar: 2002-03-14)"))
      ((symbol WIRE) (entry_date 2023-12-14)
       (detail
        "no bar on exit_date 2024-07-03 (nearest earlier bar: 2024-07-02)"))
      ((symbol WING) (entry_date 2017-08-08)
       (detail
        "entry_price=31.6000 outside 2017-08-08 bar [32.7300, 34.1600]"))
      ((symbol VRTX) (entry_date 2001-03-12)
       (detail
        "exit_price=31.6400 outside 2001-03-15 bar [31.6406, 35.6250]"))
      ((symbol SAFM) (entry_date 2022-05-31)
       (detail
        "no bar on exit_date 2022-07-25 (nearest earlier bar: 2022-07-22)"))
      ((symbol PAYC) (entry_date 2021-08-09)
       (detail
        "exit_price=454.0800 outside 2021-08-10 bar [454.0850, 472.4900]"))
      ((symbol NPSNY) (entry_date 2009-08-28)
       (detail
        "entry_price=32.1200 outside 2009-08-28 bar [31.1960, 32.1180]"))
      ((symbol NEOG) (entry_date 2017-09-05)
       (detail
        "entry_price=52.7700 outside 2017-09-05 bar [68.8760, 70.4406]")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 58)
    (n_skipped 0)
    (specimens
     (((symbol ZQKSQ) (entry_date 2013-05-22)
       (detail
        "entry bar 2013-05-22 open=7.9200 low=7.7200 close=7.8200 vs stop=7.6760, exit=7.6600"))
      ((symbol Z) (entry_date 2020-02-20)
       (detail
        "entry bar 2020-02-20 open=62.4700 low=61.9300 close=63.6300 vs stop=63.3852, exit=63.1600"))
      ((symbol XRAY) (entry_date 2000-04-25)
       (detail
        "entry bar 2000-04-25 open=27.8750 low=27.8750 close=29.1876 vs stop=28.2787, exit=28.2500"))
      ((symbol WRLD) (entry_date 2010-03-12)
       (detail
        "entry bar 2010-03-12 open=43.0000 low=42.5200 close=43.6500 vs stop=41.9694, exit=41.9300"))
      ((symbol VUZI) (entry_date 2026-05-29)
       (detail
        "entry bar 2026-05-29 open=4.5200 low=4.2200 close=4.6000 vs stop=4.1413, exit=4.1300"))
      ((symbol VRNS) (entry_date 2022-01-27)
       (detail
        "entry bar 2022-01-27 open=34.2100 low=32.4900 close=32.7600 vs stop=30.9184, exit=32.1100"))
      ((symbol UTL) (entry_date 2022-07-01)
       (detail
        "entry bar 2022-07-01 open=58.7100 low=58.0800 close=61.0000 vs stop=57.2358, exit=57.1900"))
      ((symbol UMBF) (entry_date 2024-07-31)
       (detail
        "entry bar 2024-07-31 open=103.0000 low=100.7500 close=102.0200 vs stop=100.9806, exit=100.9500"))
      ((symbol UEC) (entry_date 2021-10-18)
       (detail
        "entry bar 2021-10-18 open=3.4600 low=3.4300 close=3.4900 vs stop=3.3722, exit=3.3600"))
      ((symbol UBS) (entry_date 2014-11-26)
       (detail
        "entry bar 2014-11-26 open=17.5500 low=17.5200 close=23.2000 vs stop=21.8103, exit=18.0900")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 0)
    (specimens
     (((symbol ASPS) (entry_date 2017-04-20)
       (detail
        "force_liquidation exit 2017-04-21 (entry 2017-04-20 @ 35.53, exit @ 26.75)")))))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 16)
    (n_skipped 0)
    (specimens
     (((symbol ARJ) (entry_date 2005-12-29)
       (detail
        "median close 0.16 over 4552 bars (1999-02-09..2017-03-13); bar 2010-01-29 close 0.13 (-99.55% vs prior close 28.25) on volume 0"))
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
      ((symbol DUOT) (entry_date 2026-06-08)
       (detail
        "median close 2.72 over 3143 bars (2008-08-13..2026-06-23); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0"))
      ((symbol FIT) (entry_date 2020-12-03)
       (detail
        "median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0"))
      ((symbol FLO) (entry_date 2020-03-09)
       (detail
        "median close 18.17 over 11661 bars (1980-03-17..2026-06-23); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0"))
      ((symbol IOVA) (entry_date 2020-03-24)
       (detail
        "median close 7.45 over 3944 bars (2010-10-15..2026-06-23); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0"))
      ((symbol MVL) (entry_date 2002-03-08)
       (detail
        "median close 9.00 over 4795 bars (1999-01-04..2018-01-24); bar 2010-01-26 close 60.00 (+96.88% vs prior close 30.48) on volume 0")))))))
 (audit_join ((matched 746) (total 746))))
