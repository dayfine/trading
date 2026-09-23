# t1-topn-40-sub s2 vs a0-pit-null-sub s2 — paired read (paired.sh, join symbol|entry_date)

arm 52.91 % / 275 / maxDD 44.09 / Calmar 0.142 vs null 71.32 % / 260 / 43.77 / 0.183; V6 diff exit 0.

```
shared:    n=192 pnl=$-116768 (null pnl) / $-66322 (arm pnl)
null-only: n=68 pnl=$351846
arm-only:  n=83 pnl=$275853
first divergence (earliest entry present in only one arm): 2020-05-09
--- per entry-year realised: year null_n null_pnl arm_n arm_pnl
2019 30 $17129 30 $16908
2020 48 $672403 48 $449528
2021 36 $-87819 40 $-21298
2022 37 $-276406 37 $-277181
2023 48 $-112922 52 $224911
2024 31 $60575 28 $-73747
2025 30 $-37883 40 $-109588
--- arm-only cohort by entry-year: year n pnl winners>=+20% losers
2020 11 $139897 2 6
2021 20 $-31438 0 13
2022 8 $-83199 0 8
2023 6 $374022 2 2
2024 17 $-33377 1 13
2025 21 $-90053 1 18
--- null-only cohort by entry-year: year n pnl winners>=+20% losers
2020 11 $361289 3 4
2021 16 $-99889 0 13
2022 8 $-54362 0 5
2023 2 $52906 2 0
2024 20 $106704 3 12
2025 11 $-14802 1 7
--- arm-only top winners / losers
  arm-winner ADMA|2023-12-19 $326895
  arm-winner AN|2020-08-04 $118624
  arm-winner BMA|2023-12-18 $67028
  arm-winner AAMI|2025-06-11 $62197
  arm-winner FCNCA|2020-11-28 $58295
  arm-winner KGC|2024-04-20 $55333
  arm-loser BEAM|2021-07-03 $-27259
  arm-loser WRLD|2025-02-15 $-17306
  arm-loser ANAB|2024-07-25 $-16273
  arm-loser AG|2020-07-30 $-15922
  arm-loser UMBF|2024-07-31 $-15318
  arm-loser PSTG|2025-01-22 $-15299
```
