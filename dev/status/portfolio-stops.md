# Status: portfolio-stops

## Last updated: 2026-03-30

## Status
APPROVED

## Interface stable
YES

## Branch
feat/portfolio-stops (top-level with trading_state module)
portfolio-stops/risk (portfolio_risk module — awaiting review/merge)

## Completed
- `weinstein_stops`: stop state types, config, update machinery — MERGED to main (PRs #136, #147)
- `portfolio_risk`: risk management (position sizing, exposure limits, sector concentration) — 16+ tests, on portfolio-stops/risk, NOT YET reviewed
- `weinstein_trading_state`: JSON persistence (save/load), stop states, stage history, trade log — 25 tests, committed to feat/portfolio-stops, NOT YET reviewed

## In Progress
— (all remaining work blocked on screener merge)

## Blocked
- `order_gen`: blocked until feat/screener merges to main (needs weinstein.screener for scored_candidate type)
- `portfolio-stops/risk` PR: needs QC review before merge to main

## Next Steps
1. QC review of portfolio-stops/risk (portfolio_risk module)
2. QC review of feat/portfolio-stops (weinstein_trading_state module)
3. Merge portfolio-stops/risk → main
4. Merge feat/portfolio-stops → main
5. Wait for screener merge → implement order_gen

## Recent Commits
- `61cee6b5` feat/portfolio-stops: Add Weinstein trading state persistence: JSON save/load, stop states, stage history, trade log (25 tests)
- `469c407d` portfolio-stops/risk: Apply review: merge sector variants, monoid check_limits, reorganize mli, rename make_snap
- `ea84b60b` portfolio-stops/risk: Apply review: add snapshot_of_portfolio using Portfolio.t, convert tests to matchers
- `5a0517ed` portfolio-stops/risk: Add Portfolio risk management module (16 tests)
