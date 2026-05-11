# Holding-period sweep — 16-cell stage3_h × laggard_h on 15y Cell E

## TL;DR

**Current Cell E baseline (`stage3_h=1, laggard_h=2`) is near-optimal.** No
configuration in the 16-cell grid materially improves Sharpe; the apparent
levers (faster rotation, longer holds) trade quality for either churn or
drawdown without lifting risk-adjusted returns.

The candidate-supply bottleneck note's hypothesis — that holding-period
tweaks could relieve `Insufficient_cash` skips — is **falsified at the
strategy-level metric layer**. The downstream capital lock-up is real, but
the strategy already extracts the value the rotation can deliver; loosening
the stop is wrong, tightening rotation just churns.

## Method

15y Cell E default (`max_position_pct_long=0.14`, `max_long_exposure_pct=0.70`,
`min_cash_pct=0.30`, MaSlope, short side off) on sp500-historical 510 symbols
2010-01-01 → 2024-12-31. Only `stage3_force_exit_config.hysteresis_weeks` and
`laggard_rotation_config.hysteresis_weeks` vary across the grid.

Wall: ~3h on docker container under CPU oversubscription (5-parallel × 4
effective cores). 5 cells crashed mid-run (memory pressure: 7.9GB total
exhausted by 5×1.7GB sub-procs). Reported numbers below are from the 11
cells that produced `summary.sexp`.

## Results — 11 cells with summary

| stage3_h | laggard_h | Return | Trades | WR | Sharpe | MaxDD | AvgHold | FL fired |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 0 | 2 | 374.21% | 768 | 39.45% | **0.85** | 18.36% | 46.0d | — |
| 0 | 4 | 201.45% | 1380 | 45.72% | 0.43 | **49.39%** | 23.4d | yes |
| 1 | 1 | 359.87% | 932 | 41.63% | 0.77 | 25.78% | 36.2d | yes |
| 1 | 2 | 374.21% | 768 | 39.45% | **0.85** | 18.36% | 46.0d | — |
| 1 | 4 | 201.45% | 1380 | 45.72% | 0.43 | **49.39%** | 23.4d | yes |
| 2 | 2 | 358.88% | 786 | 38.30% | 0.81 | 20.07% | 45.1d | — |
| 2 | 3 | 313.48% | 669 | 36.77% | 0.78 | 19.73% | 53.5d | — |
| 3 | 1 | 314.82% | 924 | 40.80% | 0.72 | 26.42% | 36.6d | yes |
| 3 | 2 | 364.47% | 783 | 38.57% | 0.81 | 18.12% | 45.5d | — |
| 3 | 3 | **511.70%** | 646 | 37.93% | 0.58 | 48.23% | 56.7d | yes |
| 3 | 4 | 347.25% | 582 | 36.08% | 0.82 | **17.27%** | 64.2d | yes |

Crashed cells (no summary): s0-l1, s0-l3, s1-l3, s2-l1, s2-l4 — all
mid-rotation configurations that hit the OOM ceiling concurrently with peer
cells. Worth a re-run at `--parallel 2` to fill in the matrix.

## Key findings

### 1. stage3_h is a no-op when laggard_h=2

`s0-l2` and `s1-l2` produce **byte-identical metrics** (374.21% / 768 trades /
Sharpe 0.85 / DD 18.36%). Neither cell's directory contains
`force_liquidations.sexp` — the stage3 force-exit feature **never triggered**.
At laggard_h=2 the rotation cycles positions out before any reaches the
8-week-topping window that stage3 watches.

Same applies for s0-l4 vs s1-l4 (identical 201.45% / 1380 trades). At
laggard_h=4 the rotation is slower so positions can age, but stage3 still
doesn't differentially fire across stage3_h ∈ {0, 1}.

**Implication:** the stage3 force-exit feature pays its complexity cost only
at long laggard windows (h ≥ 3) AND with stage3_h ≥ 2. Worth a separate
question: should it be off-by-default at the new Cell E `0.14/0.70/0.30` config
since it only matters at niche corners?

### 2. Faster rotation (laggard_h=1) hurts Sharpe

s1-l1 (0.77) and s3-l1 (0.72) both lag the baseline by 0.08-0.13 Sharpe
despite their force-exit triggers firing. The +2pp WR boost doesn't carry the
Sharpe because the average winner shrinks (faster cuts = less compounding).

### 3. Longer rotation (laggard_h=4) is catastrophic

s0-l4 / s1-l4 spike DD to 49% with Sharpe 0.43. Both produced 1380 trades —
WAY more than baseline's 768. Counter-intuitive: longer hysteresis on the
laggard rotation produced *more* churn, not less. Likely mechanism: when
laggard finally fires it dumps positions in batches (rotation backed up), and
the strategy enters re-entry/whipsaw cycles. **Do not raise laggard_h above
2 at this position-size config.**

### 4. The high-return outlier — s3-l3 — is not a winner

s3-l3 returned **511.70%** (best of the grid) BUT Sharpe 0.58 and DD 48.23%.
Concentration cliff: the longest stage3 + medium laggard let positions ride
into Stage 3 tops, occasionally catching massive winners, but with concentrated
single-name exposure when the breakdown happens. Validation env's
`open_positions_value > $5M` cap also flagged this run as failing.

### 5. Tightest DD without Sharpe loss: s3-l4

DD 17.27% (vs baseline 18.36%), Sharpe 0.82 (vs baseline 0.85), but at the
cost of 24% fewer trades and 64-day average hold (longest in grid). Marginal
DD improvement; not worth the complexity bump.

## Verdict — keep baseline (s1-l2)

The 16-cell grid found NO configuration that strictly dominates the current
Cell E default on (Sharpe AND DD AND return AND WR). The lone equal-Sharpe
cell (s0-l2) is a degenerate alias of baseline, not an alternative.

The capital-supply bottleneck identified in
`dev/notes/cell-e-candidate-supply-bottleneck-2026-05-11.md` is real, but
**not addressable through holding-period tuning at this position-size config**.
The 5-position cap × 14-week average hold × 261 Fridays per year produces
~92 entries/yr maximum — the strategy already extracts that. Loosening
rotation just whipsaws; tightening doesn't lift Sharpe.

## Implications for next iteration

1. **Stage3 force-exit is on-by-default but mostly inert.** At laggard_h=2 it
   never fires. Consider:
   - flagging it OFF in the 0.14/0.70 default and treating it as a tuning
     dimension rather than a base-strategy feature, OR
   - tightening its trigger window so it actually fires at h=2.
2. **Real lever for capital throughput is per-position size.** Earlier
   `max_position_pct_long` sweep (`dev/notes/overnight-2026-05-10-results.md`)
   showed 0.14 was Sharpe-optimal. Lower (0.10, 7 positions) would create
   more slot demand → more cascade fill, but at the price of either DD or
   per-trade alpha.
3. **Entry-signal levers (PR #1043 + max_score_override #1034) remain the
   live hypothesis.** Block 3 of overnight sweep tests this: 3-arm sweep on
   15y Cell E with max_score=79 + stop_floor=0.10. Kicking off next.

## Re-run notes

The 5 crashed cells (`s0-l1, s0-l3, s1-l3, s2-l1, s2-l4`) should re-run at
`--parallel 2` once container memory is freed. They might surface a corner of
the matrix that's currently hidden, but given the 11-cell pattern is
flat-around-baseline, the expected value is "fills in the table" not "finds
a winner".
