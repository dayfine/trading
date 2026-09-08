# Post-run validation report

Invariant checks failing: 3
audit join: 181/181 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT 1 violations
    LANC 2022-10-26 twin positions: LANC/MZTI
V7 INVARIANT 23 violations
    WES 2021-05-14 Virgin_territory but only 445 weekly bars (< 520) before entry
    SSTK 2020-08-04 Virgin_territory but only 413 weekly bars (< 520) before entry
    SFM 2023-03-02 Virgin_territory but only 504 weekly bars (< 520) before entry
    ROKU 2021-07-27 Virgin_territory but only 202 weekly bars (< 520) before entry
    PI 2022-08-04 Virgin_territory but only 317 weekly bars (< 520) before entry
    PCRX 2020-07-02 Virgin_territory but only 496 weekly bars (< 520) before entry
    PAYC 2021-08-09 Virgin_territory but only 385 weekly bars (< 520) before entry
    PANW 2020-07-13 Virgin_territory but only 422 weekly bars (< 520) before entry
    OMF 2019-08-14 Virgin_territory but only 307 weekly bars (< 520) before entry
    MGNI 2023-07-11 Virgin_territory but only 487 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 33 violations (27 skipped)
    WOLF_old2 2021-11-20 prior_top=139.55 within +25% of entry=130.58
    VRNS 2021-07-21 prior_top=71.50 within +25% of entry=60.92
    VICR 2021-07-03 prior_top=107.97 within +25% of entry=107.30
    RDWR 2020-12-22 prior_top=28.14 within +25% of entry=27.18
    PSTG 2023-10-20 prior_top=39.10 within +25% of entry=33.26
    PEN 2019-06-15 prior_top=166.83 within +25% of entry=163.60
    OSPN 2020-06-19 prior_top=25.75 within +25% of entry=25.59
    ON 2021-08-27 prior_top=45.28 within +25% of entry=44.99
    NVCR 2021-05-08 prior_top=207.63 within +25% of entry=195.97
    NKE 2021-09-24 prior_top=159.03 within +25% of entry=151.04
V10 EXPECTATION 3 violations (27 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    GGAL 2023-01-12 entry_wk_close=10.58 > prior=6.23 (spike>60%)
    BPT 2022-01-22 entry_wk_close=5.52 > prior=2.85 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT PASS
V13 INVARIANT 33 violations (1 skipped)
    WOLF_old2 2021-11-20 no bar on entry_date 2021-11-20 (nearest earlier bar: 2021-11-19)
    VICR 2021-07-03 no bar on entry_date 2021-07-03 (nearest earlier bar: 2021-07-02)
    TDS 2023-08-26 no bar on entry_date 2023-08-26 (nearest earlier bar: 2023-08-25)
    SHEN 2020-03-28 no bar on entry_date 2020-03-28 (nearest earlier bar: 2020-03-27)
    PEN 2019-06-15 no bar on entry_date 2019-06-15 (nearest earlier bar: 2019-06-14)
    OMF 2019-08-14 entry_price=35.9600 outside 2019-08-14 bar [37.4800, 38.2100]
    NVCR 2021-05-08 no bar on entry_date 2021-05-08 (nearest earlier bar: 2021-05-07)
    NGLOY 2020-11-30 entry_price=12.7100 outside 2020-11-30 bar [12.7092, 12.7092]
    MRNA 2020-03-28 no bar on entry_date 2020-03-28 (nearest earlier bar: 2020-03-27)
    LPLA 2019-11-23 no bar on entry_date 2019-11-23 (nearest earlier bar: 2019-11-22)
V14 EXPECTATION PASS
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION PASS
