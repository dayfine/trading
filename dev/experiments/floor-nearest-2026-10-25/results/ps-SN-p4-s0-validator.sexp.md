# Post-run validation report

Invariant checks failing: 3
audit join: 185/185 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-ps/trading/test_data/share_classes.sexp)
V7 INVARIANT 7 violations
    XERS 2024-02-14 Virgin_territory but only 295 weekly bars (< 520) before entry
    PCOR 2023-07-11 Virgin_territory but only 112 weekly bars (< 520) before entry
    NVEE 2022-08-17 Virgin_territory but only 460 weekly bars (< 520) before entry
    KD 2023-09-11 Virgin_territory but only 99 weekly bars (< 520) before entry
    FN 2019-12-12 Virgin_territory but only 494 weekly bars (< 520) before entry
    ELF 2021-09-07 Virgin_territory but only 259 weekly bars (< 520) before entry
    BLD 2021-10-22 Virgin_territory but only 331 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 44 violations (34 skipped)
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.75
    WLY 2021-06-17 prior_top=54.87 within +25% of entry=54.45
    VRNS 2021-07-27 prior_top=71.50 within +25% of entry=62.12
    VICR 2021-07-27 prior_top=107.97 within +25% of entry=107.30
    TRUP 2021-11-15 prior_top=129.99 within +25% of entry=129.70
    SSTK 2020-09-04 prior_top=49.52 within +25% of entry=47.13
    SPB 2021-10-04 prior_top=98.59 within +25% of entry=97.90
    SIMO 2022-01-24 prior_top=86.24 within +25% of entry=83.93
    SHLX 2020-01-13 prior_top=27.19 within +25% of entry=22.11
    RRC 2022-03-07 prior_top=27.65 within +25% of entry=26.64
V10 EXPECTATION 2 violations (34 skipped)
    VIR 2021-02-17 entry_wk_close=76.58 > prior=40.53 (spike>60%)
    ISEE 2022-09-30 entry_wk_close=17.94 > prior=9.44 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 23 violations
    WTRG 2021-12-21 installed_stop=43.9296 vs fill=51.7100 -> dist=0.1505 > gate=0.1500
    TXNM 2020-02-03 installed_stop=45.3408 vs fill=54.3000 -> dist=0.1650 > gate=0.1500
    TTEK 2024-02-13 installed_stop=148.4256 vs fill=175.7000 -> dist=0.1552 > gate=0.1500
    TTE 2024-04-16 installed_stop=59.8750 vs fill=71.3800 -> dist=0.1612 > gate=0.1500
    SSD 2021-03-08 installed_stop=89.1456 vs fill=104.9500 -> dist=0.1506 > gate=0.1500
    NVR 2022-01-07 installed_stop=4559.8750 vs fill=5465.9100 -> dist=0.1658 > gate=0.1500
    NVEE 2022-08-17 installed_stop=120.8750 vs fill=142.2700 -> dist=0.1504 > gate=0.1500
    NBIS 2021-10-04 installed_stop=63.9840 vs fill=76.1800 -> dist=0.1601 > gate=0.1500
    LZB 2024-07-15 installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500
    LPG 2023-09-15 installed_stop=23.2022 vs fill=27.3000 -> dist=0.1501 > gate=0.1500
V13 INVARIANT 3 violations
    SHLX 2020-01-13 entry_price=22.1100 outside 2020-01-13 bar [21.6360, 22.1050]
    LACO 2020-05-27 no bar on exit_date 2020-10-09 (nearest earlier bar: 2020-10-08)
    KD 2023-09-11 entry_price=17.3200 outside 2023-09-11 bar [16.7000, 17.3190]
