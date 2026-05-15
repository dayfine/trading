Reviewed SHA: 34748942ecc1d54249d42597d384b6e6aa29651a

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No formatting errors; warnings only (missing dune-project) |
| H2 | dune build | PASS | Full build completes without errors |
| H3 | dune runtest | PASS | 43 tests pass; all walk_forward tests and matchers tests clean |
| P1 | Functions ≤ 50 lines — covered by language-specific linter | PASS | fn_length_linter clean as part of H3; all new functions pass |
| P2 | No magic numbers — covered by language-specific linter | PASS | linter_magic_numbers clean as part of H3 |
| P3 | All configurable thresholds/periods/weights in config record | PASS | No hardcoded numeric parameters; fold gate, window spec, and threshold params all properly defined |
| P4 | Public-symbol export hygiene — `.mli` coverage | PASS | mli_coverage linter clean; all four new library modules have complete `.mli` files |
| P5 | Internal helpers prefixed per project convention | PASS | Helper functions (_fr, _gate, _baseline_gate, _date, _make_base, _make_fold, _fa) correctly prefixed |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | PASS | All `equal_to true/false` violations eliminated via new `contains_substring` matcher (5 tests added to matchers suite). 17 substring assertions refactored: 12 in test_walk_forward_report.ml, 3 in test_walk_forward_runner.ml, 2 in test_fold_gate.ml. 4 bool assertions in test_fold_gate.ml (lines 21-26) replaced with `assert_bool` + semantic messages. grep `equal_to (true\|false)` returns no matches across all test files. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to core modules; pure addition under walk_forward/ and matchers/. matchers/ is library infrastructure, not a core domain module. |
| A2 | No new `analysis/` imports into `trading/trading/` outside backtest exception | PASS | No analysis/ imports in any dune file; only core, scenario_lib, backtest dependencies |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Rework limited to: (1) new `contains_substring` matcher in trading/base/matchers/{lib,test} — addresses library gap; (2) refactoring of walk_forward test files to use new matcher — addresses P6 finding. No existing module drift. |

## Verdict

APPROVED

## Rework note

Three commits (4d34950, c0f7fb0, 3474894) addressed the P6 finding:

1. **Matcher library addition** (4d34950): Added `contains_substring : ?msg:string -> string -> string matcher` to `trading/base/matchers/lib/matchers.{ml,mli}` with comprehensive docstring explaining the anti-pattern it replaces (`equal_to true` wrapping `String.is_substring`). Implementation is a direct assertion on `String.is_substring` result, failing with a clear message if the substring is not found.

2. **Test refactoring** (c0f7fb0, 3474894): Replaced 17 substring assertions in three walk_forward test files:
   - `test_walk_forward_report.ml`: 12 instances of `field (String.is_substring ...) (equal_to true)` → `contains_substring`
   - `test_walk_forward_runner.ml`: 3 instances
   - `test_fold_gate.ml`: 2 instances (lines 99, 122)
   - Additionally, 4 bool literal assertions in `test_fold_gate.ml` (lines 21-24, 25-26) replaced `equal_to true/false` with `assert_bool` + semantic messages (e.g., `assert_bool "Sharpe is higher-is-better" ...`)

3. **Matcher test coverage** (4d34950): Added 5 tests to `trading/base/matchers/test/test_matchers.ml` covering the new matcher:
   - Positive: substring present, exact match
   - Negative: substring absent
   - Edge cases: empty substring (passes), empty haystack (fails)

All P6 sub-rules now pass:
- Sub-rule 1: No `List.exists.*equal_to (true|false)` pattern found
- Sub-rule 2: No discarded results (`let _ = ...on_market_close` / `let _ = ....run`)
- Sub-rule 3: Test files with `open Matchers` no longer contain bare match statements with unasserted branches; all matches are pattern-matched with assertions or explicit failures

**Verification**: `grep -n "equal_to\s*true\|equal_to\s*false"` across all walk_forward and matchers test files returns zero matches.

---

# Behavioral QC — walk-forward-cv-harness
Date: 2026-05-15
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | See claim→test pairings below. Every public function and documented invariant in the four `walk_forward/lib/*.mli` files and the new `matchers.mli` `contains_substring` is pinned by at least one test. |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | PASS | PR body Test plan items are all operational (build/runtest/fmt/--help smoke). "43/43 pass" matches actual test count (11 window_spec + 13 fold_gate + 9 runner + 10 report = 43). `--help` flag is binary-level and exercised by the PR's manual smoke check, not by a unit test — acceptable per plan §"Out of scope" (on-corpus correctness deferred). |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are [equal_to ...] or equal_to on entire value), not just size_is | PASS | `test_overrides_appended_last` uses `elements_are [ equal_to base_ov; equal_to variant_ov ]` — pins both contents and order. `test_build_all_cross_product` uses `elements_are` with all 6 names. `test_render_is_deterministic` asserts `equal_to md2` on the full string. `test_universe_and_strategy_preserved` pins exact preserved values via `field`+`equal_to`. `test_train_days_zero_yields_no_train_period` uses `elements_are` with field-level identity assertions across all 6 generated folds. The two `size_is` usages (`test_start_after_end_yields_empty`, `test_no_fold_fits_yields_empty`, `test_build_all_empty_variants_yields_empty`, `test_drops_folds_past_end_date`) are emptiness/cardinality checks, not pass-through claims, so size-only is correct semantics. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | All 9 documented guards have corresponding raises tests: (1) `train_days < 0` → `test_negative_train_days_raises`; (2) `test_days <= 0` → `test_zero_test_days_raises`; (3) `step_days <= 0` → `test_zero_step_days_raises`; (4) `n < 1` → `test_n_zero_raises`; (5) `0 <= m <= n` → `test_m_out_of_range_raises`; (6) `worst_delta >= 0.0` → `test_negative_delta_raises`; (7) fold-count mismatch → `test_fold_count_mismatch_raises`; (8) empty fold_actuals → `test_empty_folds_raises`; (9) baseline_label not in variants → `test_baseline_not_present_raises`. The exact-boundary `>` semantics on `worst_delta` is additionally pinned by `test_exact_delta_boundary_passes`. |

