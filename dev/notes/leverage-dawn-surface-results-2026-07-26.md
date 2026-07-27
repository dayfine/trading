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
- ~~**Open item:** this run's baseline (.766/34.6/17.7) drifts from the M4
  surface's baseline (.827/36.2/14.1) on nominally the same spec +
  warehouse; code moved 7ef57ed2→96c4c5f between runs. Relative verdicts
  within each run stand, but identify the drift source (suspects: #2085
  exit-visibility, #2081 ADV aggregation) before reusing cached baselines.~~
  **RESOLVED 2026-07-27 — see the addendum below.**

## Integrity addendum (2026-07-27) — drift root-caused, folds 000-008 untrusted

Root cause (issue #2108): **mid-run workspace mutation, not code.** This
surface ran from the parent workspace's tree while the 07-26 morning session
mutated that workspace mid-run (picks-stack commits, jj snapshots, bookmark
pushes, git-head import at 11:53 PT — inside the run's 09:55–17:41 PT window),
violating `sweep-hygiene.md` §"No concurrent jj ops". Fold-level fingerprint:
baseline folds 000-008 (early wall-clock) all differ from M4; folds 009-012
(late wall-clock) are bit-identical to M4.

Controlled single-fold repros (fold-000 baseline; M4 = 85.13/1.472, this run =
59.80/1.171): clean 96c4c5f build × {M4-style spec, this spec}, cache
{1024, 4096}, and **the actual dawn-run binary** all reproduce **85.13**
bit-exactly. The 59.80 is not reproducible from any committed state, and no
85.13 appears anywhere in this run's output (rules out label mixup).

Corrections and consequences:

- The drift note's "code moved 7ef57ed2→96c4c5f" was wrong: the M4 chain log
  records `HEAD=0764fdebc` (post-#2047). Suspects #2085 / #2081 exonerated.
- **The clean baseline of record is M4's .827/36.2/14.1.** Never reuse this
  run's .766 aggregate as a cached baseline.
- Folds 000-008 of ALL arms in this run are untrusted. The REJECT's decisive
  qualitative evidence — falsifier fold-012 firing, monster fold-010 losing
  risk-adjusted, Sharpe monotone in dawn aggressiveness — sits in or spans the
  clean region (009-012), so the verdict very likely stands; the 3-4/13 gate
  counts lean on tainted folds.
- A hygienic full re-run (pinned worktree at 96c4c5f, flock, idle container)
  launched 2026-07-27 → `/tmp/sweeps/leverage-dawn-v2-clean/`. **COMPLETED
  2026-07-27 10:33Z — REJECT RE-CERTIFIED** (ledger
  `2026-07-27-leverage-dawn-clean-rerun`): baseline 13/13 bit-identical to M4
  (.827/36.17/14.05 — parity restored); dawn Sharpe monotone .616→.437 with
  MaxDD 22.7→44.9; best gate cell 5/13 (need ≥7), all FAIL; falsifier
  fold-012 fires in all arms; fold-010 loses risk-adjusted everywhere. Every
  qualitative claim of this memo survives; cite the clean-rerun numbers, not
  this run's dawn-cell aggregates.
- Hardening: chain scripts now build + run from a pinned worktree, never the
  parent working copy — `sweep-hygiene.md` §"Pinned-worktree builds".
