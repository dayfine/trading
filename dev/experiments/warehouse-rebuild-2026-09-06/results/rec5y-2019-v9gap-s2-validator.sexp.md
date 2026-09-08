# Post-run validation report

Invariant checks failing: 4
audit join: 179/179 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT 2 violations
    CMBT 2019-10-07 twin positions: CMBT/EURN
    ELME 2020-02-13 twin positions: ELME/WRE
V7 INVARIANT 25 violations
    ZS 2020-05-29 Virgin_territory but only 117 weekly bars (< 520) before entry
    TWST 2020-05-06 Virgin_territory but only 81 weekly bars (< 520) before entry
    SHAK 2019-06-28 Virgin_territory but only 231 weekly bars (< 520) before entry
    SC 2021-03-12 Virgin_territory but only 375 weekly bars (< 520) before entry
    ROKU 2021-07-27 Virgin_territory but only 202 weekly bars (< 520) before entry
    PI 2022-08-04 Virgin_territory but only 317 weekly bars (< 520) before entry
    PCRX 2020-07-02 Virgin_territory but only 496 weekly bars (< 520) before entry
    PAYC 2021-08-09 Virgin_territory but only 385 weekly bars (< 520) before entry
    LGIH 2020-02-06 Virgin_territory but only 330 weekly bars (< 520) before entry
    KNSL 2022-08-05 Virgin_territory but only 316 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 40 violations (23 skipped)
    VRNS 2021-07-21 prior_top=71.50 within +25% of entry=60.99
    TNET 2021-12-20 prior_top=104.23 within +25% of entry=89.80
    PEN 2019-06-15 prior_top=166.83 within +25% of entry=163.60
    OSPN 2020-06-19 prior_top=25.75 within +25% of entry=25.59
    ON 2021-08-27 prior_top=45.28 within +25% of entry=44.86
    NVCR 2021-05-08 prior_top=207.63 within +25% of entry=195.74
    NKE 2021-09-24 prior_top=159.03 within +25% of entry=151.04
    MZTI 2022-10-26 prior_top=179.92 within +25% of entry=178.32
    MRNA 2020-03-28 prior_top=30.05 within +25% of entry=30.01
    MAT 2022-02-10 prior_top=25.00 within +25% of entry=23.48
V10 EXPECTATION 3 violations (23 skipped)
    STMP 2021-07-30 entry_wk_close=326.76 > prior=199.19 (spike>60%)
    GGAL 2023-01-12 entry_wk_close=10.58 > prior=6.23 (spike>60%)
    BPT 2022-01-22 entry_wk_close=5.52 > prior=2.85 (spike>60%)
V11 EXPECTATION PASS
V12 INVARIANT 2 violations
    QLYS 2021-01-20 installed_stop=106.9728 vs fill=125.9600 -> dist=0.1507 > gate=0.1500
    MCK 2020-05-28 installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500
V13 INVARIANT 36 violations (1 skipped)
    UPS 2021-04-17 no bar on entry_date 2021-04-17 (nearest earlier bar: 2021-04-16)
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
