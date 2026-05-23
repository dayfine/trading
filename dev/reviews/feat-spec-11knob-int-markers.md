Reviewed SHA: 4d950c53d0cd07f21a84503885e261b35bba5f6f

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No source changes; fmt gate passed |
| H2 | dune build | PASS | Config-only PR; build succeeded |
| H3 | dune runtest | PASS | All tests passed; no test regressions |
| P1 | Functions ≤ 50 lines (linter) | NA | No source code in this PR |
| P2 | No magic numbers (linter) | NA | No source code in this PR |
| P3 | Config completeness | PASS | All knob bounds parameters complete; int markers present on 4 int-typed knobs per spec design |
| P4 | Public-symbol export hygiene (linter) | NA | No source code in this PR |
| P5 | Internal helpers prefixed per convention | NA | No source code in this PR |
| P6 | Tests conform to test-patterns rules | NA | No new tests in this PR |
| A1 | Core module modifications | NA | No changes to Portfolio/Orders/Position/Strategy/Engine |
| A2 | No new analysis→trading imports | NA | Config file only; no dune dependencies added |
| A3 | No unnecessary existing module modifications | PASS | Only 2 files touched: .gitignore + spec file; aligned with PR scope |

## Verdict

APPROVED

## Additional Notes

**Spec File Validation:**
- Spec syntax conforms to `Bayesian_runner_spec.t` as documented in `.mli`
- 11 knob bindings with 4 marked as `(int)`:
  - `stage3_force_exit_config.hysteresis_weeks (1.0 5.0) (int)`
  - `laggard_rotation_config.hysteresis_weeks (1.0 8.0) (int)`
  - `screening_config.weights.w_positive_rs (5.0 40.0) (int)`
  - `screening_config.weights.w_strong_volume (5.0 40.0) (int)`
- Int markers route through `int_keys` field in `Bayesian_runner_spec.t`, enabling correct float→int rounding in `Grid_search.cell_to_overrides` per plumbing in #1258 + #1261
- Composite objective (SharpeRatio 0.40 + CalmarRatio 0.30 + MaxDrawdown -0.10) matches V3 scoring per design
- Holdout folds (27 28 29 30) match V3 for comparability
- Documented stopping rule + budget arithmetic (60 total, 15 random, ~15h wall at parallel=4)

**Gitignore Entry:**
- Single line added: `dev/experiments/bayesian-production-sweep-*/output-11knob*-parallel*/`
- Necessary to preserve long-running (12-15h) sweep outputs across jj working-copy operations per feedback in memory (jj-new-wipes-long-running-outputs)
- Pattern consistent with existing entries for v3/v5/v7 sweeps

**PR Context:**
- Restores 11-knob Bayesian spec as part of P4 tuning-methodology redesign (#1237)
- Depends on functional `int_keys` plumbing from #1258 + #1261 (now merged)
- No behavioral claims; purely spec + infra; QC structural only (no qc-behavioral required)
