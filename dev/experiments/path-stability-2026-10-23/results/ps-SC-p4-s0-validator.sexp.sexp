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
   ((id V7) (severity Invariant) (passed false) (n_violations 2)
    (n_skipped 0)
    (specimens
     (((symbol XERS) (entry_date 2024-02-14)
       (detail
        "Virgin_territory but only 295 weekly bars (< 520) before entry"))
      ((symbol FN) (entry_date 2019-12-12)
       (detail
        "Virgin_territory but only 494 weekly bars (< 520) before entry")))))
   ((id V8) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V9) (severity Expectation) (passed false) (n_violations 47)
    (n_skipped 28)
    (specimens
     (((symbol XLRN) (entry_date 2020-04-20)
       (detail "prior_top=97.78 within +25% of entry=97.02"))
      ((symbol X) (entry_date 2023-09-19)
       (detail "prior_top=37.63 within +25% of entry=31.75"))
      ((symbol WOLF_old2) (entry_date 2021-11-22)
       (detail "prior_top=139.55 within +25% of entry=133.00"))
      ((symbol WIX) (entry_date 2021-03-03)
       (detail "prior_top=353.09 within +25% of entry=327.36"))
      ((symbol VICR) (entry_date 2021-07-27)
       (detail "prior_top=107.97 within +25% of entry=107.30"))
      ((symbol THO) (entry_date 2021-02-16)
       (detail "prior_top=130.65 within +25% of entry=123.20"))
      ((symbol SSTK) (entry_date 2020-09-04)
       (detail "prior_top=49.52 within +25% of entry=47.13"))
      ((symbol SIMO) (entry_date 2022-01-24)
       (detail "prior_top=86.24 within +25% of entry=83.93"))
      ((symbol SGEN) (entry_date 2019-10-14)
       (detail "prior_top=84.32 within +25% of entry=82.43"))
      ((symbol PJT) (entry_date 2023-11-03)
       (detail "prior_top=84.12 within +25% of entry=83.60")))))
   ((id V10) (severity Expectation) (passed false) (n_violations 1)
    (n_skipped 28)
    (specimens
     (((symbol ISEE) (entry_date 2022-09-30)
       (detail "entry_wk_close=17.94 > prior=9.44 (spike>60%)")))))
   ((id V11) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V12) (severity Invariant) (passed false) (n_violations 8)
    (n_skipped 0)
    (specimens
     (((symbol SOUN) (entry_date 2024-04-02)
       (detail
        "installed_stop=4.3750 vs fill=5.2400 -> dist=0.1651 > gate=0.1500"))
      ((symbol QLYS) (entry_date 2021-01-20)
       (detail
        "installed_stop=106.9728 vs fill=125.8900 -> dist=0.1503 > gate=0.1500"))
      ((symbol PGNY) (entry_date 2021-04-26)
       (detail
        "installed_stop=45.7536 vs fill=53.8700 -> dist=0.1507 > gate=0.1500"))
      ((symbol MCK) (entry_date 2020-05-28)
       (detail
        "installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500"))
      ((symbol LZB) (entry_date 2024-07-15)
       (detail
        "installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500"))
      ((symbol KLIC) (entry_date 2019-11-05)
       (detail
        "installed_stop=21.4752 vs fill=25.3100 -> dist=0.1515 > gate=0.1500"))
      ((symbol GC) (entry_date 2020-04-06)
       (detail
        "installed_stop=1392.8640 vs fill=1647.7000 -> dist=0.1547 > gate=0.1500"))
      ((symbol ESI) (entry_date 2022-03-07)
       (detail
        "installed_stop=16.7424 vs fill=19.8900 -> dist=0.1583 > gate=0.1500")))))
   ((id V13) (severity Invariant) (passed false) (n_violations 3)
    (n_skipped 0)
    (specimens
     (((symbol MIME) (entry_date 2021-06-25)
       (detail
        "no bar on exit_date 2022-05-20 (nearest earlier bar: 2022-05-19)"))
      ((symbol LACO) (entry_date 2020-05-27)
       (detail
        "no bar on exit_date 2020-10-09 (nearest earlier bar: 2020-10-08)"))
      ((symbol ERF) (entry_date 2024-03-18)
       (detail
        "no bar on exit_date 2024-05-31 (nearest earlier bar: 2024-05-30)")))))
   ((id V14) (severity Expectation) (passed false) (n_violations 9)
    (n_skipped 0)
    (specimens
     (((symbol TIGR) (entry_date 2024-11-13)
       (detail
        "entry bar 2024-11-13 open=6.1000 low=5.5900 close=5.6700 vs stop=5.3744, exit=5.3600"))
      ((symbol TDS) (entry_date 2023-09-11)
       (detail
        "entry bar 2023-09-11 open=17.8500 low=17.3700 close=17.6500 vs stop=17.1658, exit=17.0600"))
      ((symbol SDA) (entry_date 2023-07-12)
       (detail
        "entry bar 2023-07-12 open=14.1500 low=11.5500 close=11.7000 vs stop=10.4919, exit=10.4400"))
      ((symbol FLNA) (entry_date 2020-10-12)
       (detail
        "entry bar 2020-10-12 open=11.8900 low=11.0700 close=11.4300 vs stop=10.8755, exit=10.8100"))
      ((symbol EXTR) (entry_date 2022-01-21)
       (detail
        "entry bar 2022-01-21 open=12.8100 low=12.4900 close=12.4900 vs stop=12.1943, exit=12.0900"))
      ((symbol ESI) (entry_date 2022-03-07)
       (detail
        "entry bar 2022-03-07 open=21.9000 low=19.7400 close=19.9300 vs stop=16.7414, exit=19.3300"))
      ((symbol CRI) (entry_date 2021-05-10)
       (detail
        "entry bar 2021-05-10 open=110.4300 low=105.0900 close=105.1900 vs stop=102.8731, exit=102.8000"))
      ((symbol BZUN) (entry_date 2021-02-22)
       (detail
        "entry bar 2021-02-22 open=50.8300 low=48.4500 close=48.4600 vs stop=45.8705, exit=45.8200"))
      ((symbol ARDX) (entry_date 2021-04-20)
       (detail
        "entry bar 2021-04-20 open=35.4000 low=29.3600 close=32.2800 vs stop=31.8269, exit=31.8200")))))
   ((id V15) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V16) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V17) (severity Expectation) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V18) (severity Expectation) (passed false) (n_violations 2)
    (n_skipped 0)
    (specimens
     (((symbol ANIP) (entry_date 2024-03-11)
       (detail
        "median close 8.21 over 5786 bars (2001-07-24..2024-12-23); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0"))
      ((symbol FIT) (entry_date 2019-11-26)
       (detail
        "median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0")))))
   ((id V19) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V20) (severity Invariant) (passed true) (n_violations 0)
    (n_skipped 0) (specimens ()))
   ((id V21) (severity Expectation) (passed false) (n_violations 38)
    (n_skipped 0)
    (specimens
     (((symbol VGR) (entry_date 2021-12-06)
       (detail
        "LONG installed_stop 10.3471 vs screener_proxy_stop 10.0280: 3.18% tighter > 3%"))
      ((symbol TNK) (entry_date 2023-11-29)
       (detail
        "LONG installed_stop 46.3872 vs screener_proxy_stop 44.4268: 4.41% tighter > 3%"))
      ((symbol TIGR) (entry_date 2024-11-13)
       (detail
        "LONG installed_stop 5.3750 vs screener_proxy_stop 5.0876: 5.65% tighter > 3%"))
      ((symbol TDS) (entry_date 2023-09-11)
       (detail
        "LONG installed_stop 17.1648 vs screener_proxy_stop 16.0264: 7.10% tighter > 3%"))
      ((symbol SSTK) (entry_date 2020-09-04)
       (detail
        "LONG installed_stop 44.4864 vs screener_proxy_stop 42.5132: 4.64% tighter > 3%"))
      ((symbol SIMO) (entry_date 2022-01-24)
       (detail
        "LONG installed_stop 79.4880 vs screener_proxy_stop 75.6976: 5.01% tighter > 3%"))
      ((symbol REAL) (entry_date 2024-06-20)
       (detail
        "LONG installed_stop 2.9232 vs screener_proxy_stop 2.7140: 7.71% tighter > 3%"))
      ((symbol QCOM) (entry_date 2022-01-20)
       (detail
        "LONG installed_stop 164.3616 vs screener_proxy_stop 155.2776: 5.85% tighter > 3%"))
      ((symbol PKG) (entry_date 2023-08-21)
       (detail
        "LONG installed_stop 139.8912 vs screener_proxy_stop 135.2124: 3.46% tighter > 3%"))
      ((symbol NTRA) (entry_date 2020-05-26)
       (detail
        "LONG installed_stop 41.4336 vs screener_proxy_stop 38.6492: 7.20% tighter > 3%")))))
   ((id V22) (severity Expectation) (passed false) (n_violations 18)
    (n_skipped 32)
    (specimens
     (((symbol ADNT) (entry_date 2020-02-21)
       (detail
        "no stop move for 31 weeks (2020-11-09..2021-06-18), 1 completed cycle(s) stalled; last: stop 25.38, candidate 20.66, ma 20.86, correction extreme 26.23 (extreme/ma 1.26)"))
      ((symbol AIT) (entry_date 2022-08-26)
       (detail
        "no stop move for 16 weeks (2022-10-05..2023-01-26), 1 completed cycle(s) stalled; last: stop 104.22, candidate 102.48, ma 103.52, correction extreme 114.59 (extreme/ma 1.11)"))
      ((symbol AN) (entry_date 2020-07-31)
       (detail
        "no stop move for 16 weeks (2020-08-04..2020-11-24), 2 completed cycle(s) stalled; last: stop 48.84, candidate 48.78, ma 49.27, correction extreme 50.52 (extreme/ma 1.03)"))
      ((symbol BBWI) (entry_date 2020-07-31)
       (detail
        "no stop move for 31 weeks (2020-08-05..2021-03-12), 7 completed cycle(s) stalled; last: stop 22.92, candidate 20.38, ma 20.76, correction extreme 36.10 (extreme/ma 1.74)"))
      ((symbol CLX) (entry_date 2020-03-13)
       (detail
        "no stop move for 16 weeks (2020-03-16..2020-07-10), 1 completed cycle(s) stalled; last: stop 150.41, candidate 137.88, ma 139.40, correction extreme 161.11 (extreme/ma 1.16)"))
      ((symbol DKS) (entry_date 2019-10-04)
       (detail
        "no stop move for 14 weeks (2019-11-07..2020-02-14), 1 completed cycle(s) stalled; last: stop 36.34, candidate 31.73, ma 32.06, correction extreme 38.81 (extreme/ma 1.21)"))
      ((symbol DXCM) (entry_date 2019-07-05)
       (detail
        "no stop move for 55 weeks (2019-07-22..2020-08-14), 8 completed cycle(s) stalled; last: stop 133.66, candidate 92.38, ma 93.31, correction extreme 381.12 (extreme/ma 4.08)"))
      ((symbol GILD) (entry_date 2020-02-28)
       (detail
        "no stop move for 14 weeks (2020-03-02..2020-06-12), 2 completed cycle(s) stalled; last: stop 63.96, candidate 55.88, ma 56.61, correction extreme 74.40 (extreme/ma 1.31)"))
      ((symbol HPQ) (entry_date 2020-03-06)
       (detail
        "no stop move for 13 weeks (2020-11-24..2021-03-01), 1 completed cycle(s) stalled; last: stop 19.36, candidate 18.41, ma 18.60, correction extreme 24.07 (extreme/ma 1.29)"))
      ((symbol KLIC) (entry_date 2019-10-11)
       (detail
        "no stop move for 16 weeks (2019-11-05..2020-02-28), 2 completed cycle(s) stalled; last: stop 21.48, candidate 21.38, ma 21.79, correction extreme 25.07 (extreme/ma 1.15)"))))
    (skip_reason "position has no stop-decision rows"))
   ((id V23) (severity Expectation) (passed false) (n_violations 2)
    (n_skipped 0)
    (specimens
     (((symbol ISEE) (entry_date 2022-09-30)
       (detail "filled 2022-09-30 after the 2022-09-23 screen read Bearish"))
      ((symbol AIT) (entry_date 2022-10-05)
       (detail "filled 2022-10-05 after the 2022-09-30 screen read Bearish")))))))
 (audit_join ((matched 183) (total 183))))
