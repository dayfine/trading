# E1 horizon control — the entry-cap axis at 3-year folds (#2404)

**Result: "tighter is better" does not survive a 3× longer fold. Nothing beats
the committed 2.0. The 1-year surface was horizon-biased, as predicted.**

## What was run

The same axis, the same base scenario
(`goldens-sp500/sp500-2019-2023-armed-stoplimit.sexp`, which arms
`enable_sim_entry_stoplimit`), the same tree — only `test_days` changed, 365 →
1095, with `step_days` matched so the folds tile without overlap.

- 5 disjoint folds: 2010-01-01→2012-12-30, →2015-12-30, →2018-12-29,
  →2021-12-28, →2024-12-27 (folds past `end_date` are dropped).
- 30 fold-arm runs (baseline + 5 variants × 5 folds), `--parallel 2`,
  **wall 1543s, rc=0**.
- Spec: `trading/test_data/walk_forward/entry-extension-cap-3y-folds-2010-2026.sexp`.

**Null tripwire PASSED.** `entry_extension_max_pct=2.0` is bit-identical to
baseline on all 5 folds (0/5 wins, worst-fold gap 0.0000) — the base's own
value. The axis binds and the run is deterministic
(`project_ladder_v4_null_278pp`).

## The two horizons side by side

| cap | 1y folds (16) Return μ | 3y folds (5) Return μ | 1y Sharpe μ | 3y Sharpe μ | 1y Calmar wins | 3y Calmar wins |
|---|---:|---:|---:|---:|---:|---:|
| **1.0** | **8.68** (best) | **43.76** (2nd, *below* baseline) | **0.685** (best) | 0.961 | **13/16** | **2/5** |
| 2.0 = baseline | 7.87 | **45.49 (best)** | 0.613 | **0.998 (best)** | 0 | 0 |
| 5.0 | 6.44 | 37.52 (worst) | 0.514 | 0.837 | 4/16 | 1/5 |
| 10.0 | 6.74 | 39.62 | 0.557 | 0.908 | 3/16 | 2/5 |
| 15.0 (live) | 6.68 | 39.54 | 0.551 | 0.907 | 3/16 | 2/5 |

(The two Return columns are not comparable to each other in level — one is a
1-year fold's return, the other a 3-year fold's. Only the *ranking within a
column* carries.)

**Go/no-go: every variant FAILS the 3-of-5 Calmar gate.** Baseline is not
beaten by anything.

## What changed, and what it means

1. **The return advantage of the tight cap is gone.** At 1-year folds, 1.0 beat
   baseline on return, Sharpe, MaxDD and Calmar. At 3-year folds it is *below*
   baseline on return (43.76 vs 45.49), Sharpe (0.961 vs 0.998) and Calmar
   (1.002 vs 1.033). It still wins MaxDD 4/5 — but its mean MaxDD (14.38) is a
   rounding difference from baseline's (14.42).

2. **The drawdown story inverts.** At 1-year folds the tight cap won MaxDD
   15/16. At 3-year folds the *lowest* mean MaxDD belongs to the **loose** caps
   — 10.0 and 15.0 at 12.60 vs baseline's 14.42 — driven by fold-002
   (2016-2018), where the loose caps take 15.18% drawdown against baseline's
   21.45%. Tight wins narrowly and often; loose wins rarely and by a lot.

3. **This is the predicted signature of the bias, not a new mystery.** A tighter
   cap's failure mode is a no-fill, which forgoes a stock's entire subsequent
   run. A 1-year fold truncates that run at the boundary, so the miss is
   understated while the avoided chase is counted in full. Lengthen the fold and
   the forgone run lands inside the measurement window: fold-004 (2022-2024) has
   1.0 at 42.92 against baseline's 53.84, a **−10.9pp** gap on a single fold.

4. **5.0 is the worst value on both horizons.** The response is not monotone in
   the cap, which is itself a caution against reading any single-point result
   as a trend.

## What this does and does not settle

**Settles (as a direction check):** the 1-year table cannot support moving a
default. `1.0` is not promotable. The committed `2.0` survives both horizons
and is beaten by nothing.

**Does not settle:** which value live should use. Both horizons put live's
`15.0` below `2.0` on return and Calmar, which points at **changing live to
2.0** rather than re-pinning 82 backtest specs to 15.0 — but that is a
fidelity decision for the user, and it is a *ranking* claim on one universe and
one base scenario, not a promotion-grade result.

**Cannot answer at all:** whether the caps differ by *taking fewer positions*
or by *picking better*. `Walk_forward_types.fold_actual` carries no trade count
and no max single-trade P&L — filed as **#2412**. With 5 folds and σ ≈ 23pp on
return, the separation between neighbouring caps here is well inside fold
noise; only the baseline-vs-tight *direction* change between horizons is large
enough to read.

**Still absent:** the confirmation grid (`.claude/rules/promotion-confirmation.md`)
— one universe, one base, no macro-diverse cell. Nothing here is promotion
evidence; it is the horizon control the 1-year surface needed.

## Files

- `run.sh` — the launcher (parent tree, `--parallel 2`; one QC agent was
  building concurrently, so 2 rather than H1's measured-best 3).
- `walk_forward_report_3y.md` — full per-fold table, stability, sensitivity, verdict.
- `aggregate_3y.sexp` — machine-readable aggregate.
