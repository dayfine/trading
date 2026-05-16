Reviewed SHA: fc6d6915

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No formatting errors |
| H2 | dune build | PASS | Full build succeeds |
| H3 | dune runtest | PASS | 9 tuner tests + 19 tuner/bin tests + 73 walk_forward tests all pass (OK) |
| P1 | Functions ≤ 50 lines (linter) | PASS | fn_length_linter passed as part of H3 |
| P2 | No magic numbers (linter) | PASS | magic_numbers linter passed as part of H3 |
| P3 | Config completeness | PASS | No new tunable values; only parsing sexp shape |
| P4 | Public-symbol export hygiene (linter) | PASS | mli_coverage linter passed as part of H3 |
| P5 | Internal helpers prefixed per convention | PASS | All helper functions in test use underscore prefix (_with_temp_dir, _spec_text, _write_spec_file, etc.) |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | PASS | No List.exists equal_to bool; no unasserted .run/.on_market_close; all assertions use assert_that with matchers. Test file has `open Matchers` and correctly applies all_of, field, elements_are, is_some_and, matching, size_is. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to core modules; only extends bayesian_runner_spec and walk_forward spec parsing |
| A2 | No new analysis imports into trading outside backtest exception | PASS | No analysis imports present in dune files; PR only modifies tuner/bin and walk_forward/lib under trading/trading/backtest |
| A3 | No unnecessary modifications to existing modules | PASS | File list (8 files) matches PR scope exactly — new test data + new tests + minor dune deps addition. No cross-feature drift. |

## Verdict

APPROVED

## Summary

PR-B successfully pins the Phase-3 Bayesian knob inventory shape:
- New `holdout_folds : int list option` field in bayesian_runner_spec with `[@sexp.option]` for optional parsing
- `[@@sexp.allow_extra_fields]` on walk_forward spec parser to tolerate new tag without breakage
- 11-knob production fixture (bayesian-multi-param-2026-05-16.sexp) with correctly encoded bounds and holdout fold list (27 28 29 30)
- 8 new test cases covering all holdout_folds parsing paths (present, empty, omitted) + round-trip + production fixture validation
- All hard gates pass; test patterns conform to project rules; no structural issues

---

# Behavioral QC — bayesian-phase3-pr-b
Date: 2026-05-16
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | (a) `bayesian_runner_spec.mli` docstring claim "omit [holdout_folds] for `None`; `(holdout_folds (k1..kn))` for `Some [k1;..;kn]`; `(holdout_folds ())` for `Some []`" → pinned by `test_holdout_folds_omitted_parses_to_none`, `test_holdout_folds_present_parses_to_some`, `test_holdout_folds_empty_list_parses_to_some_empty`. (b) `spec.mli` (walk_forward) docstring claim "underlying record allows extra sexp fields ... walk-forward runner itself ignores the list" → pinned by `test_30fold_spec_parses` (existing test now parses fixture containing new `(holdout_folds (27 28 29 30))` block; would FAIL without `[@@sexp.allow_extra_fields]`). |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | PASS | PR body claims: (1) "round-trip Some/None/Some[]" → tests `test_holdout_folds_round_trip_{none,some,some_empty}`; (2) "parsed-shape None/Some/Some[]" → tests `test_holdout_folds_{omitted_parses_to_none,present_parses_to_some,empty_list_parses_to_some_empty}`; (3) "production fixture parses" → `test_phase3_fixture_parses`; (4) "11-knob key list pinned" → `test_phase3_fixture_bounds_cover_expected_tracks`. All 8 advertised tests present in committed file. |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are [equal_to ...] or equal_to on entire value), not just size_is | PASS | Round-trip tests assert holdout_folds list contents via `elements_are [equal_to 27; equal_to 28; equal_to 29; equal_to 30]` (not just size_is). The 11-knob key list test (`test_phase3_fixture_bounds_cover_expected_tracks`) uses `elements_are` with full ordered key list, not size_is alone. The simpler `test_phase3_fixture_parses` does use `size_is 11` on bounds, but the same fixture is checked by the keys test, so total/order/identity are jointly pinned. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | (a) `[@sexp.option]` guard (claim: "absence parses as None, distinct from `(holdout_folds ())` parsing as `Some []`") — pinned by all three semantic distinction tests + their round-trip counterparts (6 tests total). (b) `[@@sexp.allow_extra_fields]` guard on walk_forward spec (claim: "spec files may carry metadata that the runner does not consume directly (e.g. a holdout_folds block)") — pinned by `test_30fold_spec_parses` since cell_e_30fold_2026_05_16.sexp now contains the new `holdout_folds` block. (c) Pre-existing guards from prior PRs (e.g. `Failure` on malformed spec, `unknown scenario path`) remain pinned by `test_load_malformed_raises` and `test_evaluator_unknown_scenario_raises`. |

