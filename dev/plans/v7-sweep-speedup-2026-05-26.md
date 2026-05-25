# v7 sweep speedup — plan 2026-05-26

Profiling baseline: v7 sweep at 9 BO iters / ~12h wall / 548 backtests
(2 variants × 28 folds × 9 iters + warmup). Snapshot of 3015 symbols
rebuilt from CSV on every fold × variant (`csv_snapshot_builder.ml:85`
called 56× per iter). Container observed at 10 CPU / 7 GB RAM ceiling.
`ocamlopt -config | grep flambda` returns `false`. Each fork-pool worker
peaks ~1.5-2 GB during snapshot rebuild + warmup.

This plan scopes the three config-only or small-code wins that are
orchestrator-eligible for dispatch before v8 launches. Snapshot reuse
across folds (1.5-2×) is M-scale (~200 LOC, coordinated changes to
`Panel_runner` + `Csv_snapshot_builder`) and is intentionally left to a
follow-up plan.

---

## Win #2 — `--parallel 6` + container RAM 7→12 GB

### What changes

- `dev/scripts/launch_sweep.sh`: change the `PARALLEL="4"` default to
  `PARALLEL="6"`. (~1 line)
- `.devcontainer/setup.sh` or `.devcontainer/devcontainer.json`: raise
  the container memory cap from 7 GB to 12 GB (exact location depends on
  how the devcontainer is configured — likely a `--memory 12g` flag in
  the `docker run` incantation or a `hostRequirements.memory` field).
  (~1-5 lines)

Total: ~10-20 LOC.

### Why

M2 Pro has 6 performance cores. Running 6 parallel workers fully uses the
perf-core pool. At `--parallel 4`, two perf cores idle between folds.
Expected speedup: 1.3-1.4× on wall time. Container must be raised to
12 GB to handle 6 workers: each worker peaks at ~1.5-2 GB during snapshot
rebuild + warmup (post-v6 measurement), so 6 × 2 GB = 12 GB ceiling.

### Acceptance

- `dune build` passes (no OCaml changes).
- `launch_sweep.sh --dry-run` prints `--parallel 6` in the preview command.
- Container starts and has ≥ 12 GB memory visible inside:
  `docker exec trading-1-dev bash -c 'free -h | grep Mem'`.
- A short backtest (tier-1 smoke) is not slower: `dev/scripts/perf_tier1_smoke.sh`.

### Dispatch

- Track: `sweep-perf` (new, this plan; see `dev/status/sweep-perf.md`).
- Agent type: `harness-maintainer` (config-only; touches `dev/scripts/`
  and `.devcontainer/`, not `.ml`/`.mli`).

---

## Win #3 — Flambda + `-O3` compiler flags

### What changes

- opam switch: switch the devcontainer from `5.3.0` to `5.3.0+flambda`.
  This requires updating the `Dockerfile` or devcontainer setup script
  to install the `+flambda` variant. (~3-5 lines in `.devcontainer/`).
- `trading/trading/dune-project` (or a top-level `dune-project`): add
  `(env (release (flags (:standard -O3))))` to enable `-O3` optimisation
  in release builds. (~3 lines)

Total: ~10-30 LOC (mostly in `.devcontainer/`).

### Why

`ocamlopt -config | grep flambda` returns `flambda: false` on the current
switch. Flambda cross-module inlining + `-O3` is documented in the OCaml
benchmark literature to give 5-20% speedup on numerically tight code.
The per-bar loops in `simulator.ml:_to_price_bar`, the per-Friday MA
recomputes in `Weekly_ma_cache`, and the stage classifier are exactly
that shape. Expected speedup: 1.10-1.20×. No runtime semantics change —
purely a compiler optimisation.

### Acceptance

- Devcontainer rebuilds cleanly with `5.3.0+flambda`.
- `ocamlopt -config | grep flambda` returns `flambda: true` inside the
  container.
- `dune build` (in release profile) passes.
- `dune runtest` passes (no behaviour change — all parity tests pass).
- Tier-1 smoke still passes: `dev/scripts/perf_tier1_smoke.sh`.

### Dispatch

- Track: `sweep-perf`.
- Agent type: `harness-maintainer` (devcontainer image changes are
  harness-adjacent; no feature `.ml` edits).
- Note: this PR also requires a devcontainer image rebuild and push to
  `ghcr.io/dayfine/trading-devcontainer:latest` so GHA picks it up.
  The dispatch prompt must include this step explicitly or mark it as a
  manual follow-up.

---

## Win #4 — Per-fold universe pruning via `Daily_price.active_through`

### What changes

Two call sites, each requiring ~3-5 lines of filtering + a test:

1. `trading/trading/simulation/lib/simulator.ml:_get_today_bars`
   (lines 175-181): before iterating `t.deps.symbols`, filter to
   symbols where `Daily_price.active_through >= fold_start_date`. The
   `active_through` field is already populated on each price record
   (landed via #1076 + #1094).

2. `trading/trading/weinstein/strategy/lib/weinstein_strategy_screening.ml:_classify_all`
   (lines 258-262): before the Phase-1 stage classification loop, filter
   the symbol set to those active as of the fold's `test_period.start_date`.

Supporting plumbing: thread `fold_start_date` (already available in the
executor context) through to both call sites. May require adding a parameter
to the simulator/screening config. ~50-80 LOC core + ~30-50 LOC tests.

Total: ~80-130 LOC.

### Why

The 1998 fold runs against a universe where ~1500 of 3015 symbols are
pre-IPO or already delisted — Phase-1 stage classification still runs on
all 3015, paying full per-symbol cost for symbols that will never appear
in the results. This is NOT survivor bias: filtering on
`active_through >= fold_start_date` removes symbols that were genuinely
uninvestable at the time. Filtering on `active_today` (the current date)
IS survivor bias — that cut would be wrong.
Expected speedup: 1.10-1.25× on early folds; less on recent folds where
most symbols are active.

### Acceptance

- `dune build` passes.
- `dune runtest` passes — including the existing parity tests
  (`test_panel_loader_parity`, `test_runner_hypothesis_overrides`).
- New test: at least one scenario with a fold starting pre-2000 shows
  fewer symbols processed in Phase 1 (assert via a log/metric, or
  compare result counts on a synthetic fixture).
- Baseline-equivalent: a tier-1 smoke run produces metrics within the
  existing `expected` ranges (`dev/scripts/perf_tier1_smoke.sh`).

### Dispatch

- Track: `sweep-perf`.
- Agent type: `feat-backtest` (touches `.ml`/`.mli` under
  `trading/trading/simulation/` and `trading/trading/weinstein/strategy/`).
- Pre-flight context to inject: current `dune runtest` output for
  `trading/trading/simulation/test/` and
  `trading/trading/backtest/weinstein/test/`; no prior QC review.
