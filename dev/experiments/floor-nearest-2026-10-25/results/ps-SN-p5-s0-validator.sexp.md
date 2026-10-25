# Post-run validation report

Invariant checks failing: 3
audit join: 189/189 rows matched

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
V9 EXPECTATION 50 violations (27 skipped)
    XLRN 2020-04-20 prior_top=97.78 within +25% of entry=97.02
    X 2023-09-19 prior_top=37.63 within +25% of entry=31.75
    WIX 2021-03-03 prior_top=353.09 within +25% of entry=327.36
    VRNS 2021-08-02 prior_top=71.50 within +25% of entry=61.38
    UAA 2021-11-22 prior_top=32.99 within +25% of entry=27.05
    TRUP 2021-11-15 prior_top=129.99 within +25% of entry=129.70
    TRNO 2022-01-24 prior_top=74.58 within +25% of entry=71.38
    THO 2021-02-16 prior_top=130.65 within +25% of entry=123.20
    SSTK 2020-09-04 prior_top=49.52 within +25% of entry=47.13
    SPB 2021-10-04 prior_top=98.59 within +25% of entry=97.90
V10 EXPECTATION 1 violations (27 skipped)
    ISEE 2022-09-30 entry_wk_close=17.94 > prior=9.44 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 30 violations
    VIRT 2021-03-18 installed_stop=24.8750 vs fill=29.3000 -> dist=0.1510 > gate=0.1500
    TXNM 2020-02-24 installed_stop=45.3408 vs fill=54.1200 -> dist=0.1622 > gate=0.1500
    TTEK 2024-02-13 installed_stop=148.4256 vs fill=175.7000 -> dist=0.1552 > gate=0.1500
    TTE 2024-04-16 installed_stop=59.8750 vs fill=71.3800 -> dist=0.1612 > gate=0.1500
    TRNO 2022-01-24 installed_stop=59.8750 vs fill=71.3800 -> dist=0.1612 > gate=0.1500
    SSD 2021-03-08 installed_stop=89.1456 vs fill=104.9500 -> dist=0.1506 > gate=0.1500
    QLYS 2021-01-20 installed_stop=106.9728 vs fill=125.8900 -> dist=0.1503 > gate=0.1500
    NVR 2022-01-07 installed_stop=4559.8750 vs fill=5465.9100 -> dist=0.1658 > gate=0.1500
    NVEE 2022-08-17 installed_stop=120.8750 vs fill=142.2700 -> dist=0.1504 > gate=0.1500
    NEE 2020-10-21 installed_stop=256.4544 vs fill=74.1700 -> dist=2.4577 > gate=0.1500
V13 INVARIANT 5 violations (1 skipped)
    SHLX 2020-01-13 entry_price=22.1100 outside 2020-01-13 bar [21.6360, 22.1050]
    MIME 2021-06-25 no bar on exit_date 2022-05-20 (nearest earlier bar: 2022-05-19)
    KD 2023-09-11 entry_price=17.3200 outside 2023-09-11 bar [16.7000, 17.3190]
    BMCH 2020-08-11 no bar on exit_date 2021-01-06 (nearest earlier bar: 2021-01-05)
    AXIA 2021-05-24 entry_price=9.9600 outside 2021-05-24 bar [9.9638, 10.1532]
