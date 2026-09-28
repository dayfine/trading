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
   ((id V7) (severity Invariant) (passed false) (n_violations 25)
    (n_skipped 0)
    (specimens
     (((symbol VAL) (entry_date 2022-10-27)
       (detail
        "Virgin_territory but only 77 weekly bars (< 520) before entry"))
      ((symbol UE) (entry_date 2024-07-30)
       (detail
        "Virgin_territory but only 501 weekly bars (< 520) before entry"))
      ((symbol TWLO) (entry_date 2026-04-22)
       (detail
        "Virgin_territory but only 517 weekly bars (< 520) before entry"))
      ((symbol SHOP) (entry_date 2021-06-21)
       (detail
        "Virgin_territory but only 320 weekly bars (< 520) before entry"))
      ((symbol ROKU) (entry_date 2021-07-27)
       (detail
        "Virgin_territory but only 202 weekly bars (< 520) before entry"))
      ((symbol NTRA) (entry_date 2021-09-23)
       (detail
        "Virgin_territory but only 327 weekly bars (< 520) before entry"))
      ((symbol NEXT) (entry_date 2025-01-16)
       (detail
        "Virgin_territory but only 469 weekly bars (< 520) before entry"))
      ((symbol NET) (entry_date 2024-12-17)
       (detail
        "Virgin_territory but only 276 weekly bars (< 520) before entry"))
      ((symbol MRUS) (entry_date 2024-01-08)
       (detail
        "Virgin_territory but only 401 weekly bars (< 520) before entry"))
      ((symbol MNDT) (entry_date 2022-03-07)
       (detail
        "Virgin_territory but only 446 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 47)
    (n_skipped 18)
    (specimens
     (((symbol ZGN) (entry_date 2023-09-08)
       (detail "prior_top=15.43 within +25% of entry=14.25"))
      ((symbol X) (entry_date 2023-09-19)
       (detail "prior_top=37.63 within +25% of entry=31.75"))
      ((symbol VRNS) (entry_date 2021-07-21)
       (detail "prior_top=71.50 within +25% of entry=60.93"))
      ((symbol URBN) (entry_date 2025-03-13)
       (detail "prior_top=58.19 within +25% of entry=50.12"))
      ((symbol URBN) (entry_date 2025-12-22)
       (detail "prior_top=81.84 within +25% of entry=81.11"))
      ((symbol UMAC) (entry_date 2026-01-15)
       (detail "prior_top=18.73 within +25% of entry=17.69"))
      ((symbol PTGX) (entry_date 2025-06-02)
       (detail "prior_top=54.78 within +25% of entry=49.15"))
      ((symbol PSLV) (entry_date 2024-04-22)
       (detail "prior_top=10.04 within +25% of entry=9.21"))
      ((symbol PJT) (entry_date 2023-11-03)
       (detail "prior_top=84.12 within +25% of entry=83.60"))
      ((symbol PEN) (entry_date 2023-05-03)
       (detail "prior_top=305.99 within +25% of entry=294.35")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 3)
    (n_skipped 18)
    (specimens
     (((symbol VUZI) (entry_date 2026-05-29)
       (detail "entry_wk_close=4.60 > prior=2.84 (spike>60%)"))
      ((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol GSIT) (entry_date 2025-10-20)
       (detail "entry_wk_close=9.23 > prior=3.84 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 4)
    (n_skipped 0)
    (specimens
     (((symbol VLN) (entry_date 2026-05-26)
       (detail
        "installed_stop=2.9136 vs fill=3.4300 -> dist=0.1506 > gate=0.1500"))
      ((symbol MNSO) (entry_date 2025-01-06)
       (detail
        "installed_stop=21.8750 vs fill=26.0100 -> dist=0.1590 > gate=0.1500"))
      ((symbol LZB) (entry_date 2024-07-15)
       (detail
        "installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500"))
      ((symbol LPG) (entry_date 2023-09-15)
       (detail
        "installed_stop=23.2022 vs fill=27.3000 -> dist=0.1501 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 4)
    (n_skipped 1)
    (specimens
     (((symbol EC) (entry_date 2022-02-28)
       (detail
        "entry_price=14.7700 outside 2022-02-28 bar [15.4800, 16.1900]"))
      ((symbol CIG) (entry_date 2022-04-12)
       (detail "exit_price=3.1700 outside 2022-04-19 bar [3.1701, 3.3500]"))
      ((symbol CHS) (entry_date 2023-10-23)
       (detail
        "no bar on exit_date 2024-01-05 (nearest earlier bar: 2024-01-04)"))
      ((symbol AAGIY) (entry_date 2023-01-04)
       (detail
        "entry_price=46.7300 outside 2023-01-04 bar [46.7310, 46.7310]")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 21)
    (n_skipped 0)
    (specimens
     (((symbol VUZI) (entry_date 2026-05-29)
       (detail
        "entry bar 2026-05-29 open=4.5200 low=4.2200 close=4.6000 vs stop=4.1413, exit=4.0400"))
      ((symbol URBN) (entry_date 2025-12-22)
       (detail
        "entry bar 2025-12-22 open=80.4200 low=79.8700 close=80.1200 vs stop=77.8656, exit=77.8600"))
      ((symbol UMBF) (entry_date 2024-07-31)
       (detail
        "entry bar 2024-07-31 open=103.0000 low=100.7500 close=102.0200 vs stop=100.9806, exit=100.8300"))
      ((symbol UEC) (entry_date 2021-10-18)
       (detail
        "entry bar 2021-10-18 open=3.4600 low=3.4300 close=3.4900 vs stop=3.3780, exit=3.3500"))
      ((symbol UEC) (entry_date 2022-04-08)
       (detail
        "entry bar 2022-04-08 open=5.5500 low=5.3400 close=5.5000 vs stop=5.3721, exit=5.3600"))
      ((symbol TWLO) (entry_date 2026-04-22)
       (detail
        "entry bar 2026-04-22 open=152.1100 low=146.8600 close=150.4500 vs stop=146.3824, exit=146.3600"))
      ((symbol TGS) (entry_date 2026-03-24)
       (detail
        "entry bar 2026-03-24 open=32.9100 low=32.8500 close=33.9900 vs stop=33.1614, exit=33.1300"))
      ((symbol TGLS) (entry_date 2023-01-27)
       (detail
        "entry bar 2023-01-27 open=33.8000 low=33.4600 close=33.7600 vs stop=33.6642, exit=33.6300"))
      ((symbol SDA) (entry_date 2023-07-12)
       (detail
        "entry bar 2023-07-12 open=14.1500 low=11.5500 close=11.7000 vs stop=10.4919, exit=10.4400"))
      ((symbol ODFL) (entry_date 2023-02-02)
       (detail
        "entry bar 2023-02-02 open=373.2500 low=368.7600 close=371.4100 vs stop=360.4329, exit=360.4100")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 5)
    (n_skipped 0)
    (specimens
     (((symbol APLS) (entry_date 2021-06-16)
       (detail
        "median close 32.85 over 2155 bars (2017-11-09..2026-06-09); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0"))
      ((symbol BOKF) (entry_date 2021-10-20)
       (detail
        "median close 49.74 over 8752 bars (1991-09-05..2026-06-09); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0"))
      ((symbol DUOT) (entry_date 2026-06-08)
       (detail
        "median close 2.71 over 3134 bars (2008-08-13..2026-06-09); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0"))
      ((symbol IHG) (entry_date 2024-10-15)
       (detail
        "median close 37.39 over 5829 bars (2003-04-08..2026-06-09); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0"))
      ((symbol NOKBF) (entry_date 2025-10-28)
       (detail
        "median close 5.96 over 4468 bars (2001-07-11..2026-06-09); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0")))))))
 (audit_join ((matched 195) (total 195))))
