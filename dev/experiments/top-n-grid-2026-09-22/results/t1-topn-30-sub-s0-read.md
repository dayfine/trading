# t1-topn-30-sub s0 vs a0-pit-null-sub s0 — paired read (paired.sh, join symbol|entry_date)

arm 20.42 % / 264 / maxDD 43.74 / Calmar 0.062 vs null 34.39 % / 270 / 43.43 / 0.099; V6 diff exit 0.

```
shared:    n=205 pnl=$63653 (null pnl) / $105121 (arm pnl)
null-only: n=65 pnl=$60017
arm-only:  n=59 pnl=$-96357
first divergence (earliest entry present in only one arm): 2020-09-19
--- per entry-year realised: year null_n null_pnl arm_n arm_pnl
2019 30 $15593 30 $15593
2020 48 $670450 49 $503707
2021 36 $-85608 35 $-43346
2022 37 $-268181 39 $-276135
2023 48 $-114433 46 $-27322
2024 38 $-30373 35 $-105533
2025 33 $-63779 30 $-58201
--- arm-only cohort by entry-year: year n pnl winners>=+20% losers
2020 3 $-28587 0 3
2021 13 $-54593 1 11
2022 11 $-81271 0 9
2023 12 $27297 1 7
2024 10 $7233 1 6
2025 10 $33565 1 5
--- null-only cohort by entry-year: year n pnl winners>=+20% losers
2020 2 $138378 1 0
2021 14 $-96739 0 11
2022 9 $-55046 0 7
2023 14 $-54464 1 11
2024 13 $89235 2 5
2025 13 $38653 2 8
--- arm-only top winners / losers
  arm-winner KGC|2024-04-20 $58980
  arm-winner IRM|2021-02-24 $37055
  arm-winner ORCL|2025-06-14 $31059
  arm-winner X|2023-09-19 $27698
  arm-winner IT|2023-11-03 $24964
  arm-winner CRMT|2021-02-08 $24685
  arm-loser CMBT|2024-05-20 $-33490
  arm-loser SIRI|2023-07-22 $-19823
  arm-loser LPG|2022-11-12 $-18828
  arm-loser UUUU|2021-10-13 $-18622
  arm-loser NAT|2022-11-22 $-17590
  arm-loser WIX|2021-04-28 $-16061
```
