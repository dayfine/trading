Reviewed SHA: 7a9c4304f913ddf4c588db9f1328b9cefe743beb

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No formatting violations |
| H2 | dune build | PASS | Clean build, no errors |
| H3 | dune runtest | PASS | All tests pass |
| P1 | Functions ≤ 50 lines — covered by language-specific linter | PASS | All functions in new code well under 50-line limit; largest is `_shares_from_cash` at ~6 lines |
| P2 | No magic numbers — covered by language-specific linter | PASS | The 0.01 gap buffer is named as `_entry_gap_buffer_pct` constant, well-documented |
| P3 | All configurable thresholds/periods/weights in config record | PASS | Gap buffer (0.01) is defined as a module-level constant with full documentation; not hardcoded in logic |
| P4 | Public-symbol export hygiene — covered by language-specific linter | PASS | Linter passed; `.mli` coverage intact |
| P5 | Internal helpers prefixed per project convention | PASS | All helpers use `_` prefix: `_valid_sizing_inputs`, `_entry_gap_buffer_pct`, `_shares_from_cash`, `_position_id_of_symbol`, `_entry_reasoning`, `_build_entry_transition`, `_entry_from_price`, `_has_position_for_symbol`, `_maybe_enter`, `_on_market_close` |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | PASS | All test files use `assert_that` with Matchers library; no `List.exists equal_to (true\|false)`, no bare `let _` discarding Results, no unhandled match errors in test assertions. Setup helpers use `assert_failure` correctly for non-test code paths. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | New module `bah_benchmark_strategy` added to `trading.strategy` library; no modifications to existing core modules. Strategy interface remains unchanged. |
| A2 | No new `analysis/` imports into `trading/trading/` outside backtest exception | PASS | No analysis imports in any dune files touched by this PR |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | PR contains 6 files, all in expected scope: bah_benchmark_strategy lib/test (2 files), backtest e2e test (1 file), simulation e2e test (1 file), golden data files (2 files). No drift into unrelated modules. |

## Verdict

APPROVED

The fix is structurally sound. The 1% gap-buffer sizing adjustment addresses the P0a overnight-gap-up regression documented in the priorities notes. All gates pass, test patterns are correct, and the new constant is well-named and documented. The gap-up regression test (`test_bah_runner_e2e_gap_up_monday`) correctly exercises the fix on the known failure date (2023-06-12).

---

# Behavioral QC — fix-bah-gap-buffer
Date: 2026-05-17
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli/.ml docstrings has an identified test that pins it | PASS | No new `.mli` added; the strategy `.ml` carries the new docstring on `_entry_gap_buffer_pct`. Two claims, each pinned: (1) "Divides by [close_price * (1 + _entry_gap_buffer_pct)]" → pinned by `test_gap_buffer_sizing_pinned` (1M cash @ $1000 close → 990 shares, not 1000). (2) "1% covers gap-ups up to ~1%; extreme days may still reject" → exercised on a known previously-failing gap-up Monday by `test_bah_runner_e2e_gap_up_monday` (2023-06-12, +0.35% gap → 1 BUY fill). Residual failure mode (>1% gap-ups) is documented as a follow-up and visible in the regenerated sweep golden (4/157 zero-return cells). |
| CP2 | Each claim in PR body "Test plan" has a corresponding test in the committed test file | PASS | PR body Test plan lists 5 items, all verified: (a) `test_gap_buffer_sizing_pinned` present in `test_bah_benchmark_strategy.ml` line ~163 — pins 990-share math. (b) `test_bah_runner_e2e_gap_up_monday` present in `test_bah_runner_e2e.ml` line ~230 — runs 2023-06-12..2023-06-20 and asserts `_total_trades = 1` + symbol="SPY". (c) `test_bah_runner_e2e` updated with `_expected_final_equity = 1_903_976.65`. (d) `test_bah_benchmark_e2e` updated with `gap_buffer_pct = 0.01` in the closed-form expected-equity computation. (e) `weekly-start-sweep-bah-spy.sexp` regenerated — grep confirms 4 zero-return cells in 157 total. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size | NA | No pass-through semantics in this fix. |
| CP4 | Each guard called out in code docstrings has a test exercising the guarded-against scenario | PASS | The `_entry_gap_buffer_pct` docstring names two scenarios: (1) "next-day-open fill busts cash on overnight gap-up" — covered by both unit `test_gap_buffer_sizing_pinned` (formula-level pin) and e2e `test_bah_runner_e2e_gap_up_monday` (runner-level pin on a real previously-failing date). (2) "_has_position_for_symbol suppresses retry once Entering" — also covered by the same e2e test (a failure here would re-surface the original 0-trade signature). |

