# Lane M — `stop_ma_same_basis` (#2982) on the 26y record, 3 salts (2026-09-29)

Queue item 10 (`../investor-preset-2026-09-26/QUEUE.md`): the 9a arm of the 5y flag screen
(+19.7 pp at s0, `../investor-preset-2026-09-26/results-2026-09-28.md` §1) run on 26 years, 3 salts,
paired against the `f2` record and V6-gated. `f2m-ma-basis` = `f2-fills-faithful` +
`((stop_ma_same_basis true))`.

26y (2000-01 → 2026-06), top-3000 PIT schedule, `_v11pit` warehouse, $1,000,000. Chain log
`results/chain-M.log` (build `sweep-post2996`, main f5507ad86). `f2` ran on the `sweep-fixes`
build (#2964 tip). The cross-build caveat from `f1-s0-result.md` applies: no same-build `f2`
rerun exists, and `n_stop_raises` is not comparable across the two builds (#2988).

No numeric decision rule was pre-registered for item 10, only "paired, V6-gated". This is a
descriptive reading.

## Result

| salt | f2 return | f2m return | Δ | f2 max DD | f2m max DD | f2 Calmar | f2m Calmar | trades f2 / f2m | V6 f2m vs f2 |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| 0 | 132.78 % | 63.49 % | −69.3 pp | 54.57 % | 53.22 % | 0.059 | 0.035 | 724 / 740 | agree (0/0) |
| 1 | 106.54 % | 204.35 % | +97.8 pp | 49.06 % | 51.33 % | 0.057 | 0.084 | 746 / 723 | agree (0/0) |
| 2 | 70.00 % | 136.44 % | +66.4 pp | 56.44 % | 49.34 % | 0.036 | 0.067 | 741 / 720 | **DIFFER** (1/0) |

Sources: `results/{f2-fills-faithful,f2m-ma-basis}-s{0,1,2}-v11-actual.sexp`; V6 logs
`results/f2m-ma-basis-s{0,1,2}-v11.vs-f2.v6diff.log` (s1/s2 run by hand; the chain pairs only
against `a0`, logs `…vs-a0.v6diff.log`, all agree).

- **s2 is excluded.** `f2` s2 holds `AGYS 2006-01-09 (twin positions: AGYS/HXL)` and `f2m` s2 does
  not, so that pair is not a mechanism read (`mechanism-validation-rigor.md` check 8).
- **s0 and s1 are valid and disagree in sign** (−69.3 vs +97.8 pp). The portfolio-level effect of
  the fix at 26y is not distinguishable from path noise at n = 2.

## Paired per-trade read (the part that is not noise)

Joining the two arms on (entry date, symbol) and comparing each shared trade's `pnl_percent`
(column 10 of `trades.csv`, so position size drops out):

| salt | shared trades | unchanged | worse | better | mean Δ (pp) | exit date moved |
|---|---:|---:|---:|---:|---:|---:|
| 0 | 489 | 456 | 18 | 15 | −0.58 | 30 |
| 1 | 483 | 455 | 18 | 10 | −0.52 | 25 |
| 2 | 465 | 437 | 17 | 11 | −0.66 | 24 |

p10 through p90 are 0.0 on every salt: the fix leaves ~93 % of shared trades identical. Where it
acts, it mostly **cuts winners**. The largest per-trade losses repeat across salts:

- **CLB, entry 2005-07-05:** +126.3 % → +0.2 %, exiting 2005-10-13 instead of 2006-10-09, on all
  three salts.
- **CNH, 2007-01-22:** +71.2 → +46.2 % (s0), +71.4 → +46.6 % (s1).
- **HEI, 2003-09-03:** +22.8 → +2.8 % (s1), +2.2 % (s2).
- **Single-salt cuts:** GLPG 2019-04-03 +41.3 → −4.4 % (s0); DXCM 2019-07-22 +30.7 → −10.7 % (s0);
  NOAH 2017-07-05 +58.3 → −9.6 % (s2).

The largest improvement on any salt is +15.9 pp.

Realized P&L on the shared entries (dollars, so position size is included) is lower in `f2m` on
every salt: −$615k / −$486k / −$724k.

## Why

#2982's defect is that the trailing-stop raise candidate compared an adjusted MA with raw bars, so
the ratchet almost never fired on names with later splits/dividends. The flag fixes the basis, and
**the ratchet then fires as specified. Firing tightens stops on trending winners and exits them
early.** That is the mechanism the #2974 replay warned about (33 later-hit raises, p10 −14 %). It
matches three standing findings:
- `project_26y_review_pack_2026_09_24`: tighter stops lose.
- `project_edge_is_the_fat_tail`.
- `project_exit_stack_survives_fixed_basis`.

The portfolio-level sign flips because the few cut winners reroute the path, and which later
monsters get bought depends on the salt:
- f2m s0 lost BBBY/ZS size but gained ECHO 2025 +$347k;
- f2m s1 missed ECHO but kept BBBY/ZS/IRTC larger.

## Reading

- `stop_ma_same_basis` is a **correctness fix to a defective comparison**. Its per-trade effect at
  26y is a consistent small cost concentrated in large winners. Its portfolio effect at n = 2 valid
  salts is not distinguishable from path noise.
- **Not promotable** (no ACCEPT, and the paired per-trade read is negative). It stays default-off as
  an axis.
- **Forward guidance:** the lever is not the basis but **the ratchet rule itself** (#2974: the
  faithful 8 % trailing rule vs its current trigger). Any change that makes stops rise more often
  should be expected to tax the fat tail. Measure it per trade first, not by portfolio level.
- The 5y +19.7 pp screen result (one salt, 2021–2026) did not transfer. A 5y screen can only
  escalate (`mechanism-validation-rigor.md`), and here the escalation came back negative per trade.

#2982 can close as **measured**: flag shipped (#2996), 26y × 3 salts read here.