V14 EXPECTATION 4 violations
    TDS 2023-09-11 entry bar 2023-09-11 open=17.8500 low=17.3700 close=17.6500 vs stop=17.1658, exit=17.0600
    FLNA 2020-10-12 entry bar 2020-10-12 open=11.8900 low=11.0700 close=11.4300 vs stop=10.8755, exit=10.8100
    EXTR 2022-01-21 entry bar 2022-01-21 open=12.8100 low=12.4900 close=12.4900 vs stop=12.1943, exit=12.0900
    ARDX 2021-04-20 entry bar 2021-04-20 open=35.4000 low=29.3600 close=32.2800 vs stop=31.8269, exit=31.8200
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 3 violations
    ANIP 2024-03-11 median close 8.21 over 5786 bars (2001-07-24..2024-12-23); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    FIT 2019-11-26 median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0
    RRC 2022-03-07 median close 15.98 over 9216 bars (1984-11-05..2024-12-23); bar 1992-11-23 close 4.22 (+1399.47% vs prior close 0.28) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 22 violations
    TDS 2023-09-11 LONG installed_stop 17.1648 vs screener_proxy_stop 16.0264: 7.10% tighter > 3%
    SSTK 2020-09-04 LONG installed_stop 44.4864 vs screener_proxy_stop 42.5132: 4.64% tighter > 3%
    SIMO 2022-01-24 LONG installed_stop 79.4880 vs screener_proxy_stop 75.6976: 5.01% tighter > 3%
    QCOM 2022-01-20 LONG installed_stop 164.3616 vs screener_proxy_stop 155.2776: 5.85% tighter > 3%
    PKG 2023-08-21 LONG installed_stop 139.8912 vs screener_proxy_stop 135.2124: 3.46% tighter > 3%
    NSP 2019-03-05 LONG installed_stop 116.8704 vs screener_proxy_stop 112.0192: 4.33% tighter > 3%
    NCMI 2024-04-08 LONG installed_stop 4.8480 vs screener_proxy_stop 4.7012: 3.12% tighter > 3%
    MSEX 2022-04-27 LONG installed_stop 84.8750 vs screener_proxy_stop 80.5460: 5.37% tighter > 3%
    MRVL 2023-06-21 LONG installed_stop 55.8750 vs screener_proxy_stop 54.0224: 3.43% tighter > 3%
    HUYA 2024-03-19 LONG installed_stop 4.2048 vs screener_proxy_stop 3.9100: 7.54% tighter > 3%
V22 EXPECTATION 20 violations (58 skipped: position has no stop-decision rows)
    ADNT 2020-02-21 no stop move for 31 weeks (2020-11-09..2021-06-18), 1 completed cycle(s) stalled; last: stop 25.38, candidate 20.66, ma 20.86, correction extreme 26.23 (extreme/ma 1.26)
    AIT 2022-08-26 no stop move for 16 weeks (2022-10-05..2023-01-26), 1 completed cycle(s) stalled; last: stop 104.22, candidate 102.48, ma 103.52, correction extreme 114.59 (extreme/ma 1.11)
    AN 2020-07-31 no stop move for 16 weeks (2020-08-04..2020-11-24), 2 completed cycle(s) stalled; last: stop 48.84, candidate 48.78, ma 49.27, correction extreme 50.52 (extreme/ma 1.03)
    ANET 2023-03-10 no stop move for 13 weeks (2023-03-13..2023-06-16), 1 completed cycle(s) stalled; last: stop 127.22, candidate 35.88, ma 36.48, correction extreme 131.68 (extreme/ma 3.61)
    BBWI 2020-07-31 no stop move for 31 weeks (2020-08-05..2021-03-12), 7 completed cycle(s) stalled; last: stop 22.92, candidate 20.38, ma 20.76, correction extreme 36.10 (extreme/ma 1.74)
    CHDN 2019-05-17 no stop move for 23 weeks (2019-06-03..2019-11-15), 1 completed cycle(s) stalled; last: stop 90.13, candidate 56.31, ma 56.88, correction extreme 113.88 (extreme/ma 2.00)
    CIB 2022-02-11 no stop move for 16 weeks (2022-03-02..2022-06-27), 2 completed cycle(s) stalled; last: stop 32.15, candidate 21.26, ma 21.48, correction extreme 34.46 (extreme/ma 1.60)
    CLX 2020-03-13 no stop move for 16 weeks (2020-03-16..2020-07-10), 1 completed cycle(s) stalled; last: stop 150.41, candidate 137.88, ma 139.40, correction extreme 161.11 (extreme/ma 1.16)
    DQ 2019-06-14 no stop move for 18 weeks (2019-06-17..2019-10-21), 2 completed cycle(s) stalled; last: stop 38.23, candidate 7.88, ma 8.09, correction extreme 39.01 (extreme/ma 4.82)
    DXCM 2019-07-05 no stop move for 55 weeks (2019-07-22..2020-08-14), 8 completed cycle(s) stalled; last: stop 133.66, candidate 92.38, ma 93.31, correction extreme 381.12 (extreme/ma 4.08)
V23 EXPECTATION 5 violations
    SLB 2022-02-24 filled 2022-02-24 after the 2022-02-18 screen read Bearish
    ISEE 2022-09-30 filled 2022-09-30 after the 2022-09-23 screen read Bearish
    IMO 2022-06-16 filled 2022-06-16 after the 2022-06-10 screen read Bearish
    CIB 2022-03-02 filled 2022-03-02 after the 2022-02-25 screen read Bearish
    AIT 2022-10-05 filled 2022-10-05 after the 2022-09-30 screen read Bearish
