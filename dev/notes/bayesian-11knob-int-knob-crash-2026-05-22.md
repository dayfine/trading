# 11-knob BO sweep — int_of_sexp crash (2026-05-22)

Result note. First production run of the 11-knob multi-parameter Bayesian
sweep (P4 in `dev/plans/tuning-methodology-redesign-2026-05-22.md` §5)
crashed mid-evaluation. This doc captures the failure mode + root cause
+ fix path so a future session can unblock.

## Symptom

`dev/logs/bayesian-prod-11knob-v1-parallel4.log` tail:

```
Uncaught exception:
  (Failure
    "Fork_pool: job index 31 raised: (Of_sexp_error \"int_of_sexp: (Failure int_of_string)\"
   (invalid_sexp 3.8004091733819001))")

Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
Called from Fork_pool._run_pool in file "trading/backtest/fork_pool/lib/fork_pool.ml", line 210, characters 9-36
Called from Walk_forward__Walk_forward_executor._evaluate_all in file "trading/backtest/walk_forward/lib/walk_forward_executor.ml", line 147, characters 16-54
Called from Walk_forward__Walk_forward_executor.execute_spec in file "trading/backtest/walk_forward/lib/walk_forward_executor.ml", line 155, characters 21-75
Called from Tuner_bin__Bayesian_runner_evaluator.build_walk_forward.(fun) in file "trading/backtest/tuner/bin/bayesian_runner_evaluator.ml", line 142, characters 17-52
Called from Tuner_bin__Bayesian_runner_runner._run_loop.loop in file "trading/backtest/tuner/bin/bayesian_runner_runner.ml", line 158, characters 37-58
Called from Tuner_bin__Bayesian_runner_runner.run_and_write in file "trading/backtest/tuner/bin/bayesian_runner_runner.ml", lines 341-342, characters 4-34
```

Iter-1 (first random sample) crashed in walk-forward fork-pool job #31
on `3.8004091733819001`. A continuous float was handed to an
`int_of_sexp` deserializer somewhere on the config-override path.

## Root cause

`trading/trading/backtest/tuner/lib/grid_search.ml` `_binding_to_sexp`
(line 61-67) emits cell bindings as:

```ocaml
let _binding_to_sexp (key, value) =
  let key_eq_value = sprintf "%s=%.17g" key value in
  match Backtest.Config_override.parse_to_sexp key_eq_value with
  | Ok sexp -> sexp
  | ...
```

`%.17g` emits the raw float (e.g. `3.8004091733819001`). For
`screening_config.weights.w_positive_rs` (declared int in the
`screening_config.weights` record), the override sexp atom
`"3.8004091733819001"` reaches the screening_config deserializer and
`int_of_sexp` throws.

The `grid_search.mli:56-65` "integer-valued floats correctly" claim
relies on the BO/grid emitting integer-valued floats (e.g. `40.0`
formats as `40.` and parses as int 40). The 4 int-typed knobs in the
11-knob spec are bounded over wide ranges:

- `stage3_force_exit_config.hysteresis_weeks` `(1.0 5.0)`
- `laggard_rotation_config.hysteresis_weeks`  `(1.0 8.0)`
- `screening_config.weights.w_positive_rs`     `(5.0 40.0)`
- `screening_config.weights.w_strong_volume`   `(5.0 40.0)`

The GP (Gaussian-process) acquisition function samples continuous
floats in the bounded box; it has no notion of int-typed dimensions.
The very first random sample of `w_positive_rs` (or one of the other
int knobs) at `3.80…` triggers the crash. The 4-knob V3 spec doesn't
include any int knobs, so this surface was untested in production until
this run.

The fixture comment in
`trading/test_data/tuner/bayesian-multi-param-2026-05-16.sexp`:

> Track D — Cell E mechanics (int knobs, rounded at evaluator boundary;
> plan §2.5 — grid_search.mli:56-65 already encodes integer-valued
> floats correctly)

is **wrong**. There is no rounding at the evaluator boundary in
`cell_to_overrides`. The "integer-valued floats" claim only applies
when the upstream sampler emits integer-valued floats (true for
`Grid_search.cells_of_spec` when spec values are `[40.0; 41.0; …]`;
false for BO which samples continuous values).

## Fix path

Three options, increasing in invasiveness:

### Option A — Per-knob rounding in `cell_to_overrides` [recommended]

Extend the cell spec to carry an `is_int` flag per knob, and round
in `_binding_to_sexp` when the flag is set. The spec sexp shape would
become:

```sexp
(bounds
  (("knob_name" (lo hi) ?(int)) ...))
```

with `?(int)` being optional. Rounding is `Float.round_nearest` before
the `%.17g` format. ~30 LOC + a unit test.

### Option B — Auto-detect from field name pattern

Maintain a per-config registry of int-typed override fields:

```ocaml
let int_typed_knobs =
  [ "stage3_force_exit_config.hysteresis_weeks";
    "laggard_rotation_config.hysteresis_weeks";
    "screening_config.weights.w_positive_rs";
    "screening_config.weights.w_strong_volume";
    "screening_config.min_score_override";
    "stage3_reentry_cooldown_weeks" ]
```

Round when key matches. Brittle (registry must be hand-maintained); not
recommended.

### Option C — Round in the BO sampler itself

Modify `Tuner.Bayesian_opt` to support discrete dimensions. Bigger change
to the BO library; impacts acquisition optimization (GP can't honor a
discrete constraint as cleanly).

**Recommendation: Option A.** Smallest surface area, opt-in per knob,
easy to test. Add to the next session's P3 unblock plan.

## Pre-existing fixture wrongness

`bayesian-multi-param-2026-05-16.sexp` shipped 2026-05-16 and claims
test coverage that doesn't actually exercise the int-knob path under
the BO sampler. Per the comment "Tested algorithmically, never run in
production" — the algorithmic test must only have exercised the parser
shape, not the full int-roundtrip with non-integer floats. Verify
when fixing.

## Impact on session priorities

P3 (11-knob sweep) is BLOCKED on this fix until Option A or B lands.
Per `dev/notes/next-session-priorities-2026-05-22.md`:

- P0 (V3 promotion E2E) — DONE today, V3 winner promoted in
  `dayfine/trading-parameters` commit `bbd84ce`.
- P1 (sweep doc §6 → Option E) — DONE today (#1244).
- P3 (11-knob) — BLOCKED on this int-knob fix.
- P5 (V8 random-restart) — LAUNCHED today, V3 spec is 4-knob (no int
  knobs), unaffected by this bug. Seed 2027 sweep running in
  background.

## Open follow-ups

1. Land Option A: per-knob int flag + rounding in `_binding_to_sexp`.
2. Fix or remove the misleading fixture comment.
3. Re-launch 11-knob sweep with the fix.
4. Audit other multi-knob fixtures (`bayesian-multi-param-2026-05-16.sexp`,
   any others) for the same int-knob hazard.

## Reference

- Log: `dev/logs/bayesian-prod-11knob-v1-parallel4.log`
- Output dir (partial): `dev/experiments/bayesian-production-sweep-2026-05-18/output-11knob-v1-parallel4/`
- Spec: `dev/experiments/bayesian-production-sweep-2026-05-18/spec_prod_11knob_v1.sexp`
- Source: `trading/trading/backtest/tuner/lib/grid_search.ml:61-67`
- Plan: `dev/plans/tuning-methodology-redesign-2026-05-22.md` §5 P4
