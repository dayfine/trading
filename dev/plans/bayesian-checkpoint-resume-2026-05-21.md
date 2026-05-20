# Bayesian sweep checkpoint + resume (2026-05-21)

## Motivation

V2 production sweep (2026-05-20) lost ~5 hours to a power-loss restart
because `bayesian_runner_runner.ml` holds all state in memory and only
writes artefacts after the full ask/tell loop completes. If the process
dies mid-run, every evaluated iteration is lost.

Memory: `project_bayesian_sweep_checkpoint_needed.md`.

## Goal

Allow `bayesian_runner.exe` to **resume from disk** if a prior run on the
same `out_dir` was interrupted, and to **stream artefacts to disk
incrementally** so a kill at any iteration loses at most one
in-flight evaluation.

Non-goals:
- Changing the public `run_and_write` signature.
- Distributed coordination (still single-process).
- Backward compatibility with checkpoint files written by an older binary
  version — schema is fixed at v1, mismatch errors loud.

## Design

### Checkpoint file: `<out_dir>/bo_checkpoint.sexp`

Atomic write via `<path>.tmp` + `Sys.rename`. Sexp shape:

```sexp
((schema_version 1)
 (spec_signature <md5 hex of Sexp.to_string (sexp_of_spec spec)>)
 (rng_seed <int>)
 (iterations
  (((parameters ((k1 v1) (k2 v2)))
    (metric m)
    (per_scenario_metrics (<metric_set> ...))) ...)))
```

`spec_signature` is the digest of the parsed spec serialized — covers
bounds, acquisition, total_budget, initial_random, seed, scenarios,
objective, holdout_folds, sentinel_bounds, length_scales, early_stop.
Any change → resume refused.

### Incremental writes

- After each `observe`:
  1. Write `bo_checkpoint.sexp.tmp` then rename.
  2. Append the iteration's CSV row(s) to `bo_log.csv` (one row per
     scenario, same as today). Open the channel for the loop's lifetime,
     `Out_channel.flush` after each row.
- After the loop terminates:
  3. Write `best.sexp` (full rewrite).
  4. Write `convergence.md` (full rewrite — derived from observations).

The bo_log.csv header is written once on a clean start; on resume we skip
re-writing it (file already has the header + earlier rows).

### Resume protocol

In `run_and_write`:

```
if exists out_dir/bo_checkpoint.sexp:
    cp = load_checkpoint
    require cp.schema_version = 1
    require cp.spec_signature = digest(spec)
    require cp.rng_seed = spec.seed (or default 42)
    bo = BO.create (Bayesian_runner_spec.to_bo_config spec)
    for each saved_iter in cp.iterations:
        replayed_params = _suggest spec bo
        require replayed_params ≈ saved_iter.parameters  (float epsilon 1e-12)
        bo = BO.observe bo { parameters = saved_iter.parameters; metric = saved_iter.metric }
    iter_offset = List.length cp.iterations
    open bo_log.csv in append mode (no header)
else:
    bo = BO.create config
    iter_offset = 0
    open bo_log.csv in truncate mode, write header
```

Loop continues from `iter_offset` for `total_budget - iter_offset` more
iterations, persisting checkpoint after every `observe`.

### RNG state invariant

`BO.suggest_next` mutates the RNG inside `t`. Replaying `_suggest`
deterministically advances the RNG identically to the original run,
**provided the seed and observations match exactly**. We do not persist
`Stdlib.Random.State.t` directly (no public sexp), we re-create it from
the seed.

Validation: replayed `_suggest` must produce the same parameters as
the saved iteration. If float comparison fails by more than 1e-12 in any
key, raise `Failure "resume RNG mismatch"`. This catches subtle
non-determinism (lib upgrades, threading) early.

### Failure modes

| Situation | Behaviour |
|---|---|
| `out_dir` missing | mkdir_p, fresh run |
| `bo_checkpoint.sexp` missing | fresh run (overwrite any partial `bo_log.csv`) |
| Checkpoint schema_version ≠ 1 | `failwith "checkpoint schema mismatch (got N, want 1)"` |
| Spec signature mismatch | `failwith "checkpoint spec mismatch — delete bo_checkpoint.sexp to start over"` |
| Replay parameter mismatch | `failwith "resume RNG mismatch at iter N"` |
| Already at `total_budget` on resume | write final artefacts, return; no extra iterations |
| Checkpoint corrupt (parse error) | propagate sexp parse error with path |

### Cost

- Checkpoint write per iter: ~150-500 bytes per iter × budget=60 → ~30 KB file. Negligible.
- bo_log.csv flush per iter: already at row granularity; just need explicit flush.
- atomic rename: O(1) syscall.

## Files to touch

| File | Change |
|---|---|
| `trading/trading/backtest/tuner/bin/bayesian_runner_runner.ml` | Add `_load_checkpoint`, `_save_checkpoint`, `_replay_observations`. Modify `_run_loop` to accept initial `(bo, rev_obs, rev_metrics, iter_offset)`. Modify `_write_bo_log` to append-vs-truncate based on resume flag. |
| `trading/trading/backtest/tuner/bin/bayesian_runner_runner.mli` | Document new behaviour in `run_and_write` docstring. Add `type checkpoint` if exposed. |
| `trading/trading/backtest/tuner/bin/test/test_bayesian_runner_bin.ml` | Add tests: resume-equivalence (run-N then resume vs run-2N), spec-mismatch-fails, schema-version-fails, missing-checkpoint-fresh-run, already-at-budget-on-resume. |
| (optional) `dev/notes/checkpoint-design-2026-05-21.md` | Skip — this file IS the design doc. |

## Test plan

OUnit2 tests with the existing `_parabola_evaluator` stub:

1. **resume_equivalent_to_full_run** — run total_budget=20 from scratch;
   capture bo_log.csv and best.sexp. Repeat: run budget=10, then call
   `run_and_write` again on the same out_dir with budget=20. Assert the
   final bo_log.csv and best.sexp byte-equal the from-scratch version.

2. **checkpoint_written_per_iter** — run with custom evaluator that
   checks `out_dir/bo_checkpoint.sexp` exists and parses after each call.

3. **spec_mismatch_refuses_resume** — write a checkpoint, then run again
   with different bounds → expect `Failure` with substring "spec
   mismatch".

4. **schema_version_mismatch** — hand-craft a checkpoint with
   `schema_version 99` → expect `Failure`.

5. **resume_at_budget_writes_artefacts** — checkpoint with full budget of
   observations + matching total_budget → expect zero extra evaluator
   calls + best.sexp / convergence.md written.

6. **missing_checkpoint_starts_fresh** — empty out_dir → behaves
   identically to today's code path.

## Estimated size

| File | LOC delta |
|---|---|
| bayesian_runner_runner.ml | +150 |
| bayesian_runner_runner.mli | +30 (docs) |
| test_bayesian_runner_bin.ml | +180 |
| **Total** | **~360 LOC** |

Single session, single PR.

## Out of scope (followups)

- Persisting `Stdlib.Random.State.t` directly to avoid replay-cost on
  resume. Replay of 60 iterations of `_suggest` takes <1s — not worth
  the marshalling complexity.
- Resuming with a *larger* total_budget than the checkpointed run. Today
  the spec check refuses any budget change. If demand emerges, relax
  the signature to bind only "bounds/objective/seed/initial_random" and
  not "total_budget".
- Telemetry: checkpoint-resume should log to stderr — kept minimal in
  PR-1, add structured log in followup if multiple operators use it.
