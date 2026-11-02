# Issue 3476 parity run, cloud side

Cell: `trading/test_data/backtest_scenarios/goldens-broad/bull-crash-2015-2020.sexp`
Commit (origin/main): `2210132b241b12c577347a0247dab6a9628ca5a8`
Run date: 2026-11-02 (UTC). Host: cloud container, 4 cores, 15 GB RAM. Image: `ghcr.io/dayfine/trading-ci:latest`.
No bar data, snapshots or per-trade outputs are in the repo; only hashes, metrics and timings below.

## Commands

```sh
# step 2: pull (43 s wall). Archive bars/data-20261101.tar.gz sha256=79cefcfb8643582eadd4f4696174c2fb229d6c585e2a318f2d35837429118b52
sh dev/scripts/r2_bars.sh pull --dest /tmp/data      # unpacks to /tmp/data/{A..Z,breadth,macro,...}; 2.2 GB

# step 3a: build binaries (inside the CI image; -u 0 because the mount is not writable by the image user;
# build dir in /tmp to keep the repo clean). 1m18s.
docker run --rm -u 0 -v $PWD:/repo -v /tmp:/tmp ghcr.io/dayfine/trading-ci:latest bash -c \
  'cd /repo/trading && eval $(opam env) && dune build --build-dir /tmp/_build \
     trading/backtest/snapshot_warehouse/build_scenario_snapshots.exe trading/backtest/scenarios/scenario_runner.exe'

# step 3b: build the warehouse (script run in the same image/mounts)
cd /repo/trading && eval $(opam env)
export TRADING_DATA_DIR=/tmp/data
/usr/bin/time -v -o /tmp/wh_build.time /tmp/_build/default/trading/backtest/snapshot_warehouse/build_scenario_snapshots.exe \
  -scenario test_data/backtest_scenarios/goldens-broad/bull-crash-2015-2020.sexp \
  -fixtures-root test_data/backtest_scenarios -csv-data-dir /tmp/data -output-dir /tmp/wh

# step 4: run the cell (scenario staged alone in /tmp/stage, as perf_tier4_release_gate.sh does)
mkdir -p /tmp/stage && cp trading/test_data/backtest_scenarios/goldens-broad/bull-crash-2015-2020.sexp /tmp/stage/
export TRADING_DATA_DIR=/tmp/data SNAPSHOT_MAX_MMAP_HANDLES=12000
/usr/bin/time -v -o /tmp/run_cell.time /tmp/_build/default/trading/backtest/scenarios/scenario_runner.exe \
  --dir /tmp/stage --parallel 1 --fixtures-root /repo/trading/test_data/backtest_scenarios \
  --snapshot-dir /tmp/wh --no-emit-all-eligible
```

Notes for mirroring: build_scenario_snapshots takes single-dash flags; scenario_runner takes double-dash.
`SNAPSHOT_MAX_MMAP_HANDLES=12000` is my choice (copied from the 2026-10-29 seed-band chain); other env at defaults
(`SNAPSHOT_CACHE_MB` default, reported cap_mb=4096). No `TRADING_PATH_SEED_SALT`, so the spec's default tiebreak seed applies.
Fixtures-root resolves `../goldens-custom-universe/composition/top-1000-2015.sexp` to `trading/test_data/goldens-custom-universe/...`.

## Timings and RSS

| step | wall | peak RSS (`/usr/bin/time -v`) |
|---|---|---|
| r2 pull | 43 s | n/a |
| dune build (2 exes) | 78 s | n/a |
| warehouse build | 2:58.00 (manifest write 177.45 s) | 49,488 kB |
| scenario_runner cell | 5:01.87 | 484,364 kB (runner's own maxrss_bytes=495,087,616; top_heap_bytes=311,973,008) |

Warehouse: 958 entries, `verify: 958/958 files OK`; universe has 1015 symbols incl. index/sector ETFs, 57 absent from bars
(`n_symbols_touched=958 n_symbols_absent=57`). Cache: hits=5,087,050 misses=166,657 evictions=0.
Series-tail findings: 10 (2 truncated, 1 stray_dropped, 7 kept).

## Result line

`bull-crash-2015-2020  51.3%  203 trades  38.4% win  34.5% maxDD  FAIL (total_trades high (203.00 > 196.65))`
Runner exit code 1 (the FAIL is the spec's expected band; the run itself completed, `crashed false`).

## Metrics (actual.sexp)

total_return_pct 51.292230317861211, total_trades 203, win_rate 38.423645320197039, sharpe_ratio 0.40676393321315835,
max_drawdown_pct 34.533310682609695, avg_holding_days 59.891625615763544, open_positions_value 1354069.3518,
unrealized_pnl 730613.71198569215, sortino 0.55842022575669636, calmar 0.20703067268042774, ulcer 15.209064658645088,
force_liquidations_count 1, crashed false.

## sha256 of output files (scenario dir; wall_seconds.txt, progress.sexp excluded; no gc trace was produced)

```
ecea993290d3cdb40ea0127d86b60ab00519e9083b60d52b29f1c70682a3c3f0  actual.sexp
81de2bc72cd2c1ebb9531498e7947d5ea2929c4aa2f5621b58836533cd2bdf65  equity_curve.csv
af67c7181f0a030dc93137259cccedf2fa10e0cbcea0cd6b454c1c9b37ef7962  final_prices.csv
71d200d8ffab1b98ab940769da680c27d48873242f3f141a4910e6e10766e84b  fold_health.sexp
c44391328956aca23adf9c9f106d4b9f15cb0dffe6803054feeff14483078cad  force_liquidations.sexp
1fa49fcdd9a58fa1217e254af15f57dc0e78e13496e504797f9d594b06823282  macro_trend.sexp
8e1dcdad245213f089ea06e0500f476ca24660b9fe61ba8d4423ae7e6675f2b1  open_positions.csv
058a87719fa965c97fcf7a34ebccd0e53e5b5a6eb2dd7a81d012585a391ff4ef  params.sexp
de28e64ba16432e8e8df545afafda12bb2671e3c6ca81aeb7445e17704a5abdf  splits.csv
05440bf60c5ec7ec8a24ea63f4e76b96eb5a388ccb321a890ca824cfa4b3999e  summary.sexp
5dcd058df6b4baeb24aa19fe2e911159bf61d0d12a8b469ec4890ecd652f2338  trade_audit.sexp
b8de94264db32e387233060f192783ebb3b7999ce36cefbc69ad5a6b5ade88b1  trades.csv
0232228a74a92234ad7718e30015bbce81335d341b2a3ec9f6e1b66d8d5cc7aa  universe.txt
```

Not yet done: a second cloud run to confirm cloud-side determinism.
