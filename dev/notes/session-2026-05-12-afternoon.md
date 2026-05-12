# Afternoon session — 2026-05-12

Followed `next-session-priorities-2026-05-12.md` after #1043 / #1044 / #1045
all merged overnight.

## What landed before this session

`main@origin` is now `096f2608 (#1046)`. All three overnight PRs merged + the
daily orchestrator summary. P1 from the priorities note: DONE.

## What this session did

### P2-prep — cell-level parallelism for grid_search (built)

The 81-cell flagship grid spec at
`dev/experiments/grid-screening-weights-2026-05-12/spec.sexp` ran sequentially
~3h wall, not the ~2h the spec claimed (smoke catalog has grown). Solved by
adding a `--parallel N` flag to `grid_search.exe`.

Implementation:

- `Tuner.Grid_search`: expose `rows_for_cell` + `argmax_by_cell`, add
  `[@@deriving sexp]` to `row` / `cell` / `param_values` / `param_spec` so
  per-cell results can serialise across fork boundaries.
- `Trading_simulation_types.Metric_types`: added
  `metric_set_of_sexp` (inverse of the existing `sexp_of_metric_set`).
- `Tuner_bin.Grid_search_runner.run_and_write`: new required `~parallel:int`.
  - `parallel <= 1`: byte-identical to the previous sequential path.
  - `parallel >= 2`: fork-based worker pool mirroring
    `Scenario_runner._run_scenarios_parallel`. Each child evaluates one cell
    across all scenarios, serialises its `row list` to
    `<out-dir>/.cell-shards/cell-NNNNN.sexp`. Parent concatenates shards in
    cell-enumeration order, then runs argmax + sensitivity + writes the
    standard three artefacts.
- `grid_search.exe`: `--parallel N` CLI flag (default 1).
- Test: `Runner.run_and_write: parallel=2 matches parallel=1 byte-identically`
  pins output parity against the stub evaluator.

Wall-time check on a 2×2 grid × 1 scenario:
- `--parallel 1`: 1m23s (4 sims sequential)
- `--parallel 2`: 0m42s (2× speedup as expected)
- All three artefacts byte-identical between the two runs.

### P2 — 81-cell flagship grid (DONE)

Ran at `--parallel 3` to completion; ~2h 5m wall. Binary at dispatch time
was post-P2-parallelism / pre-P4-rewire, so results reflect current-
production stop behaviour.

**Headline negative result:** all 81 cells produce identical
(Sharpe, num_trades, total_pnl) per scenario — the four screener weights
(rs, volume, breakout, sector) are functionally inert on the cascade-
filtered strategy. M5.5 T-A acceptance criterion FAILS by strict reading
(no strict improvement over baseline) and PASSES by the no-need-to-tune
reading.

Per-scenario constants across all 81 cells:
- bull-2019h2: Sharpe 1.429, 32 trades, +$35,780
- crash-2020h1: Sharpe 0.170, 31 trades, -$89,432
- recovery-2023: Sharpe 1.448, 51 trades, -$36,545
- Mean Sharpe: 1.016

Full write-up: `dev/experiments/grid-screening-weights-2026-05-12/report.md`.

Hypothesis: the cascade gate is grade-driven (threshold on absolute score),
and at ±50% weight scaling no ranking ties flip. Recommended diagnostic:
4-cell sweep with `{0.0, 5.0}` per single dim to confirm vs. reject H1.

### P4 — runner multi-overlay bug investigation

