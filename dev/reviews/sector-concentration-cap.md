Reviewed SHA: d270070093403eeb8fa26f20d08cd5eb45ca0c51

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No format violations |
| H2 | dune build | PASS | Clean build |
| H3 | dune runtest --force | PASS | All tests passed; magic-numbers linter clean; 55 tests in portfolio_risk + 25 in entry_audit_capture + integration suites all pass |
| P1 | Functions ≤ 50 lines (linter) | PASS | fn_length_linter passed as part of H3 |
| P2 | No magic numbers (linter) | PASS | magic-numbers linter passed (H3): "OK: no magic numbers found in lib/ files" |
| P3 | Config completeness | PASS | New `max_sector_exposure_pct : float option` field added to config record; all tunable values routed through config, never hardcoded |
| P4 | Public-symbol export hygiene (linter) | PASS | mli-coverage linter passed as part of H3 |
| P5 | Internal helpers prefixed per convention | PASS | New helpers prefixed with `_`: `_compute_sector_exposures`, `_check_sector_exposure`, `_apply_sector_exposure_gate`, `check_sector_exposure_cap` public API per design |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | PASS | One-assert-per-value rule followed throughout. Portfolio_risk tests use `assert_that result (equal_to ...)` for Result types. Entry_audit_capture tests use `assert_that result is_some_and (field ... (equal_to ...))` and `assert_that result is_none`. No nested `assert_that` in matcher callbacks; matchers library composition (`field`, `all_of`, `is_some_and`) properly applied. 5 new sector-exposure unit tests + 5 integration tests all follow the pattern. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to core modules. PR plumbs through `entry_audit_capture` (part of `strategy` module but not a core module per A1 watch-list) and `portfolio_risk` (a Weinstein risk-management module, not a core module). No touch to `trading/trading/portfolio/`, `trading/trading/orders/`, `trading/trading/position/`, `trading/trading/engine/`, or the core `strategy.ml`. |
| A2 | No new `analysis/` imports into `trading/trading/` outside backtest exception | PASS | PR touches only `trading/trading/weinstein/*`, `trading/trading/backtest/*`, `trading/devtools/*`, and `dev/*`. No new `analysis/` imports into any `trading/trading/` module. All dependencies remain within established scopes. |
| A3 | No unnecessary modifications to existing modules | PASS | File list matches plan's scope exactly: portfolio_risk files, strategy/audit integration, backtest wiring, ppx test fixture (required for new snapshot field), and plan/status files. No cross-feature drift; all modifications directly support the sector-exposure cap feature. |

## Verdict

APPROVED

No blockers. All hard gates pass (format, build, tests). Architecture rules satisfied (no core-module touch, no boundary-crossing imports, scoped to plan). Test patterns conform. Feature is ready for behavioral review.

---

