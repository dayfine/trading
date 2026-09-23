# t1-topn-40-sub s0 vs a0-pit-null-sub s0 — paired read (paired.sh, join symbol|entry_date)

arm 50.74 % / 273 / maxDD 43.72 / Calmar 0.138 vs null 34.39 % / 270 / 43.43 / 0.099; V6 diff exit 0.

```
shared:    n=197 pnl=$-117066 (null pnl) / $-66331 (arm pnl)
null-only: n=73 pnl=$240735
arm-only:  n=76 pnl=$278496
first divergence (earliest entry present in only one arm): 2020-05-09
--- per entry-year realised: year null_n null_pnl arm_n arm_pnl
2019 30 $15593 30 $15345
2020 48 $670450 48 $447065
2021 36 $-85608 40 $-21017
2022 37 $-268181 37 $-268700
2023 48 $-114433 52 $224546
2024 38 $-30373 28 $-71581
2025 33 $-63779 38 $-113493
--- arm-only cohort by entry-year: year n pnl winners>=+20% losers
2020 11 $138894 2 6
2021 20 $-31060 0 13
2022 8 $-82082 0 8
2023 6 $374998 2 2
2024 13 $-22681 1 10
2025 18 $-99574 0 13
--- null-only cohort by entry-year: year n pnl winners>=+20% losers
2020 11 $360699 3 4
2021 16 $-97683 0 13
2022 8 $-54369 0 5
2023 2 $53145 2 0
2024 23 $26284 2 12
2025 13 $-47340 1 9
--- arm-only top winners / losers
  arm-winner ADMA|2023-12-19 $327320
  arm-winner AN|2020-08-04 $118589
  arm-winner BMA|2023-12-18 $67286
  arm-winner FCNCA|2020-11-28 $58023
  arm-winner KGC|2024-04-20 $55551
  arm-winner WLY|2021-02-05 $29805
  arm-loser AD|2025-07-28 $-47138
  arm-loser BEAM|2021-07-03 $-27174
  arm-loser AG|2020-07-30 $-15914
  arm-loser UMBF|2024-07-31 $-15402
  arm-loser PSTG|2025-01-22 $-15376
  arm-loser FNB|2022-02-10 $-14616
```
