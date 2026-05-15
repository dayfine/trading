# Walk-forward CV harness — implementation plan (Phase 2)

Date: 2026-05-15. Authority:
`dev/notes/next-session-priorities-2026-05-15.md` §"Phase 2 —
walk-forward CV harness". This is the first PR of a planned ~3-5 PR
track owned by `feat-backtest`.

## Context

Two cross-window inversions this week — M5.5 axis-2's 5y→16y blowup
(PR #1086) and the continuation-buy combined-axis sweep (PR #1095) —
have made the diagnosis explicit: **Cell E is locally near-optimal on
the levers it exposes**. The limiting factor is the validation
discipline, not the search surface.

The existing walk-forward setup at
`dev/experiments/cell-e-walk-forward-2026-05-08/` is **8 hand-curated
scenarios** (4 pairs × 2 cells). That partition produced an "11/12
wins" verdict that nonetheless failed both subsequent 16y validation
sweeps. The hand-curated shape:

- Only 4 underlying windows; one (`bull-crash-2018-2020` /
  `six-year-2018-2020`) is bit-identical.
- Two-half splits give 2 measurements per window — minimum useful
  variance signal.
- No explicit go/no-go gate; the verdict was eyeballed from the table.

Phase 2 scales this to ~30 rolling folds with parameterised window
specs, automated report generation, and a load-bearing
machine-checkable gate.

The existing infra:

- `Scenario_lib.Scenario` (`trading/trading/backtest/scenarios/scenario.{ml,mli}`)
  — sexp-loadable scenario with `period`, `universe_path`,
  `config_overrides`, `expected`.
- `Scenario_runner` (`.../scenario_runner.ml`) — parallel
  per-scenario runner via fork; writes `actual.sexp` + per-scenario
  artefacts under a timestamped output root.
- `Tuner_bin.Bayesian_runner_evaluator` — the closest analogue: an
  evaluator builder that takes `~fixtures_root ~scenarios
  ~scenarios_by_path ~objective` and runs backtests with parameter
  overrides applied per cell. Phase 3 will likely consume this lib.

## Approach

Add a new sub-library + binary under
`trading/trading/backtest/walk_forward/`:

- `lib/window_spec.{ml,mli}` — `WindowSpec.t` describing rolling
  window generation: anchor dates, train/test/step lengths in days,
  whether to emit train fold or test-only fold scenarios. Pure;
  produces a list of `{ name; period }` pairs.
- `lib/fold_gate.{ml,mli}` — pure go/no-go gate. Encodes the rule
  "wins on ≥M of N folds with no fold worse than baseline by Δ". `M`,
  `N`, and `Δ` configurable. Returns `Gate_pass | Gate_fail of
  reason_list`.
- `lib/walk_forward_runner.{ml,mli}` — pure: given a base scenario
  sexp template + `WindowSpec.t` + a list of variant config-override
  bundles (each tagged with a label like "baseline" / "cell-E"),
  generates per-fold per-variant `Scenario.t` values ready for
  `scenario_runner` execution. **Does not run backtests itself in this
  PR** — delegation is via emitting scenario sexps to a scratch dir
  and shelling out to the existing `scenario_runner.exe`, OR by
  exposing the generated list for an in-process driver. We pick the
  emit-and-shell-out shape because (a) it reuses the entire forked
  scenario_runner harness, (b) it's interruptible / re-runnable, (c)
  it gives free per-fold artefacts (trades.csv, summary.sexp, etc.)
  for downstream diagnosis.
- `lib/walk_forward_report.{ml,mli}` — pure: given a list of
  `(fold_name, variant_label, actual.sexp)` triples + a baseline
  variant label + gate parameters, emits a markdown report with the
  four required sections (per-fold metrics, stability, sensitivity,
  go/no-go).
- `bin/walk_forward_runner.ml` — thin CLI: reads a top-level sexp
  spec (`(window_spec ...) (variants ((label baseline) (overrides
  ...))) (base_scenario ...) (gate ...)`), generates per-fold
  scenario sexps under `--out-dir/scenarios/`, optionally invokes
  `Scenario_runner` machinery in-process (NOT shelling out — same
  process), reads the per-fold `actual.sexp` files, emits
  `walk_forward_report.md`.

### Public interfaces

```ocaml
(* window_spec.mli *)
type t = {
  start_date : Date.t;          (* first fold start *)
  end_date : Date.t;            (* last fold end (clamp) *)
  train_days : int;             (* in-sample width; 0 = OOS-only folds *)
  test_days : int;              (* out-of-sample width *)
  step_days : int;              (* how far to advance each fold *)
} [@@deriving sexp]

type fold = {
  index : int;                  (* 0-based *)
  name : string;                (* e.g. "fold-007" *)
  train_period : Scenario.period option;   (* None when train_days = 0 *)
  test_period : Scenario.period;
} [@@deriving sexp]

val generate : t -> fold list
(** Pure: roll a window of train_days + test_days from start_date
    forward in step_days increments, clamping to end_date.
    Folds whose test_period would extend past end_date are dropped. *)
```

```ocaml
(* fold_gate.mli *)
type metric_key =
  | Sharpe
  | Calmar
  | TotalReturnPct
  | MaxDrawdownPct
[@@deriving sexp]

type t = {
  metric : metric_key;          (* what to gate on *)
  m : int;                      (* must win at least M folds *)
  n : int;                      (* of the N folds measured *)
  worst_delta : float;          (* no single fold worse than baseline by > Δ *)
} [@@deriving sexp]

type fold_result = {
  fold_name : string;
  variant_score : float;
  baseline_score : float;
}

type verdict =
  | Pass of { wins : int; n : int; }
  | Fail of { wins : int; n : int; worst_fold : string; worst_gap : float; reason : string }

val evaluate : t -> fold_result list -> verdict
```

```ocaml
(* walk_forward_runner.mli — scenario generation *)
type variant = {
  label : string;
  overrides : Sexp.t list;
}

val build_fold_scenario :
  base : Scenario.t ->
  fold : Window_spec.fold ->
  variant : variant ->
  Scenario.t
(** Pure: produces a Scenario.t with name = "<base.name>-<variant.label>-<fold.name>",
    period = fold.test_period, config_overrides = base.config_overrides @
    variant.overrides. *)

val build_all :
  base : Scenario.t ->
  spec : Window_spec.t ->
  variants : variant list ->
  Scenario.t list
```

```ocaml
(* walk_forward_report.mli *)
type fold_actual = {
  fold_name : string;
  variant_label : string;
  total_return_pct : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
  calmar_ratio : float;
}

val render :
  baseline_label : string ->
  gate : Fold_gate.t ->
  fold_actuals : fold_actual list ->
  string
(** Pure: produces a markdown report with:
    (1) Per-fold metrics table (one row per fold × variant)
    (2) Stability table (mean ± stdev per variant)
    (3) Sensitivity ranking (variant win-count per fold)
    (4) Go/no-go verdict block from Fold_gate.evaluate. *)
```

### Rejected alternatives

1. **Reuse `Tuner_bin.Bayesian_runner_evaluator` directly.** That
   evaluator takes a single scenario and folds parameters over it. The
   walk-forward harness folds **windows**, not parameters — different
   axis. We will hand off variant evaluation to Phase 3's BO loop, but
   the walk-forward harness must own window generation independently.
2. **Modify `scenario.mli` to add a `windows` field.** That bloats the
   scenario type for every consumer. Keep windows as a separate spec;
   generate per-window scenarios from a base template.
3. **Re-invent metric collection / forking.** We delegate execution to
   `Backtest.Runner.run_backtest` directly inside the binary (same
   pattern as `Bayesian_runner_evaluator.build`). Parallel forking is
   future work — start sequential, mirror `scenario_runner.ml`'s
   fork-pool only if needed.

## Files to change

| Path | Status | Est. lines |
|---|---|---|
| `trading/trading/backtest/walk_forward/lib/window_spec.mli` | new | ~30 |
| `trading/trading/backtest/walk_forward/lib/window_spec.ml` | new | ~50 |
| `trading/trading/backtest/walk_forward/lib/fold_gate.mli` | new | ~40 |
| `trading/trading/backtest/walk_forward/lib/fold_gate.ml` | new | ~80 |
| `trading/trading/backtest/walk_forward/lib/walk_forward_runner.mli` | new | ~40 |
| `trading/trading/backtest/walk_forward/lib/walk_forward_runner.ml` | new | ~60 |
| `trading/trading/backtest/walk_forward/lib/walk_forward_report.mli` | new | ~40 |
| `trading/trading/backtest/walk_forward/lib/walk_forward_report.ml` | new | ~150 |
| `trading/trading/backtest/walk_forward/lib/dune` | new | ~10 |
| `trading/trading/backtest/walk_forward/test/test_window_spec.ml` | new | ~80 |
| `trading/trading/backtest/walk_forward/test/test_fold_gate.ml` | new | ~120 |
| `trading/trading/backtest/walk_forward/test/test_walk_forward_runner.ml` | new | ~80 |
| `trading/trading/backtest/walk_forward/test/test_walk_forward_report.ml` | new | ~80 |
| `trading/trading/backtest/walk_forward/test/dune` | new | ~10 |
| `trading/trading/backtest/walk_forward/bin/walk_forward_runner.ml` | new | ~120 |
| `trading/trading/backtest/walk_forward/bin/dune` | new | ~10 |
| `dev/status/walk-forward-cv.md` | new | ~50 |
| `dev/plans/walk-forward-cv-harness-2026-05-15.md` | this file | ~250 |

Total estimated source lines: ~720; total tests: ~360; total LOC
including docs/status: ~1050.

## Risks

1. **Same M5.5 cross-window inversion the gate is meant to prevent.**
   The gate language ("wins on ≥M of N with no fold worse than
   baseline by Δ") only catches inversions if the fold count is
   large enough to surface tail behavior. Mitigation: the gate is
   tunable; the harness is the discipline, not the threshold. Phase 3
   chooses thresholds.
2. **30 folds × N variants is multi-hour even on small universe.**
   Mitigation: this PR ships the scenario-generation + report
   machinery + a tiny integration test (2-3 folds on parity-7sym).
   Big-fold runs are out of scope for this PR; they're run-time
   artefacts produced once the harness is merged.
3. **Sexp interface ossification.** The variant-and-gate sexp shape
   becomes the public contract for downstream tooling. Mitigation:
   mark unstable in the `.mli`; we expect to iterate when Phase 3 BO
   integration lands.
4. **Date arithmetic.** Train/test boundary off-by-one bugs are
   classic walk-forward failures. Mitigation: `WindowSpec.generate`
   is pure with property tests over canonical date inputs.

## Acceptance (this PR only)

- [ ] `dune build && dune runtest` passes from a clean checkout.
- [ ] `dune build @fmt` clean.
- [ ] All public functions in `walk_forward/lib/*.mli` have doc
  comments.
- [ ] No function exceeds 50 lines (hard limit).
- [ ] Tests use `assert_that` + matchers per
  `.claude/rules/test-patterns.md`.
- [ ] `WindowSpec.generate` has at least 3 distinct date-arithmetic
  test cases (start = end, train = 0, step > test).
- [ ] `Fold_gate.evaluate` has a test for each of: full pass, M
  threshold miss, Δ threshold miss, baseline tie.
- [ ] `Walk_forward_runner.build_fold_scenario` has a parity test
  showing variant overrides are appended *after* base overrides
  (last-writer-wins, matching `Bayesian_runner_evaluator`).
- [ ] `Walk_forward_report.render` produces deterministic markdown for
  fixed inputs (one pinned-string test).
- [ ] `walk_forward_runner.exe` builds and has a `--help` flag. End-
  to-end backtest invocation is wired but its on-corpus correctness
  is deferred — the test plan uses tiny synthetic actuals.
- [ ] `dev/status/walk-forward-cv.md` created with Status / Interface
  stable / Completed / In Progress / Next Steps / Commits.
- [ ] PR diff ≤ ~1000 LOC including tests.

## Out of scope (defer)

- **Running an actual ~30-fold sweep.** First PR ships the harness;
  the first real sweep is a follow-up local run.
- **Phase 3 Bayesian integration.** Out of scope here. The harness
  exposes its public interface so a future PR can wire it into
  `bayesian_runner.exe` or a successor.
- **Parallel fold execution via fork-pool.** Start sequential; copy
  `scenario_runner._run_scenarios_parallel` only when wall-time
  measurements demand it.
- **Multi-universe sweeps.** Single-universe per spec for now.
- **Modifications to `Scenario.t`, `Backtest.Runner`, the tuner libs,
  or any existing surface.** Pure addition.
