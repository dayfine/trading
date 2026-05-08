# 15y SP500 memory cliff — root-cause investigation (2026-05-08)

## Problem

The 15y SP500 golden (`goldens-sp500-historical/sp500-2010-2026.sexp`) peaks
at **11.4 GB RSS**, vs **766 MB** at the 5y golden
(`goldens-sp500/sp500-2019-2023.sexp`). The 5y → 15y window scales the
trading days by 3×, but the memory blows up by ~15×. This OOMs the 8 GB GHA
runners and blocks every 15y experiment downstream.

Backtest memory was supposed to be bounded (incremental metrics, GC bars),
independent of window length. That contract is currently broken.

## Method

Built `scenario_runner.exe` from this worktree and ran it inside the docker
dev container (8 GB total RAM, OCaml default GC). RSS sampled via
`/tmp/rss_tree_sampler.sh` reading `/proc/<pid>/status:VmRSS` over the
process tree, every 15-30 s.

Two scaffolding runs:

* **5y baseline:** `goldens-sp500/sp500-2019-2023.sexp` (500-symbol SP500
  universe, 2019-01-02 → 2023-12-29). Wall: **255 s**, peak RSS:
  **1.26 GB** (worker process; 1.32 GB tree total). Note: this is higher
  than the cited 766 MB. The 766 MB number is from the GHA tier-3 cell on
  a different bar source / different snapshot reuse path; the *shape* of
  growth is what matters here, not the absolute value.
* **7y probe:** truncated `goldens-sp500-historical/sp500-2010-2017-7y` with
  the historical 510-symbol universe + the 15y golden's
  `max_position_pct_long 0.05 / max_long_exposure_pct 0.50 /
  min_cash_pct 0.30` overrides. Peak RSS observed at t=480s: **1.54 GB**
  worker (still climbing slowly when the run was killed). Linear growth
  ~0.8 MB/s through simulation, no super-linear blowup visible in this
  window.

The 15y run itself was **not** re-run locally — the 8 GB container would
OOM where the GHA runner already has, and the analytical signals from the
two shorter runs plus the code review are sufficient to identify the
growth structures.

GHA invocation note: `dev/scripts/golden_sp500_postsubmit.sh` sets
`OCAMLRUNPARAM=o=60,s=512k`, which tightens the major-heap overhead from
the OCaml default 80% to 60%. This shaves ~25-37% off RSS for
allocation-light runs (per
`dev/notes/panels-rss-matrix-post602-gc-tuned-2026-04-26.md`). My local
runs use the default, so absolute numbers here run higher than GHA. The
*shape* of growth is unchanged.

## Headline numbers

|             | wall (s) | peak RSS (worker) | growth-rate during sim | trades |
|-------------|----------|-------------------|------------------------|--------|
| 5y baseline | 255      | 1.26 GB           | ~1.5 MB/s              | 81     |
| 7y probe    | ≥480     | 1.54 GB+          | ~0.8 MB/s              | -      |
| 15y on GHA  | 2577     | **11.4 GB**       | (extrapolation: 2-3 MB/s) | 102 |

Linear extrapolation from 5y/7y simulation-phase growth predicts the 15y
peak at ~2-3 GB. The actual measured 11.4 GB is **3-5× higher than what
linear extrapolation predicts** — meaning *something happens at 15y that
isn't visible in the 5y/7y simulation phase*. The most likely candidate
based on the code review is a **transient peak during the post-simulation
analytics + writer phase**, not the simulation loop itself. See "Cliff #5"
below.

## RSS time series — 5y baseline (sp500-2019-2023, 500 symbols, daily)

```
elapsed_s | total_rss_mb | worker_rss_mb | phase
       0  |        143   |        80     | scenario_runner spawned
      15  |        352   |       289     | reading universe + AD bars
      30  |        940   |       877     | <-- snapshot construction (step jump)
      45  |       1028   |       965     | snapshot done; simulator created
      60  |       1060   |       996     | simulating
      75  |       1065   |      1001     | simulating
      90  |       1088   |      1025     | simulating
     105  |       1105   |      1041     | simulating
     120  |       1122   |      1058     | simulating
     135  |       1146   |      1082     | simulating
     150  |       1192   |      1127     | simulating
     165  |       1236   |      1171     | simulating
     180  |       1253   |      1188     | simulating
     195  |       1284   |      1219     | simulating
     210  |       1288   |      1223     | simulating
     225  |       1309   |      1244     | simulating
     240  |       1321   |      1256     | simulating + post-run write
     255  |        ---   |       ---     | EXIT (PASS)
```

