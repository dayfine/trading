---
name: simulator NAV fallback corrupts equity_curve (FIXED 2026-05-15)
description: Original bug at simulator.ml:213-214 silently substituted current_cash on forward-fill failure. PR #1019 moved to portfolio_valuation.ml:85-87; PR #1123 (2026-05-15) replaced with fail-loud. Historical artifact only.
type: project
originSessionId: f663a01d-13c0-428f-ad43-235cc8d9407c
---

## 2026-05-15 UPDATE — FIXED

PR #1019 (2026-05-10) refactored NAV logic into `Portfolio_valuation.compute`,
moving the silent cash-fallback to `portfolio_valuation.ml:85-87`.

PR #1123 (2026-05-15) replaces the unreachable Error branch with `failwithf`
naming held symbols + date + underlying error. Four-tier price chain
(today's bars → adapter forward-fill → run cache → avg-cost) already
implements LastKnown semantics; the cash-fallback was a dormant footgun.

**Use `trading/analysis/scripts/reconstruct_nav` ONLY for runs from BEFORE
PR #1123 merged.** Post-#1123 backtest artifacts are trustworthy.

---

## Historical (pre-2026-05-15)

[Retained for context on pre-#1123 artifacts.]

`trading/trading/simulation/lib/simulator.ml:213-214` (`_compute_portfolio_value`) silently substituted `portfolio.current_cash` for full NAV whenever `Calculations.portfolio_value` errored — i.e., whenever any held symbol's forward-fill via `get_previous_bar` returned `None` (M&A delisting, dataset window edge, survivor-bias purge). The equity_curve.csv would bounce between cash-only-fallback days and partial-NAV days, corrupting every daily-derivative metric: max_drawdown, sharpe, sortino, calmar, best/worst_*_pct, volatility, skewness, kurtosis, time_in_drawdown, ulcer_index, cvar.

**Why this mattered:** First surfaced 2026-05-10 on Cell E 15y full-window run. Corrupt artifact reported total_return −50.30% / MaxDD 99.95% / Sharpe 1.20; offline reconstruction from trades.csv + bars showed +163.56% / 20.12% / 0.59. Trade tape was unaffected — only the daily NAV series was wrong. Affected every backtest with delisted holds.
