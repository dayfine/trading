# Early-admission surface sweep — INCONCLUSIVE (data-coverage defect)

**Date:** 2026-05-30
**Verdict:** **INCONCLUSIVE** (ledger: `dev/experiments/_ledger/2026-05-30-early-admission-surface.sexp`)
**Mechanism PR:** #1378 (`feat(stage): default-off dual-MA early Stage-2 admission flag`) — stays default-off.

## TL;DR

Second use of the experiment platform, first attack on **entry-timing** (autopsy
mode `late_stage2_admission`). The mechanism shows a **consistent, strong
within-run improvement** — but on a **truncated 2017–2026 window**, not the
nominal 2010–2026 one, because the scenario's index golden only starts in 2017.
The run **cannot be promoted** and is recorded INCONCLUSIVE. The data-coverage
defect it surfaced is the more important finding: it compromises **every**
experiment run on `sp500-2010-2026` (exit-timing and hysteresis included).

## The mechanism (PR #1378)

`Stage.config.early_admission_ma_period : int option [@sexp.default None]`. When
`Some p`, a fast SMA of period `p` (read self-contained from the `get_close`
callback) promotes Stage1→Stage2 early and **holds** the position on the fast MA
while it stays rising + price-above; it defers entirely to the slow 30-week MA
otherwise (never blocks a genuine slow-MA Stage2, never forces an exit). `None`
= bit-identical no-op. The thesis: the 30-week MA admits Stage 2 months late off
bear bottoms (Mar 2009, Mar 2020); a faster confirmation MA admits earlier.

## The surface

1-D axis `stage_config.early_admission_ma_period ∈ {5, 7, 10, 13}` (all faster
than the 30-week slow MA) + the auto-baseline (`None`, mechanism off).
Geometry mirrored the exit-timing / hysteresis specs exactly: base scenario
`goldens-sp500-historical/sp500-2010-2026.sexp`, Rolling 2010-01-01→2026-04-30,
`test_days=365 step_days=182` ⇒ 31 OOS folds, `--parallel 4`. Ranking by
`Walk_forward.Variant_ranking` (Pareto) + `Backtest_stats.Deflated_sharpe`
(best-of-4 deflation).

## Raw results (per-variant means over the 31 nominal folds)

| Variant | Sharpe | Calmar | MaxDD % | Return % | Frontier | DSR |
|---|---:|---:|---:|---:|:--:|---:|
| baseline (off) | 0.251 | 0.829 | 8.95 | 12.00 | **no** | — |
| ma=5 | 0.340 | 1.041 | 8.91 | 13.40 | yes | — |
| ma=7 | 0.334 | 0.788 | 6.82 | 5.36 | no | — |
| **ma=10** | **0.414** | 0.911 | 6.79 | 7.24 | **yes** | **0.9987** |
| ma=13 | 0.405 | 1.022 | 6.77 | 6.21 | yes | — |

Per-fold wins (out of 31): ma=10 wins **15** on Sharpe, 15 Calmar, 15 return, 14
MaxDD. Every cell beats baseline on mean Sharpe; baseline is **dominated** (off
the Pareto frontier). The best cell (ma=10) survives best-of-4 deflation at
DSR 0.9987.

**On its face this looks like an ACCEPT.** It is not — see below.

## Why INCONCLUSIVE, not ACCEPT

The decisive diagnostic: **folds 000–012 are zero-trade for _every_ variant**
(baseline and all four cells produce `total_return_pct 0`, `sharpe 0`). The
first non-zero fold is fold-013, whose test window first reaches 2017.

Root cause — **the index golden is truncated**:

- `trading/test_data/G/X/GSPC.INDX/.../data.csv` covers only **2017-01-03 →
  2026-04-09**.
- NYSE A/D breadth (`trading/test_data/breadth/nyse_*.csv`) covers only
  **2017-01-02 → 2020-02-14**.
- Per-symbol bars themselves *do* span 2009→2026 — so this is purely a
  market-regime-data gap, not a symbol-data gap.

