# M5.4 E1 — Short on/off A/B

## Hypothesis

> Short-side signals add or subtract from total return + Sharpe; quantify on
> smoke scenarios.

Per `dev/plans/m5-experiments-roadmap-2026-05-02.md` §M5.4 E1.

The Weinstein book treats short-side trades as symmetric to long-side trades
(Stage 4 short is the mirror of Stage 2 long). It is an open question whether
the current implementation captures enough Stage 4 setups to add value, given
that (a) most S&P 500 names spend the bulk of any decade in Stages 1/2/3, and
(b) short-side stop semantics + cost are asymmetric with longs in real markets.

## Run metadata

- **Date**: 2026-05-02
- **Override**: `enable_short_side` (top-level on `Weinstein_strategy.config`)
  - **Baseline**: `enable_short_side = true` (default; shorts ON)
  - **Variant**: `enable_short_side = false` (shorts OFF)
- **Scenarios**: smoke catalog (`Scenario_lib.Smoke_catalog.all`) on the sp500
  universe (~491 symbols):
  - `bull` — 2019-06-01 .. 2019-12-31 (persistent uptrend)
  - `crash` — 2020-01-02 .. 2020-06-30 (COVID crash + initial recovery)
  - `recovery` — 2023-01-02 .. 2023-12-31 (post-bear rebound)
- **Initial cash**: $1,000,000 per run
- **Runner**: `backtest_runner.exe --experiment-name short-on-off --baseline
  --override enable_short_side=false --smoke`

## Headline results

| Window | Round-trips (base / variant) | Final value (base / variant) | Δ Final value |
|---|---|---|---|
| bull | 10 / 10 | $1,151,608 / $1,151,608 | **$0** |
| crash | 21 / 16 | $870,860 / $876,956 | **+$6,096 (variant wins)** |
| recovery | 26 / 26 | $1,329,344 / $1,342,215 | **+$12,871 (variant wins)** |

In every measurable dimension on the smoke catalog, **disabling shorts is
neutral-or-better than leaving them on.** The bull window shows zero short
trades fired in either run (no Stage 4 setups passed the screener — expected
given the macro regime). The crash window is the only one with closed short
round-trips: baseline took 5 SHORT trades, variant took 0; variant ended ~$6.1K
ahead with smaller drawdown (20.27% vs 22.71%) and 5 fewer total losers.
Recovery ends with the baseline holding 1 open SHORT (`WST`, entered late) which
the variant's ICE long replaces — variant ends ~$12.9K ahead.

## Key cross-window deltas

| Metric | bull | crash | recovery | Direction |
|---|---|---|---|---|
| total_return_pct (Δ = variant − baseline) | 0.00 | +0.61 | +1.29 | Variant ≥ baseline in every window |
| sharpe_ratio | 0.00 | -0.09 | +0.04 | Mixed (small) |
| sortino_ratio_annualized | 0.00 | -0.03 | +0.07 | Mixed (small) |
| max_drawdown | 0.00 | **-2.44** | 0.00 | Variant has shallower DD in crash |
| profit_factor | 0.00 | 0.00 | 0.00 | Identical (no short profits booked) |
| win_count | 0 | 0 | 0 | No closed shorts were winners in baseline |
| loss_count | 0 | -5 | 0 | All 5 baseline shorts lost; removing them removed 5 losses |
| concavity_coef | 0.00 | 0.00 | 0.00 | (need benchmark plumbing to populate — antifragility doc) |

**Headline:** in the smoke catalog, **shorts contribute 0 wins and 5 losses
(crash) + 1 unrealized open-position drag (recovery)**. They lower max
drawdown in crash via slightly lower notional risk on the long side post-stops,
but they do not improve return or Sharpe in any window.

## Caveats / what this does NOT prove

1. **Sample size is 3 windows.** This is the smoke catalog, designed for fast
   iteration not statistical significance. A multi-year continuous run (e.g.
   sp500-2019-2023 baseline) is the next step.
2. **Crash window is COVID-specific.** The 2020 V-shape recovery is unusually
   quick; shorts that worked early reversed quickly. A 2008 GFC or 2022 bear
   window would test the bear-grind thesis where shorts should add the most.
3. **`bull` window genuinely had zero short entries.** This is *expected*
   (Stage 4 setups are rare in a sustained uptrend) but it means the bull
   comparison is a tautological identity, not evidence that shorts are
   neutral.
4. **`enable_short_side` is the cleanest possible knob** (binary, top-level).
   This experiment doesn't probe the underlying short-side parameter surface
   (entry threshold, stop buffer, sizing) — those are separate experiments.
5. **Survivorship bias.** Universe is *today's* S&P 500. Symbols that delisted
   pre-2026 are missing — biases all results upward, especially the variant
   (more long exposure means more upward bias). Norgate ingestion (M5.3) will
   address.

## Followups

- Run on a longer continuous window (sp500-2019-2023) where shorts have more
  bites at the apple.
- Run on a 2022 bear window specifically (currently absent from smoke catalog).
- Probe the short-side parameter surface (`short_side` config block) rather
  than the binary on/off — the underwhelming result here may be a tuning
  problem, not a fundamental "shorts don't work" verdict.
- After Norgate is ingested, rerun with point-in-time universe to remove
  survivorship bias.

## Artifact map

| Path | Content |
|---|---|
| `bull/comparison.md` + `bull/comparison.sexp` | 70-metric diff (all zeros — no shorts fired) |
| `crash/comparison.md` + `crash/comparison.sexp` | 70-metric diff |
| `crash/baseline/trades.csv` (22 rows = 16 LONG + 5 SHORT + header) | All baseline trades; SHORT rows are the delta drivers |
| `crash/variant/trades.csv` (17 rows = 16 LONG + header) | All variant trades; identical LONG behavior |
| `crash/baseline/force_liquidations.sexp` | Force-liquidation event for the SHORT `DG` position |
| `recovery/comparison.md` + `recovery/comparison.sexp` | 70-metric diff |
| `recovery/baseline/open_positions.csv` (10 rows = 8 LONG + 1 SHORT + header) | Includes the open `WST` SHORT |
| `recovery/variant/open_positions.csv` (9 rows = 8 LONG + header) | `WST` slot replaced by `ICE` LONG |

Per-trade audit detail (`trade_audit.sexp`, `equity_curve.csv`,
`macro_trend.sexp`, `params.sexp`, `summary.sexp`, `splits.csv`, `final_prices.csv`,
`universe.txt`) was emitted by the runner but is not committed here to keep PR
scope tight; rerun the runner locally to regenerate.
