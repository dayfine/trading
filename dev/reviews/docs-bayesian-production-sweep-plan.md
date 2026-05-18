Reviewed SHA: 1250aed5

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | NA | Docs-only PR; no OCaml code |
| H2 | dune build | NA | Docs-only PR; no OCaml code |
| H3 | dune runtest | NA | Docs-only PR; no OCaml code |
| P1 | Functions ≤ 50 lines (linter) | NA | No OCaml code |
| P2 | No magic numbers (linter) | NA | No OCaml code |
| P3 | Config completeness | NA | No OCaml code |
| P4 | Public-symbol export hygiene (linter) | NA | No OCaml code |
| P5 | Internal helpers prefixed per convention | NA | No OCaml code |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | NA | No OCaml code or tests |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | NA | No code changes |
| A2 | No new `analysis/` imports into `trading/trading/` | NA | No code changes |
| A3 | No unnecessary modifications to existing modules | NA | No code changes; single-file plan doc only |

## Verdict

APPROVED

## Notes

Pure documentation PR: single markdown file (`dev/plans/bayesian-production-sweep-2026-05-18.md`, 292 lines) with no code changes. File is well-structured (12 sections: context, empirical grounding, parameter set, universe/window, objective, budget, run plan, dependencies, risks, scope, acceptance gates, companion docs). Cross-references to PR numbers and design docs are consistent with the codebase. No structural concerns.

---

# Behavioral QC — docs-bayesian-production-sweep-plan
Date: 2026-05-18
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test that pins it | NA | No new `.mli` added; pure planning doc. |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | NA | Test plan is "no code change — pure docs PR" + 3 reviewer-decision checkboxes. The 2 unchecked reviewer items ("Design choices reviewed" and "Smoke run deferred") are not advertised as committed tests. No misleading test claims. |
| CP3 | Pass-through / identity / invariant tests pin identity (not just size_is) | NA | No tests in this PR. |
| CP4 | Each guard called out in code docstrings has a test exercising the guarded-against scenario | NA | No new code/docstrings. |

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| (all S/L/C/T rows) | Stage / stops / cascade / test rows | NA | Pure planning doc; no Weinstein domain logic implemented. No code paths to verify against `weinstein-book-reference.md`. |

## Plan-content review (per dispatcher's 5 concerns)

This is a plan-only PR locking design choices for a sweep that has not yet run.
Behavioral correctness here means: do the design choices correctly reference
the live code surfaces they invoke? Findings:

### Concern 1 — Knob inventory soundness

**FAIL (1 critical, 1 cosmetic).**

