---
name: project_laggard_broad_recheck
description: Laggard-rotation REJECT (of disabling) HOLDS on broad top-3000 PIT; the top-1000 apparent reversal was fat-tail noise. Plus the WF-CV infra that enabled it.
metadata: 
  node_type: memory
  type: project
  originSessionId: 927fd47a-427f-4acc-bd93-388f8cd6b2a9
---

2026-06-09: re-checked the breadth-sensitive `laggard-disable-retracted` verdict
on the broad PIT universe via walk-forward CV (the §4-flagged candidate from the
broad-universe agenda). **Result: laggard rotation robustly HELPS across the
breadth ladder — keep it ON.**

- SP500 (≤506): laggard helps (disabling hurts) — prior REJECT.
- top-1000 (#1493, Inconclusive): disabling looked better on *mean* Sharpe
  (0.368 vs 0.232) BUT gate-failed + fat-tail-driven (one +153pp fold-020).
- **top-3000 (#1495, REJECT):** laggard-ON baseline **DOMINATES** — Sharpe 0.643
  vs 0.489, Calmar 1.382 vs 1.295, MaxDD 14.79 vs 16.51, DSR 0.9988 vs 0.9886;
  laggard-OFF off the Pareto frontier, 6/15 fold wins.

The top-1000 "reversal" was **fat-tail noise**, not breadth-sensitivity (same
dynamic as [[project_broad_universe_790_mtm_inflated]]). The
candidate-supply-sensitivity hypothesis is **refuted**. Lesson reinforced: test a
*surface across folds + DSR*, not a single comparison — the top-1000 single
point would have misled into "laggard flips on broad."

## The WF-CV infra this required (both shipped 2026-06-09)

Broad-universe WF-CV needed two new capabilities — `walk_forward_runner` couldn't
run N≥1000 at all before:
- **#1491 — `--snapshot-dir` on `walk_forward_runner`**: threads a snapshot
  `Bar_data_source` through the executor into each fold's `run_backtest` (CSV
  mode OOMs at N≥1000). Reuses `Scenario_lib.Bar_source_resolver`.
- **#1494 — fork-per-fold for Snapshot∧parallel=1** (`Fork_pool.run_each_forked`):
  at parallel=1 the runner re-decoded all ~3015 symbols PER FOLD
  (misses_per_symbol=1.00 every fold), and the cumulative VM-range churn
  exhausted Rosetta's `VMAllocationTracker` slab at ~fold 13 (exit 133). NOT the
  #1481 heap-OOM — a distinct *many-backtests-in-one-process* limit. parallel=2
  forks per fold but 2 concurrent N=3000 decodes OOM the 7.8GB Docker VM. Fix:
  fork ONE child per fold sequentially → each fold's memory dies with its child,
  resetting the slab. Peak RSS ~5.2GB steady. ~3-5 min/fold (each child
  re-decodes; in-process cache reuse OOMs).

**So N=3000 WF-CV now runs reliably at parallel=1** (~3 min/fold; 15 folds ×2
variants ≈ 90 min). #1481 fixed *single* N=3000 backtests; #1494 fixed the
*WF-many-in-process* path. Recipe: `walk_forward_runner --snapshot-dir
/tmp/snap_top3000_2011 --parallel 1`, base_scenario = a top-3000 Cell-E spec,
axis on the config flag under test.
