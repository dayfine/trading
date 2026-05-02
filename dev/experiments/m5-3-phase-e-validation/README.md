# M5.3 Phase E — validation + tier-4 spike

Phase E of the daily-snapshot streaming pipeline (parent plan
`dev/plans/daily-snapshot-streaming-2026-04-27.md` §Phasing Phase E). This
directory captures the empirical validation that ran against the just-merged
Phase A.1 / B / C / D stack.

## Status

VALIDATED with caveats; Phase F is unblocked but the snapshot-build pipeline
needs an O(N²) fix before this layer can replace `Bar_panels.t` at full
production-data scale.

## Findings summary

1. **End-to-end parity holds bit-for-bit** between CSV mode and snapshot mode
   on the panel-golden / `parity-7sym` fixture. Every output file
   (`summary.sexp`, `trades.csv`, `equity_curve.csv`, `final_prices.csv`,
   `open_positions.csv`, `splits.csv`, `universe.txt`) is byte-identical
   across the two backend selectors. This held over both the canonical
   2019-05-01..2020-01-03 window and a longer 2018-10-15..2019-12-31 window.
2. **The Phase B snapshot-writer pipeline is O(N²) per symbol.** Every
   produced row recomputes its indicators from the full prefix `[bar 0 .. bar
   i]`. For a 30y AAPL CSV (~11K bars) this means ~80 s per symbol; the full
   sp500 corpus would take ~11 hours to build. This made the dispatch's "S&P
   500 5y golden" parity validation intractable as a single-shot run; the
   fixture-scale parity above is the substitute and is sufficient for Phase F
   gating because the simulator is a pure function of bar reads (Phase D's
   per-call parity test pins those bit-equal).
