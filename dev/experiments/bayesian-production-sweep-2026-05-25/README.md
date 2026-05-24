# v7 Bayesian production sweep — 1998-2026 + top-3000 (delisted-aware)

First sweep of the research-driven program v2 (`dev/plans/tuning-research-driven-program-v2-2026-05-25.md`). Tests whether the 11-knob plateau observed in v1-v6 (all on 2010-2026 SP500) was a property of the search space topology or of the narrow universe / window.

## Files in this directory

- `spec_prod_11knob_v7.sexp` — Bayesian-optimizer spec (11 knobs, Composite objective, 60-budget, 15-initial-random, seed 2026, gate_penalty_value 2.0).
- `launch.sh` — invocation wrapper. Sources `dev/scripts/launch_sweep.sh` with v7-specific paths + pre-flight asserts the M4 fixture + baseline aggregate exist.
- `README.md` (this file).

## Prerequisites that must be in place before launching

| Item | Source | Status |
|---|---|---|
| `trading/test_data/walk_forward/cell_e_full_history_28fold_2026_05_25.sexp` | M4 T4.1 PR (in flight) | pending |
| `baseline_aggregate_v7.sexp` (BAH-derived OR Cell E run) | M4 T4.3 + T4.4 | pending |
| Host disk ≥ 50 GB free | host check | manual |
| Docker.raw < 30 GB (OR `LAUNCH_SWEEP_DOCKER_RAW_GB_MAX=45` override) | `launch_sweep.sh` preconditions | manual |

## Launching

```bash
# Default — assumes all prereqs in place
bash dev/experiments/bayesian-production-sweep-2026-05-25/launch.sh

# With Docker.raw override (when recompact not possible)
LAUNCH_SWEEP_DOCKER_RAW_GB_MAX=45 \
  bash dev/experiments/bayesian-production-sweep-2026-05-25/launch.sh

# Overriding name / parallel:
SWEEP_NAME=11knob-v7-test \
PARALLEL=2 \
  bash dev/experiments/bayesian-production-sweep-2026-05-25/launch.sh
```

## Expected wall time

~30h at parallel=4 (per-iter cost ~30 min × 60 budget) for the full sweep + an OOS validation pass on the 4 holdout folds (25-28) at the end. The disk watcher (PR-C, #1296) provides the t>0 safety net; if Docker.raw or host disk crosses thresholds the watcher SIGTERMs the runner so the BO writes a final checkpoint.

## Monitoring

```bash
# Live log
docker exec trading-1-dev tail -f /tmp/sweeps/11knob-v7-1998-2026-top3000.log

# Per-iter score progress
grep -E 'metric ' .sweep-output/11knob-v7-1998-2026-top3000/bo_checkpoint.sexp \
  | awk '{print $2}' | tr -d ')' | sort -g | tail

# Disk watcher log
tail -f .sweep-output/11knob-v7-1998-2026-top3000.watcher.log
```

## Stopping rule

If the first 15 BO iters all score within composite_delta 0.4 ± 0.1, kill the sweep — the 11-knob plateau hypothesis would have replicated on the wider universe + window, which would be evidence that the plateau is from strategy mechanics (M8+ in the plan) rather than search-space topology.

```bash
# Graceful kill (lets the runner write a final checkpoint):
docker exec trading-1-dev pkill -TERM -f 'bayesian_runner.exe.*11knob-v7'
```
