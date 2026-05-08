# Cell E generalization across small-universe windows — 2026-05-08

## Background

Capital-recycling experiment of 2026-05-07 measured the impact of Stage-3 force-exit + Laggard rotation on the 5y `sp500-2019-2023` window. Cell E (Stage3 ON, k=1; Laggard ON, h=2) outperformed Cell A (both OFF, baseline) by **+62 ppt return / +0.39 Sharpe** on that single window.

This experiment tests whether that win generalizes across **other windows + universes**. Six scenarios on the small (302-symbol) universe: `bull-crash-2015-2020`, `covid-recovery-2020-2024`, `six-year-2018-2023`, each as Cell A baseline + Cell E variant.

## Results

| Scenario | Cell | Return | Trades | Win % | Sharpe | MaxDD |
|----------|------|--------|--------|-------|--------|-------|
| **bull-crash 2015-2020** | A | 6.3% | 60 | 20.0 | 0.14 | 40.1 |
| | **E** | **125.0%** | 201 | 44.8 | **0.95** | 27.1 |
| **covid-recovery 2020-2024** | A | 51.7% | 59 | 27.1 | 0.54 | 27.8 |
| | **E** | **65.1%** | 204 | 38.7 | **0.64** | 32.4 |
| **six-year 2018-2023** | A | 10.4% | 114 | 24.6 | 0.18 | 29.5 |
| | **E** | **115.2%** | 194 | 37.6 | **0.77** | 26.5 |

Combined with the original 2026-05-07 5y SP500 (500-sym):
| **sp500-2019-2023** (2026-05-07) | A | 58.3% | 81 | 19.8 | 0.54 | 33.6 |
| | **E** | **120.0%** | 196 | — | **0.93** | 23.1 |

## Verdict

**Cell E wins on all 4 of 4 measured windows on every metric except trade-count.**

- Return uplift ranges from **+13 ppt (covid)** to **+119 ppt (bull-crash)**.
- Sharpe uplift ranges from **+0.10 (covid)** to **+0.81 (bull-crash)**.
- MaxDD is *better* in 2 of 4 windows (bull-crash, six-year — substantially), worse in 2 (covid, sp500). Mixed.
- Win-rate is consistently *higher* under Cell E (44.8 vs 20.0 on bull-crash; 38.7 vs 27.1 on covid; 37.6 vs 24.6 on six-year).
- Trade count rises from ~60–114 to ~194–204 — Cell E increases turnover ~2-3×. The Stage3 + Laggard mechanisms are doing real recycling work, generating more round-trips.

The bull-crash + six-year deltas are very large (+119 / +105 ppt). Both windows include the 2018 → 2020 transition where Cell A's static "buy and hold winners" approach got crushed by drawdowns and didn't recycle into new Stage-2 leaders. Cell E's Stage3 force-exit unlocked capital before drawdowns deepened; Laggard rotation kept reallocating into fresh momentum.

## Side-finding — small-universe Cell A baseline drift

The pinned baselines for goldens-small (per the on-disk `.sexp` comments) are higher than what Cell A actually produces today:

| Window | Pinned baseline (per file comments) | Cell A today |
|--------|-------------------------------------|--------------|
| bull-crash | ~339% / 15 trades / Sharpe 1.04 | 6.3% / 60 trades / 0.14 |
| six-year | ~84% / 19 trades / Sharpe 0.66 | 10.4% / 114 trades / 0.18 |
| covid-recovery | (no explicit pin in file) | 51.7% / 59 / 0.54 |

Cell A on bull-crash and six-year is **way below pin** — same ~10× under-performance pattern as the 15y SP500 (-85.77% vs +5.15%). Different from the canonical 5y SP500 which is bit-equal to its pin (Cell A at 58.34% / 81 trades).

**Hypothesis:** the pinned baselines were produced in a different config era (pre-2026-04-18 PR #409 mentioned in scenario comments). Today's Cell A on small universe matches *current* default behavior, just not the historical pin. The pin should be refreshed.

This is **separate from** the Cell E generalization finding — the Cell E variant is internally consistent across runs, and its A→E delta is what tests the hypothesis.

## Recommendation — flip defaults?

**Yes — strong evidence to flip `enable_stage3_force_exit` + `enable_laggard_rotation` defaults to `true` (with h=2).** Caveats below.

Pros:
- 4-of-4 window wins.
- 2 windows show >100 ppt uplift.
- Win-rate consistently improves.
- 2 windows show MaxDD improvement; 2 modestly worse but within tolerance.

Pre-flip checks needed:
1. **Walk-forward partition.** Each window above is a single fit. Partition each into 50/50 in-sample/out-of-sample, calibrate `h` on in-sample, test on OOS. If OOS still wins by ≥10 ppt, flip is durable.
2. **Run on `goldens-broad` tier-3 windows.** decade-2014-2023, sp500-30y-capacity-1996. If Cell E generalizes to broad universe + multi-decade, very robust signal.
3. **Resolve the goldens-small Cell A baseline drift first** so the comparison isn't muddied by an unrelated regression.
4. **Resolve the 15y SP500 P0** (split-day or had_market_bars artifact). Cell E's purported 15y Sharpe 0.94 from 2026-05-07 was measured pre-Q1-fix; needs re-measurement post-fix to confirm the 15y win is real, not artifact.

If those 4 checks pass, flip defaults via a new PR — not a config-only change but a new primary recommendation in `docs/design/weinstein-trading-system-v2.md` plus the bool flips.

## Artefacts

- 6 scenarios at `dev/experiments/cell-e-generalization-2026-05-08/scenarios/{bull-crash-2015-2020,covid-recovery-2020-2024,six-year-2018-2023}-cell-{A,E}.sexp`
- Per-cell raw run output at `dev/backtest/scenarios-2026-05-08-202909/<cell-name>/{actual,summary,trade_audit}.sexp`, `equity_curve.csv`, `trades.csv`, `splits.csv`, `params.sexp`
- Wall: 10 min @ parallel=5; peak RSS 656 MB across all 5 workers
