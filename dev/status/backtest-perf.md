# Status: backtest-perf

## Last updated: 2026-06-12

## Status
IN_PROGRESS

### Recent activity (2026-06-12) — runner fold-correctness fixes

Branch `feat/runner-fold-fixes` (READY_FOR_REVIEW). Root-causes + fixes
the silently-broken backtest fold (A2) surfaced by the rolling-start
matrix, plus the G1 entry-date fix and a G2 investigation. Diagnosed
from `dev/experiments/rolling-start-matrix-2026-06-11/ANALYSIS.md`.
(A1 min-window guard was shipped in parallel by PR #1546
`feat/backtest-perf-matrix-guards`; dropped from this branch to avoid
the collision.)

- **[x] A2 — degenerate-fold guard** (`trading/trading/backtest/lib/fold_health.{ml,mli}`,
  wired into `scenarios/scenario_runner.ml`). **Root cause (deterministic,
  start-date-specific):** the simulator runs from `warmup_start` (start − 210d)
  with daily cadence, so the Weinstein strategy trades during the warmup window.
  For the 2009-06-26 (Friday) start, the 2008-11-28→2009-06-26 warmup spans the
  GFC bottom; warmup-window trades blow the portfolio down to ~35% of initial
  cash *before* the measurement window opens. The in-window equity curve is then
  flat (held positions frozen on cached/avg-cost marks) and `n_round_trips = 0`
  (warmup entries can't pair with in-window exits in `extract_round_trips`),
  while `align_summary_metrics` leaves the trade-stat metrics (numtrades 26,
  largestlossdollar −556955, worstweekpct −60.6) warmup-inclusive — so the run
  reports −64.78% as if it were in-window. The sibling Monday start (2009-06-29,
  warmup 3 days later) is healthy: +30.88%, 68 round-trips, 512 distinct equity
  values. Same class as the origin's "MaxDD 190.4%" (warmup drawdown folded in).
  **Fix:** a pure `Fold_health.check` reads a run's terminal facts (initial/final
  cash, n_round_trips, n_steps, equity curve) and returns findings for the
  three degenerate signatures (zero in-window round-trips over a long window;
  flat equity curve; unexplained terminal move with zero round-trips). The
  scenario runner calls it after every run, prints each finding loudly to stderr
  (`WARN: fold-health: …`), and writes `fold_health.sexp` per scenario. Purely
  additive/diagnostic — changes no metric, every threshold config-routed via
  `Fold_health.default_config` (no magic numbers). Verify:
  `dune exec trading/backtest/test/test_fold_health.exe` (9 tests pin the A2
  signature + each guard + the healthy-run silence).
- **A1 — rolling-start min-window guard — shipped elsewhere.** Implemented in
  parallel by PR #1546 (`feat/backtest-perf-matrix-guards`), which filters
  short windows out of the report aggregate summary. Dropped from this branch
  to avoid the collision.
- **[x] G1 — open_positions.csv entry_date = simulated date**
  (`trading/trading/simulation/lib/simulator.ml`). **Root cause:** the engine
  stamps every fill with `Time_ns_unix.now ()` (`engine.ml:161`); the portfolio
  builds each lot's `acquisition_date` from `trade.timestamp`, and
  `reconciler_writer` derives `open_positions.csv`'s `entry_date` from the lot —
  so every open-position row showed the *run* date. **Fix:** the simulator
  re-stamps each fill's timestamp to the simulated `current_date` (UTC
  start-of-day) at `_process_fills_and_cancels`, the single point backtest fills
  enter the portfolio — no engine/portfolio core-module change. Round-trip
  extraction is unaffected (it keys off `step.date`, not `trade.timestamp`).
  Verify: `dune exec trading/simulation/test/test_simulator.exe` (new
  `test_fill_lot_acquisition_date_is_simulated_date` pins the lot date to the
  simulated fill date).
- **G2 — investigated only** (no code change). The THM divergence (audit closed
  a short with no `trades.csv` row, while `open_positions.csv` holds an open THM
  short with no audit record) is the same warmup-leak class as A2: a short
  *entered in warmup* and covered in-window is dropped from `trades.csv` by
  `extract_round_trips` (entry not in `steps_in_range`) yet its close survives
  in the audit (recorded from `warmup_start`); a *second* THM short opened
  in-window and still open at run end is the `open_positions.csv` row. The A2
  fold-health guard flags exactly the folds where this accounting splits.

### Recent activity (2026-06-12)

- **[x] A1 — min-window guard for the rolling-start matrix summary**
  (branch `feat/backtest-perf-matrix-guards`, PR #1546). Surfaced as a
  definitive-run blocker in
  `dev/experiments/rolling-start-matrix-2026-06-11/ANALYSIS.md`: short windows
  (≤15 months) annualise to absurd CAGR (up to +2393 %/yr) and poison the
  report's aggregate stats (raw median edge +6.0 pp/yr vs honest trimmed
  +3.2 pp/yr). Added a `min_window_days` concept — a start whose inclusive
  `start_date..end_date` window is strictly shorter than the threshold is
  **excluded from every aggregate/dispersion summary** (cagr / edge / drawdowns
  / `pct_beating_benchmark`) but **still rendered** in the per-start detail
  table, flagged `short window, excluded` (design (b): keep raw rows visible,
  protect only the poisoned summary; documented in the `.mli`). Surfaced as
  `--min-window-days N` on `bin/rolling_start_eval.ml` + a `Runner.config`
  field threaded into `Rolling_start_types.build`. **Backward compatible:**
  default `0` excludes nothing — bit-identical to prior behaviour; negative
  raises. 7 new tests pin the predicate, default-no-op, boundary (== threshold
  ⇒ included), pct-beating exclusion, and the detail-table flag.
  Verify: `dune runtest trading/backtest/rolling_start/` (18 type + 16 runner
  tests pass).
- **[x] A2 — "impossible drawdown" (MaxDD 190.4 %) investigated → root-caused
  upstream; no rolling-start-layer fix.** Both the 190.4 % MaxDD and 156.3 %
  MaxUnderwaterVsInitial on the `2023-01-26` row are different lenses on the
  **same negative-NAV step** — a true reflection of the equity curve, not a
  rolling-start projection/fork defect (`per_start_of_summary` reads the
  metrics verbatim; `Fork_pool` reassembles per-start records by index, no
  summary mixing). Root cause is upstream in **portfolio cash accounting**: the
  buy-side cash floor (`Portfolio._check_sufficient_cash`) permits negative
  `current_cash` credited against a **stale** `unrealized_pnl_per_position`
  cushion, so a later mark can drive NAV < 0 ⇒ >100 % DD. Distinct from the
  fixed 2026-05-15 NAV-fallback bug (that flatlined NAV to non-negative cash,
  ≤100 % DD only). **No guard added** in the rolling-start layer — clamping the
  metric would mask a real data-integrity signal (the fail-loud philosophy of
  `portfolio_valuation.ml`). Reproduction is warehouse-gated
  (`/tmp/snap_top3000_2011`). Full writeup +
  recommended portfolio-owner follow-up:
  `dev/notes/rolling-start-maxdd-investigation-2026-06-12.md`.

### Recent activity (2026-06-11)

