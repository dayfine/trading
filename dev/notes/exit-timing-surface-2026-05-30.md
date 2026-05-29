# Exit-timing surface — 30-fold WF-CV REJECTS the whole surface (2026-05-30)

**First real use of the systematic experiment platform**
(`dev/plans/experiment-platform-2026-05-29.md`, Gaps A–F). It works, and its
first verdict is a clean, decisive negative.

**Decision:** Do NOT pursue exit-timing hysteresis / exit-margin as a strategy
change. The *entire* knob surface is a net drag across the 2010–2026 fold
distribution — not just the one point we rejected on 2026-05-29.

## What was tested

A **surface**, not a point — the upgrade over the 2026-05-29 single-point
rejection (`dev/notes/stage3-hysteresis-walkforward-cv-2026-05-29.md`). The
trade-autopsy (#1360) flagged false Stage 2→3 exits (`late_reentry` +
`stage3_false_positive`, ~2734% missed gain over 27y × 12 sym) as the dominant
failure mode. We swept the two knobs that gate those exits:

- `stage3_force_exit_config.hysteresis_weeks` ∈ {1, 2, 3}
- `stage3_exit_margin_pct` ∈ {0.0, 0.02, 0.05}

Cartesian = 9 cells + auto-baseline, each evaluated over **31 rolling OOS folds**
(2010-01-01→2026-04-30, test=365d/step=182d, 525-symbol sp500 historical), via
`walk_forward_runner.exe` with the `axes` block from `Walk_forward.Variant_matrix`
(PR-1). Spec: `trading/test_data/walk_forward/exit-timing-surface-2026-05-30.sexp`.

## Result — monotonic degradation toward baseline

Stability (mean ± stdev across 31 folds):

| Cell | Sharpe μ | Calmar μ | Return % μ | MaxDD % μ |
|------|---------:|---------:|-----------:|----------:|
| **baseline (h1, m0)** | **0.540** | **1.249** | **8.17** | **12.28** |
| h1, m0.0 (anchor) | 0.540 | 1.249 | 8.17 | 12.28 |
| h1, m0.02 | 0.532 | 1.193 | 8.04 | 12.29 |
| h1, m0.05 | 0.519 | 1.186 | 7.89 | 12.34 |
| h2, m0.0 | 0.519 | 1.185 | 7.89 | 12.33 |
| h2, m0.02 | 0.519 | 1.185 | 7.88 | 12.34 |
| h2, m0.05 | 0.519 | 1.185 | 7.88 | 12.34 |
| h3, m0.0 | 0.519 | 1.185 | 7.87 | 12.33 |
| h3, m0.02 | 0.519 | 1.185 | 7.87 | 12.33 |
| h3, m0.05 | 0.518 | 1.184 | 7.87 | 12.33 |

Cross-fold Sharpe-win counts vs baseline (gate needs ≥16/31): best cell **4/31**.
Every cell FAILs the gate.

Three things make this decisive:

1. **No interior optimum.** Every step toward more hysteresis or more margin
   *lowers* Sharpe / Calmar / return. The gradient points entirely back to the
   no-hysteresis, no-margin corner. There is no cell to tune toward.
2. **No DSR candidate.** No cell even raw-beats baseline on mean Sharpe, so
   there's nothing to deflate (`Backtest_stats.Deflated_sharpe`); best-of-N
   correction is moot — the surface has no winner to correct.
3. **The (h1, m0) anchor exactly reproduces baseline**, confirming the harness
   is faithful; and the (h2, m0.02) cell reproduces the 2026-05-29 single-point
   rejection (same config-hash `9dfc464e…`), confirming the ledger dedup.

## Interpretation

The autopsy correctly *labels* where gain is lost, but the gain is **not
recoverable by exit-timing knobs**. The false Stage 2→3 exits it flags are
entangled with the *true* ones the same knob would also delay; across the
regime distribution, delaying any exit costs more than the false exits save —
monotonically. This is the autopsy-is-a-labeller-not-a-knob-recommender lesson,
now demonstrated over a whole surface rather than a single point. The
exit-timing question is **closed**.

Recorded: `dev/experiments/_ledger/2026-05-30-exit-timing-surface.sexp`
(verdict Reject, 10 variants with config-hashes + fold aggregates). Future
sessions that propose any exit-timing cell will find it already rejected via
`Experiment_ledger.lookup`.

## What this says about the platform

The platform produced — unattended, end-to-end — a hypothesis → 10-cell surface
→ 310 walk-forward backtests → ranked verdict → ledger record, with the autopsy
hypothesis decisively closed. The next gap-closing attempt should look at a
*different mechanism class* (exit-timing is exhausted): e.g. the autopsy's
`late_stage2_admission` (entry-timing, mode #3), or cross-sectional rotation —
run through this same loop.
