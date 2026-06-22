# Plan: expose `barbell_floor_weight` as a searchable axis (R2 completion)

Date: 2026-06-22
Track: `barbell-overlay`
Branch: `feat/barbell-floor-weight-axis`

## 1. Context

The deployable barbell overlay (gate #2, PR #1683) landed `Barbell_config.t`
with three default-off fields (`enable`, `floor_weight`, `rebalance_weeks`).
Per `.claude/rules/experiment-flag-discipline.md`:

- **R1 (default-off on merge)** — satisfied: every field is a no-op at default
  (`floor_weight = 0.0` ≡ pure engine).
- **R2 (an axis the day it lands)** — **not yet satisfied**. The mechanism is
  not searchable: a session that wants to compare 70/30 vs neighbouring floor
  weights (0.20 / 0.30 / 0.40 / …) must hand-run `barbell_overlay_runner.exe`
  once per weight and `paste`/`awk` the metric rows together by hand.
- **R3 (no default-on without ACCEPT)** — out of scope here; we flip no default.

This task closes **R2**: make `floor_weight` enumerable into a searchable
surface — one barbell run + one metric row per weight value — as a small, pure,
unit-testable expander.

### Why the existing axis machinery cannot be reused as-is

`Variant_matrix` (`trading/trading/backtest/walk_forward/lib/variant_matrix.mli`)
expands axes into `Walk_forward_runner.variant`s and **validates every override
at expansion time against the canonical `Weinstein_strategy.config`** via
`Overlay_validator.apply_overrides` (its `.mli` hard-codes that config type).
But `floor_weight` lives in a **separate** `Barbell_config.t`, and the barbell
overlay runs through its **own** `Barbell_scenario.run` →
`Barbell_runner.run` path, not the walk-forward / variant-matrix path. So a
`(barbell floor_weight)` override would fail `Overlay_validator` validation —
`floor_weight` is not a `Weinstein_strategy.config` field.

## 2. Approach — Option 1 (self-contained barbell floor-weight sweep) — CHOSEN

A small, pure module **`Barbell_floor_sweep`** in
`trading/trading/backtest/barbell/lib/` that:

- Declares a floor-weight axis: a list of `floor_weight` values to search.
- Expands it into one **cell per value**, each carrying the resolved
  `Barbell_config.t` (`enable = true`, that `floor_weight`, the shared
  `rebalance_weeks`) and a deterministic `label` (`floor_weight=0.30`).
- Provides a pure `metrics_table` that, given a per-cell *blend thunk*
  (`Barbell_config.t -> Barbell_blend.metrics`), forces each cell and returns
  the `(label, floor_weight, metrics)` rows — the searchable surface, ordered
  by ascending weight. The thunk indirection keeps the expander unit-testable
  without forking a real backtest, mirroring `Barbell_runner`'s
  leg-thunk / `Rolling_start_runner`'s pure-executable split.

This mirrors `Variant_matrix`'s "declare axis → expand to cells" ergonomics but
scoped entirely to `Barbell_config`, validated against `Barbell_config.validate`
(not `Overlay_validator`). No edit to `Weinstein_strategy.config`,
`Overlay_validator`, or `Variant_matrix`.

A thin executable **`barbell_floor_sweep_runner.exe`** under
`scenario/bin/` reuses `Barbell_scenario.run` once per cell (real backtest legs,
the engine leg run once and shared across weights since only the blend weight
varies) and writes a `floor_sweep.csv` metric table — so the surface is
producible from a single CLI invocation instead of N manual runs.

### Axis-value reuse: run the legs once, blend N times

`floor_weight` only changes the **blend weight** of two fixed equity curves; it
does not change either leg's backtest. So the runner runs the FLOOR and ENGINE
legs **once each**, then calls `Barbell_blend.blend` per weight against the same
two curves. This is both correct (the legs are weight-independent) and ~N× faster
than N full barbell runs. The pure `Barbell_floor_sweep.metrics_table` is given a
blend thunk that closes over the two shared curves, so this optimisation lives in
the runner, not the pure core.

### Rejected: Option 2 (generalize the axis machinery)

Generalizing `Overlay_validator` / `Variant_matrix` to validate against config
types other than `Weinstein_strategy.config` (functor/typeclass over the base
record) is a cross-cutting experiment-platform change touching shared modules the
maintainer owns. It is out of scope for an R2-completion follow-up and explicitly
fenced off by the dispatch guard. Option 1 fully satisfies R2 (the weight becomes
searchable as a surface) without it.

### Rejected: Option 3 (graft barbell config into `Weinstein_strategy.config`)

Explicitly forbidden by the dispatch (maintainer mid-sprint on those files).

## 3. Files to change

New (all under `trading/trading/backtest/barbell/`):
- `lib/barbell_floor_sweep.mli` — axis type + `cells` (axis → cells) + pure
  `metrics_table` (cells × blend-thunk → rows).
- `lib/barbell_floor_sweep.ml` — implementation.
- `test/test_barbell_floor_sweep.ml` — unit tests (pure, no backtest fork).
- `scenario/bin/barbell_floor_sweep_runner.ml` — CLI: run legs once, blend per
  weight, write `floor_sweep.csv`.

Modified:
- `test/dune` — add `test_barbell_floor_sweep` to `(names …)`.
- `scenario/bin/dune` — add the new executable.
- `dev/status/barbell-overlay.md` — flip the R2 checkbox, add a §Completed entry.

No edits to `lib/dune` libraries needed (the sweep module depends only on
`core` + the existing `barbell` lib's `Barbell_config` / `Barbell_blend`, which
are in the same library).

## 4. Risks / unknowns

- **R2 faithfulness.** R2 says "make it an axis"; the canonical axis type is
  `Variant_matrix.axis`. Risk: a reviewer reads R2 as *literally a
  `Variant_matrix` cell*. Mitigation: the plan + module docstring state
  explicitly that `Variant_matrix` validates against `Weinstein_strategy.config`
  and so cannot carry a `Barbell_config` field, and that this module is the
  faithful in-scope equivalent (declare axis → expand → searchable surface,
  validated against `Barbell_config.validate`). The mechanism *is* now
  searchable from one invocation, which is R2's purpose.
- **Default-off invariant.** The sweep enumerates weights but flips no global
  default; the axis is only realised when a session opts into running the
  sweep. `floor_weight = 0.0` remains a valid (no-op) cell.
- **Validation.** Each cell's `Barbell_config` must pass `Barbell_config.validate`
  (weight in `[0,1]`); the expander rejects an out-of-range weight loudly
  (mirrors `Variant_matrix` raising on a bad override) rather than silently
  producing a degenerate cell.

## 5. Acceptance criteria

- `Barbell_floor_sweep` exposes a pure axis → cells expansion and a pure
  `metrics_table`, every public symbol documented in the `.mli`.
- Unit tests (Matchers, one `assert_that` per value): cell count = value count,
  ascending-weight ordering, `Barbell_config` per cell correct, default-weight
  (0.0) cell present and valid, out-of-range weight rejected, and a
  `metrics_table` over a stub blend-thunk returns one row per cell in order.
- `barbell_floor_sweep_runner.exe` builds and reuses `Barbell_scenario`'s leg
  construction; legs run once, blended per weight.
- No function > 50 lines, no magic numbers (axis defaults are named / config).
- `dev/lib/run-in-env.sh dune build && dune runtest` green, `dune build @fmt`
  clean.
- No edits to `Weinstein_strategy.{ml,mli}`, `Overlay_validator`,
  `Variant_matrix`, or any core module. Diff confined to `barbell/` + plan +
  the one status row.

## 6. Out of scope

- Flipping any default on (promotion) — ledger-gated per R3 /
  `promotion-confirmation.md`.
- Generalizing `Overlay_validator` / `Variant_matrix` (Option 2).
- Wiring `floor_weight` into the walk-forward CV / Deflated-Sharpe pipeline —
  the sweep produces the metric surface; ranking/CV is a separate concern.
- Any change to the blend math, leg construction, or `Barbell_scenario`/runner
  semantics beyond the new sweep entrypoint.
