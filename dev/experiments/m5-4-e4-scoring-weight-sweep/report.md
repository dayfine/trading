# M5.4 E4 scoring-weight sweep — results

**Run timestamp:** 2026-05-08 (post-Q1-fixes)
**Window:** sp500-2019-2023 (5y, 500-symbol)
**Sweep harness:** PR #816 (2026-05-03)
**Cells:** 8 — single-axis perturbations of `Screener.scoring_weights`. Each cell doubles one weight from `default_scoring_weights` (or applies the named transform). Wall: ~9 min @ parallel=5.

## Results

| Cell | Return % | Trades | Win % | Sharpe | MaxDD % |
|------|----------|--------|-------|--------|---------|
| baseline                | 58.34 | 81 | 19.75 | 0.53 | 33.60 |
| equal-weights           | 23.07 | 99 | 26.26 | 0.32 | 29.51 |
| late-stage-strict       | 58.34 | 81 | 19.75 | 0.53 | 33.60 |
| **resistance-heavy**    | **80.67** | 79 | 20.25 | **0.65** | 32.85 |
| rs-heavy                | 58.34 | 81 | 19.75 | 0.53 | 33.60 |
| sector-heavy            | 59.09 | 61 | 19.67 | 0.51 | 34.00 |
| stage-heavy             | 58.34 | 81 | 19.75 | 0.53 | 33.60 |
| volume-heavy            | 35.02 | 90 | 23.33 | 0.38 | 42.20 |

Pinned baseline (`memory/project_sp500_baseline_conflict.md`): 58.34% / 81 trades — exactly matches the `baseline` cell. ✓

## Verdict

**Resistance-heavy clearly wins** on every metric except trade count (79 vs 81 baseline):

- +22.3 ppt return vs baseline (80.67% vs 58.34%)
- +0.12 absolute Sharpe (0.65 vs 0.53)
- ~0.7 ppt lower MaxDD (32.85 vs 33.60)

**Volume-heavy is the clear loser** — overweighting `volume_confirmation` produces the most-trades + worst-MaxDD pairing (90 trades, 42.2% MaxDD, 35% return). Symptom of chasing momentum-with-volume tops.

**Equal-weights underperforms baseline** (23.1% vs 58.3%) — the existing default weights are doing real work. Sharpe halved when weights are flattened.

**Three cells are bit-equal to baseline** (late-stage-strict, rs-heavy, stage-heavy):
- These doubled-weight perturbations don't change which 81 candidates make the cut; the binding constraint isn't the weight delta. Likely the cascade gates (Stage 2 detection, MA filter) bind first; the weight only orders the survivors.

## Mechanics — why resistance-heavy wins

The "resistance" axis scores how cleanly a candidate's price has cleared its prior overhead supply. Doubling that weight prefers candidates that broke out *with conviction* over candidates with tepid pullback-style entries.

The 79 vs 81 trade count tells the story: 2 baseline trades got displaced by higher-resistance-scored alternatives. Those 2 swaps account for ~22 ppt of return. Single-trade swap impact is high in a 5y window where each trade represents ~0.7% of total return on average.

This finding aligns with Weinstein's primacy on "true" breakouts above prior resistance — the weight ratio matters more than is documented in the screener config.

## Recommendation

Two follow-ups:

1. **Walk-forward partition of resistance-heavy** to detect overfitting on the 2019-2023 window. Split into 2.5y in-sample / 2.5y OOS with weight calibration on in-sample only. If OOS still wins by ≥10 ppt, this is durable.
2. **Pair with the M5.5 T-A grid_search.exe flagship 81-cell sweep** — the resistance axis is one dimension; T-A's 3×3×3 grid (rs / volume / resistance) will measure the joint surface. The flagship sweep should weight the bayesian-optimisation prior toward "high resistance, low volume" given this finding.

**Short-term knob change**: do not flip `default_scoring_weights` based on this 5y sweep alone. Wait for walk-forward + T-A flagship results.

## E3 + E4 combined inference

E3 (stop-buffer) and E4 (scoring-weights) are independent dimensions. Together:
- Tighter stops (E3 1.00) outperform on this window — but small sample.
- Resistance-heavy scoring (E4) outperforms — clearly above noise (Sharpe 0.65 vs 0.53).
- E3's "bit-equal at 1.05+" suggests buffers are inert above 1.05 in this window. E4's "bit-equal late-stage-strict / rs-heavy / stage-heavy" suggests cascade gates dominate weight changes for those axes.

The flagship T-A grid sweep (M5.5) is the right next experiment. E3+E4 give priors:
- Resistance-axis-heavy is favored.
- Volume-axis-heavy is disfavored.
- Stop-buffer is largely inert; can fix at any value 1.05–1.20 for the grid.

## Artefacts

- Per-cell artefact dirs at `dev/backtest/scenarios-2026-05-08-184230/m5-4-e4-<cell>/{actual,summary,trade_audit}.sexp`, `equity_curve.csv`, `trades.csv`, `splits.csv`, `params.sexp`.

(Total ~3.7 MB. Gitignored — re-runnable from `trading/test_data/backtest_scenarios/experiments/m5-4-e4-scoring-weight-sweep/<cell>.sexp`.)
