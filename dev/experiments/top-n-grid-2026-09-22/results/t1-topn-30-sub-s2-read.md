# t1-topn-30-sub s2 vs a0-pit-null-sub s2 — paired read (paired.sh, join symbol|entry_date)

arm 69.48 % / 256 / maxDD 43.45 / Calmar 0.180 vs null 71.32 % / 260 / 43.77 / 0.183; V6 diff exit 0.

```
shared:    n=188 pnl=$238403 (null pnl) / $262644 (arm pnl)
null-only: n=72 pnl=$-3325
arm-only:  n=68 pnl=$-9198
first divergence (earliest entry present in only one arm): 2020-09-19
--- per entry-year realised: year null_n null_pnl arm_n arm_pnl
2019 30 $17129 30 $17129
2020 48 $672403 49 $505518
2021 36 $-87819 36 $-50261
2022 37 $-276406 40 $-266162
2023 48 $-112922 46 $-37371
2024 31 $60575 29 $108729
2025 30 $-37883 26 $-24136
--- arm-only cohort by entry-year: year n pnl winners>=+20% losers
2020 3 $-28623 0 3
2021 14 $-60426 1 12
2022 11 $-55668 0 8
2023 12 $23899 1 7
2024 13 $134990 2 6
2025 15 $-23370 1 11
--- null-only cohort by entry-year: year n pnl winners>=+20% losers
2020 2 $138481 1 0
2021 14 $-97854 0 11
2022 8 $-47651 0 6
2023 14 $-45871 1 11
2024 15 $87879 3 9
2025 19 $-38310 0 11
--- arm-only top winners / losers
  arm-winner GLNG|2024-04-20 $83319
  arm-winner AAMI|2025-06-11 $63145
  arm-winner KGC|2024-04-13 $60645
  arm-winner IRM|2021-02-24 $37281
  arm-winner X|2023-09-19 $27665
  arm-winner IT|2023-11-03 $25428
  arm-loser SIRI|2023-07-22 $-19899
  arm-loser LPG|2022-11-12 $-18916
  arm-loser NAT|2022-11-22 $-17278
  arm-loser SMCI|2021-12-18 $-16828
  arm-loser WIX|2021-04-28 $-16099
  arm-loser INOD|2024-06-15 $-15683
```
