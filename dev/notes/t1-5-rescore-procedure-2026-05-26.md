# T1.5 — Re-score procedure for v4/v6 checkpoints

Owner: feat-backtest (track: `tuning`).
Plan: `dev/plans/tuning-research-driven-program-v2-2026-05-25.md` §M1 T1.5.

## What the rescorer does

`rescore_checkpoints.exe` (built at
`trading/trading/backtest/tuner/bin/rescore_checkpoints.ml`) consumes:

1. `--input <bo_rescore_input.sexp>` — per-BO-iteration parameters + per-fold
   actuals. Shape documented in the lib
   `Tuner_bin.Bayesian_runner_rescore.bo_rescore_input` (`.mli` docstring).
2. `--baseline <fold_actuals.sexp>` — Cell-E reference per-fold actuals (same
   on-disk shape as the `fold_actuals.sexp` produced by
   `Walk_forward.Walk_forward_runner._write_fold_actuals`).

It re-scores every candidate via
`Tuner_bin.Bayesian_runner_scoring.paired_delta` (merged #1308 / M1 T1.3) —
per-fold `Δ_i = candidate.metric_i - baseline.metric_i`, matched by
`fold_name`, then mean / stdev across folds. The acceptance gate is
`spread = max(mean Δ) - min(mean Δ)` across all candidates;
the default `--min-spread 4.05` is `5 × 0.81` (the v3–v6 flat-surface
historical reference). Output is a markdown report (PASS / FAIL verdict +
per-candidate row + spread anchor).

## Local-only production run (v4 / v6)

The production `bo_checkpoint.sexp` files are NOT accessible to GHA:

```
/Users/difan/Projects/trading-1/.sweep-output/<sweep-name>/bo_checkpoint.sexp
```

**Important caveat:** the production `bo_checkpoint.sexp` shape (see
`Tuner_bin.Bayesian_runner_runner._checkpoint`) does NOT carry per-fold
actuals — only the per-iteration aggregated `metric` + the synthetic
walk-forward `metric_set`. The rescorer's input shape
(`bo_rescore_input.sexp`) is an {i enriched} sibling file that pairs each
iteration with its `fold_actuals` list. An upstream adapter is required to
produce this enriched file from the production sweep output. Two options
for that adapter (out of scope for this PR; track as a follow-up if
operator wants to run the production re-score):

1. **Re-run path:** for each saved iteration's `parameters` in
   `bo_checkpoint.sexp`, re-execute the walk-forward CV (one cell at a time,
   not the full BO loop). Capture each per-iter `fold_actuals.sexp` via
   `Walk_forward.Walk_forward_runner`. Cost: one walk-forward CV per BO
   iteration in the original sweep (~26 folds × N iterations). Bigger; safer.

2. **Inline path:** patch the BO runner to persist `fold_actuals` inline as
   part of each saved iteration (extend `Bayesian_runner_runner._saved_iteration`
   with a `fold_actuals` field). Cost: a follow-up PR to the runner;
   subsequent sweeps automatically write the enriched checkpoint.

### Suggested incantation once the enriched files exist

```bash
# v6 sweep (most recent flat-surface diagnosis)
dune exec --no-build trading/backtest/tuner/bin/rescore_checkpoints.exe -- \
  --input /Users/difan/Projects/trading-1/.sweep-output/v6-11knob/bo_rescore_input.sexp \
  --baseline /Users/difan/Projects/trading-1/.sweep-output/v6-11knob/baseline_fold_actuals.sexp \
  --metric Sharpe \
  --out dev/notes/t1-5-rescore-verdict-v6-2026-05-26.md

# v4 sweep (flat-surface counterpart)
dune exec --no-build trading/backtest/tuner/bin/rescore_checkpoints.exe -- \
  --input /Users/difan/Projects/trading-1/.sweep-output/v4-9knob/bo_rescore_input.sexp \
  --baseline /Users/difan/Projects/trading-1/.sweep-output/v4-9knob/baseline_fold_actuals.sexp \
  --metric Sharpe \
  --out dev/notes/t1-5-rescore-verdict-v4-2026-05-26.md
```

Acceptance per plan §M1 T1.5:
"v4+v6 data on paired-Δ shows >5× wider spread than the original flat -10
plateau" — the rescorer's PASS/FAIL line reports this directly.

## GHA validation (this PR)

In CI the rescorer is exercised end-to-end against synthetic fixtures via
`test_bayesian_runner_rescore.ml` (17 unit tests, including a sexp round-trip
through `load_input` + `load_baseline_fold_actuals`). The fixtures
construct a 3-candidate × 4-fold scenario whose hand-computed mean Δ values
yield a spread of 5.0, exceeding the default 4.05 threshold by a margin —
the PASS path is therefore covered. A second fixture (3-candidate spread =
0.5) covers the FAIL path. The strict-inequality boundary
(spread == min_spread → FAIL) is pinned by a third test.

The plumbing — read → re-score → render → verdict — is therefore validated;
the {b only} GHA gap is the absence of the v4/v6 enriched input files,
which is a data-access limitation (production data is on local disk only),
not a code limitation.

## Where the verdict goes

When the local operator runs the rescorer against real v4/v6 data, the
verdict goes to `dev/notes/t1-5-rescore-verdict-<date>.md`. The verdict
file should record:

- which sweep (`v4-9knob`, `v6-11knob`, etc.) was re-scored;
- the rescorer's `eprintf` summary line (`candidates=N spread=X.XX
  min_spread=4.05 verdict=PASS|FAIL`);
- the full markdown report inline (or as an attachment);
- whether the v4 result and the v6 result both PASS — that's the plan §M1
  T1.5 acceptance requirement.
