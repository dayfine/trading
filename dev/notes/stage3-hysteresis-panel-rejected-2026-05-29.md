# Stage3 hysteresis panel re-pin REJECTED (2026-05-29 PM)

**Decision:** Do NOT promote `(hysteresis_weeks=2, stage3_exit_margin_pct=0.02)`
as the Cell-E default on the panel scenarios. The proposed PR-B (panel
re-pin) is abandoned — only this retraction note is being shipped.

**Status:** PR-A (#1362, code knob plumbing) is already merged on main and
remains the correct shape — knob defaults at `hysteresis_weeks=2` and
`stage3_exit_margin_pct=0.0` preserve panel behavior. Panel scenarios stay
pinned at `hysteresis_weeks=1` (explicit override) + default margin=0.0.

## What was tested

Both Cell-E panel scenarios were re-run with the autopsy-recommended values:
- `stage3_force_exit_config.hysteresis_weeks`: 1 → 2
- `stage3_exit_margin_pct`: 0.0 → 0.02 (new knob)

All other Cell-E parameters held fixed
(`max_position_pct_long=0.14`, `max_long_exposure_pct=0.70`,
`min_cash_pct=0.30`, `enable_laggard_rotation=true`,
`laggard_rotation_config.hysteresis_weeks=2`).

Runs were single-thread (parallel=1) via scenario_runner.exe inside
trading-1-dev docker, wall ~5 min (5y) + ~17 min (15y).

## Results — 5y panel `sp500-2019-2023` (IMPROVED)

| Metric | Pre-fix pin | New | Delta | Direction |
|---|---|---|---|---|
| total_return_pct | 50.66 | 54.99 | +4.33pp | ✓ better |
| total_trades | 264 | 257 | -7 | ≈ |
| win_rate | 37.50 | 35.80 | -1.70pp | ≈ |
| sharpe_ratio | 0.56 | 0.61 | +0.05 | ✓ better |
| max_drawdown_pct | 21.56 | 18.04 | -3.52pp | ✓ better |
| avg_holding_days | 40.78 | 41.30 | +0.52 | ≈ |
| open_positions_value | 1,221,041 | 1,544,808 | +27% | ≈ |
| sortino_ratio | 0.75 | 0.84 | +0.09 | ✓ better |
| calmar_ratio | 0.40 | 0.51 | +0.11 | ✓ better |
| ulcer_index | 8.41 | 6.61 | -1.80 | ✓ better |

5y panel cleanly validates the autopsy hypothesis. Every risk-adjusted +
absolute-return axis improves. No regression on any axis.

## Results — 15y panel `sp500-2010-2026` (MATERIALLY REGRESSED)

| Metric | Pre-fix pin | New | Delta | Direction |
|---|---|---|---|---|
| total_return_pct | 341.69 | 228.01 | -113.68pp | ✗ MUCH worse |
| total_trades | 806 | 686 | -120 | ≈ |
| win_rate | 39.08 | 36.88 | -2.20pp | ≈ |
| sharpe_ratio | 0.78 | 0.62 | -0.16 | ✗ worse |
| max_drawdown_pct | 18.36 | 22.83 | +4.47pp | ✗ worse |
| avg_holding_days | 44.68 | 47.92 | +3.24 | ≈ |
| open_positions_value | 3,085,413 | 3,153,724 | +2% | ≈ |
| sortino_ratio | 1.25 | 0.95 | -0.30 | ✗ worse |
| calmar_ratio | 0.52 | 0.33 | -0.19 | ✗ MUCH worse |
| ulcer_index | 7.48 | 9.09 | +1.61 | ✗ worse |

Every risk-adjusted + absolute-return axis regresses materially on the
longer horizon.

## Why we're rejecting (not iterating)

This is the textbook **single-window overfit** pattern that the project
has explicitly committed to reject per:

- `memory/project_continuation_combined_rejected.md` — continuation-buy
  combined-axis tuning won on 5y (Sharpe 0.59→0.73) but lost on 16y
  (0.71→0.68). Same single-window-overfit signature. Was REJECTED.
- `memory/feedback_strategy_mechanic_changes_too_explorative.md` — strategy
  mechanic changes need strong basis; do not iterate explorationally.

The brief allowed up to 3 attempts when the 5y panel regresses. Here the
5y won outright; the regression is purely 15y. The brief's regression
trigger condition (5y Sharpe drop > 0.10 OR Calmar drop > 0.10 OR return
drop > 5pp) was never met. Iterating on alternative knob values
(`(h=3, m=0.05)` tighter, `(h=1, m=0.01)` lighter) is exactly the
explorative search the project policy forbids: each fresh `(h, margin)`
cell would require another ~30 min of panel wall-time, and the 15y
regression direction suggests TIGHTER would be worse — but a single
24-min sweep cell is too noisy a single read to direct further search.
Per the precedent, the right next step is broader horizon coverage
(walk-forward + cross-scenario validation), not finer knob search.

## What the autopsy framework missed

The trade-autopsy diagnostic (PR #1360,
`dev/notes/trade-autopsy-2026-05-29.md`) measured failure modes on a
12-symbol per-symbol Weinstein-stage strategy panel covering 1998-2025.
The autopsy projected `late_reentry + stage3_false_positive` modes
together carry +2734% missed gain (~+8.4% CAGR per symbol).

The 5y panel result corroborates the direction (+4.33pp return ≈ +0.86%
CAGR). The 15y panel directly contradicts it (-113.68pp return ≈ -7.0%
CAGR). The aggregate over both panel windows is net-negative.

What the autopsy projection missed:

1. **Position-level missed gain ≠ portfolio-level missed gain.** The
   autopsy counts the path-not-taken on a per-symbol basis. At the
   portfolio level, capital that doesn't exit on a false-Stage-3 doesn't
   sit waiting for the same symbol to recover — it's deployed into
   different Stage-2 candidates via the laggard-rotation runner. The
   missed-gain on the not-exit side is partially offset by deployed-gain
   on the alternative-symbol side. Net effect at the portfolio level is
   not predictable from per-symbol path counts.

2. **Bear-regime exit timing matters more on long windows.** The 5y
   window 2019-2023 has one significant bear regime (2022) and one sharp
   crash (COVID 2020 Q1). The 15y window adds 2011 sideways, 2015-16
   correction, 2018 Q4 drawdown. In SHARP bears, a 2-week-delayed exit
   is the difference between exiting at the local high and exiting after
   3-8% additional drawdown. The MaxDD increase (18.36 → 22.83) +
   Calmar collapse (0.52 → 0.33) point exactly to this: the strategy
   sat through more bear-regime drawdown than the pre-fix variant.

3. **Asymmetric autopsy signal.** The autopsy measured missed gain on
   exit signals (the "early-exit, missed recovery" failure mode) but
   did not measure missed loss on the same signals (the "late-exit, ate
   the additional drawdown" failure mode). Both are present in the
   data; only the first was visible to the autopsy's recovery-proxy
   classifier.

## What the framework needs

Future autopsy-driven fixes should require:

1. **Walk-forward cross-window validation BEFORE the panel re-pin
   commits.** The 5y vs 15y disagreement is exactly what walk-forward
   should catch. The 12-symbol per-symbol panel is not a substitute
   for portfolio-level walk-forward.
2. **Symmetric autopsy.** The recovery-proxy classifier should be
   extended to also measure drawdown-proxy on the late-exit side. Net
   missed gain = missed-recovery − missed-drawdown-avoidance.
3. **The Calmar primary gate (PR #1359) is doing its job.** On the 15y
   panel the Calmar drop -0.19 well exceeds the -0.05 promote-gate
   threshold. Had this been a `promote_config.sh` candidate, the gate
   would have failed it. Confidence in the gate is reinforced.

## Followups

1. **PR-A (#1362) was a code-only knob plumbing PR with default-preserving
   behavior — no panel impact.** Stays on main; no revert needed. The
   knob remains available for future use.
2. **The autopsy framework itself remains valid as a diagnostic tool.**
   PR #1360 is not retracted; it identified a real per-symbol pattern.
   The fix-projection step is what needs the walk-forward layer.
3. **Late_stage2_admission (autopsy mode 3, +505% missed gain) remains
   open.** Per the autopsy's own ranking it's a smaller-per-trade-impact
   mode but widely distributed. Same caution applies: per-symbol missed
   gain projects poorly to portfolio outcomes; any fix needs walk-forward
   cross-window validation before panel re-pin.
4. **Reconsider the broader-first pivot from May 15
   (`project_strategic_pivot_broader_first.md`).** The pivot framed
   "broader universe + walk-forward CV + ML-discipline tuning" as P0
   over "more knobs". This retraction is a fresh data point that the
   pivot's framing is correct — knob-tuning continues to overfit
   single-window data.

## Files

- This note: `dev/notes/stage3-hysteresis-panel-rejected-2026-05-29.md`
- 5y actual: `dev/backtest/scenarios-2026-05-29-111226/sp500-2019-2023/actual.sexp` (ephemeral, gitignored)
- 15y actual: `dev/backtest/scenarios-2026-05-29-111211/sp500-2010-2026-historical/actual.sexp` (ephemeral, gitignored)
- Panel scenarios (UNCHANGED, still at hysteresis_weeks=1 default margin=0.0):
  - `trading/test_data/backtest_scenarios/goldens-sp500-historical/sp500-2010-2026.sexp`
  - `trading/test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023.sexp`
- `dev/scripts/promote_config.sh` PANEL constants UNCHANGED.

## References

- PR #1362 (PR-A merged) — code knob plumbing
- PR #1360 — trade-autopsy diagnostic
- `dev/notes/trade-autopsy-2026-05-29.md` — diagnostic basis
- `dev/notes/next-session-priorities-2026-05-29-PM.md` §P0 — dispatch brief
- `memory/project_continuation_combined_rejected.md` — prior precedent (5y win, 16y loss → REJECTED)
- `memory/feedback_strategy_mechanic_changes_too_explorative.md` — strategy mechanic changes need strong basis
- `memory/project_strategic_pivot_broader_first.md` — May 15 pivot to broader-universe + walk-forward CV
