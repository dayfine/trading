# Status: sweep-perf

## Last updated: 2026-05-26

## Status
IN_PROGRESS

## Interface stable
NO

## Goal

Improve wall-time throughput of the local Bayesian sweep (currently ~73
min/iter at `--parallel 4` on an M2 Pro with 10 vCPU visible, 7 GB RAM).
Three config-only or small-code wins that are safe to ship before v8
launches. See `dev/plans/v7-sweep-speedup-2026-05-26.md` for full specs
and acceptance criteria.

Profiling baseline: v7 sweep at 9 BO iters / ~12h wall / 548 backtests
on the 3015-symbol universe (top-3000 + index + sector ETFs). Bottleneck
is per-fold snapshot rebuild; container at 10 CPU / 7 GB RAM ceiling;
flambda OFF.

## Open work — v7 sweep speedup (2026-05-26)

- [x] **Win #2: `--parallel 6` + container RAM 7→12 GB** — raise
  `launch_sweep.sh` default parallel from 4 to 6; raise devcontainer memory
  cap to 12 GB. Config-only (~20 LOC in `dev/scripts/launch_sweep.sh` +
  `.devcontainer/`). Expected speedup: 1.3-1.4×. Owner:
  orchestrator-eligible. Spec: `dev/plans/v7-sweep-speedup-2026-05-26.md`
  §Win #2. Dispatch as `harness-maintainer`.

- [x] **Win #3: Enable Flambda + `-O3` compiler flags** — switch devcontainer
  to `ocaml 5.3.0+flambda` (via `opam switch create` inside Dockerfile — the
  upstream `ubuntu-22.04-ocaml-5.3-flambda` tag does not exist on Docker Hub);
  add `(env (release (ocamlopt_flags (:standard -O3))))` to
  `trading/dune-workspace`. Config-only (~10 LOC in `.devcontainer/` +
  `dune-workspace`). Expected speedup: 1.10-1.20×. **MERGED as PR #1323** at
  `c53bfa7d` (2026-05-26 run-2; all 3 gates green: CI + qc-structural APPROVED +
  qc-behavioral APPROVED q=5). **Manual follow-up required (maintainer):**
  rebuild `ghcr.io/dayfine/trading-devcontainer:latest` and push so the
  flambda compiler actually fires in CI — until then `-O3` is silently no-op
  per the deferred acceptance criterion documented in the PR body.