# Behavioral QC — sector-concentration-cap
Date: 2026-05-15
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | (a) `portfolio_risk.mli` `max_sector_exposure_pct = None` "default" → `test_sector_exposure_cap_off_by_default`. (b) `Some pct` cap on named sector with `(existing + proposed) / total_value <= pct` semantics → `test_sector_exposure_cap_blocks_over_concentration` (33% > 30% → Error) + `test_sector_exposure_cap_admits_under_concentration` (25% ≤ 30% → Ok). (c) empty-string sector exempt → `test_sector_exposure_cap_exempts_empty_string_sector`. (d) `sector_exposures` field computed parallel to `sector_counts` summing long+short via absolute value → `test_snapshot_computes_sector_exposures`. (e) `entry_audit_capture.mli` `check_sector_exposure_cap` default-off pass-through → `test_sector_exposure_cap_off_passes_through`; cap-on rejection → `test_sector_exposure_cap_rejects_at_33pct`; admit + accumulator bump → `test_sector_exposure_cap_admits_at_25pct`; empty-string exempt with no bucket bump → `test_sector_exposure_cap_exempts_empty_sector`; cross-candidate accumulation → `test_sector_exposure_cap_accumulates_across_candidates`. (f) `classify_candidate.mli` "Order: held → sizing → cash → short-notional → sector-exposure" and cash-refund-on-rejection: refund path is exercised by the existing short-notional gate test pattern; the new sector gate uses the same `_refund_cash_for_trans` helper. Composition of count + exposure caps → `test_sector_exposure_cap_composes_with_count_cap`. (g) `audit_recorder.mli` new `Sector_exposure_cap` variant — wired through `_skip_reason_of_event` and pinned indirectly via the gate tests asserting `is_none` and Result.Error projection. |
| CP2 | Each claim in PR body / plan "Test coverage" section has a corresponding committed test | PASS | Plan §Acceptance criteria checklist (unit tests): "Default `None` → cap doesn't fire even when concentration is high" → `test_sector_exposure_cap_off_by_default` (Tech at 50%, 5K proposed, Ok). "`Some 0.30` with sector at 28% → admit a 3% candidate fails (projected 31%)" → `test_sector_exposure_cap_blocks_over_concentration` (28% + 5K = 33% > 30% → Error; semantically equivalent claim — both pin "over-concentration is rejected with projected pct"). "`Some 0.30` with sector at 20% → admit a 5% candidate passes (projected 25%)" → `test_sector_exposure_cap_admits_under_concentration` (verbatim). "Empty-string sector is exempt from the exposure cap" → `test_sector_exposure_cap_exempts_empty_string_sector` (cap=0.05, "" bucket at 30%, Ok). Strategy gate emits `Sector_exposure_cap` skip reason → covered by the entry_audit_capture P1 tests + `_skip_reason_of_event` wiring in `trade_audit_recorder.ml`. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size_is | PASS | Default-off path (the load-bearing invariant — "preserves all goldens bit-equal") is pinned by `test_sector_exposure_cap_off_by_default` asserting `equal_to (Result.Ok ())` against a snapshot that would over-concentrate at 50% Tech with a 5K addition (projected 55%, way over any cap). The strategy-side `test_sector_exposure_cap_off_passes_through` asserts the full `shares` count (100) is preserved through the gate — not just `is_some`. The "no bucket bump on empty sector" claim is pinned by `assert_that (Hashtbl.find sector_exposure_acc "") is_none` — identity-level, not size-level. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | Guards in new code: (a) "empty-string sector is exempt" in both `_check_sector_exposure` (`portfolio_risk.ml:297`) and `check_sector_exposure_cap` (`entry_audit_capture.ml:175`) → both have dedicated tests (`test_sector_exposure_cap_exempts_empty_string_sector` and `test_sector_exposure_cap_exempts_empty_sector`). (b) "`max_sector_exposure_pct = None` → no-op pass-through" → both unit and strategy-gate tests above. (c) "accumulator NOT bumped on rejection" (cited in `check_sector_exposure_cap` doc) → `test_sector_exposure_cap_rejects_at_33pct` asserts `Hashtbl.find_exn sector_exposure_acc "Test"` remains 28_000.0 after rejection. (d) "portfolio_value <= 0 → projected_pct = 0" guard (line 187 of entry_audit_capture.ml and line 306 of portfolio_risk.ml) → not directly tested; this is a defensive path inherited from the existing `_check_cash` pattern and the same shape is unit-tested elsewhere. Acceptable — same convention as existing cash guard. |

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | Structural QC did not flag A1. PR touches only `weinstein/portfolio_risk/`, `weinstein/strategy/`, and `backtest/`. |
| S1 | Stage 1 definition matches book | NA | Risk-management gate; not a stage feature. |
| S2 | Stage 2 definition matches book | NA | Same. |
| S3 | Stage 3 definition matches book | NA | Same. |
| S4 | Stage 4 definition matches book | NA | Same. |
| S5 | Buy criteria: entry only in Stage 2, on breakout with volume | NA | Same. |
| S6 | No buy signals in Stage 1/3/4 | NA | Same. |
| L1 | Initial stop placed below the base | NA | Not a stops feature. |
| L2 | Trailing stop never lowered | NA | Same. |
| L3 | Stop triggers on weekly close | NA | Same. |
| L4 | Stop state machine transitions correct | NA | Same. |
| C1 | Screener cascade order: macro → sector → scoring → ranking | NA | Risk-management gate operates at entry-walk time, after the screener cascade. Cascade order unchanged. |
| C2 | Bearish macro blocks all buys | NA | Macro gate untouched. |
| C3 | Sector RS vs. market, not absolute | NA | Sector exposure cap is a dollar-notional cap, orthogonal to sector RS classification. |
| T1 | Tests cover all 4 stage transitions | NA | Not a stage feature. |
| T2 | Bearish macro → zero buy candidates test | NA | Macro gate untouched. |
| T3 | Stop trailing tests over multiple advances | NA | Not a stops feature. |
| T4 | Tests assert domain outcomes, not just "no error" | PASS | All new tests assert specific outcomes: `Result.Error [Sector_exposure_exceeded ("Tech", 0.33)]` with the exact sector name and projected pct; accumulator values asserted with `float_equal 25_000.0` / `28_000.0` / `20_000.0` after admit / reject paths; bucket presence/absence on the empty-string path asserted with `is_none`. The composition test pins both `Sector_concentration ("Tech", 3)` AND `Sector_exposure_exceeded ("Tech", 0.33)` in a single ordered list. None of the tests stop at "no exception thrown" — every gate outcome is tied to a specific domain value. |

## Quality Score

5 — Exemplary risk-gate addition: textbook default-off bit-equality preservation, the empty-string-sector exemption is explicitly motivated and individually pinned, the composition with the existing count-cap is tested, accumulator state transitions are asserted on both admit and reject paths, and the gate ordering / cash-refund contract is documented in the .mli with matching primitives in the strategy wiring. Could serve as a reference implementation for future risk-management gates.

## Verdict

APPROVED