With no index data before 2017, the Weinstein **macro gate** has no market-trend
read and blocks all buys in 2010–2016 ⇒ 13 zero-trade folds. Consequences:

1. **The surface was evaluated on ~18 real folds (2017–2026), not 31
   (2010–2026).** The autopsy's target regime is bear-*bottom* admission; 2020's
   COVID bottom is covered, but **2009 is pre-window and 2010–2016 is empty** —
   so the mechanism was never tested across most of the intended distribution.
2. **The gate is diluted.** `n=31` counts the 13 zero-folds as forced ties (no
   win for anyone). ma=10's 15 wins ≈ 15 of ~18 *contested* folds (~83%), yet it
   "fails" the `16/31` gate purely on the tie dilution. The pass/fail and the
   DSR both rest on a denominator that doesn't reflect what was tested.
3. **The baseline does not reconcile.** This run's baseline is Sharpe 0.251 /
   MaxDD 8.95 / return 12.0; the canonical exit-timing run on the *same* nominal
   geometry recorded baseline Sharpe **0.54** / MaxDD 12.28 / return 8.17. Same
   scenario, same default config — different backtests. The most likely reading
   is that the canonical run saw fuller index coverage (higher MaxDD ⇒ it
   included a 2010–2016 drawdown this run skipped). Until that is reconciled,
   the apparent improvement cannot be trusted as alpha.

Declaring ACCEPT here would be exactly the single-window / artifact promotion the
gap-closing loop exists to prevent.

## Broader implication (the real headline)

**The `GSPC.INDX` 2017 floor compromises every experiment that uses
`sp500-2010-2026`.** The recent exit-timing-surface REJECT (#1375) and the
stage3-hysteresis WF-CV REJECT (#1366) were both labelled "31-fold 2010–2026"
but — if they ran against the same index golden — actually only exercised
2017–2026. Their *verdicts* (rejections) are conservative and likely still hold
on the narrower window, but the "2010–2026" coverage claim in those ledgers
overstates the regime span. The fix benefits the whole experiment program, not
just this mechanism.

## Next steps

1. **(infra, P0 for this lever)** Extend the index golden (`GSPC.INDX`) and NYSE
   A/D breadth back to 2009–2010 so the macro gate can run across the full
   window. This is an `ops-data` EODHD fetch. Tracked as a GitHub issue.
2. **(re-run)** Re-run this exact surface on the repaired data. If ma=10 (or any
   cell) still beats baseline across the true 2010–2026 distribution with a DSR
   that clears the baseline's, *then* it is an ACCEPT candidate and the mechanism
   is wired on by default per `experiment-flag-discipline.md`.
3. **(promising signal, do not act yet)** The 2017–2026 consistency — including
   the 2020 bottom, the exact regime the mechanism targets — is the most
   encouraging entry-timing result so far. Worth the data fix to settle it.

## Reproduction

Spec (run with `TRADING_DATA_DIR` pointed at the repo `trading/test_data`):

```scheme
((base_scenario "goldens-sp500-historical/sp500-2010-2026.sexp")
 (window_spec
  (Rolling
   ((start_date 2010-01-01) (end_date 2026-04-30)
    (train_days 0) (test_days 365) (step_days 182))))
 (baseline_label "baseline")
 (gate ((metric Sharpe) (m 16) (n 31) (worst_delta 0.20)))
 (axes
  ((axes
    (((key (stage_config early_admission_ma_period)) (values ((5) (7) (10) (13))))))
   (expansion Cartesian))))
```

```
walk_forward_runner.exe --spec <spec> --out-dir <dir> --parallel 4
```

Ranking + DSR were computed from the emitted `aggregate.sexp` + `fold_actuals.sexp`
(no in-repo CLI for `Variant_ranking`/`Deflated_sharpe` exists yet — a small
driver was used ad hoc; a committed `rank-variants` CLI is a reasonable
follow-up).
