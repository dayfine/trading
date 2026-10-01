# Post-run validation report

Invariant checks failing: 3
audit join: 230/230 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS (share-class map: /workspaces/trading-1/.claude/worktrees/sweep-trader/trading/test_data/share_classes.sexp)
V7 INVARIANT 21 violations
    VVV 2021-10-13 Virgin_territory but only 266 weekly bars (< 520) before entry
    TW 2025-03-18 Virgin_territory but only 313 weekly bars (< 520) before entry
    SNDX 2023-01-12 Virgin_territory but only 360 weekly bars (< 520) before entry
    SKWD 2025-04-23 Virgin_territory but only 120 weekly bars (< 520) before entry
    PANW 2021-07-29 Virgin_territory but only 476 weekly bars (< 520) before entry
    NXE 2022-04-13 Virgin_territory but only 456 weekly bars (< 520) before entry
    NEXT 2025-01-16 Virgin_territory but only 469 weekly bars (< 520) before entry
    MIRM 2022-08-05 Virgin_territory but only 160 weekly bars (< 520) before entry
    LQDA 2023-06-02 Virgin_territory but only 255 weekly bars (< 520) before entry
    LIDR 2025-07-25 Virgin_territory but only 237 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 45 violations (18 skipped)
    UTHR 2022-06-02 prior_top=235.83 within +25% of entry=223.86
    TEAM 2021-06-28 prior_top=266.56 within +25% of entry=265.22
    SWX 2025-11-24 prior_top=81.18 within +25% of entry=81.00
    SPB 2021-10-04 prior_top=98.59 within +25% of entry=97.90
    RELX 2025-05-13 prior_top=52.71 within +25% of entry=52.25
    PSMT 2024-05-13 prior_top=93.93 within +25% of entry=85.60
    PRGS 2021-09-28 prior_top=51.02 within +25% of entry=50.46
    OLLI 2025-01-03 prior_top=117.91 within +25% of entry=107.61
    NMM 2024-09-18 prior_top=55.67 within +25% of entry=55.18
    NABL 2024-07-01 prior_top=15.52 within +25% of entry=15.24
V10 EXPECTATION 5 violations (18 skipped)
    LIDR 2025-07-25 entry_wk_close=4.43 > prior=0.90 (spike>60%)
    HIMX 2026-05-08 entry_wk_close=17.48 > prior=9.05 (spike>60%)
    DADA 2023-01-10 entry_wk_close=14.00 > prior=7.86 (spike>60%)
    APLD 2025-06-10 entry_wk_close=11.18 > prior=6.83 (spike>60%)
    ALEC 2021-07-02 entry_wk_close=35.21 > prior=19.54 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 3 violations
    VLN 2026-05-26 installed_stop=2.9136 vs fill=3.4300 -> dist=0.1506 > gate=0.1500
    DAR 2022-04-20 installed_stop=73.4880 vs fill=86.5100 -> dist=0.1505 > gate=0.1500
    APG 2021-08-24 installed_stop=19.8750 vs fill=23.4000 -> dist=0.1506 > gate=0.1500
V13 INVARIANT 6 violations
    SKWD 2025-04-23 exit_price=53.6200 outside 2025-04-24 bar [53.6250, 54.8000]
    DSNKY 2024-06-06 entry_price=37.0000 outside 2024-06-06 bar [37.0030, 37.0030]
    CODYY 2025-06-30 entry_price=23.3900 outside 2025-06-30 bar [23.3920, 23.3920]
    CHGCY 2025-06-09 entry_price=26.8400 outside 2025-06-09 bar [26.8410, 26.8410]
    ABMD 2022-11-21 no bar on exit_date 2022-12-26 (nearest earlier bar: 2022-12-23)
    AAGIY 2023-01-04 entry_price=46.7300 outside 2023-01-04 bar [46.7310, 46.7310]
