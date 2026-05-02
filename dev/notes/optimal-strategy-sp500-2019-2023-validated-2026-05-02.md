# Optimal-strategy validation on sp500-2019-2023 (post universe-fix)

**Date:** 2026-05-02
**Driver:** PR #749 (universe scoping) + #748 (memoize) + #750 (Score_picked variant) all merged. First time the optimal_strategy counterfactual produces meaningful numbers on sp500.

## Pre-fix numbers (PR #749 unwound)

| | Constrained | Score_picked | Relaxed_macro |
|---|---:|---:|---:|
| Return | +1997.22% | n/a | +2185.63% |
| Win rate | 100.00% | n/a | 100.00% |
| MaxDD | -0.00% | n/a | -0.00% |
| R-multiple | 222 | n/a | 232 |

**These were bogus** — the runner used `Sector_map.load` to get the universe (10473 symbols), so the optimal could pick any stock in the data dir, not just the 491 sp500 stocks. Picks included CLDX (R=+73), AXSM (R=+50), IVDA (R=+31), ENLV (R=+39) — small caps not in sp500.

## Post-fix numbers (universe=491)

| Metric | Actual | Constrained | Score_picked | Relaxed_macro |
|---|---:|---:|---:|---:|
| Total return | **+60.86%** | +42.87% | +7.33% | +40.63% |
| Win rate | 22.09% | 95.65% | 21.13% | 76.81% |
| MaxDD | -34.15% | -0.07% | -3.16% | -0.52% |
| Round-trips | 86 | 90 | TBD | TBD |
| Runtime | n/a | ~5 min | (same run) | (same run) |

## New finding: Constrained ceiling below actual

The actual strategy's +60.86% **beats** the Constrained perfect-foresight ceiling's +42.87% by 18 pp. This shouldn't be possible if Constrained is a true upper bound under the same constraints.

### Hypotheses

1. **Filler sizing too conservative.** `Optimal_portfolio_filler.config` has its own `risk_per_trade_pct` and position caps; if these are tighter than the actual strategy's, the optimal picks all winners (95.65% WR) but doesn't compound size as effectively. Actual strategy may run higher leverage / larger positions per trade.

2. **Filler doesn't stack positions across Fridays.** It may treat each Friday independently rather than maintaining open positions over time the way the simulator does. With 86 actual RTs over 5 years, position overlap matters.

3. **Score_picked at +7.33%** is much worse than actual (+60.86%). This means picking by `cascade_score` DESC alone underperforms the actual entry walk by ~54 pp. The current strategy's ordering / interaction with cash + sector caps + held filter must be doing something the pure-score-rank doesn't capture.

### Implications

- **The "cascade-ranking error" gap structure from PR #747's plan needs revising.** Score_picked < Actual means current scoring isn't the bottleneck — something about the ENTRY WALK (cash budget, held filter, sector caps, short_notional cap) makes the actual strategy outperform pure ranking.
- **The Constrained variant's filler config needs to align with the actual strategy's sizing.** Currently the gap reads as "+18% the optimal could have done" but it's actually "+18% the actual does that the optimal filler can't replicate".

### Suggested follow-up (not in current plan)

- **PR-6 (new): Filler-actual parity audit.** Compare `Optimal_portfolio_filler.config` defaults against the actual strategy's `Portfolio_risk.config` and Weinstein_strategy entry-walk semantics. Either align them or document the divergence as expected.
- **PR-7 (new): Re-validate Score_picked semantics.** A 7% return for picking the highest-scoring candidates each Friday is implausibly low — almost like score is anti-correlated with realized return. Worth investigating whether the test universe is biased (sp500 is mostly high-quality, the screener isn't separating winners from losers among them).

## Per-Friday divergences

Read `dev/backtest/scenarios-2026-05-02-002149/sp500-2019-2023/optimal_strategy.md` for full per-Friday entry comparison. Spot check shows:
- Actual entered CBRE/ALB on 2019-01-05; optimal entered nothing.
- Actual entered AAPL on 2019-05-03; optimal preferred different sp500 names with higher forward R.

## Runtime perf (PR #748 effect)

Pre-#748: ~90 min on 491-symbol universe (with bug, 10473 effectively, but the 491-only path would still have been bottlenecked by the same per-candidate forward outlook recompute).
Post-#748+#749: ~5 min on 491-symbol universe — 18x speedup. PR-1 memoization confirmed working.

## What's next

- **Don't panic on Constrained < Actual.** It's a definition issue, not a strategy regression.
- **File the Filler-parity audit as a P1 follow-up.**
- **Score_picked = 7% needs explanation** — either Weinstein scoring is poorly calibrated for this universe (likely), OR the entry walk's cash gate / held filter is what's actually generating alpha (also likely).

## References

- Plan PR: #747, `dev/plans/optimal-strategy-improvements-2026-05-01.md`
- Universe-fix: #749 (P0)
- Memoize forward outlooks: #748 (PR-1)
- Score_picked variant: #750 (PR-4)
- Validated artefact dir: `/Users/difan/Projects/trading-1/dev/backtest/scenarios-2026-05-02-002149/sp500-2019-2023/`
