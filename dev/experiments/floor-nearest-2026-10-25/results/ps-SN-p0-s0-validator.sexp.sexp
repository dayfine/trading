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
   ((id V9) (severity Expectation) (passed false) (n_violations 45)
    (n_skipped 29)
    (specimens
     (((symbol XLRN) (entry_date 2020-04-20)
       (detail "prior_top=97.78 within +25% of entry=97.02"))
      ((symbol X) (entry_date 2023-09-19)
       (detail "prior_top=37.63 within +25% of entry=31.75"))
      ((symbol WIX) (entry_date 2021-03-03)
       (detail "prior_top=353.09 within +25% of entry=327.36"))
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
      ((symbol RUN) (entry_date 2019-07-23)
       (detail "prior_top=20.21 within +25% of entry=17.88")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 2)
    (n_skipped 29)
    (specimens
     (((symbol VIR) (entry_date 2021-02-17)
       (detail "entry_wk_close=76.58 > prior=40.53 (spike>60%)"))
      ((symbol ISEE) (entry_date 2022-09-30)
       (detail "entry_wk_close=17.94 > prior=9.44 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 32)
    (n_skipped 0)
    (specimens
     (((symbol XEL) (entry_date 2020-01-27)
       (detail
        "installed_stop=56.8750 vs fill=67.1400 -> dist=0.1529 > gate=0.1500"))
      ((symbol WTRG) (entry_date 2021-12-21)
       (detail
        "installed_stop=43.9296 vs fill=51.7100 -> dist=0.1505 > gate=0.1500"))
      ((symbol VIRT) (entry_date 2021-03-18)
       (detail
        "installed_stop=24.8750 vs fill=29.3000 -> dist=0.1510 > gate=0.1500"))
      ((symbol TXNM) (entry_date 2020-02-03)
       (detail
        "installed_stop=45.3408 vs fill=54.3000 -> dist=0.1650 > gate=0.1500"))
      ((symbol TTEK) (entry_date 2024-02-13)
       (detail
        "installed_stop=148.4256 vs fill=175.7000 -> dist=0.1552 > gate=0.1500"))
      ((symbol TTE) (entry_date 2024-04-16)
       (detail
        "installed_stop=59.8750 vs fill=71.3800 -> dist=0.1612 > gate=0.1500"))
      ((symbol TRNO) (entry_date 2022-01-24)
       (detail
        "installed_stop=59.8750 vs fill=71.3800 -> dist=0.1612 > gate=0.1500"))
      ((symbol SSD) (entry_date 2021-03-08)
       (detail
        "installed_stop=89.1456 vs fill=104.9500 -> dist=0.1506 > gate=0.1500"))
      ((symbol QLYS) (entry_date 2021-01-20)
       (detail
        "installed_stop=106.9728 vs fill=125.8900 -> dist=0.1503 > gate=0.1500"))
      ((symbol PM) (entry_date 2021-11-19)
       (detail
        "installed_stop=75.2064 vs fill=89.9300 -> dist=0.1637 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 4)
    (n_skipped 0)
    (specimens
     (((symbol MIME) (entry_date 2021-06-25)
       (detail
        "no bar on exit_date 2022-05-20 (nearest earlier bar: 2022-05-19)"))
      ((symbol KD) (entry_date 2023-09-11)
       (detail
        "entry_price=17.3200 outside 2023-09-11 bar [16.7000, 17.3190]"))
      ((symbol BMCH) (entry_date 2020-08-20)
       (detail
        "no bar on exit_date 2021-01-06 (nearest earlier bar: 2021-01-05)"))
      ((symbol AXIA) (entry_date 2021-05-24)
       (detail "entry_price=9.9600 outside 2021-05-24 bar [9.9638, 10.1532]")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol TDS) (entry_date 2023-09-11)
       (detail
        "entry bar 2023-09-11 open=17.8500 low=17.3700 close=17.6500 vs stop=17.1658, exit=17.0600"))
      ((symbol CRI) (entry_date 2021-05-10)
       (detail
        "entry bar 2021-05-10 open=110.4300 low=105.0900 close=105.1900 vs stop=102.8731, exit=102.8000"))
      ((symbol ARDX) (entry_date 2021-04-20)
       (detail
        "entry bar 2021-04-20 open=35.4000 low=29.3600 close=32.2800 vs stop=31.8269, exit=31.8200")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 0)
    (specimens
     (((symbol FIT) (entry_date 2019-11-26)
       (detail
        "median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0")))))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V21) (severity Expectation) (passed false) (n_violations 18)
    (n_skipped 0)
    (specimens
     (((symbol VGR) (entry_date 2021-12-06)
       (detail
        "LONG installed_stop 10.3471 vs screener_proxy_stop 10.0280: 3.18% tighter > 3%"))
      ((symbol TDS) (entry_date 2023-09-11)
       (detail
        "LONG installed_stop 17.1648 vs screener_proxy_stop 16.0264: 7.10% tighter > 3%"))
      ((symbol SSTK) (entry_date 2020-09-04)
       (detail
        "LONG installed_stop 44.4864 vs screener_proxy_stop 42.5132: 4.64% tighter > 3%"))
      ((symbol SPSC) (entry_date 2019-02-28)
       (detail
        "LONG installed_stop 98.2368 vs screener_proxy_stop 93.0856: 5.53% tighter > 3%"))
      ((symbol QCOM) (entry_date 2022-01-20)
       (detail
        "LONG installed_stop 164.3616 vs screener_proxy_stop 155.2776: 5.85% tighter > 3%"))
      ((symbol PKG) (entry_date 2023-08-21)
       (detail
        "LONG installed_stop 139.8912 vs screener_proxy_stop 135.2124: 3.46% tighter > 3%"))
      ((symbol NSP) (entry_date 2019-03-05)
       (detail
        "LONG installed_stop 116.8704 vs screener_proxy_stop 112.0192: 4.33% tighter > 3%"))
      ((symbol NCMI) (entry_date 2024-04-08)
       (detail
        "LONG installed_stop 4.8480 vs screener_proxy_stop 4.7012: 3.12% tighter > 3%"))
      ((symbol MSEX) (entry_date 2022-04-27)
       (detail
        "LONG installed_stop 84.8750 vs screener_proxy_stop 80.5460: 5.37% tighter > 3%"))
      ((symbol MRVL) (entry_date 2023-06-21)
       (detail
        "LONG installed_stop 55.8750 vs screener_proxy_stop 54.0224: 3.43% tighter > 3%")))))
   ((id V22) (severity Expectation) (passed false) (n_violations 27)
    (n_skipped 43)
    (specimens
     (((symbol AN) (entry_date 2020-07-31)
       (detail
        "no stop move for 16 weeks (2020-08-04..2020-11-24), 2 completed cycle(s) stalled; last: stop 48.84, candidate 48.78, ma 49.27, correction extreme 50.52 (extreme/ma 1.03)"))
      ((symbol ANET) (entry_date 2023-03-10)
       (detail
        "no stop move for 13 weeks (2023-03-13..2023-06-16), 1 completed cycle(s) stalled; last: stop 127.22, candidate 35.88, ma 36.48, correction extreme 131.68 (extreme/ma 3.61)"))
      ((symbol ARLP) (entry_date 2024-05-10)
       (detail
        "no stop move for 13 weeks (2024-05-31..2024-08-30), 1 completed cycle(s) stalled; last: stop 20.97, candidate 17.73, ma 17.91, correction extreme 23.17 (extreme/ma 1.29)"))
      ((symbol BBWI) (entry_date 2020-07-31)
       (detail
        "no stop move for 31 weeks (2020-08-05..2021-03-12), 7 completed cycle(s) stalled; last: stop 22.92, candidate 20.38, ma 20.76, correction extreme 36.10 (extreme/ma 1.74)"))
      ((symbol CHDN) (entry_date 2019-05-17)
       (detail
        "no stop move for 23 weeks (2019-06-03..2019-11-15), 1 completed cycle(s) stalled; last: stop 90.13, candidate 56.31, ma 56.88, correction extreme 113.88 (extreme/ma 2.00)"))
      ((symbol CIB) (entry_date 2022-02-11)
       (detail
        "no stop move for 16 weeks (2022-03-02..2022-06-27), 2 completed cycle(s) stalled; last: stop 32.15, candidate 21.26, ma 21.48, correction extreme 34.46 (extreme/ma 1.60)"))
      ((symbol CLX) (entry_date 2020-03-13)
       (detail
        "no stop move for 16 weeks (2020-03-16..2020-07-10), 1 completed cycle(s) stalled; last: stop 150.41, candidate 137.88, ma 139.40, correction extreme 161.11 (extreme/ma 1.16)"))
      ((symbol CVNA) (entry_date 2024-07-05)
       (detail
        "no stop move for 25 weeks (2024-07-08..2024-12-30), 4 completed cycle(s) stalled; last: stop 116.17, candidate 25.38, ma 25.76, correction extreme 124.39 (extreme/ma 4.83)"))
      ((symbol DQ) (entry_date 2019-06-14)
       (detail
        "no stop move for 18 weeks (2019-06-17..2019-10-21), 2 completed cycle(s) stalled; last: stop 38.23, candidate 7.88, ma 8.09, correction extreme 39.01 (extreme/ma 4.82)"))
      ((symbol DXCM) (entry_date 2019-07-05)
       (detail
        "no stop move for 55 weeks (2019-07-22..2020-08-14), 8 completed cycle(s) stalled; last: stop 133.66, candidate 92.38, ma 93.31, correction extreme 381.12 (extreme/ma 4.08)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol SLB) (entry_date 2022-02-24)
       (detail "filled 2022-02-24 after the 2022-02-18 screen read Bearish"))
      ((symbol ISEE) (entry_date 2022-09-30)
       (detail "filled 2022-09-30 after the 2022-09-23 screen read Bearish"))
      ((symbol CIB) (entry_date 2022-03-02)
       (detail "filled 2022-03-02 after the 2022-02-25 screen read Bearish")))))))
 (audit_join ((matched 188) (total 188))))
