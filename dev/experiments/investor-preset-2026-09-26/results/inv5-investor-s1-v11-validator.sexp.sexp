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
     (((symbol GOOG) (entry_date 2025-01-03)
       (detail "twin positions: GOOG/GOOGL")))))
   ((id V7) (severity Invariant) (passed false) (n_violations 1)
    (n_skipped 0)
    (specimens
     (((symbol XERS) (entry_date 2024-02-14)
       (detail
        "Virgin_territory but only 297 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 31)
    (n_skipped 12)
    (specimens
     (((symbol X) (entry_date 2023-09-19)
       (detail "prior_top=37.63 within +25% of entry=31.74"))
      ((symbol WOLF_old2) (entry_date 2021-11-22)
       (detail "prior_top=139.55 within +25% of entry=133.00"))
      ((symbol URBN) (entry_date 2026-01-06)
       (detail "prior_top=81.84 within +25% of entry=81.19"))
      ((symbol UA) (entry_date 2021-11-22)
       (detail "prior_top=27.04 within +25% of entry=22.69"))
      ((symbol PTGX) (entry_date 2025-06-02)
       (detail "prior_top=54.78 within +25% of entry=49.19"))
      ((symbol PJT) (entry_date 2023-11-03)
       (detail "prior_top=84.12 within +25% of entry=83.64"))
      ((symbol ON) (entry_date 2021-08-27)
       (detail "prior_top=45.28 within +25% of entry=44.99"))
      ((symbol MSEX) (entry_date 2022-04-27)
       (detail "prior_top=109.11 within +25% of entry=89.30"))
      ((symbol MMYT) (entry_date 2023-10-26)
       (detail "prior_top=40.52 within +25% of entry=37.63"))
      ((symbol MEOH) (entry_date 2024-04-25)
       (detail "prior_top=52.47 within +25% of entry=49.91")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 12)
    (specimens
     (((symbol ISEE) (entry_date 2022-09-30)
       (detail "entry_wk_close=17.94 > prior=9.44 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 4)
    (n_skipped 0)
    (specimens
     (((symbol XERS) (entry_date 2024-02-14)
       (detail
        "installed_stop=2.6496 vs fill=3.1500 -> dist=0.1589 > gate=0.1500"))
      ((symbol VLN) (entry_date 2026-05-26)
       (detail
        "installed_stop=2.9136 vs fill=3.4300 -> dist=0.1506 > gate=0.1500"))
      ((symbol EVCM) (entry_date 2026-01-07)
       (detail
        "installed_stop=10.4448 vs fill=12.3100 -> dist=0.1515 > gate=0.1500"))
      ((symbol CTO) (entry_date 2021-12-22)
       (detail
        "installed_stop=50.3750 vs fill=19.4900 -> dist=1.5847 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 1) (specimens ()))
   ((id V14) (severity Expectation) (passed false) (n_violations 9)
    (n_skipped 0)
    (specimens
     (((symbol UPWK) (entry_date 2025-09-30)
       (detail
        "entry bar 2025-09-30 open=18.9800 low=18.2150 close=18.5700 vs stop=17.8706, exit=17.8000"))
      ((symbol TDS) (entry_date 2023-09-11)
       (detail
        "entry bar 2023-09-11 open=17.8500 low=17.3700 close=17.6500 vs stop=17.1658, exit=17.1400"))
      ((symbol SDA) (entry_date 2023-07-12)
       (detail
        "entry bar 2023-07-12 open=14.1500 low=11.5500 close=11.7000 vs stop=10.4919, exit=10.4900"))
      ((symbol RCAT) (entry_date 2026-03-06)
       (detail
        "entry bar 2026-03-06 open=14.6100 low=14.6100 close=15.3600 vs stop=14.8790, exit=14.8600"))
      ((symbol EXTR) (entry_date 2022-01-21)
       (detail
        "entry bar 2022-01-21 open=12.8100 low=12.4900 close=12.4900 vs stop=12.1943, exit=12.1700"))
      ((symbol DUOT) (entry_date 2026-06-08)
       (detail
        "entry bar 2026-06-08 open=12.3100 low=11.7500 close=12.2300 vs stop=10.9781, exit=10.7600"))
      ((symbol CVNA) (entry_date 2025-12-31)
       (detail
        "entry bar 2025-12-31 open=429.5500 low=421.8550 close=422.0200 vs stop=406.8887, exit=406.8700"))
      ((symbol APPF) (entry_date 2025-08-11)
       (detail
        "entry bar 2025-08-11 open=281.9800 low=279.6310 close=280.8800 vs stop=271.4265, exit=271.4300"))
      ((symbol AAOI) (entry_date 2026-01-02)
       (detail
        "entry bar 2026-01-02 open=36.3450 low=35.7600 close=39.6000 vs stop=35.3762, exit=35.2400")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol ANIP) (entry_date 2024-03-11)
       (detail
        "median close 25.95 over 6150 bars (2001-07-24..2026-06-09); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0"))
      ((symbol DUOT) (entry_date 2026-06-08)
       (detail
        "median close 2.71 over 3134 bars (2008-08-13..2026-06-09); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0"))
      ((symbol RCAT) (entry_date 2026-03-06)
       (detail
        "median close 0.02 over 7327 bars (1995-11-27..2026-06-09); bar 1996-04-10 close 5.00 (+7900.32% vs prior close 0.06) on volume 0")))))))
 (audit_join ((matched 125) (total 125))))
