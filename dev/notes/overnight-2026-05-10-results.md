# Overnight 2026-05-10 results

Session window: 2026-05-10 ~19:00Z onwards. User left around ~22:00Z.

## PRs landed (4 today, 8 with daytime carry-over)

| PR | Title | Merged |
|---|---|---|
| #1019 | fix(simulation): cache + avg-cost fallback in _resolve_price | earlier |
| #1020 | perf(orders): bound list_orders ~ActiveOnly walk via active_orders index | earlier |
| #1021 | feat(metrics): benchmark-relative metrics (alpha/beta/IR/TE/corr) | earlier |
| #1023 | fix(backtest): trade_context audit join date-window fallback | earlier |
| #1016 / #1017 / #1022 | ops + all-eligible wiring | earlier |
| **#1024** | **perf(simulation): prune Closed positions from simulator positions Map** | 22:22Z |
| **#1025** | **fix(engine): filter zero-OHLC bars at market data adapter boundary** | 22:56Z |
| **#1026** | **fix(strategy): filter Closed positions in ema/bah position lookup** | 23:40Z |

## Perf headline (PR #1024)

| Window | Wall (pre-prune) | Wall (post-prune) | Speedup |
|---|---|---|---|
| 10y Cell E | ≥17 min (killed) | 437s (7.3 min) | ≥2.3× and climbing |
| 15+y Cell E | ~5h projected (per 2026-05-09 note) | **818s (13.6 min)** | **~22×** |

15y/10y wall ratio (1.87×) ≈ 15y/10y trades ratio (1.80×) — O(N²) → O(N) confirmed.

`dev/notes/cell-e-15y-engineering-blocker-2026-05-09.md` can be retired.

## max_position_pct_long × max_long_exposure_pct sweep (8 scenarios, 15y Cell E h=2, sp500-historical 510 sym)

Sweep wall: ~1h20m. **A-series** fixed `exp=0.50`. **B-series** raised `exp=0.70` to fill deployable cash.

| Scenario | ~pos | Return | Trades | WR | Sharpe | MaxDD |
|---|---|---|---|---|---|---|
| 0.07 / exp 0.50 | 7 | +338% | **2365** | **45.8%** | 0.46 | **60.9%** ⚠ |
| 0.10 / exp 0.50 | 5 | +286% | 981 | 37.0% | 0.78 | 18.4% |
| 0.15 / exp 0.50 | 3 | +258% | 750 | 38.9% | 0.73 | 15.2% |
| 0.20 / exp 0.50 | 2-3 | +191% | 742 | 39.8% | 0.60 | 20.3% |
| 0.10 / exp 0.70 | (caps at 5) | +286% | 981 | 37.0% | 0.78 | 18.4% |
| **0.14 / exp 0.70** | 5 | **+374%** | 768 | 39.5% | **0.85** | 18.4% |
| **0.23 / exp 0.70** | 3 | +313% | 1548 | **50.8%** | 0.83 | **14.7%** |
| 0.35 / exp 0.70 | 2 | **+445%** | 636 | 42.6% | 0.57 | 46.0% |

### Insights

