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
   ((id V7) (severity Invariant) (passed false) (n_violations 31)
    (n_skipped 0)
    (specimens
     (((symbol XPOF) (entry_date 2023-01-27)
       (detail
        "Virgin_territory but only 79 weekly bars (< 520) before entry"))
      ((symbol XERS) (entry_date 2024-02-14)
       (detail
        "Virgin_territory but only 297 weekly bars (< 520) before entry"))
      ((symbol VAL) (entry_date 2022-10-27)
       (detail
        "Virgin_territory but only 77 weekly bars (< 520) before entry"))
      ((symbol TWLO) (entry_date 2026-04-22)
       (detail
        "Virgin_territory but only 517 weekly bars (< 520) before entry"))
      ((symbol SYRE) (entry_date 2026-02-20)
       (detail
        "Virgin_territory but only 519 weekly bars (< 520) before entry"))
      ((symbol SNOW) (entry_date 2025-08-28)
       (detail
        "Virgin_territory but only 259 weekly bars (< 520) before entry"))
      ((symbol SHOP) (entry_date 2021-06-21)
       (detail
        "Virgin_territory but only 320 weekly bars (< 520) before entry"))
      ((symbol ROKU) (entry_date 2021-07-27)
       (detail
        "Virgin_territory but only 202 weekly bars (< 520) before entry"))
      ((symbol REAL) (entry_date 2025-10-03)
       (detail
        "Virgin_territory but only 329 weekly bars (< 520) before entry"))
      ((symbol NXE) (entry_date 2022-04-13)
       (detail
        "Virgin_territory but only 456 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 43)
    (n_skipped 18)
    (specimens
     (((symbol ZGN) (entry_date 2023-09-08)
       (detail "prior_top=15.43 within +25% of entry=14.25"))
      ((symbol X) (entry_date 2023-09-19)
       (detail "prior_top=37.63 within +25% of entry=31.75"))
      ((symbol VRNS) (entry_date 2021-07-21)
       (detail "prior_top=71.50 within +25% of entry=60.93"))
      ((symbol URBN) (entry_date 2025-12-22)
       (detail "prior_top=81.84 within +25% of entry=81.11"))
      ((symbol SAND) (entry_date 2025-06-02)
       (detail "prior_top=9.56 within +25% of entry=9.14"))
      ((symbol PTGX) (entry_date 2025-06-02)
       (detail "prior_top=54.78 within +25% of entry=49.15"))
      ((symbol PJT) (entry_date 2023-11-03)
       (detail "prior_top=84.12 within +25% of entry=83.60"))
      ((symbol ON) (entry_date 2021-08-27)
       (detail "prior_top=45.28 within +25% of entry=44.85"))
      ((symbol NATL) (entry_date 2025-08-11)
       (detail "prior_top=37.11 within +25% of entry=36.39"))
      ((symbol MZTI) (entry_date 2022-10-26)
       (detail "prior_top=179.92 within +25% of entry=178.21")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 5)
    (n_skipped 18)
    (specimens
     (((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol GSIT) (entry_date 2025-10-20)
       (detail "entry_wk_close=9.23 > prior=3.84 (spike>60%)"))
      ((symbol GRPN) (entry_date 2025-03-26)
       (detail "entry_wk_close=18.82 > prior=11.12 (spike>60%)"))
      ((symbol EOSE) (entry_date 2023-06-28)
       (detail "entry_wk_close=4.34 > prior=2.43 (spike>60%)"))
      ((symbol BTDR) (entry_date 2024-11-29)
       (detail "entry_wk_close=14.27 > prior=7.83 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 4)
    (n_skipped 0)
    (specimens
     (((symbol YMM) (entry_date 2024-11-20)
       (detail
        "installed_stop=8.2848 vs fill=9.7700 -> dist=0.1520 > gate=0.1500"))
      ((symbol VLN) (entry_date 2026-05-26)
       (detail
        "installed_stop=2.9136 vs fill=3.4300 -> dist=0.1506 > gate=0.1500"))
      ((symbol SOUN) (entry_date 2024-04-02)
       (detail
        "installed_stop=4.3750 vs fill=5.2400 -> dist=0.1651 > gate=0.1500"))
      ((symbol LZB) (entry_date 2024-07-15)
       (detail
        "installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 7)
    (n_skipped 1)
    (specimens
     (((symbol NTTYY) (entry_date 2024-01-16)
       (detail
        "entry_price=31.7800 outside 2024-01-16 bar [31.7820, 31.7820]"))
      ((symbol HZNP) (entry_date 2023-10-09)
       (detail
        "no bar on exit_date 2023-10-10 (nearest earlier bar: 2023-10-09)"))
      ((symbol EC) (entry_date 2022-02-28)
       (detail
        "entry_price=14.7700 outside 2022-02-28 bar [15.4800, 16.1900]"))
      ((symbol CRCT) (entry_date 2025-07-02)
       (detail "entry_price=6.3700 outside 2025-07-02 bar [6.9100, 7.2150]"))
      ((symbol CHS) (entry_date 2023-10-23)
       (detail
        "no bar on exit_date 2024-01-05 (nearest earlier bar: 2024-01-04)"))
      ((symbol AZPN) (entry_date 2025-01-30)
       (detail
        "no bar on exit_date 2025-03-13 (nearest earlier bar: 2025-03-12)"))
      ((symbol AAGIY) (entry_date 2023-01-04)
       (detail
        "entry_price=46.7300 outside 2023-01-04 bar [46.7310, 46.7310]")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 24)
    (n_skipped 0)
    (specimens
     (((symbol UTL) (entry_date 2022-07-01)
       (detail
        "entry bar 2022-07-01 open=58.7100 low=58.0800 close=61.0000 vs stop=57.2322, exit=57.1400"))
      ((symbol URBN) (entry_date 2025-12-22)
       (detail
        "entry bar 2025-12-22 open=80.4200 low=79.8700 close=80.1200 vs stop=77.8656, exit=77.8600"))
      ((symbol UMBF) (entry_date 2024-07-31)
       (detail
        "entry bar 2024-07-31 open=103.0000 low=100.7500 close=102.0200 vs stop=100.9806, exit=100.8300"))
      ((symbol UEC) (entry_date 2021-10-18)
       (detail
        "entry bar 2021-10-18 open=3.4600 low=3.4300 close=3.4900 vs stop=3.3780, exit=3.3500"))
      ((symbol TWLO) (entry_date 2026-04-22)
       (detail
        "entry bar 2026-04-22 open=152.1100 low=146.8600 close=150.4500 vs stop=146.3824, exit=146.3600"))
      ((symbol TGLS) (entry_date 2023-01-27)
       (detail
        "entry bar 2023-01-27 open=33.8000 low=33.4600 close=33.7600 vs stop=33.6642, exit=33.6300"))
      ((symbol REAL) (entry_date 2025-10-03)
       (detail
        "entry bar 2025-10-03 open=11.2500 low=10.8950 close=10.9900 vs stop=10.9744, exit=10.8500"))
      ((symbol ODFL) (entry_date 2023-02-02)
       (detail
        "entry bar 2023-02-02 open=373.2500 low=368.7600 close=371.4100 vs stop=360.4329, exit=360.4100"))
      ((symbol NXE) (entry_date 2022-04-13)
       (detail
        "entry bar 2022-04-13 open=6.3000 low=6.2820 close=6.3300 vs stop=6.2666, exit=6.2200"))
      ((symbol NTRA) (entry_date 2021-09-23)
       (detail
        "entry bar 2021-09-23 open=125.6700 low=122.0250 close=123.5400 vs stop=122.7168, exit=121.9000")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 0)
    (specimens
     (((symbol TIPT) (entry_date 2025-09-25)
       (detail
        "force_liquidation exit 2025-09-26 (entry 2025-09-25 @ 27.11, exit @ 20.00)")))))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 4)
    (n_skipped 0)
    (specimens
     (((symbol ANIP) (entry_date 2024-03-04)
       (detail
        "median close 25.92 over 6149 bars (2001-07-24..2026-06-08); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0"))
      ((symbol APLS) (entry_date 2021-06-16)
       (detail
        "median close 32.88 over 2154 bars (2017-11-09..2026-06-08); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0"))
      ((symbol BOKF) (entry_date 2021-10-20)
       (detail
        "median close 49.73 over 8751 bars (1991-09-05..2026-06-08); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0"))
      ((symbol NOKBF) (entry_date 2025-10-28)
       (detail
        "median close 5.96 over 4467 bars (2001-07-11..2026-06-08); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0")))))))
 (audit_join ((matched 206) (total 206))))
