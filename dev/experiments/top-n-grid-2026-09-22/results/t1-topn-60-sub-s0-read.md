# t1-topn-60-sub s0 vs a0-pit-null-sub s0 — paired read (paired.sh, join symbol|entry_date)

arm 60.19 % / 267 / maxDD 49.98 / Calmar 0.139 vs null 34.39 % / 270 / 43.43 / 0.099; V6 diff exit 0.

```
shared:    n=193 pnl=$-34979 (null pnl) / $42598 (arm pnl)
null-only: n=77 pnl=$158648
arm-only:  n=74 pnl=$213856
first divergence (earliest entry present in only one arm): 2019-06-10
--- per entry-year realised: year null_n null_pnl arm_n arm_pnl
2019 30 $15593 28 $39986
2020 48 $670450 49 $436389
2021 36 $-85608 45 $-134061
2022 37 $-268181 41 $-262218
2023 48 $-114433 51 $216969
2024 38 $-30373 23 $78090
2025 33 $-63779 30 $-118699
--- arm-only cohort by entry-year: year n pnl winners>=+20% losers
2019 4 $-14063 0 2
2020 13 $-13551 1 10
2021 18 $-61851 0 14
2022 10 $-88210 0 9
2023 8 $336183 2 4
2024 9 $130996 2 4
2025 12 $-75648 1 9
--- null-only cohort by entry-year: year n pnl winners>=+20% losers
2019 6 $-38666 0 6
2020 12 $215147 2 5
2021 9 $-6817 0 5
2022 6 $-55295 0 5
2023 5 $28305 2 3
2024 24 $34204 2 12
2025 15 $-18229 1 10
--- arm-only top winners / losers
  arm-winner ADMA|2023-12-19 $302929
  arm-winner CVNA|2024-07-08 $86534
  arm-winner KOD|2020-10-22 $79873
  arm-winner BMA|2023-12-18 $62282
  arm-winner KGC|2024-04-20 $51430
  arm-winner HRTG|2025-04-14 $35969
  arm-loser AD|2025-07-28 $-50335
  arm-loser TNI|2019-06-10 $-19801
  arm-loser MTH|2021-12-06 $-18426
  arm-loser ADTN|2022-08-15 $-18343
  arm-loser INO|2020-07-29 $-18018
  arm-loser FIHL|2024-11-21 $-17645
```
