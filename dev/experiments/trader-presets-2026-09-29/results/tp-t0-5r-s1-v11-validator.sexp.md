# Post-run validation report

Invariant checks failing: 3
audit join: 232/232 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-trader/trading/test_data/share_classes.sexp)
V7 INVARIANT 26 violations
    ZIM 2024-09-27 Virgin_territory but only 191 weekly bars (< 520) before entry
    VVV 2021-10-13 Virgin_territory but only 266 weekly bars (< 520) before entry
    TW 2025-03-18 Virgin_territory but only 313 weekly bars (< 520) before entry
    SNDX 2023-01-12 Virgin_territory but only 360 weekly bars (< 520) before entry
    SKWD 2025-04-23 Virgin_territory but only 120 weekly bars (< 520) before entry
    PANW 2021-07-29 Virgin_territory but only 476 weekly bars (< 520) before entry
    NXE 2022-04-13 Virgin_territory but only 456 weekly bars (< 520) before entry
    NEXT 2025-01-16 Virgin_territory but only 469 weekly bars (< 520) before entry
    MIRM 2022-08-05 Virgin_territory but only 160 weekly bars (< 520) before entry
    LQDA 2023-06-02 Virgin_territory but only 255 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 46 violations (21 skipped)
    UTHR 2022-06-02 prior_top=235.83 within +25% of entry=223.86
    TRI 2024-06-21 prior_top=167.10 within +25% of entry=165.63
    TEAM 2021-06-28 prior_top=266.56 within +25% of entry=265.22
    SWX 2025-11-24 prior_top=81.18 within +25% of entry=81.10
    STE 2025-12-02 prior_top=264.82 within +25% of entry=259.36
    SPB 2021-10-04 prior_top=98.59 within +25% of entry=97.78
    PTGX 2025-06-02 prior_top=54.78 within +25% of entry=49.19
    PTCT 2025-09-10 prior_top=68.49 within +25% of entry=58.76
    PRGS 2021-09-28 prior_top=51.02 within +25% of entry=50.46
    OSG 2024-06-05 prior_top=22.48 within +25% of entry=18.25
V10 EXPECTATION 8 violations (21 skipped)
    LIDR 2025-07-25 entry_wk_close=4.43 > prior=0.90 (spike>60%)
    HIMX 2026-05-08 entry_wk_close=17.48 > prior=9.05 (spike>60%)
    GRPN 2025-03-26 entry_wk_close=18.82 > prior=11.12 (spike>60%)
    FCEL 2026-05-01 entry_wk_close=13.31 > prior=6.60 (spike>60%)
    DADA 2023-01-10 entry_wk_close=14.00 > prior=7.86 (spike>60%)
    ARTV 2026-04-16 entry_wk_close=12.55 > prior=5.32 (spike>60%)
    APLD 2025-06-10 entry_wk_close=11.18 > prior=6.83 (spike>60%)
    ALEC 2021-07-02 entry_wk_close=35.21 > prior=19.54 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 3 violations
    LZB 2024-07-15 installed_stop=34.3750 vs fill=40.6100 -> dist=0.1535 > gate=0.1500
    DAR 2022-04-20 installed_stop=73.4880 vs fill=86.4800 -> dist=0.1502 > gate=0.1500
    APG 2021-08-24 installed_stop=19.8750 vs fill=23.4000 -> dist=0.1506 > gate=0.1500
V13 INVARIANT 5 violations
    SKWD 2025-04-23 exit_price=53.6200 outside 2025-04-24 bar [53.6250, 54.8000]
    CODYY 2025-06-30 entry_price=23.3900 outside 2025-06-30 bar [23.3920, 23.3920]
    CHGCY 2025-06-09 entry_price=26.8400 outside 2025-06-09 bar [26.8410, 26.8410]
    ABMD 2022-11-21 no bar on exit_date 2022-12-26 (nearest earlier bar: 2022-12-23)
    AAGIY 2023-01-04 entry_price=46.7300 outside 2023-01-04 bar [46.7310, 46.7310]
