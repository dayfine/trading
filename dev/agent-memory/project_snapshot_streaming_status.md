---
name: project-snapshot-streaming-status
description: "The daily-snapshot streaming bar loader (the thing that lets large-N e.g. N=3000 backtests run locally at bounded RSS) is ~90% built: Phases A-D + F done/merged, parity unit-tested, snapshot mode is backtest_runner's default. Remaining: scenario_runner wiring (#1450 done) + build_snapshots composition support (#1451) + end-to-end RSS validation + flip goldens to snapshot mode."
metadata: 
  node_type: memory
  type: project
  originSessionId: aa2adf7e-e475-44dd-8bb7-1dc413997573
---

The local-N=3000 unlock is the **streaming/mmap snapshot bar loader**
(`dev/plans/daily-snapshot-streaming-2026-04-27.md`), NOT a missing optimization.
Confirmed 2026-06-05: the engine-pool work (2026-04-28) cut WALL time but RSS stayed
flat — peak RSS is the loaded-bars working set (`RSS ≈ 67 + 3.94·N + 0.19·N·(T−1)` MB
→ N=3000×5y ≈ 14 GB). This Mac is 16 GB total / Docker gets 7.75 GB, so CSV-mode
N=3000 cannot run locally. The streaming loader (pre-built snapshot dir + LRU cache,
`_snapshot_cache_mb=1024`) bounds RSS regardless of N.

**It is ~90% built (far more than the plan implies):**
- Phase A.1 schema (#786), B offline pipeline `build_snapshots.exe` (#781), C runtime
  `Daily_panels` mmap+LRU (#782) — done + tested.
- Phase D engine/sim integration — done: `panel_runner` selects
  `Bar_data_source.Csv | Snapshot {snapshot_dir; manifest}`; `snapshot_bar_source`
  bridges into the simulator adapter. `backtest_runner.exe` already has
  `--snapshot-mode --snapshot-dir`, and snapshot mode is its **default since Phase F**
  (`snapshot-engine-phase-f-2026-05-03.md`).
- Parity vs CSV is **unit-tested**: `trading/trading/backtest/test/test_snapshot_mode_parity.ml`
  (bit-identical OHLCV reads).
- Empirical (2026-06-05 spike): `build_snapshots` over 1000 syms = 1.5 GB warehouse at
  **94 MB peak RSS** (one symbol at a time). A snapshot-mode backtest carrying the full
  10,510-symbol universe peaked at 3.74 GB (confounded — universe not constrained to the
  snapshot symbols; a CSV run over 10,510 would be ~40 GB / OOM).

**Remaining work (the gaps):**
1. **`scenario_runner --snapshot-dir`** (the goldens entry point didn't expose
   `bar_data_source`) — DONE, **#1450 merged** (factored `Scenario_lib.Bar_source_resolver`,
   mirrors `backtest_runner._resolve_bar_data_source`).
2. **`build_snapshots` composition-universe support** (it only took Pinned shape;
   goldens use composition snapshots) — **#1451** (factored `Universe_loader`,
   reuses `universe_snapshot` extraction). [merge status: in flight 2026-06-05].
3. **End-to-end RSS validation** (clean, universe-constrained): build `top-1000-2020`
   snapshots → run the covid golden via `scenario_runner --snapshot-dir` → confirm
   metric == 41.3% (CSV center) AND peak RSS bounded (~hundreds MB). NOT yet done.
4. **Flip the goldens to snapshot mode** + build/cache the broad snapshot warehouses →
   N=3000 broad runs locally. (GHA path needs committed bars and is the inferior
   stopgap — streaming makes it local + bloat-free.)

## ⚠ CRITICAL FINDING 2026-06-05 — snapshot mode is pathologically SLOW (the real blocker)

