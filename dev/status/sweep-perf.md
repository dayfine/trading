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

- [ ] **Win #2: `--parallel 6` + container RAM 7→12 GB** — raise
  `launch_sweep.sh` default parallel from 4 to 6; raise devcontainer memory
  cap to 12 GB. Config-only (~20 LOC in `dev/scripts/launch_sweep.sh` +
  `.devcontainer/`). Expected speedup: 1.3-1.4×. Owner:
  orchestrator-eligible. Spec: `dev/plans/v7-sweep-speedup-2026-05-26.md`
  §Win #2. Dispatch as `harness-maintainer`.

- [ ] **Win #3: Enable Flambda + `-O3` compiler flags** — switch devcontainer
  to `ocaml 5.3.0+flambda`; add `(env (release (flags (:standard -O3))))` to
  dune-project. Config-only (~20-30 LOC in `.devcontainer/` + `dune-project`).
  Expected speedup: 1.10-1.20×. Owner: orchestrator-eligible. Spec:
  `dev/plans/v7-sweep-speedup-2026-05-26.md` §Win #3. Dispatch as
  `harness-maintainer`. Note: requires devcontainer image rebuild + push to
  ghcr.io after merge.

- [~] **Win #4: Per-fold universe pruning via `Daily_price.active_through`** —
  filter `all_symbols` in `simulator.ml:_get_today_bars` and `config.universe`
  in `weinstein_strategy_screening.ml:_classify_all` to symbols with
  `active_through >= fold_start_date`. ~80-130 LOC + tests. Expected speedup:
  1.10-1.25× on early folds. Owner: orchestrator-eligible. Spec:
  `dev/plans/v7-sweep-speedup-2026-05-26.md` §Win #4. Dispatch as
  `feat-backtest`. Not survivor bias — filters uninvestable symbols, not
  future-delisted ones. **In progress** on branch
  `feat/sweep-perf-active-through-prune`.

## Completed

(none yet — track opened 2026-05-26)

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
