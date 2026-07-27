# Leverage-dawn surface — REJECT (2026-07-26)

The P1b program's sole surviving payload is closed. Surface ran 2026-07-26
16:55-00:41Z (13-fold broad 2000-2026, v5thin, 6 dawn cells + baseline,
mechanism #2077 with the B1 funding fix). Ledger:
`2026-07-26-leverage-dawn-surface` (Reject). Report:
`.sweep-output/leverage-dawn-surface/walk_forward_report.md`.

## Result

| cell (dawn req × age) | Sharpe μ | Return μ±σ | MaxDD μ | gate |
|---|---|---|---|---|
| baseline | .766 | 34.6 ± 37 | 17.7 | — |
| 0.90 × 52w | .623 | 59.4 ± 107 | 24.6 | FAIL 4/13 |
| 0.90 × 78w | .620 | 59.7 ± 102 | 26.1 | FAIL 4/13 |
| 0.85 × 52w | .596 | 62.4 ± 87 | 30.4 | FAIL 3/13 |
| 0.85 × 78w | .536 | 63.9 ± 112 | 33.9 | FAIL 3/13 |
| 0.75 × 52w | .525 | 75.5 ± 161 | 40.0 | FAIL 4/13 |
| 0.75 × 78w | .510 | ~74 ± ~160 | ~42 | FAIL 4/13 |

Sharpe degrades monotonically in dawn aggressiveness; MaxDD balloons; the
wealth signal the P1b screen saw is real (return μ up 2×) but arrives as
variance, not risk-adjusted return.

## The two decisive folds

- **fold-012 (2024-25) — the named falsifier FIRED**: 5/6 dawn arms
  decisively negative (worst −19.8% / DD 56.8 / Sharpe −0.10 vs baseline
  +39.4 / 15.3 / 0.90). The 2023 MA flip-up labeled 2024 a dawn; the label
  levered into melt-up chop exactly as the P1b memo predicted.
- **fold-010 (2020-21) — even the monster fold loses risk-adjusted**:
  returns 297-579% vs 134 but DD 32-46 vs 13.1 and Sharpe 1.49-1.66 vs
  2.01. Dawn windows carry the same whipsaw premium as everywhere else.

## Transferable why

A lagging regime label cannot separate dawn-TAIL from dawn-CHOP: the
within-dawn tape is the same premium+monster mix as the whole sample, so
conditional leverage inherits unconditional leverage's asymmetric
amplification (chop amplifies fully; monsters were already near fully
invested), just diluted. **The fat tail cannot be scaled even
regime-conditionally.** Regime-conditioned deployment intensity joins the
reject family. Mechanism stays default-off as an axis; no grid, no flips.

## Integrity notes

- Funding confirmed at surface level: every arm diverges from baseline
  (no 0.0000 gaps) — the B1 permissive-funding fix is live.
- **Open item:** this run's baseline (.766/34.6/17.7) drifts from the M4
  surface's baseline (.827/36.2/14.1) on nominally the same spec +
  warehouse; code moved 7ef57ed2→96c4c5f between runs. Relative verdicts
  within each run stand, but identify the drift source (suspects: #2085
  exit-visibility, #2081 ADV aggregation) before reusing cached baselines.