## Behavioral Checklist

Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely": this is a pure data-foundation / tooling PR with no Weinstein domain logic (no stage classifier, no buy/sell signals, no stop-loss state machine, no screener cascade). The S*/L*/C*/T* rows are NA in their entirety. The PR only extends sexp parsing surfaces and ships a curated knob list. No core module (Portfolio/Orders/Position/Strategy/Engine) is touched; qc-structural's A1 row is PASS.

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural A1 = PASS; no core modules touched. |
| S1–S6 | Stage / buy criteria | NA | Pure tooling PR; no stage classifier or signal generation. |
| L1–L4 | Stop-loss rules | NA | No stop logic. |
| C1–C3 | Screener cascade | NA | No screener logic. |
| T1–T4 | Domain test coverage | NA | No domain behavior to test. |

## Authority cross-check — knob curation

Plan §2.1 enumerates 18 knobs across Tracks A(5)/B(4)/C(3)/D(3)/E(3); §5.2 prescribes reducing to 11 by dropping Track C entirely and trimming Tracks A/B/D/E to high-confidence subsets. PR-B fixture verified:

- Track A (4): `initial_stop_buffer`, `screening_config.candidate_params.{initial_stop_pct, installed_stop_min_pct, entry_buffer_pct}` — dropped `base_low_proxy_pct` (rated "plausible" only in §2.1).
- Track B (3): `portfolio_config.{max_position_pct_long, max_long_exposure_pct, risk_per_trade_pct}` — dropped `max_sector_concentration` (4th knob in §2.1).
- Track C (0): dropped entirely per §5.2.
- Track D (2): `stage3_force_exit_config.hysteresis_weeks`, `laggard_rotation_config.hysteresis_weeks` — dropped `laggard_rotation_config.rs_window_weeks` (3rd knob in §2.1).
- Track E (2): `screening_config.weights.w_positive_rs`, `screening_config.weights.w_strong_volume` — dropped `max_buy_candidates` (3rd knob in §2.1).

Total: 4+3+0+2+2 = **11**. Matches plan §5.2 directive. Bound ranges in fixture match §2.1 for Tracks A, B, D. Track E (weights) is encoded using the real config field names `w_positive_rs` / `w_strong_volume` (per `screener_scoring.ml:21,19`) with int-as-float ranges `(5.0 40.0)`; plan §2.1 used placeholder names `screening_config.weights.{rs,volume}` with float ranges `(0.05 0.50)` — those names don't exist in code. The fixture's correction-to-reality is acknowledged in PR body (Track E row) and is the correct grounding; the plan is the stale party here, not the fixture. Not a behavioral defect.

## Quality Score

4 — Tooling PR with comprehensive contract pinning: every docstring claim has a corresponding test, the `[@sexp.option]` semantic distinction (None vs Some []) is pinned with both parse-direction and round-trip-direction tests, the `[@@sexp.allow_extra_fields]` guarantee is implicitly exercised by the existing 30-fold parse test against the modified fixture, and the 11-knob production surface is pinned by exact ordered key list. Minor docs nit: PR body could have called out the Track E plan-to-code field-name reconciliation more prominently, but this is acknowledged within the body.

## Verdict

APPROVED
