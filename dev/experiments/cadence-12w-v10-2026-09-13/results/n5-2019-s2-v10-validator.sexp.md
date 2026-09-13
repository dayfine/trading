# Post-run validation report

Invariant checks failing: 3
audit join: 181/181 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 26 violations
    ZS 2020-05-29 Virgin_territory but only 117 weekly bars (< 520) before entry
    WES 2021-05-14 Virgin_territory but only 445 weekly bars (< 520) before entry
    VERI 2020-06-02 Virgin_territory but only 162 weekly bars (< 520) before entry
    TWST 2020-05-06 Virgin_territory but only 81 weekly bars (< 520) before entry
    SHAK 2019-06-28 Virgin_territory but only 231 weekly bars (< 520) before entry
    ROKU 2021-07-27 Virgin_territory but only 202 weekly bars (< 520) before entry
    PI 2022-08-04 Virgin_territory but only 317 weekly bars (< 520) before entry
    PETQ 2021-04-26 Virgin_territory but only 199 weekly bars (< 520) before entry
    PAYC 2021-08-09 Virgin_territory but only 385 weekly bars (< 520) before entry
    PANW 2020-07-13 Virgin_territory but only 422 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 41 violations (21 skipped)
    WOLF_old2 2021-11-20 prior_top=139.55 within +25% of entry=130.94
    VRNS 2021-07-21 prior_top=71.50 within +25% of entry=60.99
    PEN 2019-06-15 prior_top=166.83 within +25% of entry=163.60
    OSPN 2020-06-19 prior_top=25.75 within +25% of entry=25.59
    ON 2021-08-27 prior_top=45.28 within +25% of entry=44.86
    NVCR 2021-05-08 prior_top=207.63 within +25% of entry=195.74
    NKE 2021-09-24 prior_top=159.03 within +25% of entry=151.04
    MZTI 2022-10-26 prior_top=179.92 within +25% of entry=178.32
    MRNA 2020-03-28 prior_top=30.05 within +25% of entry=30.01
    LRN 2020-07-06 prior_top=36.46 within +25% of entry=33.39
V10 EXPECTATION 5 violations (21 skipped)
    VERI 2020-06-02 entry_wk_close=11.16 > prior=5.93 (spike>60%)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    GGAL 2023-01-12 entry_wk_close=10.58 > prior=6.23 (spike>60%)
    BPT 2022-01-22 entry_wk_close=5.52 > prior=2.85 (spike>60%)
    APPS 2020-06-13 entry_wk_close=10.38 > prior=5.82 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 1 violations
    DAR 2022-04-20 installed_stop=73.4880 vs fill=86.4900 -> dist=0.1503 > gate=0.1500
V13 INVARIANT 38 violations (1 skipped)
    WOLF_old2 2021-11-20 no bar on entry_date 2021-11-20 (nearest earlier bar: 2021-11-19)
    TDS 2023-08-26 no bar on entry_date 2023-08-26 (nearest earlier bar: 2023-08-25)
    SPF 2019-09-07 no bar on entry_date 2019-09-07 (nearest earlier bar: 2019-09-06)
    SHEN 2020-03-28 no bar on entry_date 2020-03-28 (nearest earlier bar: 2020-03-27)
    PEN 2019-06-15 no bar on entry_date 2019-06-15 (nearest earlier bar: 2019-06-14)
    OR 2021-05-15 no bar on entry_date 2021-05-15 (nearest earlier bar: 2021-05-14)
    NXGN 2023-09-28 no bar on exit_date 2023-11-15 (nearest earlier bar: 2023-11-14)
    NVCR 2021-05-08 no bar on entry_date 2021-05-08 (nearest earlier bar: 2021-05-07)
    NINE 2022-04-02 no bar on entry_date 2022-04-02 (nearest earlier bar: 2022-04-01)
    MRNA 2020-03-28 no bar on entry_date 2020-03-28 (nearest earlier bar: 2020-03-27)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 6 violations
    BHRB 2022-09-20 median close 2075.00 over 5297 bars (1995-08-04..2023-12-21); bar 2003-10-07 close 2001.00 (-99.80% vs prior close 1000000.00) on volume 0
    BOKF 2021-10-20 median close 47.61 over 8136 bars (1991-09-05..2023-12-21); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    FLO 2020-03-09 median close 18.04 over 11036 bars (1980-03-17..2023-12-21); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    IOVA 2020-03-24 median close 7.70 over 3319 bars (2010-10-15..2023-12-21); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0
    KBL 2020-10-08 median close 199.09 over 3819 bars (1998-01-29..2022-03-02); bar 2012-01-09 close 165.81 (+481.17% vs prior close 28.53) on volume 0
    NXGN 2023-09-28 median close 12.92 over 7854 bars (1990-01-02..2023-11-20); bar 2023-11-20 close 0.00 (-100.00% vs prior close 23.94) on volume 0
