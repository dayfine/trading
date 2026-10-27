# Post-run validation report

Invariant checks failing: 3
audit join: 148/148 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-ps/trading/test_data/share_classes.sexp)
V7 INVARIANT 1 violations
    FHB 2022-01-13 Virgin_territory but only 284 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 41 violations (23 skipped)
    XLRN 2020-04-20 prior_top=97.78 within +25% of entry=97.02
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.75
    WOLF_old2 2021-11-22 prior_top=139.55 within +25% of entry=133.00
    WIX 2021-03-03 prior_top=353.09 within +25% of entry=327.36
    THO 2021-02-16 prior_top=130.65 within +25% of entry=123.20
    STEL 2022-11-21 prior_top=33.35 within +25% of entry=33.29
    SSTK 2020-09-04 prior_top=49.52 within +25% of entry=47.13
    SGEN 2019-10-14 prior_top=84.32 within +25% of entry=82.43
    PJT 2023-11-03 prior_top=84.12 within +25% of entry=83.60
    ON 2021-08-27 prior_top=45.28 within +25% of entry=44.85
V10 EXPECTATION 2 violations (23 skipped)
    ISEE 2022-09-30 entry_wk_close=17.94 > prior=9.44 (spike>60%)
    APPS 2020-06-15 entry_wk_close=10.38 > prior=5.82 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 9 violations
    VIRT 2021-03-18 installed_stop=24.8750 vs fill=29.3000 -> dist=0.1510 > gate=0.1500
    SOUN 2024-04-02 installed_stop=4.3750 vs fill=5.2400 -> dist=0.1651 > gate=0.1500
    QLYS 2021-01-20 installed_stop=106.9728 vs fill=125.8900 -> dist=0.1503 > gate=0.1500
    OMF 2021-03-08 installed_stop=43.8750 vs fill=52.5200 -> dist=0.1646 > gate=0.1500
    NVDA 2021-05-24 installed_stop=567.6864 vs fill=154.5500 -> dist=2.6732 > gate=0.1500
    MCK 2020-05-28 installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500
    KLIC 2019-11-05 installed_stop=21.4752 vs fill=25.3100 -> dist=0.1515 > gate=0.1500
    GC 2020-04-06 installed_stop=1392.8640 vs fill=1647.7000 -> dist=0.1547 > gate=0.1500
    FHB 2022-01-13 installed_stop=26.3904 vs fill=31.0500 -> dist=0.1501 > gate=0.1500
V13 INVARIANT 2 violations (1 skipped)
    SAFE 2020-03-10 entry_price=6.7900 outside 2020-03-10 bar [6.7908, 7.1721]
    LACO 2020-05-27 no bar on exit_date 2020-10-09 (nearest earlier bar: 2020-10-08)
V14 EXPECTATION 4 violations
    TDS 2023-09-11 entry bar 2023-09-11 open=17.8500 low=17.3700 close=17.6500 vs stop=17.1658, exit=17.0600
    SDA 2023-07-12 entry bar 2023-07-12 open=14.1500 low=11.5500 close=11.7000 vs stop=10.4919, exit=10.4400
    FLNA 2020-10-12 entry bar 2020-10-12 open=11.8900 low=11.0700 close=11.4300 vs stop=10.8755, exit=10.8100
    EXTR 2022-01-21 entry bar 2022-01-21 open=12.8100 low=12.4900 close=12.4900 vs stop=12.1943, exit=12.0900
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 2 violations
    ANIP 2024-03-11 median close 8.21 over 5786 bars (2001-07-24..2024-12-23); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    TRT 2021-12-06 median close 3.95 over 7464 bars (1984-12-07..2024-12-23); bar 1994-10-14 close 2.00 (+299.84% vs prior close 0.50) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 22 violations
    VGR 2021-12-06 LONG installed_stop 10.3471 vs screener_proxy_stop 10.0280: 3.18% tighter > 3%
    TDS 2023-09-11 LONG installed_stop 17.1648 vs screener_proxy_stop 16.0264: 7.10% tighter > 3%
    SSTK 2020-09-04 LONG installed_stop 44.4864 vs screener_proxy_stop 42.5132: 4.64% tighter > 3%
    SAFE 2020-03-10 LONG installed_stop 6.3750 vs screener_proxy_stop 6.1272: 4.04% tighter > 3%
    QCOM 2022-01-20 LONG installed_stop 164.3616 vs screener_proxy_stop 155.2776: 5.85% tighter > 3%
    PKG 2023-08-21 LONG installed_stop 139.8912 vs screener_proxy_stop 135.2124: 3.46% tighter > 3%
    NSP 2019-03-05 LONG installed_stop 116.8704 vs screener_proxy_stop 112.0192: 4.33% tighter > 3%
    NPKI 2024-01-04 LONG installed_stop 6.2304 vs screener_proxy_stop 5.7684: 8.01% tighter > 3%
    MSEX 2022-04-27 LONG installed_stop 83.8560 vs screener_proxy_stop 80.5460: 4.11% tighter > 3%
    MGNI 2024-12-13 LONG installed_stop 15.3750 vs screener_proxy_stop 14.7200: 4.45% tighter > 3%