- **Critical: `portfolio_config.min_cash_pct` is a deprecated, never-wired
  field.** The plan §2 Axis A includes `min_cash_pct ∈ [0.10, 0.40]` as one of
  8 production-sweep knobs. The canonical mli
  (`trading/trading/weinstein/portfolio_risk/lib/portfolio_risk.mli` lines
  156–162) explicitly documents: *"Deprecated as of 2026-05-01: never wired
  into the entry walk's `check_cash_and_deduct`. Cash discipline is now
  handled by `max_position_pct × max_positions` + macro gating +
  force-liquidation thresholds. Field retained for sexp compat."* The plan's
  own inventory ref (`dev/notes/tunable-parameters-inventory-2026-05-18.md`
  line 143) marks it `DEPRECATED — sexp compat only`. Two further session
  notes corroborate (`next-session-priorities-2026-05-05.md` line 50:
  *"min_cash_pct has zero production callers (deprecated/never-wired)"*;
  `856-grid-sweep-2026-05-05.md` line 61: *"max_long_exposure_pct and
  min_cash_pct are dropped from the sweep"*). **Sweeping this knob will
  waste ~12% of the BO budget (1/8 of an 8-D surface) on a phantom
  dimension — the GP will register no signal because the strategy ignores
  the parameter.** Required fix: remove `min_cash_pct` from the knob set
  (drop to 7 knobs, or substitute a real cash-discipline knob like
  `force_liquidation.min_portfolio_value_fraction_of_peak`).

- **Cosmetic: "Cell-E default" column values are not the canonical defaults.**
  Plan §2 lists `max_position_pct_long = 0.14`, `max_long_exposure_pct = 0.70`,
  `min_cash_pct = 0.30` as "Default (Cell-E)" but the canonical
  `Portfolio_risk.default_config`
  (`trading/trading/weinstein/portfolio_risk/lib/portfolio_risk.ml`
  lines 68–84) sets these to 0.30 / 0.90 / 0.10 respectively. Cell-E baseline
  per `dev/experiments/capital-recycling-combined-2026-05-07/scenarios/cell-E-stage3-k1-laggard-h2.sexp`
  overlays only `enable_stage3_force_exit/laggard` flags — sizing knobs use
  defaults. The 0.14 / 0.70 / 0.30 values are the EMPIRICAL WINNERS from
  `dev/notes/overnight-2026-05-10-results.md` ("Replacing it with `0.14 /
  exp 0.70` or `0.23 / exp 0.70` produces strictly better Sharpe"), not
  the Cell-E baseline. Rename the column "Best-known prior (overnight
  2026-05-10)" or "Centre of bounds" — calling these "Cell-E defaults"
  conflates two different reference points and will confuse the reader
  comparing baseline composite against winner composite in §6 gate 1.

- **Confirmed correct knob paths/types:**
  - `portfolio_config.max_position_pct_long` (Portfolio_risk.mli:163) ✓
  - `portfolio_config.max_long_exposure_pct` (Portfolio_risk.mli:136) ✓
  - `initial_stop_buffer` is a TOP-LEVEL field on
    `Weinstein_strategy_config` (weinstein_strategy_config.mli:19) ✓ — note
    this is NOT under `stops_config`; the bare unqualified name in the plan
    is correct as-is.
  - `installed_stop_min_pct` actually lives at
    `screening_config.candidate_params.installed_stop_min_pct`
    (screener.mli:42). The plan §2 lists the bare field name without the
    `screening_config.candidate_params.` prefix. This needs to be made
    explicit in the spec.sexp `(bounds (...))` key (e.g.
    `"screening_config.candidate_params.installed_stop_min_pct"`) for the
    BO evaluator to thread the override correctly. Otherwise no behavior
    will change when the BO varies the value — same effective bug as
    `min_cash_pct`. Required fix: write out full sexp paths in §2 to make
    the override key unambiguous before authoring the spec sexp in Phase A.
  - `stage3_force_exit_config.hysteresis_weeks` (stage3_force_exit.mli:44) ✓
  - `laggard_rotation_config.hysteresis_weeks` (laggard_rotation.mli:49) ✓
  - `stage3_reentry_cooldown_weeks` (weinstein_strategy_config.mli:32) ✓ —
    confirmed top-level field. Note `laggard_reentry_cooldown_weeks` exists
    too (line 36) and is NOT in the sweep; that's a deliberate omission worth
    documenting alongside the deferral list in §2 "out of scope".

### Concern 2 — Universe choice rationale

**PASS with caveat.** The plan §3 picks `sp500-2010-2026.sexp` (survivor-aware,
510 names) over a delisted-aware composition cell, citing #1180/#1191's
finding that "strategy mechanics are universe-invariant". The empirical
evidence in `dev/notes/random-universe-sweep-v2-p6-2026-05-18.md` supports
this for trade-count / win-rate / holding-days (Win rate σ ≈ 2.7pp across 5
random draws — "strategy-mechanic invariant"), but NOT for Sharpe (σ ≈ 0.23,
range [0.27, 0.88]). Since the plan's gate 3 sets a per-fold Sharpe ≥ 0.50
floor (§6) — itself larger than the random-universe Sharpe variability —
the rationale "relative ranking of param sets is robust" holds for the
optimization step but does NOT carry through to the gate-3 hard floor. A
sweep winner that passes all gates on the survivor-biased universe may
fail gate 3 if run on a less-favorable universe. The plan §10 explicitly
defers "universe tuning" so this is a known scope limitation, not a hidden
problem. Suggest adding one sentence to §6 acknowledging that the Sharpe ≥
0.50 floor is calibrated against the survivor-biased benchmark and a
followup OOS run on a delisted-aware cell would be needed before live
promotion — but this is a soft observation, not a FAIL.

### Concern 3 — Composite objective weights + parser support

**PASS (semantics) / FAIL (sexp syntax).**

- The `Bayesian_runner_spec.Composite of (metric_type * float) list` parser
  (`bayesian_runner_spec.mli` line 20-22) accepts negative weights at parse
  time. The lib-side `Grid_search.objective` docstring
  (`tuner/lib/grid_search.mli`) explicitly says: *"a negative weight
  effectively converts a metric to a minimization target (e.g. 'minimize
  drawdown' becomes [(MaxDrawdown, -1.0)])"*. The test
  `test_grid_search.ml` line 148 evaluates a composite with
  `(Metric_types.MaxDrawdown, -0.1)` and asserts the expected scalar score —
  negative-weight support is test-pinned. ✓

- **FAIL: The §4 sexp example uses wrong constructor names.** Plan §4 writes
  `(sharpe_ratio 0.40) (calmar_ratio 0.30) (cvar95 -0.20)
  (max_drawdown_pct -0.10)`. The actual `Metric_types.metric_type`
  constructors (`trading/trading/simulation/lib/types/metric_types.mli`) are
  **`SharpeRatio`, `CalmarRatio`, `CVaR95`, `MaxDrawdown`** — PascalCase,
  no `_pct` suffix on the drawdown variant. The test fixture in
  `test_bayesian_runner_bin.ml` line 104 shows the canonical sexp form:
  `(objective (Composite ((SharpeRatio 1.0) (CalmarRatio 0.5))))`. As
  written, the plan's sexp **will not parse**. The "secondary metrics" line
  146-148 has the same issue (`sortino_ratio_annualized` →
  `SortinoRatioAnnualized`; `ulcer_index` → `UlcerIndex`;
  `force_liquidations_count` does not exist as a metric_type variant at all
  — closest match would be a custom log, not a metric). Required fix:
  rewrite §4 example sexp with the actual PascalCase constructors, or add
  a note that the snake_case names in §4 are conceptual and the spec.sexp
  authored in Phase A will use the PascalCase variants.

### Concern 4 — Promote gates vs composite objective consistency

**FLAG (intentional asymmetry, but should be documented).**

The composite objective `0.40·SR + 0.30·CR − 0.20·CVaR95 − 0.10·MaxDD`
finds the median-fold argmax over the BO surface. Gate 3 then imposes a
per-fold HARD floor `Sharpe ≥ 0.50` — orthogonal to the composite. A config
with median composite at +0.10 over Cell-E but Sharpe 0.45 on fold 2
(barely below the floor) gets rejected by gate 3 even though the composite
optimizer ranks it the global winner. The plan §6 last paragraph addresses
"only 1-2 gates clear" but is silent on "composite winner trips ONE hard
floor". This is the standard "constrained optimization via post-hoc
filtering" pattern — defensible but underspecified. Two acceptable
resolutions:
1. **Document the asymmetry**: add one bullet saying "the composite is
   unconstrained; gates 3 and 4 are hard floors enforced on the winner
   independent of objective" so the operator knows that gate-3 fail = no
   promote, period.
2. **Encode the floor in the objective**: add a large negative penalty to
   the composite for `min_fold(Sharpe) < 0.50` (or similar) so the BO
   surface itself avoids those regions.

Option 1 is the smaller change and consistent with the rest of the plan.
This is a FLAG, not a FAIL.

### Concern 5 — Budget realism

**FLAG (estimate optimistic).** Plan §5 estimates "5 folds × 16y per eval
× ~10 min wall on the sp500-2010-2026 cell ≈ 50 min per eval". The arithmetic
treats every fold as a full 16y backtest, but the walk-forward folds are
expanding-window with varying spans:
- Fold 1: 10 fold-years (train 2010–2017 + OOS 2018–2019)
- Fold 5: ~16.3 fold-years (train 2010–2025 + OOS 2026 partial)
- Cumulative across 5 folds: ~68 fold-years per BO eval.

At the empirical rate from `dev/notes/overnight-2026-05-10-results.md`
("28 min for 2 × 15y" → ~14 min per 15y → ~0.93 min per fold-year), one
BO eval ≈ 63 min — about 25% higher than the 50-min headline. 120 evals
× 63 min = 126 hr serial, ~32 hr at parallel=4. Phase 3 plan
`bayesian-multi-param-scaling-2026-05-16.md` line 392-395 estimates
"~20-40s per fold" — but that's for 1-year fold windows; the longer
train spans in this plan compound the wall time. Budget is realistic at
the "next session, ~24-30 hr wall" framing but the §5 derivation arithmetic
should acknowledge the expanding-window structure rather than the flat
"5 × 16y" shortcut. This is a FLAG (estimate refinement), not a FAIL —
the budget envelope is still within the proposed 24-30 hr.

## Quality Score

3 — Plan documents the design intent clearly and cross-references the right authority documents, but contains one hard bug (sweeping the deprecated `min_cash_pct` knob will waste BO budget on a phantom dimension), one parser-incompatible sexp example (lowercase metric constructors that won't load), and a few smaller knob-path / Cell-E-vocabulary issues that need to be fixed before Phase A authors the spec sexp.

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### Plan §2 (Axis A): `min_cash_pct` is a deprecated/unwired knob
- Finding: Plan §2 includes `portfolio_config.min_cash_pct ∈ [0.10, 0.40]` as one of 8 production-sweep knobs, but the field is documented as deprecated and never threaded into the entry-walk's cash check. The strategy ignores its value. Sweeping it wastes ~12% of the BO budget on a phantom dimension.
- Location: `dev/plans/bayesian-production-sweep-2026-05-18.md` line 62 (Axis A table row 3); `trading/trading/weinstein/portfolio_risk/lib/portfolio_risk.mli` lines 156–162 (deprecation docstring); `dev/notes/tunable-parameters-inventory-2026-05-18.md` line 143 ("DEPRECATED — sexp compat only"); `dev/notes/next-session-priorities-2026-05-05.md` line 50 ("zero production callers").
- Authority: portfolio_risk.mli lines 159–162: *"Deprecated as of 2026-05-01: never wired into the entry walk's `check_cash_and_deduct`. … Field retained for sexp compat."*
- Required fix: Remove `min_cash_pct` from §2. Either drop Axis A to 2 knobs (7-D total surface) or substitute a real cash-discipline knob — e.g. `portfolio_config.force_liquidation.min_portfolio_value_fraction_of_peak` (currently default 0.40, untuned per inventory line 159) or `risk_per_trade_pct` (currently default 0.01, untuned per inventory line 138).
- harness_gap: ONGOING_REVIEW — detecting "knob is in spec but field is deprecated/unwired" requires reading the field's docstring + cross-referencing the inventory; not a deterministic linter case.

### Plan §4: Composite sexp uses wrong metric constructor names
- Finding: §4 writes `(sharpe_ratio 0.40) (calmar_ratio 0.30) (cvar95 -0.20) (max_drawdown_pct -0.10)`. The `metric_type` constructors are `SharpeRatio`, `CalmarRatio`, `CVaR95`, `MaxDrawdown` (PascalCase, no `_pct` suffix on drawdown). The sexp as written will not load via `Bayesian_runner_spec.load`.
- Location: `dev/plans/bayesian-production-sweep-2026-05-18.md` lines 131-137 (objective sexp block) and 146-148 (secondary metrics list — same casing issue: `sortino_ratio_annualized` should be `SortinoRatioAnnualized`, `ulcer_index` → `UlcerIndex`; `force_liquidations_count` has no metric_type variant at all).
- Authority: `trading/trading/simulation/lib/types/metric_types.mli` (constructor declarations); `trading/trading/backtest/tuner/bin/test/test_bayesian_runner_bin.ml` line 104 (canonical sexp form: `(Composite ((SharpeRatio 1.0) (CalmarRatio 0.5)))`).
- Required fix: Rewrite the §4 sexp using PascalCase constructors, OR add an explicit note that §4 uses conceptual names and the Phase-A-authored spec sexp will translate them to PascalCase metric_type constructors. Verify each name exists in `metric_types.mli` before authoring.
- harness_gap: LINTER_CANDIDATE — a doc-lint that scans plan markdown for `(Composite ((...))) ` sexp examples and validates the metric_type constructor names against `metric_types.mli` would catch this deterministically.

### Plan §2 (Axis B / §2 Axis C): Knob paths need full sexp-key prefix
- Finding: §2 lists `installed_stop_min_pct` as a bare field name, but it actually lives at `screening_config.candidate_params.installed_stop_min_pct` (Screener.candidate_params, not a top-level field on Weinstein_strategy_config). The BO evaluator's override-merge needs the full key path to thread the value. Without it the spec.sexp's `(bounds (("installed_stop_min_pct" (0.04 0.15))))` will either no-op or fail to merge.
- Location: `dev/plans/bayesian-production-sweep-2026-05-18.md` line 69 (Axis B row 2).
- Authority: `trading/analysis/weinstein/screener/lib/screener.mli` lines 42–61 (field declaration under `candidate_params`); `weinstein_strategy_config.mli` line 17 (`screening_config : Screener.config`).
- Required fix: §2 should list the full sexp key path for each knob to make the spec authoring unambiguous: `screening_config.candidate_params.installed_stop_min_pct`, `portfolio_config.max_position_pct_long`, `portfolio_config.max_long_exposure_pct`, `stage3_force_exit_config.hysteresis_weeks`, `laggard_rotation_config.hysteresis_weeks`. The bare names `initial_stop_buffer` and `stage3_reentry_cooldown_weeks` are top-level on the config and remain unambiguous as-is.
- harness_gap: ONGOING_REVIEW — requires walking the config record type to find the field's owning module; not trivially linterizable until a "list all sweepable knobs as sexp keys" CLI is built.

### Plan §2: "Cell-E default" column is empirical winners, not canonical defaults
- Finding: §2 tables list 0.14 / 0.70 / 0.30 as "Default (Cell-E)" for the three Axis-A sizing knobs. The canonical `Portfolio_risk.default_config` sets these to 0.30 / 0.90 / 0.10. Cell-E baseline scenario sexp (`cell-E-stage3-k1-laggard-h2.sexp`) overlays only stage3/laggard flags; sizing fields fall through to defaults. 0.14/0.70/0.30 are the EMPIRICAL WINNERS from `dev/notes/overnight-2026-05-10-results.md`, not Cell-E baseline. The column name conflates the gate-1 baseline reference (§6 "≥ Cell-E + 0.05") with the centre-of-bounds prior.
- Location: `dev/plans/bayesian-production-sweep-2026-05-18.md` lines 58-62 (Axis A table column "Default (Cell-E)").
- Authority: `trading/trading/weinstein/portfolio_risk/lib/portfolio_risk.ml` lines 68–84 (`default_config`); `dev/experiments/capital-recycling-combined-2026-05-07/scenarios/cell-E-stage3-k1-laggard-h2.sexp` (Cell-E baseline scenario).
- Required fix: Rename the column to "Centre of bounds (best-known from overnight 2026-05-10)" or split into two columns: "Cell-E baseline" (canonical defaults) and "Empirical best-known prior". Then make explicit which one the §6 gate-1 "baseline Cell-E" composite is computed against — this matters because the +0.05 threshold has different meaning depending on which reference point is used.
- harness_gap: ONGOING_REVIEW — naming-vs-semantics issue, not a deterministic check.

---

# Behavioral QC re-review — docs-bayesian-production-sweep-plan
Date: 2026-05-18
Reviewer: qc-behavioral
Reviewed SHA: a95f0b00

## Status of prior 4 findings

| # | Prior finding | Status at a95f0b00 |
|---|---------------|---------------------|
| 1 | `min_cash_pct` deprecated (waste of BO budget) | **RESOLVED.** §2 now lists 7 params; line 70-72 explicitly notes `min_cash_pct` removed per `portfolio_risk.mli` lines 159-162 with the deprecation rationale quoted. Axis A is now 2 params (max_position_pct_long, max_long_exposure_pct). §1 → §6 prose acknowledges the change in the §2 preamble. |
| 2 | §4 Composite snake_case metric names + `force_liquidations_count` | **RESOLVED.** §4 lines 142-147 now uses PascalCase: `(SharpeRatio 0.40) (CalmarRatio 0.30) (CVaR95 -0.20) (MaxDrawdown -0.10)`. This matches the canonical fixture at `test_bayesian_runner_bin.ml:104`. Secondary metrics list lines 161-162 also PascalCase. Line 162-164 explicitly notes `force_liquidations_count` is NOT a metric_type variant + redirects to per-fold actual.sexp for analysis. |
| 3 | §2 knob paths missing sexp-key prefix | **RESOLVED.** §2 now writes full sexp paths in every row: `portfolio_config.max_position_pct_long`, `portfolio_config.max_long_exposure_pct`, `screening_config.candidate_params.installed_stop_min_pct`, `stage3_force_exit_config.hysteresis_weeks`, `laggard_rotation_config.hysteresis_weeks`, `stage3_reentry_cooldown_weeks`. `initial_stop_buffer` correctly listed without prefix (top-level field on `Weinstein_strategy_config.config` per .mli line 19). All paths cross-checked against the relevant .mli files. ✓ |
| 4 | §2 "Cell-E default" column conflated baseline (0.30/0.90) with empirical winners (0.14/0.70) | **PARTIALLY RESOLVED.** §2 now has separate "Canonical default" and "Cell-E baseline" columns. Axis A canonical column correctly shows 0.30/0.90 (per `Portfolio_risk.default_config` portfolio_risk.ml:68-84). §6 lines 211-220 adds an explicit Cell-E baseline reference table with the 0.14/0.70/h1/h2 config + TBD-must-measure callouts for composite numbers. §7 Phase A step 0 adds a pre-sweep step to establish baseline numbers. However, the Axis B and Axis C canonical-default values contain new errors (see Finding R2 below). |

## Contract Pinning Checklist (re-review)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test | NA | No new `.mli` — pure planning doc. |
| CP2 | Each claim in PR body Test plan / Test coverage has corresponding test | PASS | PR body's "Test plan" remains "no code change — pure docs PR" + cross-ref + 2 reviewer-decision checkboxes. No misleading test claims. (Note: PR body summary still references "8 params" and "~25 hr" — see Finding R3.) |
| CP3 | Pass-through tests pin identity | NA | No tests in this PR. |
| CP4 | Each docstring guard has a test exercising the guarded scenario | NA | No new code/docstrings. |

## Behavioral Checklist (Weinstein-domain rows)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| (all S/L/C/T rows) | Stage / stops / cascade / test rows | NA | Pure planning doc; no Weinstein domain logic implemented. |

## New findings introduced by the edits

### Finding R1 — Axis C "Canonical default" column has wrong values for 2 of 3 rows
- Finding: Plan §2 Axis C lists "Canonical" = 0 for all three rows. The actual canonical defaults per the authority docs are:
  - `stage3_force_exit_config.hysteresis_weeks`: **2** (per `Stage3_force_exit.default_config`, `stage3_force_exit.mli` line 59: *"Defaults: [{ hysteresis_weeks = 2 }]"*; inventory line 203: "Default `2`")
  - `laggard_rotation_config.hysteresis_weeks`: **4** (per `Laggard_rotation` mli line 51: "Default 4"; inventory line 195: "Default `4`")
  - `stage3_reentry_cooldown_weeks`: 0 ✓ (matches inventory line 28)
- This is the same finding-class as the original Finding #4 (canonical-default vs empirical-baseline conflation), reintroduced in a new table column. The §2 preamble lines 58-61 explicitly promised: *"Two 'default' columns distinguish the canonical Weinstein-config default (`Portfolio_risk.default_config` etc.) from the empirical Cell-E baseline."* — but the canonical column for Axis C does not match `Stage3_force_exit.default_config` or `Laggard_rotation.default_config`.
- Location: `dev/plans/bayesian-production-sweep-2026-05-18.md` lines 83-87 (Axis C table).
- Authority: `trading/analysis/weinstein/stage3_force_exit/lib/stage3_force_exit.mli` line 59 (`hysteresis_weeks = 2`); `trading/analysis/weinstein/laggard_rotation/lib/laggard_rotation.mli` lines 49-59 (`hysteresis_weeks` default 4); `dev/notes/tunable-parameters-inventory-2026-05-18.md` lines 195, 203.
- Required fix: Update Axis C "Canonical" column values to: `stage3_force_exit_config.hysteresis_weeks = 2`, `laggard_rotation_config.hysteresis_weeks = 4`, `stage3_reentry_cooldown_weeks = 0`. The Cell-E column (1, 2, 0) stays as-is — Cell-E does overlay these via `cell-E-stage3-k1-laggard-h2` scenario sexp.
- harness_gap: LINTER_CANDIDATE — a doc-lint that cross-references default values in plan tables against the `*_default_config` bindings in the relevant `.ml` files would catch this deterministically.

### Finding R2 — Axis B "Canonical default" column for `installed_stop_min_pct` is wrong
- Finding: Plan §2 Axis B lists `screening_config.candidate_params.installed_stop_min_pct` with Canonical=0.08, Cell-E=0.08. The actual canonical default is **0.0** (per `Screener.default_candidate_params` at `screener.ml:32`: `installed_stop_min_pct = 0.0`; and `screener.ml:12`: `installed_stop_min_pct : float; [@sexp.default 0.0]`; and inventory line 85: "Default `0.0`"). 0.08 is the m5-5 axis-1-winner empirical value that has become the de facto Cell-E baseline. The column is mis-labeled — 0.08 belongs only in the Cell-E column, not in Canonical.
- This is the same Finding-#4-class error: a battle-tested empirical winner is being labeled as the canonical default. Risk: a reviewer interpreting the canonical column as "what the strategy ships with by default" will assume the trading system already applies an 8% installed-stop floor when in fact it ships with 0% floor.
- Location: `dev/plans/bayesian-production-sweep-2026-05-18.md` line 79 (Axis B row 2).
- Authority: `trading/analysis/weinstein/screener/lib/screener.ml` lines 12, 32 (`installed_stop_min_pct = 0.0`); `dev/notes/tunable-parameters-inventory-2026-05-18.md` line 85 ("Default `0.0`, Tuned: m5-5-installed-stop-min-pct-2026-05-13 — axis-1 winner").
- Required fix: Change Axis B `installed_stop_min_pct` Canonical column from 0.08 to 0.0. Keep Cell-E = 0.08.
- harness_gap: LINTER_CANDIDATE — same lint as R1.

### Finding R3 — §9 / §11 internal inconsistencies left over from the edits
- Finding: The §5/§6 revisions update the knob count (8→7) and wall budget (25hr → 24-48hr), but three downstream sections still carry the v1 numbers:
  1. §9 Risks table row 5 (line 294): *"8-D continuous + 3-D integer mix"* — should be **4-D continuous + 3-D integer = 7-D** per the §5 revision (line 184).
  2. §11 Acceptance gate 1 (line 312): *"The 8 parameters in §2 are confirmed reasonable"* — should be **7 parameters** (matches §2 line 52).
  3. §11 Acceptance gate 5 (line 320): *"The ~24-30 hr wall + 25 hr CPU budget at parallel=4 is acceptable"* — should reflect the new §5 estimate **24-48 hr wall** (line 182). The phrase "25 hr CPU budget at parallel=4" is also internally awkward — at parallel=4, the CPU-hour count and wall-hour count are not 1:1 (the v1 framing conflated them). Either drop the CPU-hour clause or restate as "~96-192 CPU-hours (24-48 hr wall at parallel=4)".
- Location: `dev/plans/bayesian-production-sweep-2026-05-18.md` lines 294, 312, 320.
- Authority: Internal consistency with §2 line 52 (7 params), §5 lines 181-186 (24-48 hr / 7-D).
- Required fix: Update §9 to "4-D continuous + 3-D integer mix"; §11 gate 1 to "7 parameters"; §11 gate 5 to match the §5 framing.
- harness_gap: ONGOING_REVIEW — cross-section consistency is hard to automate without a structured plan schema; this is a manual-review case.

### Observation (non-blocking) — PR body summary still carries v1 numbers
- The PR body summary still says "**Knob inventory** | 8 params" and "**Budget** | 120 evals, 20 random initial, EI acquisition, ~25 hr wall at parallel=4." This is a cosmetic mismatch with the (corrected) plan body — not a CP2 failure (the body's "Test plan" section has no test claims that aren't met), but the operator will hit conflicting numbers between the PR landing page and the doc. Suggest the author update the PR description as well; this is a soft observation, not a FAIL.

## Quality Score

3 — Prior 4 findings are substantively resolved (min_cash_pct dropped; PascalCase metric names; sexp-path prefixes added; baseline-vs-empirical column split). However, the new "Canonical default" column reintroduces the same Finding-#4-class error in 3 of the 7 rows (R1 + R2), and the §5/§6 budget/knob-count revisions left three downstream consistency bugs in §9 and §11 (R3). The plan is closer to mergeable but still has mechanical errors that will mislead the Phase-A spec author about what canonical-config baselines look like.

## Verdict

NEEDS_REWORK

## Summary for orchestrator

Three prior findings (min_cash_pct, PascalCase metrics, sexp-paths) are fully resolved. The fourth (Cell-E vs canonical conflation) is structurally resolved by splitting the column but reintroduces wrong values in 3 of 7 canonical-default cells. Three internal-consistency bugs from the §5/§6 rewrites remain in §9 and §11. None of the new findings are blocking for the design intent — they are mechanical-data corrections to make the plan internally consistent before Phase A authors the spec sexp.

