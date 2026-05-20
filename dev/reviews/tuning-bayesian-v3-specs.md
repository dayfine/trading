Reviewed SHA: 7ab49f4620af54e0f5923dbfce597c1dc60561c1

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | 37 tests, 37 passed, 0 failed |
| P1 | Functions ≤ 50 lines — covered by language-specific linter | NA | No code changes; sexp-data-only PR |
| P2 | No magic numbers — covered by language-specific linter | NA | No code changes; sexp-data-only PR |
| P3 | All configurable thresholds/periods/weights in config record | NA | No code changes; sexp-data-only PR |
| P4 | Public-symbol export hygiene | NA | No code changes; sexp-data-only PR |
| P5 | Internal helpers prefixed per project convention | NA | No code changes; sexp-data-only PR |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | NA | No code changes; sexp-data-only PR |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | NA | No core module changes; sexp specs only |
| A2 | No new `analysis/` imports into `trading/trading/` | NA | No code changes; sexp-data-only PR |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Only two new sexp files added; no existing files modified |

## Sexp Syntax Verification

Both spec files conform to `Bayesian_runner_spec.t`:

**spec_prod_v3.sexp (47 LOC):**
- bounds: 4 entries (portfolio position-sizing + stop placement axes) ✓
- acquisition: Expected_improvement ✓
- initial_random: 10, total_budget: 60, seed: (2026) ✓
- n_acquisition_candidates: () (None) ✓
- objective: Composite with 3 terms (SharpeRatio 0.40, CalmarRatio 0.30, MaxDrawdown -0.10) ✓
- scenarios: (), holdout_folds: (27 28 29 30) ✓