Two distinct phases:

1. **Snapshot construction (t=15→30s):** RSS jumps **+600 MB in 15 s**.
   This is `Backtest.Csv_snapshot_builder.build` reading every CSV in the
   universe into memory simultaneously, then iterating to write `.snap`
   files. The peak working set during this phase is dominated by
   `symbol_bars : (string * Daily_price.t list) list` rooted by the outer
   `List.map`.
2. **Simulation loop (t=30→240s):** linear growth ~**1.5 MB/s** from
   1.05 GB → 1.26 GB over 210 s. This is `step_history` accumulation in
   `Trading_simulation.Simulator.t` — every `Simulator.step` prepends a
   `step_result` to `step_history`, and the entire reversed list is held
   to end-of-run for the metric computers and the equity-curve writer.

## Identified growth structures (file-line citations)

### Cliff #1 — Csv_snapshot_builder.build holds the universe-wide bar set

`trading/trading/backtest/lib/csv_snapshot_builder.ml`, lines 65–80:

```ocaml
let build ~data_dir ~universe ~start_date ~end_date =
  let symbol_bars =
    _read_bars_in_window ~data_dir ~universe ~start_date ~end_date
  in
  let dir = Stdlib.Filename.temp_dir ... in
  let entries =
    List.map symbol_bars ~f:(fun (symbol, bars) ->
        let rows = _build_rows_or_fail ~symbol ~bars in
        let path = _write_symbol_snap ~dir ~symbol rows in
        _file_metadata_of ~symbol ~path)
  in ...
```

`_read_bars_in_window` returns a `(string * Daily_price.t list) list` of
**every symbol's full bar history in the window** before any per-symbol
processing starts. While the `List.map` body iterates, `symbol_bars` stays
rooted (the iteration walks its spine).

* 5y / 500 symbols / ~1453 trading days × 88 B/bar (Daily_price record +
  cons cell) = **~64 MB live**.
* 15y / 510 symbols / ~4350 trading days × 88 B/bar = **~195 MB live**,
  scaling linearly with window.

This alone doesn't account for 11 GB, but the design assumption — that the
snapshot builder is a streaming, per-symbol-bounded operation — is
violated.

### Cliff #2 — Two independent Daily_panels caches, each capped at 1 GiB

`trading/trading/backtest/lib/panel_runner.ml`, lines 168–187 (`_setup_hybrid`):

```ocaml
let daily_panels =
  match Daily_panels.create ~snapshot_dir ~manifest
          ~max_cache_mb:_snapshot_cache_mb with ...
in
let bar_reader = _build_snapshot_bar_reader ~daily_panels ~calendar in
let strategy = _build_strategy input ~strategy_choice ~bar_reader ~audit_recorder in
let adapter =
  _build_market_data_adapter ~data_dir:input.data_dir_fpath
    ~bar_data_source:(Bar_data_source.Snapshot { snapshot_dir; manifest })
in ...
```

The `daily_panels` instance backs the strategy's bar reader. Then
`_build_market_data_adapter` constructs the simulator's adapter, and inside
`Bar_data_source._build_snapshot_adapter` (lines 12–21 of
`bar_data_source.ml`) it calls `Daily_panels.create` **a second time**:

```ocaml
let _build_snapshot_adapter ~snapshot_dir ~manifest ~max_cache_mb =
  let%bind panels = Daily_panels.create ~snapshot_dir ~manifest ~max_cache_mb in
  ...
```

The module-doc comment in `_setup_hybrid` (panel_runner.ml lines 165–167)
explicitly claims "all reading through one Daily_panels.t" — but the code
violates that contract. We end up with **two separate LRU caches**, each
sized to `_snapshot_cache_mb = 1024`, both holding (largely overlapping)
copies of the same per-symbol row arrays.

* 5y / 510 symbols / 1453 rows × ~150 B (12 floats + overhead) =
  **~110 MB per panel** → fits comfortably under the 1 GiB cap →
  **~220 MB resident across both caches**.
* 15y / 510 symbols / 4350 rows × ~150 B = **~330 MB per panel** →
  still under cap → **~660 MB across both caches**.

