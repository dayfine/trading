; Pinned "results-of-record" for the heavy multi-decade broad-universe backtests.
;
; These are NOT recomputed by CI — the top-3000 runs use an out-of-repo warehouse
; that the README auto-block (readme_toplines) cannot regenerate. This file is the
; machine-readable mirror of the headline rows in dev/backtest/DEEP_RESULTS.md;
; `readme_toplines` renders it into the README's <!-- deep-headline --> block.
;
; Each record pins its scenario sexp + the commit it was measured at. Optional
; numeric fields (max_drawdown_pct, trades, win_rate_pct) may be omitted — they
; render as "—" (used for the index comparator row).
;
; Row order = render order (headline first). When a record supersedes another,
; add the new row ABOVE and keep the superseded row with a "(superseded)" label.

((label "Weinstein top-3000 (promoted config)")
 (total_return_pct 8689.0)
 (max_drawdown_pct 30.3)
 (trades 1170)
 (win_rate_pct 38.4)
 (period "2000-01-01 -> 2026-06-26")
 (scenario_path
  "test_data/backtest_scenarios/staging-leverf-28y/top3000-2000-2026-rcb-f000.sexp")
 (basis_commit "6a2d9b426 (PR #2047 — promoted bundle: w30 + virgin-crossing + floors-zero)")
 (date "2026-07-23"))

((label "SPY total return (same window, comparator)")
 (total_return_pct 706.0)
 (period "2000-01-01 -> 2026-06-26")
 (scenario_path "n/a — dividend-adjusted SPY buy & hold")
 (basis_commit "DEEP_RESULTS.md record-of-record standing comparator")
 (date "2026-07-14"))

((label "Pre-bundle record (superseded)")
 (total_return_pct 7914.0)
 (max_drawdown_pct 32.3)
 (trades 1187)
 (period "2000-01-01 -> 2026-06-26")
 (scenario_path
  "test_data/backtest_scenarios/staging-record-convention/top3000-2000-2026-record-convention.sexp")
 (basis_commit "0a2e4562d (PR #1960, Run D, dedup-v2 warehouse; DEEP_RESULTS record-of-record 2026-07-14)")
 (date "2026-07-14"))
