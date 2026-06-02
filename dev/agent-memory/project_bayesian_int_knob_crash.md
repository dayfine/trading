---
name: bayesian-int-knob-crash
description: 11-knob BO sweep crashes int_of_sexp because cell_to_overrides emits raw %.17g floats for int-typed knobs. P3 BLOCKED until per-knob round added.
metadata: 
  node_type: memory
  type: project
  originSessionId: 9d6c3146-4c0d-486e-8ab6-7006f38aad9a
---

11-knob multi-param BO sweep (`spec_prod_11knob_v1.sexp`) crashed mid-iter-1 on 2026-05-22 first production run with:

```
(Of_sexp_error "int_of_sexp: (Failure int_of_string)" (invalid_sexp 3.8004091733819001))
```

**Why:** `_binding_to_sexp` (`trading/trading/backtest/tuner/lib/grid_search.ml:61-67`) emits all cell bindings as raw `%.17g` floats. The 4 int-typed knobs in the 11-knob spec (`stage3_force_exit_config.hysteresis_weeks`, `laggard_rotation_config.hysteresis_weeks`, `screening_config.weights.w_positive_rs`, `screening_config.weights.w_strong_volume`) receive continuous BO samples (e.g. `3.80…`) that `int_of_sexp` can't parse downstream.

**Hidden until 2026-05-22:** V3/V4/V5/V6/V7 specs are all 4-knob, none int-typed. The 11-knob fixture (`trading/test_data/tuner/bayesian-multi-param-2026-05-16.sexp`) shipped with the comment "tested algorithmically, never run in production" — that algorithmic test exercised parser shape, not BO-sample-as-float roundtrip.

**Why:** First production run of the 11-knob sweep was today; P3 of 2026-05-22 priorities depends on it.

**How to apply:**
- P3 (11-knob sweep) is BLOCKED until a per-knob `is_int` flag + round is added to `cell_to_overrides`. Per `dev/notes/bayesian-11knob-int-knob-crash-2026-05-22.md` §"Fix path", **Option A** is recommended (~30 LOC + unit test).
- P5 (V8 random-restart) is UNAFFECTED — V3 spec is 4-knob, none int-typed. Seed 2027 sweep launched 2026-05-22 background.
- Don't launch sweeps with int-typed knobs (`hysteresis_weeks`, `w_positive_rs`, `w_strong_volume`, `min_score_override`, `stage3_reentry_cooldown_weeks`) until the fix lands.
- Audit other multi-knob fixtures for the same hazard when fixing.

Related: [[bayesian-sweep-checkpoint-needed]].