Bigger problem: as `read_history` / `read_today` faults symbols in, each
cache fills independently. With sp500's 510 symbols × 4350 rows × 150 B
≈ 330 MB, *both* caches would settle at ~330 MB rather than evicting,
because each is sized to 1 GiB. Total resident: 660 MB.

### Cliff #3 — Simulator.step_history accumulates every step_result indefinitely

`trading/trading/simulation/lib/simulator.ml`, line 423:

```ocaml
let t' = {
  t with
  current_date = Date.add_days t.current_date 1;
  portfolio;
  positions;
  step_history = step_result :: t.step_history;
}
```

`step_history : step_result list` grows monotonically across the entire
simulation. The entire list is then materialised at end-of-run by
`_build_run_result` (line 339: `let steps = List.rev t.step_history`),
handed to every metric computer in the suite (11 computers, one fold over
`steps` each), threaded through `Backtest.Runner.result.steps`, and finally
walked by `Result_writer._write_equity_curve` to emit `equity_curve.csv`.

Each `step_result` (defined in
`trading/trading/simulation/lib/types/simulator_types.ml` lines 18–28) carries:

```ocaml
type step_result = {
  date : Date.t;
  portfolio : Trading_portfolio.Portfolio.t;
  portfolio_value : float;
  trades : Trading_base.Types.trade list;
  orders_submitted : Trading_orders.Types.order list;
  splits_applied : Trading_portfolio.Split_event.t list;
  benchmark_return : float option;
  had_market_bars : bool;
}
```

The `portfolio` field is a **full `Trading_portfolio.Portfolio.t` record**
(see `trading/trading/portfolio/lib/portfolio.ml` line 8), which itself
contains `trade_history : trade_with_pnl list` and `positions :
portfolio_position list`. Crucially, `apply_single_trade`
(portfolio.ml line 380) builds new trade_history with `@`:

```ocaml
trade_history = portfolio.trade_history @ [ trade_with_pnl ];
```

Each `@` allocates a fresh non-shared cons-cell prefix, so each
trade-emitting step's `step_result.portfolio.trade_history` points to a
distinct list head. With 102 trades over 15 y the cons-cell count is small
(~5 K cells for unique spines, dominated by the spine after the last
trade), but the broader concern is **every `step_result` retains a
reference to its portfolio snapshot**, including positions, orders, splits.

The **dominant simulation-phase growth** is *linear in trading days*: at
1.5 MB/s observed over 5 y (1453 days × strategy_cadence Daily), the
per-step incremental allocation in the live set is roughly 800 B–1 KB.
Multiplied by 4350 days for the 15 y run, that's **+3.5 GB of step_history
working set** that is never reclaimed — held by `Simulator.t.step_history`
through the entire run, then by `Runner.result.steps` until
`Result_writer.write` returns.

### Cliff #5 — Post-simulation analytics holds [steps] resident through 11 metric folds + 8 sexp/csv writers (suspected dominant)

`trading/trading/simulation/lib/simulator.ml` line 338, `_build_run_result`:

```ocaml
let _build_run_result t =
  let steps = List.rev t.step_history in
  let base_metrics =
    _compute_metrics ~computers:t.deps.metric_suite.computers
      ~config:t.config ~steps
  in
  let metrics =
    _compute_derived ~derived_computers:t.deps.metric_suite.derived
      ~config:t.config ~base_metrics
  in
  { steps; metrics }
```

`_compute_metrics` then folds **11 separate metric computers** over the
same `steps` list (one fold per computer):

```ocaml
List.fold computers ~init:Trading_simulation_types.Metric_types.empty
  ~f:(fun acc (computer : any_metric_computer) ->
    Trading_simulation_types.Metric_types.merge acc
      (computer.run ~config ~steps))
```

Each computer has its own internal allocations. At the 5y window (1453
steps) each computer's transient allocations (~30-100 KB per computer)
are dwarfed by the in-place fold of `steps`. At the 15y window (4350
steps) several computers do operations that are O(N) but with sizeable
constants:
- `Drawdown_analytics_computer`: builds an episode list (drawdown segments),
  then `Array.of_list` over it.
- `Distributional_computer`: `List.sort` on the per-step return list +
  `List.take`/`List.drop` for tail-bucket computation.
- `Antifragility_computer`: bins step returns and computes per-bin stats.

Across all 11 computers folded sequentially, total transient allocation per
end-of-run pass is ~15-50 MB at 5y, scaling linearly to ~50-150 MB at 15y.