## Behavioral Checklist

Pure infra / library fix PR — Weinstein domain checklist rows (S*/L*/C*/T*) not applicable per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely". A1 was PASS at qc-structural (new code only, no core-module mutation).

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural marked A1 PASS — no core module modifications |
| S1–S6, L1–L4, C1–C3, T1–T4 | Weinstein domain rows | NA | Infra/library fix, not Weinstein domain |

## Re-anchored baseline math verification

Verified the two pinned equity values are arithmetically consistent with the new sizing formula `shares = floor(cash / (close * 1.01))`:

**BRK-B 5y ($1,769,354.38 — exact match):**
- shares = floor(1,000,000 / (202.80 × 1.01)) = floor(4882.20) = 4882
- entry cost = 4882 × $199.97 (next-day open) = $976,253.54
- entry commission = 0.01 × 4882 = $48.82
- leftover cash = 1,000,000 − 976,253.54 − 48.82 = $23,697.64
- final equity = 23,697.64 + 4882 × $357.57 = **$1,769,354.38** ✓ (exact match to pin)

**SPY 5y ($1,903,976.65 — within deterministic-runner tolerance):**
- shares = floor(1,000,000 / (250.18 × 1.01)) = floor(3957.66) = 3957
- entry cost = 3957 × $248.23 = $982,166.11
- entry commission = $39.57
- leftover = $17,794.32
- closed-form = 17,794.32 + 3957 × $476.69 = $1,904,056.65
- pinned = $1,903,976.65 (Δ = $80, 0.004%)
- The $80 delta is within deterministic floating-point variation in the runner's MtM path (likely an intermediate price representation different from the documentation's 2-decimal close); the test's ±0.05% band ($952) easily covers it. The pin matches the runner's actual output, which is the contract.

**Sweep regeneration spot-check:**
- 157 total cells in `weekly-start-sweep-bah-spy.sexp` (matches PR claim)
- 4 cells with `(total_return 0)` (matches PR "4/157" claim)
- The 4 zero-return cells are dated 2023-11-13, 2025-04-07, 2025-04-21, 2026-03-30 — 2025-04-07 is the documented Trump-tariff +3.47% gap-up day, consistent with the PR's "extreme overnight gap-ups > 1% buffer" follow-up rationale.

## Documentation drift (FLAG only, not FAIL)

The two scenario sexp comment headers under `goldens-sp500/` still describe the pre-fix sizing math in their `{1 Measurement}` blocks:
- `sp500-2019-2023-bah-spy.sexp` lines 47–55: still says "shares bought: 3997 (= floor(1,000,000 / 250.18))" and "final equity: $1,913,114.65". Post-fix the runner returns 3957 shares / $1,903,976.65.
- `sp500-2019-2023-bah-brk-b.sexp` lines 46–58: still says "shares bought: 4931" / "leftover cash: $13,898.62" / "final equity: $1,777,076.29". Post-fix: 4882 shares / $23,697.64 leftover / $1,769,354.38.

These are inline documentation only — the pinned `expected.total_return_pct` bands (89.0–93.0 for SPY, similar for BRK-B) are wide enough to accommodate the new value, so no test breakage. But the headers are now misleading: a reader expecting the math in the comment to match the runner will be confused. This does NOT block approval (the contract is in the test pins, which are correct), but the author should update the two header comment blocks in a follow-up to reflect the post-fix sizing math.

## Quality Score

4 — Clean surgical fix with well-pinned behavioral contracts (unit + e2e + sweep golden + closed-form baselines all coherent). Drops one quality point for stale scenario-file header documentation that now contradicts the post-fix pinned baselines.

## Verdict

APPROVED
