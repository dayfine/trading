# Next-session priorities — 2026-06-06

**Supersedes:** `next-session-priorities-2026-06-03-PM2.md` (its P0 split-fix +
P1 late-dial both shipped — see below). This doc was written during an overnight
autonomous session whose main thread was **landing the snapshot-streaming
infra + proving local large-N**, plus a full repo gardening pass.

## What shipped this session (2026-06-05 → 06)

- **#1454 MERGED** — `build_scenario_snapshots` (scenario→warehouse wrapper).
  A rework agent had stalled 50 min on a dune-lock wait while hiding an
  **un-compiled fix** (hoisted `date_arg` to top level where `optional` — a
  `Command.Param` binding only in scope inside `let%map_open.Command` — was
  unbound). Recovered its work, fixed (`Command.Param.optional`), nesting
  2.72→1.63, admin-merged on CI-green. Lesson recorded in
  `project-snapshot-streaming-status`: a rework agent stuck in a lock-wait may
  be hiding a build failure — verify its `dune build` before trusting "almost
  done."
- **N=3000 LOCAL SNAPSHOT PROOF — the headline result.** Ran covid-2020-2024 ×
  PIT **top-3000-2020** (3015 syms incl index/ETFs), Cell E, snapshot mode, via
  the #1454 wrapper (auto-derived warmup 2019-06-06 + the 15 index/ETF extras —
  end-to-end wrapper validation).
  - **Return 152.75% / Sharpe 0.89 / MaxDD 25.53% / Calmar 0.80 / 231 RT / PF 1.76.**
  - **RSS bounded ~3.0 GB** (vs ~28 GB CSV-mode projection for N=3000×5y) — local
    large-N is viable on memory; the streaming loader does its job.
  - **Perf caveat: SLOW** — 8685 s (~2.4 h) for 5y (~33 s/cycle vs ~2 s/cycle at
    N=1000). Fit for occasional validation, NOT sweeps. Durable fix = Phase-F
    windowed/mmap decode in `Daily_panels` (per-cycle cost O(positions) not
    O(universe)). Also leaks ~1218 `/tmp/snapshot_*.tmp.*` files per run.
  - **Breadth = THE lever, clean same-window A/B confirmation:** top-1000 covid
    (41.3% / 0.46 / 36.1% DD / Calmar 0.20) → top-3000 covid (152.75% / 0.89 /
    25.5% DD / **Calmar 0.80, 4×**). Tripling breadth cut DD and quadrupled
    Calmar at ~flat win-rate. (`project_cell_e_2020_stall_regime` updated.)
- **#1455 (tier4-broad PIT migration)** — migrated the 2 remaining
  `tier4-broad-{1y,10y}` SCALE cells off the `universes/broad.sexp` sentinel to
  PIT `top-3000-{2022,2014}`. Fixture-only; scaffolding cells (never pinned),
  ranges stay wide. Completes the Q2 broad-universe refresh.
- **Full repo gardening:** jj workspaces 30→1, worktree dirs 6→0 (−17 GB),
  local bookmarks 124→2, remote branches 16→2, 597+1218 `/tmp` temps purged,
  host disk free 84→89 GB, stale container dune procs killed, task list empty.

## Next session — P0 → P2

### P0 · Late-Stage-2 dial confirmation grid (the scoped 4-6h block, READY)
The named next step on the **stage-accuracy** track. P1 dial #1446 (the
`late`-driven trailing-stop tightening) landed **default-off** and was never
evaluated. Run the confirmation grid per `.claude/rules/promotion-confirmation.md`:
- `Variant_matrix` axis: `Flag enable_late_stage2_stop_tighten (true)` ×
  `Key late_stage2_stop_buffer_pct (0.0 0.03 0.05 0.08)`. (Axis support
  confirmed in `variant_matrix.mli`; Overlay_validator validates at expand-time.)
- ≥3 period×universe cells, **one deep pre-2009 macro cell** (the load-bearing
  grid rule — a post-2009-only grid certified an artifact before). Seeds:
  `dev/experiments/cell-e-walk-forward`, `p0-barbell-{prod,spy}` deep/bull specs.
- Pareto + Deflated-Sharpe per cell. Question: does any buffer cut the
  37%/17.5% MaxDD without killing the 918%/237% return?
- Write a `dev/experiments/_ledger/` entry. **Promote only a grid-robust value;
  never the single-window winner.** Default stays off if none robust.
- Pure backtest work — no strategy-core risk. Output to `/tmp/sweeps/`, no
  concurrent jj agents (per `feedback_no_parent_backtest_during_jj_agent`).

### P1 · Snapshot-loader Phase-F perf fix (unblocks local sweeps at large-N)
The N=3000 proof shows local large-N works on RSS but is ~16× too slow per
cycle for sweeps. Durable fix: windowed/mmap decode in `Daily_panels` so
per-cycle cost is O(active positions), not O(universe). Also fix the per-run
`/tmp/snapshot_*.tmp.*` leak (~1218 files/run). Until then, N=3000 local is
validation-only. (`project-snapshot-streaming-status`.)

### P2 · Breadth as a first-class lever (follow the confirmation)
Breadth keeps winning (now 4× Calmar at top-3000 vs top-1000, same window).
Consider: pin a top-3000 broad golden as a tracked baseline once the Phase-F
perf fix makes re-runs cheap; revisit position-count / sizing at higher breadth.

## State at handoff
- main GREEN; only open PR is **#1455** (tier4 migration, admin-merging on CI green).
- Repo + container clean (see gardening above). No in-flight agents/sweeps.
- Memory refreshed: `project-snapshot-streaming-status` (N=3000 proof + perf
  caveat), `project_cell_e_2020_stall_regime` (breadth A/B). Run
  `sh dev/scripts/export-memory.sh` after this doc lands.

## Ramp-up reminders
- Print wall-clock time on every pause.
- Strategy-mechanic changes need TDD + the confirmation grid; don't rush.
- Fixture/docs PRs → admin-merge on CI green (no QC); simulation/strategy code →
  full 3-gate. A rework agent stuck in a lock-wait may hide an un-compiled fix.
