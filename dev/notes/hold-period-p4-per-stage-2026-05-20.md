# Hold-period P4 — per-stage hold-distribution analysis (2026-05-20)

Probe P4 from `dev/plans/hold-period-deep-dive-2026-05-19.md`. Companion to P1 / P3 (not yet run).

## Headline

**P4 hypothesis falsified.** The plan asked whether the cell-E strategy admits a meaningful number of Stage-3 or Stage-4 entries that the screener filter mis-classifies, and whether laggard-rotation's longer hold (P50=28d) is in fact catching those mis-classifications. The data answers cleanly: **every single one of 2075 cell-E entries is classified `Stage2`**. There are zero `Stage1`, zero `Stage2_late`, zero `Stage3`, zero `Stage4` entries. The screener cascade is doing its job — only Stage 2 candidates reach entry.

The follow-up question — does the laggard-rotation branch catch stocks that became "wrong-direction" after entry — is therefore not answerable by stage decomposition. The 600 laggard-rotation trades and 1382 stop-loss trades are drawn from the same Stage-2 entry pool; whatever separates them lives downstream of stage classification.

## Pivoted-axis finding — screener-score quartiles

Since `entry_stage` is uniform, I bucketed the same 2075 trades by `screener_score_at_entry` quartile (Q25=60, Q50=70, Q75=75) instead. **The relationship is inverse to what the cascade-as-quality-filter premise would predict:**

| Bucket | N | P50 | P75 | P95 | Mean hold | Mean P&L % | Win-rate % |
|---|---:|---:|---:|---:|---:|---:|---:|
| Q1 (lowest, score < 60) | 230 | 14 | 63 | 161 | 43.4 | **1.71** | **42.6** |
| Q2 (60-69) | 755 | 13 | 47 | 175 | 40.8 | 1.24 | 35.8 |
| Q3 (70-74) | 299 | 11 | 56 | 196 | 44.3 | 1.59 | 38.8 |
| Q4 (highest, score >= 75) | 791 | 12 | 35 | 161 | 35.9 | **0.74** | 33.8 |

Lowest-score entries (Q1) deliver **2.3x the mean P&L** (1.71% vs 0.74%) and the **highest win rate** (42.6% vs 33.8%) of the highest-score entries (Q4). They also hold longest on average (43.4d vs 35.9d). Q4 trades exit on stop-loss 69.5% of the time vs 65.2% for Q1.

This is a single-run observation, not a robust finding — but it's a meaningful signal that the **screener score is anti-predictive of trade outcome on this universe / period**. The score system is probably ranking on "Stage 2 momentum strength," and the strongest-momentum names are precisely the ones most prone to mean-revert hard before the trade matures.

## Setup

- **Source data**: `dev/backtest/scenarios-2026-05-10-215704/15y-cell-e-stage3-k1-laggard-h2/trades.csv` (510-symbol SP500 historical universe, 2010-01-01 to 2026-04-30, 2075 round-trips).
- The canonical cell-E baseline at `dev/experiments/cell-e-15y-2026-05-07/trades.csv` (2090 trades, Sharpe 0.94) was rejected: its M5.2e audit columns (`entry_stage`, `entry_volume_ratio`, `stop_initial_distance_pct`, `screener_score_at_entry`) are all empty for every row, even though M5.2e was merged in #769 on 2026-05-02 before this 2026-05-07 backtest ran. The audit-writer did not flow data into that run; subsequent backtests from 2026-05-10+ do populate it.
- Substitute run is the same scenario name (`15y-cell-e-stage3-k1-laggard-h2`), same universe and window, 2075 trades vs canonical's 2090 — within 1%. Sharpe is 0.70 vs the canonical's 0.94 — different by enough that this run is NOT a baseline-equivalent for absolute numbers, but the structural per-bucket conclusions (stage uniformity, score-quartile inversion) should generalize.
- **Code**: `trading/analysis/scripts/hold_period_per_stage_analysis/hold_period_per_stage_analysis.ml`.
- **Reproduce**:
  ```
  docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && \
    eval $(opam env) && dune build analysis/scripts/hold_period_per_stage_analysis && \
    _build/default/analysis/scripts/hold_period_per_stage_analysis/hold_period_per_stage_analysis.exe \
    -trades /workspaces/trading-1/dev/backtest/scenarios-2026-05-10-215704/15y-cell-e-stage3-k1-laggard-h2/trades.csv'
  ```

## Exit-trigger composition is invariant across score quartiles

| Bucket | Trigger | Count | % of bucket |
|---|---|---:|---:|
| Q1 (lowest) | stop_loss | 150 | 65.2 |
| Q1 (lowest) | laggard_rotation | 63 | 27.4 |
| Q1 (lowest) | stage3_force_exit | 16 | 7.0 |
| Q2 | stop_loss | 493 | 65.3 |
| Q2 | laggard_rotation | 214 | 28.3 |
| Q2 | stage3_force_exit | 47 | 6.2 |
| Q3 | stop_loss | 179 | 59.9 |
| Q3 | laggard_rotation | 106 | 35.5 |
| Q3 | stage3_force_exit | 14 | 4.7 |
| Q4 (highest) | stop_loss | 550 | 69.5 |
| Q4 (highest) | laggard_rotation | 209 | 26.4 |
| Q4 (highest) | stage3_force_exit | 29 | 3.7 |

The 60-70% stop_loss share holds across all 4 quartiles. Q4 (highest score) tilts a bit more stop_loss-heavy (69.5%); Q3 (mid-high score) tilts more laggard_rotation-heavy (35.5%). No quartile breaks the fast-churn pattern.

## What this means for the plan

1. **P4 as originally framed is closed.** Stage uniformity means there is no "Stage-3 entries to weed out" sub-population. The probe should be marked `done — falsified hypothesis` in the parent plan.

2. **The screener score is a new lead.** Q1 vs Q4 mean-P&L of 1.71% vs 0.74% with the same exit-trigger composition is a 130 bp gap on identical-stage entries. That's strategy-relevant if it replicates on the canonical baseline. **Recommendation:** when the v2 Bayesian sweep finishes (PID 90733), re-run this same per-quartile analysis on its winning config's trade log to confirm. If the inversion holds, propose a follow-up experiment: **invert the score gate** (rank candidates ascending by screener_score for entry selection, capped at min_score=55 or similar).

3. **Audit coverage gap discovered.** The canonical cell-E-15y-2026-05-07 trade log lacks audit columns. We should rerun that scenario (or pin a newer cell-E run that has audit on) before further per-trade decomposition work — otherwise every P1 / P3 / P5 follow-up has to use the 2026-05-10 substitute, which has a different Sharpe.

## What this is NOT

- Not a replacement for P1 (exit-trigger × P&L decomposition) — that still needs to be run. The exit-trigger numbers above are *within-bucket* composition, not the unconditional cross-tab P1 asks for.
- Not a defense of the score-quartile-inversion finding as a tradeable signal until it replicates on a second backtest config.
- Not a recommendation to drop the screener score: ranking still gives us 200-800 candidates per tick that filter to ~30 long entries. The finding only says the score is anti-predictive of *trade outcome conditional on entering* — that's a portfolio-construction signal, not a screener-replacement.
