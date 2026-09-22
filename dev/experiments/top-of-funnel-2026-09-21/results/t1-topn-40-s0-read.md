# t1-topn-40 salt 0 — paired read vs `a0-pit-null-s0-v11`

Cell wall 4h48m (20:49 → 01:38 PT), peak RSS 6.47 GB, V6 = 0 (`validator_diff -check V6` exit 0), V16/V17 PASS.

| metric | null s0 | arm s0 (cap 40) |
|---|---:|---:|
| total_return_pct | 457.01 | **237.38** |
| total_trades | 732 | 771 |
| max_drawdown_pct | 40.64 | 44.48 |
| calmar_ratio | 0.165 | 0.106 |
| mean concurrent positions (Σ days_held / 9,660 d) | 4.85 | 5.00 |

**Rule at this salt: fails both** (realised and Calmar worse). The arm needs ≥ 2/3 salts clearing both; s1 and s2 must both clear.

## Paired join on `symbol|entry_date` (`paired.sh`)

| cohort | n | pnl | ≥ +20 % winners | losers | median pnl % | mean score | mean entry vol ratio |
|---|---:|---:|---:|---:|---:|---:|---:|
| shared | 491 | $2.51 M (null) / $2.94 M (arm) | 45 (9.2 %) | 66 % | −3.0 | 108.6 | 2.89 |
| null-only | 241 | **+$1.34 M** | 26 (10.8 %) | 64.7 % | −2.9 | 106.4 | 2.95 |
| arm-only | 280 | **−$0.87 M** | 19 (6.8 %) | 68.2 % | −3.9 | 101.6 | 3.35 |

First divergence 2000-03-01 (the cap binds from week one — `d0-funnel-decomposition.md`). The arm-only cohort is 68 % losers, under the pre-registered 80 % "stale-entry breadth" trigger; its winners are half as frequent as the null-only cohort's and its mean screener score is 5 points lower. Exit mix: arm-only stop_loss 180 / laggard_rotation 96 of 280; null-only 158 / 73 of 241.

## Where the money moved (year-end NAV, k$; arm − null)

| span | arm − null at span end | driver |
|---|---:|---|
| 2000–2010 | +$351 k (2010) | small, steady: arm ahead every year, +$0.1–0.35 M |
| 2011–2019 | +$58 k (2019); peak **+$752 k (2017)** | arm ahead 2014–2018 (2014 arm-only +$125 k, 2017 +$229 k) |
| 2020 | **−$889 k** | null-only 2020 entries +$513 k (3 monsters); arm-only 2020 −$448 k (24 entries, 17 losers) |
| 2021–2024 | −$988 k (2024) | arm-only 2021 −$309 k, 2023 −$187 k; both books lose 2021–23 |
| 2025–26 | **−$2.20 M** | null-only 2025 entries **+$1.17 M** (4 ≥ +20 % winners); arm 2025 +$65 k vs null +$1.17 M |

The whole gap is the 2020 and 2025 monster cohorts landing in the null's book, not a per-trade edge: through 2019 the arm was *ahead*, on the same kind of reshuffle. This is the `project_edge_is_the_fat_tail` / ECHO-lottery shape — a different draw of which A_plus ties fill the ~5 slots.

## What the arm-only entries were in the null's cascade (`join.awk` on d0's `candidates.sexp`)

Latest Friday before entry, 224 of 280 arm-only entries with a candidate row in the prior 8 weeks:

| null's outcome that Friday | n | share |
|---|---:|---:|
| **Admitted** (null screened it too, order never filled) | 102 | 46 % |
| Dropped_at_top_n (the marginal 21–40) | 63 | 28 % |
| Dropped_at_breakout (older resting order; not that week's signal) | 56 | 25 % |
| other | 3 | 1 % |

Null-only entries: 147/147 with rows were `Admitted` (143 A_plus), as expected.

So only **~28 % of the arm's extra trades are the marginal names the cap had cut**. Nearly half are names the null admitted too but never filled: a 40-name list changes *which* resting orders trigger first against ~5 open slots and the cash floor, and that reshuffle — not the marginal 21–40 — carries the delta. Mean concurrent positions are equal (4.85 vs 5.00): the arm holds a different set, not more.

## Provisional mechanism read (pending s1/s2)

Capacity at the screener is not the leak. The binding constraint is downstream (slots + cash + trigger order), so widening the list is a re-draw of the slot lottery with slightly worse expected picks (lower score, higher volume-ratio entries, fewer ≥ +20 % winners). If s1/s2 agree, the top-N cut in #2490's funnel (36 % of monsters "lost" at top-N) is really a slot loss: the monster was admitted often enough; it did not win the slot. Next lever is slot policy (what fills first when the list exceeds the slots), not cap width.
