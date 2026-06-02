---
name: 2026-05-10 session — simulator NAV fix + perf hotspot + decay analysis
description: Today's session findings and PRs — simulator NAV fallback bug fix, Order_manager active-orders index, benchmark-relative metrics, state-pollution experiment in flight.
type: project
originSessionId: f663a01d-13c0-428f-ad43-235cc8d9407c
---
## What landed today (2026-05-10)

PRs in flight off `main@origin`:

- **#1019** `fix(simulation): cache + avg-cost fallback in _resolve_price` — fixes the silent cash-only fallback in `_compute_portfolio_value` that corrupted equity_curve daily-derivative metrics on runs with delisted holds. Refactored into a new `Portfolio_valuation` module to satisfy linters (file/function/nesting limits).
- **#1020** `perf(orders): bound list_orders ~ActiveOnly walk` — **MERGED**. Added an `active_orders` mirror Hashtbl to `Order_manager`; `list_orders ~filter:ActiveOnly` walks the bounded mirror instead of the monotonically-growing audit table. 5y Cell E wall: 6:30 → 6:14; bigger payoff predicted on 15y (~10× cumulative orders).
- **#1021** `feat(metrics): benchmark-relative metrics` — adds CAPM-style alpha/beta + tracking error + information ratio + correlation to benchmark via a new `Benchmark_relative_computer`. Mirrors the antifragility computer pattern.

## Diagnostic findings

**Why:** Cell E h=2 15y showed `total_return -50% / MaxDD 99.95%` while offline reconstruction from `trades.csv` showed `+163.56% / 20.12% / Sharpe 0.59`. Trade tape correct; equity_curve corrupt. Root cause: `simulator.ml:213-214` substituted `current_cash` whenever any held position lacked a price, even when the position was simply going through a corporate-action bar gap.

**How to apply:** when interpreting any backtest's `equity_curve.csv` or `summary.sexp` daily-derivative metrics from BEFORE #1019 lands, treat them as suspect. Use `trading/analysis/scripts/reconstruct_nav/reconstruct_nav.exe -artifact-dir <DIR> -start <D> -end <D>` for canonical numbers (~3-sec runtime).

## Strategy decay analysis (open)

5-year subperiods on Cell E h=2 reconstructed 15y curve:
- 2010-2014: +101% / Sharpe 1.06 / WR 40.7% / $1,366/trade
- 2015-2019: +30% / Sharpe 0.59 / WR 35.1% / $1,252/trade
- 2020-2024: +8% / Sharpe 0.20 / WR 33.6% / $290/trade
- 2025-Apr2026: −7% / Sharpe −0.86 / WR 33.1% / −$779/trade

Vanilla 15y has 0 trades in 2017-2019 + 2024-2026 (default sizing too tight; the classifier finds nothing). Generalized base-strategy decay: post-2017 SP500 doesn't reward Weinstein-style 30w-MA breakouts as strongly. Cell E features amplify activity but each marginal trade has near-zero edge.

**State-pollution experiment in flight** (running 2026-05-10): three independent 5y Cell E h=2 backtests on 2010-2014, 2015-2019, 2020-2024 — each starting fresh at $1M with no inherited state. If per-period returns materially exceed the 15y slice returns → state pollution (stop-state, indicator caches, hysteresis, macro state) is dragging performance forward. If similar → the decay is regime-driven. Artifact path: `dev/experiments/state-pollution-2026-05-10/`.

## Lessons for future sessions

- **`gh pr checkout` from a sub-agent will reset the parent's git HEAD.** That triggered jj to reparent my working `@` mid-session, reverting in-progress edits to mainline content. Mitigation: snapshot WIP into a described commit BEFORE dispatching qc agents that need to checkout.
- **Build silent on Warning 8 `partial-match`.** Adding new `Metric_type` variants didn't fail the build despite explicit non-exhaustive matches in `metric_computers.ml` and `metric_info_registry.ml`. Don't rely on the compiler — grep for matches on the type name and update them all proactively.
- **Memory-grow scaling:** the per-day rate on Cell E 15y was ~14× the 5y rate, even after PRs #1014 + #1015. Identified hotspot: `Order_manager.list_orders ~filter:ActiveOnly` walked the cumulative orders hashtable every step — fix in #1020. Confirms that "growing-state per-step iter" is the recurring perf pattern to grep for in this codebase.
