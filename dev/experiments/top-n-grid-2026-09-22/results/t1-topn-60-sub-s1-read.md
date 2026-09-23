# t1-topn-60-sub s1 vs a0-pit-null-sub s1 — paired read (paired.sh, join symbol|entry_date)

arm 11.44 % / 271 / maxDD 48.58 / Calmar 0.032 vs null -9.54 % / 281 / 48.32 / -0.029; V6 diff exit 0.

```
shared:    n=187 pnl=$-40923 (null pnl) / $-85132 (arm pnl)
null-only: n=94 pnl=$-89080
arm-only:  n=84 pnl=$-42075
first divergence (earliest entry present in only one arm): 2019-06-01
--- per entry-year realised: year null_n null_pnl arm_n arm_pnl
2019 30 $17012 31 $-14115
2020 48 $428897 48 $422336
2021 43 $-100907 37 $-2869
2022 40 $-253022 42 $-289154
2023 48 $-86076 47 $-70851
2024 39 $-90220 36 $-128753
2025 33 $-45688 30 $-43801
--- arm-only cohort by entry-year: year n pnl winners>=+20% losers
2019 8 $-54769 0 6
2020 12 $143609 2 8
2021 9 $-7303 0 6
2022 9 $-77593 0 8
2023 17 $5981 1 12
2024 14 $-42630 1 12
2025 15 $-9369 1 8
--- null-only cohort by entry-year: year n pnl winners>=+20% losers
2019 7 $-23345 0 6
2020 12 $126730 2 7
2021 15 $-105325 0 14
2022 7 $-51455 0 5
2023 18 $-14994 2 13
2024 17 $-9613 1 12
2025 18 $-11079 1 12
--- arm-only top winners / losers
  arm-winner SNBR|2020-10-14 $124864
  arm-winner GME|2020-09-14 $84347
  arm-winner BMA|2023-12-18 $64913
  arm-winner KGC|2024-04-20 $52191
  arm-winner AAP|2021-03-13 $31457
  arm-winner AMD|2021-07-31 $24175
  arm-loser SDA|2023-07-12 $-32867
  arm-loser TTB|2021-09-23 $-25569
  arm-loser HRMY|2022-11-26 $-22100
  arm-loser WBTN|2025-08-30 $-20210
  arm-loser TNI|2019-06-10 $-19381
  arm-loser ADTN|2022-08-15 $-19357
```
