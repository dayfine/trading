# 15y sp500 historical backtest — 0 trades diagnosis (2026-05-03)

## Result

```
start_date 2010-01-01  end_date 2026-04-30  universe_size 10472
n_steps 5963  initial_cash $1M  final_portfolio_value $1M  n_round_trips 0
all metrics 0
wall 103m12s
```

15y window simulated end-to-end without crash, but **zero trades placed**.

## Root cause

**Missing universe constraint in invocation**:

```
backtest_runner.exe 2010-01-01 2026-04-30 \
  --snapshot-mode \
  --snapshot-dir <historical-snapshot-dir> \
  --experiment-name sp500-historical-15y
```

No `--universe-path` flag (doesn't exist on `backtest_runner.exe`'s single-run mode). Runner defaulted to `data/sectors.csv` (10,472 symbols) but only 507 had snapshot data → 9,965 symbols return None → 0 candidates → 0 trades.

`universe_size 10472` in summary confirms: full broad universe was loaded, not the 510-sp500-historical universe.

## Fix paths

### Path A: scenario_runner.exe with proper scenario sexp (preferred)

`goldens-sp500-historical/sp500-2010-01-01.sexp` is a UNIVERSE file (just `(Pinned (...))`); not a complete SCENARIO. Need a sibling scenario file:

```
trading/test_data/backtest_scenarios/goldens-sp500-historical/sp500-2010-2026.sexp:

((name "sp500-2010-2026-historical")
 (description "15y sp500 backtest with 2010-01-01 historical universe (510 symbols, survivorship-aware)")
 (period ((start_date 2010-01-01) (end_date 2026-04-30)))
 (universe_path "goldens-sp500-historical/sp500-2010-01-01.sexp")
 (universe_size 510)
 (config_overrides ())
 (expected (...)))
```

Then run via `scenario_runner.exe --dir goldens-sp500-historical/`.

### Path B: add `--universe-path` flag to backtest_runner.exe (smaller scope)

Extend `backtest_runner_args.ml` parser with `--universe-path <path>`. Single-run mode loads universe from that file. ~30 LOC.

## Recommendation

Path A is more idiomatic (matches existing goldens-* scenario shape) and reusable. Path B is faster but adds CLI-flag clutter for a single-use case.

**File a follow-up PR**: add scenario sexp + use scenario_runner.exe. ~50 LOC + golden re-run on user's box.

## Other findings during the 100-min run

1. **Snapshot corpus completeness**: 507/510 (3 skipped: ACE, BF.B, BRK.B — dot-form ticker mismatches). 0 verify failures (after gitignore fix; previous attempts had 68/507 fails due to mid-run dir-wipe by jj auto-snapshot).
2. **Build wall**: 9m1s for 510 symbols × 16y. Extrapolates to ~115 min for full broad × 10y (~10k symbols × 10y).
3. **Backtest wall**: 103m for 5963 steps with empty universe. Real backtest with 510 symbols + actual screener picks = expect 2-3× longer due to per-tick screener cost.