**spec_prod_v3_cadence.sexp (41 LOC):**
- Same bounds + acquisition + budget + seed as V3 ✓
- objective: Composite with 4 terms (V3's 3-term + AvgHoldingDays 0.10) ✓
- holdout_folds: (27 28 29 30) ✓

Both metrics used (SharpeRatio, CalmarRatio, MaxDrawdown, AvgHoldingDays) are valid per `metric_types.mli`. Sexp parser is exercised by existing `dune runtest` (Spec.load tests in test_bayesian_runner_bin.ml).

## Verdict

APPROVED

---

# Behavioral QC — tuning-bayesian-v3-specs
Date: 2026-05-21
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | FAIL | No .mli added (pure sexp data), but applying CP1 to the spec-file header docstrings (which serve as the "contract" for these tuning artifacts): the V3 spec header line 20-21 claims "Keep `max_position_pct_long` and `installed_stop_min_pct` bounds unchanged from V2 — V2 winners on these axes were near-baseline." This is FALSE against the on-disk shape. V2 had `max_position_pct_long (0.02 0.20)` / `installed_stop_min_pct (0.04 0.15)`; V3 has `(0.04 0.15)` / `(0.06 0.13)` — both TIGHTENED. The V3 bounds match the priorities-doc P0 spec (`dev/notes/next-session-priorities-2026-05-21-pm.md` §P0 lines 66-69), so the spec content is correct; only the prose claim is wrong. See NEEDS_REWORK item below. Other docstring claims (Composite 3-term formula, tightened exposure lower bound 0.30→0.45, tightened initial_stop_buffer upper bound 1.10→1.05, seed/budget/holdout unchanged for cross-version comparability, V3-cadence prerequisite of cell-E baseline regen) all PASS against the on-disk shape. |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | PASS | PR body Test plan: "Sexp format mirrors spec_prod_v2.sexp exactly (only bounds + objective differ). The Spec.t parser path already has full coverage in test_bayesian_runner_bin.ml (Composite objective tests + test_load_simple_spec_parses)." Verified: `test_load_simple_spec_parses` at trading/trading/backtest/tuner/bin/test/test_bayesian_runner_bin.ml:75; Composite objective parser at line 109 (`test_load_ucb_acquisition_and_composite_objective_parses`). The Composite parser test covers a 2-term positive-weight Composite — the parser is general (Metric_type * float pairs), and the V3-specific scoring of negative weights (MaxDrawdown -0.10) + AvgHoldingDays is pinned by test 23 (line 805) + test 24 (line 843, exact 4-term Composite production formula) in test_bayesian_runner_scoring.ml. Sexp-format-mirrors-V2 claim verified via direct diff of spec_prod_v2.sexp vs spec_prod_v3.sexp — only `(bounds ...)` and `(objective ...)` clauses differ; other fields byte-identical. The smoke-launch checkbox is correctly left unchecked (sequenced after PR #1224 merges per PR body §Sequencing). |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are [equal_to ...] or equal_to on entire value), not just size_is | NA | No pass-through semantics — these are tuning input artifacts, not transformation code. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | V3-cadence header lines 10-18 explicitly call out the NaN-poisoning guard: "PRE-REQUISITE: the cell-E baseline aggregate MUST be regenerated against the post-#1220 build... V1/V2 baseline aggregates predate #1220 and have `(avg_holding_days NaN)` in `variant_stability` — passing them through the AvgHoldingDays scoring term would NaN-poison every cell." This is an operational pre-launch step, not an in-code guard, so a test would not be the appropriate enforcement vector — the spec correctly names the directory (`v3-cell-e-baseline/`), the executor (`walk_forward_runner.exe`), and the verification step (verify avg_holding_days is finite). The infrastructure that makes this guard meaningful — AvgHoldingDays carrying through to scoring — is itself test-covered (test_bayesian_runner_scoring.ml test 23 line 805+ exercises the AvgHoldingDays scoring branch end-to-end). |

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1–T4 | Weinstein-domain rows | NA | Pure tuning-spec data PR; no domain logic. Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely". |

## Quality Score

3 — Spec content correctly implements priorities-doc §P0 (V3 baseline) and §P1 (V3 cadence sequencing). All four bounds match the authority spec exactly, the 3-term Composite mirrors the scoring.mli "production sweep formula" docstring (line 42), and the V3-cadence prerequisite is operationally crisp. One docstring inaccuracy: V3 header line 20-21 claims `max_position_pct_long` and `installed_stop_min_pct` bounds are "unchanged from V2" when both were tightened (0.02→0.04, 0.20→0.15 and 0.04→0.06, 0.15→0.13). The actual numbers match the priorities doc, so the launch will use the right bounds — but the prose explanation is misleading and a future reader diffing V2 vs V3 will be confused.

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### CP1: Misleading docstring claim — "unchanged from V2" bounds are actually tightened
- Finding: V3 spec header lines 20-21 say `Keep max_position_pct_long and installed_stop_min_pct bounds unchanged from V2 — V2 winners on these axes were near-baseline.` But the on-disk V3 bounds DIFFER from V2 on both axes:
  - `max_position_pct_long`: V2 `(0.02 0.20)` → V3 `(0.04 0.15)` (tightened both bounds)
  - `installed_stop_min_pct`: V2 `(0.04 0.15)` → V3 `(0.06 0.13)` (tightened both bounds)
- Location: `dev/experiments/bayesian-production-sweep-2026-05-18/spec_prod_v3.sexp` lines 20-21 (and by extension the V3-cadence spec's "Same bounds ... as V3 baseline" line 21 which is correct relative to V3 but inherits the inaccuracy if a reader walks V2→V3 transitively)
- Authority: `dev/notes/next-session-priorities-2026-05-21-pm.md` §P0 lines 66-69 specifies V3 bounds as `(0.04 0.15)` for max_position_pct_long and `(0.06 0.13)` for installed_stop_min_pct. The spec correctly implements these — the inaccuracy is only in the prose explaining the diff from V2. Cross-check: V1 spec had `max_position_pct_long (0.05 0.20)` and `installed_stop_min_pct (0.04 0.15)` — V3 doesn't match V1 either. The "unchanged" claim is wrong against every prior baseline.
- Required fix: Update V3 spec header lines 20-21 to one of:
  - Option A (preferred): Replace with an accurate description, e.g. "Tighten `max_position_pct_long` to (0.04 0.15) and `installed_stop_min_pct` to (0.06 0.13) — V2's wider bounds at these axes did not move winners far from baseline, so the narrower bounds focus BO budget on the search regions priorities-doc §P0 calls out as productive."
  - Option B: If the author actually meant "unchanged from priorities-doc §P0 spec," restate it that way and reference the doc.
- harness_gap: ONGOING_REVIEW — verifying header-prose claims against on-disk parameter shape requires correlating two artifacts; a linter could in principle diff the spec header against parent specs but the cost/value trade-off (1 cleanup PR a quarter) is below the bar for a deterministic check. Leave to QC review.