V14 EXPECTATION 16 violations
    SKWD 2025-04-23 entry bar 2025-04-23 open=56.0600 low=54.7200 close=54.8400 vs stop=53.6550, exit=53.6200
    SDA 2023-07-12 entry bar 2023-07-12 open=14.1500 low=11.5500 close=11.7000 vs stop=10.4919, exit=10.4900
    QFIN 2023-01-09 entry bar 2023-01-09 open=24.0000 low=23.2300 close=23.4900 vs stop=22.8480, exit=22.8100
    PIPR 2023-12-06 entry bar 2023-12-06 open=161.4900 low=156.8300 close=157.3500 vs stop=156.4916, exit=156.4700
    NXE 2022-04-13 entry bar 2022-04-13 open=6.3000 low=6.2820 close=6.3300 vs stop=6.2687, exit=6.2400
    GFI 2023-05-04 entry bar 2023-05-04 open=17.2000 low=17.0600 close=17.4000 vs stop=16.3744, exit=16.1600
    FHN 2023-03-10 entry bar 2023-03-10 open=20.3300 low=19.5300 close=20.1000 vs stop=18.7675, exit=18.8700
    EVER 2025-03-17 entry bar 2025-03-17 open=26.4400 low=26.1100 close=28.0500 vs stop=26.8742, exit=26.8400
    DTEGY 2025-10-29 entry bar 2025-10-29 open=33.6900 low=32.6400 close=32.7100 vs stop=28.1249, exit=31.6700
    DADA 2023-01-10 entry bar 2023-01-10 open=12.2600 low=12.1600 close=13.8100 vs stop=12.8712, exit=12.8300
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 2 violations
    APLS 2021-06-16 median close 32.70 over 2166 bars (2017-11-09..2026-06-24); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0
    FERG 2023-12-13 median close 69.80 over 4408 bars (2001-07-20..2026-06-24); bar 2001-10-22 close 60.37 (-97.71% vs prior close 2641.96) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 177 violations
    ZIM 2024-09-27 LONG installed_stop 22.9824 vs screener_proxy_stop 22.0248: 4.35% tighter > 3%
    YUM 2022-01-03 LONG installed_stop 130.9920 vs screener_proxy_stop 125.5340: 4.35% tighter > 3%
    WEC 2025-08-04 LONG installed_stop 106.8750 vs screener_proxy_stop 102.6352: 4.13% tighter > 3%
    WCN 2023-12-13 LONG installed_stop 142.9824 vs screener_proxy_stop 137.0248: 4.35% tighter > 3%
    VVV 2021-10-13 LONG installed_stop 33.4272 vs screener_proxy_stop 32.0344: 4.35% tighter > 3%
    UTHR 2022-06-02 LONG installed_stop 210.6912 vs screener_proxy_stop 201.9124: 4.35% tighter > 3%
    UGP 2023-11-01 LONG installed_stop 3.9648 vs screener_proxy_stop 3.7996: 4.35% tighter > 3%
    UBSI 2024-11-25 LONG installed_stop 42.3750 vs screener_proxy_stop 40.8204: 3.81% tighter > 3%
    TW 2025-03-18 LONG installed_stop 136.7040 vs screener_proxy_stop 131.0080: 4.35% tighter > 3%
    TTE 2022-06-07 LONG installed_stop 57.9264 vs screener_proxy_stop 55.5128: 4.35% tighter > 3%
V22 EXPECTATION 3 violations (157 skipped: position has no stop-decision rows)
    CELH 2023-05-12 no stop move for 18 weeks (2023-05-26..2023-10-05), 3 completed cycle(s) stalled; last: stop 117.94, candidate 55.24, ma 55.80, correction extreme 167.16 (extreme/ma 3.00)
    CRWD 2023-09-01 no stop move for 22 weeks (2023-11-10..2024-04-15), 2 completed cycle(s) stalled; last: stop 188.42, candidate 61.32, ma 61.94, correction extreme 238.61 (extreme/ma 3.85)
    VVV 2021-09-24 no stop move for 14 weeks (2021-10-13..2022-01-20), 1 completed cycle(s) stalled; last: stop 33.43, candidate 33.24, ma 34.98, correction extreme 33.58 (extreme/ma 0.96)
V23 EXPECTATION 9 violations
    TTE 2022-06-07 filled 2022-06-07 after the 2022-06-03 screen read Bearish
    STN 2025-05-01 filled 2025-05-01 after the 2025-04-25 screen read Bearish
    SKWD 2025-04-23 filled 2025-04-23 after the 2025-04-11 screen read Bearish
    REGN 2022-10-13 filled 2022-10-13 after the 2022-10-07 screen read Bearish
    HLN 2025-05-02 filled 2025-05-02 after the 2025-04-25 screen read Bearish
    DEN 2022-10-05 filled 2022-10-05 after the 2022-09-30 screen read Bearish
    CIB 2022-03-02 filled 2022-03-02 after the 2022-02-25 screen read Bearish
    BSM 2022-10-06 filled 2022-10-06 after the 2022-09-30 screen read Bearish
    ARGX 2022-06-21 filled 2022-06-21 after the 2022-06-17 screen read Bearish
