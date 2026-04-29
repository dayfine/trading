# goldens-broad long-only baselines (2026-04-29)

First canonical baseline for the four `goldens-broad/*.sexp` cells, captured
with `enable_short_side = false` to mirror the mitigation already applied to
`goldens-sp500/sp500-2019-2023` in PR #682. These long-only numbers replace
the prior `BASELINE_PENDING` wide ranges; expected ranges are now tightened
to ±~15 % around each measured value.

## Why long-only

`dev/notes/short-side-gaps-2026-04-29.md` documents four short-side gaps
(G1-G4) — short stops fire with the wrong direction, `Metrics.extract_round_trips`
is blind to shorts, the cash floor only fires on Buy, and there is no
force-liquidation mechanism. Together these produce wildly broken metrics
(negative returns, MaxDD > 100 %, portfolio_value going negative on multiple
days) any time a scenario crosses a Bearish-macro window — which all four
goldens-broad cells do (2018 Q4, 2020 Q1, 2022).

PR #682 disabled shorts on the sp500 cell; today's runs of the 6y + 10y
goldens-broad cells (PR #683) confirmed the same pathology there. Until
G1-G4 close, all five goldens (`sp500-2019-2023` and the four broad cells
below) run long-only so the benchmark is stable.

## Per-cell baseline (measured 2026-04-29)

Each cell was run twice (once to measure, once to validate the tightened
ranges). 3/4 cells were bit-identical between runs; **decade-2014-2023 was
the only cell to drift** (see "Determinism" below).

| Cell | Period | Return | Trades | WinRate | Sharpe | MaxDD | AvgHold | UnrealPnL | CAGR | Calmar | Peak RSS | Wall |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bull-crash-2015-2020 | 2015-01 - 2020-12 (6y) | +148.77 % | 91 | 39.56 % | 0.508 | 62.91 % | 61.0 d | $2.39 M | 14.88 % | 0.24 | 1,650 MB | 2:33 |
| covid-recovery-2020-2024 | 2020-01 - 2024-12 (5y) | +15.12 % | 149 | 20.81 % | 0.238 | 75.30 % | 61.1 d | $1.12 M | 2.56 % | 0.03 | 1,693 MB | 2:50 |
| six-year-2018-2023 | 2018-01 - 2023-12 (6y) | +35.34 % | 167 | 37.13 % | 0.301 | 74.86 % | 72.6 d | $1.18 M | 4.72 % | 0.06 | 1,722 MB | 3:00 |
| decade-2014-2023 (run-1, single-cell) | 2014-01 - 2023-12 (10y) | +1582.85 % | 145 | 40.69 % | 0.960 | 94.31 % | 103.3 d | $15.91 M | 30.64 % | 0.32 | 1,956 MB | 4:31 |
| decade-2014-2023 (run-2, batch-of-4) | 2014-01 - 2023-12 (10y) | +1627.09 % | 135 | 40.00 % | 0.960 | 94.84 % | 98.0 d | $16.66 M | 30.96 % | 0.33 | ~1,950 MB | ~4:30 |
| decade-2014-2023 (run-3, single-cell) | 2014-01 - 2023-12 (10y) | +1582.85 % | 145 | 40.69 % | 0.960 | 94.31 % | 103.3 d | $15.91 M | 30.64 % | 0.32 | ~1,950 MB | ~4:30 |

For comparison, the long-only sp500-2019-2023 baseline (the seed cell) is
+18.49 % return / 133 trades / 28.6 % win rate / 0.26 Sharpe / 47.6 % MaxDD
on a 5y window — see `dev/notes/sp500-golden-baseline-2026-04-26.md`.

### Determinism

3 of 4 cells reproduce to the last decimal across reruns:
- **bull-crash-2015-2020**: identical (return 148.77232406999994, trades 91,
  Sharpe 0.50756142149975014 → 0.50756142149975081 — final-decimal float
  noise, but everything else bit-identical).
- **covid-recovery-2020-2024**: identical to last decimal.
- **six-year-2018-2023**: identical to last decimal.

**decade-2014-2023 is non-deterministic.** Three independent runs produced
two different outcomes:

- run-1 (initial baseline): 145 trades / +1582.85 % / 40.69 % WR / 103.3 d /
  $15.91 M unrealized.
- run-2 (validation rerun, batch with the other 3 cells): 135 trades /
  +1627.09 % / 40.00 % WR / 98.0 d / $16.66 M unrealized.
- run-3 (final validation against tightened decade ranges): 145 trades /
  +1582.85 % / 40.69 % WR / 103.3 d / $15.91 M unrealized — **bit-identical
  to run-1**.

Pattern: run-1 + run-3 cluster (both ran on a single-scenario `--dir`
launch); run-2 was the outlier (ran in a 4-scenario batch alongside
bull-crash + covid + six-year, all in the same `--dir`). Suspicion
strengthens around scenario-execution-order non-determinism — when the
runner forks scenarios sequentially from the same parent process, the
parent's heap state at fork time may differ depending on which prior
scenarios it loaded. The other 3 cells stay deterministic because their
horizons are short enough that the heap-state divergence doesn't surface
before the run ends.

Likely cause: hashtable iteration-order divergence in the screener / candidate
selection accumulating over the longer 10y horizon. The shorter 5-6y cells
may not run long enough for divergent paths to actually fork (they pick the
same trades because the early-window state matches). This is **NOT** a
short-side issue — both runs were long-only. Source needs nailing down
before tighter pinning is feasible; I am NOT going to chase it down in this
PR. Decade ranges below are widened to encompass both observed runs +
~10 % headroom.

Followup item: trace the source of decade non-determinism. Suspects in
priority order:
1. `Hashtbl.iteri` over `ticker_sectors` or `stop_states` in the
   strategy / screener path (Core's `Hashtbl` uses randomized seed unless
   explicitly built with a deterministic seed).
2. `Time_ns_unix.now()` reads in audit-record construction.
3. Order-set iteration in the simulator's per-day fill loop.

## Cross-cell observations

1. **MaxDD is structurally high across every multi-year long-only window.**
   62.9 % (bull-crash), 74.9 % (six-year), 75.3 % (covid-recovery), and
   94.3 % (decade) all exceed any reasonable risk budget. The strategy
   does not go to cash in 2018 Q4, 2020 Q1, or 2022 — it stays long
   through the drawdown and leans on individual-position trailing stops
   to bleed exposure. With shorts disabled there is no offsetting positive
   carry.

2. **The decade cell's 94 % MaxDD is the headline finding.** A +1582.9 %
   return with 94 % drawdown means the equity curve compounds aggressively
   then gives back nearly everything in 2022 before recovering by 2023.
   This is consistent with a heavy concentration in late-2021 winners
   that traded down hard in the 2022 bear, where individual stops did
   fire but were bigger than the portfolio's risk budget could absorb.
   Sharpe 0.96 / Calmar 0.32 says the strategy compounds well *despite*
   the drawdown — an investor with infinite stomach is rewarded.

3. **Win rates fan out wildly: 20.8 % (covid) - 40.7 % (decade).** All
   well below Weinstein's expected 40-50 %. The covid-recovery cell's
   20.8 % is the worst — most entries during 2020-2022 chop got
   shaken out before the trend established.

4. **Return scaling is highly nonlinear with horizon.** Bull-crash 6y
   does +148 %, six-year 6y does +35 %, covid 5y does +15 % — same
   universe, similar lengths, dramatically different outcomes depending
   on whether the window starts in a Stage-2 advance (2015) vs a
   Stage-1/4 transition (2018, 2020). The strategy is path-dependent on
   regime at start.

5. **Decade MaxDD (94.3 %) hits the 100 % cap for re-pin tolerance.**
   The decade cell's `max_drawdown_pct` upper bound is set to 100.0
   rather than +10 % above 94.3 (which would be 103.7) because MaxDD
   cannot exceed 100 %. The lower bound 85.0 (-10 %) is the meaningful
   regression gate.

6. **No cell shows obviously broken metrics — these are real long-only
   results.** The MaxDDs are alarming but consistent with a "leave the
   strategy alone, hold through drawdowns" backtest with no shorts and
   no portfolio-level stop. They are the right baseline to lock in for
   the upcoming short-side rework.

## Reproduction

Each cell was run independently in `trading-1-dev` from the `feat/goldens-broad-long-only-baselines`
worktree, with the canonical sexp (long-only override applied):

```sh
# Build runner once
dev/lib/run-in-env.sh dune build trading/backtest/scenarios/scenario_runner.exe

# For each cell <NAME> in {bull-crash-2015-2020, covid-recovery-2020-2024,
#                          six-year-2018-2023, decade-2014-2023}:
docker exec trading-1-dev bash -c \
  "mkdir -p /tmp/cell-XYZ && \
   cp /workspaces/trading-1/trading/test_data/backtest_scenarios/goldens-broad/<NAME>.sexp /tmp/cell-XYZ/"

docker exec trading-1-dev bash -c \
  "cd /workspaces/trading-1/trading && eval \$(opam env) && \
   OCAMLRUNPARAM=o=60,s=512k \
   /usr/bin/time -v \
   _build/default/trading/backtest/scenarios/scenario_runner.exe \
     --dir /tmp/cell-XYZ \
     --fixtures-root /workspaces/trading-1/trading/test_data/backtest_scenarios"
```

GC tuning (`OCAMLRUNPARAM=o=60,s=512k`) matches the sp500 baseline run.

## Pinned ranges

Tolerance pattern (matches sp500-2019-2023 pre-#682 shape):

- `total_return_pct`: ±15 % relative
- `total_trades`: ±10 absolute
- `win_rate`: ±15 % relative
- `sharpe_ratio`: small absolute, wider relative band (~±50 %)
- `max_drawdown_pct`: ±10 % relative (capped at 100.0)
- `avg_holding_days`: ±10 % relative
- `unrealized_pnl`: ±15 % relative

Concrete ranges per cell (from each sexp):

### bull-crash-2015-2020

```
(total_return_pct   ((min 126.0)        (max 172.0)))     ;; ±15% around 148.8
(total_trades       ((min 81)           (max 101)))       ;; ±10 around 91
(win_rate           ((min 33.5)         (max 45.5)))      ;; ±15% around 39.6
(sharpe_ratio       ((min 0.25)         (max 0.75)))      ;; small absolute, wider relative
(max_drawdown_pct   ((min 56.5)         (max 69.5)))      ;; ±10% around 62.9
(avg_holding_days   ((min 55.0)         (max 67.5)))      ;; ±10% around 61.0
(unrealized_pnl     ((min 2030000.0)    (max 2760000.0))))   ;; ±15% around 2.39M
```

### covid-recovery-2020-2024

```
(total_return_pct   ((min 12.5)         (max 17.5)))     ;; ±15% around 15.1
(total_trades       ((min 139)          (max 159)))      ;; ±10 around 149
(win_rate           ((min 17.5)         (max 24.0)))     ;; ±15% around 20.8
(sharpe_ratio       ((min 0.10)         (max 0.40)))     ;; small absolute, wider relative
(max_drawdown_pct   ((min 67.5)         (max 83.0)))     ;; ±10% around 75.3
(avg_holding_days   ((min 55.0)         (max 67.5)))     ;; ±10% around 61.1
(unrealized_pnl     ((min 955000.0)     (max 1295000.0))))   ;; ±15% around 1.12M
```

### six-year-2018-2023

```
(total_return_pct   ((min 30.0)         (max 41.0)))     ;; ±15% around 35.3
(total_trades       ((min 157)          (max 177)))      ;; ±10 around 167
(win_rate           ((min 31.5)         (max 42.7)))     ;; ±15% around 37.1
(sharpe_ratio       ((min 0.15)         (max 0.45)))     ;; small absolute, wider relative
(max_drawdown_pct   ((min 67.5)         (max 82.5)))     ;; ±10% around 74.9
(avg_holding_days   ((min 65.0)         (max 80.0)))     ;; ±10% around 72.6
(unrealized_pnl     ((min 999000.0)     (max 1352000.0))))   ;; ±15% around 1.18M
```

### decade-2014-2023

Widened to encompass BOTH observed runs (run-1 + run-2) + ~10 % headroom.
This cell is non-deterministic (see "Determinism" above).

```
(total_return_pct   ((min 1300.0)       (max 1900.0)))   ;; encompass 1582.9 + 1627.1, ±10% headroom
(total_trades       ((min 125)          (max 160)))      ;; encompass 135 + 145, ±10 headroom
(win_rate           ((min 34.0)         (max 47.0)))     ;; encompass 40.0 + 40.7, ±15% headroom
(sharpe_ratio       ((min 0.65)         (max 1.30)))     ;; small absolute, wider relative
(max_drawdown_pct   ((min 84.0)         (max 100.0)))    ;; encompass 94.3 + 94.8 (capped at 100)
(avg_holding_days   ((min 88.0)         (max 115.0)))    ;; encompass 98.0 + 103.3, ±10% headroom
(unrealized_pnl     ((min 13500000.0)   (max 19000000.0))))   ;; encompass 15.9 + 16.7M
```

## Disclaimer — these are LONG-ONLY baselines

Once short-side gaps G1-G4 close, the
`(config_overrides (((universe_cap (1000)) (enable_short_side false))))`
override should be reverted to
`(config_overrides (((universe_cap (1000)))))` (defaulting back to
`enable_short_side = true`), and the `expected` ranges re-pinned against
the with-shorts numbers. The sp500-2019-2023 cell follows the same path —
see `dev/notes/short-side-gaps-2026-04-29.md` § Re-enabling shorts.

## References

- Override flag introduced: PR #682 (sp500-2019-2023 mitigation).
- Short-side gaps: `dev/notes/short-side-gaps-2026-04-29.md`.
- sp500 long-only baseline (companion cell):
  `dev/notes/sp500-golden-baseline-2026-04-26.md` (pre-#682; numbers there
  reflect a with-shorts run on a different post-#604 build, not directly
  comparable; the post-#682 long-only baseline is captured in PR #682).
- Tier-4 release-gate context:
  `dev/notes/tier4-release-gate-checklist-2026-04-28.md`.
- RSS / panels matrix:
  `dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md` (β = 3.94
  MB/symbol). Measured RSS (1.65-1.96 GB) lands well below the predicted
  4.8-5.7 GB ceiling — the per-symbol cost on the broad-1000 universe is
  notably cheaper than the matrix's typical-curve fit, consistent with
  the broad-data shape vs small-302 finding in
  `dev/notes/sp500-golden-baseline-2026-04-26.md` § Predicted vs measured
  RSS.
