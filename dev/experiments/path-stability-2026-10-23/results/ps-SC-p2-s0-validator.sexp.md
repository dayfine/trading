# Post-run validation report

Invariant checks failing: 3
audit join: 187/187 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-ps/trading/test_data/share_classes.sexp)
V7 INVARIANT 2 violations
    XERS 2024-02-14 Virgin_territory but only 295 weekly bars (< 520) before entry
    FN 2019-12-12 Virgin_territory but only 494 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 48 violations (30 skipped)
    ZS 2020-10-29 prior_top=154.85 within +25% of entry=142.28
    XLRN 2020-04-20 prior_top=97.78 within +25% of entry=97.02
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.75
    WOLF_old2 2021-11-22 prior_top=139.55 within +25% of entry=133.00
    WIX 2021-03-03 prior_top=353.09 within +25% of entry=327.36
    VICR 2021-07-27 prior_top=107.97 within +25% of entry=107.30
    THO 2021-02-08 prior_top=130.65 within +25% of entry=122.15
    SSTK 2020-09-04 prior_top=49.52 within +25% of entry=47.13
    SIMO 2022-01-24 prior_top=86.24 within +25% of entry=83.93
    SGEN 2019-10-14 prior_top=84.32 within +25% of entry=82.43
V10 EXPECTATION 1 violations (30 skipped)
    ISEE 2022-09-30 entry_wk_close=17.94 > prior=9.44 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 7 violations
    ZS 2020-10-29 installed_stop=118.8750 vs fill=142.2800 -> dist=0.1645 > gate=0.1500
    SOUN 2024-04-02 installed_stop=4.3750 vs fill=5.2400 -> dist=0.1651 > gate=0.1500
    QLYS 2021-01-20 installed_stop=106.9728 vs fill=125.8900 -> dist=0.1503 > gate=0.1500
    LZB 2024-07-15 installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500
    KLIC 2019-11-05 installed_stop=21.4752 vs fill=25.3100 -> dist=0.1515 > gate=0.1500
    GC 2020-04-06 installed_stop=1392.8640 vs fill=1647.7000 -> dist=0.1547 > gate=0.1500
    DAR 2022-04-20 installed_stop=73.4880 vs fill=86.5100 -> dist=0.1505 > gate=0.1500
V13 INVARIANT 4 violations
    MIME 2021-06-25 no bar on exit_date 2022-05-20 (nearest earlier bar: 2022-05-19)
    LACO 2020-05-27 no bar on exit_date 2020-10-09 (nearest earlier bar: 2020-10-08)
    ERF 2024-03-18 no bar on exit_date 2024-05-31 (nearest earlier bar: 2024-05-30)
    BMCH 2020-08-11 no bar on exit_date 2021-01-06 (nearest earlier bar: 2021-01-05)
V14 EXPECTATION 9 violations
    TIGR 2024-11-13 entry bar 2024-11-13 open=6.1000 low=5.5900 close=5.6700 vs stop=5.3744, exit=5.3600
    TDS 2023-09-11 entry bar 2023-09-11 open=17.8500 low=17.3700 close=17.6500 vs stop=17.1658, exit=17.0600
    SDA 2023-07-12 entry bar 2023-07-12 open=14.1500 low=11.5500 close=11.7000 vs stop=10.4919, exit=10.4400
    PEGA 2020-03-10 entry bar 2020-03-10 open=79.5400 low=76.5800 close=83.4400 vs stop=78.9307, exit=78.9000
    FLNA 2020-10-12 entry bar 2020-10-12 open=11.8900 low=11.0700 close=11.4300 vs stop=10.8755, exit=10.8100
    EXTR 2022-01-21 entry bar 2022-01-21 open=12.8100 low=12.4900 close=12.4900 vs stop=12.1943, exit=12.0900
    CRI 2021-05-10 entry bar 2021-05-10 open=110.4300 low=105.0900 close=105.1900 vs stop=102.8731, exit=102.8000
    BZUN 2021-02-22 entry bar 2021-02-22 open=50.8300 low=48.4500 close=48.4600 vs stop=45.8705, exit=45.8200
    ARDX 2021-04-20 entry bar 2021-04-20 open=35.4000 low=29.3600 close=32.2800 vs stop=31.8269, exit=31.8200
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 3 violations
    ANIP 2024-03-11 median close 8.21 over 5786 bars (2001-07-24..2024-12-23); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    FIT 2019-11-26 median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0
    FLO 2021-06-03 median close 18.61 over 11288 bars (1980-03-17..2024-12-23); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 37 violations
    VGR 2021-12-06 LONG installed_stop 10.3471 vs screener_proxy_stop 10.0280: 3.18% tighter > 3%
    TNK 2023-11-29 LONG installed_stop 46.3872 vs screener_proxy_stop 44.4268: 4.41% tighter > 3%
    TIGR 2024-11-13 LONG installed_stop 5.3750 vs screener_proxy_stop 5.0876: 5.65% tighter > 3%
    TDS 2023-09-11 LONG installed_stop 17.1648 vs screener_proxy_stop 16.0264: 7.10% tighter > 3%
    SSTK 2020-09-04 LONG installed_stop 44.4864 vs screener_proxy_stop 42.5132: 4.64% tighter > 3%
    SPSC 2019-02-28 LONG installed_stop 98.2368 vs screener_proxy_stop 93.0856: 5.53% tighter > 3%
    SIMO 2022-01-24 LONG installed_stop 79.4880 vs screener_proxy_stop 75.6976: 5.01% tighter > 3%
    REAL 2024-06-20 LONG installed_stop 2.9232 vs screener_proxy_stop 2.7140: 7.71% tighter > 3%
    QCOM 2022-01-20 LONG installed_stop 164.3616 vs screener_proxy_stop 155.2776: 5.85% tighter > 3%
    PEGA 2020-03-10 LONG installed_stop 78.9312 vs screener_proxy_stop 76.4244: 3.28% tighter > 3%
