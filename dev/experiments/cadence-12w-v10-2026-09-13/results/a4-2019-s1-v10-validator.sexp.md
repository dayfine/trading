# Post-run validation report

Invariant checks failing: 3
audit join: 178/178 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 24 violations
    WES 2021-05-14 Virgin_territory but only 445 weekly bars (< 520) before entry
    ROKU 2021-07-27 Virgin_territory but only 202 weekly bars (< 520) before entry
    PLAN 2020-09-28 Virgin_territory but only 105 weekly bars (< 520) before entry
    PI 2022-08-04 Virgin_territory but only 317 weekly bars (< 520) before entry
    PFSI 2019-07-31 Virgin_territory but only 328 weekly bars (< 520) before entry
    PEN 2020-02-13 Virgin_territory but only 232 weekly bars (< 520) before entry
    PAYC 2021-08-09 Virgin_territory but only 385 weekly bars (< 520) before entry
    OMF 2019-08-14 Virgin_territory but only 307 weekly bars (< 520) before entry
    NEX 2023-07-19 Virgin_territory but only 341 weekly bars (< 520) before entry
    MGNI 2023-07-11 Virgin_territory but only 487 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 36 violations (22 skipped)
    VRNS 2021-07-21 prior_top=71.50 within +25% of entry=60.92
    TAL 2021-02-17 prior_top=89.10 within +25% of entry=85.77
    PLAB 2019-10-22 prior_top=12.78 within +25% of entry=11.71
    OSPN 2020-06-19 prior_top=25.75 within +25% of entry=25.59
    ON 2021-08-27 prior_top=45.28 within +25% of entry=44.99
    NVCR 2021-05-08 prior_top=207.63 within +25% of entry=195.97
    MZTI 2022-10-26 prior_top=179.92 within +25% of entry=178.06
    MAT 2022-02-10 prior_top=25.00 within +25% of entry=23.48
    LRN 2020-07-06 prior_top=36.46 within +25% of entry=33.17
    ISRG 2021-05-04 prior_top=291.84 within +25% of entry=282.52
V10 EXPECTATION 3 violations (22 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    BPT 2022-01-22 entry_wk_close=5.52 > prior=2.85 (spike>60%)
    AAOI 2023-07-11 entry_wk_close=9.14 > prior=4.85 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 5 violations
    ISRG 2021-05-04 installed_stop=731.2626 vs fill=282.5200 -> dist=1.5884 > gate=0.1500
    HLX 2023-07-29 installed_stop=7.8750 vs fill=9.3900 -> dist=0.1613 > gate=0.1500
    CNDT 2021-06-08 installed_stop=6.8750 vs fill=8.0900 -> dist=0.1502 > gate=0.1500
    BHRB 2022-09-20 installed_stop=2042.8750 vs fill=58.7500 -> dist=33.7723 > gate=0.1500
    BBAR 2023-02-27 installed_stop=4.3750 vs fill=5.1600 -> dist=0.1521 > gate=0.1500
V13 INVARIANT 36 violations (3 skipped)
    SPF 2019-09-07 no bar on entry_date 2019-09-07 (nearest earlier bar: 2019-09-06)
    SHEN 2020-03-28 no bar on entry_date 2020-03-28 (nearest earlier bar: 2020-03-27)
    SAFM 2022-05-28 no bar on entry_date 2022-05-28 (nearest earlier bar: 2022-05-27)
    PFSI 2019-07-31 entry_price=24.6600 outside 2019-07-31 bar [24.0000, 24.6550]
    OMF 2019-08-14 entry_price=35.9600 outside 2019-08-14 bar [37.4800, 38.2100]
    NVCR 2021-05-08 no bar on entry_date 2021-05-08 (nearest earlier bar: 2021-05-07)
    NGLOY 2020-11-30 entry_price=12.7100 outside 2020-11-30 bar [12.7092, 12.7092]
    NEX 2023-07-19 no bar on exit_date 2023-09-07 (nearest earlier bar: 2023-09-06)
    MRNA 2020-03-28 no bar on entry_date 2020-03-28 (nearest earlier bar: 2020-03-27)
    LPLA 2019-11-23 no bar on entry_date 2019-11-23 (nearest earlier bar: 2019-11-22)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
V18 EXPECTATION 6 violations
    BHRB 2022-09-20 median close 2079.95 over 5294 bars (1995-08-04..2023-12-18); bar 2003-10-07 close 2001.00 (-99.80% vs prior close 1000000.00) on volume 0
    BOKF 2021-10-20 median close 47.60 over 8133 bars (1991-09-05..2023-12-18); bar 1991-12-17 close 8.84 (+9348.18% vs prior close 0.09) on volume 0
    CYRX 2021-11-08 median close 2.00 over 4613 bars (2005-08-22..2023-12-18); bar 2010-02-05 close 9.30 (+900.00% vs prior close 0.93) on volume 0
    FLO 2020-03-09 median close 18.02 over 11033 bars (1980-03-17..2023-12-18); bar 2001-03-27 close 16.55 (+399.90% vs prior close 3.31) on volume 0
    IOVA 2020-03-24 median close 7.70 over 3316 bars (2010-10-15..2023-12-18); bar 2013-09-26 close 4.00 (+9900.00% vs prior close 0.04) on volume 0
    KBL 2020-10-08 median close 199.09 over 3819 bars (1998-01-29..2022-03-02); bar 2012-01-09 close 165.81 (+481.17% vs prior close 28.53) on volume 0
