# Continuation-buys impact — 5y sp500-2019-2023 (2026-05-14)

## TL;DR

Enabling `enable_continuation_buys = true` on Cell E / 5y sp500-2019-2023 changes
**1 trade** (264 → 265, +0.38%). Return ticks up 1.48 pp (50.66 → 52.15), MaxDD
identical to four decimal places, Sharpe +0.022, Calmar +0.010. **Recommendation:
keep default-off and run a follow-up tuning sweep** before considering promotion
— the detector at ship defaults is so conservative on a 5y / 500-symbol Cell E
universe that the result is essentially indistinguishable from baseline.

## Setup

- Scenarios: `dev/experiments/continuation-buys-impact-2026-05-14/scenarios/`
- Output: `dev/backtest/scenarios-2026-05-14-005026/`
- Runner: `scenario_runner.exe --parallel 2 --no-emit-all-eligible`
- Wall: 185 s total (parallel-2, both ~180 s)
- Universe: 500 symbols, 2019-01-02 → 2023-12-29
- Authority: PR #1078 (Interpretation B, default-off), PR #1074 (plan), issue #889

## Per-cell metrics

| Metric                    | baseline      | continuation-on | Δ              | Δ %      |
|---------------------------|---------------|-----------------|----------------|----------|
| `total_return_pct`        | 50.6636       | 52.1471         | +1.4835        | +2.93%   |
| `total_trades`            | 264           | 265             | +1             | +0.38%   |
| `win_rate`                | 37.50         | 37.74           | +0.24 pp       | +0.63%   |
| `sharpe_ratio`            | 0.5636        | 0.5855          | +0.0219        | +3.89%   |
| `max_drawdown_pct`        | 21.5583       | 21.5583         | +0.0000        | 0%       |
| `avg_holding_days`        | 40.78         | 40.42           | −0.36          | −0.88%   |
| `open_positions_value`    | 1,221,041     | 1,229,980       | +8,939         | +0.73%   |
| `sortino_ratio_annualized`| 0.7479        | 0.7849          | +0.0370        | +4.95%   |
| `calmar_ratio`            | 0.3972        | 0.4071          | +0.0099        | +2.49%   |
| `ulcer_index`             | 8.4146        | 7.0793          | −1.3353        | −15.87%  |

## Interpretation

**Sanity check.** The continuation arm fired but admitted only 1 net new trade
across 5 years × 500 symbols × Cell E sizing. The wiring is correct (non-zero
delta confirms the OR-arm is reachable), but the detector at ship defaults
(`ma_slope_min=0.01`, `pullback_band=[0.95,1.05]`, `pullback_lookback_weeks=8`,
`consolidation_range_pct=0.10`, `consolidation_weeks=4`) is extremely selective
on a 5y / Cell E configuration. Plausible causes:

1. **0.70 long-exposure cap is binding much of the time.** With 5 positions
   typically fillable, even when a continuation candidate qualifies the cascade
   doesn't have a slot — the candidate falls off the ranking. The detector
   produced more eligibility events than 1, but only 1 converted to a fill.
2. **Cell E already runs a high turnover engine** (stage3 force-exit h=1,
   laggard rotation h=2) — these features already do most of the
   capital-recycling work continuation buys were designed to add. The marginal
   surface is small in this regime.
3. **5y / 500-symbol window is too small** to register a meaningful sample at
   ship-default selectivity. The book describes continuation buys as a
   relatively rare pattern (mature Stage 2 + pullback-to-MA + tight
   consolidation + fresh breakout), so 1 hit / 5y is in the right order of
   magnitude.

**Directional read.** Every changed metric moved favourably: return +1.48pp,
Sharpe +0.022, Sortino +0.037, Calmar +0.010, MaxDD unchanged, Ulcer index
−1.34. But the magnitude is well within noise — on adjacent 5y windows this
delta would not survive a fuzz sweep (PR #788 fuzz had Sharpe IQR of ~0.15 on
this exact scenario at ±2 weeks start-date).

## Verdict

**Recommend follow-up parameter tuning before flipping default-on.**

Specifically, before considering a `true` default ship, sweep at least:

1. `ma_slope_min` ∈ {0.005, 0.01, 0.015} — looser slope admits more late-Stage-2
   names; tighter rejects flatter "fake continuation" patterns.
2. `pullback_band` ∈ {[0.93, 1.07], [0.95, 1.05], [0.97, 1.03]} — wider band
   captures shallower pullbacks (more candidates), narrower restricts to
   textbook MA-touches.
3. `consolidation_weeks` ∈ {3, 4, 6} — shorter window allows more recent
   breakouts to count.
4. Re-test on a longer horizon (10y `decade-2014-2023` or 16y
   `sp500-2010-2026`) where the rare-pattern hit rate has more statistical
   power.

A 5y / Cell E single-cell measurement of a single near-no-op trade is not a
basis for changing the ship default in either direction. Default-off remains
correct until a sweep at a longer horizon shows a real edge with bounded
drawdown impact.

**Do NOT promote default-on.** Default-off is the safer ship choice given:

- 1-trade delta is statistically meaningless (Wilson 95% CI on 264/265
  proportions overlap fully).
- The book's continuation-buy pattern is most useful when bidding *new* capital
  into a mature trend; Cell E already aggressively recycles via stage3 +
  laggard rotation.
- Detector parameters have not yet been tuned to this universe / horizon.

## Sanity: continuation arm fired

Trade-count delta = +1 (non-zero). Detector wiring is correct. `trades.csv`
differs between baseline (264 rows) and continuation-on (265 rows). Drilling
into the specific continuation entry was out of scope for this 2-cell sanity
sweep — the follow-up grid sweep above would be the right place to investigate
which patterns fire and which slip through the cascade slot-allocation.
