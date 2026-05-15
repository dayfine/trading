## Walk-forward CV harness — Phase 2 follow-up: scale to ~30 rolling folds

Date: 2026-05-16. Authority:
`dev/notes/next-session-priorities-2026-05-16.md` §"P2 walk-forward CV".
Predecessor: PR #1100 (`dev/plans/walk-forward-cv-harness-2026-05-15.md`)
which landed `Window_spec` + `Fold_gate` + `Walk_forward_runner` +
`Walk_forward_report` + the thin CLI. This is the second PR of the
~3-5 PR Phase-2 track.

## Context

PR #1100 landed the harness modules. Their first-PR scope was "build
the machinery"; the second-PR scope (this PR) is "make ~30 rolling
folds expressible and instrumented, and migrate the 2026-05-08
hand-curated 8-fold experiment onto the harness as a regression
fixture".

What PR #1100 already does well:

- `Window_spec.t` is already a rolling generator with `start_date /
  end_date / train_days / test_days / step_days`. Setting `train_days
  = 0` produces OOS-only folds; setting `step_days = test_days /2`
  gives 50%-overlap rolling folds, etc. **The rolling-K-fold case
  is already expressible.** The dispatch's framing — "extend from N
  half-period folds to rolling K-fold" — is partly already done.
- `Fold_gate.evaluate` already encodes "wins ≥M of N AND no fold
  worse by Δ", parameterised by metric (Sharpe / Calmar /
  TotalReturnPct / MaxDrawdownPct). Direction is correctly inverted
  for drawdown.
