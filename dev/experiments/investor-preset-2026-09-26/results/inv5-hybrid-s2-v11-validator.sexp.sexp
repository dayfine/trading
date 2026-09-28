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
   ((id V7) (severity Invariant) (passed false) (n_violations 24)
    (n_skipped 0)
    (specimens
     (((symbol VAL) (entry_date 2022-10-27)
       (detail
        "Virgin_territory but only 77 weekly bars (< 520) before entry"))
      ((symbol TRMD) (entry_date 2024-01-24)
       (detail
        "Virgin_territory but only 311 weekly bars (< 520) before entry"))
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
      ((symbol MNDT) (entry_date 2022-03-07)
       (detail
        "Virgin_territory but only 446 weekly bars (< 520) before entry"))
      ((symbol LQDA) (entry_date 2023-06-02)
       (detail
        "Virgin_territory but only 255 weekly bars (< 520) before entry"))
      ((symbol LBRT) (entry_date 2023-10-18)
       (detail
        "Virgin_territory but only 303 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 47)
    (n_skipped 16)
    (specimens
     (((symbol VRNS) (entry_date 2021-07-21)
       (detail "prior_top=71.50 within +25% of entry=60.99"))
      ((symbol URBN) (entry_date 2025-03-13)
       (detail "prior_top=58.19 within +25% of entry=50.12"))
      ((symbol URBN) (entry_date 2025-12-22)
       (detail "prior_top=81.84 within +25% of entry=81.28"))
      ((symbol UMAC) (entry_date 2026-01-15)
       (detail "prior_top=18.73 within +25% of entry=17.82"))
      ((symbol STVN) (entry_date 2023-03-02)
       (detail "prior_top=28.27 within +25% of entry=23.47"))
      ((symbol RYAN) (entry_date 2024-04-04)
       (detail "prior_top=54.48 within +25% of entry=51.91"))
      ((symbol ROST) (entry_date 2023-11-14)
       (detail "prior_top=125.52 within +25% of entry=124.00"))
      ((symbol PTGX) (entry_date 2025-06-02)
       (detail "prior_top=54.78 within +25% of entry=49.17"))
      ((symbol PJT) (entry_date 2023-11-03)
       (detail "prior_top=84.12 within +25% of entry=83.64"))
      ((symbol PEN) (entry_date 2023-05-03)
       (detail "prior_top=305.99 within +25% of entry=294.56")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 8)
    (n_skipped 16)
    (specimens
     (((symbol VTNRQ) (entry_date 2022-05-16)
       (detail "entry_wk_close=14.40 > prior=8.84 (spike>60%)"))
      ((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol OKLO) (entry_date 2024-11-04)
       (detail "entry_wk_close=24.47 > prior=9.15 (spike>60%)"))
      ((symbol ISEE) (entry_date 2022-09-30)
       (detail "entry_wk_close=17.94 > prior=9.44 (spike>60%)"))
      ((symbol GSIT) (entry_date 2025-10-20)
       (detail "entry_wk_close=9.23 > prior=3.84 (spike>60%)"))
      ((symbol GRPN) (entry_date 2025-03-26)
       (detail "entry_wk_close=18.82 > prior=11.12 (spike>60%)"))
      ((symbol CUTRQ) (entry_date 2022-03-28)
       (detail "entry_wk_close=72.31 > prior=40.49 (spike>60%)"))
      ((symbol BTDR) (entry_date 2024-11-29)
       (detail "entry_wk_close=14.27 > prior=7.83 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol SOUN) (entry_date 2024-04-02)
       (detail
        "installed_stop=4.3750 vs fill=5.2400 -> dist=0.1651 > gate=0.1500"))
      ((symbol LZB) (entry_date 2024-07-15)
       (detail
        "installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500"))
      ((symbol DAR) (entry_date 2022-04-20)
       (detail
        "installed_stop=73.4880 vs fill=86.4900 -> dist=0.1503 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 5)
    (n_skipped 1)
    (specimens
     (((symbol KD) (entry_date 2023-09-11)
       (detail
        "entry_price=17.3200 outside 2023-09-11 bar [16.7000, 17.3190]"))
      ((symbol HZNP) (entry_date 2023-10-09)
       (detail
        "no bar on exit_date 2023-10-10 (nearest earlier bar: 2023-10-09)"))
      ((symbol GERN) (entry_date 2024-04-11)
       (detail "entry_price=3.7900 outside 2024-04-11 bar [3.4400, 3.7860]"))
      ((symbol CRCT) (entry_date 2025-07-02)
       (detail "entry_price=6.3600 outside 2025-07-02 bar [6.9100, 7.2150]"))
      ((symbol AAGIY) (entry_date 2023-01-04)
       (detail
        "entry_price=46.7300 outside 2023-01-04 bar [46.7310, 46.7310]")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 21)
    (n_skipped 0)
    (specimens
     (((symbol URBN) (entry_date 2025-12-22)
       (detail
        "entry bar 2025-12-22 open=80.4200 low=79.8700 close=80.1200 vs stop=77.8662, exit=77.7900"))
      ((symbol UMBF) (entry_date 2024-07-31)
       (detail
        "entry bar 2024-07-31 open=103.0000 low=100.7500 close=102.0200 vs stop=100.9815, exit=100.5300"))
      ((symbol UEC) (entry_date 2021-10-18)
       (detail
        "entry bar 2021-10-18 open=3.4600 low=3.4300 close=3.4900 vs stop=3.3749, exit=3.3300"))
      ((symbol TRMD) (entry_date 2024-01-24)
       (detail
        "entry bar 2024-01-24 open=36.5500 low=35.8800 close=35.9700 vs stop=35.3118, exit=35.2700"))
      ((symbol TGLS) (entry_date 2023-01-27)
       (detail
        "entry bar 2023-01-27 open=33.8000 low=33.4600 close=33.7600 vs stop=33.6658, exit=33.5400"))
      ((symbol QFIN) (entry_date 2024-04-11)
       (detail
        "entry bar 2024-04-11 open=20.2000 low=19.9400 close=20.0000 vs stop=19.6766, exit=19.2500"))
      ((symbol NTRA) (entry_date 2021-09-23)
       (detail
        "entry bar 2021-09-23 open=125.6700 low=122.0250 close=123.5400 vs stop=122.7232, exit=121.9000"))
      ((symbol NET) (entry_date 2024-12-17)
       (detail
        "entry bar 2024-12-17 open=118.2300 low=116.0101 close=117.5600 vs stop=111.9165, exit=111.8900"))
      ((symbol MNDT) (entry_date 2022-03-07)
       (detail
        "entry bar 2022-03-07 open=19.3800 low=18.5450 close=22.4900 vs stop=21.9988, exit=21.7300"))
      ((symbol INOD) (entry_date 2024-06-06)
       (detail
        "entry bar 2024-06-06 open=14.9100 low=14.7634 close=15.1600 vs stop=14.8247, exit=14.7700")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 8)
    (n_skipped 0)
    (specimens
     (((symbol APLS) (entry_date 2021-06-16)
       (detail
        "median close 32.72 over 2165 bars (2017-11-09..2026-06-23); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0"))
      ((symbol ATLKY) (entry_date 2026-01-15)
       (detail
        "median close 24.88 over 7445 bars (1996-11-18..2026-06-23); bar 2003-09-01 close 1000000.00 (+3311246.00% vs prior close 30.20) on volume 0"))
      ((symbol BOKF) (entry_date 2021-10-20)
       (detail
        "median close 49.76 over 8761 bars (1991-09-05..2026-06-23); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0"))
      ((symbol CECO) (entry_date 2024-12-09)
       (detail
        "median close 4.62 over 11481 bars (1980-12-02..2026-06-23); bar 1992-09-29 close 2.66 (+399.96% vs prior close 0.53) on volume 0"))
      ((symbol DUOT) (entry_date 2026-06-08)
       (detail
        "median close 2.72 over 3143 bars (2008-08-13..2026-06-23); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0"))
      ((symbol IHG) (entry_date 2024-10-15)
       (detail
        "median close 37.44 over 5838 bars (2003-04-08..2026-06-23); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0"))
      ((symbol NOKBF) (entry_date 2025-10-28)
       (detail
        "median close 5.97 over 4477 bars (2001-07-11..2026-06-23); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0"))
      ((symbol VTNRQ) (entry_date 2022-05-16)
       (detail
        "median close 1.36 over 7522 bars (1992-10-21..2025-01-21); bar 2003-11-11 close 0.00 (-90.00% vs prior close 0.02) on volume 0")))))))
 (audit_join ((matched 199) (total 199))))
