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
   ((id V7) (severity Invariant) (passed false) (n_violations 23)
    (n_skipped 0)
    (specimens
     (((symbol XERS) (entry_date 2024-02-14)
       (detail
        "Virgin_territory but only 297 weekly bars (< 520) before entry"))
      ((symbol VAL) (entry_date 2022-10-27)
       (detail
        "Virgin_territory but only 77 weekly bars (< 520) before entry"))
      ((symbol TWLO) (entry_date 2026-04-22)
       (detail
        "Virgin_territory but only 517 weekly bars (< 520) before entry"))
      ((symbol SHOP) (entry_date 2021-06-21)
       (detail
        "Virgin_territory but only 320 weekly bars (< 520) before entry"))
      ((symbol ROKU) (entry_date 2021-07-27)
       (detail
        "Virgin_territory but only 202 weekly bars (< 520) before entry"))
      ((symbol REAL) (entry_date 2025-10-03)
       (detail
        "Virgin_territory but only 329 weekly bars (< 520) before entry"))
      ((symbol NTRA) (entry_date 2021-09-23)
       (detail
        "Virgin_territory but only 327 weekly bars (< 520) before entry"))
      ((symbol NEXT) (entry_date 2025-01-16)
       (detail
        "Virgin_territory but only 469 weekly bars (< 520) before entry"))
      ((symbol MNDT) (entry_date 2022-03-07)
       (detail
        "Virgin_territory but only 446 weekly bars (< 520) before entry"))
      ((symbol LQDA) (entry_date 2023-06-02)
       (detail
        "Virgin_territory but only 255 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 52)
    (n_skipped 17)
    (specimens
     (((symbol ZGN) (entry_date 2023-09-08)
       (detail "prior_top=15.43 within +25% of entry=14.25"))
      ((symbol VRNS) (entry_date 2021-07-21)
       (detail "prior_top=71.50 within +25% of entry=60.93"))
      ((symbol URBN) (entry_date 2025-12-22)
       (detail "prior_top=81.84 within +25% of entry=81.11"))
      ((symbol RYAN) (entry_date 2024-04-04)
       (detail "prior_top=54.48 within +25% of entry=51.91"))
      ((symbol ROST) (entry_date 2023-11-14)
       (detail "prior_top=125.52 within +25% of entry=124.00"))
      ((symbol PTGX) (entry_date 2025-06-02)
       (detail "prior_top=54.78 within +25% of entry=49.15"))
      ((symbol PJT) (entry_date 2023-11-03)
       (detail "prior_top=84.12 within +25% of entry=83.60"))
      ((symbol PEN) (entry_date 2023-05-03)
       (detail "prior_top=305.99 within +25% of entry=294.35"))
      ((symbol OWL) (entry_date 2025-03-03)
       (detail "prior_top=23.98 within +25% of entry=20.63"))
      ((symbol ORCL) (entry_date 2024-08-05)
       (detail "prior_top=141.64 within +25% of entry=128.84")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 4)
    (n_skipped 17)
    (specimens
     (((symbol STMP) (entry_date 2021-07-30)
       (detail "entry_wk_close=326.76 > prior=199.19 (spike>60%)"))
      ((symbol OKLO) (entry_date 2024-11-04)
       (detail "entry_wk_close=24.47 > prior=9.15 (spike>60%)"))
      ((symbol GSIT) (entry_date 2025-10-20)
       (detail "entry_wk_close=9.23 > prior=3.84 (spike>60%)"))
      ((symbol GRPN) (entry_date 2025-03-26)
       (detail "entry_wk_close=18.82 > prior=11.12 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol VLN) (entry_date 2026-05-26)
       (detail
        "installed_stop=2.9136 vs fill=3.4300 -> dist=0.1506 > gate=0.1500"))
      ((symbol LZB) (entry_date 2024-07-15)
       (detail
        "installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500"))
      ((symbol LPG) (entry_date 2023-09-15)
       (detail
        "installed_stop=23.2022 vs fill=27.3000 -> dist=0.1501 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 5)
    (n_skipped 1)
    (specimens
     (((symbol HZNP) (entry_date 2023-10-09)
       (detail
        "no bar on exit_date 2023-10-10 (nearest earlier bar: 2023-10-09)"))
      ((symbol EC) (entry_date 2022-02-28)
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
     (((symbol URBN) (entry_date 2025-12-22)
       (detail
        "entry bar 2025-12-22 open=80.4200 low=79.8700 close=80.1200 vs stop=77.8656, exit=77.8600"))
      ((symbol UEC) (entry_date 2021-10-18)
       (detail
        "entry bar 2021-10-18 open=3.4600 low=3.4300 close=3.4900 vs stop=3.3780, exit=3.3500"))
      ((symbol UEC) (entry_date 2022-04-08)
       (detail
        "entry bar 2022-04-08 open=5.5500 low=5.3400 close=5.5000 vs stop=5.3721, exit=5.3600"))
      ((symbol TWLO) (entry_date 2026-04-22)
       (detail
        "entry bar 2026-04-22 open=152.1100 low=146.8600 close=150.4500 vs stop=146.3824, exit=146.3600"))
      ((symbol TGLS) (entry_date 2023-01-27)
       (detail
        "entry bar 2023-01-27 open=33.8000 low=33.4600 close=33.7600 vs stop=33.6642, exit=33.6300"))
      ((symbol REAL) (entry_date 2025-10-03)
       (detail
        "entry bar 2025-10-03 open=11.2500 low=10.8950 close=10.9900 vs stop=10.9744, exit=10.8500"))
      ((symbol QFIN) (entry_date 2024-04-11)
       (detail
        "entry bar 2024-04-11 open=20.2000 low=19.9400 close=20.0000 vs stop=19.6773, exit=19.2500"))
      ((symbol OWL) (entry_date 2025-03-03)
       (detail
        "entry bar 2025-03-03 open=21.6800 low=20.5900 close=20.8300 vs stop=19.4170, exit=19.4100"))
      ((symbol ODFL) (entry_date 2023-02-02)
       (detail
        "entry bar 2023-02-02 open=373.2500 low=368.7600 close=371.4100 vs stop=360.4329, exit=360.4100"))
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
   ((id V18) (severity Expectation) (passed false) (n_violations 7)
    (n_skipped 0)
    (specimens
     (((symbol ANIP) (entry_date 2024-04-01)
       (detail
        "median close 26.24 over 6159 bars (2001-07-24..2026-06-23); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0"))
      ((symbol APLS) (entry_date 2021-06-16)
       (detail
        "median close 32.72 over 2165 bars (2017-11-09..2026-06-23); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0"))
      ((symbol ATLKY) (entry_date 2026-01-15)
       (detail
        "median close 24.88 over 7445 bars (1996-11-18..2026-06-23); bar 2003-09-01 close 1000000.00 (+3311246.00% vs prior close 30.20) on volume 0"))
      ((symbol BOKF) (entry_date 2021-10-20)
       (detail
        "median close 49.76 over 8761 bars (1991-09-05..2026-06-23); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0"))
      ((symbol DUOT) (entry_date 2026-06-08)
       (detail
        "median close 2.72 over 3143 bars (2008-08-13..2026-06-23); bar 2009-03-11 close 0.50 (+100.00% vs prior close 0.25) on volume 0"))
      ((symbol IHG) (entry_date 2024-10-15)
       (detail
        "median close 37.44 over 5838 bars (2003-04-08..2026-06-23); bar 2003-04-10 close 5.80 (+5799900.00% vs prior close 0.00) on volume 0"))
      ((symbol NOKBF) (entry_date 2025-10-28)
       (detail
        "median close 5.97 over 4477 bars (2001-07-11..2026-06-23); bar 2001-12-07 close 25.00 (+322.22% vs prior close 5.92) on volume 0")))))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V21) (severity Expectation) (passed false) (n_violations 145)
    (n_skipped 0)
    (specimens
     (((symbol ZGN) (entry_date 2023-09-08)
       (detail
        "LONG installed_stop 13.4112 vs screener_proxy_stop 12.8524: 4.35% tighter > 3%"))
      ((symbol WSBC) (entry_date 2022-10-27)
       (detail
        "LONG installed_stop 38.4672 vs screener_proxy_stop 36.8644: 4.35% tighter > 3%"))
      ((symbol VRSK) (entry_date 2023-06-05)
       (detail
        "LONG installed_stop 214.2912 vs screener_proxy_stop 205.3624: 4.35% tighter > 3%"))
      ((symbol VRNS) (entry_date 2021-07-21)
       (detail
        "LONG installed_stop 58.4640 vs screener_proxy_stop 56.0280: 4.35% tighter > 3%"))
      ((symbol VAL) (entry_date 2022-10-27)
       (detail
        "LONG installed_stop 61.2192 vs screener_proxy_stop 58.6684: 4.35% tighter > 3%"))
      ((symbol UUUU) (entry_date 2025-08-26)
       (detail
        "LONG installed_stop 10.9920 vs screener_proxy_stop 10.5340: 4.35% tighter > 3%"))
      ((symbol URBN) (entry_date 2025-12-22)
       (detail
        "LONG installed_stop 77.8656 vs screener_proxy_stop 74.6212: 4.35% tighter > 3%"))
      ((symbol TWLO) (entry_date 2026-04-22)
       (detail
        "LONG installed_stop 146.3750 vs screener_proxy_stop 140.4932: 4.19% tighter > 3%"))
      ((symbol TIPT) (entry_date 2025-09-25)
       (detail
        "LONG installed_stop 25.9488 vs screener_proxy_stop 24.8676: 4.35% tighter > 3%"))
      ((symbol TGLS) (entry_date 2023-01-27)
       (detail
        "LONG installed_stop 33.6672 vs screener_proxy_stop 32.2644: 4.35% tighter > 3%")))))
   ((id V23) (severity Expectation) (passed false) (n_violations 9)
    (n_skipped 0)
    (specimens
     (((symbol WSBC) (entry_date 2022-10-27)
       (detail "filled 2022-10-27 after the 2022-10-21 screen read Bearish"))
      ((symbol VAL) (entry_date 2022-10-27)
       (detail "filled 2022-10-27 after the 2022-10-21 screen read Bearish"))
      ((symbol MZTI) (entry_date 2022-10-26)
       (detail "filled 2022-10-26 after the 2022-10-21 screen read Bearish"))
      ((symbol HLN) (entry_date 2025-05-02)
       (detail "filled 2025-05-02 after the 2025-04-25 screen read Bearish"))
      ((symbol FSS) (entry_date 2022-11-10)
       (detail "filled 2022-11-10 after the 2022-11-04 screen read Bearish"))
      ((symbol FN) (entry_date 2022-11-11)
       (detail "filled 2022-11-11 after the 2022-11-04 screen read Bearish"))
      ((symbol EC) (entry_date 2022-02-28)
       (detail "filled 2022-02-28 after the 2022-02-25 screen read Bearish"))
      ((symbol BMI) (entry_date 2022-10-26)
       (detail "filled 2022-10-26 after the 2022-10-21 screen read Bearish"))
      ((symbol BBSI) (entry_date 2022-10-31)
       (detail "filled 2022-10-31 after the 2022-10-28 screen read Bearish")))))))
 (audit_join ((matched 196) (total 196))))
