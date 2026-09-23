# t1-topn-30-sub s1 vs a0-pit-null-sub s1 — paired read (paired.sh, join symbol|entry_date)

arm 130.16 % / 263 / maxDD 40.29 / Calmar 0.314 vs null -9.54 % / 281 / 48.32 / -0.029; V6 diff exit 0.

```
shared:    n=211 pnl=$144774 (null pnl) / $27256 (arm pnl)
null-only: n=70 pnl=$-274777
arm-only:  n=52 pnl=$808114
first divergence (earliest entry present in only one arm): 2020-09-01
--- per entry-year realised: year null_n null_pnl arm_n arm_pnl
2019 30 $17012 30 $17012
2020 48 $428897 45 $651724
2021 43 $-100907 39 $-58721
2022 40 $-253022 37 $-184094
2023 48 $-86076 52 $276444
2024 39 $-90220 28 $-47834
2025 33 $-45688 32 $180840
--- arm-only cohort by entry-year: year n pnl winners>=+20% losers
2020 4 $166536 2 1
2021 8 $-24564 0 6
2022 6 $43873 1 4
2023 8 $441429 2 4
2024 12 $23268 1 8
2025 14 $157572 2 8
--- null-only cohort by entry-year: year n pnl winners>=+20% losers
2020 7 $-57692 0 6
2021 12 $-80686 0 11
2022 9 $-80738 0 8
2023 4 $37683 2 2
2024 23 $-34970 1 16
2025 15 $-58375 0 11
--- arm-only top winners / losers
  arm-winner ADMA|2023-12-19 $398873
  arm-winner TMQ|2025-09-11 $160710
  arm-winner GLNG|2022-01-31 $127499
  arm-winner GME|2020-09-14 $95765
  arm-winner BMA|2023-12-18 $82037
  arm-winner KGC|2024-04-20 $67570
  arm-loser MIRM|2022-08-05 $-42102
  arm-loser LPG|2022-11-12 $-22585
  arm-loser FIHL|2024-11-21 $-21661
  arm-loser UMBF|2024-07-31 $-18785
  arm-loser ANAB|2024-07-25 $-17658
  arm-loser DAR|2022-04-20 $-17477
```