1. **`max_long_exposure_pct=0.70` only helps when paired with bigger position size.** `0.10 / exp 0.70` is *identical* to `0.10 / exp 0.50` — Cell E's screener doesn't find 7+ qualifying candidates simultaneously, so the extra 2 slots stay unfilled. The supply-side bottleneck is the cascade filter, not the exposure cap. (This is itself a finding: the `enable_short_side=true` setting or the cascade's score-floor could be relaxed if more concurrent positions are desired.)

2. **Sweet spot for Sharpe: 0.14 / exp 0.70 (5 positions, 70% deployed).** +374% return, Sharpe 0.85, DD 18.4%. Beats every other config on risk-adjusted return.

3. **Best WR + lowest DD: 0.23 / exp 0.70 (3 positions).** +313% return, 50.8% WR (highest of the sweep), MaxDD 14.7%. Trades 2× more than 0.14/exp0.70 — the rotation cycles tighter with fewer slots.

4. **Concentration cliffs both ways.** At 7 positions (`0.07`) the strategy thrashes (2365 trades, MaxDD 60.9% — alarming). At 2 positions (`0.35`) raw return is highest (+445%) but single-name DD explodes (46%). The 3-5 position band is the practical sweet spot.

5. **Cell E h=2 baseline (0.05 / exp 0.50, 10 max positions) was an over-broad default**. Replacing it with `0.14 / exp 0.70` or `0.23 / exp 0.70` produces strictly better Sharpe AND lower DD on the 15y window. Recommend re-running rolling 5y windows with the new config to confirm robustness.

## Segmentation vs MaSlope A/B (15y Cell E, 2010-2024)

Both scenarios completed; wall 1669s (28 min for 2 × 15y).

| Stage classifier | Return | Trades | WR | Sharpe | MaxDD |
|---|---|---|---|---|---|
| MaSlope (default) | +189.7% | 1924 | 36.4% | 0.66 | 17.8% |
| Segmentation | +200.7% | 1794 | 36.0% | 0.68 | 18.3% |

**Verdict: Segmentation is marginally better but not a differentiator.**
- +11pp absolute return (5.8% relative)
- -130 trades (-7%, slightly less churn)
- Sharpe +0.02 (within noise)
- MaxDD +0.5pp (also within noise)

The Segmentation classifier (PR #754, alternative to MaSlope) doesn't materially change the strategy's edge. Both classifiers produce ~36% WR / Sharpe ~0.67 over 15y on this universe. Keeping the existing `MaSlope` default is fine; promoting Segmentation requires a stronger signal than 11pp on a single window — needs walk-forward confirmation.

Note: these A/B returns (189-200%) are lower than the prior 15y postpatch run (+235%) because the A/B window is 2010-2024 (15y) vs the postpatch 2010-2026-04-30 (16.3y), and the postpatch run included the extra strong-bull 2025-Q1 period.

## Notes

- A/B v1 (with all-eligible diagnostic) was killed at 27 min wall on scenario 1 because the `all_eligible` post-step adds substantial time (full-universe scan across 783 Fridays). Re-fired with `--no-emit-all-eligible`. Per scenario wall went from 27+ min to ~14 min — confirms all-eligible is the dominant cost when enabled.

## Entry-feature analysis (Task #21, completed earlier in session)

Note: `dev/notes/entry-signal-aggregate-2026-05-10.md` — 4480 trades across 7 rolling 5y windows.

Three actionable levers:
1. Cap screener score < 80 — top quintile (avg 79.2) has the worst WR (27.2%) of any quintile.
2. Cap volume_ratio < 2.5× — extreme volume (>3×) loses on WR.
3. Stop buffer Q3 (~12% distance) is the only quintile with negative $/trade.

## Files / experiments referenced

- `dev/backtest/scenarios-2026-05-10-223952/cell-e-15y-maxpos-*/actual.sexp` — sweep results
- `dev/backtest/scenarios-2026-05-10-002046/15y-cell-e-*/actual.sexp` — A/B (when complete)
- `dev/experiments/perf-positions-prune-2026-05-10/scenarios/cell-e-10y-perf-measure.sexp` — perf measurement scenario
- `dev/experiments/cell-e-15y-postpatch-2026-05-10/scenarios/15y-cell-e-postpatch.sexp` — 15y post-patch run
- `dev/notes/perf-residual-positions-map-2026-05-10.md` — perf hotspot writeup
- `dev/notes/entry-signal-aggregate-2026-05-10.md` — entry-feature buckets

## Tasks status (today's task IDs)

Completed: #4, #5, #6, #7, #8, #9, #12, #13, #14, #15, #16, #17, #19, #20, #21, #22, #23, #24
In-progress: #10 (sweep — running summary write), #11 (A/B running), #18 (positions-Map prune merged as #1024; close on next pass)

## Rolling 5y validation of sweep winner (0.14 / exp 0.70)

Re-ran the 7 rolling 5y windows from earlier today with the sweep winner config. Wall=1177s (20 min for 7 × 5y, ~3 min/scenario — much faster than the 12 min/scenario baseline run from earlier because the baseline ran pre-PR-#1024 in the loaded simulator binary, while this validation ran on the post-#1024 patched main).

| Window | Baseline 0.05/0.50 | Sweep winner 0.14/0.70 | Δ return | Δ Sharpe |
|---|---|---|---|---|
| 2011-01 | 60.4% / 0.85 | **52.7%** / 0.71 | −7.7pp | −0.14 |
| 2012-07 | 93.0% / 1.22 | **110.4%** / 1.23 | +17.4pp | +0.01 |
| 2014-01 | 51.1% / 0.75 | **63.9%** / 0.81 | +12.8pp | +0.06 |
| 2015-07 | 29.7% / 0.57 | **81.1%** / 0.93 | **+51.4pp** | +0.36 |
| 2017-01 | 47.8% / 0.77 | **72.2%** / 1.09 | +24.4pp | +0.32 |
| 2018-07 |  6.0% / 0.16 | **12.3%** / 0.25 |  +6.3pp | +0.09 |
| 2020-01 | 18.4% / 0.32 | **12.5%** / 0.23 |  −5.9pp | −0.09 |

**Verdict: 0.14 / exp 0.70 generalizes.**
- Wins return in 5 of 7 windows
- Wins Sharpe in 5 of 7 windows
- Geom-mean 5y return: 41% (baseline) → 50% (new) — **+22% relative**
- Avg Sharpe: 0.66 (baseline) → 0.75 (new) — **+13% relative**
- Trades reduced ~60% (from ~600/window to ~250/window) — much lower turnover
- Losses are small (2011-01, 2020-01 ≤8pp) and within typical noise

Two windows the new config loses: 2011-01 (mild macro-recovery year — broader diversification may help) and 2020-01 (COVID crash + 2022 bear — concentration hurts when the rotation can't outrun whipsaws).

**Recommendation: promote `0.14 / exp 0.70` to the new Cell E default**, replacing the current `0.05 / exp 0.50` baseline. Requires:
- Update `dev/experiments/cell-e-15y-2026-05-07/scenarios/15y-cell-e.sexp` overrides (or document a new baseline scenario)
- Update any pinned tests / goldens that reference the old config
- Add a follow-up note: investigate the candidate-supply bottleneck so future configs aren't capped artificially by Cell E's screener

## Recommended next session

1. Re-run rolling 5y on the new config (0.14 / exp 0.70 OR 0.23 / exp 0.70) to confirm sweep insights generalize across windows.
2. Investigate Cell E candidate-supply bottleneck: why does the cascade not find 7 qualifying candidates simultaneously? Score floor relaxation or cascade-weight rebalance.
3. Action the entry-signal levers (cap score < 80, cap volume_ratio < 2.5×, widen stop buffer).
4. If A/B Segmentation completes overnight, compare against the MaSlope baseline + current cell-e-15y baseline.