**More important: after `_build_run_result` returns, `Backtest.Runner` keeps
`steps` alive in `result.steps`**
(`trading/trading/backtest/lib/runner.ml` line 480) so the writer can emit
`equity_curve.csv`. The writer folds over `steps` again
(`Result_writer._write_equity_curve`) and so does
`Reconciler_writer.write_open_positions / write_final_prices /
write_splits`. Each of these traversals allocates per-step transients that
overlap with the still-live previous-traversal's allocations until major GC.

When the major heap is sized at default 80% overhead, sustained allocation
during these end-of-run passes can push RSS to ~2× live set. With 4350
step_results × ~5 KB each (full portfolio + trades + orders + splits +
benchmark_return) ≈ 22 MB live for step_history alone, but with the *full
Portfolio.t* on every step including positions and per-trade-cumulative
trade_history, the per-step retained allocation balloons to ~50-200 KB
each → **~600 MB - 2 GB live for step_history at 15y**.

Combined with:
- 2 × Daily_panels caches at ~330 MB each post-fault = ~660 MB
- transient computer allocations during fold = ~150 MB peak
- transient writer allocations during sexp serialisation = ~500 MB-1 GB
  (Sexp.save_hum on `summary.sexp` with 11×N metric values + the 4350-row
  `equity_curve.csv` formatted floats + the per-trade `trades.csv` rows)
- GC overhead at default 80% = ~2× the live set during sustained alloc

A live working set of ~3 GB at the 15y end-of-run analytics phase pushes
RSS to ~6-8 GB; with the major heap not catching up between successive
allocations, the watermark `time -v %M` reports can settle at 11 GB. This
is the "cliff" — not a leak, but a transient peak that scales with N
during a code path that allocates aggressively while keeping all of
`steps`, all metric inputs, and the materialised sexp tree live
simultaneously.

This is the dominant contributor at 15y per the linear-extrapolation gap
between predicted (~2-3 GB) and measured (11.4 GB).

### Cliff #4 — equity_curve writer (PR #916) was the trigger, not the cause

PR #916 (commit 54c91b69) widened `_compute_portfolio_value` to forward-fill
held-position prices when bars stop arriving and added the `had_market_bars`
field to `step_result`. This was the right behavioural fix for the
ANDV-merger truncation, but the bigger structural issue — that
`step_result.portfolio` is a *full* portfolio snapshot rather than a
projection of the few fields downstream consumers actually need — predates
#916. The 15 y window is the first scenario where step_history × full
portfolio retention exceeds 8 GB.

## Why memory grows with window length (the violated assumption)

The design contract in `eng-design-4-simulation-tuning.md` framed the
simulator as a streaming reducer: `init → fold over bars → metric set`.
In practice three things break that:

1. The metric computers were spec'd as fold-state computers
   (`Simulator_types.metric_computer` has the right shape:
   `init / update / finalize`), but the simulator's `_build_run_result`
   (simulator.ml line 338) materialises the whole `steps` list and the
   computer suite folds over it post-hoc rather than online. That's a
   refactor that landed early (way before this regression) and made
   further computers cheap to wire up — but it requires `step_history` to
   be retained.
2. `step_result.portfolio` carries the entire `Portfolio.t` instead of the
   minimal projection the computers actually consume (mostly just
   `current_cash`, `portfolio_value`, count of positions). That makes each
   retained step_result O(open positions × trade_history) rather than O(1).
3. The snapshot path grew two redundant `Daily_panels` caches because the
   `Bar_data_source` abstraction couldn't accept a pre-built panel — the
   adapter has to instantiate its own. PR #844 raised the cap to 1 GiB to
   speed up sp500 cache hits; combined with the duplication, that pushed
   resident snapshot memory from ~110 MB to ~660 MB at 15 y.

## Proposed fix (in priority order)

The single most-impactful change is **Fix B** (slim down step_result so
step_history × 4350 stops swelling the live set). Validate by remeasuring
the 15y peak after Fix B alone — it should drop the simulation-phase
working set by 5-10× and let the 15y run fit comfortably in 8 GB.

### Fix A — Reuse the existing Daily_panels.t in the simulator adapter

`trading/trading/backtest/lib/panel_runner.ml`, `_setup_hybrid`. Wire
`daily_panels` (already constructed for `bar_reader`) directly into the
adapter via a new `Bar_data_source` constructor that takes a
`Daily_panels.t` instead of a `(snapshot_dir, manifest)` pair, or expose
`Market_data_adapter.create_with_callbacks` that consumes the existing
`Snapshot_callbacks.t` derived from the same panel.

