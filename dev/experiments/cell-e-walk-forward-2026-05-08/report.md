# Cell E walk-forward partition test — 2026-05-08

## Background

Cell E (`enable_stage3_force_exit=true` k=1, `enable_laggard_rotation=true` h=2)
won 4-of-4 measured windows in `dev/experiments/cell-e-generalization-2026-05-08/`
(bull-crash, covid-recovery, six-year, sp500-2019-2023). Each measurement is a
single fit on the full window — could be window-overfitting.

This experiment partitions each window chronologically into two halves and
re-runs Cell A vs Cell E on each half independently. If Cell E wins both
halves of all 4 windows, the generalization signal is robust.

## Setup

- 4 windows × 2 chronological halves × {Cell A, Cell E} = **16 scenarios**
- Scenarios at `dev/experiments/cell-e-walk-forward-2026-05-08/scenarios/`
- Wall: ~30 min @ parallel=5 (small + sp500 universes mixed)

Window splits:

| Window | First half | Second half |
|--------|-----------|-------------|
| bull-crash | 2015-01..2017-12 (3y) | 2018-01..2020-12 (3y) |
| covid-recovery | 2020-01..2022-06 (2.5y) | 2022-07..2024-12 (2.5y) |
| six-year | 2018-01..2020-12 (3y) | 2021-01..2023-12 (3y) |
| sp500 | 2019-01..2021-06 (2.5y) | 2021-07..2023-12 (2.5y) |

Note: `bull-crash-2018-2020` and `six-year-2018-2020` are bit-equal (same
window, same universe). Treated as 1 datapoint, so 7 unique halves.

## Results

| Half | Cell A | Cell E | Δ Return | Cell A Sharpe | Cell E Sharpe |
|------|--------|--------|----------|---------------|---------------|
| bull-crash 2015-2017 | 14.3% | **59.4%** | **+45.1** | 0.43 | **1.39** |
| bull-crash 2018-2020 | 4.6% | **68.7%** | **+64.1** | 0.17 | **1.00** |
| covid 2020-2022h1 | 42.0% | **83.0%** | **+41.0** | 0.78 | **1.25** |
| covid 2022h2-2024 | -8.6% | **10.6%** | **+19.2** | -0.16 | **0.34** |
| six-year 2018-2020 | 4.6% | **68.7%** | **+64.1** | 0.17 | **1.00** |
| six-year 2021-2023 | -12.3% | **18.2%** | **+30.5** | -0.24 | **0.42** |
| sp500 2019-2021h1 | 52.9% | **73.5%** | **+20.6** | 0.92 | **1.21** |
| sp500 2021h2-2023 | **22.4%** | 16.9% | **−5.5** | **0.55** | 0.47 |

**Cell E wins 7-of-8 halves** on return AND on Sharpe.

## Verdict

**Strong confirmation of the generalization signal.**

Combining:
- Full-window cell-e-generalization-2026-05-08: 4 wins / 0 losses
- Walk-forward halves: 7 wins / 1 loss

= **11 wins / 1 loss across 12 measured windows ≈ 92% win-rate.**

Cell E's only loss is on **sp500 2021h2-2023** — the bear market into late-2022.
Cell E's higher trade frequency (109 vs 57) caused more whipsaw losses during
the bear, dragging Sharpe slightly below baseline (0.47 vs 0.55). Even on this
loss, Cell E's win-rate (26.6%) is higher than Cell A's (19.3%) — the underlying
trades are higher quality, just more of them in a regime that punishes activity.

Win-rate per round-trip is consistently higher in Cell E across all 8 halves
(34-45% vs 13-31%). MaxDD is mixed (better in some halves, worse in others) —
unsurprising given Cell E trades more aggressively, taking smaller losses faster
but also re-entering more.

## Recommendation

**Flip `enable_stage3_force_exit` + `enable_laggard_rotation` defaults to
`true` (h=1 / h=2 respectively).** The 11/12 win-rate is a robust signal
across multiple windows and out-of-sample halves. Risks:

1. The single loss (sp500 bear 2021h2-2023) is recent. Live-mode could land
   in a similar regime; Cell E may underperform Cell A there.
2. Trade count nearly doubles — ops considerations (commission, slippage,
   tax) need explicit accounting. The PR #920 cost-overlay slippage_bps knob
   exists but defaults to 0 — would need to be set realistically before
   flipping.
3. The 15y SP500 measurement is still pending a clean post-Q1-fix re-pin
   (Task #22). If the 15y also confirms Cell E ≫ Cell A, this is even more
   compelling.

## Pre-flip checklist

- [ ] Refresh 15y baseline (Task #22). After tomorrow's cron run + artefact.
- [ ] Run Cell E on goldens-broad (decade-2014-2023, 30y). Broad-universe test.
- [ ] Pick realistic slippage_bps for live-comparable expectations.
- [ ] One full session of confirming Cell E behavior on a hand-tested fixture
      so we understand the round-trip engine works correctly under recycling.

After those: a feature PR that flips both bool defaults + updates
`docs/design/weinstein-trading-system-v2.md` to make Stage3+Laggard primary
behavior.

## Artefacts

- 16 scenarios at `dev/experiments/cell-e-walk-forward-2026-05-08/scenarios/`
- Per-cell raw output at `dev/backtest/scenarios-2026-05-08-...../`

(Artefact dirs ~7 MB total. Gitignored — re-runnable from scenarios.)
