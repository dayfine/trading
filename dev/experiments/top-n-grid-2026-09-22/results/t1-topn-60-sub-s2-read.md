# t1-topn-60-sub s2 vs a0-pit-null-sub s2 — paired read (paired.sh, join symbol|entry_date)

arm -6.68 % / 279 / maxDD 47.88 / Calmar -0.021 vs null 71.32 % / 260 / 43.77 / 0.183; V6 diff exit 0.

```
shared:    n=180 pnl=$203325 (null pnl) / $244172 (arm pnl)
null-only: n=80 pnl=$31753
arm-only:  n=99 pnl=$-334778
first divergence (earliest entry present in only one arm): 2019-06-10
--- per entry-year realised: year null_n null_pnl arm_n arm_pnl
2019 30 $17129 28 $41599
2020 48 $672403 49 $439207
2021 36 $-87819 44 $-119239
2022 37 $-276406 39 $-263597
2023 48 $-112922 46 $-99881
2024 31 $60575 35 $14193
2025 30 $-37883 38 $-102888
--- arm-only cohort by entry-year: year n pnl winners>=+20% losers
2019 4 $-13648 0 2
2020 13 $-11789 1 10
2021 17 $-56548 0 12
2022 9 $-104692 0 9
2023 9 $-15669 1 6
2024 23 $-52948 0 16
2025 24 $-79483 0 16
--- null-only cohort by entry-year: year n pnl winners>=+20% losers
2019 6 $-38289 0 6
2020 12 $216085 2 5
2021 9 $-19187 0 6
2022 7 $-85662 0 6
2023 11 $-12838 1 8
2024 19 $-18734 1 12
2025 16 $-9623 1 10
--- arm-only top winners / losers
  arm-winner KOD|2020-10-22 $80032
  arm-winner AAP|2021-03-13 $31607
  arm-winner SUN|2023-10-09 $24612
  arm-winner MFC|2024-01-31 $22524
  arm-winner FICO|2023-04-21 $13901
  arm-winner PHYS|2025-02-03 $13071
  arm-loser WBTN|2025-08-23 $-22121
  arm-loser ADTN|2022-08-15 $-19428
  arm-loser TNI|2019-06-10 $-19401
  arm-loser LRCX|2021-12-07 $-18132
  arm-loser INO|2020-07-29 $-18038
  arm-loser LPG|2022-11-12 $-17247
```
