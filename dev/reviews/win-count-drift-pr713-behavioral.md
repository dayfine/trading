Reviewed SHA: c17b897aa12fba165d8e790a5e53eeda1899f481

# Behavioral QC — win-count-drift (PR #713)
Date: 2026-04-30
Reviewer: qc-behavioral

PR: https://github.com/dayfine/trading/pull/713
Branch: fix/panel-golden-win-count-drift
Title: fix(summary): align summary win/loss count with trades.csv (reconciler-surfaced drift)

Classification: Metrics-aggregation fix (non-domain). Per
`.claude/rules/qc-behavioral-authority.md`, the Weinstein S*/L*/C*/T* checklist
is N/A; only the generic CP1–CP4 contract-pinning rows apply.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | New .mli additions in `metrics.mli`: `compute_profit_factor` and `compute_round_trip_metric_set`. (a) `compute_profit_factor` docstring claim "returns Float.infinity when there are profitable trades but no losses, and 0.0 when there are no trades or no profits" → pinned by `test_profit_factor_all_winners` (assert_that ProfitFactor (float_equal Float.infinity)) and `test_profit_factor_no_trades` (ProfitFactor = 0.0). (b) `compute_round_trip_metric_set` docstring claim "Empty round_trips yields just { ProfitFactor = 0.0 } — matching the legacy Summary_computer convention. The win/loss/PnL keys are omitted so an empty-range overlay leaves the simulator's pre-existing reading intact via Metric_types.merge" → pinned by `test_compute_round_trip_metric_set_empty` (asserts ProfitFactor=0.0 AND `Map.mem WinCount = false`, `Map.mem LossCount = false`, `Map.mem TotalPnl = false`). The omission claim is the load-bearing one for the runner overlay; it is exhaustively pinned. (c) Non-empty branch claim (TotalPnl/AvgHoldingDays/WinCount/LossCount/WinRate/ProfitFactor populated) → pinned by `test_compute_round_trip_metric_set_mixed_long_short` (5 trades; pins all 5 emitted keys + the arithmetic_wins parallel computation that mirrors the reconciler's predicate) and `test_compute_round_trip_metric_set_all_winners` (LossCount=0, ProfitFactor=+inf). |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | PASS | PR body "Test coverage" advertises 4 tests; all 4 are present at this SHA: (1) "mixed long+short (3 long wins + 1 long loss + 1 short win → n_wins = 4)" → `test_compute_round_trip_metric_set_mixed_long_short` (lines 703–733 of test_metrics.ml; asserts WinCount=4, LossCount=1, WinRate=80.0, TotalPnl=500.0, ProfitFactor≈4.333); (2) "all winners (LossCount = 0, ProfitFactor = +inf)" → `test_compute_round_trip_metric_set_all_winners` (lines 752–768); (3) "empty round-trip list (only ProfitFactor = 0.0...)" → `test_compute_round_trip_metric_set_empty` (lines 743–748); (4) "test_runner_filter: 1 new test pinning the overlay's alignment semantics on a synthetic warmup-contaminated metric_set + range-filtered round_trips, mirroring the panel-golden-2019-full bug exactly" → `test_summary_metrics_overlay_aligns_with_range_round_trips` (lines 202–266 of test_runner_filter.ml). PR body "Test plan" claim "panel_round_trips_golden test gates still pass — the goldens pin round_trips, not summary metrics, so they're unaffected" — verified by inspection: structural review confirmed no golden fixture changes in this diff and `Summary_computer` continues to use the new helper for the no-trades path (test_summary_computer_with_no_trades + test_profit_factor_no_trades still pin ProfitFactor=0.0 contract). |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are [equal_to ...] or equal_to on entire value), not just size_is | PASS | The overlay's "non-overlay metrics survive" semantics is the pass-through case here. `test_summary_metrics_overlay_aligns_with_range_round_trips` (test_runner_filter.ml lines 248–266) pins identity — not just size — by asserting `(SharpeRatio, float_equal 0.6); (MaxDrawdown, float_equal 2.0); (CAGR, float_equal 1.83)` against specific values seeded into `sim_metrics`. This is the canonical CP3 anti-pattern guard: the test would fail under any drift that touched non-overlay keys. The overlay-wins side is similarly pinned by exact `float_equal` on WinCount=2, LossCount=5, TotalPnl=-2750, WinRate=28.57%. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | The new code's load-bearing guards: (a) `_align_summary_metrics_to_round_trips`'s docstring (runner.ml lines 241–254) explicitly calls out the "warmup-vs-range-window" misalignment as the bug being guarded against — the synthetic test in test_runner_filter exactly mirrors that scenario (3W/6L sim_metrics fed into the overlay vs 2W/5L runner round_trips → assert post-overlay reads 2W/5L). (b) The empty-list guard claim in `compute_round_trip_metric_set` ("an empty-range overlay leaves the simulator's pre-existing reading intact via Metric_types.merge") is implicitly pinned: `test_compute_round_trip_metric_set_empty` asserts the overlay does not contain WinCount/LossCount/TotalPnl keys, which combined with `merge`'s "skewed combine, second wins on conflict, missing keys preserved from m1" semantics (verified at metric_types.ml line 58) means an empty-range overlay is a no-op on those keys — exactly the documented behavior. (c) The reconciler's authoritative-source claim is pinned by parallel computation in `test_compute_round_trip_metric_set_mixed_long_short` (line 718–722): the test computes `arithmetic_wins = List.count round_trips ~f:(fun m -> Float.(m.pnl_dollars > 0.0))` independently and asserts both `arithmetic_wins = 4` and `WinCount = 4.0` — directly pinning the equivalence to the reconciler's predicate. |

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | Metrics-aggregation fix; domain checklist not applicable. (Per `.claude/rules/qc-behavioral-authority.md`: "For pure infrastructure / library / refactor / harness PRs that touch no domain logic — the generic CP1–CP4 ... constitute the full review.") No core trading module is modified strategy-specifically. |
| S1–S6, L1–L4, C1–C3, T1–T4 | Weinstein domain rules | NA | Metrics-aggregation fix; domain checklist not applicable. |

## Independent verification of PR-body numbers

Spot-checked the panel-golden-2019-full reproducer:
- Located scenarios output at `dev/backtest/scenarios-2026-04-30-135918/panel-golden-2019-full/trades.csv` (post-fix run).
- 7 in-range round-trips. Tally:
  - Wins (pnl_dollars > 0): JNJ 2019-06-22→25 (+1524.02), JNJ 2019-12-07→10 (+1163.12) → **2 wins** ✓
  - Losses: JPM 05-04→07 (-2098.05), JNJ 06-29→07-02 (-1276.80), JNJ 11-30→12-03 (-584.43), CVX 05-18→10-03 (-7752.00), AAPL 05-04→07 (-2670.33) → **5 losses** ✓
  - Sum of pnl_dollars: 2687.14 + (-14381.61) = **-11694.47** ✓ (matches PR body)
  - Mean days_held: (3+3+3+3+3+138+3)/7 = 156/7 = **22.29** ✓
  - Profit factor: 2687.14 / 14381.61 = **0.1869 ≈ 0.19** ✓
- Pre-fix's claimed 9 round-trips (= 7 in-range + warmup AAPL/JPM 2019-04-26→29 pair) is consistent with the date-range arithmetic: warmup_days = 210 ⇒ warmup_start ≈ 2018-10-03; the AAPL/JPM 2019-04-26→29 cycle landed in the warmup window (before the 2019-05-01 start_date) and was thus reachable to the simulator's full step_history but excluded from `steps_in_range`.

## Edge-case coverage

- **All winners**: `test_compute_round_trip_metric_set_all_winners` asserts `(ProfitFactor, float_equal Float.infinity)` — the matcher uses direct `Float.infinity` equality, NOT a finite ratio approximation, so the +inf semantics is precisely pinned (no NaN trap). Mirrored by the older `test_profit_factor_all_winners` integration. ✓
- **Single-trade**: not pinned as a dedicated test. Covered structurally by 2-trade `test_compute_round_trip_metric_set_all_winners` and the variety of pair sizes; not a finding because the pairing logic is identical for n=1 vs n=2 vs n=5. NOTE only.
- **Empty list**: pinned three ways — `test_compute_round_trip_metric_set_empty` (only ProfitFactor=0 emitted, win/loss keys absent), `test_summary_computer_with_no_trades` (ProfitFactor=0.0 via the integrated computer), `test_profit_factor_no_trades` (legacy contract). The "why zero and not NaN/undefined" answer: it is the legacy `Summary_computer` convention (pre-PR), preserved for backwards compatibility — explicitly called out in `compute_profit_factor`'s if/then branch (`if Float.(gross_profit > 0.0) then Float.infinity else 0.0`). The PR comment in `compute_round_trip_metric_set` (metrics.ml lines 195–198) explicitly cites this as a deliberate compatibility choice. ✓

## Test fixture impact

- `panel_round_trips_golden` goldens pin the `round_trips` list directly (not the summary metric_set), so they are unaffected by an aggregation-only fix. PR body's "no fixture updates required" claim is consistent with the structural diff (no golden fixture files in the changed-files list).
- `Summary_computer.ml` was deduplicated (now calls `Metrics.compute_round_trip_metric_set` directly), which is a strict refactor — the no-trades contract (`ProfitFactor = 0.0`) is preserved by `compute_round_trip_metric_set`'s explicit empty-list shape, so `test_summary_computer_with_no_trades` continues to pass against the dedup'd implementation.

## Quality Score

5 — Exemplary metric-alignment fix: clear root-cause narrative in PR body and code docstrings, the new helpers are minimally scoped and well-typed, the legacy empty-list convention is deliberately preserved with an in-source citation, and the test design directly mirrors the bug — including a synthetic 3W/6L → 2W/5L overlay test that pins both the overlay-wins keys and the pass-through (Sharpe/MaxDrawdown/CAGR) keys, plus a parallel arithmetic-count test that pins equivalence to the reconciler's `pnl_dollars > 0` predicate.

## Verdict

APPROVED
