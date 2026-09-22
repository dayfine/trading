# t1-topn-40 salt 2 — paired read vs `a0-pit-null-s2-v11`

Cell wall 3h59m (05:54 → 09:53 PT), peak RSS 6.45 GB, V6 = 0 (`validator_diff -check V6` exit 0), V16/V17 PASS.

| metric | null s2 | arm s2 (cap 40) |
|---|---:|---:|
| total_return_pct | 152.03 | **329.51** |
| total_trades | 762 | 766 |
| max_drawdown_pct | 51.32 | 44.68 |
| calmar_ratio | 0.069 | 0.127 |
| sharpe | 0.297 | 0.414 |
| mean concurrent positions | 4.67 | 5.03 |

**Rule at this salt: clears both.** With s1 also clearing, the pre-registered rule reads **2 of 3 → ACCEPT**.

## Paired join on `symbol|entry_date`

| cohort | n | pnl | ≥ +20 % winners | losers | median pnl % | mean score | mean entry vol ratio |
|---|---:|---:|---:|---:|---:|---:|---:|
| shared | 501 | $1.91 M (null) / $2.30 M (arm) | — | — | — | — | — |
| null-only | 261 | **−$0.51 M** | 18 (6.9 %) | 70.5 % | −3.5 | 106.1 | 3.30 |
| arm-only | 265 | **+$0.85 M** | 24 (9.1 %) | 65.7 % | −3.7 | 103.0 | 2.81 |

Arm-only top winners: GME 2020-09-14 +$341 k, CMG 2010 +$314 k, GLNG 2024 +$308 k, PETS 2017 +$304 k, MELI 2019 +$278 k,
BKE 2020 +$236 k — six names over $230 k spread across five years, not one monster. Per entry-year the arm wins 2016
(+$0.5 M), 2017 (+$0.33 M), 2019 (+$0.37 M), 2020 (+$0.52 M), 2024 (+$0.39 M) and loses 2018 (−$0.40 M), 2022
(−$0.34 M), 2026 (−$0.30 M).