`next-session-priorities-2026-05-12.md` P4 ("Fix runner `_apply_overrides`
deep-merge for multi-overlay") turned out to be a **misdiagnosis**. Full
write-up: `dev/notes/runner-multi-overlay-investigation-2026-05-12.md`.

TL;DR:
- The deep-merge works correctly (new regression test
  `test_two_overlays_same_top_level_field` pins this in
  `test_runner_hypothesis_overrides.ml`).
- Arms B / C of `entry-caps-2026-05-12` produced byte-identical
  `trades.csv` because the override they used
  (`((screening_config ((candidate_params ((initial_stop_pct 0.10))))))`)
  targets a **vestigial knob** — `candidate_params.initial_stop_pct` only
  feeds the advisory `Screener.scored_candidate.suggested_stop`, which the
  G15 refactor severed from the installed-stop path.

### P4-rewire — restore the knob

Per the answer to the priorities-note follow-up
("Re-wire: plumb knob back into entry_audit_helpers"), the knob now drives
the installed stop. New primitive
`Weinstein_stops.widen_initial_to_min_distance` widens an `Initial` stop to
at least the configured distance from entry, recomputing
`reference_level` so the widened state stays self-consistent for
`stop_split_adjust` and the trailing state machine.

Plumbing:
1. `Entry_audit_helpers.initial_stop_and_kind` — new optional
   `?min_stop_distance_pct` (default 0.0 = no widen).
2. `Entry_audit_capture.make_entry_transition` — threads the same parameter
   through.
3. `Weinstein_strategy_screening` — call-site passes
   `config.screening_config.candidate_params.initial_stop_pct`.

Tests: 6 new unit tests on the widening primitive (no-op when pct=0,
no-op when already wide enough, widen long/short, synthetic
`reference_level` round-trips, `Trailing`/`Tightened` pass-through). All 31
stop tests green.

#### Goldens-shift resolution (RESOLVED)

User-chosen path: keep advisory `initial_stop_pct = 0.08` default
(preserves `suggested_stop` / `risk_pct` semantics for snapshot diagnostics
and audit logs), and **add a separate opt-in field**
`installed_stop_min_pct : float [@sexp.default 0.0]` on
`Screener.candidate_params`. Strategy plumbs the new field through
`Entry_audit_capture.make_entry_transition` to
`Stop_widen.widen_initial_to_min_distance`.

Effects:
- Default behaviour bit-equal to pre-rewire — existing goldens unchanged.
- Sweepers opt in via
  `((screening_config ((candidate_params ((installed_stop_min_pct 0.10))))))`.
- Original `initial_stop_pct` (advisory) docstring updated to clarify it's
  advisory-only (per the G15 severance).

Also extracted `widen_initial_to_min_distance` to its own module
`Weinstein_stops.Stop_widen` to keep `weinstein_stops.ml` under the
file-length linter (496 / 500 lines).

## State at end of session

| Item | Status |
|---|---|
| #1043 / #1044 / #1045 | MERGED |
| P2 81-cell grid | DONE — all 81 cells tied; weights inert |
| P2 cell-parallelism (code) | DONE, tested, pre-PR |
| P4 deep-merge bug | RESOLVED — no bug; regression test added |
| P4 re-wire | DONE, tested, pre-PR — opt-in field, default no-op |
| Planning: norgate / horizon / universe | DONE — `dev/notes/plan-norgate-horizon-universe-2026-05-12.md` |
| Planning: short integration | DONE — `dev/notes/plan-short-integration-2026-05-12.md` |
| P5 Q5-cap refinements (E5/E6/E7) | NOT STARTED — now unblocked (P4 default-safe) |
| P3 re-run 5 OOM holding-period cells | NOT STARTED — independent |

## Files touched (pre-PR, currently on local `wip` change)

P2 cell-parallelism:
- `trading/trading/backtest/tuner/lib/grid_search.{ml,mli}`
- `trading/trading/backtest/tuner/bin/{grid_search,grid_search_runner}.{ml,mli}`
- `trading/trading/backtest/tuner/bin/dune` (+ `core_unix`)
- `trading/trading/backtest/tuner/bin/test/test_grid_search_bin.ml`
- `trading/trading/simulation/lib/types/metric_types.{ml,mli}` (added
  `metric_set_of_sexp`)

P4 rewire:
- `trading/trading/weinstein/stops/lib/weinstein_stops.{ml,mli}`
- `trading/trading/weinstein/stops/test/test_weinstein_stops.ml`
- `trading/trading/weinstein/strategy/lib/entry_audit_helpers.ml`
- `trading/trading/weinstein/strategy/lib/entry_audit_capture.{ml,mli}`
- `trading/trading/weinstein/strategy/lib/weinstein_strategy_screening.ml`

Multi-overlay regression test:
- `trading/trading/backtest/test/test_runner_hypothesis_overrides.ml`

Notes:
- `dev/notes/runner-multi-overlay-investigation-2026-05-12.md`
- `dev/notes/session-2026-05-12-afternoon.md` (this file)
- `dev/experiments/grid-screening-weights-2026-05-12/tiny-grid-spec.sexp`
  (verification spec for the parallel runner)

## Next steps

1. Split current wip change into focused PRs:
   - **PR A** — `feat(tuner): cell-level --parallel N for grid_search.exe`
     - Touches: `trading/backtest/tuner/{lib,bin}/`,
       `simulation/lib/types/metric_types.{ml,mli}` (added
       `metric_set_of_sexp`), `.gitignore` (shard dir).
     - Tests: `Runner.run_and_write: parallel=2 matches parallel=1
       byte-identically`.
   - **PR B** — `feat(screener): installed_stop_min_pct opt-in floor on
     placed stop`
     - Touches: `analysis/weinstein/screener/lib/screener.{ml,mli}`,
       `trading/weinstein/stops/lib/{stop_widen.ml,stop_widen.mli,weinstein_stops.{ml,mli}}`,
       `trading/weinstein/strategy/lib/{entry_audit_helpers,entry_audit_capture,weinstein_strategy_screening}.{ml,mli}`,
       `trading/weinstein/stops/test/test_weinstein_stops.ml` (6 new
       widen tests).
     - Default = 0.0 → no-op → goldens unchanged.
   - **PR C** — `test(runner): pin multi-overlay deep-merge parity`
     - Touches: `trading/backtest/test/test_runner_hypothesis_overrides.ml`
       (one new test).
     - Doc-only sister: `dev/notes/runner-multi-overlay-investigation-2026-05-12.md`.
   - **PR D** — `ops(experiments): 81-cell flagship grid results + tiny
     parity spec + planning notes`
     - Touches: `dev/experiments/grid-screening-weights-2026-05-12/{report.md,grid.csv,best.sexp,sensitivity.md,tiny-grid-spec.sexp}`,
       `dev/notes/{session-2026-05-12-afternoon.md,plan-norgate-horizon-universe-2026-05-12.md,plan-short-integration-2026-05-12.md,runner-multi-overlay-investigation-2026-05-12.md}`.

2. Diagnose the screener-weights-inert finding: 4-cell sweep
   `{rs: 0.0, rs: 5.0}` × one-dim, see if any extreme moves the
   objective. If still flat → H1 confirmed (cascade is grade-driven).

3. Pin a long-short 16y golden (Phase A of the short plan).

4. Run P5 / P6 sweeps with the new `installed_stop_min_pct` knob —
   the entry-caps arm C that the bug investigation was chasing.

5. Re-run the 5 OOM holding-period cells at `--parallel 2` for matrix
   completeness (P3 from the priorities note).