End-to-end validation (covid 5y × **constrained** N=1000 universe, top-1000-2020
snapshots built via #1451, run via `scenario_runner --snapshot-dir`): the run is
**CPU-bound (100% CPU, state R, 0 snapshot fds open) and pathologically slow** —
progress.sexp showed **4 of 291 cycles in ~17 min (~250 sec/cycle)** → the full
5y run would take **~20 HOURS**. CSV mode does the identical covid 5y × 1000 in
**~9 min (~2 sec/cycle)**. So the snapshot bar-reader path is **~100× slower per
cycle**, AND peak RSS was only **3.76 GB** (vs ~4.8 GB CSV projection — a mere
~25% reduction, NOT the ~30× / hundreds-of-MB the plan projected).

**So streaming as currently integrated does NOT enable practical local large-N.**
The bottleneck is CPU per-cycle in the snapshot bar-reader path (NOT disk I/O,
NOT the LRU cache size) — likely the strategy's `Bar_reader.of_snapshot_views
~calendar` (1454 days × 1000 symbols) rebuilding/rescanning views per cycle, or
LRU thrashing forcing re-decode every tick. This is the real reason Phase E (the
at-scale validation spike) was never run — it would have caught this. The
integration shipped (A–F) with **parity unit tests but no at-scale perf test**.

**Revised B status:** the loader is built + parity-correct + now fully wired
(#1450 `scenario_runner --snapshot-dir`, #1451 `build_snapshots` composition both
merged), but the runtime path has a **severe per-cycle CPU cost** that makes it
unusable for real goldens. Running N=3000 locally is **BLOCKED on a performance
investigation/optimization of the snapshot bar-reader** (diagnose the O(cost) per
cycle), NOT on RSS or wiring. This is a real perf-engineering task, bigger than
"flip the cells."

Note: the *actual goldens bug* (reproducibility) is already fixed at N=1000 by the
PIT migration ([[project_tier4_goldens_pit_migration]]) which runs fine in CSV
mode (~9 min, fits local). Streaming was the path to N=3000; that path needs the
perf fix first.

## ✅ RESOLVED 2026-06-05 (later that day) — root-caused, fixed, parity-confirmed

Diagnosis (the `diagnose` skill): the ~100× slowdown was **cache thrash from a
whole-file decode of a full-history warehouse**. `build_snapshots.exe` wrote each
symbol's ENTIRE CSV history (AAPL 11,439 rows; GE ~16k) with no date window;
`Daily_panels._load_symbol_file` decodes the **whole** sexp file per symbol on
access; 1000 full-history symbols decoded ≫ the 1 GB LRU cap → re-decode every
symbol every cycle (CPU-bound, 0 disk fds). `Csv_snapshot_builder` (CSV mode)
escapes it by pre-windowing each symbol to `[warmup_start, end_date]`.

**Fix (#1453 merged):** `build_snapshots.exe -start-date/-end-date` windows the
warehouse (mirrors Csv_snapshot_builder). Durable fix is still Phase-F
windowed/mmap decode in `Daily_panels` (so warehouse size doesn't matter).

**End-to-end confirmation (covid 5y × N=1000):** windowed warehouse →
**~2 sec/cycle (~180× faster, ~7 min total vs ~20 h), peak RSS 1.1-1.2 GB**
(bounded near the cache cap, below the ~4.8 GB CSV projection), and **BIT-IDENTICAL
parity** with CSV mode (41.343815730% / 272 trades / Sharpe 0.45915971 / 36.135%
MaxDD — PASS on the golden).

**Two operational gotchas a snapshot warehouse MUST satisfy (both are what
`Csv_snapshot_builder` does automatically; getting either wrong silently changes
results, NOT caught by the bit-read parity unit test):**
1. **Window to the runner's exact `warmup_start`** (covid → 2019-06-06). A wider
   warmup (e.g. 2018-01-01) changed the result to 81.5% (the stage classifier is
   path-dependent on the indicator series start).
2. **Include the index + sector ETFs** (the `all_symbols` set = universe + GSPC.INDX
   + the 11 SPDR XL* + global indices), not just the trading universe — else macro/RS
   columns are degenerate → **0 trades**. (build_snapshots rewrites the manifest per
   run, so all symbols must be in ONE `-universe-path`.)

**So local N=3000 broad is now viable** (windowed top-3000-2020 + index + ETFs ≈
~750 MB, fits cache, runs fast at bounded RSS). Clean follow-up: a wrapper that
builds a warehouse FROM a scenario (auto-deriving warmup_start + all_symbols) so the
two gotchas can't be tripped. Three infra PRs landed this session: #1450
(`scenario_runner --snapshot-dir`), #1451 (`build_snapshots` composition universes),
#1453 (`build_snapshots` date windowing).

## LANDED (2026-06-06 ~00:21 PDT)
- **#1454 MERGED** (sha 1ca552b3) `build_scenario_snapshots` (scenario→warehouse wrapper; exposes `Runner.warmup_days_for`/`all_snapshot_symbols`/`primary_index_symbol`, factors `Build_runner`). The rework agent's nesting fix had a **compile bug** (hoisted `date_arg` to top level where `optional` — a `Command.Param` binding only in scope inside `let%map_open.Command` — was unbound; that's why it appeared to "run" 50 min: never got past `dune build`). Fixed by qualifying `Command.Param.optional`; nesting 2.72→1.63; admin-merged on CI-green. Lesson: a rework agent stuck in a lock-wait may be hiding an un-compiled fix — verify its build before trusting "almost done."

## ✅ N=3000 LOCAL PROOF COMPLETE (2026-06-06)
Ran covid-2020-2024 × **PIT top-3000-2020** (3015 syms incl index/ETFs), Cell E, snapshot
mode, built via the #1454 wrapper (auto-derived warmup 2019-06-06 + the 15 index/ETF extras
— validating the wrapper end-to-end). **Result: total_return 152.75% / Sharpe 0.89 / MaxDD
25.53% / Calmar 0.80 / 231 round-trips / win 34.6% / PF 1.76.**
- **RSS proof HOLDS: peak ~3.0 GB** (worker VmHWM 3,104,664 kB) vs the CSV-mode projection
  ~28 GB for N=3000×5y (`67+3.94·N+0.19·N·(T−1)`). Fits the 7.75 GB container — **local
  large-N is viable on memory**. This was the whole point of streaming.
- **PERF CAVEAT: it's SLOW.** Main 5y run = **8685 s (~2.4 h)**, ~33 s/cycle over 261 Fridays
  — vs ~2 s/cycle at N=1000. Per-cycle cost scales worse-than-linearly in N (the snapshot
  bar reader rebuilds views over all 3015 syms each cycle). So N=3000 local is fit for
  **occasional validation, NOT sweeps**. The durable fix remains Phase-F windowed/mmap decode
  in `Daily_panels` (so per-cycle cost is O(active positions), not O(universe)).
- **GOTCHA: disable the all_eligible diagnostic for big-N proof runs.** It runs a SECOND
  expensive pass (scanning 261 Fridays × 3001 syms) AFTER the main backtest — added ~hours.
  The main `summary.sexp` is written before it, so kill the runner once that lands.

## IN-FLIGHT (overnight remaining)
- **top-3000 warehouse** pre-built at container `/tmp/snap3k` (582 MB, 3000 windowed `.snap`, [2019-06-06,2024-12-31]) but **manifest is universe-only (missing index/ETFs)**. To finish the N=3000 proof: easiest is to use the merged **wrapper** on a top-3000 scenario (it auto-adds index+ETFs + warmup window). Manual fallback: list `/tmp/snap3k/*.snap` filenames + the 15 extras (GSPC.INDX, GDAXI/N225.INDX, ISF.LSE, 11 SPDR XL*) → one Pinned sexp → rebuild (build_snapshots rewrites manifest per run) → run a top-3000-2020 covid-window scenario via `scenario_runner --dir <cell> --fixtures-root test_data/backtest_scenarios --snapshot-dir /tmp/snap3k`. Expect fast + bounded RSS.
- **Overnight plan:** (1) land #1454; (2) N=3000 local snapshot run → report number; (3) migrate the 2 `goldens-broad/tier4-broad-{1y,10y}` cells to PIT (only real Q2 refresh target; perf-sweep/* + capacity cells stay top-N); (4) handoff/priorities doc + `sh dev/scripts/export-memory.sh`. NO strategy/default changes; don't flip goldens to snapshot-default (waits for human).
- **Q1 (GHA deprecate) conclusion:** none — GHA golden/perf runs are *automatic* gates; local big-N is manual/additive. Future upside: committed *warehouses* (smaller than bars) could let GHA run *bigger* universes (add coverage, not deprecate).

Related: [[project_tier4_goldens_pit_migration]].
