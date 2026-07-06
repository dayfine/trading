# Cash-reserve surface (`cash_reserve_pct`) — WF-CV verdict: REJECT; envelope program closed both directions (2026-07-06)

**Ledger:** `dev/experiments/_ledger/2026-07-06-cash-reserve-surface.sexp`
**Mechanism:** #1867 (`cash_reserve_pct`, default 0.0; working entry-funding
reserve, exits exempt — the replacement for the dead `min_cash_pct`, #1861)
**Spec + artifacts:** `dev/experiments/cash-reserve-2026-07-06/`
**Origin:** user-directed 2026-07-06 — "I thought we were going to look into
cash reserve = 30%."

## Setup

Broad-only surface (top-3000 PIT-2000), 2000–2026, 13×2y folds, production
caps + catstop, long-only + stage3/laggard. Variants:
`cash_reserve_pct ∈ {0.0=baseline, 0.10, 0.20, 0.30}`. Gate: Sharpe, m=7/n=13,
worst_delta 0.30. ~8.5h wall, 52 fold-runs, zero failures.

## Result — all variants FAIL the gate

| Variant | Sharpe μ±σ | Return% μ±σ | MaxDD% μ | Calmar μ | Sharpe wins | MaxDD wins |
|---|---|---|---|---|---|---|
| baseline (0.0) | 0.597 ± 0.494 | 19.9 ± 20.6 | 15.4 | 0.683 | — | — |
| r10 | 0.413 ± 0.574 | 12.2 ± 18.4 | 16.0 | 0.451 | 4/13 | 6/13 |
| r20 | **0.620** ± 0.443 | 16.8 ± **15.8** | **13.2** | **0.706** | 6/13 | 9/13 |
| r30 | 0.441 ± 0.714 | 12.7 ± 18.1 | 13.4 | 0.609 | 4/13 | 9/13 |

**The direct answer to the motivating question: a 30% reserve is a clear
loss.** Sharpe 0.441 vs 0.597, return 12.7% vs 19.9% per fold, and it is
WORSE in the 2022 bear fold (−15.5% vs baseline −10.2%). It buys ~2pp of mean
MaxDD relief for a ~7pp return cost. The old `min_cash_pct 0.30` config values
were never a good idea that had been switched off — they were untested
decoration.

## Why r20 is NOT promotable despite its aggregate edge

- **Non-monotonic response.** r10 is worse than BOTH neighbors nearly
  everywhere (f000: −5.0 vs +5.4/+7.6; f003: 10.6 vs 36.3/22.5; f009: −5.1 vs
  18.0/14.8); r20 beats both neighbors. A funding-budget change reshuffles
  *which* candidates get funded at the cash boundary (score order +
  alphabetical tiebreak) — chaotic path-dependence, not a smooth risk dial.
  Same class as the capacity-concentration **0.25 knife-edge spike**
  (2026-06-25): single-value win between worse neighbors = do-not-promote.
- **One flipped fold does the work.** r20's edge is mostly f011 (2022):
  +12.7% vs baseline −10.2% (Sharpe +0.66 vs −0.42). r30 got the **opposite**
  in the same fold (−15.5%, Sharpe −1.15) — not a robust regime benefit.
- Raw mean-Sharpe edge is +0.023 with σ≈0.44 over 13 folds and n_trials=3 —
  nowhere near DSR-survivable; and it still gate-fails on worst-fold f001
  (gap 0.40).

## The transferable WHYs

1. **10th `edge_is_the_fat_tail` confirmation:** in the monster fold f010
   (2020–21) every reserve level costs return (72.0% → 45.3/56.1/48.8). The
   marginal, cash-boundary entries carry positive expectancy on net; cutting
   their funding costs more than the cash cushion returns.
2. **Envelope program now closed BOTH directions.** Loosening is impossible
   (already ~100% deployed — #1861); tightening is now tested and rejected.
   If capital protection is ever wanted, the evidenced lever class is the
   **barbell overlay** (70/30 passed its promotion grid 2026-06-20), not an
   entry-funding reserve.
3. **Secondary observation (lens candidate, not a build):** the fold-level
   chaos under small funding perturbations is further evidence that
   cash-boundary candidate selection is noise-dominated (score ties +
   alphabetical tiebreak) — connects to
   `project_screener_alphabetical_tiebreak`.

## Status

`cash_reserve_pct` stays merged, default 0.0, searchable axis. Do not
re-sweep standalone. Track file `dev/status/cash-reserve.md` updated to
CLOSED.
