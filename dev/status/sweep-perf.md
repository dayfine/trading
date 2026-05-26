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

- [~] **Win #3: Enable Flambda + `-O3` compiler flags** — switch devcontainer
  to `ocaml 5.3.0+flambda`; add `(env (release (ocamlopt_flags (:standard -O3))))` to
  `trading/dune-workspace`. Config-only (~10 LOC in `.devcontainer/` + `dune-workspace`).
  Expected speedup: 1.10-1.20×. Owner: orchestrator-eligible. Spec:
  `dev/plans/v7-sweep-speedup-2026-05-26.md` §Win #3. Dispatch as
  `harness-maintainer`. Note: requires devcontainer image rebuild + push to
  ghcr.io after merge. **IN FLIGHT**: PR #TBD (`harness/sweep-perf-flambda-o3`).

- [x] **Win #4: Per-fold universe pruning via `Daily_price.active_through`** —
  filter `all_symbols` in `simulator.ml:_get_today_bars` and `config.universe`
  in `weinstein_strategy_screening.ml:_classify_all` to symbols with
  `active_through >= fold_start_date`. ~80-130 LOC + tests. Expected speedup:
  1.10-1.25× on early folds. **MERGED as PR #1318** at `ebe4a01d` (2026-05-26
  orchestrator run; all 3 gates green: CI + qc-structural APPROVED q=5 +
  qc-behavioral APPROVED q=5). Surface + tests landed (5 new tests covering
  pure-helper pruning, point-in-time vs survivor-bias framing, and integration
  through `Weinstein_strategy_screening`); production wiring
  (`panel_runner` / `scenario_runner` opt-in to pass `?active_through_for`)
  is the follow-up.

## Completed

- **Win #4** (PR #1318, `feat/sweep-perf-active-through-prune`): per-fold
  universe pruning via `Daily_price.active_through`. Adds optional
  `?active_through_for` (simulator) and `?fold_start_date` (Weinstein_strategy)
  parameters; defaults preserve bit-equal baselines. 10 files touched,
  +495 / -137 (incl. 5 new tests). MERGED at `ebe4a01d` (2026-05-26).
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
