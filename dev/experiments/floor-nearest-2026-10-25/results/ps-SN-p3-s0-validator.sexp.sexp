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
    (specimens ())
    (skip_reason
     "share-class map: /workspaces/trading-1/.claude/worktrees/sweep-ps/trading/test_data/share_classes.sexp"))
   ((id V7) (severity Invariant) (passed false) (n_violations 7)
    (n_skipped 0)
    (specimens
     (((symbol XERS) (entry_date 2024-02-14)
       (detail
        "Virgin_territory but only 295 weekly bars (< 520) before entry"))
      ((symbol PCOR) (entry_date 2023-07-11)
       (detail
        "Virgin_territory but only 112 weekly bars (< 520) before entry"))
      ((symbol NVEE) (entry_date 2022-08-17)
       (detail
        "Virgin_territory but only 460 weekly bars (< 520) before entry"))
      ((symbol KD) (entry_date 2023-09-11)
       (detail
        "Virgin_territory but only 99 weekly bars (< 520) before entry"))
      ((symbol FN) (entry_date 2019-12-12)
       (detail
        "Virgin_territory but only 494 weekly bars (< 520) before entry"))
      ((symbol ELF) (entry_date 2021-09-07)
       (detail
        "Virgin_territory but only 259 weekly bars (< 520) before entry"))
      ((symbol BLD) (entry_date 2021-10-22)
       (detail
        "Virgin_territory but only 331 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 50)
    (n_skipped 28)
    (specimens
     (((symbol XLRN) (entry_date 2020-04-20)
       (detail "prior_top=97.78 within +25% of entry=97.02"))
      ((symbol WIX) (entry_date 2021-04-28)
       (detail "prior_top=353.09 within +25% of entry=321.01"))
      ((symbol VRNS) (entry_date 2021-08-02)
       (detail "prior_top=71.50 within +25% of entry=61.38"))
      ((symbol UAA) (entry_date 2021-11-22)
       (detail "prior_top=32.99 within +25% of entry=27.05"))
      ((symbol TRUP) (entry_date 2021-11-15)
       (detail "prior_top=129.99 within +25% of entry=129.70"))
      ((symbol TRNO) (entry_date 2022-01-24)
       (detail "prior_top=74.58 within +25% of entry=71.38"))
      ((symbol THO) (entry_date 2021-02-16)
       (detail "prior_top=130.65 within +25% of entry=123.20"))
      ((symbol SSTK) (entry_date 2020-09-04)
       (detail "prior_top=49.52 within +25% of entry=47.13"))
      ((symbol SPB) (entry_date 2021-10-04)
       (detail "prior_top=98.59 within +25% of entry=97.90"))
      ((symbol SIMO) (entry_date 2022-01-24)
       (detail "prior_top=86.24 within +25% of entry=83.93")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 28)
    (specimens
     (((symbol ISEE) (entry_date 2022-09-30)
       (detail "entry_wk_close=17.94 > prior=9.44 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 29)
    (n_skipped 0)
    (specimens
     (((symbol VIRT) (entry_date 2021-03-18)
       (detail
        "installed_stop=24.8750 vs fill=29.3000 -> dist=0.1510 > gate=0.1500"))
      ((symbol TXNM) (entry_date 2020-02-03)
       (detail
        "installed_stop=45.3408 vs fill=54.3000 -> dist=0.1650 > gate=0.1500"))
      ((symbol TTEK) (entry_date 2024-02-13)
       (detail
        "installed_stop=148.4256 vs fill=175.7000 -> dist=0.1552 > gate=0.1500"))
      ((symbol TTE) (entry_date 2024-05-02)
       (detail
        "installed_stop=59.8750 vs fill=71.3000 -> dist=0.1602 > gate=0.1500"))
      ((symbol TRNO) (entry_date 2022-01-24)
       (detail
        "installed_stop=59.8750 vs fill=71.3800 -> dist=0.1612 > gate=0.1500"))
      ((symbol SSD) (entry_date 2021-03-08)
       (detail
        "installed_stop=89.1456 vs fill=104.9500 -> dist=0.1506 > gate=0.1500"))
      ((symbol RBA) (entry_date 2024-05-06)
       (detail
        "installed_stop=58.4064 vs fill=69.9600 -> dist=0.1651 > gate=0.1500"))
      ((symbol QLYS) (entry_date 2021-01-20)
       (detail
        "installed_stop=106.9728 vs fill=125.8900 -> dist=0.1503 > gate=0.1500"))
      ((symbol NVR) (entry_date 2022-01-07)
       (detail
        "installed_stop=4559.8750 vs fill=5465.9100 -> dist=0.1658 > gate=0.1500"))
      ((symbol NVEE) (entry_date 2022-08-17)
       (detail
        "installed_stop=120.8750 vs fill=142.2700 -> dist=0.1504 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 4)
    (n_skipped 1)
    (specimens
     (((symbol MIME) (entry_date 2021-06-25)
       (detail
        "no bar on exit_date 2022-05-20 (nearest earlier bar: 2022-05-19)"))
      ((symbol LACO) (entry_date 2020-05-27)
       (detail
        "no bar on exit_date 2020-10-09 (nearest earlier bar: 2020-10-08)"))
      ((symbol KD) (entry_date 2023-09-11)
       (detail
        "entry_price=17.3200 outside 2023-09-11 bar [16.7000, 17.3190]"))
      ((symbol AXIA) (entry_date 2021-05-24)
       (detail "entry_price=9.9600 outside 2021-05-24 bar [9.9638, 10.1532]")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 5)
    (n_skipped 0)
    (specimens
     (((symbol VCYT) (entry_date 2020-07-27)
       (detail
        "entry bar 2020-07-27 open=30.3700 low=29.3700 close=30.2400 vs stop=28.6744, exit=28.6200"))
      ((symbol TDS) (entry_date 2023-09-11)
       (detail
        "entry bar 2023-09-11 open=17.8500 low=17.3700 close=17.6500 vs stop=17.1658, exit=17.0600"))
      ((symbol FLNA) (entry_date 2020-10-12)
       (detail
        "entry bar 2020-10-12 open=11.8900 low=11.0700 close=11.4300 vs stop=10.8755, exit=10.8100"))
      ((symbol EXTR) (entry_date 2022-01-21)
       (detail
        "entry bar 2022-01-21 open=12.8100 low=12.4900 close=12.4900 vs stop=12.1943, exit=12.0900"))
      ((symbol CBU) (entry_date 2021-09-09)
       (detail
        "entry bar 2021-09-09 open=69.7900 low=69.1100 close=69.1600 vs stop=61.6666, exit=68.3300")))))
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
        "median close 8.15 over 5784 bars (2001-07-24..2024-12-19); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0"))
      ((symbol FIT) (entry_date 2019-11-26)
       (detail
        "median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0"))
      ((symbol FLO) (entry_date 2021-06-03)
       (detail
        "median close 18.60 over 11286 bars (1980-03-17..2024-12-19); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0")))))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V21) (severity Expectation) (passed false) (n_violations 21)
    (n_skipped 0)
    (specimens
     (((symbol TDS) (entry_date 2023-09-11)
       (detail
        "LONG installed_stop 17.1648 vs screener_proxy_stop 16.0264: 7.10% tighter > 3%"))
      ((symbol SSTK) (entry_date 2020-09-04)
       (detail
        "LONG installed_stop 44.4864 vs screener_proxy_stop 42.5132: 4.64% tighter > 3%"))
      ((symbol SIMO) (entry_date 2022-01-24)
       (detail
        "LONG installed_stop 79.4880 vs screener_proxy_stop 75.6976: 5.01% tighter > 3%"))
      ((symbol QCOM) (entry_date 2022-01-20)
       (detail
        "LONG installed_stop 164.3616 vs screener_proxy_stop 155.2776: 5.85% tighter > 3%"))
      ((symbol PKG) (entry_date 2023-08-21)
       (detail
        "LONG installed_stop 139.8912 vs screener_proxy_stop 135.2124: 3.46% tighter > 3%"))
      ((symbol NSP) (entry_date 2019-03-05)
       (detail
        "LONG installed_stop 116.8704 vs screener_proxy_stop 112.0192: 4.33% tighter > 3%"))
      ((symbol MRVL) (entry_date 2023-06-21)
       (detail
        "LONG installed_stop 55.8750 vs screener_proxy_stop 54.0224: 3.43% tighter > 3%"))
      ((symbol MIME) (entry_date 2019-02-26)
       (detail
        "LONG installed_stop 45.1296 vs screener_proxy_stop 43.3320: 4.15% tighter > 3%"))
      ((symbol HPQ) (entry_date 2024-06-27)
       (detail
        "LONG installed_stop 33.4464 vs screener_proxy_stop 31.3444: 6.71% tighter > 3%"))
      ((symbol GME) (entry_date 2020-09-10)
       (detail
        "LONG installed_stop 6.8832 vs screener_proxy_stop 6.3940: 7.65% tighter > 3%")))))
   ((id V22) (severity Expectation) (passed false) (n_violations 19)
    (n_skipped 35)
    (specimens
     (((symbol ADNT) (entry_date 2020-02-21)
       (detail
        "no stop move for 31 weeks (2020-11-09..2021-06-18), 1 completed cycle(s) stalled; last: stop 25.38, candidate 20.66, ma 20.86, correction extreme 26.23 (extreme/ma 1.26)"))
      ((symbol AN) (entry_date 2020-07-31)
       (detail
        "no stop move for 16 weeks (2020-08-04..2020-11-24), 2 completed cycle(s) stalled; last: stop 48.84, candidate 48.78, ma 49.27, correction extreme 50.52 (extreme/ma 1.03)"))
      ((symbol ANET) (entry_date 2023-03-10)
       (detail
        "no stop move for 13 weeks (2023-03-13..2023-06-16), 1 completed cycle(s) stalled; last: stop 127.22, candidate 35.88, ma 36.48, correction extreme 131.68 (extreme/ma 3.61)"))
      ((symbol BBWI) (entry_date 2020-07-31)
       (detail
        "no stop move for 31 weeks (2020-08-05..2021-03-12), 7 completed cycle(s) stalled; last: stop 22.92, candidate 20.38, ma 20.76, correction extreme 36.10 (extreme/ma 1.74)"))
      ((symbol CHDN) (entry_date 2019-05-17)
       (detail
        "no stop move for 23 weeks (2019-06-03..2019-11-15), 1 completed cycle(s) stalled; last: stop 90.13, candidate 56.31, ma 56.88, correction extreme 113.88 (extreme/ma 2.00)"))
      ((symbol CLX) (entry_date 2020-03-13)
       (detail
        "no stop move for 16 weeks (2020-03-16..2020-07-10), 1 completed cycle(s) stalled; last: stop 150.41, candidate 137.88, ma 139.40, correction extreme 161.11 (extreme/ma 1.16)"))
      ((symbol DXCM) (entry_date 2019-07-05)
       (detail
        "no stop move for 55 weeks (2019-07-22..2020-08-14), 8 completed cycle(s) stalled; last: stop 133.66, candidate 92.38, ma 93.31, correction extreme 381.12 (extreme/ma 4.08)"))
      ((symbol GILD) (entry_date 2020-02-28)
       (detail
        "no stop move for 14 weeks (2020-03-02..2020-06-12), 2 completed cycle(s) stalled; last: stop 63.96, candidate 55.88, ma 56.61, correction extreme 74.40 (extreme/ma 1.31)"))
      ((symbol JBSS) (entry_date 2019-05-24)
       (detail
        "no stop move for 26 weeks (2019-06-07..2019-12-06), 2 completed cycle(s) stalled; last: stop 72.80, candidate 62.64, ma 63.27, correction extreme 77.50 (extreme/ma 1.22)"))
      ((symbol MCY) (entry_date 2021-01-08)
       (detail
        "no stop move for 19 weeks (2021-01-20..2021-06-04), 2 completed cycle(s) stalled; last: stop 47.88, candidate 46.38, ma 47.08, correction extreme 59.09 (extreme/ma 1.26)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol SLB) (entry_date 2022-02-24)
       (detail "filled 2022-02-24 after the 2022-02-18 screen read Bearish"))
      ((symbol ISEE) (entry_date 2022-09-30)
       (detail "filled 2022-09-30 after the 2022-09-23 screen read Bearish"))
      ((symbol DINO) (entry_date 2022-07-06)
       (detail "filled 2022-07-06 after the 2022-07-01 screen read Bearish")))))))
 (audit_join ((matched 194) (total 194))))
