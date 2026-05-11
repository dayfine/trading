Reviewed SHA: 1f6901013f933553c9f82f997bd9fe20472665f9

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No formatting issues |
| H2 | dune build | PASS | All modules build cleanly |
| H3 | dune runtest | PASS | 44 tests passed (25 factor_model + 19 synth_v3); all linters passed |
| P1 | Functions ≤ 50 lines — covered by language-specific linter | PASS | Longest function is generate_symbol_returns at 15 lines; fn_length_linter confirmed "OK: no functions exceed 50 lines" |
| P2 | No magic numbers — covered by language-specific linter | PASS | All numeric literals are config defaults or named constants (e.g. _max_truncation_retries, _beta_seed_offset); magic_numbers linter confirmed "OK: no magic numbers found in lib/ files" |
| P3 | All configurable thresholds/periods/weights in config record | PASS | Default distributions (loading_distribution, idio_distribution) are exposed as configurable record types in default_loading_distribution and default_idio_distribution; seed cascade offsets are named constants; no hardcoded algorithm parameters |
| P4 | Public-symbol export hygiene — covered by language-specific linter | PASS | All lib/*.ml files have corresponding .mli files; mli_coverage linter confirmed "OK: all lib/*.ml files have a corresponding .mli" |
| P5 | Internal helpers prefixed per project convention | PASS | All internal functions prefixed with underscore (e.g. _normal_sample, _sample_truncated_normal, _build_bar, _seed_for_betas, _generate_symbol) |
| P6 | Tests conform to `.claude/rules/test-patterns.md` (presence + conformance) | PASS | Both test files open Matchers and use assert_that exclusively with proper matcher composition (all_of, field, elements_are, is_ok_and_holds, equal_to, size_is, gt, is_between). Sub-rule 1: no `List.exists.*equal_to(true\|false)`. Sub-rule 2: no discarded Results (let _ = ...). Sub-rule 3: pattern matches either unwrap safely via _unwrap_or_fail helper or extract data without Result/Option. 44 tests total, all following declarative matcher style |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) — FLAG if any found | PASS | No modifications to core modules; feature is strictly additive to analysis/data/synthetic/ |
| A2 | No new `analysis/` imports into `trading/trading/` outside the established backtest exception surface | PASS | synthetic library in analysis/data/synthetic/ imports only core, core_unix.sys_unix, csv, status (base/status), types (analysis/data/types). No trading/trading/ imports. Zero cross-layer boundary violations |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | PR file list verified against git diff: 12 files, all within synth-v3 scope (dev/plans, dev/status, trading/analysis/data/synthetic/lib, trading/analysis/data/synthetic/bin, trading/analysis/data/synthetic/test). No unrelated module modifications |

## Verdict

APPROVED

---

# Behavioral QC — synth-v3-multi-symbol-factor
Date: 2026-05-11
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | factor_model.mli: `default_loading_distribution` validates → `test_default_loading_distribution_validates`; `validate_loading_distribution` rejects stddev<=0 / inverted range / out-of-range mean → `test_loading_distribution_rejects_{zero_stddev,inverted_range,out_of_range_mean}`; `default_idio_distribution` validates → `test_default_idio_distribution_validates`; `validate_idio_distribution` rejects non-stationary / zero omega → `test_idio_distribution_rejects_{non_stationary,zero_omega}`; `sample_betas` empty when n<=0 → `test_sample_betas_zero_n`; deterministic given seed → `test_sample_betas_deterministic` + `_different_seeds_differ`; raises on invalid dist → `test_sample_betas_invalid_distribution_raises`; truncation [min_value, max_value] → `test_sample_betas_in_range`; `sample_idio_params` per-symbol omega varies, alpha/beta shared → `test_sample_idio_params_omegas_vary` + `_zero_sigma_collapses`; deterministic → `test_sample_idio_params_deterministic`; raises on invalid → `test_sample_idio_params_invalid_raises`; `generate_symbol_returns` empty on empty market → `test_generate_symbol_returns_empty_market`; length=market length → `test_generate_symbol_returns_length`; deterministic → `test_generate_symbol_returns_deterministic`. synth_v3.mli: `default_symbol_names` 4-digit padded → `test_default_symbol_names_padded`; empty for n<=0 → `test_default_symbol_names_zero`; calendar alignment "all symbols share the same date sequence" → `test_all_symbols_share_dates`; seed cascade determinism → `test_determinism_{same_seed,different_seed_differs}` + `test_different_symbols_differ`; all six `generate` error paths (n_symbols<=0, start_price<=0, symbol list length mismatch, bad loading dist, bad idio dist, bad market) → `test_validation_{zero_n_symbols,zero_start_price,symbol_list_mismatch,bad_loading_dist,bad_idio_dist,bad_market_propagates}`. |
| CP2 | Each claim in PR body "Test plan" sections has a corresponding test in the committed test file | PASS | "25 unit tests" → `grep -c '>::' test_factor_model.ml` = 26 entries (25 tests + 1 suite header) ✓. "19 tests" → `grep -c '>::' test_synth_v3.ml` = 20 entries (19 tests + 1 suite header) ✓. "validation, sampling determinism, range/empirical-mean tracking" → all present (validation cluster, `_deterministic` tests, `_in_range`, `_empirical_mean_near_target`). "β=0 strips market" → `test_generate_symbol_returns_beta_zero_strips_market`. "β=1 reproduces market" → `test_generate_symbol_returns_beta_one_reproduces_market`. "Load-bearing cross-sectional acceptance test (50 sym × 5000 bars, avg pairwise corr in [0.3, 0.7], target ~0.5)" → `test_cross_sectional_correlation` uses exactly `n_symbols=50, target=5_000, is_between low:0.3 high:0.7` ✓. CLI smoke is documented as a one-off claim (not a test-file requirement). |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size_is | PASS | Numerical invariants are pinned with specific bands: cross-sectional correlation → `is_between low:0.3 high:0.7`; β empirical mean → `is_between low:0.9 high:1.1`; β=0 strips market → `max_abs < 1e-4`; β=1 reproduces market → elementwise `abs(r-m) < 1e-5` per `for_all2_exn` ✓; omega-variation → `>40 distinct out of 50` (specific count, not vacuous "non-empty"); zero-sigma idio collapses → `abs(o - omega_mean) < 1e-12`. Determinism pinned with `List.equal Float.equal` on full close-price series (not just length). Calendar alignment pinned with `List.for_all` over `List.equal Date.equal` across all symbol pairs (not just count). The `size_is N` uses are correct for length-contract claims, which is the actual semantic — no pass-through identity is left only with size_is. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | factor_model.mli guards: `sample_betas` empty for n<=0 → `test_sample_betas_zero_n` ✓; raises Invalid_argument on bad loading dist → `test_sample_betas_invalid_distribution_raises` ✓; `sample_idio_params` raises on bad idio dist → `test_sample_idio_params_invalid_raises` ✓; `generate_symbol_returns` empty for empty market → `test_generate_symbol_returns_empty_market` ✓. synth_v3.mli `generate` guards all six error conditions explicitly listed in the docstring → each has a `test_validation_*` test ✓. Risk-section "all prices remain finite" guard from plan → exercised by `test_ohlc_well_formed_all_symbols` which checks `Float.is_finite b.close_price` + positivity ✓. Minor note (not a FAIL): `generate_symbol_returns`' explicit "raises Invalid_argument if idio_params fails Garch.validate" claim has no direct unit test exercising that raise from `generate_symbol_returns` itself — but the equivalent guard is pinned at the dispatch layer (`test_validation_bad_idio_dist`) and `sample_idio_params` raise-path is directly tested. Acceptable: the direct-call raise is implementation guard depth, the public-surface contract is covered. |

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| (all) | Domain rows S*/L*/C*/T* | NA | Pure infra / synthetic-data-layer PR; domain checklist not applicable per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely". The PR touches no Weinstein domain logic (stages, stops, screener, macro). Net file footprint is strictly additive under `analysis/data/synthetic/` — no `trading/trading/` modules touched (qc-structural's A1 row already confirms PASS). The generated synthetic universe is a *consumer-facing artifact* of the Weinstein backtest, not Weinstein logic itself. |

## Quality Score

5 — Exemplary contract pinning: every public docstring claim has a named test, the load-bearing acceptance test from the m7 plan is pinned with the exact parameters and band stated in the plan, β=0/β=1 sanity tests cleanly bracket the model math (no market term when decoupled, exact reproduction when fully exposed), determinism is verified at three layers (sample_betas, sample_idio_params, full universe close-price series), and validation paths cover all six explicitly-listed error conditions in `Synth_v3.generate`'s docstring. The cross-sectional correlation test wires the M7.0 acceptance criterion directly into CI.

## Verdict

APPROVED

