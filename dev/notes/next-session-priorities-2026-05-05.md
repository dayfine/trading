# Next-session priorities — 2026-05-05

End-of-session snapshot from 2026-05-04 → 2026-05-05 (sprint: ~50 PRs merged across the
F.3 retirement chain, parity bisect + Option-1 revert, perf fix, fixture cleanups, and
jj-workspace harness fix).

## Top-level state

- **5y SP500** (`goldens-sp500/sp500-2019-2023`): GOOD. 500-sym universe (post-#851
  share-class dedup), tight-pinned 2026-05-05 to 58.34%/81 trades / 0.54 sharpe /
  33.60% MaxDD / 84-day avg holding.
- **5y SP500 long-only** (`goldens-sp500/sp500-2019-2023-long-only`): GOOD. Re-pinned
  2026-05-05 to 503-sym actuals (79.74%/74); will narrow on next run with 500-sym.
- **15y SP500** (`goldens-sp500-historical/sp500-2010-2026`): perf GOOD (7m wall
  via #845's Daily_panels O(log N) reads); trade-count fixed via #855 position-sizing
  override; tight-pinned to 5.15%/102 trades / 0.40 sharpe / 16.12% MaxDD; CAGR
  anemic (0.31%) — see #856 for return-tuning follow-up.

## Open follow-ups (priority-ordered)

### Priority 1 — Forward-fix #848 (path-dependent regression)

URL: https://github.com/dayfine/trading/issues/848

Bisect (#852 / `dev/notes/path-dependent-regression-848-investigation-2026-05-05.md`)
identified two coupled bugs in `Snapshot_bar_views`:

1. **`daily_view_for` window mismatch**: panel walks `lookback` calendar weekday
   columns; snapshot walks `~1.5×lookback` calendar days then takes trailing
   `lookback` actual rows. Drives 30142/30900 cell differences. Recommended fix:
   add `~calendar` parameter to `Snapshot_bar_views.daily_view_for` (and
   `low_window`) so snapshot mirrors panel calendar semantics.
2. **`_assemble_daily_bars` NaN open_price**: returns `Float.nan` for OPEN
   field due to schema lookup mismatch (the schema HAS `Snapshot_schema.Open`
   defined; `_assemble_daily_bars:86` doesn't read it). Mechanical fix.

Acceptance: `diag_panel_vs_snapshot_extended.exe` (in `trading/trading/backtest/diag/`)
reaches 0 diffs across all 5 primitives + `dev/scripts/check_sp500_baseline.sh`
PASS on Option-1 wiring. Once landed, F.3.b-2/c-2/d-2/e (caller migrations +
`bar_panels.t` deletion) are unblocked.

### Priority 2 — #856 grid-search 15y position-sizing

URL: https://github.com/dayfine/trading/issues/856

The #855 override (`max_position_pct_long: 0.05`) brought 15y from 16 → 102
trades but CAGR is 0.31% (vs 0.95% pre-fix). qc-behavioral #855 F1 found that
2 of the 3 overrides are inert: `max_long_exposure_pct` is dominated by
`Float.min(per_position, exposure)` when per-position is the tighter cap;
`min_cash_pct` has zero production callers (deprecated/never-wired).

Only `max_position_pct_long` is the binding knob. Try a 5-cell sweep
{0.07, 0.10, 0.13, 0.16, 0.20} via M5.5 T-A grid_search (already shipped via #805).
Acceptance: ≥50% return AND 200-400 trades AND ≥0.6 Sharpe.

### Priority 3 — F.3 caller migrations + F.3.e bar_panels.t deletion

Blocked on Priority 1 (#848 forward fix). Once `Snapshot_bar_views.daily_view_for`
parity is bit-equal to panel path, can:

- F.3.b-2: migrate Weekly_ma_cache callers to `of_snapshot_views`, delete legacy `create`
- F.3.c-2: migrate Panel_callbacks callers
- F.3.d-2: migrate Macro_inputs callers
- F.3.e: delete `bar_panels.{ml,mli}` + tests

This completes the M5.3 streaming pipeline. Plan: `dev/plans/snapshot-engine-phase-f-2026-05-03.md` §F.3.

### Priority 4 — 10k universe (deferred per user 2026-05-04)

Build a Pinned-shape 10k-symbol universe from `data/sectors.csv` — DO NOT
pre-filter on bar coverage (`memory/project_broad_universe_semantics.md`).
Run broad×10y scenario. Likely takes ~2-4 hr of snapshot build + backtest.
Defer to a fresh session with full disk + memory budget.

### Priority 5 — 3 side-issues from #853

1. `equity_curve.csv` truncates at 2010-11-16 despite simulator running through
   2026-04-29 (per `progress.sexp` `cycles_done 882`)
2. MRO appears in BOTH `trades.csv` (closed 2015-08-07) AND `open_positions.csv`
   (still held at run end, same qty) — zombie position post stop-loss
3. `progress.sexp current_equity $100K` vs `summary.sexp final_portfolio_value $1.16M`
   (10× discrepancy in current_equity field)

All three flagged in `dev/notes/15y-trade-count-investigation-2026-05-05.md`
§"Side-issues surfaced". File as separate issues if not already.

## Operational state

- **Autonomous merge policy active** — see `~/.claude/projects/-Users-difan-Projects-trading-1/memory/feedback_no_pr_merging.md`. All 3 gates required (CI + qc-structural + qc-behavioral). Trivial docs PRs (~10 lines) can skip QC.
- **jj workspace contamination fix** — every feat-* / harness-maintainer / ops-data agent prompt now includes `## Pre-Work Setup` boilerplate (`jj workspace add`) per #839. Read-only QC agents can run concurrent with one feat-* agent.
- **Wakeup cadence** — interactive sessions: wake every 10-15 min while async work in flight (memory `feedback_use_schedulewakeup_async.md`).
- **GHA orchestrator** — runs 2 overnight slots (00:17 / 05:17 PT). Substantive work happens in local sessions.

## Issues / PRs to watch

| ID | Status | Notes |
|----|--------|-------|
| #848 | OPEN | Path-dependent regression in `Bar_reader.of_snapshot_views`; blocks F.3.e |
| #856 | OPEN | 15y return tuning via grid search on `max_position_pct_long` |
| #843 | CLOSED | F.2 parity break (resolved by #847 partial revert) |
| #844 | CLOSED | Super-linear perf regression (resolved by #845) |

## Snapshot of canonical baselines (as of 2026-05-05)

```
sp500-2019-2023 (500-sym universe, post-#851 dedup):
  total_return_pct  58.34   total_trades 81   win_rate 19.75
  sharpe_ratio       0.54   max_drawdown 33.60  avg_holding_days 84.10

sp500-2019-2023-long-only (503-sym, pre-#851; will narrow on next 500-sym run):
  total_return_pct  79.74   total_trades 74   win_rate 27.03
  sharpe_ratio       0.66   max_drawdown 30.79  avg_holding_days 94.55

sp500-2010-2026 (510-sym Wiki replay, with #855 position-sizing override):
  total_return_pct   5.15   total_trades 102   win_rate 21.57
  sharpe_ratio       0.40   max_drawdown 16.12  avg_holding_days 130.58
```

Tight-pinned in scenario files 2026-05-05 with ±10-25% tolerance bands.
