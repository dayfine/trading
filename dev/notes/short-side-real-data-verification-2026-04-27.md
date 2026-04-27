# Short-side bear-window verification on real SP500 broad-data (2026-04-27)

PR #608 follow-up. The agent's investigation conclusion (breadth-data /
ADL composer / macro confidence weighting are the load-bearing blockers)
was based on the 7-symbol synthetic test fixture; this note re-runs on
real broad-data and isolates the actual symptom.

## Setup

- Build: post-#609 main (`7692694e`) + locally-pushed PRs.
- Scenario: `goldens-sp500/sp500-2019-2023.sexp` — 491-symbol S&P 500
  snapshot × 5y (2019-01-02 – 2023-12-29). Includes COVID crash (2020 H1),
  V recovery, full 2022 bear, 2023 leadership rotation.
- Run: `_build/default/trading/backtest/scenarios/scenario_runner.exe
  --dir trading/test_data/backtest_scenarios/goldens-sp500`
  with `OCAMLRUNPARAM=o=60,s=512k`.
- Wall: 2:26. Peak RSS: 2,131 MB.
- Output: `dev/backtest/scenarios-2026-04-27-064628/sp500-2019-2023/`.

## Backtest result

| Metric | Value |
|---|---:|
| Round-trips | 133 |
| Total return | +18.5 % |
| Win rate | 28.6 % |
| Max drawdown | 47.6 % |
| Sharpe | 0.26 |
| CAGR | 3.10 % |

## Trade-side decomposition (the question)

Schema: `symbol,entry_date,exit_date,days_held,entry_price,exit_price,quantity,pnl_dollars,...`.
Negative `quantity` = short.

| Bucket | Count |
|---|---:|
| All trades | 133 |
| **Short** | **0** |
| Long | 133 |

By entry-year × side:

| Entry year | LONG | SHORT |
|---|---:|---:|
| 2019 | 25 | 0 |
| 2020 | 15 | 0 |
| 2021 | 9 | 0 |
| **2022 (bear)** | **37** | **0** |
| 2023 | 47 | 0 |

Note the 37 long entries opened in 2022 — i.e. the strategy is opening
new long positions during the deepest bear year in the window. That's
the same symptom #608 was trying to fix.

## Macro-layer behaviour on real data (unit-level)

`analysis/weinstein/macro/test/test_macro_e2e.ml::test_macro_2022_bear_market`
**passes**: `Macro.analyze` on real GSPC weekly bars (cached, real
`Test_data_loader`) through 2022-10-14 with **empty `ad_bars` and empty
`global_index_bars`** returns:

- `trend = Bearish`
- `confidence < 0.5` (well into the Bearish region; threshold is `< 0.35`)
- `index_stage` derived from real GSPC alone is enough to drive the
  composite Bearish.

So the three #608-hypotheses fail at the unit level:

| #608 hypothesis | Status |
|---|---|
| (a) GSPC slope threshold too tight for 2022 | **REFUTED** — Stage classifier alone yields Bearish on real 2022 GSPC. |
| (b) Synthetic ADL not in worktree / breadth blocker | **REFUTED** — Macro returns Bearish even with ad_bars=[]. The composer fix is unrelated to this symptom. |
| (c) Macro confidence weighting too lax | **REFUTED** — composite confidence < 0.5 on real data; well below the 0.35 Bearish threshold. |

## Where the actual bug is

Upstream macro returns Bearish during 2022. Downstream the live cascade
emits 0 short candidates AND keeps emitting long candidates (37 in 2022).
The disconnect lives in one of:

1. **Short-side gating in screener cascade** — short-candidate emission
   may be gated on a different condition than `macro.trend = Bearish`
   (e.g. requires Stage 4 on the individual symbol AND something else
   that's not firing).
2. **Position sizing / risk gates** — shorts may be filtered by
   exposure limits, sector concentration, or a config default that
   silently disables short emission in this scenario.
3. **Long-candidate veto on Bearish macro is not wired** — the system
   should *suppress* longs when macro is Bearish; 37 long entries in
   2022 say it's not. So both directions of the bear-window contract
   are broken: shorts not emitted AND longs not suppressed.

The 7-symbol synthetic-fixture run the original agent used did not have
real GSPC bars in the index slot, so its macro never registered Bearish,
which masked the *real* downstream bug. Fixing the fixture's GSPC stub
won't address what's broken in the live cascade.

## Recommendation

- Close PR #608 (its diagnosis premise is wrong).
- Open a fresh issue scoped to the actual wedge: "Bear-window contract
  not enforced — macro=Bearish does not suppress longs nor emit shorts
  in live cascade". Repro is this scenario; assertion is that 2022
  long-entries should drop substantially and short-entries should be
  > 0.
- The fix likely lives in the screener cascade or the `Weinstein_strategy`
  signal-emission path, not in `Macro` / `Stage` / `Ad_bars`.

## Output dir

`dev/backtest/scenarios-2026-04-27-064628/sp500-2019-2023/`
(`trades.csv` 10 KB, `equity_curve.csv` 28 KB, `summary.sexp`,
`actual.sexp`, `params.sexp`).
