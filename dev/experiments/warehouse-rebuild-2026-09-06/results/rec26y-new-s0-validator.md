# Post-run validation report

Invariant checks failing: 3
audit join: 715/715 rows matched

V1 INVARIANT PASS
V2 INVARIANT PASS
V3 INVARIANT PASS
V4 INVARIANT PASS
V5 INVARIANT PASS
V6 INVARIANT PASS
V7 INVARIANT 63 violations (457 skipped)
    WY 2018-01-24 Virgin_territory but only 476 weekly bars (< 520) before entry
    WFC 2013-12-18 Virgin_territory but only 260 weekly bars (< 520) before entry
    WDC 2017-04-11 Virgin_territory but only 435 weekly bars (< 520) before entry
    WAB 2005-07-21 Virgin_territory but only 0 weekly bars (< 520) before entry
    VRSN 2012-04-18 Virgin_territory but only 172 weekly bars (< 520) before entry
    TTWO 2015-07-17 Virgin_territory but only 344 weekly bars (< 520) before entry
    TSN 2007-01-29 Virgin_territory but only 0 weekly bars (< 520) before entry
    TFC 2005-11-10 Virgin_territory but only 0 weekly bars (< 520) before entry
    TDY 2017-07-25 Virgin_territory but only 450 weekly bars (< 520) before entry
    SPGI 2012-08-29 Virgin_territory but only 191 weekly bars (< 520) before entry
V8 EXPECTATION PASS
V9 EXPECTATION 31 violations (555 skipped)
    WAB 2023-07-08 prior_top=109.50 within +25% of entry=108.45
    VRTX 2014-06-28 prior_top=93.77 within +25% of entry=92.22
    VRTX 2019-11-09 prior_top=201.31 within +25% of entry=197.08
    URBN 2026-01-06 prior_top=81.84 within +25% of entry=81.27
    UHS 2018-11-19 prior_top=138.87 within +25% of entry=133.32
    TGT 2020-03-12 prior_top=109.11 within +25% of entry=92.66
    STE 2025-11-15 prior_top=262.46 within +25% of entry=259.36
    RMD 2016-06-21 prior_top=65.33 within +25% of entry=60.79
    RMD 2022-01-24 prior_top=284.32 within +25% of entry=230.06
    REGN 2012-01-28 prior_top=84.97 within +25% of entry=81.55
V10 EXPECTATION PASS (555 skipped)
V11 EXPECTATION PASS
V12 INVARIANT 16 violations
    TRN 2013-10-31 installed_stop=32.9664 vs fill=17.3100 -> dist=0.9045 > gate=0.1500
    TRMB 2003-11-24 installed_stop=25.8750 vs fill=19.6700 -> dist=0.3155 > gate=0.1500
    PH 2007-04-04 installed_stop=77.1361 vs fill=58.9800 -> dist=0.3078 > gate=0.1500
    NEOG 2017-09-05 installed_stop=60.8750 vs fill=52.4700 -> dist=0.1602 > gate=0.1500
    MNT 2005-04-15 installed_stop=31.3920 vs fill=37.4500 -> dist=0.1618 > gate=0.1500
    MMM 2003-07-26 installed_stop=131.9328 vs fill=69.6800 -> dist=0.8934 > gate=0.1500
    MCK 2020-05-28 installed_stop=132.4224 vs fill=156.7300 -> dist=0.1551 > gate=0.1500
    LRCX 2014-05-03 installed_stop=48.3750 vs fill=57.2000 -> dist=0.1543 > gate=0.1500
    KOPN 2025-07-17 installed_stop=1.8750 vs fill=2.2200 -> dist=0.1554 > gate=0.1500
    FULT 2002-03-07 installed_stop=23.3952 vs fill=19.5000 -> dist=0.1998 > gate=0.1500
V13 INVARIANT 105 violations (457 skipped)
    WDC 2003-10-02 no bar on entry_date 2003-10-02 (nearest earlier bar: none)
    WAB 2005-07-21 no bar on entry_date 2005-07-21 (nearest earlier bar: none)
    WAB 2023-07-08 no bar on entry_date 2023-07-08 (nearest earlier bar: 2023-07-07)
    VRTX 2014-06-28 no bar on entry_date 2014-06-28 (nearest earlier bar: 2014-06-27)
    VRTX 2019-11-09 no bar on entry_date 2019-11-09 (nearest earlier bar: 2019-11-08)
    URBN 2025-12-20 no bar on entry_date 2025-12-20 (nearest earlier bar: 2025-12-19)
    TTWO 2015-07-17 entry_price=31.3200 outside 2015-07-17 bar [29.9300, 31.3199]
    TSN 2007-01-29 no bar on entry_date 2007-01-29 (nearest earlier bar: none)
    TRV 2025-05-10 no bar on entry_date 2025-05-10 (nearest earlier bar: 2025-05-09)
    TRMB 2003-11-24 no bar on entry_date 2003-11-24 (nearest earlier bar: none)
V14 EXPECTATION PASS (346 skipped)
V15 EXPECTATION PASS
V16 EXPECTATION PASS
V17 EXPECTATION 5 violations (506 skipped)
    LLY 2026-06-06 entry filled 2026-06-06 but last bar is 2026-04-10 (57 days stale)
    INFY 2025-12-20 entry filled 2025-12-20 but last bar is 2025-05-16 (218 days stale)
    CP 2026-02-27 entry filled 2026-02-27 but last bar is 2025-05-16 (287 days stale)
    COST 2026-05-19 entry filled 2026-05-19 but last bar is 2026-05-01 (18 days stale)
    BP 2026-03-31 entry filled 2026-03-31 but last bar is 2025-05-16 (319 days stale)
