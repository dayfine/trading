# t1-topn-40 salt 1 — paired read vs `a0-pit-null-s1-v11`

Cell wall 4h16m (01:38 → 05:54 PT), peak RSS 6.46 GB, V6 = 0 (`validator_diff -check V6` exit 0), V16/V17 PASS.

| metric | null s1 | arm s1 (cap 40) |
|---|---:|---:|
| total_return_pct | 188.05 | **303.97** |
| total_trades | 766 | 748 |
| max_drawdown_pct | 53.05 | 43.84 |
| calmar_ratio | 0.077 | 0.123 |
| sharpe | 0.329 | 0.409 |
| mean concurrent positions | 4.83 | 5.03 |

**Rule at this salt: clears both** (realised +116 pp, Calmar 0.123 vs 0.077, maxDD 9 points lower). With s0 failing both, **s2 decides** (≥ 2/3 needed).

## Paired join on `symbol|entry_date`

| cohort | n | pnl | ≥ +20 % winners | losers | median pnl % | mean score | mean entry vol ratio |
|---|---:|---:|---:|---:|---:|---:|---:|
| shared | 468 | $1.67 M (null) / $1.97 M (arm) | 38 (8.1 %) | 64.7 % | −3.0 | 108.0 | 2.94 |
| null-only | 298 | **+$4 k** | 23 (7.7 %) | 69.5 % | −3.5 | 106.6 | 2.95 |
| arm-only | 280 | **+$0.88 M** | 24 (8.6 %) | 62.9 % | −3.0 | 101.8 | 3.30 |

The mirror image of s0 with the same cohort sizes (280 arm-only both salts; 241 / 298 null-only): the arm-only draw
wins here, loses there. Per-trade quality is again lower on the arm's extra names (score 101.8 vs 106.6, higher
volume ratio), and the winner rate is a coin-flip between the two cohorts across salts (6.8 % / 8.6 % arm-only vs
10.8 % / 7.7 % null-only).

## Where the money moved (per entry-year realised, arm − null)

| year | null | arm | Δ | driver |
|---|---:|---:|---:|---|
| 2017 | +$650 k | +$120 k | −$531 k | null-only 2017 +$833 k (5 ≥ +20 % winners) |
| 2018 | −$729 k | −$212 k | **+$517 k** | null-only 2018 20 entries, 17 losers, −$353 k |
| 2019 | −$138 k | +$323 k | +$461 k | arm-only PODD +$347 k |
| 2020 | +$1.46 M | +$1.04 M | −$425 k | both books catch 2020; null-only +$717 k (4 winners) |
| 2024 | −$795 k | −$176 k | **+$619 k** | null-only 2024 36 entries, 25 losers, −$540 k |
| 2025 | +$55 k | +$497 k | +$442 k | arm-only **ECHO 2025-08-26 +$677 k** |

Arm-only top winners: ECHO +$677 k, PODD +$347 k, WIT +$281 k, KR +$268 k, FCNCA +$213 k. ECHO alone is 77 % of the
arm-only cohort's pnl — the same single name that decided the index-veto arm's salt read
(`project_index_stage_veto_verdict`, "ECHO lottery"). Strip ECHO and the arm-only cohort is +$203 k on 279 trades,
inside the shared-cohort scaling noise; the remaining s1 win is the null's 2018 and 2024 whipsaw cohorts (42 losers of
56 entries) that the arm's re-draw happened to skip.

## Read across s0 + s1

Two salts, opposite signs, same mechanism: a 40-name list re-draws which A_plus ties fill ~5 slots (concurrency
4.83–4.85 null vs 5.00–5.03 arm). Which draw holds the year's monster (2020 / 2025 in the null at s0; ECHO in the arm at
s1) and which draw eats the whipsaw cohorts (2018 / 2024) decides the sign. No property of the marginal names is
robust across the two salts. s2 is the tiebreak on the pre-registered rule; on the mechanism read the arm is already
a lottery re-draw, not a capacity lever.