V22 EXPECTATION 21 violations (30 skipped: position has no stop-decision rows)
    ADNT 2020-02-21 no stop move for 31 weeks (2020-11-09..2021-06-18), 1 completed cycle(s) stalled; last: stop 25.38, candidate 20.66, ma 20.86, correction extreme 26.23 (extreme/ma 1.26)
    AIT 2022-08-26 no stop move for 16 weeks (2022-10-05..2023-01-26), 1 completed cycle(s) stalled; last: stop 104.22, candidate 102.48, ma 103.52, correction extreme 114.59 (extreme/ma 1.11)
    AN 2020-07-31 no stop move for 16 weeks (2020-08-04..2020-11-24), 2 completed cycle(s) stalled; last: stop 48.84, candidate 48.78, ma 49.27, correction extreme 50.52 (extreme/ma 1.03)
    AUDC 2020-05-01 no stop move for 13 weeks (2020-05-04..2020-08-07), 5 completed cycle(s) stalled; last: stop 26.88, candidate 26.79, ma 27.06, correction extreme 37.21 (extreme/ma 1.38)
    BBWI 2020-07-31 no stop move for 31 weeks (2020-08-05..2021-03-12), 7 completed cycle(s) stalled; last: stop 22.92, candidate 20.38, ma 20.76, correction extreme 36.10 (extreme/ma 1.74)
    CLX 2020-03-13 no stop move for 16 weeks (2020-03-16..2020-07-10), 1 completed cycle(s) stalled; last: stop 150.41, candidate 137.88, ma 139.40, correction extreme 161.11 (extreme/ma 1.16)
    DKS 2019-10-04 no stop move for 14 weeks (2019-11-07..2020-02-14), 1 completed cycle(s) stalled; last: stop 36.34, candidate 31.73, ma 32.06, correction extreme 38.81 (extreme/ma 1.21)
    DXCM 2019-07-05 no stop move for 55 weeks (2019-07-22..2020-08-14), 8 completed cycle(s) stalled; last: stop 133.66, candidate 92.38, ma 93.31, correction extreme 381.12 (extreme/ma 4.08)
    GILD 2020-02-28 no stop move for 14 weeks (2020-03-02..2020-06-12), 2 completed cycle(s) stalled; last: stop 63.96, candidate 55.88, ma 56.61, correction extreme 74.40 (extreme/ma 1.31)
    HPQ 2020-03-06 no stop move for 13 weeks (2020-11-24..2021-03-01), 1 completed cycle(s) stalled; last: stop 19.36, candidate 18.41, ma 18.60, correction extreme 24.07 (extreme/ma 1.29)
V23 EXPECTATION 2 violations
    ISEE 2022-09-30 filled 2022-09-30 after the 2022-09-23 screen read Bearish
    AIT 2022-10-05 filled 2022-10-05 after the 2022-09-30 screen read Bearish