- **[x] Rolling-start robustness runner v2 — start-date × edge-vs-benchmark
  matrix** (branch `feat/rolling-start-v2`, READY_FOR_REVIEW). P0 per
  `dev/notes/next-session-priorities-2026-06-11-PM.md`: the single-start
  headline numbers are misleading; the honest evaluation is "across many start
  dates each held to today, does the strategy robustly beat buy-and-hold of the
  benchmark?" Extends the existing `rolling_start` lib/bin (NOT a fresh module),
  additively — existing report fields, default behaviour, goldens bit-identical.
  Plan: `dev/plans/rolling-start-v2-2026-06-11.md`. Four increments:
  - **Jittered start enumeration** — `Rolling_start_runner.enumerate_starts_jittered`:
    the fixed base grid with a deterministic seeded per-point forward jitter
    (uniform `[0, stride_days)`), so starts don't all land on calendar
    boundaries. First point pinned; jittered points crossing `end_date` dropped.
    Pure, deterministic given seed (exact dates pinned in tests for seed 42).
  - **Benchmark overlay** — `Rolling_start_runner.bah_cagr_pct` (pure projection
    of a `(date, close)` series → buy-and-hold CAGR over the same window via the
    walk-forward `cagr_pct` convention; `nan` when unpriceable). `per_start`
    gains `benchmark_cagr_pct` + `edge_pct` (= strategy − benchmark); the report
    gains an `edge` dispersion summary + `pct_beating_benchmark` + an
    "Edge-vs-benchmark robustness" markdown block (median edge / worst start /
    % beating). Series sourced (snapshot mode) from `Daily_panels.read_history`
    on the benchmark symbol's adjusted closes; designed so SPY / BRK-B /
    GSPC.INDX all work.
  - **Richer per-start matrix columns** — `per_start` gains `sharpe` (summary
    `SharpeRatio`), `time_underwater_pct` (`Convexity_stats.time_underwater_pct`
    over the run's NAV curve), and `realized_return_pct` (strips summary
    `UnrealizedPnl` from the terminal value so an AXTI-style unrealized mark
    can't flatter recent-start rows). Matrix detail table renders start ×
    {CAGR, benchmark CAGR, edge, Sharpe, capital-DD, time-underwater, MaxDD,
    realized}.
  - **Parallel fork-per-start** — `run` forks each start via `Fork_pool`
    (`run_each_forked` at `--parallel 1` = the N=3000 memory-safe path mirroring
    the walk-forward fork-per-fold runner; `run_parallel ~parallel` for `>1`),
    result order = ascending start-date order. `bin/rolling_start_eval.ml` wires
    `--stride-days` (alias of `--start-stride-days`), `--jitter-seed`,
    `--benchmark SYMBOL`, `--parallel N` (`--snapshot-dir` already existed).
  - Verify: `dune runtest trading/backtest/rolling_start/` (27 tests pass: 7 new
    jitter, 3 benchmark/edge, 1 matrix-columns in the runner suite; 3 edge/% +
    extended markdown in the types suite). No full matrix backtest run here —
    that's the dispatcher's job after merge (P1 universe-composition dependency;
    every produced number is on the old universe until P1 lands).

### Recent activity (2026-06-09)

- **[x] N=3000 walk-forward parallel=1 crash fixed — fork-per-fold for
  the broad-universe snapshot path** (branch
  `feat/backtest-wf-cache-reuse`). The `--snapshot-dir` WF runner
  crashed at `--parallel 1` on N=3000 after ~13 folds with a Rosetta
  `VmTracker slab allocator has run out of memory`
  (`VMAllocationTracker.cpp:659`, exit 133): each fold's
  `run_backtest` created **and closed** its own `Daily_panels` decode
  cache, so every fold re-decoded all ~3015 symbols
  (`misses_per_symbol = 1.00` logged on *every* fold). The cumulative
  ~3015×N-folds fresh VM allocations exhaust the process's fixed
  `VMAllocationTracker` slab; separately, the known ~25 MB/backtest
  GC-uncollectible residue scales to ~340 MB/fold at N=3000 and OOMs
  the 7.8 GB container across ~29 folds even with an in-process shared
  cache.
  - Root cause confirmed (diagnose loop, not assumed): reproduced the
    crash, instrumented per-fold cache stats + RSS. Per-fold cache
    `misses=3015 evictions=0` confirmed full rebuild each fold; RSS
    sawtoothed to ~5.8 GB/fold with a ~340 MB/fold inter-fold floor
    creep (the residue), so an in-process shared cache alone OOMs.
  - Fix: for the broad-universe path (`bar_data_source = Snapshot` ∧
    `parallel = 1`), the executor now runs each fold in its own forked
    child via new `Fork_pool.run_each_forked` (one child at a time —
    the parallel>1 path already forks, but runs ≥2 concurrent N=3000
    caches which itself OOMs). Each fold's decode + transient heap +
    the GC-residue live and **die with the child**, and the child's
    exit also resets the `VMAllocationTracker` slab. Only one child's
    transient is resident at a time → peak single-process RSS ~5.2 GB,
    well under the 7.8 GB ceiling; the parent stays ~40 MB.
  - Surface:
    - `fork_pool.{ml,mli}` — new `run_each_forked` (forks each job in
      its own child sequentially, parent persists; distinct from
      `run_parallel ~parallel:1`'s in-process fast path).
    - `walk_forward_executor.{ml,mli}` — `execute_spec` builds a
      parent-owned `Daily_panels` via the new
      `Bar_data_source.build_shared_panels` and runs folds via
      `run_each_forked` when Snapshot+parallel=1; closes the handle once
      after the grid (`Exn.protect`). The per-fold `Gc.compact` is
      skipped on the forked path (the child exit reclaims it).
    - `bar_data_source.{ml,mli}` — `build_shared_panels` /
      `close_shared_panels` (a caller-owned cache; in-process callers
      get true cross-call decode reuse).
    - `panel_runner.{ml,mli}` + `runner.{ml,mli}` — `?shared_panels`
      threaded through `run` / `run_backtest`: read through a
      caller-owned cache without closing it. `None` (the default) is
      byte-identical to the prior per-run create/close path.
  - Tests:
    `test_walk_forward_snapshot_parity.ml` gains
    `test_shared_panels_reused_across_backtests` — two backtests over
    one shared `Daily_panels` decode each symbol once (second run adds
    zero misses; `evictions = 0`). Existing snapshot/CSV parity +
    flag-off tests still pass (signature additions are default-off).
  - Verify (acceptance): the full 29-fold × 2-variant N=3000 WF at
    `--parallel 1` completes without the VMTracker crash and writes
    `aggregate.sexp` + `fold_actuals.sexp`:
    `SNAPSHOT_CACHE_MB=4096 dune exec
    trading/backtest/walk_forward/bin/walk_forward_runner.exe --
    --spec <rolling-29-fold-spec> --snapshot-dir <top3000-snapshot>
    --parallel 1 --out-dir <out>`. `misses_per_symbol = 1.00` per fold
    is expected and harmless on the forked path (each fold is an
    isolated child). Unblocks broad-PIT WF-CV.

- **[x] `walk_forward_runner.exe --snapshot-dir`** (branch
  `feat/backtest-wf-snapshot`). Threads a `Backtest.Bar_data_source.t`
  through `Walk_forward.Walk_forward_executor` into every fold's
  `Backtest.Runner.run_backtest`, so broad-universe (N≥1000) WF-CV can
  read OHLCV from a pre-built snapshot warehouse instead of building the
  whole universe's bars in-process from CSV (superlinear / OOMs at
  N≥1000 per `feedback_large_n_needs_snapshot_mode`). Default-off:
  omitting the flag is byte-identical to the prior CSV path. Unblocks
  the broad-PIT WF-CV experiment agenda.
  - Surface:
    - `walk_forward_executor.{ml,mli}` — `execute_spec` gains
      `?bar_data_source:Backtest.Bar_data_source.t`, threaded down
      through `_run_one` → `_extract_fold` → `run_backtest` (the
      `[@inline never]` + `Gc.compact` memory discipline kept intact).
    - `bin/walk_forward_runner.ml` — `--snapshot-dir <path>` flag,
      resolved via the shared `Scenario_lib.Bar_source_resolver.resolve`
      (same resolver `rolling_start_eval` / `scenario_runner` use; reads
      `<dir>/manifest.sexp`, exits non-zero on a missing/corrupt
      manifest at parse time).
  - Tests:
    `trading/trading/backtest/walk_forward/test/test_walk_forward_snapshot_parity.ml`
    — (1) end-to-end snapshot-vs-CSV parity: same synthetic OHLCV stream
    built into both a CSV dir (via `TRADING_DATA_DIR`) and a snapshot dir
    over `Backtest.Runner.all_snapshot_symbols`, a 2-fold WF run in each
    mode yields byte-identical `aggregate` + `fold_actuals`; (2) flag-off
    backward-compat: `?bar_data_source:None` is byte-identical to omitting
    it at the executor seam.
  - Verify:
    `dune exec trading/backtest/walk_forward/test/test_walk_forward_snapshot_parity.exe`.

- **[x] P3 — time-underwater + antifragility convexity prototypes**
  (branch `feat/rolling-start-time-underwater`). P3 ("prototype, hold
  skeptically") of `dev/plans/evaluation-objective-and-metrics-2026-06-07.md`
  §P3: pure analysis-only metrics over an equity curve / period-return
  `float list`, companion to `Dispersion_stats`.
  - Surface: new `Convexity_stats` pure module at
    `trading/trading/backtest/rolling_start/lib/convexity_stats.{ml,mli}`:
    - `time_underwater_pct` — fraction of NAV observations strictly below
      the running prior high-water mark, ×100 (monotone-up / flat /
      empty / singleton → 0.0).
    - `tail_ratio` — convexity tail-ratio `|p95| / |p5|` over a return
      series (type-7 percentile via `Dispersion_stats.percentile`;
      `+infinity` when p5 mag is 0 and p95 mag positive; 0.0 on empty /
      both-tails-zero).
    - `return_skew` — third standardized moment (population variance,
      matching the simulation-layer `Skewness` convention; 0.0 on empty /
      singleton / zero-variance).
  - Additive / analysis-only: not wired into the default metric suite,
    no strategy behaviour change, all existing goldens bit-identical →
    no experiment-flag gate. (NB: step-based counterparts
    `TimeInDrawdownPct` / `TailRatio` / `Skewness` already exist in the
    simulation metrics layer; these are the equity-curve formulations the
    rolling-start harness consumes.)
  - **worst-vol-decile conditional return: DEFERRED** — it needs a
    per-period volatility / regime tag not available from a plain return
    series; the plan flags it the most involved prototype and explicitly
    says not to build new regime-tagging infra here. Shipped
    time_underwater + tail_ratio + skew only.
  - Verify: `dune runtest trading/backtest/rolling_start/` (51 tests:
    19 dispersion-stats + 17 convexity-stats + 8 types + 7 runner).

- **[x] Rolling-start dispersion — pure stats core (PR-1 of 2)**
  (branch `feat/rolling-start-dispersion`). P1 ("highest value") of
  `dev/plans/evaluation-objective-and-metrics-2026-06-07.md` §2: judge a
  strategy on the *distribution* of terminal outcomes across many
  backtest start dates (to a fixed end), not one full-window number —
  start-date robustness as the primary evaluation lens (plan §1.3).
  - Surface: new `rolling_start` lib at
    `trading/trading/backtest/rolling_start/lib/`:
    - `Dispersion_stats` — pure `percentile` (NumPy linear / type-7),
      `median`, `iqr`, and a `summarize` → `summary`
      (median / p10 / IQR / min / max / n) over a `float list`. The
      rock-solid numeric core; unit-tested against hand-computed values
      with no backtest.
    - `Rolling_start_types` — `per_start` row (start_date + CAGR +
      `MaxUnderwaterVsInitialPct` capital-relative DD (#1471) +
      peak-relative MaxDD), `report` (one `Dispersion_stats.summary` per
      metric), `build`, and a `to_markdown` renderer mirroring the
      `walk_forward_render` table style + a derived sexp.
  - Additive / analysis-only: no strategy behaviour, runs nothing in the
    default pipeline → no experiment-flag gate.
  - Verify: `dune runtest trading/backtest/rolling_start/` (27 tests:
    19 dispersion-stats + 8 types).
  - **[x] Follow-up (PR-2) — `rolling_start_eval` exe** (READY_FOR_REVIEW,
    branch `feat/rolling-start-eval`, PR #1476). Enumerates start dates
    (quarterly cadence, `--start-stride-days` default 91), runs
    `Backtest.Runner.run_backtest` per start (with `--snapshot-dir`
    threaded via `Scenario_lib.Bar_source_resolver.resolve`, reusing the
    `walk_forward_executor` per-fold run + metric-map extraction
    pattern), collects per-start metrics, and emits the `report`.
    - Surface: new `Rolling_start_runner` lib module at
      `trading/trading/backtest/rolling_start/lib/rolling_start_runner.{ml,mli}`
      (`enumerate_starts` — pure quarterly-cadence enumeration + clipping;
      `per_start_of_summary` — pure projection of a `Backtest.Summary.t`
      into a `per_start`, CAGR via `Walk_forward_runner.cagr_pct` +
      `MaxUnderwaterVsInitialPct` + `MaxDrawdown`; `run` — the N-backtest
      orchestration). Thin CLI wrapper at
      `trading/trading/backtest/rolling_start/bin/rolling_start_eval.ml`
      (`--scenario` / `--end-date` / `--start-stride-days` /
      `--fixtures-root` / `--snapshot-dir` / `--out`).
    - Additive / analysis-only: runs nothing in the default pipeline, no
      strategy behaviour change → no experiment-flag gate.
    - Tested (CI, no external data): `test_rolling_start_runner` — 7
      tests pinning the start-date enumeration (quarterly cadence,
      first/last clipping, empty cases, non-positive-stride rejection)
      and the per-start metric extraction (CAGR + capital-relative DD +
      peak-relative DD from a hand-built `Summary.t`, NaN surfacing).
    - **Data-gated / uncovered**: a true multi-start end-to-end PIT run
      (`run` driving real `Runner.run_backtest` calls) needs deep PIT
      OHLCV / `EODHD_API_KEY`, unavailable in GHA; the CLI plumbing is
      smoke-verified on `smoke/bull-2019h2.sexp` with `--end-date` equal
      to the scenario start (empty enumeration → empty report, no
      backtest).
    - Verify: `dune runtest trading/backtest/rolling_start/` (34 tests:
      19 dispersion-stats + 8 types + 7 runner).

### Recent activity (2026-06-04)

- **[x] `scenario_runner --snapshot-dir <path>`** (READY_FOR_REVIEW,
  branch `feat/scenario-runner-snapshot-dir`). Exposes snapshot
  (streaming) bar-reading at the `--dir` golden entry point so a
  large-N golden cell (e.g. N=3000) reads OHLCV from a pre-built
  snapshot warehouse instead of building the whole universe's bars
  in-process from CSVs (~14 GB resident at N=3000). Mirrors
  `backtest_runner.exe --snapshot-dir` exactly: the manifest at
  `<dir>/manifest.sexp` is read once at parse time and the resulting
  `Bar_data_source.Snapshot {…}` is reused for every cell; missing /
  corrupt manifest exits 1. With no flag, behaviour is bit-identical
  to today's CSV mode.
  - Surface: new `Scenario_lib.Bar_source_resolver.resolve` (lib
    module + `.mli`, mirrors `backtest_runner._resolve_bar_data_source`
    so the manifest-read + error path is unit-testable);
    `scenario_runner.ml` parses `--snapshot-dir`, resolves once, and
    threads `?bar_data_source` into `Backtest.Runner.run_backtest`.
  - Verify: `dune runtest trading/backtest/scenarios/test/` (new
    `test_bar_source_resolver` — `resolve None -> None`;
    `resolve (Some dir) -> Snapshot {…}` over a real written manifest).
  - Unblocks running large-N goldens locally in snapshot mode at
    bounded RSS — a prerequisite step toward the tier-4 release-gate
    at N≥5000 (see § Blocked on).

### Recent activity (2026-05-14..22, since last refresh)

- **#1151 — cost-model overlay scaffold** (MERGED 2026-05-17). 4-knob
  `Backtest_cost_model.Cost_model` module (`per_trade_commission`,
  `per_share_commission`, `bid_ask_spread_bps`,
  `market_impact_bps_per_pct_adv`; `zero` / `retail_default` /
  `institutional_default` presets; `validate` / `to_engine_costs` /
  `apply_per_trade_commission` / `market_impact_bps` /
  `apply_market_impact` API; ~85 LOC impl + ~130 LOC mli + ~290 LOC
  test, 27 unit tests). **Not yet wired into simulator** — 4
  deferred items tracked in `dev/status/cost-model.md`: (1)
  `scenario.mli` plumbing; (2) `Simulator._apply_trades_best_effort`
  hook; (3) ADV plumbing for market-impact; (4) Cell E re-pin under
  cost overlay. See `dev/status/cost-model.md` for the wiring track.
- **Fork-based job parallelism for walk-forward + Bayesian runners**
  (#1199 / #1200 / #1202 / #1203, MERGED 2026-05-18..19). Motivated
  by `base.Random` DLS leak (#1201) requiring a fresh process per
  fold for reproducibility. Stack:
  - **#1199** `Gc.compact` between folds + `_extract_fold` scoping
    (in-process leak mitigation; partial fix prior to fork-pool).
  - **#1200** `Fork_pool` library — `trading/trading/backtest/
    fork_pool/` (~200 LOC + tests).
  - **#1202** wire `Fork_pool` into `Walk_forward_executor`.
  - **#1203** `--parallel N` CLI flag on `walk_forward_runner.exe` +
    `bayesian_runner.exe`.
- **#1197 — plan(walk-forward): parallelise executor — design**
  (MERGED 2026-05-19). The implementation lives in the fork_pool
  stack above; #1197 is the design-doc commit.

**15y memory cliff RESOLVED 2026-05-08..10.** Three data-side fixes (#988
Fix C stream `csv_snapshot_builder` per-symbol, #992 Fix A dedupe
`Daily_panels` LRU caches, #993 Fix B skinny `step_result.portfolio`
projection) + four simulator/orders-side fixes (#1019 simulator NAV
`_resolve_price` cache + avg-cost fallback, #1020 `Order_manager`
`active_orders` index O(N)→O(1) for `list_orders ~ActiveOnly`, #1024
simulator Closed-positions prune from positions Map, #1014 portfolio
`trade_history` prepend O(N²)→O(N)) + audit-loop hoist (#1015 trade_context
audit_idx out of trades.csv iter loop) brought 15y SP500 wall from ~5 h to
~13.6 min (≈22×) and peak RSS from 11.4 GB to ~766 MB band. Root-cause
investigation pinned in `dev/notes/15y-memory-cliff-2026-05-08.md` (PR #987)
and `dev/notes/15y-memory-cliff-validation-2026-05-08.md`. SCALE cell scaffolding
extended via #897 (tier4-broad-1y). Cell-E 15y engineering blocker (simulator
NAV-fallback equity_curve corruption) tracked in
`dev/notes/cell-e-15y-engineering-blocker-2026-05-09.md` — largely addressed by
#1019 + #1063 (`Portfolio_view` avg-cost fallback when `get_price=None`,
MERGED 2026-05-13). 

Steps 1+2 (`feat/backtest-perf-tier1-catalog`, PR #574) merged
2026-04-26T16:07Z. **`perf-tier1.yml` landed via PR #616 on 2026-04-27**
— per-PR perf smoke is now wired. **Tier-1 universe-path bug fixed
+ gate flipped to strict on `fix/perf-tier1-universe-path`
2026-04-28**: explicit `--fixtures-root` flag, `Fixtures_root.resolve`
helper, `continue-on-error: false`, `PERF_CATALOG_CHECK_STRICT=1`;
local smoke 4/4 PASS. **Tier-2 nightly workflow landed via PR #622 on
2026-04-27**: `perf_tier2_nightly.sh` +
`.github/workflows/perf-nightly.yml`, six tier-2 cells, 30 min/cell
budget, cron `0 5 * * *` (22:00 PT). **Tier-3 weekly workflow open
at `feat/backtest-perf-tier3-weekly` on 2026-04-27**:
`perf_tier3_weekly.sh` + `.github/workflows/perf-weekly.yml`, two
tier-3 cells (`perf-sweep/{bull-1y, bull-3y}`), 2 h/cell budget,
cron `0 7 * * 1` (Monday 00:00 PT). **Engine-layer-pooling PR-1
(Gc.stat instrumentation, panel_runner per-step snapshots) merged
via PR #618 on 2026-04-27**; **PR-2 (per-symbol Scratch type +
buffer-reusing internal helpers + parity gate) merged via PR #626
on 2026-04-27**; **PR-3 (thread Scratch through `Engine.update_market`
per-tick loop) opened at `feat/backtest-perf-engine-pool-thread` on
2026-04-27 — collapses per-tick float-array allocs to per-symbol-once;
parity-tested via `test_panel_loader_parity` and
`test_engine_scratch_threading_parity`**; **PR-4 (transient
buffer pool for `_sample_student_t.sum_squares` accumulator +
`Hashtbl.find_or_add` in `update_market`) merged via PR #632 on
2026-04-27**; **PR-5 (matrix re-run validation) opened at
`feat/backtest-perf-engine-pool-matrix` on 2026-04-28 — measured
β: 4.3 → 3.94 MB/symbol (−8%, far short of plan's 1-1.5 target);
wall: −36% at 292×6y (2:51 → 1:49). All 5 engine-pool PRs landed
or in flight. See `dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md`**.
Step 5 (release_perf_report OCaml exe) tracked separately;
landed via #585 / #606 on the test-data + perf-runner side. Tier-4
release-gate scenarios structurally unblocked since data-panels
Stage 4.5 PR-B (#604) merged 2026-04-27T02:33Z. **Tier-4 release-gate is local-only**: `dev/scripts/perf_tier4_release_gate.sh`
runs at release-cut time per
`dev/notes/tier4-release-gate-checklist-2026-04-28.md`. Four
`goldens-broad/` cells (`bull-crash-2015-2020`,
`covid-recovery-2020-2024`, `decade-2014-2023` (NEW),
`six-year-2018-2023`) all baking `(config_overrides
((universe_cap 1000)))`, 8 h/cell budget. The accompanying GHA
workflow `.github/workflows/perf-release-gate.yml` was removed
2026-04-28 (could not satisfy `Full_sector_map` data load on GHA).
**N≥5000 release-gate stays P1** pending daily-snapshot streaming.

## Interface stable
NO

## Goal

Continuous perf coverage in CI + formal release-gate strategy. Two
regression dimensions tracked together:

1. **Trading-performance metrics** — return %, Sharpe ratio, win
   rate, max drawdown, trade count, P&L. Catches strategy
   regressions: "did this commit change Sharpe by 0.2?"
2. **Infra-performance profile** — peak RSS, wall-time, per-phase
   allocation breakdown, memtrace .ctf. Catches infra regressions:
   "did this commit double peak memory at N=1000?"

A single scenario run produces BOTH outputs, with separate
pass-criteria sections.

## Plan

`dev/plans/perf-scenario-catalog-2026-04-25.md` (PR #550) — full
4-tier catalog (per-PR / nightly / weekly / release) + cataloging
mechanics + release-gate procedure.

## Open work

- **`perf/daily-panels-binary-search`** (PR #845, addresses #844) — open
  for review. Replaces `Daily_panels.read_today`'s `List.find` and
  `read_history`'s `List.filter + List.sort` with binary-search slice
  over a date-sorted `Snapshot.t array`. Bumps `_snapshot_cache_mb` from
  256 to 1024 to fit a 15y × 500-symbol resident snapshot footprint
  (the prior cap caused per-Friday cache thrashing). Measured 5y sp500
  ~7 min → ~4 min (2× speedup); per-call cost ratio at 15y ~150×, so
  the super-linear blow-up flagged by #844 collapses back to roughly
  linear. Bit-identical metrics to the post-#828 baseline confirm the
  fix is pure perf. Files: `daily_panels.ml`, `panel_runner.ml`. Verify:
  `dune runtest analysis/weinstein/snapshot_runtime trading/backtest/test
  trading/weinstein/strategy` — all 86+ tests pass; `scenario_runner.exe
  --dir goldens-sp500 --parallel 1` finishes in ~4 min.
- **`feat/trade-audit-cascade-rejections`** (trade-audit cascade-rejection
  counts, extension to PR-2) — open for review. Extends the per-trade audit
  shipped in #642 with per-Friday cascade-phase admission counts. Lets the
  audit answer "did the macro gate ever block a candidate", "was the sector
  filter trivially permissive", "did the RS hard gate ever filter shorts" —
  questions the per-trade audit alone can't answer because filtered
  candidates never reach the per-entry alternatives bucket. `Screener.result`
  gains a `cascade_diagnostics` field (additive); `Audit_recorder` gains a
  `record_cascade_summary` callback fired at the end of each Friday's
  `_screen_universe`; `Trade_audit.t` gains a `cascade_summaries` queue and
  the `audit_blob` envelope persists both lists in `trade_audit.sexp`. 13
  new tests (5 screener diagnostic + 5 trade_audit cascade + 3 e2e capture).
  Bit-exact behavioural parity — pure observer extension. Verify:
  `dune build && dune build @fmt` clean; existing parity tests
  (`test_panel_loader_parity`, `test_runner_hypothesis_overrides`) unchanged.
- **PR #550** (plan, doc-only) — MERGED 2026-04-25.
- **`feat/backtest-perf-tier1-catalog`** (Steps 1+2) — open for review.
  Adds tier headers to all 15 catalog scenarios, the
  `perf_catalog_check.sh` integrity gate (annotate-only), the
  `perf_tier1_smoke.sh` runner, and the `perf-tier1.yml` GHA
  workflow.
- **`feat/backtest-perf-engine-pool-instrument`** (engine-pooling PR-1) —
  PR #618 open for review. Per-step `Gc.stat` snapshots in
  `Panel_runner.run`, gated by the existing `?gc_trace`. Confirms
  `Engine.update_market` is the dominant per-tick allocator before
  the buffer-reuse refactors land (PR-2..PR-4 per
  `dev/plans/engine-layer-pooling-2026-04-27.md`).
- **`feat/backtest-perf-engine-pool-thread`** (engine-pooling PR-3) —
  open for review. Threads `Price_path.Scratch.t` through
  `Engine.update_market` per-tick by giving `Engine.t` a
  `(symbol, Scratch.t) Hashtbl.t` and replacing the
  `Price_path.generate_path` call site with `generate_path_into ~scratch`.
  Adds `Price_path.Scratch.required_capacity` to make the per-symbol
  re-allocation decision pure (no throwaway probe scratch). New
  `test_engine_scratch_threading_parity` pins bit-equality between a
  reused engine and N fresh engines. Bit-exact parity vs PR-2
  validated by `test_panel_loader_parity` on both `tiered-loader-parity`
  and `panel-golden-2019-full` scenarios.
  See `dev/notes/engine-pool-pr3-impact-2026-04-27.md` for the
  per-call allocation breakdown (~3.2 KB float-array alloc dropped
  per `update_market` call after the symbol's first day).
- **`feat/backtest-perf-engine-pool-pool`** (engine-pooling PR-4) —
  PR #632 merged 2026-04-27. Adds `Buffer_pool.{ml,mli}` (Stack-backed
  pool of `float array` workspaces with `acquire ?capacity () /
  release` API, bounded by `max_size`). Routes the per-call
  `_sample_student_t` chi-squared accumulator (was `let acc = ref
  0.0`) through a 1-slot float array borrowed from a per-`Scratch`
  pool. Switches `Engine._scratch_for_symbol` from `match Hashtbl.find
  … with Some …` to `Hashtbl.find_or_add … ~default` to remove the
  per-call `Some` allocation that dominated `update_market.(fun)` per
  the post-PR-A memtrace. FP order is unchanged — same left-fold for
  loop, just a different storage location for the accumulator. New
  9-test `test_buffer_pool.ml` pins the pool's API contract;
  `test_golden_bit_equality` and `test_panel_loader_parity` (the
  load-bearing parity gates) pass unchanged.
- **`feat/backtest-perf-engine-pool-matrix`** (engine-pooling PR-5) —
  open for review. Re-runs the 4-cell matrix (N×T = {50,292}×{1y,6y})
  with all four engine-pool PRs landed. **β: 4.3 → 3.94 MB/symbol
  (−8%, far short of plan's 1-1.5 MB/symbol target). Wall: −36% at
  292×6y (2:51 → 1:49)**. The cumulative-promotion target *was* hit
  (50×1y `promoted_words = 85.8M` < plan's 100M target); peak RSS
  didn't move because at the post-#602+GC-tuned baseline RSS is
  dominated by the major-heap working set, not allocation churn. New
  fit: `RSS ≈ 67 + 3.94·N + 0.19·N·(T−1)` MB. Tier-4 implication:
  N=1000×10y at ~5.7 GB still fits 8 GB; N≥5000 still requires
  daily-snapshot streaming (separate plan
  `dev/plans/daily-snapshot-streaming-2026-04-27.md`). Note:
  `dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md`. No
  code changes — pure measurement + docs PR.
- **`feat/backtest-perf-release-report`** (Step 6 — release_perf_report
  OCaml exe) — open for review. Adds
  `trading/trading/backtest/release_report/` library +
  `trading/trading/backtest/bin/release_perf_report.ml` binary +
  11-test fixture (`test_release_perf_report.ml`). Replaces the
  deleted Python `perf_sweep_report.py`. End-to-end smoke verified:
  feeding two synthetic scenario dirs reproduces the full markdown
  shape including the `:rotating_light:` flag on +20% RSS regression.
- **`feat/backtest-perf-tier3-weekly`** (Step 4 — tier-3 weekly) —
  open for review. Adds `dev/scripts/perf_tier3_weekly.sh` +
  `.github/workflows/perf-weekly.yml`. Auto-discovers both
  `;; perf-tier: 3` scenarios under
  `trading/test_data/backtest_scenarios/perf-sweep/{bull-1y,bull-3y}.sexp`,
  runs each via `scenario_runner.exe --parallel 1` with
  `timeout 7200`, publishes wall + peak-RSS table to
  `$GITHUB_STEP_SUMMARY`. Cron `0 7 * * 1` (Monday 00:00 PT PDT /
  23:00 PT Sunday PST), 2 h after perf-nightly's 05:00 UTC slot and
  17 min before the orchestrator's 07:17 UTC slot. Non-blocking
  (`continue-on-error: true`) — same VISIBILITY-first posture as
  tier-1/tier-2.
- **`feat/backtest-perf-tier4-release-gate`** (Step 5 — tier-4
  release-gate at N=1000) — local-only. Adds
  `dev/scripts/perf_tier4_release_gate.sh` (the GHA workflow yaml
  added in this branch was removed 2026-04-28 because it could not
  satisfy `Full_sector_map` data load on GHA — see
  `dev/notes/tier4-release-gate-checklist-2026-04-28.md`).
  Auto-discovers four `;; perf-tier: 4` scenarios under
  `trading/test_data/backtest_scenarios/goldens-broad/{bull-crash-2015-2020,covid-recovery-2020-2024,decade-2014-2023,six-year-2018-2023}.sexp`,
  runs each via `scenario_runner.exe --parallel 1` with
  `timeout 28800` (8 h). All four sexps now bake
  `(config_overrides ((universe_cap 1000)))` so each cell runs at
  N=1000 self-contained. The four sexps had been SKIPPED placeholders
  pinned to the 1,654-symbol era; this PR resets them to
  BASELINE_PENDING (wide ranges) for the first run to fill in. The
  new `decade-2014-2023.sexp` is the canonical 10-year release-gate
  cell. Per
  `dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md`,
  N=1000×10y projects to ~5.7 GB (fits 8 GB ceiling). N≥5000 stays
  blocked on daily-snapshot streaming. First run is **not yet
  scheduled** — out-of-PR follow-up.

## Completed

- **15y memory-cliff resolution + perf hotspot fixes** (2026-05-08..13). Combined
  data-side + simulator-side + orders-side work brought 15y SP500 wall from ~5 h
  to ~13.6 min (~22×) and peak RSS from 11.4 GB to ~766 MB. MERGED:
  - **#987** — investigation: 15y SP500 memory cliff root cause (doc-only;
    `dev/notes/15y-memory-cliff-2026-05-08.md`). Identifies 5 contributing
    structures; headline is post-simulation analytics phase keeping full `steps`
    list resident while folding 11 metric computers + 8 sexp/csv writers.
  - **#988** — Fix C: stream `csv_snapshot_builder` per-symbol (15y memory).
  - **#992** — Fix A: dedupe `Daily_panels` LRU caches (15y memory).
  - **#993** — Fix B: project `step_result.portfolio` to skinny summary (15y memory).
  - **#1014** — fix(portfolio): prepend trades to `trade_history` (O(N²) → O(N)).
  - **#1015** — perf(backtest): hoist `trade_context` `audit_idx` out of trades.csv iter loop.
  - **#1019** — fix(simulation): cache + avg-cost fallback in `_resolve_price`
    (extracts `Portfolio_valuation`; resolves NAV-fallback equity_curve corruption
    flagged in `dev/notes/cell-e-15y-engineering-blocker-2026-05-09.md`).
  - **#1020** — perf(orders): bound `list_orders ~ActiveOnly` walk via
    `active_orders` index (O(N) → O(1) mirror on `Order_manager`).
  - **#1024** — perf(simulation): prune Closed positions from simulator positions
    Map (15y wall 5h → 13.6 min, ~22×).
  - **#1063** — fix(portfolio_view): avg-cost fallback when `get_price=None`
    (2026-05-13 follow-on to #1019).

- **Tier-4 release-gate SCALE scaffolding for N=5k/10k × 5-10y** (2026-05-03,
  `feat/backtest-tier4-scaffolding`). Adds three scenarios + a dedicated
  runner script for the snapshot-mode-only N≥5000 release-gate cells.
  Files:
  - `trading/test_data/backtest_scenarios/goldens-broad/tier4-N5000-5y.sexp`
    (5y × N=5000, 2019-2023).
  - `trading/test_data/backtest_scenarios/goldens-broad/tier4-N5000-10y.sexp`
    (10y × N=5000, 2014-2023; mirrors `decade-2014-2023.sexp` window).
  - `trading/test_data/backtest_scenarios/goldens-broad/tier4-N10000-5y.sexp`
    (5y × N=10000, 2019-2023; chose 5y over 10y to keep wall budget
    reasonable at the widest cell).
  - `dev/scripts/run_tier4_release_gate.sh` — auto-discovers
    `;; perf-tier: 4-scale` scenarios, runs each via `scenario_runner.exe`
    with `timeout 43200` (12 h default), `--snapshot-mode`, and
    `--fixtures-root`. Supports `--dry-run` (prints discovered cells +
    planned commands without executing) and `--help`.
  Scaffolding only — `expected` ranges are intentionally permissive
  (`BASELINE_PENDING_AFTER_FIRST_RUN`); first local run on the user's 8 GB
  box (under snapshot mode + auto-built corpus) populates the canonical
  baseline. Distinct sub-tier (`4-scale` vs the existing `4`) keeps these
  cells OFF the standard `dev/scripts/perf_tier4_release_gate.sh` until
  the snapshot corpus + 5-10k symbol data plumbing land. CSV-mode formula
  upper bound: N=5000×5y ≈ 24 GB, N=5000×10y ≈ 28 GB, N=10000×5y ≈ 47 GB —
  all far beyond any single runner; reachable only under snapshot mode
  (Phase E §F3 cache-bounded RSS ~50-200 MB). Verify:
  `dev/scripts/run_tier4_release_gate.sh --dry-run` (3 cells discovered),
  `dune runtest trading/backtest/scenarios/test/` (scenarios parse, 10/10),
  `PERF_CATALOG_CHECK_STRICT=1 sh trading/devtools/checks/perf_catalog_check.sh`
  (20/20 tagged). The actual gate run is a follow-up local-only task,
  blocked on (a) the ops-data 15y sp500 historical fetch in flight and
  (b) the 5-10k symbol snapshot corpus not yet built.

- **G6 — decade-2014-2023 non-determinism investigation + forward-guard test**
  (2026-04-30, `feat/backtest-g6-decade-nondeterminism`). Investigation note
  `dev/notes/g6-decade-nondeterminism-investigation-2026-04-30.md` audits the
  scenario_runner.ml fork-per-cell flow and identifies the primary source of
  the decade cell's `145 trades vs 135 trades` drift across run modes:
  **`trading/orders/lib/create_order.ml:_generate_order_id` mints order IDs
  with a `Time_ns_unix.now()` ns-precision prefix; these IDs are hashtable
  keys in `Trading_orders.Manager.orders`; `Manager.list_orders` iterates via
  `Hashtbl.fold` so iteration order depends on bucket placement of keys.**
  Different wall-clock during order creation → different IDs → different
  buckets → different `process_orders` iteration order → different fill
  order under cash-floor / sizing edges → divergent metrics on long-horizon
  ×broad-universe scenarios. Why only the 10y cell drifts: the multiplicative
  factor 520 Fridays × N=1000 puts the per-Friday flip probability into a
  range where ~40 % of runs see at least one flip; shorter cells stay below
  the threshold. Why batch-of-4 is more divergent than single: 4 children
  competing for cores produce more clock jitter, more divergent IDs.
  Reproduction on GHA-sized data (22 symbols × 15 months) does NOT surface
  the divergence — the multiplicative surface is ~1300 cell-Fridays vs
  520k for decade. The fix surface is `trading/orders/lib/create_order.ml`,
  outside this agent's scope (a "core module" per
  `.claude/rules/qc-structural-authority.md` A1 list); flagged for
  feat-weinstein / orders-owner follow-up. Forward-guard regression test
  added at `trading/trading/backtest/scenarios/test/test_scenario_runner_isolation.ml`
  with three sub-tests (round_trips after one perturber, summary after one
  perturber, round_trips across two perturber cycles). Test PASSES today
  on the GHA-sized panel-golden-2019-full + tiered-loader-parity pair —
  the property holds on small data; the test catches future regressions
  that break isolation badly enough to flip even small runs. Verify:
  `dune runtest trading/backtest/scenarios/test/`.

- **goldens-broad long-only baselines pinned** (2026-04-29,
  `feat/goldens-broad-long-only-baselines`). All four `goldens-broad/*.sexp`
  cells (`bull-crash-2015-2020`, `covid-recovery-2020-2024`,
  `six-year-2018-2023`, `decade-2014-2023`) now have `(enable_short_side
  false)` in `config_overrides` (mirrors the sp500 mitigation in #682) and
  tightened `expected` ranges replacing the prior BASELINE_PENDING wide
  bounds. Per-cell metrics (run-1):
  | Cell | Return | Trades | WinRate | MaxDD | RSS | Wall |
  |---|---:|---:|---:|---:|---:|---:|
  | bull-crash | +148.77 % | 91 | 39.56 % | 62.91 % | 1,650 MB | 2:33 |
  | covid | +15.12 % | 149 | 20.81 % | 75.30 % | 1,693 MB | 2:50 |
  | six-year | +35.34 % | 167 | 37.13 % | 74.86 % | 1,722 MB | 3:00 |
  | decade | +1582.85 % | 145 | 40.69 % | 94.31 % | 1,956 MB | 4:31 |
  Validation rerun: 4/4 PASS. **Determinism finding**: 3/4 cells are
  bit-identical across reruns; **decade-2014-2023 is non-deterministic**
  (run-1: 145 trades / +1582.85 % return; run-2: 135 trades / +1627.09 %
  return — same Sharpe ~0.96, MaxDD ~94 %). Decade ranges are widened to
  encompass both observed runs; source of variance (likely Hashtbl
  iteration order on the longer 10y horizon) is a follow-up. Files:
  `trading/test_data/backtest_scenarios/goldens-broad/{bull-crash-2015-2020,covid-recovery-2020-2024,six-year-2018-2023,decade-2014-2023}.sexp`,
  `dev/notes/goldens-broad-long-only-baselines-2026-04-29.md`. Disclaimer:
  these are LONG-ONLY baselines — when short-side gaps G1-G4 close
  (`dev/notes/short-side-gaps-2026-04-29.md`), the
  `enable_short_side false` override should be reverted and ranges
  re-pinned against shorts-on numbers (same playbook as the sp500 cell).

- **Split-day broker-model fix lands; sp500 phantom MaxDD bug resolved
  on the simulator side** (2026-04-29, PR-4 of split-day redesign).
  PR #658 (Split_detector), PR #662 (Split_event), PR #664 (Simulator
  wire-in), and the PR-4 verification PR collectively close the open
  PR #641 trail. The 97.69% phantom MaxDD documented for
  `goldens-sp500/sp500-2019-2023` in
  `dev/notes/goldens-performance-baselines-2026-04-28.md` and
  `dev/notes/sp500-2019-2023-baseline-canonical-2026-04-28.md` is
  caused by the AAPL 2020-08-31 4:1 phantom drop (raw close
  $499.23 → $129.04 with no ledger adjustment, MtM crashes 75%); the
  broker model multiplies quantity by 4 / divides cost-basis-per-share
  by 4 on the split day, preserving total cost basis and eliminating
  the phantom drop. Verification: `test_split_day_mtm.ml` 3/3 PASS,
  smoke parity goldens (`panel-golden-2019-full`,
  `tiered-loader-parity`) bit-identical to pre-#641 main.
  **Local sp500 baseline rerun is deferred** because GHA's 22-symbol
  fixture cannot satisfy the 491-symbol sp500 universe (same
  data-availability blocker that scoped tier-4 release-gate to
  local). Expected post-fix metrics on the canonical baseline:
  trades ≈ 134, return ≈ +71%, win rate ≈ 38%, MaxDD ~5% (down from
  97.69%). When a maintainer captures these, two follow-ups:
  (a) supersede `dev/notes/sp500-2019-2023-baseline-canonical-2026-04-28.md`
  with a 2026-04-29-or-later note, (b) re-pin
  `goldens-sp500/sp500-2019-2023.sexp` `expected` ranges against the
  corrected MaxDD. Plan: `dev/plans/split-day-ohlc-redesign-2026-04-28.md`.
  Verification record: `dev/notes/split-day-broker-model-verification-2026-04-29.md`.

- **Tier-1 smoke universe_path resolution + flip continue-on-error: false**
  (2026-04-28, PR #634). Fix for next-step #4.
  Root cause: `scenario_runner._fixtures_root` did
  `Data_path.default_data_dir() |> Fpath.parent ^ "trading/test_data/..."`
  which assumed `TRADING_DATA_DIR` pointed at the legacy `data/` location
  at the repo root. The perf workflows set
  `TRADING_DATA_DIR=$WS/trading/test_data`, so `Fpath.parent` walked
  one level too high and `^ "trading/..."` produced a
  doubled-segment path
  `.../trading/trading/test_data/backtest_scenarios`. Net: every
  tier-1 run since #616 crashed 4/4 on the universe lookup, masked
  by `continue-on-error: true`.
  Files:
  - `trading/trading/backtest/scenarios/fixtures_root.{ml,mli}` — new
    `Fixtures_root.resolve ?fixtures_root ()` helper. With
    `?fixtures_root`, returns it verbatim. Without, returns
    `Data_path.default_data_dir() / "backtest_scenarios"` (matches the
    convention `test/test_panel_loader_parity.ml` and the perf
    workflows already use).
  - `trading/trading/backtest/scenarios/scenario_runner.ml` — adds
    `--fixtures-root <path>` CLI flag, threads it through
    `_run_scenario_in_child` so each child resolves the scenario's
    `universe_path` against the original fixtures root rather than
    the per-cell `_stage_<name>/` scratch dir.
  - `trading/trading/backtest/scenarios/test/test_fixtures_root.ml` —
    4-test regression suite; pins explicit-override behaviour, env
    fallback, and the no-doubled-`trading/trading` invariant.
  - `dev/scripts/perf_tier{1_smoke,2_nightly,3_weekly}.sh` — pass
    `--fixtures-root "$SCENARIO_ROOT"`.
  - `.github/workflows/perf-tier1.yml` —
    `continue-on-error: false` (tier-1 is the per-PR gate; tier-2/3
    stay `true` while their warm-up budgets accumulate).
  - `trading/devtools/checks/dune` — set
    `PERF_CATALOG_CHECK_STRICT=1` on the dune rule so missing tier
    tags fail the build (was annotate-only).
  Verify:
  ```
  TRADING_DATA_DIR=$(pwd)/trading/test_data \
    dev/scripts/perf_tier1_smoke.sh
  ```
  expected: 4/4 PASS. Also run
  `dune runtest trading/backtest/scenarios/` (4 + 7 + 10 tests, all
  green). Plan: `dev/plans/perf-tier1-universe-path-2026-04-28.md`.
  Follow-up: `_repo_root()`/`_make_output_root()` in
  `scenario_runner.ml` still uses the old `Fpath.parent` heuristic
  (writes artefacts to `<ws>/trading/dev/backtest/scenarios-...`
  instead of `<ws>/dev/backtest/...`); the path resolves and the dir
  is created, just lands one level too deep. Not load-bearing —
  separate clean-up.

- **Step 5 — tier-4 release-gate workflow at N=1000** (2026-04-28, PR pending).
  Mirrors the tier-1/2/3 pattern but is **manual-only**
  (local-only). Adds
  `dev/scripts/perf_tier4_release_gate.sh` (POSIX-sh runner that
  auto-discovers `;; perf-tier: 4` scenarios via grep, runs each via
  `scenario_runner.exe --parallel 1` with `timeout 28800` = 8 h,
  captures wall + peak RSS, writes `summary.txt`). The GHA workflow
  (`perf-release-gate.yml`) added on this branch was removed
  2026-04-28 because GHA cannot supply `Full_sector_map` data — see
  `dev/notes/tier4-release-gate-checklist-2026-04-28.md`. Four tier-4
  cells covered, all under
  `goldens-broad/`: `bull-crash-2015-2020` (~6y), `covid-recovery-2020-2024`
  (~5y), `decade-2014-2023` (~10y, NEW canonical decade-long cell),
  `six-year-2018-2023` (6y). All four bake
  `(config_overrides ((universe_cap 1000)))` so each cell is
  self-contained at N=1000 (the largest size that fits the 8 GB
  ubuntu-latest ceiling at decade-length per β=3.94 MB/symbol). Expected
  ranges intentionally wide (BASELINE_PENDING) — first manual
  dispatch produces the canonical baseline; tighten ranges via
  follow-up PR. **N≥5000 release-gate stays P1** awaiting
  daily-snapshot streaming
  (`dev/plans/daily-snapshot-streaming-2026-04-27.md`). First run is
  **not yet scheduled**; operator triggers when ready to cut a
  release. Verify locally:
  `dev/scripts/perf_tier4_release_gate.sh` inside the devcontainer
  (or with `TRADING_IN_CONTAINER=1`).
  Files: `dev/scripts/perf_tier4_release_gate.sh`,
  `trading/test_data/backtest_scenarios/goldens-broad/{bull-crash-2015-2020,covid-recovery-2020-2024,decade-2014-2023,six-year-2018-2023}.sexp`.

- **Step 4 — tier-3 weekly perf workflow** (2026-04-27, PR pending).
  Mirrors the tier-1/tier-2 pattern. Adds
  `dev/scripts/perf_tier3_weekly.sh` (POSIX-sh runner that
  auto-discovers `;; perf-tier: 3` scenarios via grep, runs each via
  `scenario_runner.exe --parallel 1` with `timeout 7200` = 2 h,
  captures wall + peak RSS, writes `summary.txt`) and
  `.github/workflows/perf-weekly.yml` (cron `0 7 * * 1` = 00:00 PT
  Monday PDT / 23:00 PT Sunday PST; 2 h after perf-nightly's 05:00
  UTC and 17 min before the orchestrator's 07:17 UTC; same
  `trading-ci:latest` container, same `_build` cache, same
  `continue-on-error: true` posture as tier-1/tier-2; publishes
  summary to `$GITHUB_STEP_SUMMARY`; `timeout-minutes: 300` job
  ceiling). Two tier-3 cells covered:
  `perf-sweep/{bull-1y, bull-3y}`. Verify locally:
  `dev/scripts/perf_tier3_weekly.sh` inside the devcontainer (or
  with `TRADING_IN_CONTAINER=1`); the workflow itself is exercised
  on its first scheduled run (next Monday 07:00 UTC) or via manual
  `workflow_dispatch`.

- **Step 3 — tier-2 nightly perf workflow** (2026-04-27, PR #622 merged).
  Mirrors the tier-1 pattern. Adds
  `dev/scripts/perf_tier2_nightly.sh` (POSIX-sh runner that
  auto-discovers `;; perf-tier: 2` scenarios via grep, runs each via
  `scenario_runner.exe --parallel 1` with `timeout 1800`, captures
  wall + peak RSS, writes `summary.txt`) and
  `.github/workflows/perf-nightly.yml` (cron `0 5 * * *` = 22:00 PT
  PDT / 21:00 PT PST, well clear of the orchestrator's 07:17/12:17
  UTC slots; same `trading-ci:latest` container, same `_build` cache,
  same `continue-on-error: true` posture as tier-1; publishes summary
  to `$GITHUB_STEP_SUMMARY`). Six tier-2 cells covered:
  `goldens-small/{bull-crash-2015-2020, covid-recovery-2020-2024,
  six-year-2018-2023}` and `smoke/{bull-2019h2, crash-2020h1,
  recovery-2023}`. Verify locally: `dev/scripts/perf_tier2_nightly.sh`
  inside the devcontainer (or with `TRADING_IN_CONTAINER=1`); the
  workflow itself is exercised on its first scheduled run / manual
  `workflow_dispatch`.

- **Engine-pooling PR-4 — Buffer_pool for transient workspaces** (2026-04-27, PR #632 open).
  New `trading/trading/engine/lib/buffer_pool.{ml,mli}` — Stack-backed
  pool of `float array` workspace buffers; pre-seeds one buffer at
  construction so the first `acquire` is allocation-free; bounded by
  `max_size` (drops on overflow). `Price_path._sample_student_t` now
  acquires a 1-slot float-array accumulator on entry and releases it
  on exit, removing the `let acc = ref 0.0` per-call heap allocation
  (~85K sampled events / ~850M real allocations on `bull-crash-292x6y`
  per the post-PR-A memtrace). `Engine._scratch_for_symbol` now uses
  `Hashtbl.find_or_add ~default`, removing the per-call `Some`
  allocation that dominated `update_market.(fun)` (~316 KB / 19,800
  sampled events). Bit-equality preserved: chi-squared accumulation
  order is identical (same left-fold for-loop, just `acc.(0)` instead
  of `!acc`); `test_golden_bit_equality` and `test_panel_loader_parity`
  pass unchanged. Verify:
  `dune runtest trading/engine/test` (96 tests) +
  `TRADING_DATA_DIR=$(pwd)/test_data dune exec
  trading/backtest/test/test_panel_loader_parity.exe`. Files:
  `trading/trading/engine/lib/buffer_pool.{ml,mli}`,
  `trading/trading/engine/lib/{price_path,engine,dune}.ml`,
  `trading/trading/engine/test/test_buffer_pool.ml`.

- **Engine-pooling PR-1 — Gc.stat instrumentation** (2026-04-27, PR #618).
  Per-step `Gc.stat` snapshots in `Panel_runner.run`, gated by the
  existing `?gc_trace`. Phase labels `step_<YYYY-MM-DD>_before` /
  `step_<YYYY-MM-DD>_after` interleave between `macro_done` and
  `fill_done` so a CSV consumer can pair them by date and recover
  per-day deltas. When `gc_trace = None` the loop is functionally
  identical to `Simulator.run` modulo one `Option.is_some` check per
  step. Smoke check on a 6-month tier-1 run produces 476 per-step
  rows; cumulative `minor_words` climbs 2.8M→93M, ready to be
  diffed step-by-step. Verify:
  `_build/default/trading/backtest/bin/backtest_runner.exe \
   2019-06-03 2019-06-30 --gc-trace /tmp/gc_smoke.csv` then
  `grep -c step_ /tmp/gc_smoke.csv` (expect ~476). Files:
  `trading/trading/backtest/lib/panel_runner.{ml,mli}`,
  `trading/trading/backtest/lib/runner.{ml,mli}`,
  `trading/trading/backtest/test/test_panel_runner_gc_trace.ml`.

- **Step 1 — scenario catalog headers** (2026-04-26).
  Added `;; perf-tier: <1|2|3|4>` + `;; perf-tier-rationale: ...` to
  every scenario sexp under `goldens-small/`, `goldens-broad/`,
  `perf-sweep/`, `smoke/`. Tier breakdown:
  - **Tier 1** (per-PR, ≤2 min): 4 scenarios —
    `smoke/{tiered-loader-parity, panel-golden-2019-full}`,
    `perf-sweep/{bull-3m, bull-6m}`.
  - **Tier 2** (nightly, ≤30 min): 6 scenarios —
    `goldens-small/*`, `smoke/{bull-2019h2, crash-2020h1, recovery-2023}`.
  - **Tier 3** (weekly, ≤2 h): 2 scenarios —
    `perf-sweep/{bull-1y, bull-3y}`.
  - **Tier 4** (release-gate, ≤8 h): 3 scenarios —
    `goldens-broad/*` (currently SKIPPED placeholders).

  Verify: `sh trading/devtools/checks/perf_catalog_check.sh` -> "OK: 15
  scenarios all carry tier tags."
- **Step 2 — tier-1 smoke gate** (2026-04-26).
  - `trading/devtools/checks/perf_catalog_check.sh` + dune wiring —
    grep-based integrity check; annotate-only by default, strict via
    `PERF_CATALOG_CHECK_STRICT=1`.
  - `dev/scripts/perf_tier1_smoke.sh` — POSIX-sh runner that
    auto-discovers `;; perf-tier: 1` scenarios, runs each via
    `scenario_runner.exe` with `timeout 120`, captures wall-time + peak
    RSS, prints a summary table.
  - `.github/workflows/perf-tier1.yml` — **drafted but held out of this
    PR** because the agent's PAT lacks the `workflow` scope required to
    push GHA workflow files. The script + check + headers all land in
    this PR; a maintainer follow-up needs to add the workflow file
    using a workflow-scoped token. Draft YAML is in the PR body /
    branch history for paste-and-commit. Sibling workflow design
    (`pull_request` + `push: main` triggers, non-blocking
    (`continue-on-error: true`), publishes summary to
    `$GITHUB_STEP_SUMMARY`).
  - Verify locally: `dev/scripts/perf_tier1_smoke.sh` (run inside the
    devcontainer or with `TRADING_IN_CONTAINER=1`).

## Next steps

1. (DONE) Tier 2 (nightly) — `perf-nightly.yml` +
   `perf_tier2_nightly.sh` merged in PR #622 on 2026-04-27. Six
   tier-2 cells, 30 min budget per cell, cron `0 5 * * *` (22:00 PT).
2. (DONE on this PR) Tier 3 (weekly) — `perf-weekly.yml` +
   `perf_tier3_weekly.sh`, two tier-3 cells
   (`perf-sweep/{bull-1y, bull-3y}`), 2 h budget per cell, cron
   `0 7 * * 1` (Monday 00:00 PT). The tier-3 cell count is below
   the original plan's 4 because tagged tier-3 scenarios are
   currently 2; expanding the catalog (e.g., bull-crash 1000×6y,
   covid-recovery 300×4y, six-year 300×6y per the plan's Tier 3
   table) is a follow-up scenario-authoring task, not gating on
   the workflow itself.
3. **(DONE on `feat/backtest-perf-tier4-release-gate`; GHA removed
   2026-04-28)** Tier 4 (release-gate) at **N=1000 × decade-long** —
   `dev/scripts/perf_tier4_release_gate.sh`, four tier-4 cells under
   `goldens-broad/` (`bull-crash-2015-2020`, `covid-recovery-2020-2024`,
   `decade-2014-2023` (NEW), `six-year-2018-2023`), 8 h budget per
   cell, **local-only** (release-gate runs at release-cut time, not on
   a recurring schedule). The four sexps now bake
   `(config_overrides ((universe_cap 1000)))` so each
   cell is self-contained — no CLI override needed. Per
   `dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md` (β=3.94
   MB/symbol), N=1000×10y projects to ~5.7 GB peak RSS, fits the 8 GB
   ubuntu-latest ceiling. **N≥5000 release-gate stays P1 awaiting
   daily-snapshot streaming** (`dev/plans/daily-snapshot-streaming-2026-04-27.md`):
   at β=3.94, N=5000×10y projects to ~28 GB, far beyond the runner
   ceiling. Expected ranges are intentionally wide for the four cells
   (BASELINE_PENDING) — first manual dispatch produces the canonical
   baseline; tighten ranges via follow-up PR after that run lands.
4. **(DONE on `fix/perf-tier1-universe-path`)** Tier-1 smoke
   universe_path resolution + flip the gate. Added
   `Scenario_lib.Fixtures_root.resolve` plus `--fixtures-root` CLI
   flag on `scenario_runner.exe` that the three tier scripts pass
   explicitly. Flipped `.github/workflows/perf-tier1.yml`
   `continue-on-error: false` (tier-1 is the per-PR gate; tier-2/3
   stay VISIBILITY-first). Set `PERF_CATALOG_CHECK_STRICT=1` in
   `trading/devtools/checks/dune`. Verified: 4/4 PASS post-fix. Plan:
   `dev/plans/perf-tier1-universe-path-2026-04-28.md`.
5. After ~10 PR cycles of *real* tier-1 perf data: pin per-cell
   budgets. Same flip applies to `perf-nightly.yml` once tier-2
   budgets are pinned (~10 weeks of nightly data) and to
   `perf-weekly.yml` once tier-3 budgets are pinned (~10 weekly
   cycles).
6. (DONE on `feat/backtest-perf-release-report`) **`release_perf_report`
   OCaml exe.** New library
   `trading/trading/backtest/release_report/` (`release_report.{ml,mli}`,
   `dune`) + binary `trading/trading/backtest/bin/release_perf_report.ml`
   + 11 tests in `trading/trading/backtest/test/test_release_perf_report.ml`.
   Reads two release `dev/backtest/scenarios-<ts>/` directories (each
   subdirectory = one scenario with `actual.sexp`, `summary.sexp`, and
   optional `peak_rss_kb.txt` / `wall_seconds.txt` sidecars from the
   perf-tier runners), pairs scenarios by name, and emits a markdown
   report with three matrices: trading metrics (return %, Sharpe, win
   rate, max DD, trades, avg holding) side-by-side; peak-RSS (current
   vs prior, ∆%); wall-time (current vs prior, ∆%). PR-level regression
   flags fire when ∆% exceeds defaults from
   `dev/plans/perf-scenario-catalog-2026-04-25.md` (RSS > +10%, wall
   > +25%); both thresholds are CLI-overridable via
   `--threshold-rss-pct N` / `--threshold-wall-pct M`. Verify:
   `dune build trading/backtest/release_report
   trading/backtest/bin/release_perf_report.exe` then run
   `_build/default/trading/backtest/bin/release_perf_report.exe
   --current <dir> --prior <dir>`; tests via
   `dune test trading/backtest/test/test_release_perf_report.exe`
   (11/11 PASS). Pure OCaml per `.claude/rules/no-python.md`.
7. (DONE on `docs/goldens-performance-baselines`) **Goldens performance
   baselines — small + sp500.** Ran the four non-broad goldens
   (`goldens-small/{bull-crash-2015-2020, covid-recovery-2020-2024,
   six-year-2018-2023}` + `goldens-sp500/sp500-2019-2023`) and
   documented per-cell metrics + buy-and-hold context in
   `dev/notes/goldens-performance-baselines-2026-04-28.md`. Pure
   docs PR. Headline finding: strategy underperforms B&H on 4/4
   windows; closest on bull-crash (−2.2 pp), worst on covid-recovery
   (−49.6 pp). Three of the four cells are now red against their
   pinned `total_trades` ranges — trade-count drift since the
   2026-04-18 pinning is the next thing the trade-audit work
   (`dev/plans/trade-audit-2026-04-28.md`) needs to explain.
   Surfaced an Aug-2020 mark-to-market anomaly on the sp500 cell
   (portfolio briefly $25K during AAPL/Tesla split window) — flagged
   for trade-audit follow-up.

## Follow-up

- **Panel_runner per-fold tmp-dir leak fix (#1393)** — landed via
  `feat/panel-runner-tmp-cleanup`. `Csv_snapshot_builder` now registers
  every `/tmp/panel_runner_csv_snapshot_*` dir in a process-wide
  cleanup ledger; `Stdlib.at_exit` removes any dir still in the ledger
  on exit, and SIGTERM/SIGINT/SIGHUP handlers re-raise as
  `exit 130` so the at_exit chain fires on graceful kill. Adds
  `cleanup`, `register_for_cleanup`, `registered_dirs`,
  `startup_orphan_sweep` to the .mli. Closes the 1895-dir / 53 GB
  orphan accumulation observed 2026-05-31. SIGKILL remains uncoverable
  by design; `startup_orphan_sweep` is the belt-and-suspenders
  mitigation for that residual.

## Ownership

`feat-backtest` agent (sibling of backtest-infra and backtest-scale).
Pure infra work — scenario cataloging, GHA workflows, report
generators.

## Branch

`feat/backtest-perf-<step>` per item above. Active:
`feat/backtest-perf-tier4-release-gate` (Step 5 — tier-4 release-gate
at N=1000) and `feat/backtest-perf-tier3-weekly` (Step 4).

## Blocked on

- **Tier 4 release-gate at N≥5000** stays blocked on daily-snapshot
  streaming (`dev/plans/daily-snapshot-streaming-2026-04-27.md`). At
  the post-engine-pool β=3.94 MB/symbol, N=5000×10y projects to ~28 GB
  RSS, far beyond the 8 GB ubuntu-latest ceiling. Tier-4 at N=1000 is
  **unblocked** and shipped on `feat/backtest-perf-tier4-release-gate`.

## Decision items (need human or QC sign-off)

Carried verbatim from `dev/plans/perf-scenario-catalog-2026-04-25.md`:

1. Are the tier costs (per-PR ≤2min, nightly ≤30min, weekly ≤2h,
   release ≤8h) the right budget?
2. Tier 4 pass criteria — what RSS / wall budget defines a passing
   release? Per `dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md`,
   post-engine-pool β=3.94 MB/symbol; tier-4 at N=1000×10y projects
   to ~5.7 GB (fits 8 GB ceiling). N≥5000 release-gate still requires
   daily-snapshot streaming
   (`dev/plans/daily-snapshot-streaming-2026-04-27.md`). Initial
   tier-4 ranges are intentionally wide (BASELINE_PENDING); first
   manual dispatch produces the canonical baseline.
3. Should `perf_catalog_check` fail builds or annotate-only?
   Initial: annotate-only.
4. Tracking format: CSV in repo (auditable, grows) vs external store.
   Initial: CSV in repo.

## References

- Plan: `dev/plans/perf-scenario-catalog-2026-04-25.md`
- Existing perf harness: `dev/scripts/run_perf_hypothesis.sh` (#537),
  `dev/scripts/run_perf_sweep.sh` (#547)
- Sibling track: `dev/status/data-panels.md` — tier 4 blocker
  (supersedes the older `incremental-indicators` track)
- Predecessor: `dev/status/backtest-infra.md` (MERGED) for the
  experiments/analysis side this builds on
