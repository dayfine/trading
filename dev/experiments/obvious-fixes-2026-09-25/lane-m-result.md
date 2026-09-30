# Lane M — `stop_ma_same_basis` (#2982) on the 26y record, 3 salts (2026-09-29)

Queue item 10 (`../investor-preset-2026-09-26/QUEUE.md`) takes the 9a arm of the 5y flag screen
(+19.7 pp at s0, `../investor-preset-2026-09-26/results-2026-09-28.md` §1) and runs it on 26 years,
3 salts, paired against the `f2` record and V6-gated. `f2m-ma-basis` = `f2-fills-faithful` +
`((stop_ma_same_basis true))`; the spec is `specs/f2m-ma-basis.sexp`.

**Setup.** 26y (2000-01 → 2026-06), top-3000 PIT schedule, `_v11pit` warehouse, $1,000,000.

**Builds.**
- `f2m` ran on the `sweep-post2996` build (main f5507ad86); chain log `results/chain-M.log`.
- `f2` ran on the `sweep-fixes` build (#2964 tip).
- The cross-build caveat from `f1-s0-result.md` applies. No same-build `f2` rerun exists, and
  `n_stop_raises` is not comparable across the two builds (#2988).

No numeric decision rule was pre-registered for item 10, only "paired, V6-gated". This is a
descriptive reading.

## Result

| salt | f2 return | f2m return | Δ | f2 max DD | f2m max DD | f2 Calmar | f2m Calmar | trades f2 / f2m | V6 f2m vs f2 |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| 0 | 132.78 % | 63.49 % | −69.3 pp | 54.57 % | 53.22 % | 0.059 | 0.035 | 724 / 740 | agree (0/0) |
| 1 | 106.54 % | 204.35 % | +97.8 pp | 49.06 % | 51.33 % | 0.057 | 0.084 | 746 / 723 | agree (0/0) |
| 2 | *excluded* | | | | | | | | **DIFFER** (1/0) |

**Sources.**
- Metrics: `results/{f2-fills-faithful,f2m-ma-basis}-s{0,1}-v11-actual.sexp`.
- V6 logs: `results/f2m-ma-basis-s{0,1,2}-v11.vs-f2.v6diff.log`.
  - The `vs-f2` logs were run by hand and record no `exit=` line. `validator_diff` exited 0 on s0
    and s1 and 1 on s2.
  - The chain pairs only against `a0` (`…vs-a0.v6diff.log`); all three agree.

- **s2 is excluded.** `f2` s2 holds `AGYS 2006-01-09 (twin positions: AGYS/HXL)` and `f2m` s2 does
  not, so the pair is not a mechanism read (`mechanism-validation-rigor.md` check 8). No s2 number
  is used below. Its artifacts are committed for the record only.
- **s0 and s1 are valid and disagree in sign** (−69.3 vs +97.8 pp). At n = 2 the portfolio-level
  effect of the fix at 26y cannot be told apart from path noise.

## Paired per-trade read (s0 and s1)

The two arms were joined on (entry date, symbol).

**Trade sets.** About a third of each arm's trades are not in the other:

| salt | f2 trades | f2m trades | shared | f2-only (P&L) | f2m-only (P&L) |
|---|---:|---:|---:|---|---|
| 0 | 724 | 740 | 489 | 235 (−$223,736) | 251 (−$104,012) |
| 1 | 746 | 723 | 483 | 263 (−$267,938) | 240 (+$343,890) |

**Shared trades,** compared on `pnl_percent` (column 10 of `trades.csv`, so position size drops
out):

| salt | shared | unchanged | worse | better | mean Δ (pp) | sum worse / better (pp) | exit date moved |
|---|---:|---:|---:|---:|---:|---|---:|
| 0 | 489 | 456 | 18 | 15 | −0.58 | −345 / +63 | 30 |
| 1 | 483 | 455 | 18 | 10 | −0.52 | −275 / +23 | 25 |

**Every worse shared trade was a winner under `f2`** (18/18 on both salts). The cuts that repeat on
both valid salts:

| entry | f2 (s0 / s1) | f2m (s0 / s1) |
|---|---|---|
| CLB 2005-07-05 | +126.3 / +126.8 % | +0.2 / +0.3 % (exit 2005-10-13 instead of 2006-10-09) |
| CNH 2007-01-22 | +71.2 / +71.4 % | +46.2 / +46.6 % |
| HEI 2003-09-03 | +22.9 / +22.8 % | +2.1 / +2.8 % |
| COLM 2003-05-28 | +15.4 / +15.5 % | +5.8 / +5.8 % |
| ACN 2006-10-30 | +14.2 % (both) | +4.1 / +4.2 % |
| ACIW 2012-02-22 | +10.9 / +10.8 % | −4.3 / −4.4 % |
| X 2014-07-30 | +10.5 % (both) | −0.6 / −0.8 % |

s0 alone adds GLPG 2019-04-03 (+41.3 → −4.4 %) and DXCM 2019-07-22 (+30.7 → −10.7 %). The largest
improvement on either salt is +15.9 pp.

**Decomposing the realized-P&L gap** (f2m − f2):

| salt | total | shared trades | unshared trades (f2m-only − f2-only) |
|---|---:|---:|---:|
| 0 | −$495,495 | −$615,218 | +$119,724 |
| 1 | +$126,249 | −$485,578 | +$611,828 |

- On the trades both arms took, the fix costs money on both salts.
- On the trades that differ, `f2m` did better on both salts.
- **The portfolio sign is set by the unshared set, i.e. by the path.** At s1 the f2m-only trades
  net +$452k in 2009–19, and the path also misses ECHO 2025 (`f2` +$312,755).

**Per-year split of the unshared trades.** The three eras disagree between salts:

| salt | arm | 2000–08 | 2009–19 | 2020–26 |
|---|---|---:|---:|---:|
| 0 | f2-only | +$60k | −$79k | −$204k |
| 0 | f2m-only | +$28k | −$58k | −$74k |
| 1 | f2-only | −$84k | −$258k | +$73k |
| 1 | f2m-only | +$141k | +$452k | −$249k |

No era is consistently favourable to either arm, so no per-year conclusion is drawn.

## Why

- **The defect (#2982):** the trailing-stop raise candidate compared an adjusted MA with raw bars,
  so the ratchet almost never fired on names with later splits or dividends.
- **The fix:** the flag corrects the basis, and **the ratchet then fires as specified: it tightens
  stops on trending winners and exits them early.** The shared-trade read shows exactly that:
  ~93 % of shared trades unchanged, and every trade that got worse was a winner cut short.
- **The #2974 replay predicted this** (33 later-hit raises, p10 −14 %).
- **It matches three standing findings:**
  - `project_26y_review_pack_2026_09_24`: tighter stops lose.
  - `project_edge_is_the_fat_tail`.
  - `project_exit_stack_survives_fixed_basis`.
- **Why the portfolio sign flips:** exiting a winner early frees cash on a different date. The
  unshared third of the book then buys different names, and which later monsters get bought
  depends on the salt.

## Reading

- `stop_ma_same_basis` is a **correctness fix to a defective comparison**.
  - On the trades it changes directly, it has a consistent cost at 26y, concentrated in large
    winners (2 valid salts).
  - Its portfolio effect at n = 2 is not distinguishable from path noise.
- **Not promotable** (no ACCEPT, and the per-trade read is negative). It stays default-off as an axis.
- **Forward guidance:** the lever is not the basis but **the ratchet rule itself** (#2974: the
  faithful 8 % trailing rule vs its current trigger). Any change that makes stops rise more often
  should be expected to tax the fat tail. Measure it per trade (shared trades, `pnl_percent`)
  before reading portfolio levels.
- The 5y +19.7 pp screen (one salt, 2021–2026) did not transfer. A 5y screen can only escalate
  (`mechanism-validation-rigor.md`), and here the escalation came back negative per trade.

#2982 can close as **measured**: the flag shipped (#2996), and the 26y 3-salt read is here.
