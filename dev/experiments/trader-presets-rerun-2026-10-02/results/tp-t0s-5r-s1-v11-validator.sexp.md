# Post-run validation report

Invariant checks failing: 3
audit join: 225/225 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-trader-rerun/trading/test_data/share_classes.sexp)
V7 INVARIANT 21 violations
    XENE 2023-05-04 Virgin_territory but only 446 weekly bars (< 520) before entry
    VVV 2021-10-13 Virgin_territory but only 266 weekly bars (< 520) before entry
    TW 2025-03-18 Virgin_territory but only 313 weekly bars (< 520) before entry
    SNDX 2023-01-12 Virgin_territory but only 360 weekly bars (< 520) before entry
    SKWD 2025-04-23 Virgin_territory but only 120 weekly bars (< 520) before entry
    PANW 2021-07-29 Virgin_territory but only 476 weekly bars (< 520) before entry
    NEXT 2025-01-16 Virgin_territory but only 469 weekly bars (< 520) before entry
    MIRM 2022-08-05 Virgin_territory but only 160 weekly bars (< 520) before entry
    LQDA 2023-06-02 Virgin_territory but only 255 weekly bars (< 520) before entry
    LI 2023-07-28 Virgin_territory but only 156 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 45 violations (19 skipped)
    VNOM 2022-02-18 prior_top=26.35 within +25% of entry=25.96
    UTHR 2022-06-02 prior_top=235.83 within +25% of entry=223.86
    TW 2024-02-05 prior_top=98.25 within +25% of entry=97.68
    TEAM 2021-06-28 prior_top=266.56 within +25% of entry=265.22
    STE 2025-12-02 prior_top=264.82 within +25% of entry=259.36
    SPB 2021-10-04 prior_top=98.59 within +25% of entry=97.78
    SLB 2026-04-20 prior_top=56.37 within +25% of entry=52.71
    SAP 2023-09-07 prior_top=150.79 within +25% of entry=139.97
    RELX 2025-05-13 prior_top=52.71 within +25% of entry=52.28
    PTGX 2025-06-02 prior_top=54.78 within +25% of entry=49.19
V10 EXPECTATION 6 violations (19 skipped)
    HIMX 2026-05-08 entry_wk_close=17.48 > prior=9.05 (spike>60%)
    FCEL 2026-05-01 entry_wk_close=13.31 > prior=6.60 (spike>60%)
    DGXX 2025-11-07 entry_wk_close=5.07 > prior=3.05 (spike>60%)
    DADA 2023-01-10 entry_wk_close=14.00 > prior=7.86 (spike>60%)
    ARTV 2026-04-16 entry_wk_close=12.55 > prior=5.32 (spike>60%)
    ALEC 2021-07-02 entry_wk_close=35.21 > prior=19.54 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 3 violations
    FWONK 2025-10-06 installed_stop=90.7891 vs fill=106.8700 -> dist=0.1505 > gate=0.1500
    ASPN 2024-03-11 installed_stop=14.8750 vs fill=17.5600 -> dist=0.1529 > gate=0.1500
    APG 2021-08-24 installed_stop=19.8750 vs fill=23.4000 -> dist=0.1506 > gate=0.1500
V13 INVARIANT 6 violations
    SKWD 2025-04-23 exit_price=53.6200 outside 2025-04-24 bar [53.6250, 54.8000]
    DSNKY 2024-06-06 entry_price=37.0000 outside 2024-06-06 bar [37.0030, 37.0030]
    CODYY 2025-06-30 entry_price=23.3900 outside 2025-06-30 bar [23.3920, 23.3920]
    CHGCY 2025-06-09 entry_price=26.8400 outside 2025-06-09 bar [26.8410, 26.8410]
    ABMD 2022-11-21 no bar on exit_date 2022-12-26 (nearest earlier bar: 2022-12-23)
    AAGIY 2023-01-04 entry_price=46.7300 outside 2023-01-04 bar [46.7310, 46.7310]