- [x] **Win #4: Per-fold universe pruning via `Daily_price.active_through`** —
  filter `all_symbols` in `simulator.ml:_get_today_bars` and `config.universe`
  in `weinstein_strategy_screening.ml:_classify_all` to symbols with
  `active_through >= fold_start_date`. ~80-130 LOC + tests. Expected speedup:
  1.10-1.25× on early folds. **MERGED as PR #1318** at `ebe4a01d` (2026-05-26
  orchestrator run; all 3 gates green: CI + qc-structural APPROVED q=5 +
  qc-behavioral APPROVED q=5). Surface + tests landed (5 new tests covering
  pure-helper pruning, point-in-time vs survivor-bias framing, and integration
  through `Weinstein_strategy_screening`).
  - [x] **Production opt-in wiring** — `Panel_runner.run` now takes
    `?prune_universe_by_active_through:bool` (default `false`). When `true`, the
    fold's `start_date` becomes the point-in-time cutoff threaded onto both
    surfaces: the strategy screener (via `Panel_strategy_builder.build`'s new
    `?fold_start_date` → `Weinstein_strategy.make`'s `?fold_start_date`) and the
    simulator bar-fetch loop (via `Simulator.create_deps`'s `?active_through_for`,
    built from `Daily_panels.active_through_for`). Default `false` is bit-equal —
    no golden re-pin. Verify: `dune build && dune runtest`; new test
    `trading/trading/backtest/test/test_panel_runner_active_through.ml` asserts
    (a) flag→cutoff mapping (`false`→`None`, `true`→`Some start_date`) and
    (b) opt-in ON → strictly fewer symbols reach Phase-1 classification than OFF
    on a fixture whose fold starts after a member's `active_through`.

## Completed

- **Win #3** (PR #1323, `harness/sweep-perf-flambda-o3`): Flambda + `-O3` in
  release profile. Adds `RUN opam switch create 5.3.0+flambda` +
  `ENV OPAMSWITCH=5.3.0+flambda` to `.devcontainer/Dockerfile` (+11), and
  `(env (release (ocamlopt_flags (:standard -O3))))` to `trading/dune-workspace`
  (+4). 3 files / +19 / -4. MERGED at `c53bfa7d` (2026-05-26 run-2). Note:
  `ocamlopt_flags` (not `flags`) is correct — `ocamlc` rejects `-O3`. Manual
  follow-up: rebuild + push `ghcr.io/dayfine/trading-devcontainer:latest`.
- **Win #3 follow-up fix** (PR #1324, `fix/dockerfile-flambda-switch-syntax`):
  corrects the opam switch invocation that #1323 introduced. The original
  `--packages=ocaml-variants.5.3.0+flambda` references a non-existent package
  for the 5.3 series (only `5.3.0+options` and `5.3.0+BER` are published in
  opam-repository for that line; flambda layers via the standalone
  `ocaml-option-flambda` package). Fixed form:
  `--packages=ocaml-variants.5.3.0+options,ocaml-option-flambda`. Caught
  post-merge via the `Build CI image` workflow failure on `c53bfa7d`
  (Build CI image is NOT a required check, so #1323 merged green; but the
  manual ghcr.io rebuild path would have failed until #1324 landed). 1 file /
  +1 / -1. MERGED at `a3dcca7c` (2026-05-26 run-2; all 3 gates green:
  CI + qc-structural APPROVED + qc-behavioral APPROVED q=4).

- **Win #4** (PR #1318, `feat/sweep-perf-active-through-prune`): per-fold
  universe pruning via `Daily_price.active_through`. Adds optional
  `?active_through_for` (simulator) and `?fold_start_date` (Weinstein_strategy)
  parameters; defaults preserve bit-equal baselines. 10 files touched,
  +495 / -137 (incl. 5 new tests). MERGED at `ebe4a01d` (2026-05-26).
- **Win #4 production wiring** (`feat/sweep-perf-active-through-wiring`): wires
  the opt-in path so production sweeps can actually fire the per-fold prune.
  Adds `Panel_runner.run`'s `?prune_universe_by_active_through:bool`
  (default `false`) + the pure helper `Panel_runner.fold_start_date_of_opt_in`;
  threads `?fold_start_date` through `Panel_strategy_builder.build` into
  `Weinstein_strategy.make`; builds the simulator-side `?active_through_for`
  from the run's `Daily_panels.t`. Default `false` → bit-equal baselines (no
  golden re-pin). New test `test_panel_runner_active_through.ml` (3 cases).
  `panel_runner.ml` marked `@large-module` (it was at the 300-line cap; the
  feature plumbing pushed it to 341 — it is the canonical single execution
  pipeline, mirroring sibling `runner.ml`'s existing marker).
- **Win #2** (PR #1317, `harness/sweep-parallel-6`): raised `PARALLEL` default
  from 4 to 6 in `dev/scripts/launch_sweep.sh` (1 line); added `--memory 12g`
  to the `docker run` incantation in `.devcontainer/setup.sh` (1 line). Total:
  3 files touched, 4 insertions, 3 deletions. Verify:
  `grep 'PARALLEL="6"' dev/scripts/launch_sweep.sh` and
  `grep 'memory.*12' .devcontainer/setup.sh`. MERGED at `2c5e5716` (2026-05-26).

## Ownership

`harness-maintainer` (Wins #2 + #3) and `feat-backtest` (Win #4). All three
items are orchestrator-eligible — no "blocked on", "deferred to", or
"maintainer-active" language applies. Dispatch sequencing: ship Wins #2 + #3
first (config-only, zero risk), then Win #4.

## References

- Plan: `dev/plans/v7-sweep-speedup-2026-05-26.md`
- Sweep hygiene rules: `.claude/rules/sweep-hygiene.md`
- Launch wrapper: `dev/scripts/launch_sweep.sh`
- Active sweep: v7 (PID 27298 in container as of 2026-05-26, ~12h wall,
  do not kill — wait for it to finish before launching v8)