V14 EXPECTATION 5 violations
    VCYT 2020-07-27 entry bar 2020-07-27 open=30.3700 low=29.3700 close=30.2400 vs stop=28.6744, exit=28.6200
    TDS 2023-09-11 entry bar 2023-09-11 open=17.8500 low=17.3700 close=17.6500 vs stop=17.1658, exit=17.0600
    GBT 2020-01-31 entry bar 2020-01-31 open=65.1000 low=61.8000 close=65.2600 vs stop=63.3735, exit=62.8100
    FLNA 2020-10-12 entry bar 2020-10-12 open=11.8900 low=11.0700 close=11.4300 vs stop=10.8755, exit=10.8100
    EXTR 2022-01-21 entry bar 2022-01-21 open=12.8100 low=12.4900 close=12.4900 vs stop=12.1943, exit=12.0900
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 3 violations
    ANIP 2024-03-11 median close 8.21 over 5786 bars (2001-07-24..2024-12-23); bar 2002-06-03 close 4.10 (+811.11% vs prior close 0.45) on volume 0
    FIT 2019-11-26 median close 6.00 over 2090 bars (2003-09-10..2021-01-19); bar 2015-06-17 close 20.00 (+127.79% vs prior close 8.78) on volume 0
    GBT 2020-01-31 median close 39.10 over 1897 bars (2007-10-09..2022-10-05); bar 2015-08-11 close 20.00 (+325.54% vs prior close 4.70) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 26 violations
    VGR 2021-12-06 LONG installed_stop 10.3471 vs screener_proxy_stop 10.0280: 3.18% tighter > 3%
    TNK 2023-11-29 LONG installed_stop 46.3872 vs screener_proxy_stop 44.4268: 4.41% tighter > 3%
    TDS 2023-09-11 LONG installed_stop 17.1648 vs screener_proxy_stop 16.0264: 7.10% tighter > 3%
    SSTK 2020-09-04 LONG installed_stop 44.4864 vs screener_proxy_stop 42.5132: 4.64% tighter > 3%
    PKG 2023-08-21 LONG installed_stop 139.8912 vs screener_proxy_stop 135.2124: 3.46% tighter > 3%
    NTRA 2020-05-26 LONG installed_stop 41.4336 vs screener_proxy_stop 38.6492: 7.20% tighter > 3%
    NSP 2019-03-05 LONG installed_stop 116.8704 vs screener_proxy_stop 112.0192: 4.33% tighter > 3%
    NCMI 2024-04-08 LONG installed_stop 4.8480 vs screener_proxy_stop 4.7012: 3.12% tighter > 3%
    MSEX 2022-04-27 LONG installed_stop 84.8750 vs screener_proxy_stop 80.5460: 5.37% tighter > 3%
    MRVL 2023-06-21 LONG installed_stop 55.8750 vs screener_proxy_stop 54.0224: 3.43% tighter > 3%
V22 EXPECTATION 20 violations (48 skipped: position has no stop-decision rows)
    ADNT 2020-02-21 no stop move for 31 weeks (2020-11-09..2021-06-18), 1 completed cycle(s) stalled; last: stop 25.38, candidate 20.66, ma 20.86, correction extreme 26.23 (extreme/ma 1.26)
    AN 2020-07-31 no stop move for 16 weeks (2020-08-04..2020-11-24), 2 completed cycle(s) stalled; last: stop 48.84, candidate 48.78, ma 49.27, correction extreme 50.52 (extreme/ma 1.03)
    ANET 2023-03-10 no stop move for 13 weeks (2023-03-13..2023-06-16), 1 completed cycle(s) stalled; last: stop 127.22, candidate 35.88, ma 36.48, correction extreme 131.68 (extreme/ma 3.61)
    BBWI 2020-07-31 no stop move for 31 weeks (2020-08-05..2021-03-12), 7 completed cycle(s) stalled; last: stop 22.92, candidate 20.38, ma 20.76, correction extreme 36.10 (extreme/ma 1.74)
    CHDN 2019-05-17 no stop move for 23 weeks (2019-06-03..2019-11-15), 1 completed cycle(s) stalled; last: stop 90.13, candidate 56.31, ma 56.88, correction extreme 113.88 (extreme/ma 2.00)
    CLX 2020-03-13 no stop move for 16 weeks (2020-03-16..2020-07-10), 1 completed cycle(s) stalled; last: stop 150.41, candidate 137.88, ma 139.40, correction extreme 161.11 (extreme/ma 1.16)
    DXCM 2019-07-05 no stop move for 55 weeks (2019-07-22..2020-08-14), 8 completed cycle(s) stalled; last: stop 133.66, candidate 92.38, ma 93.31, correction extreme 381.12 (extreme/ma 4.08)
    KLIC 2019-10-11 no stop move for 16 weeks (2019-11-05..2020-02-28), 2 completed cycle(s) stalled; last: stop 21.48, candidate 21.38, ma 21.79, correction extreme 25.07 (extreme/ma 1.15)
    MCY 2021-01-08 no stop move for 19 weeks (2021-01-20..2021-06-04), 2 completed cycle(s) stalled; last: stop 47.88, candidate 46.38, ma 47.08, correction extreme 59.09 (extreme/ma 1.26)
    MPT 2019-08-30 no stop move for 17 weeks (2019-09-04..2020-01-03), 1 completed cycle(s) stalled; last: stop 16.38, candidate 11.37, ma 11.49, correction extreme 18.94 (extreme/ma 1.65)
V23 EXPECTATION 2 violations
    SLB 2022-02-24 filled 2022-02-24 after the 2022-02-18 screen read Bearish
    ISEE 2022-09-30 filled 2022-09-30 after the 2022-09-23 screen read Bearish