V14 EXPECTATION 12 violations
    SKWD 2025-04-23 entry bar 2025-04-23 open=56.0600 low=54.7200 close=54.8400 vs stop=53.6550, exit=53.6200
    QFIN 2023-01-09 entry bar 2023-01-09 open=24.0000 low=23.2300 close=23.4900 vs stop=22.8480, exit=22.8100
    PIPR 2023-12-06 entry bar 2023-12-06 open=161.4900 low=156.8300 close=157.3500 vs stop=156.4916, exit=156.4700
    NCNO 2024-03-28 entry bar 2024-03-28 open=36.0000 low=35.8700 close=37.3800 vs stop=35.9433, exit=35.7200
    GENI 2025-07-21 entry bar 2025-07-21 open=11.7400 low=10.9650 close=11.0800 vs stop=10.8752, exit=10.4100
    EVER 2025-03-17 entry bar 2025-03-17 open=26.4400 low=26.1100 close=28.0500 vs stop=26.8742, exit=26.8400
    DTEGY 2025-10-29 entry bar 2025-10-29 open=33.6900 low=32.6400 close=32.7100 vs stop=28.1249, exit=31.6700
    DADA 2023-01-10 entry bar 2023-01-10 open=12.2600 low=12.1600 close=13.8100 vs stop=12.8712, exit=12.8300
    CAAP 2025-10-29 entry bar 2025-10-29 open=21.9800 low=21.9200 close=22.0300 vs stop=21.3511, exit=21.6900
    BJRI 2025-02-25 entry bar 2025-02-25 open=38.2000 low=37.8600 close=38.6300 vs stop=37.5012, exit=37.4900
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 4 violations
    AEL 2022-12-20 median close 16.73 over 5139 bars (2003-12-04..2024-05-14); bar 2024-05-13 close 0.00 (-100.00% vs prior close 56.47) on volume 0
    APLS 2021-06-16 median close 32.74 over 2161 bars (2017-11-09..2026-06-17); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0
    CECO 2026-05-05 median close 4.62 over 11478 bars (1980-12-02..2026-06-17); bar 1992-09-29 close 2.66 (+399.96% vs prior close 0.53) on volume 0
    FERG 2023-12-13 median close 69.80 over 4404 bars (2001-07-20..2026-06-17); bar 2001-10-22 close 60.37 (-97.71% vs prior close 2641.96) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 172 violations
    ZYME 2025-11-19 LONG installed_stop 20.6880 vs screener_proxy_stop 19.8260: 4.35% tighter > 3%
    XENE 2023-05-04 LONG installed_stop 39.9360 vs screener_proxy_stop 38.2720: 4.35% tighter > 3%
    WEC 2025-08-04 LONG installed_stop 106.8750 vs screener_proxy_stop 102.6352: 4.13% tighter > 3%
    WCN 2023-12-13 LONG installed_stop 142.9824 vs screener_proxy_stop 137.0248: 4.35% tighter > 3%
    VVV 2021-10-13 LONG installed_stop 33.4272 vs screener_proxy_stop 32.0344: 4.35% tighter > 3%
    VNOM 2022-02-18 LONG installed_stop 24.4320 vs screener_proxy_stop 23.4140: 4.35% tighter > 3%
    VEON 2025-08-11 LONG installed_stop 56.2464 vs screener_proxy_stop 53.9028: 4.35% tighter > 3%
    UTHR 2022-06-02 LONG installed_stop 210.6912 vs screener_proxy_stop 201.9124: 4.35% tighter > 3%
    UGP 2023-11-01 LONG installed_stop 3.9648 vs screener_proxy_stop 3.7996: 4.35% tighter > 3%
    UBSI 2024-11-25 LONG installed_stop 42.3750 vs screener_proxy_stop 40.8204: 3.81% tighter > 3%
V22 EXPECTATION 8 violations (152 skipped: position has no stop-decision rows)
    ACA 2023-03-03 no stop move for 14 weeks (2023-04-28..2023-08-04), 2 completed cycle(s) stalled; last: stop 63.48, candidate 62.88, ma 63.67, correction extreme 65.36 (extreme/ma 1.03)
    ARGX 2022-04-08 no stop move for 13 weeks (2022-06-21..2022-09-22), 2 completed cycle(s) stalled; last: stop 344.22, candidate 338.70, ma 342.12, correction extreme 345.57 (extreme/ma 1.01)
    BMA 2023-12-08 no stop move for 13 weeks (2023-12-12..2024-03-15), 4 completed cycle(s) stalled; last: stop 24.38, candidate 24.22, ma 24.46, correction extreme 34.64 (extreme/ma 1.42)
    CELH 2023-05-12 no stop move for 18 weeks (2023-05-26..2023-10-05), 3 completed cycle(s) stalled; last: stop 117.94, candidate 46.86, ma 47.34, correction extreme 167.16 (extreme/ma 3.53)
    CRWD 2023-09-08 no stop move for 22 weeks (2023-11-10..2024-04-15), 2 completed cycle(s) stalled; last: stop 188.42, candidate 51.23, ma 51.75, correction extreme 238.61 (extreme/ma 4.61)
    HSY 2021-12-10 no stop move for 22 weeks (2021-12-13..2022-05-19), 1 completed cycle(s) stalled; last: stop 176.28, candidate 164.44, ma 166.10, correction extreme 185.17 (extreme/ma 1.11)
    MFC 2024-09-06 no stop move for 14 weeks (2024-09-11..2024-12-23), 2 completed cycle(s) stalled; last: stop 26.38, candidate 26.20, ma 26.46, correction extreme 29.07 (extreme/ma 1.10)
    VVV 2021-09-24 no stop move for 14 weeks (2021-10-13..2022-01-20), 1 completed cycle(s) stalled; last: stop 33.43, candidate 32.84, ma 33.18, correction extreme 33.58 (extreme/ma 1.01)
V23 EXPECTATION 7 violations
    TTE 2022-06-07 filled 2022-06-07 after the 2022-06-03 screen read Bearish
    STN 2025-05-01 filled 2025-05-01 after the 2025-04-25 screen read Bearish
    SKWD 2025-04-23 filled 2025-04-23 after the 2025-04-11 screen read Bearish
    DEN 2022-10-05 filled 2022-10-05 after the 2022-09-30 screen read Bearish
    CIB 2022-03-02 filled 2022-03-02 after the 2022-02-25 screen read Bearish
    BSM 2022-10-06 filled 2022-10-06 after the 2022-09-30 screen read Bearish
    ARGX 2022-06-21 filled 2022-06-21 after the 2022-06-17 screen read Bearish