V14 EXPECTATION 18 violations
    SKWD 2025-04-23 entry bar 2025-04-23 open=56.0600 low=54.7200 close=54.8400 vs stop=53.6550, exit=53.6200
    SDA 2023-07-12 entry bar 2023-07-12 open=14.1500 low=11.5500 close=11.7000 vs stop=10.4919, exit=10.4400
    QFIN 2023-01-09 entry bar 2023-01-09 open=24.0000 low=23.2300 close=23.4900 vs stop=22.8480, exit=22.8100
    PIPR 2023-12-06 entry bar 2023-12-06 open=161.4900 low=156.8300 close=157.3500 vs stop=156.4954, exit=156.3400
    NXE 2022-04-13 entry bar 2022-04-13 open=6.3000 low=6.2820 close=6.3300 vs stop=6.2666, exit=6.2200
    NCNO 2024-03-28 entry bar 2024-03-28 open=36.0000 low=35.8700 close=37.3800 vs stop=35.9471, exit=35.9300
    GFI 2023-05-04 entry bar 2023-05-04 open=17.2000 low=17.0600 close=17.4000 vs stop=16.3762, exit=16.1600
    GENI 2025-07-21 entry bar 2025-07-21 open=11.7400 low=10.9650 close=11.0800 vs stop=10.8752, exit=10.8200
    FHN 2023-03-10 entry bar 2023-03-10 open=20.3300 low=19.5300 close=20.1000 vs stop=18.7675, exit=18.8700
    EVER 2025-03-17 entry bar 2025-03-17 open=26.4400 low=26.1100 close=28.0500 vs stop=26.8742, exit=26.7800
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 3 violations
    APLS 2021-06-16 median close 32.85 over 2155 bars (2017-11-09..2026-06-09); bar 2026-05-11 close 3.58 (-91.26% vs prior close 41.03) on volume 0
    CECO 2026-05-05 median close 4.59 over 11472 bars (1980-12-02..2026-06-09); bar 1992-09-29 close 2.66 (+399.96% vs prior close 0.53) on volume 0
    FERG 2023-12-13 median close 69.61 over 4398 bars (2001-07-20..2026-06-09); bar 2001-10-22 close 60.37 (-97.71% vs prior close 2641.96) on volume 0
V19 INVARIANT PASS
V20 INVARIANT PASS
V21 EXPECTATION 181 violations
    YUM 2022-01-03 LONG installed_stop 130.9920 vs screener_proxy_stop 125.5340: 4.35% tighter > 3%
    WEC 2025-08-04 LONG installed_stop 106.8750 vs screener_proxy_stop 102.6352: 4.13% tighter > 3%
    WCN 2023-12-13 LONG installed_stop 142.9824 vs screener_proxy_stop 137.0248: 4.35% tighter > 3%
    VVV 2021-10-13 LONG installed_stop 33.4272 vs screener_proxy_stop 32.0344: 4.35% tighter > 3%
    VEON 2025-08-11 LONG installed_stop 56.2464 vs screener_proxy_stop 53.9028: 4.35% tighter > 3%
    UTHR 2022-06-02 LONG installed_stop 210.6912 vs screener_proxy_stop 201.9124: 4.35% tighter > 3%
    UGP 2023-11-01 LONG installed_stop 3.9648 vs screener_proxy_stop 3.7996: 4.35% tighter > 3%
    UBSI 2024-11-25 LONG installed_stop 42.3750 vs screener_proxy_stop 40.8204: 3.81% tighter > 3%
    TW 2025-03-18 LONG installed_stop 136.7040 vs screener_proxy_stop 131.0080: 4.35% tighter > 3%
    TTE 2022-06-07 LONG installed_stop 57.9264 vs screener_proxy_stop 55.5128: 4.35% tighter > 3%
V22 EXPECTATION 3 violations (153 skipped: position has no stop-decision rows)
    CELH 2023-05-12 no stop move for 18 weeks (2023-05-26..2023-10-05), 3 completed cycle(s) stalled; last: stop 117.94, candidate 55.24, ma 55.80, correction extreme 167.16 (extreme/ma 3.00)
    CRWD 2023-09-01 no stop move for 22 weeks (2023-11-10..2024-04-15), 2 completed cycle(s) stalled; last: stop 188.42, candidate 61.32, ma 61.94, correction extreme 238.61 (extreme/ma 3.85)
    VVV 2021-09-24 no stop move for 14 weeks (2021-10-13..2022-01-20), 1 completed cycle(s) stalled; last: stop 33.43, candidate 33.24, ma 34.98, correction extreme 33.58 (extreme/ma 0.96)
V23 EXPECTATION 8 violations
    TTE 2022-06-07 filled 2022-06-07 after the 2022-06-03 screen read Bearish
    STN 2025-05-01 filled 2025-05-01 after the 2025-04-25 screen read Bearish
    SKWD 2025-04-23 filled 2025-04-23 after the 2025-04-11 screen read Bearish
    REGN 2022-10-13 filled 2022-10-13 after the 2022-10-07 screen read Bearish
    DEN 2022-10-05 filled 2022-10-05 after the 2022-09-30 screen read Bearish
    CIB 2022-03-02 filled 2022-03-02 after the 2022-02-25 screen read Bearish
    BSM 2022-10-06 filled 2022-10-06 after the 2022-09-30 screen read Bearish
    ARGX 2022-06-21 filled 2022-06-21 after the 2022-06-17 screen read Bearish