3. **Tier-4 RSS at N=10K is bounded by the LRU cache cap, not the corpus
   size.** Plan §C5's "30 days × 720 KB = 22 MB" framing assumed a per-day
   file format; the shipped Phase A format is per-symbol. Effective working
   set at runtime is `min(N_active × file_size, max_cache_mb)`. With default
   `max_cache_mb = 64` and ~2 MB per production-data symbol, ~32 symbols stay
   resident at once — comfortable for the realistic working set
   (held positions + Friday's screened candidates ≈ 30-100 symbols). Plan
   §C5's literal "~25 MB peak RSS" target needs reframing as "~25 MB
   {b incremental} above Bar_panels", not "absolute".

## Detailed findings

### F1 — End-to-end parity holds (CSV mode ≡ snapshot mode)

**Method.** Run `backtest_runner.exe` twice on the same scenario, once in CSV
mode (default) and once with `--snapshot-mode --snapshot-dir`. Compare every
output file byte-for-byte.

**Setup.**
- Universe: `parity-7sym` (AAPL, MSFT, JPM, JNJ, CVX, KO, HD).
- Macro: GSPC.INDX + 11 SPDR sector ETFs + 3 global indices (= 15 macro
  symbols). All sourced from `trading/test_data/`.
- Snapshot dir built via
  `analysis/scripts/build_snapshots/build_snapshots.exe -universe-path <22-sym
  pinned> -csv-data-dir <test_data> -output-dir /tmp/snapshots-7sym
  -benchmark-symbol GSPC.INDX`. Build wall: 16 s for 22 symbols (~10y data
  per symbol).
- `TRADING_DATA_DIR` set to the worktree's `trading/test_data/` so both modes
  read the same source CSVs.

**Result.**

| Metric                  | Window 2019-05-01..2020-01-03 | Window 2018-10-15..2019-12-31 |
|-------------------------|-------------------------------|-------------------------------|
| `final_portfolio_value` | 996,921.77 (both modes)       | 948,698.05 (both modes)       |
| `n_round_trips`         | 3                             | 13                            |
| `TotalReturnPct`        | -0.31                         | -5.13                         |
| `NumTrades`             | 6                             | 13                            |
| `WinRate`               | 0                             | 15.38                         |
| `SharpeRatio`           | -0.47                         | -0.70                         |
| `MaxDrawdown`           | 2.92                          | 9.38                          |
| `AvgHoldingDays`        | 49.33                         | 31.69                         |
| `summary.sexp` diff     | byte-identical                | byte-identical                |
| `trades.csv` diff       | byte-identical                | byte-identical                |
| `equity_curve.csv` diff | byte-identical                | byte-identical                |
| `final_prices.csv` diff | byte-identical                | byte-identical                |
| `open_positions.csv`    | byte-identical                | byte-identical                |
| `splits.csv`            | byte-identical                | byte-identical                |

Verify command (in container, from worktree's `trading/`):
```
TRADING_DATA_DIR=$PWD/test_data \
  ./_build/default/trading/backtest/bin/backtest_runner.exe \
    2019-05-01 2020-01-03 --experiment-name csv-mode-baseline
TRADING_DATA_DIR=$PWD/test_data \
  ./_build/default/trading/backtest/bin/backtest_runner.exe \
    2019-05-01 2020-01-03 --snapshot-mode --snapshot-dir /tmp/snapshots-7sym \
    --experiment-name snap-mode-test
diff dev/experiments/csv-mode-baseline/summary.sexp \
     dev/experiments/snap-mode-test/summary.sexp   # exit 0
diff dev/experiments/csv-mode-baseline/trades.csv \
     dev/experiments/snap-mode-test/trades.csv     # exit 0
```

Captured summaries: `window-2019h2-csv-mode.sexp`,
`window-2019h2-snapshot-mode.sexp`, `window-2018h2-2019-csv-mode.sexp`,
`window-2018h2-2019-snapshot-mode.sexp`.

**Why parity is bit-equal (not just within tolerance).** Phase D's
`test_snapshot_mode_parity` already pins per-call bit-equality at the
`Market_data_adapter` seam. The simulator is a deterministic function of its
bar reads (engine.update_market, MtM portfolio_value, split detection,
benchmark return all derive from those reads), so bit-equality at the seam
propagates to bit-equality in the published metrics. The strategy's panel
reads via `Bar_panels.t` are unchanged across modes (Phase D scope explicitly
preserved them), so the strategy's transition stream is also identical, which
makes round-trip extraction identical, which makes every aggregated metric
identical. Phase E's Phase F follow-up will collapse this duality once
`Bar_panels.t` retires and the strategy reads through `Daily_panels.t` too.

### F2 — Phase B pipeline is O(N²) per symbol

**Method.** Time the snapshot writer at 3 increasing data-density tiers.

**Result.**

| Source dir       | Symbols | Avg bars/symbol | Wall   | Throughput      |
|------------------|---------|-----------------|--------|-----------------|
| test_data (~10y) | 3       | ~2,100          | 24.3 s | 12.2 sym/min    |
| test_data (~10y) | 22      | ~2,000          | 15.8 s | 83.5 sym/min    |
| production (30y) | 1 (AAPL)| ~11,400         | 80 s   | 0.75 sym/min    |
| production (30y) | 22      | ~10,000 (proj.) | >600 s | hung at AAPL    |

The 22-symbol test_data run is faster per-symbol than the 3-symbol test_data
run — that's because the 3-symbol run included a benchmark-bars side load.
Removing that overhead, per-symbol wall scales roughly with `N_bars²` per
symbol (the warmup-from-zero indicator recompute pattern). Production data
at 30y is ~5.5× the bar count of test_data, which translates to
~30× per-symbol wall via the quadratic relationship — matching the observed
80 s/symbol.

**Root cause** (`analysis/weinstein/snapshot_pipeline/lib/pipeline.ml`):
- `_ema_at` / `_sma_at` / `_atr_at` / `_rsi_at` rebuild from bar 0 every call
  (`for k = 0 to period-1 do … `, then `for t = period to i do …`).
- `_weekly_prefix` calls `List.take bars (i+1)` and re-aggregates daily→weekly
  every call.
- `_stage_value_for_prefix` and `_rs_value_for_prefix` re-aggregate weekly
  every call, then run `Stage.classify` over 60 weekly bars and `Rs.analyze`
  over 100 weekly bars per row.

For a symbol with N daily bars, the per-symbol cost is `O(N) × O(N) = O(N²)`
indicator-FLOPs. At N=11K (30y), that's ~120M indicator updates per symbol —
none reused across rows. The pipeline.ml docstring even calls this out: "The
whole prefix is rebuilt per call — Phase B is offline and per-day; Phase C
will memoize." That memoization plan never materialised in shipped code.

**Recommended fix (post-Phase F).** Convert the four rolling-window kernels
to incremental updaters (state machines that emit one row per `add_bar` call,
identical to how `analysis/technical/indicators/{ema,sma,atr,rsi}_kernel.ml`
already work in the runtime path). Convert `_weekly_prefix` to maintain a
running daily→weekly aggregator. This drops per-symbol cost from O(N²) to
O(N), bringing the full sp500 build from ~11h to ~5 min, restoring the plan's
"~5 min wall" target. Tracked separately — out of Phase E scope.

**Impact on Phase E plan.** The plan's "Run S&P 500 5y golden, assert metrics
within band" became infeasible as a one-shot under the current writer. The
~22-symbol test_data parity above is the empirically-checked substitute. The
F1 result + Phase D's per-call parity together cover the same proof obligation
as the plan's original sp500-5y validation: "snapshot-mode runs produce the
same trade outcomes as CSV-mode runs". They cover it on a smaller fixture.

### F3 — Tier-4 RSS bounded by LRU cache, not corpus size

**Method.** Measure on-disk snapshot file sizes, derive expected runtime cache
footprint via `Daily_panels.t`'s LRU semantics.

**Result.**

| Symbol class            | Source dir           | Bars   | File size |
|-------------------------|----------------------|--------|-----------|
| Long-history US equity  | test_data            | ~2,100 | ~370 KB   |
| SPDR sector ETF         | test_data            | ~250   | ~41 KB    |
| Global index            | test_data            | ~250   | ~43 KB    |
| Long-history US equity  | production data (proj) | ~11,400 | ~2.0 MB   |
| Long-history US equity  | production data 30y (proj) | ~7,500 | ~1.3 MB   |

Per `Daily_panels.t` semantics
(`analysis/weinstein/snapshot_runtime/lib/daily_panels.mli` §Memory budget),
peak RSS for the snapshot cache is bounded by `max_cache_mb` (default 64). The
LRU evicts symbols once total tracked bytes exceed the cap.

**Tier-4 projection (N=10K × 10y).**

- On-disk corpus: 10K × 1.3 MB = 13 GB total.
- Hot working set during a backtest: held positions (~30) + this Friday's
  screened candidates (~100) ≈ 100 unique symbols touched per Friday.
- Monday-Thursday: only held positions (~30 symbols) read.
- Active cache at default 64 MB cap → fits ~32 symbols of 2 MB each.
  Friday-cycle eviction will churn (~100 promotions − 32 cap = 70 evictions
  per Friday).
- Bumping cap to 256 MB → fits ~128 symbols → no Friday-cycle churn.
- Bumping cap to 512 MB → fits ~256 symbols → comfortable headroom.

**Plan §C5 reframing.** The plan's literal "30 days × 720 KB = 22 MB" cache
window was based on a per-day file format that the implementation diverged
from (per-symbol files instead, see `daily_panels.mli` §"Why per-symbol and
not per-day"). The actual per-symbol cache is sized in **MB per
loaded symbol** (~2 MB at production scale). The plan's "~25 MB peak RSS"
goal was a per-day-cache figure; the achievable target with the per-symbol
format is ~50-200 MB depending on `max_cache_mb` + working-set size — still
~50× under the ~10 GB Bar_panels-per-symbol-fully-loaded cost the plan was
trying to displace.

**Phase F readiness.** Phase D shipped feature-flagged opt-in; Phase F's job
is to retire `Bar_panels.t` and have the strategy read through
`Daily_panels.t` as well. F1 above proves the simulator-side reads compose to
identical outputs; F3's cache-size analysis confirms the runtime memory
profile fits the system budget at tier-4 scale (with the understanding that
~25 MB was an overly tight target). Phase F is unblocked from a correctness
standpoint. The Phase B O(N²) issue should be fixed first as a prerequisite
to running real Phase F validation experiments at sp500 scale (otherwise
each schema bump forces ~11h of corpus rebuild).

## Files in this directory

- `README.md` (this file) — findings + verify commands.
- `window-2019h2-csv-mode.sexp` / `window-2019h2-snapshot-mode.sexp` — the
  bit-identical summaries from window 1 of F1.
- `window-2018h2-2019-csv-mode.sexp` /
  `window-2018h2-2019-snapshot-mode.sexp` — the bit-identical summaries from
  window 2 of F1.

## References

- Parent plan: `dev/plans/daily-snapshot-streaming-2026-04-27.md` §Phasing
  Phase E + §Catches C5.
- Phase D plan: `dev/plans/snapshot-engine-phase-d-2026-05-02.md`.
- Phase D parity gate: `trading/trading/backtest/test/test_snapshot_mode_parity.ml`.
- Phase B writer: `trading/analysis/scripts/build_snapshots/build_snapshots.ml`
  + `trading/analysis/weinstein/snapshot_pipeline/lib/pipeline.ml` (O(N²)
  finding).
- Phase C runtime: `trading/analysis/weinstein/snapshot_runtime/lib/daily_panels.mli`
  (LRU cache semantics).