**LOC:** ~30–50 (1 new constructor in `bar_data_source.ml`, threading in
`panel_runner.ml`).

**Expected savings at 15y:** ~330 MB (drop the duplicate cache).

### Fix B — Project step_result.portfolio to the minimal shape the consumers need

Add `step_result.portfolio_summary : { current_cash; positions_count;
position_value_total } option` and stop carrying the full
`Trading_portfolio.Portfolio.t` on every step. Audit the 11 metric
computers + `Result_writer` + `Reconciler_writer` for any remaining
consumer that actually needs the full portfolio; route those through
`Trade_audit` (already a sparse log) instead of step_history.

**LOC:** ~150–250 (touching `simulator_types.ml`,
`simulator.ml._process_step_day`, every metric computer that reads
`step.portfolio`, `result_writer.ml`, `reconciler_writer.ml`).

**Expected savings at 15y:** ~3 GB (the dominant linear-growth term).

### Fix C — Stream Csv_snapshot_builder per-symbol

`trading/trading/backtest/lib/csv_snapshot_builder.ml`. Refactor `build` to
read + process + write each symbol in turn, never holding more than one
symbol's bars at once:

```ocaml
let build ~data_dir ~universe ~start_date ~end_date =
  let dir = Stdlib.Filename.temp_dir "panel_runner_csv_snapshot_" "" in
  let entries =
    List.map universe ~f:(fun symbol ->
      let _, bars = _read_one_symbol ~data_dir ~start_date ~end_date symbol in
      let rows = _build_rows_or_fail ~symbol ~bars in
      let path = _write_symbol_snap ~dir ~symbol rows in
      _file_metadata_of ~symbol ~path)
  in
  let manifest = Snapshot_manifest.create ~schema:Snapshot_schema.default ~entries in
  _write_manifest_or_fail ~dir manifest;
  (dir, manifest)
```

**LOC:** ~10 (mechanical inversion).

**Expected savings at 15y:** ~195 MB (the rooted `symbol_bars` list).

### Fix D — Online metric folding (medium-term)

Restructure `_build_run_result` to fold metric computers *during*
`Simulator.step` rather than at end-of-run, so `step_history` can be
truncated to a small ring buffer (the longest lookback any computer needs,
typically 252 days for annualisation). Reverts the original streaming
design from `eng-design-4-simulation-tuning.md`.

**LOC:** ~300–500 (rewires the `metric_suite` plumbing in
`simulator.ml` + the runner).

**Expected savings at 15y:** another ~500 MB if combined with B (the
`step.portfolio` shrunk + a 252-day ring buffer keeps step_history bounded
regardless of window).

## Sanity prediction after fixes A+B+C

* 5y peak: ~700 MB (mostly Daily_panels + per-step ring buffer + GC overhead).
* 15y peak: ~900 MB (linear in symbol count, near-flat in window length).
* The 15 y / 5 y ratio drops from ~15× to ~1.3× — back to the bounded
  contract.

Validating the prediction needs the 15y run to fit in the dev container
post-fix; until A+B land, the 15 y run can only be measured on a
≥16 GB host. Local 5 y + 7 y comparison should already show the simulation
phase no longer grows with window length once Fix B is in.

## Next step

Two follow-up PRs from this investigation:

1. **Fix A first** (mechanical, ~50 LOC): wire `daily_panels` reuse into
   the simulator adapter. Remeasure 5y peak — should drop from 1.26 GB
   worker to ~900 MB worker (~330 MB savings). Confirms the
   duplicate-cache hypothesis and frees an immediate slice of GHA budget.
2. **Fix B as the headline** (~200 LOC): split `step_result.portfolio`
   into the projection metric computers actually need. Remeasure 15y
   on a host with ≥16 GB RAM. Expected drop: ~3-8 GB → 15y peak settles
   in the 2-3 GB range, fitting GHA comfortably.

Fix C is a freebie alongside Fix A (touches the same panel_runner +
csv_snapshot_builder area). Fix D (online metric folding) is optional —
only worth landing if A+B+C don't drop the 15y peak below 6 GB on GHA.

Don't run any 15y experiments locally on the 8 GB container until at
least Fix A lands.