V22 EXPECTATION 17 violations (36 skipped: position has no stop-decision rows)
    AIT 2022-08-26 no stop move for 16 weeks (2022-10-05..2023-01-26), 1 completed cycle(s) stalled; last: stop 104.22, candidate 102.48, ma 103.52, correction extreme 114.59 (extreme/ma 1.11)
    AN 2020-07-31 no stop move for 16 weeks (2020-08-04..2020-11-24), 2 completed cycle(s) stalled; last: stop 48.84, candidate 48.78, ma 49.27, correction extreme 50.52 (extreme/ma 1.03)
    BBWI 2020-07-31 no stop move for 31 weeks (2020-08-05..2021-03-12), 7 completed cycle(s) stalled; last: stop 22.92, candidate 20.38, ma 20.76, correction extreme 36.10 (extreme/ma 1.74)
    CLX 2020-03-13 no stop move for 16 weeks (2020-03-16..2020-07-10), 1 completed cycle(s) stalled; last: stop 150.41, candidate 137.88, ma 139.40, correction extreme 161.11 (extreme/ma 1.16)
    DKS 2019-10-04 no stop move for 14 weeks (2019-11-07..2020-02-14), 1 completed cycle(s) stalled; last: stop 36.34, candidate 31.73, ma 32.06, correction extreme 38.81 (extreme/ma 1.21)
    DXCM 2019-07-05 no stop move for 55 weeks (2019-07-22..2020-08-14), 8 completed cycle(s) stalled; last: stop 133.66, candidate 92.38, ma 93.31, correction extreme 381.12 (extreme/ma 4.08)
    GILD 2020-02-28 no stop move for 14 weeks (2020-03-02..2020-06-12), 2 completed cycle(s) stalled; last: stop 63.96, candidate 55.88, ma 56.61, correction extreme 74.40 (extreme/ma 1.31)
    KLIC 2019-10-11 no stop move for 16 weeks (2019-11-05..2020-02-28), 2 completed cycle(s) stalled; last: stop 21.48, candidate 21.38, ma 21.79, correction extreme 25.07 (extreme/ma 1.15)
    OWL 2021-07-16 no stop move for 19 weeks (2021-08-02..2021-12-17), 2 completed cycle(s) stalled; last: stop 11.16, candidate 10.88, ma 11.15, correction extreme 14.67 (extreme/ma 1.32)
    PKG 2023-08-18 no stop move for 18 weeks (2023-08-21..2023-12-29), 1 completed cycle(s) stalled; last: stop 139.89, candidate 135.77, ma 137.14, correction extreme 143.82 (extreme/ma 1.05)
V23 EXPECTATION 2 violations
    ISEE 2022-09-30 filled 2022-09-30 after the 2022-09-23 screen read Bearish
    AIT 2022-10-05 filled 2022-10-05 after the 2022-09-30 screen read Bearish