### Claim → Test pairings (CP1 detail)

**`window_spec.mli`** (10 claims):
- "first fold train: start..start+train_days-1; test: start+train_days..+test_days-1" → `test_train_followed_by_test`
- "anchor advances by step_days" → `test_overlapping_step_yields_overlapping_test_windows`
- "fold dropped if test_period ends after end_date" → `test_drops_folds_past_end_date`
- "start_date > end_date → empty" → `test_start_after_end_yields_empty`
- "no fold fits → empty" → `test_no_fold_fits_yields_empty`
- "train_days = 0 → train_period = None" → `test_train_days_zero_yields_no_train_period`
- "name shape fold-NNN, zero-padded width 3" → `test_fold_names_zero_padded`
- 3 raises guards → 3 dedicated tests (covered in CP4)
- sexp round-trip → `test_sexp_round_trip`

**`fold_gate.mli`** (10 claims):
- "Pass iff wins ≥ M AND no fold trails by > Δ" → `test_full_pass_5_of_5` + `test_m_threshold_miss` + `test_delta_threshold_miss`
- "ties count as baseline win (strict beat)" → `test_tie_counts_as_baseline_win`
- "MaxDrawdownPct inverts direction" → `test_drawdown_inverted_direction` (pass case) + `test_drawdown_inverted_delta_miss` (fail case)
- "Fail diagnostic surfaces worst_fold / worst_gap" → `test_delta_threshold_miss` asserts `worst_fold = "fold-004"`, `worst_gap = 0.5`
- "Δ uses strict `>` not `>=`" → `test_exact_delta_boundary_passes`
- "higher_is_better classification" → `test_higher_is_better`
- 4 raises guards → 4 dedicated tests (covered in CP4)
- sexp round-trip → `test_gate_sexp_round_trip`

**`walk_forward_runner.mli`** (8 claims):
- "name = base.name-variant.label-fold.name" → `test_name_composes_base_variant_fold`
- "period = fold.test_period" → `test_period_is_test_period_of_fold`
- "config_overrides = base @ variant (variant appended last)" → `test_overrides_appended_last` (CP3-quality identity assertion)
- "description prefixed with fold + variant labels" → `test_description_marks_fold_and_variant`
- "universe_path + strategy preserved" → `test_universe_and_strategy_preserved`
- "slippage_bps preserved" → `test_slippage_bps_preserved`
- "build_all ordering: outer=variants, inner=folds" → `test_build_all_cross_product`
- "empty variants → empty result" → `test_build_all_empty_variants_yields_empty`
- variant sexp round-trip → `test_variant_sexp_round_trip`

**`walk_forward_report.mli`** (6 claims):
- "four sections: per-fold, stability, sensitivity, verdict" → `test_render_contains_all_four_section_headers`
- "deterministic — same inputs yield byte-identical output" → `test_render_is_deterministic`
- "verdict block pairs each non-baseline variant against baseline" → `test_render_contains_pass_when_variant_wins` + `test_render_contains_fail_when_m_threshold_missed`
- "per-fold table formats metrics" → `test_per_fold_table_renders_decimal_metrics`
- "stability uses μ ± σ" → `test_stability_row_shows_mean_and_stdev`
- "sensitivity table shows win-count per variant" → `test_sensitivity_row_per_variant` (pins `"| cellE | 3 | 3 |"`)
- 2 raises guards → 2 dedicated tests (covered in CP4)
- fold_actual sexp round-trip → `test_fold_actual_sexp_round_trip`

**`matchers.mli` `contains_substring`** (5 edge cases, all pinned):
- positive substring present → `test_contains_substring_passes`
- substring absent → `test_contains_substring_fails_when_absent`
- empty substring → `test_contains_substring_empty_substring_passes`
- empty haystack → `test_contains_substring_empty_haystack_fails`
- substring = haystack → `test_contains_substring_equal_strings_passes`

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | Pure infra / harness PR; domain checklist not applicable. |
| S1–S6 | Stage definitions / buy criteria | NA | Pure infra / harness PR; domain checklist not applicable. |
| L1–L4 | Stop-loss rules / state machine | NA | Pure infra / harness PR; domain checklist not applicable. |
| C1–C3 | Screener cascade / macro gate / sector RS | NA | Pure infra / harness PR; domain checklist not applicable. |
| T1–T4 | Domain-outcome assertions / scenario coverage | NA | Pure infra / harness PR; domain checklist not applicable. |

## Quality Score

5 — Reference-quality contract pinning: every documented claim in all four `.mli` files plus the new `contains_substring` matcher has an explicit test, every documented guard has a corresponding raises test (matching error-message substrings), identity-level invariants are pinned via `elements_are`/`equal_to` rather than `size_is`, the strict-inequality (`>`) boundary on `worst_delta` is explicitly pinned, the MaxDrawdownPct direction inversion is pinned in both directions (pass + Δ-miss), determinism is pinned via byte-identical equality, and the variant-overrides-appended-last semantics is pinned with the exact two-element list.

## Verdict

APPROVED