- `Walk_forward_report.render` already emits per-fold metrics,
  stability (μ±σ per variant), cross-fold sensitivity (win-counts
  per variant on the gate's metric), and a go/no-go verdict block.

What's missing for the dispatch's "scale to ~30 rolling folds":

1. **No way to express the existing 8 hand-curated folds.** The
   2026-05-08 experiment has 4 distinct underlying windows
   (`bull-crash-2015-2017`, `bull-crash-2018-2020`, `covid-2020-2022h1`,
   etc.) — each split into two halves. The four windows are NOT a
   rolling-step pattern; one (`bull-crash-2018-2020` /
   `six-year-2018-2020`) is bit-identical. The rolling
   `start_date/end_date/step_days` shape can't generate that
   exact set. To migrate the 8-fold experiment onto the harness as
   a regression fixture — important because that's the dataset the
   "M5.5 axis-2 / continuation-combined" 11/12 verdict came from —
   we need an explicit-folds escape hatch.
2. **Stability is markdown-only.** `Walk_forward_report` emits
   μ±σ in a table but doesn't expose the underlying floats. The
   dispatch asks for variance of Sharpe/CAGR/MaxDD as a programmatic
   surface so Phase 3 (BO) can consume it directly without parsing
   markdown.
3. **Cross-fold sensitivity is single-metric.** The current
   sensitivity section computes wins-per-variant on the gate's
   metric only. The dispatch asks "does cell X win on every fold or
   just on average" — that's already covered for one metric, but
   surfacing wins on each of {Sharpe, Calmar, TotalReturn, MaxDD}
   would let the human see Sharpe-vs-MaxDD trade-offs at a glance.
4. **No checked-in spec for the ~30-fold sweep.** PR #1100's binary
   reads a spec sexp but no production spec lives under
   `trading/test_data/backtest_scenarios/`. Adding a canonical
   `walk-forward-cell-e-30fold/spec.sexp` is the smallest "make it
   real" step.

## Approach

Pure addition only. Touch the existing 4 walk-forward modules; do not
modify `Scenario.t`, `Backtest.Runner`, or any tuner lib. Tests for
new code; no test regressions.

### 1. `Window_spec` — add an `Explicit` constructor

Today's `Window_spec.t` is a single record. Promote it to a variant:

```ocaml
(* window_spec.mli — new shape *)

type rolling_spec = {
  start_date : Date.t;
  end_date : Date.t;
  train_days : int;
  test_days : int;
  step_days : int;
} [@@deriving sexp]

type explicit_fold = {
  name : string;
  train_period : Scenario_lib.Scenario.period option;
  test_period : Scenario_lib.Scenario.period;
} [@@deriving sexp]
(** One hand-curated fold. The `name` is the suffix used in generated
    scenario names; the `train_period` is optional like the rolling
    case. *)

type t =
  | Rolling of rolling_spec
  | Explicit of explicit_fold list
[@@deriving sexp]

type fold = {
  index : int;
  name : string;
  train_period : Scenario_lib.Scenario.period option;
  test_period : Scenario_lib.Scenario.period;
} [@@deriving sexp]

val generate : t -> fold list
(** Rolling: as today — start_date/train_days/test_days/step_days
    expansion, dropping folds extending past end_date.

    Explicit: passes the list through, assigning [index]
    in input order and using each [explicit_fold.name] as [fold.name]
    verbatim (NOT "fold-NNN"). Raises [Failure] on duplicate names
    or empty list. *)
```

**Sexp migration.** The current sexp shape is a flat record:
`((start_date ...) (end_date ...) (train_days ...) ...)`. The new
shape is a variant: `(Rolling ((start_date ...) ...))` or
`(Explicit (((name ...) (test_period ...))...))`. To avoid breaking
the in-tree spec file the binary consumes, ship a one-line
backwards-compatible parser:

```ocaml
let t_of_sexp sexp =
  match sexp with
  | Sexp.List (Sexp.Atom "Rolling" :: _) | Sexp.List (Sexp.Atom "Explicit" :: _)
    -> [%of_sexp: t_variant] sexp
  | _ -> Rolling (rolling_spec_of_sexp sexp)  (* legacy flat shape *)
```

Test: round-trip the legacy flat shape, the new `Rolling` shape, and
the new `Explicit` shape. ~3 tests.

### 2. `Walk_forward_report` — expose structured stability + multi-metric sensitivity

Today's `render : ... -> string` is markdown-only. Add a sibling
`compute : ...` that returns a structured value, and route the
existing `render` through it. Markdown output preserved byte-identically.

```ocaml
(* walk_forward_report.mli additions *)

type per_metric_stats = {
  mean : float;
  stdev : float;       (* sample stdev, NaN when N < 2 *)
  min : float;
  max : float;
} [@@deriving sexp]

type variant_stability = {
  variant_label : string;
  total_return_pct : per_metric_stats;
  sharpe_ratio : per_metric_stats;
  max_drawdown_pct : per_metric_stats;
  calmar_ratio : per_metric_stats;
} [@@deriving sexp]

type variant_sensitivity = {
  variant_label : string;
  sharpe_wins : int;
  calmar_wins : int;
  total_return_wins : int;
  max_drawdown_wins : int;    (* "wins" = lower MaxDD than baseline *)
} [@@deriving sexp]

type aggregate = {
  fold_count : int;
  baseline_label : string;
  stability : variant_stability list;       (* including baseline *)
  sensitivity : variant_sensitivity list;   (* excluding baseline *)
  verdicts : (string * Fold_gate.verdict) list;  (* per non-baseline variant *)
} [@@deriving sexp]

val compute :
  baseline_label:string ->
  gate:Fold_gate.t ->
  fold_actuals:fold_actual list ->
  aggregate
(** Same validation rules as [render]; returns the structured aggregate
    Phase 3 (Bayesian optimizer) consumes directly. *)

val render :
  baseline_label:string ->
  gate:Fold_gate.t ->
  fold_actuals:fold_actual list ->
  string
(** Unchanged behaviour — internally now calls [compute] and prints.
    The cross-fold sensitivity section's table grows from 1 metric
    to 4 metrics (Sharpe / Calmar / TotalReturn / MaxDD wins).
    The verdict block remains gate-metric-only. *)
```

The aggregate gets serialised to `<out-dir>/aggregate.sexp` by the
binary in addition to the existing `walk_forward_report.md` and
`fold_actuals.sexp`. Phase 3's BO loop reads `aggregate.sexp` to
score candidate variants.

### 3. Multi-metric sensitivity in the markdown report

The "wins-per-variant" table grows from 1 column to 4. Keep the
gate-metric column highlighted (asterisk in the column header).

Pinned-string test: the existing report's "Cross-fold sensitivity"
section will diff. Update the pinned string in
`test_walk_forward_report.ml`.

### 4. Migrate the 2026-05-08 8-fold experiment as a `Window_spec.Explicit`

Add `dev/experiments/cell-e-walk-forward-2026-05-08-harness/spec.sexp`
that re-expresses the 8 hand-curated scenarios as a single
`Window_spec.Explicit` plus `variants = [cell-A; cell-E]`. This is
the regression fixture proving the harness reproduces (within
tolerance) the existing eyeballed 11/12 verdict.

Do NOT run the actual sweep in this PR — running it is a follow-up
that produces `report.md`. This PR's deliverable is the spec sexp
checked in and a pinned-test demonstrating the spec loads via
`spec_of_sexp` and `Window_spec.generate` produces the expected 8 folds.

### 5. Production 30-fold spec sexp (checked in, not run)

Add `dev/experiments/walk-forward-cell-e-30fold-2026-05-16/spec.sexp`
with:

- `base_scenario = "goldens-sp500-historical/sp500-2010-2026.sexp"`
- `window_spec = Rolling { start_date = 2010-01-01; end_date =
  2026-04-30; train_days = 0; test_days = 365; step_days = 182 }` —
  yields ~30 OOS-only rolling folds (16y / 0.5y = 32 candidate
  anchors; the harness clamps to those whose test_period ends
  before 2026-04-30).
- `variants = [baseline; cell-E]` — actually, cell-E IS the pinned
  baseline now, so variants = [cell-E-baseline; cell-A-degenerate]
  to give the harness a "known no-op" comparison sanity check.
- `gate = { metric = Sharpe; m = 17; n = 30; worst_delta = 0.30 }`
  — "wins on majority of folds, no fold worse by 0.30 Sharpe".

Same caveat as #4: this PR ships the spec; the actual sweep is a
local-only follow-up.

## Per-fold stability surfacing — does the dispatch need anything beyond μ±σ?

Re-checking the dispatch language:

> Per-fold stability metric surfacing (variance of Sharpe / CAGR /
> MaxDD across folds) — confirm `Walk_forward_report` already
> supports this or what extension is needed.

The current `_render_stability_table` (`walk_forward_report.ml:69-87`)
prints `μ ± σ` for each of `total_return_pct`, `sharpe_ratio`,
`max_drawdown_pct`, `calmar_ratio` per variant. That's the
"variance across folds" the dispatch asks for. **Programmatic
surfacing is the missing piece** — `aggregate.sexp` in §2 supplies it.

CAGR specifically is NOT one of the four metrics; today's
`fold_actual.total_return_pct` is total return over the test
window (not annualised). For ~1-year test windows that's roughly
CAGR anyway, but for `test_days != 365` it isn't. Add a
`cagr_pct : float` field to `fold_actual` derived from
`total_return_pct + test_period.length`:

```ocaml
(* derived in walk_forward_runner.ml bin, NOT a backtest summary metric *)
let _cagr_pct ~test_days ~total_return_pct =
  let years = Float.of_int test_days /. 365.25 in
  ((1.0 +. (total_return_pct /. 100.0)) ** (1.0 /. years) -. 1.0) *. 100.0
```

Per-fold tests: assert that `cagr_pct = total_return_pct` (within
tolerance) when `test_days = 365`, and assert the formula for
182-day and 730-day windows.

## Cross-fold parameter sensitivity — what new aggregation in `walk_forward_report.ml`?

Already covered in §2/§3 above: the existing single-metric
wins-per-variant table becomes 4-metric. No new logic; the
`_wins_per_variant_on_metric` helper already exists and is
metric-parameterised — we just call it four times for the four
metrics.

## Go/no-go gate language — already in place per PR #1100?

Yes. Confirmed by re-reading `fold_gate.mli` lines 19-37 and
`fold_gate.ml` lines 82-101. The shape is:

> Pass iff (variant wins ≥M folds) AND (no fold worse by >Δ).

The metric is configurable, direction-inverted for drawdown, and
the `fold_result` records carry per-fold variant + baseline scores.
This PR does not modify `Fold_gate`.

## Files to change

| Path | Status | Est. lines |
|---|---|---|
| `trading/trading/backtest/walk_forward/lib/window_spec.mli` | edit | +25 / -5 |
| `trading/trading/backtest/walk_forward/lib/window_spec.ml` | edit | +40 / -5 |
| `trading/trading/backtest/walk_forward/lib/walk_forward_report.mli` | edit | +60 / -0 |
| `trading/trading/backtest/walk_forward/lib/walk_forward_report.ml` | edit | +90 / -20 |
| `trading/trading/backtest/walk_forward/bin/walk_forward_runner.ml` | edit | +30 / -5 |
| `trading/trading/backtest/walk_forward/test/test_window_spec.ml` | edit | +50 / -0 |
| `trading/trading/backtest/walk_forward/test/test_walk_forward_report.ml` | edit | +60 / -0 |
| `dev/experiments/cell-e-walk-forward-2026-05-08-harness/spec.sexp` | new | ~50 |
| `dev/experiments/walk-forward-cell-e-30fold-2026-05-16/spec.sexp` | new | ~30 |
| `dev/status/walk-forward-cv.md` | edit | +25 / -3 |
| `dev/plans/walk-forward-cv-rolling-30fold-2026-05-16.md` | this file | ~250 |

Total estimated source lines: **~270 src + ~110 tests + ~80 fixtures
+ ~50 status/plan = ~510 LOC**. At the upper edge of the <500-LOC
target; if the implementation drifts over, split §1+§2+§4 into one
PR and §3+§5+CAGR into a follow-up PR.

## Rejected alternatives

1. **Define a new `WindowSpec.Hybrid` constructor that mixes
   rolling + explicit folds.** Over-engineered for the dispatch's
   scope. Rolling-only and explicit-only cover the two use cases
   we have. Hybrid is a YAGNI knob.
2. **Compute aggregate stats inside `Fold_gate`.** They belong
   with the renderer; the gate is single-purpose ("pass/fail this
   shape of fold list"). Putting stats in the gate bloats the
   gate's contract.
3. **Change `Fold_gate` to be multi-metric.** Today's gate gates
   on ONE metric. The dispatch confirms this is the right shape —
   "wins ≥M of N folds with no fold worse than baseline by Δ" is
   a single-metric statement. Multi-metric gating is a future
   research question (gate on Sharpe, with drawdown as a tiebreaker?)
   that's out of scope here.
4. **Run the actual 30-fold sweep as part of this PR.** That's
   multi-hour wall-time; mismatches the "harness merge" cadence.
   The sweep is a local-only follow-up; this PR ships the
   instrumentation.

## Risks

1. **Sexp variant migration breaks existing in-tree spec files.**
   Mitigated by the legacy-flat-shape fallback in `t_of_sexp`. Add a
   regression test that loads a flat-shape spec and confirms it
   parses as `Rolling`. The `cell-e-walk-forward-2026-05-08-harness/`
   spec uses the new variant shape; nothing in-tree uses the old
   flat shape yet (PR #1100's tests construct the value in OCaml
   directly), so the migration is low-risk.
2. **CAGR formula off-by-one when test_days crosses leap days.**
   Mitigated by tolerance (±0.05 pp) in the formula test. The
   formula is `(1+r)^(1/years) - 1` where `years =
   test_days / 365.25`. We don't try to be calendar-exact;
   approximately right is fine for a stability metric.
3. **Multi-metric sensitivity table is hard to read with 4 columns
   per variant.** Mitigated by marking the gate metric with `*` and
   keeping the table to 6 columns total (variant, sharpe wins,
   calmar wins, total return wins, maxdd wins, of-N). Local-eye
   review confirms readability before merge.
4. **The 2026-05-08 8-fold-as-Explicit spec drifts from the original
   scenarios' config_overrides.** Mitigated by `cell-e-walk-forward-
   2026-05-08-harness/spec.sexp` re-using the SAME base_scenario
   + variants that the original `.sexp` files use; no
   config_overrides drift. Confirmed by diffing the new spec's
   override sexp against the 16 original files.

## Acceptance (this PR only)

- [ ] `dune build && dune runtest trading/backtest/walk_forward` passes.
- [ ] `dune build @fmt` clean.
- [ ] `Window_spec.t` round-trips through sexp for all three
  shapes: legacy flat, new `Rolling`, new `Explicit`.
- [ ] `Window_spec.generate` on an `Explicit` spec passes folds
  through verbatim with correct indexes.
- [ ] `Walk_forward_report.compute` produces an `aggregate` that
  matches the markdown report on the same inputs (pinned-tuple test
  asserting stability and sensitivity values).
- [ ] Multi-metric sensitivity markdown matches a pinned string
  for fixed inputs.
- [ ] `cagr_pct` formula passes 3 tests (365-day, 182-day, 730-day).
- [ ] `cell-e-walk-forward-2026-05-08-harness/spec.sexp` parses
  via `spec_of_sexp` and `Window_spec.generate` returns exactly 8
  folds with the original names.
- [ ] `walk-forward-cell-e-30fold-2026-05-16/spec.sexp` parses;
  `Window_spec.generate` returns ≥28 folds (target ~30 minus
  end-of-range clamping).
- [ ] `dev/status/walk-forward-cv.md` updated with the new PR's
  scope checked.
- [ ] PR diff ≤ ~500 LOC; split into two PRs if it drifts over.

## Out of scope (defer)

- **Running an actual 30-fold or 8-fold-harness sweep.** This PR
  ships the spec; the runs are follow-ups producing
  `dev/experiments/.../report.md`. The runs are multi-hour
  wall-time and don't fit the "harness extension" PR cadence.
- **Phase 3 Bayesian integration.** Phase 3 consumes
  `aggregate.sexp` (added by this PR). The actual wiring into
  `bayesian_runner.exe` is a separate PR.
- **Parallel fold execution via fork-pool.** Still sequential;
  ~30 folds × 2 variants × ~20 min/fold = ~20 hours wall-time on
  small universe. Acceptable for a one-shot run. Parallel becomes
  necessary when Phase 3 BO requires repeated sweeps.
- **Modifications to `Backtest.Runner`, `Scenario`, `Fold_gate`,
  or the tuner libs.** Pure addition + edits to walk_forward only.
- **`statistical_significance` field on `aggregate`.** Bootstrap
  CI on Sharpe-difference is a research question; deferred.

## Sequence for execution

1. Spec sexp variant + legacy-flat parser + tests (small isolated change).
2. `aggregate` type + `compute` function + structured stability tests.
3. Multi-metric sensitivity in markdown render + pinned-string test.
4. `cagr_pct` derived in binary + 3 tests.
5. Two fixture spec sexps + parse-only tests.
6. Status file update.

If the diff goes over 500 LOC at step 4, split: PR-A = steps 1-2,
PR-B = steps 3-5. Same plan file; the second PR cites this plan
and notes "Part 2 of 2".

## Cross-reference

- Predecessor plan: `dev/plans/walk-forward-cv-harness-2026-05-15.md`
  — PR #1100 spec, merged.
- Status: `dev/status/walk-forward-cv.md` — update to add a "Phase 2.2"
  entry.
- Authority: `dev/notes/next-session-priorities-2026-05-16.md` §P2.
- Memory references: `memory/project_m5-5-tuning-exhausted.md`,
  `memory/project_continuation_combined_rejected.md` — the
  cross-window inversions this harness is designed to catch.
